/*
### CODE OWNERS: Kyle Baird, Steve Gredell

### OBJECTIVE:
	Unit test the calculation of diabetes HbA1c quality measure
	so we can better understand how future changes to logic
	affect results

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp02_Shared_Testing.sas" / source2;

/* Libnames */
%MockLibrary(M015_out,pollute_global=true)
%MockLibrary(M033_out,pollute_global=true)
%MockLibrary(M035_out,pollute_global=true)
%MockLibrary(M073_out,pollute_global=true)
%MockLibrary(M150_out,pollute_global=true)
%let M150_tmp = %MockDirectoryGetPath();
%CreateFolder(&M150_tmp.)

%let suppress_parser = True;
%let anonymize = True;
%let date_performanceyearstart = %sysfunc(mdy(1,1,2015));
%let date_latestpaid_round = %sysfunc(mdy(9,30,2015));
%let quality_metrics = oha_incentive_measures;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




/***** SETUP INPUTS *****/
data M015_out.oha_codes;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		measure :$24.
		component :$32.
		codesystem :$16.
		code :$16.
		grouping_id :$32.
		diag_type :$16.
		;
datalines;
diabetes_hba1c|denom_diabetes|HCPCS|dbHCP||
diabetes_hba1c|denom_diabetes|CPT|dbCPT||
diabetes_hba1c|denom_diabetes|ICD9CM-Diag|dbICD09||
diabetes_hba1c|denom_diabetes|ICD10CM-Diag|dbICD10||
diabetes_hba1c|denom_service|HCPCS|opHCP||
diabetes_hba1c|denom_service|CPT|opCPT||
diabetes_hba1c|denom_service|ICD9CM-Diag|opICD09||
diabetes_hba1c|denom_service|ICD10CM-Diag|opICD10||
run;

data M035_out.member;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		member_id :$40.
		dob :YYMMDD10.
		anticipated_numerator :12.
		anticipated_denominator :12.
		;
datalines;
too_old|1898-10-31|0|0
too_young|2002-01-05|0|0
not_diabetic|1948-02-14|0|0
no_op_service|1960-01-01|0|0
op_service_too_early|1965-04-10|0|0
a1c_too_low|1970-05-24|0|1
a1c_too_high|1980-12-21|1|1
wrong_units|1981-02-28|1|1
a1c_present_but_missing|1962-08-20|1|1
no_a1c_value|1971-09-16|1|1
a1c_reading_too_early|1969-07-04|1|1
run;

data M073_out.outclaims_prm;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		member_id :$40.
		prm_fromdate :YYMMDD10.
		prm_todate :YYMMDD10.
		hcpcs :$5.
		icddiag1 :$7.
		icddiag2 :$7.
		icddiag3 :$7.
		;
	format
		prm_fromdate YYMMDDd10.
		prm_todate YYMMDDd10.
		;
datalines;
too_old|2015-04-20|2015-04-20|dbHCP|opICD10||
too_young|2015-06-10|2015-06-10|dbCPT|XXXXXXX|opICD09|
not_diabetic|2015-01-08|2015-01-08|opCPT|XXXXXXX||
no_op_service|2015-03-15|2015-03-15|XXXXX|dbICD10||
op_service_too_early|2014-09-18|2014-09-18|opHCP|XXXXXXX|XXXXXXX|XXXXXXX
op_service_too_early|2014-09-18|2014-09-18|dbHCP|XXXXXXX||
a1c_too_low|2013-12-26|2013-12-26|dbCPT|XXXXXXX||
a1c_too_low|2015-06-30|2015-06-30|opCPT|XXXXXXX||
a1c_too_high|2012-05-10|2012-05-10|XXXXX|dbICD10|XXXXXXX|XXXXXXX
a1c_too_high|2015-07-18|2015-07-18|opHCP|XXXXXXX|XXXXXXX|XXXXXXX
wrong_units|2012-11-18|2012-11-18|XXXXX|dbICD09||
wrong_units|2015-08-18|2015-08-18|XXXXX|XXXXXXX|XXXXXXX|opICD09
a1c_present_but_missing|2015-01-25|2015-01-25|opHCP|XXXXXXX|XXXXXXX|dbICD09
no_a1c_value|2014-09-10|2014-09-10|dbCPT|XXXXXXX||
no_a1c_value|2015-09-10|2015-09-10|opCPT|XXXXXXX||
a1c_reading_too_early|2014-07-10|2014-07-10|XXXXX|XXXXXXX|dbICD09|XXXXXXX
a1c_reading_too_early|2014-08-10|2014-08-10|XXXXX|opICD09||
a1c_reading_too_early|2015-02-10|2015-02-10|opHCP|XXXXXXX||
run;

data M033_out.emr_labs;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		member_id :$40.
		test_date :YYMMDD10.
		prm_test :$11.
		prm_test_item :$12.
		prm_test_value :best12.
		prm_test_value_decimals :best12.
		prm_test_units_desc :$8.
		;
	format test_date YYMMDDd10.;
datalines;
too_old|2015-04-20|Hemoglobin|A1c|5|1|%
too_young|2015-07-31|Hemoglobin|A1c|10|1|%
no_op_service|2015-04-01|Hemoglobin|A1c|15|1|%
op_service_too_early|2015-03-09|Hemoglobin|A1c|8|1|%
wrong_units|2015-08-25|Hemoglobin|A1c|4|1|g/mL
a1c_too_low|2015-07-10|Hemoglobin|A1c|6|1|%
a1c_too_high|2015-07-20|Hemoglobin|A1c|12|1|%
a1c_present_but_missing|2015-02-14|Hemoglobin|A1c||
a1c_reading_too_early|2014-08-10|Hemoglobin|A1c|6|1|%
run;

/***** RUN THE PRODUCTION PROGRAM *****/
%include "%GetParentFolder(0)Prod10_Diabetes_HbA1c.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

%put System Return Code = &syscc.;
