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

data M030_Out.InpDental;
    infile datalines delimiter = '~' missover dsd;
    input
        ClaimID             :$40.
        Member_ID             :$40.
        DOB                 :YYMMDD10.
        fromdate        :YYMMDD10.
        HCPCS                 :$20.
        Tooth                :$20.
        ;
    format DOB                 YYMMDD10.
           fromdate         YYMMDD10.
           ;
datalines;
Numer_CDT~Numer_CDT~1990-01-01~2014-06-01~D0120~Right_Tooth
Numer_InvalidDate~Numer_InvalidDate~1990-01-01~2013-06-01~D0120~Right_Tooth
Bad_CDT~Bad_CDT~1990-01-01~2014-06-01~D0000~Right_Tooth
;
run;
data M150_Tmp.member;
    infile datalines delimiter = '~';
    input
        Member_ID                     :$40.
        DOB                         :YYMMDD10.
        anticipated_numerator         :12.
        anticipated_denominator         :12.
        ;
    format DOB                         :YYMMDDd10.;
datalines;
Denom_TooYoung~2009-01-01~0~0
Denom_JustEighteen~1996-12-31~0~1
Denom_OneVisit~1990-01-01~0~1
Denom_OneVisitPriorYear~1990-01-01~0~1
Denom_TwoVisits~1990-01-01~0~1
Denom_TwoClaimsOneDay~1990-01-01~0~0
Denom_Medication~1990-01-01~0~1
Denom_EligPriorYear~1990-01-01~0~1
Denom_TempDiabetes~1990-01-01~0~0
Denom_TempDiabetesAndDiabetes~1990-01-01~0~1
Numer_CDT~1990-01-01~1~1
Numer_InvalidDate~1990-01-01~0~1
Bad_CDT~1990-01-01~0~1
TwoGaps~1990-01-01~0~0
SmallSingularGap~1990-01-01~0~1
BigSingularGap~1990-01-01~0~0
TelehealthIPExcluded~1990-01-01~0~0
TelehealthNonAcuteExcluded~1990-01-01~0~0
TelehealthOtherOPExcluded~1990-01-01~0~0
TelehealthNontelehealthCombined~1990-01-01~0~1
TelephoneNontelehealthCombined~1990-01-01~0~1
TwoVisitsDiffYearsExcluded~1990-01-01~0~0
HospiceExcluded~1990-01-01~0~0
FrailtyAdvancedIllnessDiagExcluded~1900-01-01~0~0
FrailtyDementiaRxExcluded~1900-01-01~0~0
FrailtyTooYoungIncluded~1990-01-01~0~1
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
BigSingularGap~2014-01-01~2014-02-01
BigSingularGap~2014-08-01~2014-12-31
Denom_TooYoung~2014-01-01~2014-12-31
Denom_JustEighteen~2014-01-01~2014-12-31
Denom_OneVisit~2014-01-01~2014-12-31
Denom_OneVisitPriorYear~2013-01-01~2014-12-31
Denom_TwoVisits~2014-01-01~2014-12-31
Denom_TwoClaimsOneDay~2014-01-01~2014-12-31
Denom_Medication~2014-01-01~2014-12-31
Denom_EligPriorYear~2014-01-01~2014-12-31
Denom_TempDiabetes~2014-01-01~2014-12-31
Denom_TempDiabetesAndDiabetes~2014-01-01~2014-12-31
Bad_CDT~2014-01-01~2014-12-31
Numer_CDT~2014-01-01~2014-12-31
Numer_InvalidDate~2014-01-01~2014-12-31
SmallSingularGap~2014-01-01~2014-01-31
SmallSingularGap~2014-03-01~2014-12-31
TwoGaps~2014-01-01~2014-01-31
TwoGaps~2014-03-01~2014-03-31
TwoGaps~2014-05-01~2014-12-31
TelehealthIPExcluded~2014-01-01~2014-12-31
TelehealthNonAcuteExcluded~2014-01-01~2014-12-31
TelehealthOtherOPExcluded~2014-01-01~2014-12-31
TelehealthNontelehealthCombined~2014-01-01~2014-12-31
TelephoneNontelehealthCombined~2014-01-01~2014-12-31
TwoVisitsDiffYearsExcluded~2014-01-01~2014-12-31
HospiceExcluded~2014-01-01~2014-12-31
FrailtyAdvancedIllnessDiagExcluded~2014-01-01~2014-12-31
FrailtyDementiaRxExcluded~2014-01-01~2014-12-31
FrailtyTooYoungIncluded~2014-01-01~2014-12-31
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


