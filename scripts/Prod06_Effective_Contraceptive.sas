/*
### CODE OWNERS: Ben Copeland, Neil Schneider, Michael Menser, Katherine Castro

### OBJECTIVE:
	Calculate the Effective Contraceptive Use quality measure
	so it can be included in the reports.

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2;

/* Libnames */
libname ref_data "%sysget(reference_data_pathref)" access=readonly;
libname oha_ref "%sysget(OHA_INCENTIVE_MEASURES_PATHREF)" access=readonly;
libname M150_Out "&M150_Out.";
libname M150_Tmp "&M150_Tmp.";
%CacheWrapperPRM(035,150)
%CacheWrapperPRM(073,150)
%FindICDFieldNames()

%let measure_name = eff_contra;
%let age_limit_expression = between 15 and 50;
%let gender_limit = F;
%CodeGenClaimsFilter(
	&measure_name.
	,component=numerator_cpthcpcs
	,Reference_Source=oha_ref.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=numerator_icddiag
	,Reference_Source=oha_ref.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=numerator_icdproc
	,Reference_Source=oha_ref.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,Name_Output_Var=claims_filter_numer_perm
	,component=numerator_permanent
	,Reference_Source=oha_ref.oha_codes
)
%CodeGenClaimsFilter(
    &measure_name.
    ,component=denom_exclusion
    ,Reference_Source=oha_ref.oha_codes
)
/*Bring all numerators back together so we can grab all numerator claims at once.*/
%let claims_filter_numerator = &claims_filter_numer_perm. or &claims_filter_numerator_cpthcpcs. or &claims_filter_numerator_icddiag. or &claims_filter_numerator_icdproc.;
%put &=claims_filter_numerator.;
%CodeGenClaimsFilter(
	&measure_name.
	,component=numerator_ndc
	,Reference_Source=oha_ref.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_exclusion
	,Reference_Source=oha_ref.oha_codes
	)

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/

/*** DERIVE LAST CREDIBLE ELIGIBILITY DATE ***/
proc sql;
	create table elig_date_end_freq as
	select
		elig_date_end
		,count(*) as memcnt format = comma12.
	from (
		select
			member_id
			,max(date_end) as elig_date_end format = YYMMDDd10.
		from M150_tmp.member_time
		group by member_id
		)
	group by elig_date_end
	order by elig_date_end desc
	;
quit;

%sysfunc(ifc(%symexist(empirical_elig_date_end)
	,%nrstr(%put empirical_elig_date_end already present, likely from test mocking.;)
	,%nrstr(
		proc sql noprint;
			select max(elig_date_end)
			into :empirical_elig_date_end trimmed
			from elig_date_end_freq
			where memcnt ge 42
			;
		quit;
		)
	))
%let empirical_elig_date_end = %sysfunc(min(&empirical_elig_date_end.,&measure_end.));
%put empirical_elig_date_end = &empirical_elig_date_end. %sysfunc(putn(&empirical_elig_date_end.,YYMMDDd10.));

/*** AGE RESTRICTIONS ***/
data members_meeting_ag;
	set M150_tmp.member (
		keep =
			member_id
			dob
			gender
		);
	where
		floor(yrdif(dob,&measure_end.,"age")) &age_limit_expression.
		and upcase(gender) eq upcase("&gender_limit.")
	;
run;

/*Remove members with denominator exclusins*/
proc sql;
	create table members_not_excl
	as select
		src.*
	from members_meeting_ag as src
	left join
		(select distinct
			member_ID
		from m150_tmp.outclaims_prm
		where
			(&claims_filter_denom_exclusion.)
		) as excl
	on
		src.member_ID eq excl.member_ID
	where excl.member_ID is null
	;
quit;

/*Merge on elig windows*/
proc sql;
	create table members_elig_windows
	as select
		mem_time.member_id
		,mem_time.date_start
		,mem_time.date_end
	from m150_tmp.member_time as mem_time
	inner join members_not_excl as member
	on mem_time.member_ID eq member.member_ID
	order by
		mem_time.member_id
		,mem_time.date_end
	;
quit;

