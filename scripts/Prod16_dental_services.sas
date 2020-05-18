/*
### CODE OWNERS: Ben Copeland

### OBJECTIVE:
    Calculate the Dental Services measures

### DEVELOPER NOTES:

*/

%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2;

libname oha_ref "%sysget(OHA_INCENTIVE_MEASURES_PATHREF)" access=readonly;
libname M150_Out "&M150_Out.";
libname M150_Tmp "&M150_Tmp.";
libname M030_Out "&M030_Out.";

%AssertDataSetExists(M030_Out.InpDental,
                     ReturnMessage=M030_Out.InpDental does not exist.,
                     FailAction=EndActiveSASSession)
                     ;

%CacheWrapperPRM(025,150);
%CacheWrapperPRM(035,150);
%CacheWrapperPRM(073,150);
%let Measure_Name = dental_services;

%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=diagnostic_dental
    ,Reference_Source=oha_ref.oha_codes
);
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=preventive_dental
    ,Reference_Source=oha_ref.oha_codes
);
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=dental_treatment
    ,Reference_Source=oha_ref.oha_codes
);


data age_buckets;
	set m150_tmp.member;

	format
		age_measure 12.
		age_bucket $16.
	;
	age_measure = floor(yrdif(dob, &measure_end., "age"));
	if age_measure lt 1 then age_bucket = '0-1';
	else if age_measure ge 1 and age_measure le 5 then age_bucket = '1_to_5';
	else if age_measure ge 6 and age_measure le 14 then age_bucket = '6_to_14';
	else if age_measure ge 15 and age_measure le 17 then age_bucket = '15_to_17';
	else if age_measure ge 18 and age_measure le 25 then age_bucket = '18_to_25';
	else if age_measure ge 26 and age_measure le 65 then age_bucket = '26_to_65';
	else age_bucket = '65+';
run;

proc sql;
    create table member_time_age_flags as
    select
        member_time.*
		,age_buckets.age_bucket
    from m150_tmp.member_time as member_time
    inner join age_buckets
    on age_buckets.member_id = member_time.member_id
    order by member_id, date_start, date_end
    ;

quit;

data member_time_cont_elig;
	set member_time_age_flags;
	by
		member_id
		date_start
		date_end
	;
	where
		date_end ge &measure_start.
		and date_start le &measure_end.
	;
	date_start = max(date_start, &measure_start.);
	date_end = min(date_end, &measure_end.);

	format
		cont_elig_window_id 12.
		previous_date_end yymmdd10.
		days 12.
	;
	retain
		cont_elig_window_id
		previous_date_end
	;
	if first.member_id then do;
		cont_elig_window_id = 0;
		previous_date_end = .;
	end;

	if (date_start - previous_date_end) ne 1 then cont_elig_window_id + 1;

	days = date_end - date_start + 1;
	previous_date_end = date_end;
run;

proc summary nway missing
	data = member_time_cont_elig;
	class
		member_id
		age_bucket
		cont_elig_window_id
	;
	var
		days
	;
	output
		out = agg_cont_elig_windows
		sum=
	;
run;

%let round_elig_date= %sysfunc(min(&date_latestpaid., &measure_end.));
%let bounded_min_cont_elig_days = %sysfunc(min(%eval(&round_elig_date. - &measure_start.), 180));
%put &=bounded_min_cont_elig_days.;

proc sql;
	create table denom_members
	as select
		distinct member_id, age_bucket
	from agg_cont_elig_windows
	where
		days ge &bounded_min_cont_elig_days.
	;
quit;

proc sql;
	create table dental_flags
	as select
		outclaims_prm.member_id
		,outclaims_prm.providerid
		,providers.prv_taxonomy_cd
		,case
			when &claims_filter_diagnostic_dental.
			then 1
			else 0
		end as diagnostic_dental
		,case
			when &claims_filter_preventive_dental.
			then 1
			else 0
		end as preventive_dental
		,case
			when &claims_filter_dental_treatment.
			then 1
			else 0
		end as dental_treatment
		,max(
			calculated diagnostic_dental
			,calculated preventive_dental
			,calculated dental_treatment
		) as any_dental
	from m030_out.inpdental as outclaims_prm
	left join m150_tmp.providers on
		outclaims_prm.providerid eq providers.prv_id
	where
		outclaims_prm.fromdate ge &measure_start.
		and outclaims_prm.fromdate le &measure_end.
	;
quit;

proc summary nway missing
	data = dental_flags;
	class
		member_id
		prv_taxonomy_cd
	;
	var
		_numeric_
	;
	output
		out=dental_taxonomy_aggs (drop = _type_ _freq_)
		max=
	;
run;

proc sql;
	create table valid_dental_taxonomy_aggs
	as select
		aggs.*
	from dental_taxonomy_aggs as aggs
	inner join oha_ref.dental_taxonomy on
		aggs.prv_taxonomy_cd eq dental_taxonomy.taxonomy_code
	;
quit;

proc summary nway missing
	data = valid_dental_taxonomy_aggs;
	class
		member_id
	;
	var
		_numeric_
	;
	output
		out=member_dental_flags (drop = _type_ _freq_)
		max=
	;
run;

proc sql;
	create table denom_members_flags
	as select
		denom.member_id
		,denom.age_bucket
		,coalesce(dental_flags.any_dental, 0) as any_dental
		,coalesce(dental_flags.diagnostic_dental, 0) as diagnostic_dental
		,coalesce(dental_flags.preventive_dental, 0) as preventive_dental
		,coalesce(dental_flags.dental_treatment, 0) as dental_treatment
		,1 as denominator
	from denom_members as denom
	left join member_dental_flags as dental_flags on
		denom.member_id eq dental_flags.member_id
	;
quit;

proc transpose
	data = denom_members_flags
	out = member_dental_flags_long (rename = (col1 = numerator))
	name = category
	;
	by
		member_id
		age_bucket
		denominator
	;
run;
	
data measure_presentation_prep;
	set member_dental_flags_long;

	format
		short_measure_category $20.
		measure $32.
		comments $128.
		comp_quality_date_actionable yymmddd10.
	;
	if category eq 'any_dental' then short_measure_category = 'any_dental';
	else if category eq 'diagnostic_dental' then short_measure_category = 'diag_dental';
	else if category eq 'preventive_dental' then short_measure_category = 'prev_dental';
	else if category eq 'dental_treatment' then short_measure_category = 'treat_dental';

	measure = catx('_', short_measure_category, age_bucket);

	if numerator eq 0 then comp_quality_date_actionable = &measure_end.;

	comments = '';
run;

data 
	m150_out.results_prev_dental_1_to_5
	m150_out.results_prev_dental_6_to_14
;
	set measure_presentation_prep;

	if measure eq 'prev_dental_1_to_5' then output m150_out.results_prev_dental_1_to_5;
	if measure eq 'prev_dental_6_to_14' then output m150_out.results_prev_dental_6_to_14;
run;


%put System Return Code = &syscc.;
