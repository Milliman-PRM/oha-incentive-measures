/*
### CODE OWNERS: Aaron Hoch, Ben Copeland, Michael Menser
### OBJECTIVE:
  Test the Assessments within 60 Days for Children in DHS Custody measure computation.
### DEVELOPER NOTES:
  <None>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

%let Suppress_Parser = True;
%let DATE_PERFORMANCEYEARSTART = %sysfunc(mdy(1,1,2014));
%let Date_LatestPaid_Round = %sysfunc(mdy(2,28,15));
%let date_latestpaid = %sysfunc(mdy(2,26,2015));
%let QUALITY_METRICS = OHA_INCENTIVE_MEASURES;
%let empirical_elig_date_end = %sysfunc(mdy(10,01,2014));


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
DHS_assessments~Numerator_Physical~CPT~CHK1~~
DHS_assessments~Numerator_Physical~CPT~CHK6~~
DHS_assessments~Numerator_Mental~CPT~CHK2~~
DHS_assessments~Numerator_Mental~CPT~CHK3a~DHS_Pair1~
DHS_assessments~Numerator_Mental~MODIFIER~3a~DHS_Pair1~
DHS_assessments~Numerator_PRTS~CPT~CHK4a~DHS_Pair2~
DHS_assessments~Numerator_PRTS~POS~4a~DHS_Pair2~
DHS_assessments~Numerator_Dental~CDT~CHK5~~
DHS_assessments~Numerator_PhysMent~CPT~CHK6~physical_mental~
DHS_assessments~Numerator_PhysMent~ICD9CM-Diag~mhdiag9~physical_mental~
DHS_assessments~Numerator_PhysMent~ICD10CM-Diag~mhdiag0~physical_mental~
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
MsBabyGirl~2014-01-01~1~1
Ms2yrOld~2013-01-01~1~1
Mr5yrOld~2010-01-01~1~1
MsPRTS~2003-01-01~1~1
MrTooOld~1945-01-01~0~0
MrOneBigGap~2005-01-01~0~0
MrGuardianChange~2008-01-01~0~0
MrChkTooEarly~2000-01-01~1~0
MrNoMental~2000-01-01~1~0
MsNoPhysical~2000-01-01~1~0
MsNoDental~2000-01-01~1~0
MrIncorrectCode~2000-01-01~1~0
MsEnterTooEarly~2000-01-01~0~0
MsClaimInDentalFile~2013-01-01~1~1
MrWrongCodeInDentalFile~2001-01-01~1~0
MrMissedDateCutoffInDentalFile~2004-01-01~1~0
MrPhys_Mental_DentalFile09~2004-01-01~1~1
MrPhys_Mental_DentalFile10~2004-01-01~1~1
MrPhys_Mental_DentalFile_wrong_vers~2004-01-01~1~0
; /*Test the incorporation of the dental file with the last three lines.*/
run;

data M036_Out.members_foster_care;
	infile datalines delimiter = '~';
	input
		Member_ID :$40.
		Report_Date :YYMMDD10.
		dob :YYMMDD10.
		branch_code :$4.
		Eligibility_Effective_Date :YYMMDD10.
		;
	format Report_Date dob YYMMDDd10. Eligibility_Effective_Date :YYMMDD10.;
