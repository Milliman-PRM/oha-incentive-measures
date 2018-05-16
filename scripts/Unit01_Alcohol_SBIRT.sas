/*
### CODE OWNERS: Aaron Hoch, Shea Parkes, Neil Schneider, Jason Altieri

### OBJECTIVE:
  Test the Alcohol and Drug Misuse (SBIRT) measure computation.

### DEVELOPER NOTES:
  We test more of the CodeGen features here than SBIRT really uses.
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

%let Suppress_Parser = True;
%let DATE_PERFORMANCEYEARSTART = %sysfunc(mdy(1,1,2014));
%let Date_LatestPaid_Round = %sysfunc(mdy(2,28,15));
%let QUALITY_METRICS = OHA_INCENTIVE_MEASURES;


/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/





/**** PERFORM MOCKING ****/

%SetupMockLibraries()


data M015_Out.OHA_codes;
	infile datalines delimiter = '~' dsd;
	input
		Measure :$24.
		Component :$32.
		CodeSystem :$16.
		Code :$16.
		Grouping_ID :$32.
		Diag_Type :$16.
		;
datalines;
Alcohol_SBIRT~DENOMINATOR~CPT~PCP1~~
Alcohol_SBIRT~DENOMINATOR~CPT~PCP2~~
Alcohol_SBIRT~DENOMINATOR~CPT~PCP3~~
Alcohol_SBIRT~NUMERATOR~CPT~CHK1~~
Alcohol_SBIRT~NUMERATOR~CPT~CHK2~~
Alcohol_SBIRT~NUMERATOR~ICD9CM-Diag~DCHK1~~
Alcohol_SBIRT~NUMERATOR~ICD9CM-Diag~DCHK2~~
Alcohol_SBIRT~NUMERATOR~CPT~CPTG1~Group1~
Alcohol_SBIRT~NUMERATOR~ICD9CM-Diag~ICDG1~Group1~
Alcohol_SBIRT~NUMERATOR~CPT~CPTG4~Group42~
Alcohol_SBIRT~NUMERATOR~ICD9CM-Diag~ICDG4~Group42~
Alcohol_SBIRT~NUMERATOR~CPT~CPT2D~GroupW2Diag~
Alcohol_SBIRT~NUMERATOR~ICD9CM-Diag~DG2D1~GroupW2Diag~
Alcohol_SBIRT~NUMERATOR~ICD9CM-Diag~DG2D2~GroupW2Diag~
Alcohol_SBIRT~NUMERATOR~ICD9CM-Proc~PROC1~~
Alcohol_SBIRT~NUMERATOR~ICD9CM-Diag~PRIM1~~Primary
Alcohol_SBIRT~NUMERATOR~ICD9CM-Diag~SEC1~~Secondary
Alcohol_SBIRT~NUMERATOR~ICD10CM-Diag~D10CHK1~~
Alcohol_SBIRT~NUMERATOR~CPT~CPT2D~GroupW2Diag10~
Alcohol_SBIRT~NUMERATOR~ICD10CM-Diag~D10G2D1~GroupW2Diag10~
Alcohol_SBIRT~NUMERATOR~ICD10CM-Diag~D10G2D2~GroupW2Diag10~
Alcohol_SBIRT~NUMER_EXCL~CPT~XCPT1~~
Alcohol_SBIRT~NUMER_EXCL~CPT~XCPT2~~
Alcohol_SBIRT~NUMER_EXCL~UBREV~XREV~~
Alcohol_SBIRT~NUMER_EXCL_PROCS~CPT~XPROC~GROUP1~
Alcohol_SBIRT~NUMER_EXCL_PROCS~POS~XP~GROUP1~
;
run;


data M150_Tmp.member;
    infile datalines delimiter = '~';
    input
        Member_ID :$40.
        DOB :YYMMDD10.
		gender :$1.
		anticipated_denominator :12.
		anticipated_numerator :12.
        ;
	format DOB YYMMDDd10.;