data M150_Tmp.outpharmacy_prm;
    infile datalines delimiter = '~';
    input
        Member_ID         :$40.
        prm_fromdate    :YYMMDD10.
        NDC             :$20.
        ;
    format FromDate     :YYMMDDd10.;
datalines;
Denom_Medication~2014-06-01~00002143301
Denom_TempDiabetes~2013-07-01~00002143301
Denom_TempDiabetesAndDiabetes~2014-05-01~00002143301
FrailtyDementiaRxExcluded~2014-05-01~00054009021
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
Denom_TooYoung~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
Denom_JustEighteen~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
Denom_OneVisit~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
Denom_OneVisitPriorYear~2013-06-01~99221~E1010~ ~ ~ ~N~~~~
Denom_TwoVisits~2014-01-02~99201~E1010~ ~ ~ ~N~~~~
Denom_TwoVisits~2014-06-01~99201~E1010~ ~ ~ ~N~~~~
Denom_TwoClaimsOneDay~2014-06-01~99221~ ~ ~ ~ ~N~claim_one_visit~~~
Denom_TwoClaimsOneDay~2014-06-01~XXXXX~E1010~ ~ ~ ~N~claim_diabetes_diagnosis~~~
Denom_EligPriorYear~2013-06-01~99221~E1010~ ~ ~ ~N~~~~
Denom_TempDiabetes~2014-06-01~XXXXX~E0800~ ~ ~ ~N~~~~
Denom_TempDiabetesAndDiabetes~2014-06-01~XXXXX~ ~E0800~ ~ ~N~~~~
Denom_TempDiabetesAndDiabetes~2014-01-01~ ~E1010~ ~ ~ ~N~~~~
Numer_CDT~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
Numer_InvalidDate~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
Bad_CDT~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
TwoGaps~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
SmallSingularGap~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
BigSingularGap~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
TelehealthIPExcluded~2014-06-01~99221~E1010~ ~ ~ ~N~~95~~
TelehealthNonAcuteExcluded~2014-01-02~99304~E1010~ ~ ~ ~N~~~95~
TelehealthNonAcuteExcluded~2014-06-01~99304~E1010~ ~ ~ ~N~~~95~
TelehealthOtherOPExcluded~2014-01-02~99217~E1010~ ~ ~ ~N~~95~~
TelehealthOtherOPExcluded~2014-06-01~99217~E1010~ ~ ~ ~N~~95~~
TelehealthNontelehealthCombined~2014-01-02~99217~E1010~ ~ ~ ~N~~95~~
TelehealthNontelehealthCombined~2014-06-01~99217~E1010~ ~ ~ ~N~~~~
TelephoneNontelehealthCombined~2014-01-02~98969~E1010~ ~ ~ ~N~~~~
TelephoneNontelehealthCombined~2014-06-01~99217~E1010~ ~ ~ ~N~~~~
TwoVisitsDiffYearsExcluded~2013-01-02~99201~E1010~ ~ ~ ~N~~~~
TwoVisitsDiffYearsExcluded~2014-06-01~99201~E1010~ ~ ~ ~N~~~~
HospiceExcluded~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
HospiceExcluded~2014-03-01~99377~E1010~ ~ ~ ~N~~~~
FrailtyAdvancedIllnessDiagExcluded~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
FrailtyAdvancedIllnessDiagExcluded~2014-03-01~99504~E1010~ ~ ~ ~N~~~~
FrailtyAdvancedIllnessDiagExcluded~2014-03-01~99221~A8100~ ~ ~ ~N~~~~
FrailtyDementiaRxExcluded~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
FrailtyDementiaRxExcluded~2014-03-01~99504~E1010~ ~ ~ ~N~~~~
FrailtyTooYoungIncluded~2014-06-01~99221~E1010~ ~ ~ ~N~~~~
FrailtyTooYoungIncluded~2014-03-01~99504~E1010~ ~ ~ ~N~~~~
FrailtyTooYoungIncluded~2014-03-01~99221~A8100~ ~ ~ ~N~~~~
;
run;



/**** TEST WITH CLEAN ELIG END ****/

%let empirical_elig_date_end = %sysfunc(mdy(12,31,2014));
%DeleteWorkAndResults()
%include "%GetParentFolder(0)\Prod14_Diabetes_Oral_Eval.sas" / source2;
%CompareResults()


%put System Return Code = &syscc.;
