/*
### CODE OWNERS: Aaron Hoch, Ben Copeland, Michael Menser
### OBJECTIVE:
	Calculate the Assessments within 60 Days for Children in DHS Custody
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
libname M030_Out "&M030_Out." access=readonly;
libname M036_Out "&M036_Out." access=readonly;
libname M150_Out "&M150_Out.";
libname M150_Tmp "&M150_Tmp.";

%AssertThat(%GetRecordCount(M036_Out.members_foster_care)
	,gt
	,0
	,ReturnMessage=This program only applies when DHS custody notifications are present.
	,FailAction=EndActiveSASSession
	)

%CacheWrapperPRM(030,150)
%CacheWrapperPRM(035,150)
%CacheWrapperPRM(073,150)

%FindICDFieldNames()

%let measure_name = DHS_assessments;
%let age_limit_expression = calculated report_date_Age le 17;

%CodeGenClaimsFilter(
	&measure_name.
	,component=Numerator_Physical
	,Reference_Source=m015_out.oha_codes
	)

%CodeGenClaimsFilter(
	&measure_name.
	,component=Numerator_Mental
	,Reference_Source=m015_out.oha_codes
	)

%CodeGenClaimsFilter(
	&measure_name.
	,component=Numerator_Dental
	,Reference_Source=m015_out.oha_codes
	)

%CodeGenClaimsFilter(
	&measure_name.
	,component=Numerator_PRTS
	,Reference_Source=m015_out.oha_codes
	)

%let DHS_measure_end = %sysfunc(intnx(month,&Measure_End.,-2, end));
%put DHS_measure_end = %sysfunc(putn(&DHS_measure_end.,yymmddd10.));

%let n_days_allowed_for_assessments = 60;

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

proc sql;
	create table DHS_member_time
	as select
		mtime.member_ID
		,dhs.Report_Date
		,dhs.Eligibility_Effective_Date
		,intnx('days', dhs.Report_Date, -30) as Report_Date_minus_30 format= YYMMDDd10.
		,min(
			intnx('days', dhs.Report_Date, 60)
			,&empirical_elig_date_end.
			) as Report_Date_plus_60 format= YYMMDDd10.
		,dhs.dob
		,intck('year', dob, Report_Date, 'c') as report_date_Age
		,mtime.date_start
		,mtime.date_end
		
	from M036_Out.members_foster_care as dhs
	left join
		M150_Tmp.member_time as mtime
		on dhs.member_ID = mtime.member_ID

	where Report_Date between &Measure_start. and &DHS_measure_end.
			and &age_limit_expression.
			and dhs.branch_code not in ('6050','0060')	/*OHA is excluding children with a ‘6050’ or '0060' branch code, which signifies adoption/guardianship change.*/

	order by
		mtime.member_ID
		,dhs.Report_Date
		,mtime.date_end
	;
quit;


%FindEligGaps(
	DHS_member_time
	,DHS_elig_gaps
	,global_date_end=&DHS_measure_end.
	,varname_member_date_start=Report_Date
	,varname_member_date_end=Report_Date_plus_60
	,extra_by_variables=Report_Date
	)

proc summary nway missing data=DHS_member_time;
	class member_ID report_date Eligibility_Effective_Date Report_Date_minus_30 Report_Date_plus_60 report_date_Age;
	output out=DHS_Members_Age (drop=_:);
run;

proc sql;
	create table Denom_Members
	as select
		dhs.member_ID
		,dhs.report_date_Age
		,dhs.report_date
		,dhs.Report_Date_minus_30
		,dhs.Report_Date_plus_60
		,egaps.gap_cnt
		,egaps.gap_days
	from DHS_Members_Age as dhs
	left join
		DHS_elig_gaps as egaps
		on dhs.member_ID = egaps.member_ID
		and dhs.report_date = egaps.report_date

	where egaps.gap_cnt = 0 and Eligibility_Effective_Date ge Report_Date_minus_30
	;
quit;

