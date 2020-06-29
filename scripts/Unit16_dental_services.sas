/*
### CODE OWNERS: Ben Copeland, Chas Busenburg

### OBJECTIVE:
	Test the Dental Services Utilization measures

### DEVELOPER NOTES:
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

%let Suppress_Parser = True;
%let DATE_PERFORMANCEYEARSTART = %sysfunc(mdy(1,1,2020));
%let Date_LatestPaid_Round = %sysfunc(mdy(2,28,21));
%let date_latestpaid = %sysfunc(mdy(2,15,21));
%let QUALITY_METRICS = OHA_INCENTIVE_MEASURES;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/


/**** SETUP MOCKING ****/

%SetupMockLibraries()
options set=OHA_INCENTIVE_MEASURES_PATHREF "%sysfunc(pathname(oha_ref))";

data oha_ref.oha_codes;
	infile datalines delimiter = '~' missover dsd;
	input
		Measure :$24.
		Component :$32.
		CodeSystem :$16.
		Code :$16.
		Grouping_ID :$32.
		Diag_Type :$16.
		;
datalines;
dental_services~diagnostic_dental~CDT~DIAGX~~
dental_services~preventive_dental~CDT~PREVX~~
dental_services~dental_treatment~CDT~TREAT~~
;
run;

data oha_ref.dental_taxonomy;
	infile datalines delimiter = '~' missover dsd;
	input
		taxonomy_code :$10.
		;
datalines;
DENTAL_TAX
;
run;


data M030_Out.InpDental;
	infile datalines delimiter = '~' missover dsd;
	input
		Member_ID :$40.
		fromdate :YYMMDD10.
		providerid :$40.
		HCPCS :$5.
		;
	format
		fromdate YYMMDD10.
	;
datalines;
prev_1_to_5~2020-05-15~dental_prv~PREVX
prev_1_to_5_non_dental_prv~2020-05-15~non_dental_prv~PREVX
prev_1_to_5_wrong_year_claim~2019-05-15~dental_prv~PREVX
prev_6_to_14~2020-05-15~dental_prv~PREVX
treat_1_to_5~2020-05-15~dental_prv~TREAT
treat_6_to_14~2020-05-15~dental_prv~TREAT
diag_26_to_65~2020-05-15~dental_prv~DIAGX
multiple_services_26_to_65~2020-05-15~dental_prv~DIAGX
multiple_services_26_to_65~2020-05-15~dental_prv~PREVX
multiple_services_26_to_65~2020-05-15~dental_prv~TREAT
;
run;


data M025_out.providers;
	infile datalines delimiter = '~' missover dsd;
	input
		prv_id :$40.
		prv_taxonomy_cd :$10.
		;
datalines;
dental_prv~DENTAL_TAX
non_dental_prv~OTHER_TAX
;
run;

data M150_Tmp.member;
	infile datalines delimiter = '~';
	input
		Member_ID :$40.
		DOB :YYMMDD10.
	;
	format DOB :YYMMDDd10.;
datalines;
prev_1_to_5~2017-01-01
prev_1_to_5_no_cont_elig~2017-01-01
prev_1_to_5_non_dental_prv~2017-01-01
prev_1_to_5_wrong_year_claim~2017-01-01
prev_6_to_14~2011-01-01
treat_1_to_5~2017-01-01
treat_6_to_14~2011-01-01
diag_26_to_65~1980-01-01
multiple_services_26_to_65~1980-01-01
;
run;

data member_time;
	infile datalines delimiter = '~';
	input
		Member_ID	 :$40.
		date_start	 :YYMMDD10.
		date_end	 :YYMMDD10.
		;
	format date_start date_end :YYMMDDd10.;