%FindEligGaps(
	dataset_input=members_elig_windows
	,dataset_output=member_elig_gaps
	,global_date_start=&measure_start.
	,global_date_end=&empirical_elig_date_end.
	)

/*** FLAG DENOMINATOR ***/
proc sort data = member_elig_gaps
	out = members_denominator (keep = member_id)
	;
	where
		gap_cnt le 1
		and gap_days le 45
		;
	by member_id;
run;

/*** FLAG NUMERATOR ***/
%macro flag_numerator_claims();
proc sql;
	create table qualifying_claims_med as
	select
		qualifying_claims.*
		,coalesce(ref_hcpcs_cpt.hcpcs_desc,"Unknown") as hcpcs_desc
	from (
		select
			member_id
			,claimid
			,linenum
			,sequencenumber
			,prm_fromdate
			,paiddate
			,prm_costs
			,hcpcs
			,case
				when (&claims_filter_numerator_cpthcpcs.) then 1
				else 0
				end
				as match_cpthcpcs
			,case
				when prm_fromdate ge &measure_start.
					and prm_fromdate le &measure_end.
					then 1
				when (&claims_filter_numer_perm.) then 1
				else 0
				end
				as in_current_measure_period
		from M150_tmp.outclaims_prm
		where (&claims_filter_numerator.)
		) as qualifying_claims
	left join ref_data.hcpcs_descr as ref_hcpcs_cpt
		on qualifying_claims.hcpcs eq ref_hcpcs_cpt.hcpcs
	order by
		qualifying_claims.member_id
		,qualifying_claims.prm_fromdate
		,qualifying_claims.paiddate
		,abs(qualifying_claims.prm_costs) desc
		,qualifying_claims.claimid
		,qualifying_claims.linenum
		,qualifying_claims.sequencenumber
	;
quit;

data qualifying_claims_med_recent;
	set qualifying_claims_med;
	by member_id;
	retain numerator;

	if first.member_id then numerator = 0;
	if in_current_measure_period eq 1 then numerator = 1;

	format comments $128.;
	if match_cpthcpcs then comments = cat(
		"Procedure description: "
		,substr(strip(hcpcs_desc),1,min(length(hcpcs_desc),90)) /*Only have up to 128 characters*/
		," on "
		,putn(prm_fromdate,"MMDDYYs10.")
		);
	else comments = cat(
		"Applicable medical claim on "
		,putn(prm_fromdate,"MMDDYYs10.")
		);
	keep
		member_id
		prm_fromdate
		numerator
		comments
		;
	if last.member_id;
run;

%if %upcase(&rx_claims_exist.) eq YES %then %do;
	proc sql;
		create table qualifying_claims_rx as
		select
			member_id
			,prm_fromdate
			,ndc
			,coalesce(prm_productname,"Unknown") as prm_productname
			,case
				when prm_fromdate ge &measure_start.
					and prm_fromdate le &measure_end.
					then 1
				else 0
				end
				as in_current_measure_period
		from M150_tmp.outpharmacy_prm
		where (&claims_filter_numerator_ndc.)
		order by
			member_id
			,prm_fromdate
			,paiddate
			,abs(prm_costs) desc
			,claimid
			,sequencenumber
		;
	quit;

	data qualifying_claims_rx_recent;
		set qualifying_claims_rx;
		by member_id;
		retain numerator;

		if first.member_id then numerator = 0;
		if in_current_measure_period eq 1 then numerator = 1;

		format comments $128.;
		comments = cat(
			"Filled Script for "
			,substr(prm_productname,1,min(length(prm_productname),95)) /*Only have up to 128 characters*/
			," on "
			,putn(prm_fromdate,"MMDDYYs10.")
			);
		keep
			member_id
			prm_fromdate
			numerator
			comments
			;
		if last.member_id;
	run;
%end;
%else %do;
	data qualifying_claims_rx_recent;
		set qualifying_claims_med_recent (
			obs=0
			keep =
				member_id
				prm_fromdate
				numerator
				comments
			);
	run;
%end;
%mend flag_numerator_claims;
%flag_numerator_claims()

data qualifying_claims_stacked;
	set
		qualifying_claims_med_recent
		qualifying_claims_rx_recent
		;
run;

