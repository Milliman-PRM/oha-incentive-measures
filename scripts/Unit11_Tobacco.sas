/*
### CODE OWNERS: Kyle Baird, Shea Parkes

### OBJECTIVE:
	Unit test the calculated quality measure so we have more feedback about
	logic changes

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

/* Libnames */
%MockLibrary(M033_Out, pollute_global=True)
%MockLibrary(M035_Out, pollute_global=True)
%MockLibrary(M150_Out, pollute_global=True)
%let M150_tmp = %MockDirectoryGetPath();
%CreateFolder(&M150_tmp.)

%let suppress_parser = True;
%let anonymize = True;
%let date_performanceyearstart = %sysfunc(mdy(1,1,2015));
%let date_latestpaid_round = %sysfunc(mdy(9,30,2015));
%let quality_metrics = oha_incentive_measures;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




/*** SETUP INPUTS ***/
data M035_out.member;
	infile
		datalines
		dsd
		delimiter = "|"
		;
	input
		member_id :$40.
		anticipated_numerator :12.
		anticipated_denominator :12.
		;
datalines;
current|1|1
former|0|1
never|0|1
new|1|1
prior_current|1|1
prior_former|0|1
cross_years_quit|0|1
quit|0|1
null_results|0|1
no_results|0|1
results_too_early|0|1
results_too_late|0|1
;
run;

data M033_out.emr_tobacco;
	infile
		datalines
		dsd
		delimiter = "|"
		;
	input
		member_id :$40.
		prm_tobacco_status_date :YYMMDD10.
		prm_tobacco_status :$32.
		;
	format prm_tobacco_status_date YYMMDDd10.;
datalines;
current|2015-02-28|Current
former|2015-03-15|Former
never|2015-07-08|Never
new|2015-01-30|Never
new|2015-04-30|Current
prior_current|2014-01-01|Current
prior_former|2014-03-25|Former
cross_years_quit|2014-12-01|Current
cross_years_quit|2015-06-13|Former
quit|2015-03-15|Current
quit|2015-09-15|Former
null_results|2015-08-20|
results_too_early|2013-09-26|Never
results_too_late|2016-01-10|Former
;
run;

/*** RUN THE PRODUCTION PROGRAM ***/
%include "%GetParentFolder(0)Prod11_Tobacco.sas" / source2;

/*** TEST OUTPUTS ***/
%CompareResults()

%put System Return Code = &syscc.;
