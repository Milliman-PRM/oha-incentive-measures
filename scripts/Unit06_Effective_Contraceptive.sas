/*
### CODE OWNERS: Ben Copeland, Neil Schneider

### OBJECTIVE:
	Test the Effective Contraceptive Use measure calculation

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp02_Shared_Testing.sas" / source2;

/* Libnames */
%MockLibrary(oha_ref,pollute_global=true)
options set=OHA_INCENTIVE_MEASURES_PATHREF "%sysfunc(pathname(oha_ref))";
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
%let rx_claims_exist = YES;

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
eff_contra|numerator_cpthcpcs|CPT|CPTA||
eff_contra|numerator_cpthcpcs|HCPCS|HCPCA||
eff_contra|numerator_icddiag|ICD9CM-Diag|DIAGA||
eff_contra|numerator_icdproc|ICD9CM-Proc|PROCA||
eff_contra|numerator_icddiag|ICD10CM-Diag|DIAGA10||
eff_contra|numerator_icdproc|ICD10CM-Proc|PROCA10||
eff_contra|numerator_NDC|NDC|NDCA||
eff_contra|numer_exclusion|ICD9CM-Diag|PREGO9||
eff_contra|numer_exclusion|CPT|PREGO||
eff_contra|denom_exclusion|ICD9CM-Diag|EXDIAGA||
eff_contra|denom_exclusion|ICD9CM-Proc|EXPROCA||
eff_contra|denom_exclusion|ICD10CM-Diag|XDIAGA0||
eff_contra|denom_exclusion|ICD10CM-Proc|XPROCA0||
eff_contra|denom_exclusion|CPT|XCPTA||
run;

proc sql;
	create table M015_out.hcpcs_descr as
	select distinct
		code as hcpcs
		,cat(strip(code)," (description)") as hcpcs_desc length = 256 format = $256.
	from oha_ref.oha_codes
	where upcase(codesystem) ne "NDC"
	;
quit;

data 
	unittest.member (keep = member_id dob gender anticipated_:)
	M035_out.member_time (keep = member_id date_start date_end)
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
		gender: :$1.
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
too_old|1960-02-28|F|2010-02-28|2015-05-31|0|0
too_young|2005-03-15|F|2015-01-01|2015-05-31|0|0
large_elig_gap|1990-02-14|F|2015-01-01|2015-01-31|0|0
large_elig_gap|1990-02-14|F|2015-05-01|2015-05-31|0|0
multiple_small_elig_gap|1980-07-01|F|2015-01-01|2015-01-28|0|0
multiple_small_elig_gap|1980-07-01|F|2015-02-01|2015-03-15|0|0
multiple_small_elig_gap|1980-07-01|F|2015-04-01|2015-05-31|0|0
all_good|1975-09-01|F|2014-09-01|2015-05-31|1|1
med_only|1975-09-01|F|2014-09-01|2015-05-31|1|1
rx_only|1975-09-01|F|2014-09-01|2015-05-31|1|1
denom_excl|1970-01-08|F|2014-01-08|2015-05-31|0|0
prego_not_excl|1980-03-31|F|2013-03-31|2015-05-31|1|1
prego_excl|1980-05-01|F|2014-05-01|2015-05-31|0|0
not_compliant|1980-03-01|F|2014-09-01|2015-05-31|0|1
male|1980-03-01|M|2014-09-01|2015-05-31|0|0
all_good_icd10|1975-09-01|F|2014-09-01|2015-05-31|1|1
denom_excl_icd10|1970-01-08|F|2014-01-08|2015-05-31|0|0
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
	,ReturnMessage=Testing member table does not simulate expected set up.
	)

data M073_out.outclaims_prm;
	call streaminit(&rand_seed.);
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	format sequencenumber best12.;
	sequencenumber = _n_;
	input
		member_id :$40.
		prm_fromdate :YYMMDD10.
		hcpcs :$5.
		icddiag1 :$7.
		icdproc1 :$7.
		icdversion :$2.
		;
	format prm_fromdate YYMMDDd10.;
	format claimid $64.;
	claimid = catx("_",member_id,putn(prm_fromdate,"YYMMDDn8."));
	format linenum $3.;
	linenum = "001";
	format paiddate YYMMDDd10.;
	paiddate = sum(prm_fromdate,rand("poisson",7));
	prm_costs = rand("exponential") * 420;
datalines;
too_old|2015-03-14|CPTA|XXXXXXX|XXXXXXX|09
too_young|2015-04-15|HCPCA|XXXXXXX|XXXXXXX|09
large_elig_gap|2015-01-08|XXXXX|DIAGA|XXXXXXX|09
multiple_small_elig_gap|2015-02-14|XXXXX|XXXXXXX|PROCA|09
all_good|2015-02-07|CPTA|XXXXXXX|XXXXXXX|09
med_only|2015-02-07|HCPCA|XXXXXXX|XXXXXXX|09
denom_excl|2014-02-07|XCPTA|XXXXXXX|XXXXXXX|09
denom_excl|2015-02-07|XXXXX|DIAGA|XXXXXXX|09
prego_not_excl|2015-01-05|PREGO|XXXXXXX|XXXXXXX|09
prego_not_excl|2015-02-07|XXXXX|XXXXXXX|PROCA|09
prego_excl|2015-02-07|PREGO|XXXXXXX|XXXXXXX|09
all_good_icd10|2015-02-07|XXXXX|XXXXXXX|PROCA10|10
denom_excl_icd10|2014-02-07|XXXXX|XDIAGA0|XXXXXXX|10
denom_excl_icd10|2015-02-07|XXXXX|DIAGA|XXXXXXX|09
run;

data M073_out.outpharmacy_prm;
	format sequencenumber best12.;
	sequencenumber = _n_;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		member_id :$40.
		prm_fromdate :YYMMDD10.
		ndc :$11.
		prm_productname :$128.
		;
	format prm_fromdate YYMMDDd10.;
	format claimid $64.;
	claimid = catx("_",member_id,putn(prm_fromdate,"YYMMDDn8."));
	format paiddate YYMMDDd10.;
	paiddate = sum(prm_fromdate,rand("poisson",7));
	prm_costs = rand("exponential") * 42;
datalines;
all_good|2015-03-14|NDCA|my_contraceptive
rx_only|2015-04-15|NDCA|my_contraceptive
run;

/***** RUN THE PRODUCTION PROGRAM *****/
%include "%GetParentFolder(0)Prod06_Effective_Contraceptive.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

/***** RE-TEST BY DROPPING RX CLAIMS *****/
%let rx_claims_exist = No;
%MockLibrary(M035_out,pollute_global=true) /*We will need to update our anticipated_numerator for certain member(s)*/
%MockLibrary(M073_out,pollute_global=true)
%MockLibrary(M150_out,pollute_global=true) /*Reset a new library for outputs so nothing conflicts.*/

data M035_out.member;
	set M150_tmp.member;
	if upcase(member_id) eq "RX_ONLY" then anticipated_numerator = 0;
run;

data M035_out.member_time;
	set M150_tmp.member_time;
run;

/*Pass over ONLY the medical claims table.*/
data M073_out.outclaims_prm;
	set M150_tmp.outclaims_prm;
run;

/*Set a new location for caching so nothing conflicts.*/
%let M150_tmp = %MockDirectoryGetPath();
%CreateFolder(&M150_tmp.)

/***** RUN THE PRODUCTION PROGRAM *****/
%include "%GetParentFolder(0)Prod06_Effective_Contraceptive.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

%put System Return Code = &syscc.;
