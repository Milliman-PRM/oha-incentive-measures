/*
### CODE OWNERS: Chas Busenburg, Ben Copeland

### OBJECTIVE:
    Test the Oral-Evaluation for Adults with Diabetes

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
    infile datalines delimiter = '~';
    input
        Member_ID :$40.
        anticipated_numerator :12.
        anticipated_denominator :12.
        ;
    format DOB :YYMMDDd10.;
datalines;
no_birth~0~0
denom_birth_only~0~1
denom_excl_non_live_birth~0~0
denom_excl_cont_enroll~0~0
denom_excl_hospice~0~0
denom_several_claims~0~0
prenatal_care_219_280_days~1~1
prenatal_care_lt_219_days~1~1
postpartum_care~1~1
postpartum_care_ip_excl~1~1
both_numerators~1~1
;
run;

data member_time;
    infile datalines delimiter = '~';
    input
        Member_ID     :$40.
        date_start     :YYMMDD10.
        date_end     :YYMMDD10.
        ;
    format date        :YYMMDDd10.;
datalines;
no_birth~2013-01-01~2013-12-31
no_birth~2014-01-01~2014-12-31
denom_birth_only~2013-01-01~2013-12-31
denom_birth_only~2014-01-01~2014-12-31
denom_excl_non_live_birth~2013-01-01~2013-12-31
denom_excl_non_live_birth~2014-01-01~2014-12-31
denom_excl_cont_enroll~2013-01-01~2013-12-31
denom_excl_cont_enroll~2014-01-01~2014-03-01
denom_excl_cont_enroll~2014-05-01~2014-12-31
denom_excl_hospice~2013-01-01~2013-12-31
denom_excl_hospice~2014-01-01~2014-12-31
denom_several_claims~2013-01-01~2013-12-31
denom_several_claims~2014-01-01~2014-12-31
prenatal_care_219_280_days~2013-01-01~2013-12-31
prenatal_care_219_280_days~2014-01-01~2014-12-31
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

data M150_Tmp.outclaims_prm;
    infile datalines delimiter = '~' dsd;
    input
        Member_ID :$40.
        prm_fromdate :YYMMDD10.
        prm_todate :YYMMDD10.
        HCPCS :$20.
        RevCode :$20.
        POS :$2.
        ICDDiag1 :$7.
        ICDDiag2 :$7.
        ICDDiag3 :$7.
        ICDProc1 :$7.
        ICDProc2 :$7.
        ICDProc3 :$7.
        ;
    format
        prm_fromdate     YYMMDDd10.
    ;
datalines;
denom_birth_only~2014-04-20~2014-04-25~59400~~~~~~~~
denom_excl_non_live_birth~2014-04-20~2014-04-25~59400~~~~~~~~
denom_excl_cont_enroll~2014-04-20~2014-04-25~59400~~~~~~~~
denom_excl_hospice~2014-04-20~2014-04-25~59400~~~~~~~~
denom_several_claims~2014-04-20~2014-04-25~59400~~~~~~~~
prenatal_care_219_280_days~2014-04-20~2014-04-25~59400~~~~~~~~
prenatal_care_lt_219_days~2014-04-20~2014-04-25~59400~~~~~~~~
postpartum_care~2014-04-20~2014-04-25~59400~~~~~~~~
postpartum_care_ip_excl~2014-04-20~2014-04-25~59400~~~~~~~~
both_numerators~2014-04-20~2014-04-25~59400~~~~~~~~
;
run;



/**** TEST WITH CLEAN ELIG END ****/

%let empirical_elig_date_end = %sysfunc(mdy(12,31,2014));
%DeleteWorkAndResults()
%include "%GetParentFolder(0)\Prod14_Diabetes_Oral_Eval.sas" / source2;
%CompareResults()


%put System Return Code = &syscc.;