datalines;
prev_1_to_5~2020-01-01~2020-3-31
prev_1_to_5~2020-04-01~2020-12-31
prev_1_to_5_no_cont_elig~2020-01-01~2020-3-31
prev_1_to_5_no_cont_elig~2020-06-01~2020-8-31
prev_1_to_5_no_cont_elig~2020-11-01~2020-12-31
prev_1_to_5_non_dental_prv~2020-01-01~2020-12-31
prev_1_to_5_wrong_year_claim~2020-01-01~2020-12-31
prev_6_to_14~2020-01-01~2020-12-31
treat_1_to_5~2020-01-01~2020-12-31
treat_6_to_14~2020-01-01~2020-12-31
diag_26_to_65~2020-01-01~2020-12-31
multiple_services_26_to_65~2020-01-01~2020-12-31
;
run;

data expected_results;
	infile datalines delimiter = '~';
	input
		member_id :$40.
		measure :$32.
		anticipated_numerator :12.
		anticipated_denominator :12.
	;
datalines;
prev_1_to_5~any_dental_1_to_5~1~1
prev_1_to_5~diag_dental_1_to_5~0~1
prev_1_to_5~prev_dental_1_to_5~1~1
prev_1_to_5~treat_dental_1_to_5~0~1
prev_1_to_5_non_dental_prv~any_dental_1_to_5~0~1
prev_1_to_5_non_dental_prv~diag_dental_1_to_5~0~1
prev_1_to_5_non_dental_prv~prev_dental_1_to_5~0~1
prev_1_to_5_non_dental_prv~treat_dental_1_to_5~0~1
prev_1_to_5_wrong_year_claim~any_dental_1_to_5~0~1
prev_1_to_5_wrong_year_claim~diag_dental_1_to_5~0~1
prev_1_to_5_wrong_year_claim~prev_dental_1_to_5~0~1
prev_1_to_5_wrong_year_claim~treat_dental_1_to_5~0~1
prev_6_to_14~any_dental_6_to_14~1~1
prev_6_to_14~diag_dental_6_to_14~0~1
prev_6_to_14~prev_dental_6_to_14~1~1
prev_6_to_14~treat_dental_6_to_14~0~1
treat_1_to_5~any_dental_1_to_5~1~1
treat_1_to_5~diag_dental_1_to_5~0~1
treat_1_to_5~prev_dental_1_to_5~0~1
treat_1_to_5~treat_dental_1_to_5~1~1
treat_6_to_14~any_dental_6_to_14~1~1
treat_6_to_14~diag_dental_6_to_14~0~1
treat_6_to_14~prev_dental_6_to_14~0~1
treat_6_to_14~treat_dental_6_to_14~1~1
diag_26_to_65~any_dental_26_to_65~1~1
diag_26_to_65~diag_dental_26_to_65~1~1
diag_26_to_65~prev_dental_26_to_65~0~1
diag_26_to_65~treat_dental_26_to_65~0~1
multiple_services_26_to_65~any_dental_26_to_65~1~1
multiple_services_26_to_65~diag_dental_26_to_65~1~1
multiple_services_26_to_65~prev_dental_26_to_65~1~1
multiple_services_26_to_65~treat_dental_26_to_65~1~1
;
run;

proc sort
	data = member_time
	out = M150_Tmp.member_time
	;
	by
		Member_ID
		date_end
	;
	run
	;



/**** TEST WITH CLEAN ELIG END ****/

%let empirical_elig_date_end = %sysfunc(mdy(12,31,2020));
%include "%GetParentFolder(0)\prod16_dental_services.sas" / source2;

proc sql;
	create table mismatches
	as select
		actual.member_id
		,actual.measure
		,actual.denominator
		,actual.numerator
		,expected.anticipated_denominator
		,expected.anticipated_numerator
	from measure_presentation_prep as actual
	full outer join expected_results as expected on
		actual.member_id eq expected.member_id
		and actual.measure eq expected.measure
	where
		numerator ne anticipated_numerator
		or denominator ne anticipated_denominator
	;
quit;
%AssertDataSetNotPopulated(mismatches, ReturnMessage=The &Measure_Name. results are not as expected.  Aborting...);


%put System Return Code = &syscc.;