proc sql;
	create table claims_interesting as
	select distinct
		denom.member_id
		,denom.report_date_Age
		,denom.report_date
		,denom.Report_Date_minus_30
		,denom.Report_Date_plus_60
		,denom.gap_cnt
		,denom.gap_days
		,outclaims_prm.prm_fromdate
		,outclaims_prm.hcpcs
		,outclaims_prm.modifier
		,outclaims_prm.modifier2
		,outclaims_prm.POS
		,icdversion
		,&diag_fields_select.
		,case 
			when 
				denom.member_ID ne "" 
				then 1
			else 0
		end as denominator

		,case
			when 
				(
					outclaims_prm.prm_fromdate ge denom.Report_Date_minus_30
					and outclaims_prm.prm_fromdate le denom.Report_Date_plus_60
					and ((&claims_filter_Numerator_Physical.) or (&claims_filter_Numerator_PRTS.))
				)
				then 1
			else 0
		end as Physical_Assessment

		,case
			when
				(
					outclaims_prm.prm_fromdate ge denom.Report_Date_minus_30
					and outclaims_prm.prm_fromdate le denom.Report_Date_plus_60
					and ((&claims_filter_Numerator_Mental.) or (&claims_filter_Numerator_PRTS.))
				)
				then 1
			else 0
		end as Mental_Assessment

		,case
			when
				(
					outclaims_prm.prm_fromdate ge denom.Report_Date_minus_30
					and outclaims_prm.prm_fromdate le denom.Report_Date_plus_60
					and (&claims_filter_Numerator_Dental.)
				)
				then 1
			else 0
		end as Dental_Assessment

	from M150_Tmp.Outclaims_PRM as Outclaims_PRM
	inner join Denom_Members as denom on
		Outclaims_PRM.Member_ID eq denom.Member_ID
	where
		outclaims_prm.prm_fromdate between &Measure_Start. and &Measure_End.
		and (
			(&claims_filter_Numerator_Physical.) 
			or (&claims_filter_Numerator_Mental.)
			or (&claims_filter_Numerator_Dental.)
			or (&claims_filter_Numerator_PRTS.)
			)
	
	order by
		denom.member_ID
		,outclaims_prm.prm_fromdate desc
	;
quit;

/*Mental Health Diagnosis Value Set is too large, so prepare to manually merge
on the codes*/
data mental_health_codes;
	set m015_out.oha_codes;
	where
		measure eq "&measure_name."
		and component eq 'Numerator_PhysMent'
	;
run;

proc sql noprint;
	select
		quote(trim(code))
	into
		:physical_new_em_codes separated by ','
	from
		mental_health_codes
	where
		codesystem eq 'CPT'
	;
quit;
%put &=physical_new_em_codes.;

data mental_health_diag_munge;
	set mental_health_codes;
	where codesystem ne 'CPT';

	/*Put ICDVersion in the format used in the claims data*/
	if codesystem eq 'ICD9CM-Diag' then ICDVersion = '09';
	else if codesystem eq 'ICD10CM-Diag' then ICDVersion = '10';

	mental_health_diag_yn = 'Y';
run;

data claims_physical_mental;
	set claims_interesting;

	format
		mental_health_diag_yn $1.
	;

	if _n_ = 1 then do;
		call missing(mental_health_diag_yn);
		declare hash hash_diag (dataset:  "mental_health_diag_munge", duplicate:  "ERROR");
		rc_diag = hash_diag.DefineKey("code", "icdversion");
		rc_diag = hash_diag.DefineData("mental_health_diag_yn");
		rc_diag = hash_diag.DefineDone();
	end;

	/*Hash on diag*/
	array icddiags icddiag:;

	do over icddiags;
		if icddiags ne "" then do;
			code = icddiags;
			rc_diag = hash_diag.find();
			if mental_health_diag_yn eq 'Y' then do;
				leave; /*No need to keep looping if we found this, only needed once per claim*/
			end;
		end;
	end;

	format
		physical_mental_assessment 8.
	;
	if
		hcpcs in (&physical_new_em_codes.)
		and mental_health_diag_yn eq 'Y'
	then do;
		physical_mental_assessment = 1;
		physical_assessment = 1;
		mental_assessment = 1;
	end;
	else do;
		physical_mental_assessment = 0;
	end;
