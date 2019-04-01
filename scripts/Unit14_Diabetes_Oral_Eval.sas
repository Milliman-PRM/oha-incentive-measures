/*
### CODE OWNERS: Chas Busenburg

### OBJECTIVE:
    Test the Oral-Evaluation for Adults with Diabetes

### DEVELOPER NOTES:

*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

%let Suppress_Parser = True;
%let DATE_PERFORMANCEYEARSTART = %sysfunc(mdy(1,1,2014));
%let Date_LatestPaid_Round = %sysfunc(mdy(2,28,15));
%let QUALITY_METRICS = OHA_INCENTIVE_MEASURES;


/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/


/**** SETUP MOCKING ****/

%SetupMockLibraries()
options set=OHA_INCENTIVE_MEASURES_PATHREF "%sysfunc(pathname(oha_ref))";

data oha_ref.OHA_codes;
	infile datalines delimiter = '~' missover dsd;
	input
		Measure 	:$24.
		Component 	:$32.
		CodeSystem 	:$16.
		Code 		:$16.
		Grouping_ID :$32.
		Diag_Type 	:$16.
		;
datalines;
diabetes_oral_eval~numerator~CDT~Good_Code~~
not_diabetes_oral_eval~not_numerator~CDT~Bad_Code~~
;
run;

data oha_ref.medications;
    infile datalines delimiter = '~' missover dsd;
    input
		Measure 	:$24.
		Component 	:$32.
		CodeSystem 	:$16.
		Code 		:$16.
		Grouping_ID :$32.
		Diag_Type 	:$16.
		;
datalines;
diabetes_oral_eval~denom_medication~NDC~itsadrugcode~~
notdiabetes_ora_eval~not_denom_medications~NDC~itsnotavalidcode~~
;
run;

data oha_ref.hedis_codes;
    infile datalines delimiter = '~' missover dsd;
    input
		Measure 	:$24.
		Component 	:$32.
		CodeSystem 	:$16.
		Code 		:$16.
		Grouping_ID :$32.
		Diag_Type 	:$16.
		;
datalines;
diabetes_oral_eval~denom_one_visit~CPT~CPT_ONE_VISIT~~
diabetes_oral_eval~denom_one_visit~UBREV~UBREV_ONE_VISIT~~
diabetes_oral_eval~denom_diabetes~ICD10CM-Diag~DIAG_CO~~
diabetes_oral_eval~denom_two_visits~CPT~CPT_TWO_VISITS_1~~
diabetes_oral_eval~denom_two_visits~HCPCS~HCPCS_TWO_VISITS~~
diabetes_oral_eval~denom_two_visits~UBREV~UBREV_TWO_VISITS~~
diabetes_oral_eval~denom_excl_temp~ICD10CM-Diag~TMPDIAB~~
;
run;

data M030_Out.InpDental;
	infile datalines delimiter = '~' missover dsd;
	input
		ClaimID 		    :$40.
		Member_ID 		    :$40.
		DOB 			    :YYMMDD10.
		prm_fromdate        :YYMMDD10.
		HCPCS 			    :$20.
		Tooth			    :$20.
		;
	informat DOB 		    :YYMMDD10.
			 prm_fromdate   :YYMMDD10.
			 ;
	format DOB 			    :YYMMDD10.
		   prm_fromdate 	    :YYMMDD10.
		   ;
datalines;
Numer_CDT~Numer_CDT~1990-01-01~2014-06-01~Good_Code~Right_Tooth
Bad_CDT~Bad_CDT~1990-01-01~2014-06-01~Bad_Code~Right_Tooth
;
run;
data M150_Tmp.member;
	infile datalines delimiter = '~';
	input
		Member_ID 					:$40.
		DOB 						:YYMMDD10.
		anticipated_numerator	 	:12.
		anticipated_denominator 		:12.
		;
	format DOB 						:YYMMDDd10.;
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
Bad_CDT~1990-01-01~0~1
TwoGaps~1990-01-01~0~0
SmallSingularGap~1990-01-01~0~1
BigSingularGap~1990-01-01~0~0
;
run;

data member_time;
	infile datalines delimiter = '~';
	input
		Member_ID 	:$40.
		date_start 	:YYMMDD10.
		date_end 	:YYMMDD10.
		;
	format date		:YYMMDDd10.;
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
SmallSingularGap~2014-01-01~2014-01-31
SmallSingularGap~2014-03-01~2014-12-31
TwoGaps~2014-01-01~2014-01-31
TwoGaps~2014-03-01~2014-03-31
TwoGaps~2014-05-01~2014-12-31
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
		Member_ID 		:$40.
		prm_fromdate	:YYMMDD10.
		NDC             :$20.
        ;
	format FromDate 	:YYMMDDd10.;
datalines;
Denom_Medication~2014-06-01~itsadrugcode
Denom_TempDiabetes~2013-07-01~itsadrugcode
Denom_TempDiabetesAndDiabetes~2014-05-01~itsadrugcode
;
run;

data M150_Tmp.outclaims_prm;
	infile datalines delimiter = '~';
	input
		Member_ID 		:$40.
		prm_fromdate    :YYMMDD10.
		HCPCS 			:$20.
		ICDDiag1 		:$7.
		ICDDiag2 		:$7.
		ICDDiag3 		:$7.
        RevCode         :$20.
		PRM_Denied_YN 	:$1.
		;
	format 
		prm_fromdate 	YYMMDDd10.
		ICDDiag4-ICDDiag15 $7.;
	;
datalines;
Denom_TooYoung~2014-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
Denom_JustEighteen~2014-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
Denom_OneVisit~2014-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
Denom_OneVisitPriorYear~2013-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
Denom_TwoVisits~2014-01-02~CPT_TWO_VISITS_1~DIAG_CO~ ~ ~ ~N
Denom_TwoVisits~2014-06-01~HCPCS_TWO_VISITS~DIAG_CO~ ~ ~ ~N
Denom_TwoClaimsOneDay~2014-06-01~CPT_ONE_VISIT~ ~ ~ ~ ~N
Denom_TwoClaimsOneDay~2014-06-01~XXXXX~DIAG_CO~ ~ ~ ~N
Denom_EligPriorYear~2013-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
Denom_TempDiabetes~2014-06-01~XXXXX~TMPDIAB~ ~ ~ ~N
Denom_TempDiabetesAndDiabetes~2014-06-01~XXXXX~ ~TMPDIAB~ ~ ~N
Denom_TempDiabetesAndDiabetes~2014-01-01~ ~DIAG_CO~ ~ ~ ~N
Numer_CDT~2014-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
Bad_CDT~2014-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
TwoGaps~2014-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
SmallSingularGap~2014-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
BigSingularGap~2014-06-01~CPT_ONE_VISIT~DIAG_CO~ ~ ~ ~N
;
run;



/**** TEST WITH CLEAN ELIG END ****/

%let empirical_elig_date_end = %sysfunc(mdy(12,31,2014));
%DeleteWorkAndResults()
%include "%GetParentFolder(0)\Prod14_Diabetes_Oral_Eval.sas" / source2;
%CompareResults()


%put System Return Code = &syscc.;
