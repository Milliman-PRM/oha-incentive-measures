/*
### CODE OWNERS: Neil Schneider, Ben Copeland

### OBJECTIVE:
	Test the Follow-Up after Hospitalization for Mental Illness

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp02_Shared_Testing.sas" / source2;

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
%let date_latestpaid_round = %sysfunc(mdy(12,31,2015));
%let date_latestpaid = %sysfunc(mdy(12,29,2015));
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
FUH_Mental|Numerator|CPT|Proc1||
FUH_Mental|Numerator|HCPCS|Proc2||
FUH_Mental|Numerator|UBREV|Rev1||
FUH_Mental|Numerator|CPT|CPTG1|Group1|
FUH_Mental|Numerator|POS|11|Group1|
FUH_Mental|Numerator|CPT|CPTG2|Group2|
FUH_Mental|Numerator|POS|52|Group2|
FUH_Mental|Numer_rev2|UBREV|Rev2||
FUH_Mental|Numerator_TCM|CPT|TCM||
FUH_Mental|Denominator|ICD9CM-Diag|DiagA||Primary
FUH_Mental|Denominator|ICD10CM-Diag|DiagA10||Primary
FUH_Mental|denom_excl_NAC|CPT|NAC||
FUH_Mental|denom_excl_MHD|ICD9CM-Diag|DiagA||Primary
FUH_Mental|denom_excl_MHD|ICD9CM-Diag|DiagB||Primary
FUH_Mental|denom_excl_MHD|ICD10CM-Diag|DiagA10||Primary
FUH_Mental|Inpatient|UBREV|Rev3||
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
one_denom|1970-01-01|2015-01-01|2015-12-31|1|1
two_denom|1970-01-01|2015-01-01|2015-12-31|1|2
tcm_following|1970-01-01|2015-01-01|2015-12-31|1|1
group1_followup|1970-01-01|2015-01-01|2015-12-31|1|1
group2_followup|1970-01-01|2015-01-01|2015-12-31|1|1
day_of_followup|1970-01-01|2015-01-01|2015-12-31|1|1
denom_excl_NAF_MHD|1970-01-01|2015-01-01|2015-12-31|0|0
denom_excl_NAF|1970-01-01|2015-01-01|2015-12-31|0|0
denom_excl_acute|1970-01-01|2015-01-01|2015-12-31|0|0
denom_excl_elig|1970-01-01|2015-01-01|2015-03-15|0|0
denom_excl_age|2013-01-01|2015-01-01|2015-12-31|0|0
denom_excl_too_late|1970-01-01|2015-01-01|2015-12-31|0|0
one_denom_icd10|1970-01-01|2015-01-01|2015-12-31|1|1
denom_excl_NAF_MHD_icd10|1970-01-01|2015-01-01|2015-12-31|0|0
inpatient_not_found|1970-01-01|2015-01-01|2015-12-31|0|0
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
		prm_todate :YYMMDD10.
		RevCode :$4.
		hcpcs :$5.
		pos :$2.
		prm_line :$4.
		icddiag1 :$7.
		icddiag2 :$7.
		;
	format prm_fromdate YYMMDDd10. prm_todate YYMMDDd10.;
datalines;
one_denom|2015-02-01|2015-02-05|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
one_denom|2015-02-07|2015-02-07|XXXX|Proc1|XX|P32c|XXXXXXX|XXXXXXX
two_denom|2015-03-01|2015-03-04|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
two_denom|2015-06-01|2015-06-02|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
two_denom|2015-06-04|2015-06-04|Rev2|XXXXX|XX|P32c|DiagA|XXXXXXX
tcm_following|2015-02-28|2015-03-01|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
tcm_following|2015-03-30|2015-03-30|XXXX|TCM|XX|P32c|XXXXXXX|XXXXXXX
group1_followup|2015-01-01|2015-01-02|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
group1_followup|2015-01-04|2015-01-04|XXXX|CPTG1|11|P32c|XXXXXXX|XXXXXXX
group2_followup|2015-02-01|2015-02-02|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
group2_followup|2015-02-04|2015-02-04|XXXX|CPTG2|52|P32c|XXXXXXX|XXXXXXX
day_of_followup|2015-03-01|2015-03-05|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
day_of_followup|2015-03-05|2015-03-05|XXXX|Proc2|XX|P32c|XXXXXXX|XXXXXXX
denom_excl_NAF_MHD|2015-04-01|2015-04-04|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
denom_excl_NAF_MHD|2015-04-20|2015-04-20|Rev3|NAC|XX|O99|DiagB|XXXXXXX
denom_excl_NAF|2015-04-01|2015-04-01|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
denom_excl_NAF|2015-04-25|2015-04-25|Rev3|NAC|XX|O99|XXXXXXX|XXXXXXX
denom_excl_acute|2015-05-01|2015-05-04|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
denom_excl_acute|2015-05-10|2015-05-12|Rev3|XXXXX|XX|I11a|XXXXXXX|XXXXXXX
denom_excl_elig|2015-03-01|2015-03-05|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
denom_excl_elig|2015-03-06|2015-03-06|Rev3|Proc1|XX|P32c|XXXXXXX|XXXXXXX
denom_excl_age|2015-07-01|2015-07-02|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
denom_excl_age|2015-07-03|2015-07-03|Rev3|Proc2|XX|P32c|XXXXXXX|XXXXXXX
denom_excl_too_late|2015-12-15|2015-12-17|Rev3|XXXXX|XX|I11a|DiagA|XXXXXXX
denom_excl_too_late|2015-12-20|2015-12-20|Rev1|XXXXX|XX|P32c|XXXXXXX|XXXXXXX
one_denom_icd10|2015-02-01|2015-02-05|Rev3|XXXXX|XX|I11a|DiagA10|XXXXXXX
one_denom_icd10|2015-02-07|2015-02-07|XXXX|Proc1|XX|P32c|XXXXXXX|XXXXXXX
denom_excl_NAF_MHD_icd10|2015-04-01|2015-04-04|Rev3|XXXXX|XX|I11a|DiagA10|XXXXXXX
denom_excl_NAF_MHD_icd10|2015-04-20|2015-04-20|Rev3|NAC|XX|O99|DiagA10|XXXXXXX
inpatient_not_found|2015-05-03|2015-05-08|Rev2|XXXXX|XX|O99|DiagA10|XXXXXXX
run;

/***** RUN THE PRODUCTION PROGRAM *****/
%include "%GetParentFolder(0)Prod07_follow_up_mental_hospitalization.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

%put System Return Code = &syscc.;
