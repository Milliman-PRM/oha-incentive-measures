/*
### CODE OWNERS: Ben Copeland, Neil Schneider

### OBJECTIVE:
	Test the ED Visits measure calculation

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\Supp02_Shared_Testing.sas" / source2;

/* Libnames */
%MockLibrary(oha_ref,pollute_global=true)
options set=OHA_INCENTIVE_MEASURES_PATHREF "%sysfunc(pathname(oha_ref))";
%MockLibrary(M035_out,pollute_global=true)
%MockLibrary(M073_out,pollute_global=true)
%MockLibrary(M150_out,pollute_global=true)
%let M130_out = %MockDirectoryGetPath();
%CreateFolder(&M130_out.)
%let M150_tmp = %MockDirectoryGetPath();
%CreateFolder(&M150_tmp.)
%MockLibrary(unittest)

%let suppress_parser = True;
%let date_performanceyearstart = %sysfunc(mdy(1,1,2015));
%let date_latestpaid_round = %sysfunc(mdy(7,31,2015));
%let quality_metrics = oha_incentive_measures;

%let rand_seed = 42;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




/***** SETUP INPUTS *****/
data oha_ref.oha_codes;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		measure :$24.
		component :$32.
		codesystem :$16.
		code :$16.
		grouping_id :$32.
		diag_type :$16.
		;
datalines;
ed_visits|numer_cpt|CPT|CPT-A||
ed_visits|numer_cpt|CPT|CPT-B||
ed_visits|numer_rev|UBREV|REVA||
ed_visits|numer_rev|UBREV|REVB||
ed_visits|Numer_procs|CPT|PROCA|GROUP1|
ed_visits|Numer_procs|CPT|PROCB|GROUP1|
ed_visits|Numer_procs|CPT|PROCC|GROUP1|
ed_visits|Numer_procs|POS|PA|GROUP1|
ed_visits|numer_excl_mh|ICD9CM-Diag|DIAG-A||Primary
ed_visits|numer_excl_mh|ICD9CM-Diag|DIAG-B||Primary
ed_visits|numer_excl_mh|ICD10CM-Diag|DIAG-A0||Primary
ed_visits|numer_excl_mh|ICD10CM-Diag|DIAG-B0||Primary
ed_visits|numer_excl_psych|CPT|XCPTA||
ed_visits|numer_excl_psych|CPT|XCPTB||
ed_visits|Numer_Excl_IP_Stay|UBREV|UBR1||
ed_visits|Denom_Excl_Hospice|CPT|HCPT1||
ed_visits|Denom_Excl_Hospice|UBREV|HREV||
run;

data
	M035_out.member_time (drop = anticipated_:)
	unittest.member (keep = member_id dob anticipated_:)
	;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		member_id :$40.
		dob :YYMMDD10.
		elig_month :YYMMDD10.
		memmos :best12.
		cover_medical :$1.
		anticipated_numerator :best12.
		anticipated_denominator :best12.
		;
	format 
		dob YYMMDDd10.
		elig_month YYMMDDd10.
		;
datalines;
rev_incl|1920-07-01|2015-01-15|1|Y|2|0.002
rev_incl|1920-07-01|2015-02-15|1|Y|2|0.002
cpt_incl|1990-07-01|2015-01-15|1|Y|2|0.002
cpt_incl|1990-07-01|2015-02-15|1|Y|2|0.002
group_incl|1920-07-01|2015-01-15|1|Y|1|0.002
group_incl|1920-07-01|2015-02-15|1|Y|1|0.002
short_mmos|1990-07-01|2015-01-15|1|Y|0|0.001
ip_excl|1920-07-01|2015-01-15|1|Y|0|0.002
ip_excl|1920-07-01|2015-02-15|1|Y|0|0.002
denied_excl|1990-07-01|2015-01-15|1|Y|0|0.002
denied_excl|1990-07-01|2015-02-15|1|Y|0|0.002
mh_excl|1920-07-01|2015-01-15|1|Y|0|0.002
mh_excl|1920-07-01|2015-02-15|1|Y|0|0.002
non_prim_mh|1990-07-01|2015-01-15|1|Y|1|0.002
non_prim_mh|1990-07-01|2015-02-15|1|Y|1|0.002
pysch_excl|1990-07-01|2015-01-15|1|Y|0|0.002
pysch_excl|1990-07-01|2015-02-15|1|Y|0|0.002
no_elig|1920-07-01|2015-01-15|1|N|0|0
elig_after|1990-07-01|2015-05-01|1|Y|0|0
visit_after|1990-07-01|2015-01-01|1|Y|0|0.001
two_day_stay|1990-07-01|2015-02-15|1|Y|1|0.001
two_visits|1990-07-01|2015-02-15|1|Y|2|0.001
mh_excl_icd10|1920-07-01|2015-01-15|1|Y|0|0.002
mh_excl_icd10|1920-07-01|2015-02-15|1|Y|0|0.002
hospice_excl_icd10|1920-07-01|2015-02-15|1|Y|0|0
hospice_excl_rev|1920-07-01|2015-02-15|1|Y|0|0
run;

proc sql;
	create table M035_out.member as
	select distinct
		*
	from unittest.member
	;
quit;
%AssertNoDuplicates(
	M035_out.member
	,member_id
	,ReturnMessage=Member table not set up as expected.
	)

data M073_out.outclaims_prm;
	infile
		datalines
		dsd
		truncover
		delimiter = "|"
		;
	input
		member_id :$40.
		prm_fromdate :YYMMDD10.
		prm_line :$4.
		claimID :$60.
		hcpcs :$5.
		RevCode :$4.
		POS :$2.
		icddiag1 :$7.
		icddiag2 :$7.
		icddiag3 :$7.
		prm_denied_YN :$1.
		;
	format prm_fromdate YYMMDDd10.;