datalines;
MsBabyGirl~2014-03-01~2014-01-01~ ~2014-02-15
Ms2yrOld~2014-03-01~2013-01-01~ ~2014-02-15
Mr5yrOld~2014-03-01~2010-01-01~ ~2014-02-15
MsPRTS~2014-03-01~2003-01-01~ ~2014-02-15
MrTooOld~2014-03-01~1945-01-01~ ~2014-02-15
MrOneBigGap~2014-03-01~2005-01-01~ ~2014-02-15
MrGuardianChange~2014-03-01~2008-01-01~6050~2014-02-15
MrChkTooEarly~2014-03-01~2000-01-01~ ~2014-02-15
MrNoMental~2014-03-01~2000-01-01~ ~2014-02-15
MsNoPhysical~2014-03-01~2000-01-01~ ~2014-02-15
MsNoDental~2014-03-01~2000-01-01~ ~2014-02-15
MrIncorrectCode~2014-03-01~2000-01-01~ ~2014-02-15
MsEnterTooEarly~2014-03-01~2000-01-01~ ~2014-01-01
MsClaimInDentalFile~2014-03-01~2013-01-01~ ~2014-02-15
MrWrongCodeInDentalFile~2014-03-01~2001-01-01~ ~2014-02-15
MrMissedDateCutoffInDentalFile~2014-03-01~2004-01-01~ ~2014-02-15
MrPhys_Mental_DentalFile09~2014-03-01~2008-01-01~ ~2014-02-15
MrPhys_Mental_DentalFile10~2014-03-01~2008-01-01~ ~2014-02-15
MrPhys_Mental_DentalFile_wrong_vers~2014-03-01~2008-01-01~ ~2014-02-15
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
MsBabyGirl~2014-01-01~2014-10-01
Ms2yrOld~2014-01-01~2014-10-01
Mr5yrOld~2014-01-01~2014-10-01
MsPRTS~2014-01-01~2014-10-01
MrTooOld~2014-01-01~2014-10-01
MrOneBigGap~2014-01-01~2014-04-25
MrGuardianChange~2014-01-01~2014-10-01
MrChkTooEarly~2014-01-01~2014-10-01
MrNoMental~2014-01-01~2014-10-01
MsNoPhysical~2014-01-01~2014-10-01
MsNoDental~2014-01-01~2014-10-01
MrIncorrectCode~2014-01-01~2014-10-01
MsEnterTooEarly~2014-01-01~2014-10-01
MsClaimInDentalFile~2014-01-01~2014-10-01
MrWrongCodeInDentalFile~2014-01-01~2014-10-01
MrMissedDateCutoffInDentalFile~2014-01-01~2014-10-01
MrPhys_Mental_DentalFile09~2014-01-01~2014-10-01
MrPhys_Mental_DentalFile10~2014-01-01~2014-10-01
MrPhys_Mental_DentalFile_wrong_vers~2014-01-01~2014-10-01
;
run;

data M150_Tmp.outclaims_prm;
	infile datalines delimiter = '~' dsd;
	input
		Member_ID :$40.
		PRM_FromDate :YYMMDD10.
		HCPCS :$5.
		Modifier :$2.
		Modifier2 :$2.
		POS :$2.
		ICDVersion :$2.
		ICDDiag1 :$7.
		ICDDiag2 :$7.
		;
	format PRM_FromDate YYMMDDd10.;
datalines;
MsBabyGirl~2014-04-01~CHK1~XX~XX~XX~~~
Ms2yrOld~2014-04-01~CHK1~XX~XX~XX~~~
Ms2yrOld~2014-04-02~CHK5~XX~XX~XX~~~
Mr5yrOld~2014-04-01~CHK1~XX~XX~XX~~~
Mr5yrOld~2014-04-02~CHK2~XX~XX~XX~~~
Mr5yrOld~2014-04-03~CHK5~XX~XX~XX~~~
MsPRTS~2014-04-01~CHK4a~XX~XX~4a~~~
MsPRTS~2014-04-02~CHK5~XX~XX~XX~~~
MrTooOld~2014-04-01~CHK1~XX~XX~XX~~~
MrTooOld~2014-04-02~CHK3a~3a~XX~XX~~~
MrTooOld~2014-04-01~CHK5~XX~XX~XX~~~
MrOneBigGap~2014-04-01~CHK1~XX~XX~XX~~~
MrOneBigGap~2014-04-02~CHK2~XX~XX~XX~~~
MrOneBigGap~2014-04-03~CHK5~XX~XX~XX~~~
MrGuardianChange~2014-04-01~CHK1~XX~XX~XX~~~
MrGuardianChange~2014-04-02~CHK2~XX~XX~XX~~~
MrGuardianChange~2014-04-03~CHK5~XX~XX~XX~~~
MrChkTooEarly~2014-01-15~CHK1~XX~XX~XX~~~
MrChkTooEarly~2014-01-16~CHK3a~3a~XX~XX~~~
MrChkTooEarly~2014-04-01~CHK5~XX~XX~XX~~~
MrNoMental~2014-04-01~CHK1~XX~XX~XX~~~
MrNoMental~2014-04-03~CHK5~XX~XX~XX~~~
MsNoPhysical~2014-04-02~CHK2~XX~XX~XX~~~
MsNoPhysical~2014-04-03~CHK5~XX~XX~XX~~~
MsNoDental~2014-04-01~CHK1~XX~XX~XX~~~
MsNoDental~2014-04-02~CHK2~XX~XX~XX~~~
MrIncorrectCode~2014-04-01~CHK1~XX~XX~XX~~~
MrIncorrectCode~2014-04-02~CHK3a~3b~XX~XX~~~
MrIncorrectCode~2014-04-01~CHK5~XX~XX~XX~~~
MsEnterTooEarly~2014-04-01~CHK2~XX~XX~XX~~~
MsClaimInDentalFile~2014-04-01~CHK1~XX~XX~XX~~~
MsClaimInDentalFile~2014-04-02~CHK2~XX~XX~XX~~~
MrWrongCodeInDentalFile~2014-04-01~CHK1~XX~XX~XX~~~
MrWrongCodeInDentalFile~2014-04-01~CHK2~XX~XX~XX~~~
MrMissedDateCutoffInDentalFile~2014-04-01~CHK1~XX~XX~XX~~~
MrMissedDateCutoffInDentalFile~2014-04-03~CHK2~XX~XX~XX~~~
MrPhys_Mental_DentalFile09~2014-04-01~CHK6~XX~XX~XX~09~XX~mhdiag9
MrPhys_Mental_DentalFile10~2014-04-01~CHK6~XX~XX~XX~10~mhdiag0~
MrPhys_Mental_DentalFile_wrong_vers~2014-04-01~CHK6~XX~XX~XX~10~mhdiag9~
;
run;

