/*
### CODE OWNERS: Kyle Baird, Ben Copeland

### OBJECTIVE:
	Test the Colorectal Cancer Screening measure calculation

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

/* Libnames */
%MockLibrary(M015_out,pollute_global=true)
%MockLibrary(M035_out,pollute_global=true)
%MockLibrary(M073_out,pollute_global=true)
%MockLibrary(M150_out,pollute_global=true)
%let M150_tmp = %MockDirectoryGetPath();
%CreateFolder(&M150_tmp.)
%MockLibrary(unittest)

%let suppress_parser = True;
%let date_performanceyearstart = %sysfunc(mdy(1,1,2015));
%let date_latestpaid_round = %sysfunc(mdy(5,31,2015));
%let quality_metrics = oha_incentive_measures;
%let empirical_elig_date_end = %sysfunc(mdy(5,31,2015));

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
crc_screening|denom_exclusion|CPT|exCPT||
crc_screening|denom_exclusion|HCPCS|exHCP||
crc_screening|denom_exclusion|ICD9CM-Diag|exDiag||
crc_screening|denom_exclusion|ICD9CM-Proc|exProc||
crc_screening|denom_exclusion|ICD10CM-Diag|exDiag0||
crc_screening|denom_exclusion|ICD10CM-Proc|exProc0||
crc_screening|Numer_FOBT|CPT|FOBT||
crc_screening|Numer_FOBT|HCPCS|FOBT||
crc_screening|Numer_FOBT|ICD9CM-Diag|FOBT||
crc_screening|Numer_FOBT|ICD9CM-Proc|FOBT||
crc_screening|Numer_FOBT|ICD10CM-Diag|FOBT10||
crc_screening|Numer_FOBT|ICD10CM-Proc|FOBT10||
crc_screening|Numer_FlexSig|CPT|FlxSg||
crc_screening|Numer_FlexSig|HCPCS|FlxSg||
crc_screening|Numer_FlexSig|ICD9CM-Diag|FlxSg||
crc_screening|Numer_FlexSig|ICD9CM-Proc|FlxSg||
crc_screening|Numer_FlexSig|ICD10CM-Diag|FlxSg10||
crc_screening|Numer_FlexSig|ICD10CM-Proc|FlxSg10||
crc_screening|Numer_Colo|CPT|Colo||
crc_screening|Numer_Colo|HCPCS|Colo||
crc_screening|Numer_Colo|ICD9CM-Diag|Colo||
crc_screening|Numer_Colo|ICD9CM-Proc|Colo||
crc_screening|Numer_Colo|ICD10CM-Diag|Colo10||
crc_screening|Numer_Colo|ICD10CM-Proc|Colo10||
crc_screening|Numer_CT|CPT|CT10||
crc_screening|Numer_FIT|CPT|FIT10||
crc_screening|Numer_FIT|HCPCS|FIT10||
run;

data
	M035_out.member_time (keep = member_id date_:)
	unittest.member (keep = member_id dob anticipated_:)
	;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		member_id :$40.
		dob :YYMMDD10.
		date_start :YYMMDD10.
		date_end :YYMMDD10.
		anticipated_numerator :12.
		anticipated_denominator :12.
		;
	format 
		dob YYMMDDd10.
		date_: YYMMDDd10.
		;