datalines;
rev_incl|2015-02-14|O11a|1|XXXXX|REVA|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
rev_incl|2015-02-15|O11a|2|XXXXX|REVB|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
cpt_incl|2015-02-14|O11a|1|CPT-A|XXXX|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
cpt_incl|2015-02-15|O11a|2|CPT-B|XXXX|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
group_incl|2015-02-14|O11a|1|PROCA|XXXX|PA|XXXXXXX|XXXXXXX|XXXXXXX|N
group_incl|2015-02-15|O11a|2|PROCB|XXXX|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
ip_excl|2015-02-14|O11a|1|CPT-A|REVA|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
ip_excl|2015-02-14|I11a|2|XXXXX|UBR1|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
denied_excl|2015-02-14|O11a|1|XXXXX|REVA|XX|XXXXXXX|XXXXXXX|XXXXXXX|Y
mh_excl|2015-02-14|O11a|1|CPT-A|XXXX|XX|DIAG-A|XXXXXXX|XXXXXXX|N
non_prim_mh|2015-02-14|O11a|1|CPT-A|XXXX|XX|XXXXXXX|DIAG-B|XXXXXXX|N
pysch_excl|2015-02-14|O11a|1|CPT-A|XXXX|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
pysch_excl|2015-02-14|O11a|1|XCPTA|XXXX|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
visit_after|2015-05-14|O11a|1|CPT-A|XXXX|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
two_day_stay|2015-02-14|O11a|1|CPT-A|XXXX|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
two_day_stay|2015-02-15|O11a|1|CPT-B|XXXX|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
two_visits|2015-02-14|O11a|1|XXXXX|REVA|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
two_visits|2015-02-15|O11a|2|XXXXX|REVB|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
mh_excl_icd10|2015-02-14|O11a|1|CPT-A|XXXX|XX|DIAG-A0|XXXXXXX|XXXXXXX|N
hospice_excl_icd10|2015-02-14|O11a|1|XXXXX|REVA|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
hospice_excl_icd10|2015-01-15|P82b|2|HCPT1|XXXX|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
hospice_excl_rev|2015-02-14|O11a|1|XXXXX|REVA|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
hospice_excl_rev|2015-03-15|P82b|2|XXXXX|HREV|XX|XXXXXXX|XXXXXXX|XXXXXXX|N
run;

/*Simulate prediction output by mimicking R write.foreign*/
data _null_;
	set M035_out.member (keep = member_id);
	call streaminit(&rand_seed.);
	where rand("bernoulli",0.95); /*Members are not guaranteed to have predictions*/

	file
		"&M130_out.custom.pred.pop.csv"
		dsd
		delimiter = ","
		;

	er_visits_pred_prob = rand("beta",2,5);

	put
		member_id
		er_visits_pred_prob
		;
run;

data _null_;
	file "&M130_out.custom.pred.pop.sas";
	put "/*";
	put "Generated from program %GetProgramName by %sysget(username) at %sysfunc(strip(%sysfunc(putn(%sysfunc(datetime()),datetime20.))))";
	put "*/";
	put; /*Writes blank line*/
	put "data custom_pred;";
	put 1*"    " "infile %bquote("&M130_out.custom.pred.pop.csv") dsd lrecl=64;";
	put 1*"    " "input member_id :$40. er_visits_pred_prob;";
	put "run;";
run;

/***** RUN THE PRODUCTION PROGRAM *****/
%include "%GetParentFolder(0)Prod05_ED_Visits.sas" / source2;

/***** TEST OUTPUTS *****/
%CompareResults()

proc sql noprint;
	select round(avg(case when prxmatch("/Probability of ED Visit Next 6 Months:/",strip(comments)) ne 0 then 1 else 0 end),0.001)
	into :pct_members_prediction_comments trimmed
	from M150_out.results_&measure_name.
	;
quit;
%put &=pct_members_prediction_comments.;
%AssertThat(&pct_members_prediction_comments.,gt,0.21,ReturnMessage=An unexpected number of members had predictions mentioned in comments.)

/***** RETEST WITHOUT PREDICTIONS *****/
proc datasets library = work kill nolist;
quit;
%EraseFile(&M130_out.custom.pred.pop.sas,prompt=N)
%EraseFile(&M130_out.custom.pred.pop.csv,prompt=N)
%symdel pct_members_prediction_comments;

%include "%GetParentFolder(0)Prod05_ED_Visits.sas" / source2;

proc sql noprint;
    create table Unexpected_results as
        select
            exp.*
            ,coalesce(act.Denominator, 0) as Actual_Denominator
            ,coalesce(act.Numerator, 0) as Actual_Numerator
    from &dset_expected. as exp
    left join M150_Out.ed_visits_all as act
        on exp.member_ID = act.member_ID
    where 
        round(exp.anticipated_denominator,.0001) ne round(calculated Actual_Denominator,.0001)
        or round(exp.anticipated_numerator,.0001) ne round(calculated Actual_Numerator,.0001)
    ;
quit;

%AssertDataSetNotPopulated(Unexpected_results, ReturnMessage=The &Measure_Name. results are not as expected.  Aborting...)

proc sql noprint;
	select round(avg(case when prxmatch("/Probability of ED Visit Next 6 Months:/",strip(comments)) ne 0 then 1 else 0 end),0.001)
	into :pct_members_prediction_comments trimmed
	from M150_out.ed_visits_all
	;
quit;
%put &=pct_members_prediction_comments.;
%AssertThat(&pct_members_prediction_comments.,eq,0,ReturnMessage=No predicitons should be mentioned in comments when predictions are not available.)

%put System Return Code = &syscc.;
