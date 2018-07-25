
/*
### CODE OWNERS: Chas Busenburg, Ben Copeland

### OBJECTIVE:
Test the ED Visits with mental health measure calculation

### DEVELOPER NOTES:
<none>
*/

%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

/* Libnames */
%MockLibrary(oha_ref,pollute_global=true)
options set=OHA_INCENTIVE_MEASURES_PATHREF "%sysfunc(pathname(oha_ref))";
%MockLibrary(M035_out,pollute_global=true)
    %MockLibrary(M073_out,pollute_global=true)
    %MockLibrary(M150_out,pollute_global=true)
    %let M130_out = %MockDirectoryGetPath();
%CreateFolder(&M130_out.)
    %let M150_tmp = %MockDirectoryGetPath();
%CreateFolder(&M150_tmp.)
    %MockLibrary(unittest)

    %let suppress_parser = True;
%let date_performanceyearstart = %sysfunc(mdy(1,1,2015));
%let date_latestpaid_round = %sysfunc(mdy(7,31,2015));
%let quality_metrics = oha_incentive_measures;

%let rand_seed = 42;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/

/***** SETUP INPUTS *****/
data oha_ref.oha_codes;
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
ED_Visits_MI|Denominator|ICD10CM-Diag|DIAG-10||
ED_Visits_MI|Denominator|ICD9CM-Diag|DIAG-9||
run;

data
	M035_out.member
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
		;
	format
		dob YYMMDDd10.
		elig_month YYMMDDd10.
		;
datalines;
diag_denom|1920-07-01
diag_denom|1920-07-01
excl_one_visit|1920-07-01
excl_one_visit|1920-07-01
excl_same_date|1920-07-01
excl_same_date|1920-07-01
excl_too_old|1920-07-01
excl_too_old|1920-07-01
excl_age_young|2000-07-01
excl_age_young|2000-07-01
diag_denom|1920-07-01
diag_denom|1920-07-01
run;

data M150_out.results_ed_visits;
  infile
    datalines
    dsd
    truncover
    delimiter = "|"
    ;
  input
    member_id :$40.
    numerator :BEST12.
    denominator :BEST12.
    comments :$128.
    comp_quality_date_actionable :YYMMDD10.
	;
datalines;
diag_denom|2|0.002|Recent Visit(s):  02/15/2015, 02/14/2015|
excl_one_visit|1|0.002|Recent Visit(s): 02/14/2015|
excl_same_date|2|0.002|Recent Visit(s):  02/14/2015, 02/14/2015|
excl_too_old|2|0.002|Recent Visit(s):  02/15/2000, 02/14/2000|
excl_age_young|2|0.002|Recent Visit(s):  02/15/2015, 02/14/2015|

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
		prm_line :$4.
		claimID :$60.
		hcpcs :$5.
		RevCode :$4.
		POS :$2.
		icddiag1 :$7.
		icddiag2 :$7.
		icddiag3 :$7.
		prm_denied_YN :$1.
		;
	format prm_fromdate YYMMDDd10.;
datalines;
diag_denom|2015-02-14|O11a|1|XXXXX|XXXX|XX|DIAG-10|XXXXXXX|XXXXXXX|N
diag_denom|2015-02-15|O11a|2|XXXXX|XXXX|XX|XXXXXXX|DIAG-9|XXXXXXX|N
excl_one_visit|2015-02-14|O11a|1|XXXXX|XXXX|XX|DIAG-10|XXXXXXX|XXXXXXX|N
excl_same_date|2015-02-14|O11a|2|XXXXX|XXXX|XX|DIAG-9|XXXXXXX|XXXXXXX|N
excl_same_date|2015-02-14|O11a|1|XXXXX|XXXX|XX|DIAG-10|XXXXXXX|XXXXXXX|N
excl_too_old|2000-02-15|O11a|2|XXXXX|XXXX|XX|DIAG-9|XXXXXXX|XXXXXXX|N
excl_too_old|2000-02-14|O11a|1|XXXXX|XXXX|XX|DIAG-10|XXXXXXX|XXXXXXX|N
excl_age_young|2015-02-15|O11a|2|XXXXX|XXXX|XX|DIAG-9|XXXXXXX|XXXXXXX|N
excl_age_young|2015-02-14|O11a|1|XXXXX|XXXX|XX|DIAG-10|XXXXXXX|XXXXXXX|N
run;




/***** RUN THE PRODUCTION PROGRAM *****/
%include "%GetParentFolder(0)Prod13_ED_Visits_Mental_Illness.sas" / source2;

data M150_tmp.expected_ed_mi;
  infile
    datalines
    dsd
    truncover
    delimiter = "|"
    ;
  input
    member_id :$40.
    anticipated_numerator :BEST12.
    anticipated_denominator :BEST12.
    comments :$128.
    comp_quality_date_actionable :YYMMDD10.
	;
datalines;
diag_denom|2|0.002|Recent Visit(s):  02/15/2015, 02/14/2015|
run;

/***** TEST OUTPUTS *****/
%CompareResults(dset_expected=m150_tmp.expected_ed_mi)

%put System Return Code = &syscc.;
