/*
### CODE OWNERS: Kyle Baird, Steve Gredell

### OBJECTIVE:
	Unit test the calculation of OHA hypertension so we can understand impact
	of future changes to the production code logic

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%GetParentFolder(1)Supp02_Shared_Testing.sas" / source2;

/* Libnames */
%MockLibrary(M015_out,pollute_global=true)
%MockLibrary(M033_out,pollute_global=true)
%MockLibrary(M035_out,pollute_global=true)
%MockLibrary(M073_out,pollute_global=true)
%MockLibrary(M150_out,pollute_global=true)
%let M150_tmp = %MockDirectoryGetPath();
%CreateFolder(&M150_tmp.)
%MockLibrary(unittest)

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
hypertension|denom_hypertens|CPT|hyCPT||
hypertension|denom_hypertens|ICD9CM-Diag|hyICD9||
hypertension|denom_hypertens|ICD10CM-Diag|hyICD10||
hypertension|denom_hypertens|HCPCS|hyHCP||
hypertension|denom_service|CPT|opCPT||
hypertension|denom_service|ICD9CM-Diag|opICD9||
hypertension|denom_service|ICD10CM-Diag|opICD10||
hypertension|denom_service|HCPCS|opHCP||
hypertension|denom_excl_disease|CPT|dsCPT||
hypertension|denom_excl_disease|ICD9CM-Diag|dsICD9||
hypertension|denom_excl_disease|ICD10CM-Diag|dsICD10||
hypertension|denom_excl_disease|HCPCS|dsHCP||
hypertension|denom_excl_renal|CPT|rnCPT||
hypertension|denom_excl_renal|ICD9CM-Diag|rnICD9||
hypertension|denom_excl_renal|ICD10CM-Diag|rnICD10||
hypertension|denom_excl_renal|HCPCS|rnHCP||
hypertension|denom_excl_prego1|CPT|prCPT||
hypertension|denom_excl_prego1|ICD9CM-Diag|prICD9||
hypertension|denom_excl_prego1|ICD10CM-Diag|prICD10||
hypertension|denom_excl_prego1|HCPCS|prHCP||
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
	format dob YYMMDDd10.;
datalines;
too_old|1899-12-25|0|0
too_young|2011-07-18|0|0
not_hypertensive|1975-04-01|0|0
no_op_service|1980-01-07|0|0
has_esrd|1970-03-21|0|0
is_preggers|1988-06-09|0|0
dialysis_cpt|1975-03-03|0|0
diagnosed_too_late|1959-08-20|0|0
has_ckd|1961-09-30|0|0
op_service_too_early|1970-11-01|0|0
no_claims|1950-10-12|0|0
no_bp_reading|1962-05-15|0|1
bp_too_high|1965-02-28|0|1
bp_systolic_too_high|1972-10-10|0|1
bp_diastolic_too_high|1972-10-10|0|1
bp_just_right|1968-11-15|1|1
was_preggers|1990-05-20|1|1
diagnosed_long_ago|1975-02-01|1|1
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
too_old|2015-02-03|2015-02-03|hyHCP|XXXXXXX|XXXXXXX|XXXXXXX
too_old|2015-02-14|2015-02-14|XXXXX|XXXXXXX|opICD9|XXXXXXX
too_young|2015-03-12|2015-03-12|hyCPT|opICD9|XXXXXXX|XXXXXXX
not_hypertensive|2015-04-01|2015-04-01|opCPT|XXXXXXX|XXXXXXX|XXXXXXX
no_op_service|2015-01-20|2015-01-20|XXXXX|hyICD10|XXXXXXX|XXXXXXX
has_esrd|2015-05-20|2015-05-20|opHCP|hyICD9|dsICD9|XXXXXXX
is_preggers|2015-04-03|2015-04-03|opCPT|hyICD10|XXXXXXX|XXXXXXX
is_preggers|2015-07-03|2015-07-03|XXXXX|prICD10|XXXXXXX|XXXXXXX
dialysis_cpt|2015-01-16|2015-01-16|hyHCP|XXXXXXX|XXXXXXX|XXXXXXX
dialysis_cpt|2015-07-16|2015-07-16|rnCPT|XXXXXXX|XXXXXXX|XXXXXXX
diagnosed_too_late|2015-07-29|2015-07-29|opHCP|hyICD9|XXXXXXX|XXXXXXX
has_ckd|2015-04-30|2015-04-30|XXXXX|XXXXXXX|XXXXXXX|hyICD10
has_ckd|2015-05-31|2015-05-31|opHCP|XXXXXXX|dsICD9|XXXXXXX
op_service_too_early|2014-12-06|2014-12-06|opCPT|hyICD10|XXXXXXX|XXXXXXX
no_bp_reading|2014-10-30|2014-10-30|XXXXX|hyICD9|XXXXXXX|XXXXXXX
no_bp_reading|2015-08-15|2015-08-15|XXXXX|XXXXXXX|opICD10|XXXXXXX
bp_too_high|2015-06-04|2015-06-04|opHCP|hyICD10|XXXXXXX|XXXXXXX
bp_systolic_too_high|2015-04-26|2015-04-26|hyHCP|opICD10|XXXXXXX|XXXXXXX
bp_diastolic_too_high|2015-05-01|2015-05-01|XXXXX|hyICD9|opICD9|XXXXXXX
bp_just_right|2015-01-10|2015-01-10|XXXXX|hyICD10|XXXXXXX|XXXXXXX
bp_just_right|2015-08-10|2015-08-10|opCPT|XXXXXXX|XXXXXXX|XXXXXXX
was_preggers|2013-09-25|2013-09-25|prCPT|XXXXXXX|XXXXXXX|XXXXXXX
was_preggers|2014-05-25|2014-05-25|XXXXX|hyICD9|XXXXXXX|XXXXXXX
was_preggers|2015-08-25|2015-08-25|XXXXX|opICD10|XXXXXXX|XXXXXXX
diagnosed_long_ago|2008-12-02|2008-12-02|hyCPT|XXXXXXX|XXXXXXX|XXXXXXX
diagnosed_long_ago|2015-07-02|2015-07-02|opCPT|XXXXXXX|XXXXXXX|XXXXXXX
run;

data M033_out.emr_vitals;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		member_id :$40.
		vitals_date :YYMMDD10.
		diastolic :12.
		systolic :12.
		;
datalines;
too_old|2015-03-07|85|115
too_young|2015-03-28|70|105
not_hypertensive|2015-04-01|88|118
no_op_service|2015-01-27|60|100
has_esrd|2015-07-20|85|117
is_preggers|2015-04-03|89|119
dialysis_cpt|2015-05-16|75|100
op_service_too_early|2015-01-12|40|80
bp_too_high|2015-08-04|100|150
bp_systolic_too_high|2015-04-26|99|110
bp_diastolic_too_high|2015-09-01|80|150
bp_just_right|2015-08-31|80|115
was_preggers|2015-05-05|75|115
diagnosed_long_ago|2015-07-02|70|110
run;

/***** RUN THE PRODUCTION PROGRAM *****/
%include "%GetParentFolder(0)Prod09_Hypertension.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

%put System Return Code = &syscc.;
