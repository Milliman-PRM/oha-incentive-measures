/*
### CODE OWNERS: Chas Busenburg

## OBJECTIVE:
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
		anticipated_numerator_init :12.
		anticipated_denominator_init :12.
		anticipated_numerator_engage :12.
		anticipated_denominator_engage :12.
		;
	format DOB :YYMMDDd10.;
datalines;
MrGood~1988-01-01~1~1~1~1
MrTooYoung~2016-01-01~0~0~0~0
MrHospice~1988-01-01~1~0~1~0
MrNegativeHistory~1988-01-01~1~0~1~0
MrIneligibleContinuousEnrollment~1988-01-01~1~0~1~0
;
run;
/* MrHospiceExcludedCPT~1988-01-01~0~0~0~0 */
/* MrHospiceExcludedREV~1988-01-01~0~0~0~0 */

proc sql;
	create table M150_Tmp.member_init as
	select
		members.member_id
		,members.DOB
		,members.anticipated_numerator_init as anticipated_numerator
		,members.anticipated_denominator_init as anticipated_denominator
	from M150_Tmp.member as members
	;
quit;

proc sql;
	create table M150_Tmp.member_engage as
	select
		members.member_id
		,members.DOB
		,members.anticipated_numerator_engage as anticipated_numerator
		,members.anticipated_denominator_engage as anticipated_denominator
	from M150_Tmp.member as members
	;
quit;


/* MrBarelyYoungEnough */

data M150_tmp.member_time;
	infile datalines delimiter='~';
	input
		member_id     :$40.
		date_start     :YYMMDD10.
		date_end     :YYMMDD10.
		;
	format date        :YYMMDDd10.;
datalines;
MrGood~2014-01-01~2014-12-31
MrTooYoung~2014-01-01~2014-12-31
MrHospice~2014-01-01~2014-12-31
MrNegativeHistory~2014-01-01~2014-12-31
MrIneligibleContinuousEnrollmentGap~2014-01-01~2014-01-30
MrIneligibleContinuousEnrollmentGap~2014-03-01~2014-03-30
;
run;
/* MrHospiceExcludedCPT~2014-01-01~2014-12-31 */
/* MrHospiceExcludedREV~2014-01-01~2014-12-31 */

/* data M150_Tmp.outpharmacy_prm; */
/*     infile datalines delimiter = '~'; */
/*     input */
/*         member_id         :$40. */
/*         prm_fromdate    :YYMMDD10. */
/*         NDC             :$20. */
/*         ; */
/*     format prm_fromdate :YYMMDDd10.; */
/* datalines; */
/* /1* insert outpharmcy datalines here *1/ */
/* ; */
/* run; */

data M150_Tmp.outclaims_prm;
    infile datalines delimiter = '~' dsd;
    input
        Member_ID         :$40.
	caseadmitid	:$40.
	ClaimID :$40.
	prm_fromdate    :YYMMDD10.
	prm_todate	:YYMMDD10.
	prm_fromdate_case	:YYMMDD10.
	prm_todate_case	:YYMMDD10.
	HCPCS		:$20.
	ICDDiag1	:$7.
	ICDDiag2	:$7.
	ICDDiag3	:$7.
	ICDProc1	:$7.
	ICDProc2	:$7.
	ICDProc3	:$7.
	RevCode         :$20.
	PRM_Denied_YN     :$1.
	Modifier :$2.
	Modifier2 :$2.
	POS :$2.
        ;
    format
        prm_fromdate     YYMMDDd10.
        ICDDiag4-ICDDiag15 $7.
	ICDProc4-ICDProc15 $7.;
    ;
datalines;
MrGood~GoodIndexEp~GIEClaim1~2014-03-15~2014-03-15~2014-03-15~2014-03-15~G0176~F1010~~~~~~~~~~
MrTooYoung~TooYoungIndexEp~TYIEClaim1~2014-03-15~2014-03-15~2014-03-15~2014-03-15~G0176~F1010~~~~~~~~~~
MrHospice~HospiceIndexEp~HospiceClaim1~2014-03-15~2014-03-15~2014-03-15~2014-03-15~G0176~F1010~~~~~~~~~~
MrHospice~HospiceEp2~HospiceClaim2~2014-12-15~2014-12-15~2014-12-15~2014-12-15~G9473~~~~~~~~~~~
MrNegativeHistory~NegativeHistEp~NegHistClaim1~2013-12-15~2013-12-15~2013-12-15~2013-12-15~G0176~F1010~~~~~~~~~~
MrNegativeHistory~NegativeHistIndexEp~NegHistClaim2~2014-01-15~2014-01-15~2014-01-15~2014-01-15~G0176~F1010~~~~~~~~~~
MrIneligibleContinuousEnrollment~IneligIndexEp~IneligContClaim1~2014-03-15~2014-03-15~2014-03-15~2014-03-15~G0176~F1010~~~~~~~~~~
;
run;
/* MrHospiceExcludedCPT~hospcptindexep~hecptClaim1~~~~~~~~~~~~~ */
/* MrHospiceExcludedREV~hosprevindexep~herevClaim1~~~~~~~~~~~~~ */
/* MrIneligibleContinuousEnrollmentGap~ineligenrollindexep~iceClaim1~~~~~~~~~~~~~ */

/**** Run the test with clean elig end ****/
%let empirical_elig_date_end = %sysfunc(mdy(12,31,2014));
%DeleteWorkAndResults()
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Prod18_aod_init_engage.sas" / source2;
%CompareResults(dset_expected=M150_Tmp.member_init,dset_compare=M150_Out.Results_&Measure_Name._init,unexpected_out=unexpected_results_init)
%CompareResults(dset_expected=M150_Tmp.member_engage,dset_compare=M150_Out.Results_&Measure_name._engage,unexpected_out=unexpected_results_engage)

%put System Return Code = &syscc.;

