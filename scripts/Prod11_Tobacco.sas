/*
### CODE OWNERS: Kyle Baird, Shea Parkes

### OBJECTIVE:
	Calculate the Tobacco Use Prevalence quality measure

### DEVELOPER NOTES:
	There are not currently any code sets published. This is calculated off
	of survey data collected in an office visit.
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%GetParentFolder(1)Supp01_Shared.sas" / source2;

%AssertThat(%upcase(&quality_metrics.),eq, OHA_INCENTIVE_MEASURES
			,ReturnMessage=The user has not chosen to run OHA Incentive Measures.  This program does not need run.
			,FailAction = EndActiveSASSession 
			);

%AssertThat(
	%upcase(&anonymize.)
	,eq
	,TRUE
	,ReturnMessage=Clinically based quality measures are only calculated for demostration only.
	,FailAction=EndActiveSASSession
	)

%put WARNING: METRIC CALCULATION CODE BELOW IS LIKELY STALE. USERS SHOULD CONSIDER THIS BEFORE ENABLING PROGRAM FOR PRODUCTION PURPOSES;

/* Libnames */
libname M033_Out "&M033_Out." access=readonly;
libname M035_Out "&M035_Out." access=readonly;
libname M150_Tmp "&M150_Tmp.";
libname M150_Out "&M150_Out.";

%AssertDataSetExists(
	M033_out.emr_tobacco
	,ReturnMessage=EMR tobacco results are required to calculate the measure.
	,FailAction=EndActiveSASSession
	)
%sysfunc(ifc(%symexist(suppress_parser)
	,%str()
	,%nrstr(%AssertRecordCount(
		M033_out.emr_tobacco
		,gt
		,42
		,ReturnMessage=EMR data must be populated to calculate tobacco measure.
		,FailAction=EndActiveSASSession
		))
	));

%CacheWrapperPRM(033, 150)
%CacheWrapperPRM(035, 150)

%let measure_name = tobacco_use;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




proc sort
	data = M033_out.emr_tobacco
	out = emr_tobacco_sort
	;
	by
		member_id
		prm_tobacco_status_date
		;
run;

data emr_tobacco_recent;
	set emr_tobacco_sort;
	by
		member_id
		prm_tobacco_status_date
		;
	retain numerator;

	if prm_tobacco_status_date ge &measure_start.
		and prm_tobacco_status_date le &measure_end. then in_current_measure_period = 1;
	else in_current_measure_period = 0;

	if upcase(prm_tobacco_status) in (
		"CURRENT"
		) then numerator_eligible = 1;
	else numerator_eligible = 0;

	if in_current_measure_period eq 1 then numerator = numerator_eligible;

	format comments $128.;
	if prm_tobacco_status ne "" then do;
		comments = cat(
			"Smoking status of "
			,strip(prm_tobacco_status)
			," reported on "
			,putn(prm_tobacco_status_date,"MMDDYYs10.")
			);
		if in_current_measure_period eq 0 then comments = cat(
			strip(comments)
			," (not in performance year)"
			);
	end;

	if last.member_id;
run;

proc sql;
	create table M150_out.results_&measure_name. as
	select
		member.member_id
		,coalesce(
			tobacco.numerator
			,0
			) as numerator
		,1 as denominator
		,case calculated numerator
			when 1 then &measure_end.
			else .
			end
			as comp_quality_date_actionable format = YYMMDDd10.
		,coalesce(
			tobacco.comments
			,"Missing tobacco use status"
			) as comments format = $128. length = 128
	from M150_tmp.member as member
	left join emr_tobacco_recent as tobacco
		on member.member_id eq tobacco.member_id
	;
quit;
%LabelDataSet(M150_out.results_&measure_name.)

%put System Return Code = &syscc.;
