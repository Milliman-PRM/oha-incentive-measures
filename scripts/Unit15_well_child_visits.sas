/*
### CODE OWNERS: Ben Copeland, Matthew Hawthorne

### OBJECTIVE:
  Test the Well Child Visits measure computation.

### DEVELOPER NOTES:
  <None>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

%let Suppress_Parser = True;
%let DATE_PERFORMANCEYEARSTART = %sysfunc(mdy(1,1,2020));
%let Date_LatestPaid_Round = %sysfunc(mdy(2,28,2021));
%let QUALITY_METRICS = OHA_INCENTIVE_MEASURES;


/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/


/**** SETUP MOCKING ****/

%SetupMockLibraries()
options set=OHA_INCENTIVE_MEASURES_PATHREF "%sysfunc(pathname(oha_ref))";

data oha_ref.hedis_codes;
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
well_child_visits~well_care~CPT~CHK1~~
well_child_visits~well_care~CPT~CHK2~~
well_child_visits~well_care~ICD10CM-Diag~D10CHK1~~
well_child_visits~well_care~ICD10CM-Diag~D10CHK2~~
well_child_visits~telehealth_modifier~Modifier~TH~~
well_child_visits~telehealth_pos~POS~02~~
well_child_visits~hospice_encounter~UBREV~HSPE~~
well_child_visits~hospice_intervention~CPT~HSPCI~~
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
MrAllGood~2016-01-01~1~1
MrTooOld~1945-01-01~0~0
MrTooYoung~2019-01-01~0~0
MrTwoGaps~2016-01-01~0~0
MrOneBigGap~2016-01-01~0~0
MrOneSmallGap~2016-03-03~1~1
MrDiagBased~2016-01-01~1~1
MrDeniedChk~2016-01-01~1~1
MrChkTooEarly~2016-01-01~1~0
MrIncorrectCode~2016-01-01~1~0
MrHospiceExcludedCPT~2016-01-01~0~0
MrHospiceExcludedREV~2016-01-01~0~0
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
MrAllGood~2019-01-01~2020-07-01
MrAllGood~2020-07-02~2021-01-01
MrTooOld~2019-01-01~2021-01-01
MrTooYoung~2019-01-01~2021-01-01
MrTwoGaps~2019-01-01~2020-02-01
MrTwoGaps~2020-02-04~2020-08-01
MrTwoGaps~2020-08-04~2020-12-31
MrOneBigGap~2020-01-01~2020-02-01
MrOneBigGap~2020-07-01~2020-12-31
MrOneSmallGap~2019-01-01~2020-07-01
MrOneSmallGap~2020-07-13~2021-01-01
MrDiagBased~2020-01-01~2020-12-31
MrDeniedChk~2020-01-01~2020-12-31
MrChkTooEarly~2020-01-01~2020-12-31
MrIncorrectCode~2020-01-01~2020-12-31
MrHospiceExcludedCPT~2019-01-01~2021-01-01
MrHospiceExcludedREV~2019-01-01~2021-01-01
;
run;

data M150_Tmp.outclaims_prm;
	infile datalines delimiter = '~' dsd;
	input
		Member_ID :$40.
		FromDate :YYMMDD10.
		RevCode :$4.
		HCPCS :$5.
		ICDDiag1 :$7.
		ICDDiag2 :$7.
		ICDDiag3 :$7.
		PRM_Denied_YN :$1.
		POS :$2.
		modifier :$2.
		modifier2 :$2.
		;
	format FromDate YYMMDDd10.;
datalines;
MrAllGood~2020-04-17~~CHK1~ ~ ~ ~N~~~
MrTooOld~2020-04-17~~CHK1~ ~ ~ ~N~~~
MrTwoGaps~2020-04-17~~CHK1~ ~ ~ ~N~~~
MrOneBigGap~2020-04-17~~CHK1~ ~ ~ ~N~~~
MrOneSmallGap~2020-04-17~~CHK1~ ~ ~ ~N~~~
MrDiagBased~2020-04-16~~ ~D10CHK1~ ~ ~N~~~
MrDeniedChk~2020-04-17~~CHK1~ ~ ~ ~Y~~~
MrChkTooEarly~2019-04-17~~CHK1~ ~ ~ ~N~~~
MrIncorrectCode~2020-04-17~~NoCHK~ ~ ~ ~N~~~
MrHospiceExcludedCPT~2020-04-20~~HSPCI~~ ~ ~N~~~
MrHospiceExcludedREV~2020-04-20~HSPE~~~ ~ ~N~~~
;
run;



/**** TEST WITH CLEAN ELIG END ****/

%let empirical_elig_date_end = %sysfunc(mdy(12,31,2020));
%DeleteWorkAndResults()
%include "%GetParentFolder(0)\Prod15_well_child_visits.sas" / source2;
%CompareResults()



/**** TEST WITH EXTRA ELIG RUNOUT ****/

%let empirical_elig_date_end = %sysfunc(mdy(3,01,2021));
%DeleteWorkAndResults()
%include "%GetParentFolder(0)\Prod15_well_child_visits.sas" / source2;
%CompareResults()



/**** TEST WITH TRUNCATED ELIG ****/

%let empirical_elig_date_end = %sysfunc(mdy(06,30,2020));
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

%include "%GetParentFolder(0)\Prod15_well_child_visits.sas" / source2;
%CompareResults()


%put System Return Code = &syscc.;
