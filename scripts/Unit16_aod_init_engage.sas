/*
### CODE OWNERS: Chas Busenburg

### OBJECTIVE:
	Tes the Initiation and engagement of Alcohol and Drug abuse measure

### DEVELOPER NOTES:
    Must have access to compiled reference data, such as by running
    `compile_reference_data_locally.bat` or by running through `run_tests.bat`
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

%let Suppress_Parser = True;
%let DATE_PERFORMANCEYEARSTART = %sysfunc(mdy(1,1,2014));
%let Date_LatestPaid_Round = %sysfunc(mdy(2,28,15));
%let date_latestpaid = %sysfunc(mdy(2,15,15));
%let QUALITY_METRICS = OHA_INCENTIVE_MEASURES;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/


/**** SETUP MOCKING ****/

%SetupMockLibraries()

data M150_Tmp.member;
	infile datalines delimiter='~';
	input
		member_id :$40.
		DOB: :YYMMDD10.
		anticipated_numerator :12.
		anticipated_denominator :12.
		;
	format DOB :YYMMDDd10.;
datalines;
/* insert member datalines here */
;
run;

data member_time;
	infile datalines delimiter='~';
	input
		member_id     :$40.
		date_start     :YYMMDD10.
		date_end     :YYMMDD10.
		;
	format date        :YYMMDDd10.;
datalines;
/* insert member_time datalines here */
;
run;

data M150_Tmp.outpharmacy_prm;
    infile datalines delimiter = '~';
    input
        member_id         :$40.
        prm_fromdate    :YYMMDD10.
        NDC             :$20.
        ;
    format prm_fromdate :YYMMDDd10.;
datalines;
/* insert outpharmcy datalines here */
;
run;

data M150_Tmp.outclaims_prm;
    infile datalines delimiter = '~' dsd;
    input
        Member_ID         :$40.
        prm_fromdate    :YYMMDD10.
        HCPCS             :$20.
        ICDDiag1         :$7.
        ICDDiag2         :$7.
        ICDDiag3         :$7.
        RevCode         :$20.
        PRM_Denied_YN     :$1.
	ClaimID :$40.
	Modifier :$2.
	Modifier2 :$2.
	POS :$2.
        ;
    format
        prm_fromdate     YYMMDDd10.
        ICDDiag4-ICDDiag15 $7.;
    ;
datalines;
/* insert outclaims_prm datalines here */
;
run;

/**** Run the test with clean elig end ****/
%let empirical_elig_date_end = %sysfunc(mdy(12,31,2014));
%DeleteWorkAndResults()
%include "%GetParentFolder()\Prod16_aod_init_engage.sas" / source2;
%CompareResults()

%put System Return Code = &syscc.;

