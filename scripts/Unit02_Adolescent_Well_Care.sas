/*
### CODE OWNERS: Aaron Hoch, Shea Parkes, Neil Schneider

### OBJECTIVE:
  Test the Adolescent Well Care Visits (AWC) measure computation.

### DEVELOPER NOTES:
  <None>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp02_Shared_Testing.sas" / source2;

%let Suppress_Parser = True;
%let DATE_PERFORMANCEYEARSTART = %sysfunc(mdy(1,1,2014));
%let Date_LatestPaid_Round = %sysfunc(mdy(2,28,15));
%let QUALITY_METRICS = OHA_INCENTIVE_MEASURES;


/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/


/**** SETUP MOCKING ****/

%SetupMockLibraries()

data M015_Out.OHA_codes;
	infile datalines delimiter = '~' missover dsd;
	input
		Measure :$24.
		Component :$32.
		CodeSystem :$16.
		Code :$16.
		Grouping_ID :$32.
		Diag_Type :$16.
		;
datalines;
Adolescent_Well_Care~NUMERATOR~CPT~CHK1~~
Adolescent_Well_Care~NUMERATOR~CPT~CHK2~~
Adolescent_Well_Care~NUMERATOR~ICD9CM-Diag~DCHK1~~
Adolescent_Well_Care~NUMERATOR~ICD9CM-Diag~DCHK2~~
Adolescent_Well_Care~NUMERATOR~ICD10CM-Diag~D10CHK1~~
Adolescent_Well_Care~NUMERATOR~ICD10CM-Diag~D10CHK2~~
;
run;

data M150_Tmp.member;
	infile datalines delimiter = '~';
	input
		Member_ID :$40.
		DOB :YYMMDD10.
		anticipated_denominator :12.
		anticipated_numerator :12.
		;
	format DOB YYMMDDd10.;
datalines;
MrAllGood~2000-01-01~1~1
MrTooOld~1945-01-01~0~0
MrTooYoung~2012-01-01~0~0
MrTwoGaps~2000-01-01~0~0
MrOneBigGap~2000-01-01~0~0
MrOneSmallGap~2001-03-03~1~1
MrDiagBased~2000-01-01~1~1
MrDeniedChk~2000-01-01~1~1
MrChkTooEarly~2000-01-01~1~0
MrIncorrectCode~2000-01-01~1~0
MrAllGood_icd10~2000-01-01~1~1
;
run;

data M150_Tmp.member_time;
	infile datalines delimiter = '~';
	input
		Member_ID :$40.
		date_start :YYMMDD10.
		date_end :YYMMDD10.
		;
	format date: YYMMDDd10.;
datalines;
MrAllGood~2013-01-01~2014-07-01
MrAllGood~2014-07-02~2015-01-01
MrTooOld~2013-01-01~2015-01-01
MrTooYoung~2013-01-01~2015-01-01
MrTwoGaps~2013-01-01~2014-02-01
MrTwoGaps~2014-02-04~2014-08-01
MrTwoGaps~2014-08-04~2014-12-31
MrOneBigGap~2014-01-01~2014-02-01
MrOneBigGap~2014-07-01~2014-12-31
MrOneSmallGap~2013-01-01~2014-07-01
MrOneSmallGap~2014-07-13~2015-01-01
MrDiagBased~2014-01-01~2014-12-31
MrDeniedChk~2014-01-01~2014-12-31
MrChkTooEarly~2014-01-01~2014-12-31
MrIncorrectCode~2014-01-01~2014-12-31
MrAllGood_icd10~2013-01-01~2015-01-01
;
run;

data M150_Tmp.outclaims_prm;
	infile datalines delimiter = '~';
	input
		Member_ID :$40.
		FromDate :YYMMDD10.
		HCPCS :$5.
		ICDDiag1 :$7.
		ICDDiag2 :$7.
		ICDDiag3 :$7.
		PRM_Denied_YN :$1.
		;
	format FromDate YYMMDDd10.;
datalines;
MrAllGood~2014-04-17~CHK1~ ~ ~ ~N
MrTooOld~2014-04-17~CHK1~ ~ ~ ~N
MrTwoGaps~2014-04-17~CHK1~ ~ ~ ~N
MrOneBigGap~2014-04-17~CHK1~ ~ ~ ~N
MrOneSmallGap~2014-04-17~CHK1~ ~ ~ ~N
MrDiagBased~2014-04-16~ ~DCHK2~ ~ ~N
MrDeniedChk~2014-04-17~CHK1~ ~ ~ ~Y
MrAllGood~2013-04-17~CHK1~ ~ ~ ~N
MrIncorrectCode~2014-04-17~NoCHK1~ ~ ~ ~N
MrAllGood_icd10~2014-04-17~ ~D10CHK1~ ~ ~N
;
run;



/**** TEST WITH CLEAN ELIG END ****/

%let empirical_elig_date_end = %sysfunc(mdy(12,31,2014));
%DeleteWorkAndResults()
%include "%GetParentFolder(0)\Prod02_Adolescent_Well_Care.sas" / source2;
%CompareResults()



/**** TEST WITH EXTRA ELIG RUNOUT ****/

%let empirical_elig_date_end = %sysfunc(mdy(3,01,2015));
%DeleteWorkAndResults()
%include "%GetParentFolder(0)\Prod02_Adolescent_Well_Care.sas" / source2;
%CompareResults()



/**** TEST WITH TRUNCATED ELIG ****/

%let empirical_elig_date_end = %sysfunc(mdy(06,30,2014));
%DeleteWorkAndResults()

data M150_Tmp.member;
	set M150_Tmp.member;
	select (Member_ID);
		when ('MrTwoGaps') do;
			anticipated_numerator = 1;
			anticipated_denominator = 1;
			end;
		otherwise;
		end;
	run;

%include "%GetParentFolder(0)\Prod02_Adolescent_Well_Care.sas" / source2;
%CompareResults()


%put System Return Code = &syscc.;