datalines;
MrNoClaims~2001-04-04~M~0~0
MrsAllGood~1990-01-02~F~1~1
MrAllGood~1991-01-02~M~1~1
MrsFail~1995-04-10~F~1~0
MrNoPCP~1980-12-23~M~0~0
MrDeniedPCP~1980-12-23~M~0~0
MrDeniedSBIRT~1975-01-22~M~1~1
MrKid~2010-10-04~M~0~0
MrPCPTooEarly~1942-01-02~M~0~0
MrGroupTest~1990-01-02~M~1~1
MrGroupAlmost~1990-01-02~M~1~0
MrGroupTest42~1990-01-02~M~1~1
MrGroupAlmost42~1990-01-02~M~1~0
MrGroupAlmostCrossGroup~1990-01-02~M~1~0
Mr2DiagGroupSuccess~1990-01-02~M~1~1
Mr2DiagGroupFail~1990-01-02~M~1~0
MrByProc~1990-01-02~M~1~1
MrByPrimaryDiag~1991-01-02~M~1~1
MrMissedPrimaryDiag~1991-01-02~M~1~0
MrBySecondaryDiag~1991-01-02~M~1~1
MrMissedSecondaryDiag~1991-01-02~M~1~0
MrAdolescent~2000-01-01~M~1~0
Mr2Diag10GroupSuccess~1990-01-02~M~1~1
MrsAllGood_icd10~1990-01-02~F~1~1
MrCPTExclusion~1991-01-02~M~1~0
MrRevExclusion~1991-01-02~M~1~0
MrGroup1Exclusion~1991-01-02~M~1~0
MrsExclusionOnDifferentLine~1990-01-02~F~1~1
;
run;


data M150_Tmp.outclaims_prm;
    infile datalines delimiter = '~' missover;
    input
        Member_ID :$40.
        ClaimID :$60.
        LineNum :$3.
        FromDate :YYMMDD10.
        RevCode :$4.
        HCPCS :$5.
        POS :$2.
        ICDDiag1 :$7.
        ICDDiag2 :$7.
        ICDDiag3 :$7.
		PRM_Denied_YN :$1.
        ICDProc1 :$7.
        ICDProc2 :$7.
        ICDProc3 :$7.
        ;
	format FromDate YYMMDDd10.;