data M150_Tmp.inpDental;
	infile datalines delimiter = '~';
	input
		Member_ID :$40.
		FromDate :YYMMDD10.
		HCPCS :$5.
		Modifier :$2.
		Modifier2 :$2.
		POS :$2.
		;
	format FromDate YYMMDDd10.;
datalines;
MsClaimInDentalFile~2014-04-01~CHK5~XX~XX~XX
MrWrongCodeInDentalFile~2014-04-03~CHK4a~XX~XX~4a
MrMissedDateCutoffInDentalFile~2014-06-30~CHK5~XX~XX~XX
MrPhys_Mental_DentalFile09~2014-04-30~CHK5~XX~XX~XX
MrPhys_Mental_DentalFile10~2014-04-30~CHK5~XX~XX~XX
MrPhys_Mental_DentalFile_wrong_vers~2014-04-30~CHK5~XX~XX~XX
;
run;


/***** RUN THE PRODUCTION PROGRAM with supplied DHS custody list*****/
%include "%GetParentFolder(0)\Prod08_Assessments_for_DHS_children.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

/***** Now check that the code works given no dental file. *****/
libname M036_Out "&M036_Out."; /*Do this because the test run makes the library read-only.*/

data M150_Tmp.member;
	set M150_Tmp.member;
	if find(Member_ID,'DentalFile','i') eq 0; /*Remove members that pertain to the dental file test, since we will delete the dental file.*/
run;

data M036_Out.members_foster_care;
	set M036_Out.members_foster_care;
	if find(Member_ID,'DentalFile','i') eq 0;
run;

data M150_Tmp.member_time;
	set M150_Tmp.member_time;
	if find(Member_ID,'DentalFile','i') eq 0;
run;

data M150_Tmp.Outclaims_PRM;
	set M150_Tmp.Outclaims_PRM;
	if find(Member_ID,'DentalFile','i') eq 0;
run;

proc datasets noprint library=M150_Tmp;
	delete inpdental;
quit;

/***** RUN THE PRODUCTION PROGRAM with no dental file*****/
%include "%GetParentFolder(0)\Prod08_Assessments_for_DHS_children.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

/***** *Make the DHS custody list blank *****/
%SetupMockLibraries()

data M036_Out.members_foster_care;
	infile datalines delimiter = '~';
	input
		Member_ID :$40.
		Report_Date :YYMMDD10.
		dob :YYMMDD10.
		branch_code :$4.
		Eligibility_Effective_Date :YYMMDD10.
		;
	format Report_Date dob YYMMDDd10. Eligibility_Effective_Date :YYMMDD10.;
datalines;
;
run;

/***** RUN THE PRODUCTION PROGRAM with and empty DHS custody list*****/
%include "%GetParentFolder(0)\Prod08_Assessments_for_DHS_children.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

%put System Return Code = &syscc.;