datalines;
too_old|1920-07-01|2014-01-01|2014-12-31|0|0
too_old|1920-07-01|2015-01-01|2015-05-31|0|0
too_young|1990-07-01|2014-01-01|2014-12-31|0|0
too_young|1990-07-01|2015-01-01|2015-05-31|0|0
not_elig_on_anchor|1945-01-01|2014-01-01|2014-12-31|0|0
no_claims|1950-12-25|2014-01-01|2015-05-31|0|1
gaps_in_elig|1952-07-04|2014-01-01|2014-06-30|0|0
gaps_in_elig|1952-07-04|2014-11-01|2015-05-31|0|0
small_elig_gap|1960-01-01|2014-01-01|2014-12-31|1|1
small_elig_gap|1960-01-01|2015-02-01|2015-05-31|1|1
fobt_prior_year|1958-11-11|2014-01-01|2015-05-31|0|1
really_old_colonoscopy|1941-12-07|2014-02-01|2015-05-31|0|1
multiple_elig_gaps|1948-07-31|2014-01-01|2014-06-30|0|0
multiple_elig_gaps|1948-07-31|2014-07-07|2014-10-31|0|0
multiple_elig_gaps|1948-07-31|2014-11-07|2015-05-31|0|0
found_by_hcpcs|1951-10-04|2014-01-01|2015-05-31|1|1
found_by_cpt|1951-10-04|2014-01-01|2015-05-31|1|1
found_by_diag|1951-10-04|2014-01-01|2015-05-31|1|1
found_by_proc|1951-10-04|2014-01-01|2015-05-31|1|1
denom_excluded_claim_cpt|1955-04-28|2014-01-01|2015-05-31|0|0
denom_excluded_claim_diag|1955-04-28|2014-01-01|2015-05-31|0|0
denom_excluded_claim_proc|1955-04-28|2014-01-01|2015-05-31|0|0
found_by_diag_icd10|1951-10-04|2014-01-01|2015-05-31|1|1
found_by_proc_icd10|1951-10-04|2014-01-01|2015-05-31|1|1
denom_excluded_claim_diag_icd10|1955-04-28|2014-01-01|2015-05-31|0|0
denom_excluded_claim_proc_icd10|1955-04-28|2014-01-01|2015-05-31|0|0
had_CT_claim|1952-08-01|2014-01-01|2015-05-31|1|1
had_FIT_claim|1950-02-28|2014-01-01|2015-05-31|1|1
run;

proc sql;
	create table M035_out.member as
	select distinct
		*
	from unittest.member
	;
quit;
%AssertNoDuplicates(
	M035_out.member
	,member_id
	,ReturnMessage=Member table not set up as expected.
	)

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
		hcpcs :$5.
		icddiag1 :$7.
		icddiag2 :$7.
		icddiag3 :$7.
		icdproc1 :$7.
		icdproc2 :$7.
		icdproc3 :$7.
		;
	format prm_fromdate YYMMDDd10.;
datalines;
too_old|2015-02-14|XXXXX|XXXXXXX|Colo|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
too_young|2015-02-14|XXXXX|XXXXXXX|XXXXXXX|XXXXXXX|Colo|XXXXXXX|XXXXXXX
not_elig_on_anchor|2015-03-31|FlxSg|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
gaps_in_elig|2014-12-20|XXXXX|FlxSg|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
small_elig_gap|2015-04-15|XXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|FOBT|XXXXXXX
fobt_prior_year|2014-09-30|FOBT|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
really_old_colonoscopy|2000-08-20|XXXXX|XXXXXXX|XXXXXXX|Colo|XXXXXXX|XXXXXXX|XXXXXXX
multiple_elig_gaps|2014-05-15|FlxSg|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
found_by_hcpcs|2015-01-15|FOBT|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
found_by_cpt|2015-01-31|Colo|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
found_by_diag|2015-02-15|XXXXX|XXXXXXX|XXXXXXX|FlxSg|XXXXXXX|XXXXXXX|XXXXXXX
found_by_proc|2015-05-15|XXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|FOBT|XXXXXXX
denom_excluded_claim_cpt|2012-01-30|exCPT|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
denom_excluded_claim_cpt|2015-01-30|XXXXX|XXXXXXX|FOBT|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
denom_excluded_claim_diag|2012-01-30|XXXXX|exDiag|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
denom_excluded_claim_diag|2015-01-30|XXXXX|XXXXXXX|FOBT|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
denom_excluded_claim_proc|2012-01-30|XXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|exProc
denom_excluded_claim_proc|2015-01-30|XXXXX|XXXXXXX|FOBT|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
found_by_diag_icd10|2015-02-15|XXXXX|XXXXXXX|XXXXXXX|FlxSg10|XXXXXXX|XXXXXXX|XXXXXXX
found_by_proc_icd10|2015-05-15|XXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|FOBT10|XXXXXXX
denom_excluded_claim_diag_icd10|2012-01-30|XXXXX|exDiag0|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
denom_excluded_claim_diag_icd10|2015-01-30|XXXXX|XXXXXXX|FOBT10|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
denom_excluded_claim_proc_icd10|2012-01-30|XXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|exProc0
denom_excluded_claim_proc_icd10|2015-01-30|XXXXX|XXXXXXX|FOBT10|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
had_CT_claim|2013-08-15|CT10|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
had_FIT_claim|2015-02-12|FIT10|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX|XXXXXXX
run;

/***** RUN THE PRODUCTION PROGRAM *****/
%include "%GetParentFolder(0)Prod03_Colorectal_Cancer_Screening.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

%put System Return Code = &syscc.;
