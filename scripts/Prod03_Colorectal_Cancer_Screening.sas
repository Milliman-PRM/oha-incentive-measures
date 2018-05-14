/*
### CODE OWNERS: Kyle Baird, Ben Copeland

### OBJECTIVE:
	Calculate the Colorectal Cancer Screening measure and provide a list of members inlcuded in the measure.

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2;

%AssertThat(%upcase(&quality_metrics.),eq, OHA_INCENTIVE_MEASURES
			,ReturnMessage=The user has not chosen to run OHA Incentive Measures.  This program does not need run.
			,FailAction = EndActiveSASSession 
			);

/* Libnames */
libname M015_Out "&M015_Out." access=readonly;
libname M150_Out "&M150_Out.";
libname M150_Tmp "&M150_Tmp.";
%CacheWrapperPRM(035,150);
%CacheWrapperPRM(073,150);

%let measure_name = crc_screening;
%let max_days_elig_gaps = 45;
%let max_cnt_elig_gaps = 1;
%let age_limit_expression = between 51 and 75;

%FindICDFieldNames()

%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_exclusion
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_colo
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_flexsig
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_fobt
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=Numer_CT
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=Numer_FIT
	,Reference_Source=m015_out.oha_codes
	)

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




/*** FIND ELIGIBILITY GAPS ***/
proc sql;
	create table elig_gap_prep as
	select
		member_time.member_id
		,member_time.date_start
		,member_time.date_end
	from M150_tmp.member_time as member_time
	inner join M150_tmp.member as member
		on member_time.member_id eq member.member_id
			and floor(yrdif(member.dob,&measure_end.,"age")) &age_limit_expression.
	order by
		member_time.member_id
		,member_time.date_end
	;
quit;

