/*
### CODE OWNERS: Ben Copeland

### OBJECTIVE:
    Test the calculation of Timeliness of Prenatal and Postpartum Care

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
        measure :$32.
        anticipated_numerator :12.
        anticipated_denominator :12.
        ;
    format DOB :YYMMDDd10.;
datalines;
no_birth~prenatal_care~0~0
no_birth~postpartum_care~0~0
denom_birth_only~prenatal_care~0~1
denom_birth_only~postpartum_care~0~1
denom_excl_non_live_birth~prenatal_care~0~0
denom_excl_non_live_birth~postpartum_care~0~0
denom_excl_cont_enroll~prenatal_care~0~0
denom_excl_cont_enroll~postpartum_care~0~0
denom_excl_hospice~prenatal_care~0~0
denom_excl_hospice~postpartum_care~0~0
denom_several_claims~prenatal_care~0~1
denom_several_claims~postpartum_care~0~1
denom_multiple_births~prenatal_care~0~2
denom_multiple_births~postpartum_care~0~2
prenatal_care_219_280_days~prenatal_care~1~1
prenatal_care_219_280_days~postpartum_care~0~1
prenatal_care_lt_219_days~prenatal_care~1~1
prenatal_care_lt_219_days~postpartum_care~0~1
postpartum_care~prenatal_care~0~1
postpartum_care~postpartum_care~1~1
postpartum_care_ip_excl~prenatal_care~0~1
postpartum_care_ip_excl~postpartum_care~0~1
both_numerators~prenatal_care~1~1
both_numerators~postpartum_care~1~1
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
denom_multiple_births~2013-01-01~2013-12-31
denom_multiple_births~2014-01-01~2014-12-31
prenatal_care_219_280_days~2013-01-01~2013-12-31
prenatal_care_219_280_days~2014-01-01~2014-12-31
prenatal_care_lt_219_days~2013-01-01~2013-05-31
prenatal_care_lt_219_days~2013-12-01~2013-12-31
prenatal_care_lt_219_days~2014-01-01~2014-12-31
postpartum_care~2013-01-01~2013-12-31
postpartum_care~2014-01-01~2014-12-31
postpartum_care_ip_excl~2013-01-01~2013-12-31
postpartum_care_ip_excl~2014-01-01~2014-12-31
both_numerators~2013-01-01~2013-12-31
both_numerators~2014-01-01~2014-12-31
;
run;

data member_time_cover_medical;
	set member_time;

	format
		cover_medical $1.
	;
	cover_medical = 'Y';
run;

proc sort
    data = member_time_cover_medical
    out = M150_Tmp.member_time
    ;
    by
        Member_ID
        date_end
    ;
    run
    ;

/* DEV TOOL FOR FINDING THE FIRST CODE IN EACH COMPONENT */
/*
	libname oha_ref "%sysget(OHA_INCENTIVE_MEASURES_PATHREF)" access=readonly;
	proc sort nodupkey
	data=oha_ref.hedis_codes
	out = first_code
	;
	by
		measure
		component
	;
	where measure eq "prenatal_postpartum_care";
run;
*/

data M150_Tmp.outclaims_prm;
    infile datalines delimiter = '~' dsd;
    input
        Member_ID :$40.
        prm_fromdate :YYMMDD10.
        prm_todate :YYMMDD10.
        HCPCS :$20.
        RevCode :$20.
        POS :$2.
        ICDVersion :$2.
        ICDDiag1 :$7.
        ICDDiag2 :$7.
        ICDDiag3 :$7.
        ICDProc1 :$7.
        ICDProc2 :$7.
        ICDProc3 :$7.
        ;
    format
        prm_fromdate YYMMDDd10.
        prm_todate YYMMDDd10.
    ;
datalines;
denom_birth_only~2014-04-20~2014-04-25~59400~~~10~~~~~~
denom_excl_non_live_birth~2014-04-20~2014-04-25~59400~~~10~O000~~~~~
denom_excl_cont_enroll~2014-04-20~2014-04-25~59400~~~10~~~~~~
denom_excl_hospice~2014-04-20~2014-04-25~59400~~~10~~~~~~
denom_excl_hospice~2014-09-20~2014-09-25~G9473~~~10~~~~~~
denom_several_claims~2014-04-23~2014-04-23~59400~~~10~~~~~~
denom_several_claims~2014-04-24~2014-04-24~59400~~~10~~~~~~
denom_several_claims~2014-04-20~2014-04-30~59400~~~10~~~~10D00Z0~~
denom_multiple_births~2013-10-23~2013-10-23~59400~~~10~~~~~~
denom_multiple_births~2013-10-24~2013-10-24~59400~~~10~~~~~~
denom_multiple_births~2013-10-20~2013-10-30~59400~~~10~~~~10D00Z0~~
denom_multiple_births~2014-09-23~2014-09-23~59400~~~10~~~~~~
denom_multiple_births~2014-09-24~2014-09-24~59400~~~10~~~~~~
denom_multiple_births~2014-09-20~2014-09-30~59400~~~10~~~~10D00Z0~~
prenatal_care_219_280_days~2014-04-20~2014-04-25~59400~~~10~~~~~~
prenatal_care_219_280_days~2013-08-15~2013-08-15~99201~~~10~O0900~~~~~
prenatal_care_lt_219_days~2014-04-20~2014-04-25~59400~~~10~~~~~~
prenatal_care_lt_219_days~2013-12-22~2014-12-22~99201~~~10~O0900~~~~~
postpartum_care~2014-04-20~2014-04-25~59400~~~10~~~~~~
postpartum_care~2014-05-20~2014-05-20~57170~~~10~~~~~~
postpartum_care_ip_excl~2014-04-20~2014-04-25~59400~~~10~~~~~~
postpartum_care_ip_excl~2014-05-20~2014-05-20~57170~~21~10~~~~~~
both_numerators~2014-04-20~2014-04-25~59400~~~10~~~~~~
both_numerators~2013-08-15~2013-08-15~99201~~~10~XXXXX~O0900~XXXXX~~~
both_numerators~2014-05-20~2014-05-20~57170~~~10~~~~~~
;
run;



/**** TEST WITH CLEAN ELIG END ****/

%let empirical_elig_date_end = %sysfunc(mdy(12,31,2014));
%DeleteWorkAndResults()
%include "%GetParentFolder(0)\Prod16_prenatal_postpartum_care.sas" / source2;


proc sql;
	create table mismatches
	as select
		coalesce(actual.member_id, expected.member_id) as member_id
		,actual.measure
		,actual.denominator
		,actual.numerator
		,expected.anticipated_denominator
		,expected.anticipated_numerator
	from measure_results_summ as actual
	full outer join m150_tmp.member as expected on
		actual.member_id eq expected.member_id
		and actual.measure eq expected.measure
	where
		numerator ne anticipated_numerator
		or denominator ne anticipated_denominator
	;
quit;
%AssertDataSetNotPopulated(mismatches, ReturnMessage=The &Measure_Name. results are not as expected.  Aborting...);


%put System Return Code = &syscc.;