run;




/*If we have a separate table for dental claims, incorporate those into the main claims.*/

%macro incorporate_dental_table;
	%if %sysfunc(exist(M150_Tmp.inpdental)) ne 0 %then %do;

		proc sql;
			create table inpdental_interesting as
			select distinct
				denom.member_id
				,denom.report_date_Age
				,denom.report_date
				,denom.Report_Date_minus_30
				,denom.Report_Date_plus_60
				,denom.gap_cnt
				,denom.gap_days
				,Outclaims_PRM.FromDate as prm_fromdate
				,Outclaims_PRM.hcpcs
				,Outclaims_PRM.modifier
				,Outclaims_PRM.modifier2
				,Outclaims_PRM.POS
				,case 
					when 
						denom.member_ID ne "" 
						then 1
					else 0
				end as denominator
				,0 as Physical_Assessment
				,0 as Mental_Assessment
				,case 
					when
						(
							Outclaims_PRM.FromDate ge denom.Report_Date_minus_30
							and Outclaims_PRM.FromDate le denom.Report_Date_plus_60
							and (&claims_filter_Numerator_Dental.)
						)
						then 1
					else 0
				end as Dental_Assessment

			from M150_Tmp.inpdental as Outclaims_PRM /*Alias dental table as outclaims_prm so that our CodeGenClaimsFilter macro works.*/
			inner join Denom_Members as denom on
				Outclaims_PRM.Member_ID eq denom.Member_ID
			where
				Outclaims_PRM.FromDate between &Measure_Start. and &Measure_End.
				and &claims_filter_Numerator_Dental.

			order by
				denom.member_ID
				,Outclaims_PRM.FromDate desc
			;
		quit;

		data claims_interesting;
			set claims_physical_mental
				inpdental_interesting;
		run;

		proc sort data = claims_interesting;
			by member_ID descending PRM_FromDate;
		run;
	%end;
%mend incorporate_dental_table;

%incorporate_dental_table;

proc summary nway missing
	data = claims_interesting;
	class member_id report_date report_date_Age;
	var denominator Physical_Assessment Mental_Assessment Dental_Assessment;
	where denominator ne 0;
	output out = flagged_assessments (drop = _Type_ _freq_)
		max=
	;
run;

proc sql;
	create table flagged_numerators
	as select
		*
		,case
			when
				(
					(
						report_date_Age ge 4
						and Physical_Assessment = 1
						and Mental_Assessment = 1
						and Dental_Assessment = 1
					)

					or

					(
						report_date_Age ge 1 and report_date_Age lt 4
						and Physical_Assessment = 1
						and Dental_Assessment = 1

					)

					or

					(
						report_date_Age lt 1
						and Physical_Assessment = 1
					)

				)
				then 1
			else 0
		end as numerator
		,intnx("day",report_date,&n_days_allowed_for_assessments.,"same") as date_assessment_cutoff format = YYMMDDd10.
		,case calculated numerator
			when 0 then case
				when calculated date_assessment_cutoff gt &date_latestpaid. then calculated date_assessment_cutoff
				else .
				end
			else .
			end
			as comp_quality_date_actionable format = YYMMDDd10.
		,cat(
			'DHS Notification Date: '
			,put(report_date, MMDDYYs10.)
			,"; "
			,case
				when calculated date_assessment_cutoff
					le &date_latestpaid. /*Should be really sure users have view reports after this date*/
					then "Assessment period ended"
				else cat("Assessment period ends ",putn(calculated date_assessment_cutoff,"MMDDYYs10."))
				end
			) as comments format = $128. length = 128
		
	from flagged_assessments 
	;
quit;


proc summary nway missing
	data = flagged_numerators;
	class member_id comp_quality_date_actionable comments;
	var denominator numerator;
	output out = M150_out.results_&measure_name. (drop = _Type_ _freq_)
		sum=
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
