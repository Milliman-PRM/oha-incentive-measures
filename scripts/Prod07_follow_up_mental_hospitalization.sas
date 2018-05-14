/*
### CODE OWNERS: Neil Schneider, Ben Copeland, Michael Menser

### OBJECTIVE:
	Calculate the Follow-Up after Hospitalization for Mental Illness (NQF 0576)

### DEVELOPER NOTES:
	While we used to determine whether claims were inpatient by looking for a PRM_Line code starting with "I," WOAH's 2016 quality metric pdf has a new definition
	for inpatient claims.  A claim is inpatient if its revenue code is in a certain set of values (given in the pdf), and this code implements that definition.
	
	Deviation from specifications document:
	  We have not accounted for OHA's adult mental health residential service codes in denominator exclusions. We have not yet found any of these codes in the data
	  , and implementation would require infrastructure changes to the shared code/macros
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
%CacheWrapperPRM(035,150)
%CacheWrapperPRM(073,150)
%FindICDFieldNames()

%let measure_name = fuh_mental;
%let age_limit_expression = ge 6;
%CodeGenClaimsFilter(
	&measure_name.
	,component=denominator
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=inpatient
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_excl_NAC
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_excl_MHD
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=numerator
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_rev2
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=numerator_TCM
	,Reference_Source=m015_out.oha_codes
	)

%let admission_end = %sysfunc(intnx(days, &measure_end., -30));
%put admission_end = %sysfunc(putn(&admission_end.,yymmddd10.));
/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/

proc sql;
	create table claims_interesting as
	select distinct
		outclaims_prm.member_id
		,member.dob
		,outclaims_prm.prm_fromdate
		,outclaims_prm.prm_todate
/*		,outclaims_prm.prm_line*/
/*		,outclaims_prm.hcpcs*/
/*		,outclaims_prm.icddiag1*/
/*		,outclaims_prm.POS*/
		,case
			when (&claims_filter_denominator.) and (&claims_filter_inpatient.) and not (&claims_filter_denom_excl_NAC.) then 'Y'
			else 'N'
		end as denominator_elig_YN
		,case
			when (&claims_filter_inpatient.) and (&claims_filter_denom_excl_NAC.) then 'Y'
			else 'N'
		end as non_acute_fac_YN
		,case
			when (&claims_filter_denom_excl_MHD.) and (&claims_filter_inpatient.) and not (&claims_filter_denom_excl_NAC.) then 'Y'
			else 'N'
		end as acute_MH_readmission_elig_YN
		,case
			when 
				(&claims_filter_numerator.)
				or ((&claims_filter_numer_rev2.) and (&claims_filter_denominator.))
				then 'Y'
			else 'N'
		end as numerator_YN
		,case
			when (&claims_filter_numerator_TCM.) then 'Y'
			else 'N'
		end as numerator_TCM_YN
		,case
			when (&claims_filter_inpatient.) and not (&claims_filter_denom_excl_NAC.) then 'Y'
			else 'N'
		end as acute_YN
	from M150_Tmp.Outclaims_PRM as Outclaims_PRM
	inner join M150_Tmp.Member as Member on
		Outclaims_PRM.Member_ID eq Member.Member_ID
	where
		outclaims_prm.prm_todate between &Measure_Start. and &Measure_End.
		and (
			(&claims_filter_inpatient. and not (&claims_filter_denom_excl_NAC.))
			or ((&claims_filter_inpatient.) and (&claims_filter_denom_excl_NAC.))
			or (&claims_filter_numerator.)
			or (&claims_filter_numerator_TCM.)
			or ((&claims_filter_numer_rev2.) and (&claims_filter_denominator.))
			)
	order by
		outclaims_prm.member_ID
		,outclaims_prm.prm_todate desc
		,outclaims_prm.prm_fromdate desc
	;
quit;

/*Flag exclusions and follow-ups*/
data claims_flagged;
	set claims_interesting;
	by
		member_id
		descending prm_todate
		descending prm_fromdate
	;

	format
		last_followup
		last_followup_TCM
		last_exclusion
		YYMMDDd10.
	;

	retain
		last_followup
		last_followup_TCM
		last_exclusion
	;
	
	array last_dates last_:;
	if first.member_ID then do over last_dates;
		last_dates = .;
	end;

	if 
		denominator_elig_YN eq 'Y'
		and not (last_exclusion - prm_todate in (0:30)) 
		and floor(yrdif(dob,prm_todate,"age")) &age_limit_expression. 
		and prm_todate le &admission_end. then do;
		denominator = 1;
		if (last_followup - prm_todate) in (0:7) then numerator = 1;
		else if (last_followup_TCM - prm_todate) eq 29 then numerator = 1;
		else numerator = 0;
	end;

	output;

	if numerator_YN eq 'Y' then last_followup = prm_fromdate;
	if numerator_TCM_YN eq 'Y' then last_followup_TCM = prm_fromdate;
	if acute_YN eq 'Y' or acute_MH_readmission_elig_YN eq 'Y' or non_acute_fac_YN eq 'Y' then last_exclusion = prm_fromdate;
run;
		
/*Isolate lines flagged for the denominator*/
data denom_disch;
	set claims_flagged;
	where denominator eq 1;
run;

/*Merge eligibility info onto each denominator discharge*/
proc sql;
	create table disch_member_time
	as select
		disch.member_ID
		,disch.prm_todate
		,disch.prm_todate as elig_start
		,disch.prm_todate + 30 as elig_end format = YYMMDDd10.
		,mem_time.date_start
		,mem_time.date_end
	from denom_disch as disch
	left join m150_tmp.member_time as mem_time
		on disch.member_ID = mem_time.member_ID
	order by
		disch.member_ID
		,disch.prm_todate
		,mem_time.date_end
	;
quit;

%FindEligGaps(
	dataset_input= disch_member_time
	,dataset_output= disch_elig_gaps
	,varname_member_date_start= elig_start
	,varname_member_date_end= elig_end
	,extra_by_variables= prm_todate
	);

/*Limit to only discharges with continuous eligibility requirements.*/
proc sql;
	create table disch_elig
	as select
		src.*
	from denom_disch as src
	left join disch_elig_gaps as lim
		on src.member_id eq lim.member_id
		and src.prm_todate eq lim.prm_todate
	where
		lim.gap_days eq 0
		and lim.gap_cnt eq 0
	;
quit;

/*Find the most recent discharge*/
proc summary nway missing
	data = disch_elig;
	class member_id;
	var prm_todate;
	where denominator ne .;
	output out = max_disch_date (drop = _type_ _freq_)
		max= / autoname
	;
run;

/*Roll up to member level*/
proc summary nway missing
	data = disch_elig;
	class member_id;
	var denominator numerator;
	where denominator ne .;
	output out = member_rollup (drop = _Type_ _freq_)
		sum=
	;
run;

proc sql;
	create table M150_out.results_&measure_name.
	as select
		src.*
		,case src.numerator
			when 0 then
				case
					when sum(max_disch_date.prm_todate_max,7) gt &date_latestpaid. then sum(max_disch_date.prm_todate_max,7)
					else .
					end
			else .
			end
			as comp_quality_date_actionable format = YYMMDDd10.
		,cat(
			'Most Recent Hospitalization: ', 
			put(max_disch_date.prm_todate_max, MMDDYYs10.)
		) as comments length = 128 format = $128.
	from member_rollup as src
	left join max_disch_date
		on src.member_id = max_disch_date.member_id
	order by
		src.member_id
	;
quit;
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




/*** DETERMINE ELIGIBLE MEMBERS ***/

%put System Return Code = &syscc.;