proc sql;
	create table elig_date_end_freq as
	select
		elig_date_end
		,count(*) as memcnt format=comma12.
	from (
		select
			member_id
			,max(date_end) as elig_date_end format=YYMMDDd10.
		from elig_gap_prep
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
%let empirical_elig_date_end = %sysfunc(min(&empirical_elig_date_end., &Measure_End.));
%put empirical_elig_date_end = &empirical_elig_date_end. (i.e. %sysfunc(putn(&empirical_elig_date_end., yymmdd10.)));

%FindEligGaps(
	elig_gap_prep
	,elig_gaps_prior
	,global_date_start=%sysfunc(intnx(year,&measure_start.,-1,same))
	,global_date_end=%sysfunc(intnx(year,&measure_end.,-1,same))
	)
%FindEligGaps(
	elig_gap_prep
	,elig_gaps_current
	,global_date_start=&measure_start.
	,global_date_end=&empirical_elig_date_end.
	,global_date_anchor=&empirical_elig_date_end.
	)

/*** SNAG ALL MEMBERS MEETING BASIC MEMBERSHIP REQUIREMENTS ***/
proc sql;
	create table members_meeting_elig as
	select
		current.member_id
	from (
		select
			member_id
		from elig_gaps_current
		where gap_cnt le &max_cnt_elig_gaps.
			and gap_days le &max_days_elig_gaps.
			and upcase(elig_on_anchor_yn) eq "Y"
		) as current
	inner join (
		select
			member_id
		from elig_gaps_prior
		where gap_cnt le &max_cnt_elig_gaps.
			and gap_days le &max_days_elig_gaps.
		) as prior
		on current.member_id eq prior.member_id
	order by current.member_id
	;
quit;

/*** KNOCKOUT MEMBERS WITH SPECIFIC CLAIM HISTORIES ***/
proc sql;
	create table members_denominator as
	select
		members.member_id
	from members_meeting_elig as members
	left join (
		select distinct
			member_id
		from M150_tmp.outclaims_prm
		where (&claims_filter_denom_exclusion.)
		) as excluded
		on members.member_id eq excluded.member_id
	where excluded.member_id is null
	;
quit;

/*** FLAG MEMBERS QUALIFYING FOR NUMERATOR ***/
proc sql;
	create table numerator_colonoscopy as
	select
		member_id
		,max(prm_fromdate) as most_recent_screening format = YYMMDDd10.
		,max(
			case
				when outclaims_prm.prm_fromdate between %sysfunc(intnx(year,&measure_start.,-9,same)) and &measure_end. then 1
				else 0
				end
		) as numerator_colonoscopy
		,cat("Colonoscopy (", putn(calculated most_recent_screening,"MMDDYYs10."), ")") as comments_colonoscopy length = 42 format = $42.
	from M150_tmp.outclaims_prm
	where (&claims_filter_numer_colo.)
	group by member_id
	order by member_id
	;
	create table numerator_flexsig as
	select
		member_id
		,max(prm_fromdate) as most_recent_screening format = YYMMDDd10.
		,max(
			case
				when outclaims_prm.prm_fromdate between %sysfunc(intnx(year,&measure_start.,-4,same)) and &measure_end. then 1
				else 0
				end
		) as numerator_flexsig
		,cat("Flexible Sigmoidoscopy (", putn(calculated most_recent_screening,"MMDDYYs10."),")") as comments_flexsig length = 42 format = $42.
	from M150_tmp.outclaims_prm
	where (&claims_filter_numer_flexsig.)
	group by member_id
	order by member_id
	;
	create table numerator_fobt as
	select
		member_id
		,max(prm_fromdate) as most_recent_screening format = YYMMDDd10.
		,max(
			case
				when outclaims_prm.prm_fromdate between &measure_start. and &measure_end. then 1
				else 0
				end
		) as numerator_fobt
		,cat(
			"FOBT ("
			,putn(calculated most_recent_screening,"MMDDYYs10.")
			,case
				when not (calculated most_recent_screening between &Measure_Start. and &Measure_End.) then " not in performance year"
				else ""
				end
			,")"
			) as comments_fobt length = 42 format = $42.
	from M150_tmp.outclaims_prm
	where (&claims_filter_numer_fobt.)
	group by member_id
	order by member_id
	;
	create table numerator_ct_colonography as
	select
		member_id
		,max(prm_fromdate) as most_recent_screening format = YYMMDDd10.
		,max(
			case
				when outclaims_prm.prm_fromdate between %sysfunc(intnx(year,&measure_start.,-4,same)) and &measure_end. then 1
				else 0
				end
		) as numerator_ct
		,cat("CT Colonography (", putn(calculated most_recent_screening,"MMDDYYs10."),")") as comments_ct length = 42 format = $42.
	from M150_tmp.outclaims_prm
	where (&claims_filter_numer_ct.)
	group by member_id
	order by member_id
	;
	create table numerator_fit_dna as
	select
		member_id
		,max(prm_fromdate) as most_recent_screening format = YYMMDDd10.
		,max(
			case
				when outclaims_prm.prm_fromdate between %sysfunc(intnx(year,&measure_start.,-2,same)) and &measure_end. then 1
				else 0
				end
		) as numerator_fit
		,cat("FIT-DNA Test (", putn(calculated most_recent_screening,"MMDDYYs10."),")") as comments_fit length = 42 format = $42.
	from M150_tmp.outclaims_prm
	where (&claims_filter_numer_fit.)
	group by member_id
	order by member_id
	;
quit;

/*** OUTPUT ***/
data M150_out.results_&measure_name.;
	merge
		members_denominator (in = denom)
		numerator_colonoscopy
		numerator_flexsig
		numerator_fobt
		numerator_ct_colonography
		numerator_fit_dna
		;
	by member_id;
	if denom;
	denominator = 1;
	numerator = max(
		numerator_colonoscopy
		,numerator_flexsig
		,numerator_fobt
		,numerator_ct
		,numerator_fit
		,0
		);
	format comp_quality_date_actionable YYMMDDd10.;
	if numerator eq 0 then comp_quality_date_actionable = &measure_end.;
	format comments $128.;
	*Logic done by length checks to avoid need for ORs;
	comments = comments_colonoscopy;
	if lengthn(comments) gt 0 then do;
		if lengthn(comments_flexsig) gt 0 then comments = cat(strip(comments),"; ",comments_flexsig);
	end;
	else comments = comments_flexsig;
	if lengthn(comments) gt 0 then do;
		if lengthn(comments_fobt) gt 0 then comments = cat(strip(comments),"; ",comments_fobt);
	end;
	else comments = comments_fobt;
	if lengthn(comments) gt 0 then do;
		if lengthn(comments_ct) gt 0 then comments = cat(strip(comments),"; ",comments_ct);
	end;
	else comments = comments_ct;
	if lengthn(comments) gt 0 then do;
		if lengthn(comments_fit) gt 0 then comments = cat(strip(comments),"; ",comments_fit);
	end;
	else comments = comments_fit;
	*Tack on the prefix after so the above length checks work correctly;
	if lengthn(comments) gt 0 then comments = cat("Screening Date(s): ",strip(comments));
	keep
		member_id
		denominator
		numerator
		comp_quality_date_actionable
		comments
		;
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
