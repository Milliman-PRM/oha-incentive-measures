/*
### CODE OWNERS: Kyle Baird, Ben Copeland

### OBJECTIVE:
	Test the Developmental Screening measure calculation

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

/* Libnames */
%MockLibrary(oha_ref,pollute_global=true)
%MockLibrary(M035_out,pollute_global=true)
%MockLibrary(M073_out,pollute_global=true)
%MockLibrary(M150_out,pollute_global=true)
%let M150_tmp = %MockDirectoryGetPath();
%CreateFolder(&M150_tmp.)
%MockLibrary(unittest)

%let suppress_parser = True;
%let date_performanceyearstart = %sysfunc(mdy(1,1,2015));
%let date_latestpaid_round = %sysfunc(mdy(5,31,2015));
%let date_latestpaid = %sysfunc(mdy(5,28,2015));
%let quality_metrics = oha_incentive_measures;
%let empirical_elig_date_end = %sysfunc(mdy(5,31,2015));

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
dev_screening|numerator|HCPCS|96110||
run;

data 
	unittest.member (keep = member_id dob anticipated_:)
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
too_old|2010-02-28|2010-02-28|2015-05-31|0|0
too_young|2015-03-15|2015-03-15|2015-05-31|0|0
large_elig_gap|2014-02-14|2014-02-14|2014-09-30|0|0
large_elig_gap|2014-02-14|2015-01-01|2015-05-31|0|0
multiple_small_elig_gap|2013-07-01|2013-07-01|2014-07-15|0|0
multiple_small_elig_gap|2013-07-01|2014-07-30|2014-09-30|0|0
multiple_small_elig_gap|2013-07-01|2014-10-10|2015-05-31|0|0
birthday_after_data|2013-09-01|2014-09-01|2015-05-31|1|1
no_claims|2014-01-08|2014-01-08|2015-05-31|0|1
screening_after_birthday|2013-03-31|2013-03-31|2015-05-31|1|1
wrong_type_of_claim|2014-05-01|2014-05-01|2015-05-31|0|1
is_actionable|2014-12-01|2014-12-01|2015-05-31|0|1
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
		;
	format prm_fromdate YYMMDDd10.;
datalines;
too_old|2015-03-14|96110
too_young|2015-04-15|96110
large_elig_gap|2015-01-08|96110
multiple_small_elig_gap|2015-02-14|96110
birthday_after_data|2015-02-07|96110
screening_after_birthday|2014-04-15|96110
wrong_type_of_claim|2015-04-15|12345
run;

/***** RUN THE PRODUCTION PROGRAM *****/
%include "%GetParentFolder(0)Prod04_Developmental_Screening.sas" / source2;

/***** TEST OUTPUTS *****/
%let measure_name = &name_measure.; /*Duplicate this variable into what is expected for the macro.*/
%CompareResults()

data _has_actionable_date;
	set m150_out.results_&name_measure.;
	where comp_quality_date_actionable ne .;
run;
%AssertDataSetPopulated(
	_has_actionable_date,
	ReturnMessage=Actionable dates are not populated for any member
)
%put System Return Code = &syscc.;