datalines;
MrsFail~CLM1~LN1~2014-04-17~ ~PCP1~ ~ ~ ~ ~N
MrsAllGood~CLM1~LN1~2014-08-15~ ~ PCP2~ ~ ~ ~ ~N
MrsAllGood~CLM1~LN1~2014-08-30~ ~ ~ ~ ~DCHK2~ ~N
MrAllGood~CLM1~LN1~2014-07-15~ ~PCP2~ ~ ~ ~ ~N
MrAllGood~CLM1~LN1~2014-07-30~ ~CHK1~ ~ ~ ~ ~N
MrNoPCP~CLM1~LN1~2014-09-30~ ~ ~ ~ ~DCHK2~ ~N
MrDeniedPCP~CLM1~LN1~2014-01-15~ ~PCP2~ ~ ~ ~ ~Y
MrDeniedSBIRT~CLM1~LN1~2014-01-15~ ~PCP2~ ~ ~ ~ ~N
MrDeniedSBIRT~CLM1~LN1~2014-02-15~ ~ ~ ~ ~ ~DCHK1~Y
MrKid~CLM1~LN1~2014-01-15~ ~PCP2~ ~ ~ ~DCHK2~N
MrPCPTooEarly~CLM1~LN1~2013-12-20~ ~PCP1~ ~ ~ ~ ~N
MrGroupTest~CLM1~LN1~2014-04-17~ ~PCP1~ ~ ~ ~ ~N
MrGroupTest~CLM1~LN1~2014-04-17~ ~CPTG1~ ~ ~ICDG1~ ~N
MrGroupAlmost~CLM1~LN1~2014-04-17~ ~PCP1~ ~ ~ ~ ~N
MrGroupAlmost~CLM1~LN1~2014-04-17~ ~CPTG1~ ~ ~ ~ ~N
MrGroupAlmost~CLM1~LN1~2014-04-17~ ~ ~ ~ICDG1~ ~ ~N
MrGroupTest42~CLM1~LN1~2014-04-17~ ~PCP1~ ~ ~ ~ ~N
MrGroupTest42~CLM1~LN1~2014-04-17~ ~CPTG4~ ~ ~ICDG4~ ~N
MrGroupAlmost42~CLM1~LN1~2014-04-17~ ~PCP1~ ~ ~ ~ ~N
MrGroupAlmost42~CLM1~LN1~2014-04-17~ ~CPTG4~ ~ ~ ~ ~N
MrGroupAlmost42~CLM1~LN1~2014-04-17~ ~ ~ ~ICDG4~ ~ ~N
MrGroupAlmostCrossGroup~CLM1~LN1~2014-04-17~ ~PCP1~ ~ ~ ~ ~N
MrGroupAlmostCrossGroup~CLM1~LN1~2014-04-17~ ~CPTG1~ ~ ~ICDG4~ ~N
Mr2DiagGroupSuccess~CLM1~LN1~2014-04-17~ ~PCP1~ ~ ~ ~ ~N
Mr2DiagGroupSuccess~CLM1~LN1~2014-04-17~ ~CPT2D~ ~ ~DG2D2~DG2D1~N
Mr2DiagGroupFail~CLM1~LN1~2014-04-17~ ~PCP1~ ~ ~ ~ ~N
Mr2DiagGroupFail~CLM1~LN1~2014-04-17~ ~CPT2D~ ~ ~DG2D2~ ~N
Mr2DiagGroupFail~CLM1~LN1~2014-04-17~ ~CPT2D~ ~ ~ ~DG2D1~N
MrByProc~CLM1~LN1~2014-07-15~ ~PCP2~ ~ ~ ~ ~N
MrByProc~CLM1~LN1~2014-07-30~ ~ ~ ~ ~ ~ ~N~ ~PROC1
MrByPrimaryDiag~CLM1~LN1~2014-07-15~ ~PCP2~ ~ ~ ~ ~N
MrByPrimaryDiag~CLM1~LN1~2014-07-30~ ~ ~ ~PRIM1~ ~ ~N~ ~
MrMissedPrimaryDiag~CLM1~LN1~2014-07-15~ ~PCP2~ ~ ~ ~ ~N
MrMissedPrimaryDiag~CLM1~LN1~2014-07-30~ ~ ~ ~ ~PRIM1~ ~N~ ~
MrBySecondaryDiag~CLM1~LN1~2014-07-15~ ~PCP2~ ~ ~ ~ ~N
MrBySecondaryDiag~CLM1~LN1~2014-07-30~ ~ ~ ~ ~SEC1~ ~N~ ~
MrMissedSecondaryDiag~CLM1~LN1~2014-07-15~ ~PCP2~ ~ ~ ~ ~N
MrMissedSecondaryDiag~CLM1~LN1~2014-07-30~ ~ ~ ~SEC1~ ~ ~N~ ~
MrAdolescent~CLM1~LN1~2014-07-12~ ~PCP1~ ~ ~ ~ ~N~ ~ ~
Mr2Diag10GroupSuccess~CLM1~LN1~2014-04-17~ ~PCP1~ ~ ~ ~ ~N
Mr2Diag10GroupSuccess~CLM1~LN1~2014-04-17~ ~CPT2D~ ~ ~D10G2D2~D10G2D1~N
MrsAllGood_icd10~CLM1~LN1~2014-08-15~ ~PCP2~ ~ ~ ~ ~N
MrsAllGood_icd10~CLM1~LN1~2014-08-30~ ~ ~ ~ ~D10CHK1~ ~N
MrCPTExclusion~CLM1~LN1~2014-08-30~ ~PCP1~ ~ ~ ~ ~N
MrRevExclusion~CLM1~LN1~2014-08-30~ ~PCP1~ ~ ~ ~ ~N
MrGroup1Exclusion~CLM1~LN1~2014-08-30~ ~PCP1~ ~ ~ ~ ~N
MrsExclusionOnDifferentLine~CLM1~LN1~2014-08-30~ ~PCP1~ ~ ~ ~ ~N
MrCPTExclusion~CLM2~LN1~2014-08-30~ ~XCPT1~ ~DCHK1~ ~ ~N
MrRevExclusion~CLM2~LN1~2014-08-30~XREV~ ~ ~DCHK1~ ~ ~N
MrGroup1Exclusion~CLM2~LN1~2014-08-30~ ~XPROC~XP~DCHK1~ ~ ~N
MrsExclusionOnDifferentLine~CLM2~LN1~2014-08-30~ ~XPROC~ ~DCHK1~ ~ ~N
MrsExclusionOnDifferentLine~CLM2~LN2~2014-08-30~ ~ ~XP~DCHK1~ ~ ~N
;
run;



/**** RUN PRODUCTION PROGRAM ****/

%include "%GetParentFolder(0)\Prod01_Alcohol_SBIRT.sas" / source2;



/**** PERFORM TESTS ****/

%CompareResults()


%put System Return Code = &syscc.;
