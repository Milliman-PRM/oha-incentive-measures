/*
### CODE OWNERS: Scott Cox, Ben Copeland

### OBJECTIVE:
  Test the Dental Sealants measure computation.

### DEVELOPER NOTES:
  Design pattern borrowed from Aaron Hoch, Shea Parkes, Neil Schneider
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
Wrong_Measure~Wrong_Component~CDT~Good_Code~~~
Wrong_Measure~Wrong_Component~CDT~Wrong_Code~~~
Dental_Sealants~Numer_Seals~CDT~Good_Code~~~
Dental_Sealants~Numer_Dental_Claim_Code~DENTAL~Good_Code~Tooth_Code~~
Dental_Sealants~Numer_Dental_Tooth_Code~TOOTH~Right_Tooth~Tooth_Code~~
;
run;
data M030_Out.InpDental;
	infile datalines delimiter = '~' missover dsd;
	input
		ClaimID 		:$40.
		Member_ID 		:$40.
		DOB 			:YYMMDD10.
		FromDate 		:YYMMDD10.
		HCPCS 			:$20.
		Tooth			:$20.
		;
	informat DOB 		:YYMMDD10.
			 FromDate 	:YYMMDD10.
			 ;	
	format DOB 			:YYMMDD10.
		   FromDate 	:YYMMDD10.
		   ;
datalines;
MrAllGoodMinAge~MrAllGoodMinAge~2008-12-31~2014-06-01~Good_Code~Right_Tooth
MrAllGoodMaxAge~MrAllGoodMaxAge~2000-01-01~2014-06-01~Good_Code~Right_Tooth
MrWrongTooth~MrWrongTooth~2004-06-01~2014-06-01~Good_Code~Wrong_Tooth
MrWrongCodeAndTooth~MrWrongCodeAndTooth~2004-06-01~2014-06-01~Wrong_Code~Wrong_Tooth
MrWrongCodeRightTooth~MrWrongCodeRightTooth~2004-06-01~2014-06-01~Wrong_Code~Right_Tooth
MrTooYoung~MrTooYoung~2009-01-01~2014-06-01~Good_Code~Right_Tooth
MrTooOld~MrTooOld~1999-12-31~2014-06-01~Good_Code~Right_Tooth
MrWrongCode~MrWrongCode~2004-06-01~2014-06-01~Wrong_Code~Right_Tooth
MrWrongGoodCode~MrWrongGoodCode~2004-06-01~2014-06-01~Wrong_Code~Right_Tooth
MrOneSmallGap~MrOneSmallGap~2001-03-03~2001-03-03~Good_Code~Right_Tooth
MrOneBigGap~MrOneBigGap~2001-03-03~2001-03-03~Good_Code~Right_Tooth
MrTwoGaps~MrTwoGaps~2001-03-03~2001-03-03~Good_Code~Right_Tooth
MrWrongDate~MrWrongdDate~2004-06-01~2013-12-31~Good_Code~Right_Tooth
;
run;
data M150_Tmp.member;
	infile datalines delimiter = '~';
	input
		Member_ID 					:$40.
		DOB 						:YYMMDD10.
		anticipated_denominator 	:12.
		anticipated_numerator 		:12.
		;
	format DOB 						:YYMMDDd10.;
datalines;
MrAllGoodMinAge~2008-12-31~1~1
MrAllGoodMaxAge~2000-01-01~1~1
MrAllGoodNoToothInfo~2004-06-01~1~1
MrWrongTooth~2004-06-01~1~0
MrWrongCodeAndTooth~2004-06-01~1~0
MrWrongCodeRightTooth~2004-06-01~1~0
MrWrongCodeNoToothInfo~2004-06-01~1~0
MrTooYoung~2009-01-01~0~0
MrTooOld~1999-12-31~0~0
MrWrongCode~2004-06-01~1~0
MrWrongGoodCode~2004-06-01~1~1
MrWrongCodeNoToothInfo~2004-06-01~1~0
MrWrongGoodCodeNoToothInfo~2004-06-01~1~0
MrOneSmallGap~2001-03-03~1~1
MrOneBigGap~2001-03-03~0~0
MrTwoGaps~2001-03-03~0~0
MrWrongDate~2004-06-01~0~0
;
run;

data M150_Tmp.member_time;
	infile datalines delimiter = '~';
	input
		Member_ID 	:$40.
		date_start 	:YYMMDD10.
		date_end 	:YYMMDD10.
		;
	format date		:YYMMDDd10.;
datalines;
MrAllGoodMinAge~2014-01-01~2014-12-31
MrAllGoodMaxAge~2014-01-01~2014-12-31
MrAllGoodNoToothInfo~2014-01-01~2014-12-31
MrWrongTooth~2014-01-01~2014-12-31
MrWrongCodeAndTooth~2014-01-01~2014-12-31
MrWrongCodeRightTooth~2014-01-01~2014-12-31
MrWrongCodeNoToothInfo~2014-01-01~2014-12-31
MrTooYoung~2014-01-01~2014-12-31
MrTooOld~2014-01-01~2014-12-31
MrWrongCode~2014-01-01~2014-12-31
MrWrongGoodCode~2014-01-01~2014-12-31
MrWrongCodeNoToothInfo~2014-01-01~2014-12-31
MrWrongGoodCodeNoToothInfo~2014-01-01~2014-12-31
MrOneSmallGap~2013-01-01~2014-04-01
MrOneSmallGap~2014-05-17~2015-12-31
MrOneBigGap~2013-01-01~2014-04-01
MrOneBigGap~2014-05-18~2015-12-31
MrTwoGaps~2013-01-01~2014-04-01
MrTwoGaps~2014-04-03~2014-05-01
MrTwoGaps~2014-05-03~2015-12-31
MrWrongDate~2013-01-01~2013-12-31
;
run;

data M150_Tmp.outclaims_prm;
	infile datalines delimiter = '~';
	input
		Member_ID 		:$40.
		FromDate 		:YYMMDD10.
		HCPCS 			:$20.
		ICDDiag1 		:$7.
		ICDDiag2 		:$7.
		ICDDiag3 		:$7.
		PRM_Denied_YN 	:$1.
		;
	format FromDate 	:YYMMDDd10.;
datalines;
MrAllGoodMinAge~2014-06-01~Good_Code~ ~ ~ ~N
MrAllGoodMaxAge~2014-06-01~Good_Code~ ~ ~ ~N
MrAllGoodNoToothInfo~2014-06-01~Good_Code~ ~ ~ ~N
MrWrongCodeAndTooth~2014-06-01~Wrong_Code~ ~ ~ ~N
MrWrongCodeRightTooth~2014-06-01~Wrong_Code~ ~ ~ ~N
MrWrongCodeNoToothInfo~2014-06-01~Wrong_Code~ ~ ~ ~N
MrTooOld~2014-06-01~Good_Code~ ~ ~ ~N
MrTooYoung~2014-06-01~Good_Code~ ~ ~ ~N
MrWrongCode~2014-06-01~Wrong_Code~ ~ ~ ~N
MrWrongGoodCode~2014-06-01~Good_Code~ ~ ~ ~N
MrWrongCodeNoToothInfo~2014-06-01~Wrong_Code~ ~ ~ ~N
MrWrongGoodCodeNoToothInfo~2014-06-01~Wrong_Code~ ~ ~ ~N
MrOneSmallGap~2014-04-17~Good_Code~ ~ ~ ~N
MrOneBigGap~2014-04-17~Good_Code~ ~ ~ ~N
MrTwoGaps~2014-04-17~Good_Code~ ~ ~ ~N
MrWrongDate~2013-01-01~Good_Code~ ~ ~N
;
run;



/**** TEST WITH CLEAN ELIG END ****/

%let empirical_elig_date_end = %sysfunc(mdy(12,31,2014));
%DeleteWorkAndResults()
%include "%GetParentFolder(0)\Prod12_Dental_Sealant.sas" / source2;
%CompareResults()


%put System Return Code = &syscc.;
