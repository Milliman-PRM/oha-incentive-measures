/*
### CODE OWNERS: Kyle Baird, Steve Gredell

### OBJECTIVE:
	Calculate the Poor HbA1c control measure for patient with diabetes
	so it can be reported

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas";

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
libname M015_out "&M015_out." access=readonly;
libname M033_out "&M033_out." access=readonly;
libname M150_tmp "&M150_tmp.";
libname M150_out "&M150_out.";

%AssertDataSetExists(
	M033_out.emr_labs
	,ReturnMessage=EMR lab results are required to calculate the measure.
	,FailAction=EndActiveSASSession
	)
%sysfunc(ifc(%symexist(suppress_parser)
	,%str()
	,%nrstr(%AssertRecordCount(
		M033_out.emr_labs
		,gt
		,42
		,ReturnMessage=EMR data must be populated to calculate diabetes HbA1c measure.
		,FailAction=EndActiveSASSession
		))
	));

%CacheWrapperPRM(033, 150)
%CacheWrapperPRM(035, 150)
%CacheWrapperPRM(073, 150)

%let measure_name = Diabetes_HbA1c;
%let age_limit_expression = between 18 and 75;

%FindICDFieldNames()

%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_diabetes
	,Reference_Source=m015_out.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_service
	,Reference_Source=m015_out.oha_codes
	)

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




proc sql;
	create table members_denom as
	select members_age.member_id
	from (
		select member_id
		from M150_tmp.member
		where floor(yrdif(dob,&measure_end.,"age")) &age_limit_expression.
		) as members_age
	inner join (
		select distinct member_id
		from M150_tmp.outclaims_prm
		where outclaims_prm.prm_fromdate le &measure_end.
			and (&claims_filter_denom_diabetes.)
		) as members_diabetes
		on members_age.member_id eq members_diabetes.member_id
	inner join (
		select distinct member_id
		from M150_tmp.outclaims_prm
		where outclaims_prm.prm_todate ge &measure_start.
			and outclaims_prm.prm_fromdate le &measure_end.
			and (&claims_filter_denom_service.)
		) as members_op_service
		on members_age.member_id eq members_op_service.member_id
	;
quit;

proc sql;
	create table tests_hba1c as
	select
		labs.member_id
		,labs.test_date
		,labs.prm_test_value
		,labs.prm_test_value_decimals
		,labs.prm_test_units_desc
		,case
			when labs.prm_test_value gt 9.0 then 1
			else 0
			end
			as diabetes_poor_control
		,case
			when labs.test_date between &measure_start. and &measure_end. then 1
			else 0
			end
			as in_current_measure_period
		,case
			when calculated diabetes_poor_control eq 0 
				and calculated in_current_measure_period eq 1
				then 0
			else 1 /*No value=poor control*/
			end
			as numerator_eligible
	from M033_out.emr_labs as labs
	where upcase(labs.prm_test) eq "HEMOGLOBIN"
		and upcase(labs.prm_test_item) eq "A1C"
		and labs.prm_test_units_desc eq "%" /*Measure numerator target is given as percentage.*/
	order by
		labs.member_id
		,labs.test_date
		,calculated numerator_eligible desc /*Numerator match is bad, benfit of doubt if multiple readings on same day*/
	; 
quit;

data recent_hba1c;
	set tests_hba1c;
	by
		member_id
		test_date
		descending numerator_eligible
		;
	retain numerator;

	if first.member_id then numerator = 1;
	if in_current_measure_period eq 1 then numerator = numerator_eligible;
	/*Round to the requested number of decimals, allowing for negatives*/
	Rounded_Value = round(prm_test_value,10**(-PRM_Test_Value_Decimals));

	SAS_Format_Code = cats('comma12.',put(max(0,PRM_Test_Value_Decimals),12.));
	format comments $128.;
	comments = cat(
		"Lab test on "
		,putn(test_date,"MMDDYYs10.")
		," with result of "
		,strip(putn(Rounded_Value,SAS_Format_Code))
		,prm_test_units_desc
		);
	if in_current_measure_period eq 0 then comments = cat(
		strip(comments)
		," (not in performance year)"
		);
	keep
		member_id
		numerator
		comments
		;
	if last.member_id;
run;

proc sql;
	create table M150_out.results_&measure_name. as
	select
		denom.member_id
		,coalesce(
			lab_results.numerator
			,1 /*No test result is assumed poorly controlled*/
			) as numerator
		,lab_results.comments
		,case calculated numerator
			when 1 then &measure_end.
			else .
			end
			as comp_quality_date_actionable format = YYMMDDd10.
		,1 as denominator
	from members_denom as denom
	left join recent_hba1c as lab_results
		on denom.member_id eq lab_results.member_id
	order by denom.member_id
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

%put System Return Code = &syscc.;