proc sort data = qualifying_claims_stacked out = qualifying_claims_sort;
	by member_id descending numerator descending prm_fromdate;
run;

data members_numerator_no_exclusions;
	set qualifying_claims_sort;
	by member_id;
	if first.member_id;
	drop prm_fromdate;
run;

/*Remove second round of denominator exclusions, which requires knowledge
of numerator compliancy first*/

/*The numerator exclusion code set is too large to store in a macro variable, so we must limit our OHA code set to numerator exclusion codes,
then merge this on to the outclaims to identify numerator exclusion claims.*/

data denominator_exception_codes;
	set oha_ref.oha_codes;
	where
 		upcase(measure) eq %upcase("&measure_name.")
 		and upcase(component) eq %upcase('Denom_Exception')
 	;
run;

proc sql noprint;
 select
 	quote(strip(code))
 into
 	:CPT_denominator_exception_codes separated by ','
 from
 	denominator_exception_codes
 where
 	codesystem in ('CPT', 'HCPCS')
 ;
quit;

%put &=CPT_denominator_exception_codes.;

data denominator_exception_diag_munge;
	set denominator_exception_codes;
	where codesystem in ('ICD9CM-Diag', 'ICD10CM-Diag');

	/*Put ICDVersion in the format used in the claims data*/
	if codesystem eq 'ICD9CM-Diag' then ICDVersion = '09';
	else if codesystem eq 'ICD10CM-Diag' then ICDVersion = '10';

	denominator_exception_code_yn = 'Y';
run;

data claims_denominator_exception;
	set M150_tmp.Outclaims_prm;

	format
	denominator_exception_code_yn $1.
	;

	denominator_exception_code_yn = 'N';

	if _n_ = 1 then do;
 		declare hash hash_diag (dataset:  "denominator_exception_diag_munge", duplicate:  "ERROR");
 		rc_diag = hash_diag.DefineKey("code", "icdversion");
 		rc_diag = hash_diag.DefineData("denominator_exception_code_yn");
 		rc_diag = hash_diag.DefineDone();
 	end;

	if
 		hcpcs in (&CPT_denominator_exception_codes.)
 	then
 		denominator_exception_code_yn = 'Y';

 	/*Hash on diag*/
	array icddiags icddiag:;

	if denominator_exception_code_yn eq 'N' then do;
 		do over icddiags;
 			if icddiags ne "" then do;
 				code = icddiags;
 				rc_diag = hash_diag.find();
 				if denominator_exception_code_yn eq 'Y' then do;
 					leave; /*No need to keep looping if we found this, only needed once per claim*/
 				end;
 			end;
 		end;
	end;
run;

proc sql;
	create table pregnancy_exclusions as
	select distinct member_ID
	from claims_denominator_exception
	where denominator_exception_code_yn = 'Y'
		and prm_fromdate ge &measure_start.
		and prm_fromdate le &measure_end.
	order by member_ID
	;
quit;

/*Combine and output*/
data m150_out.results_&measure_name.;
	merge
		members_denominator (in = denom)
		members_numerator_no_exclusions (in = numer)
		pregnancy_exclusions (in = exclusion)
		;
	by member_id;
	if denom;
	denominator = 1;
	numerator = coalesce(numerator,0);
	format comp_quality_date_actionable YYMMDDd10.;
	if numerator eq 0 then comp_quality_date_actionable = &measure_end.;
	*Exclusion only applies if they were not numerator compliant;
	if numerator eq 1
		or not(exclusion)
		then output;
run;
%LabelDataSet(M150_out.results_&measure_name.)

proc sql noprint;
	select
		sum(numerator) as sum_numerator
		,sum(denominator) as sum_denominator
		,case
			when calculated sum_denominator gt 0 then round(coalesce(calculated sum_numerator,0) / calculated sum_denominator,0.0001)
			else 0
			end
			as measure_rate
	into :sum_numerator trimmed
		,:sum_denominator trimmed
		,:measure_rate trimmed
	from M150_out.results_&measure_name.
	;
quit;
%put sum_numerator = &sum_numerator.;
%put sum_denominator = &sum_denominator.;
%put measure_rate = &measure_rate.;


%put System Return Code = &syscc.;
