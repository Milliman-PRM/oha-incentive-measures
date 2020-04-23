/*
### CODE OWNERS: Chas Busenburg, Ben Copeland

### OBJECTIVE:
    Calculate the Oral-Evaluation for Adults with Diabetes

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

%CacheWrapperPRM(035,150);
%CacheWrapperPRM(073,150);
%FindICDFieldNames()
%let Measure_Name = diabetes_oral_eval;
%let age_limit_expression= ge 18;
%let days_enrollment_gap = gt 45;
%let bad_number_gaps = ge 2;

%let measure_start_minus_one_year = %sysfunc(INTNX(year,&measure_start.,-1, same));
%put measure_start_minus_one_year=%sysfunc(putn(&measure_start_minus_one_year, yymmddd10.));
%let measure_end_minus_one_year = %sysfunc(INTNX(year,&measure_end.,-1, same));
%put measure_end_minus_one_year=%sysfunc(putn(&measure_end_minus_one_year, yymmddd10.));
%let measure_elig_period = (prm_fromdate ge &measure_start_minus_one_year. and prm_fromdate le &measure_end.);

%let path_hedis_components = %sysget(OHA_INCENTIVE_MEASURES_HOME)scripts\hedis\measure_mapping.csv;
%put &=path_hedis_components.;
%let path_medication_components = %sysget(OHA_INCENTIVE_MEASURES_HOME)scripts\medications\measure_mapping.csv;
%put &=path_medication_components.;

%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=numerator
    ,Reference_Source=oha_ref.oha_codes
);

proc import
	file = "&path_hedis_components."
	out = hedis_components
	dbms = csv
	replace
	;
run;
proc import
	file = "&path_medication_components."
	out = medication_components
	dbms = csv
	replace
	;
run;

data components;
	set
		hedis_components (
			keep = measure component
			in = hedis
		)
		medication_components (
			keep = measure component
			in = medication
		)
	;
	format source $32.;
	if hedis then source = 'oha_ref.hedis_codes';
	else if medication then source = 'oha_ref.medications';

	format name_output_var $32.;
	name_output_var = cats('filter_', component);

	format macro_call $256.;
	macro_call = cats(
		'%nrstr('
		,'%CodeGenClaimsFilter('
		,measure
		,','
		,'component='
		,component
		,','
		,'reference_source='
		,source
		,','
		,'name_output_var='
		,name_output_var
		,'));'
	);
run;

data _null_;
	set components;

	call execute(macro_call);
run;

proc sql noprint;
	select
		component
	into
		:list_components separated by '~'
	from components
	where source ne 'oha_ref.medications'
	;
quit;
%put &=list_components;

proc sql;
    create table members_ge_eighteen as
    select distinct
        member_id
		,floor(yrdif(dob, &measure_end., "age")) as age
        ,case
            when floor(yrdif(dob, &measure_end., "age")) &age_limit_expression.
            then 1
            else 0
            end
            as age_elig_flag
    from m150_tmp.member
    order by member_id
    ;

    create view outclaims_prm as
    select
        claims.*
    from m150_tmp.outclaims_prm as claims
    inner join members_ge_eighteen as ge_eighteen
    on ge_eighteen.member_id = claims.member_id
    where ge_eighteen.age_elig_flag = 1
    ;

    create view outpharmacy_prm as
    select
        claims.*
    from m150_tmp.outpharmacy_prm as claims
    inner join members_ge_eighteen as ge_eighteen
    on ge_eighteen.member_id = claims.member_id
    where ge_eighteen.age_elig_flag = 1
    ;
quit;


%macro flag_denom;
proc sql;
    create table denom_flags as
    select
        member_id
        ,prm_fromdate
		,claimid
		%let component_cnt = %eval(%sysfunc(countc(&list_components.,%str(~))) + 1);
		%do i_component = 1 %to &component_cnt.;
			%let component_current = %scan(&list_components.,&i_component.,%str(~));
	        ,case
	            when (&&filter_&component_current.)
	            then 1
	            else 0
	            end
	            as &component_current.

		%end;
    from outclaims_prm
    where &measure_elig_period.
    ;
quit;
%mend flag_denom;

%flag_denom;
		
proc sql noprint;
	select
		name
	into
		:orig_flags_list separated by ' '
	from
		sashelp.vcolumn
	where
		lowcase(memname) eq 'denom_flags'
		and lowcase(type) eq 'num'
		and lowcase(name) ne 'prm_fromdate'
	;
quit;
%put &=orig_flags_list.;

proc summary nway missing
	data = denom_flags;
	class
		member_id
		prm_fromdate
		claimid
	;
	var &orig_flags_list.;
	output
		out=denom_flags_claims (drop = _type_ _freq_)
		max=
	;
run;

data denom_derived_flags;
	set denom_flags_claims;

	format
		acute_ip_diabetes 12.
		nonacute_ip_diabetes 12.
		other_outpatient_non_tele 12.
		other_outpatient_tele 12.
		telephone_diabetes 12.
		online_assessments_diabetes 12.
		acute_ip_advanced_illness 12.
		any_outpatient_advanced_illness 12.
	;
	if (
		acute_inpatient
		and diabetes
		and not (telehealth_modifier or telehealth_pos)
	)
	then acute_ip_diabetes = 1;
	else acute_ip_diabetes = 0;

	if (
		nonacute_inpatient
		and diabetes
		and not (telehealth_modifier or telehealth_pos)
	)
	then nonacute_ip_diabetes = 1;
	else nonacute_ip_diabetes = 0;

	if (
		(outpatient or observation or ed)
		and diabetes
		and not (telehealth_modifier or telehealth_pos)
	)
	then other_outpatient_non_tele = 1;
	else other_outpatient_non_tele = 0;

	if (
		(outpatient or observation or ed)
		and diabetes
		and (telehealth_modifier or telehealth_pos)
	)
	then other_outpatient_tele = 1;
	else other_outpatient_tele = 0;

	if (
		telephone_visits
		and diabetes
	)
	then telephone_diabetes = 1;
	else telephone_diabetes = 0;

	if (
		online_assessments
		and diabetes
	)
	then online_assessments_diabetes = 1;
	else online_assessments_diabetes = 0;

	if (
		acute_inpatient
		and advanced_illness
	)
	then acute_ip_advanced_illness = 1;
	else acute_ip_advanced_illness = 0;

	if (
		(outpatient or observation or ed or nonacute_inpatient)
		and advanced_illness
	)
	then any_outpatient_advanced_illness = 1;
	else any_outpatient_advanced_illness = 0;

	format
		two_visits_non_tele 12.
		two_visits_tele 12.
	;
	two_visits_non_tele = max(
		nonacute_ip_diabetes
		,other_outpatient_non_tele
	);
	two_visits_tele = max(
		other_outpatient_tele
		,telephone_diabetes
		,online_assessments_diabetes
	);

	format
		time_period $16.
	;
	if (
		prm_fromdate ge &measure_start_minus_one_year.
		and prm_fromdate le &measure_end_minus_one_year.
	)
	then time_period = 'prior_year';
	if (
		prm_fromdate ge &measure_start.
		and prm_fromdate le &measure_end.
	)
	then time_period = 'current_year';
run;
		
proc sql noprint;
	select
		name
	into
		:all_flags_list separated by ' '
	from
		sashelp.vcolumn
	where
		lowcase(memname) eq 'denom_derived_flags'
		and lowcase(type) eq 'num'
		and lowcase(name) ne 'prm_fromdate'
	;
quit;
%put &=all_flags_list.;

proc summary nway missing
	data = denom_derived_flags;
	class
		member_id
		time_period
		prm_fromdate
	;
	var
		&all_flags_list.
	;
	output
		out=denom_date_flags (drop = _type_ _freq_)
		max=
	;
run;


proc summary nway missing
	data = denom_derived_flags (drop = prm_fromdate);
	class
		member_id
		time_period
	;
	var
		&all_flags_list.
	;
	output
		out=denom_time_period_flags (drop = _type_ _freq_)
		sum=
	;
run;

data denom_med_eligible;
	set denom_time_period_flags;
	where time_period ne '';

	if (
		acute_ip_diabetes ge 1
		or two_visits_non_tele ge 2
		or (
			two_visits_non_tele ge 1
			and two_visits_tele ge 1
		)
	);
run;

proc sql;
	create table denom_med_members
	as select
		distinct member_id
		,1 as denom_med
	from denom_med_eligible
	;
quit;

proc sql;
    create view denom_flags_rxclaims as
    select distinct
        member_id
        ,1 as denom_rx_flag
    from outpharmacy_prm
    where
        (&filter_diabetes_medications.)
        and (&measure_elig_period.)
    order by member_id
	;
    create view denom_excl_flags_rxclaims as
    select distinct
        member_id
        ,1 as denom_rx_excl_flag
    from outpharmacy_prm
    where
        (&filter_dementia_medications.)
        and (&measure_elig_period.)
    order by member_id
    ;
quit;

proc sql;
	create table denom_members
	as select
		distinct member_id
	from (
		select member_id from denom_med_members
	) union (
		select member_id from denom_flags_rxclaims
	);
quit;

proc sql;
	create table denom_time_period_age
	as select
		time_period.*
		,member.age
		,rx_excl.denom_rx_excl_flag
		,denom_med.denom_med
		,case
			when time_period.time_period eq 'prior_year' then 0
			when time_period.time_period eq 'current_year' then 1
			else 0
			end as sort_order

	from denom_time_period_flags as time_period
	left join members_ge_eighteen as member on
		time_period.member_id eq member.member_id
	left join denom_excl_flags_rxclaims as rx_excl on
		time_period.member_id eq rx_excl.member_id
	left join denom_med_members as denom_med on
		time_period.member_id eq denom_med.member_id
	order by
		time_period.member_id
		,calculated sort_order
	;
quit;

data denom_exclusions;
	set denom_time_period_age;
	by
		member_id
		sort_order
	;
	where time_period ne '';

	format
		retain_acute_ip_advanced_illness 12.
		retain_count_op_advanced_illness 12.
		retain_diabetes 12.
		retain_diabetes_exclusions 12.
	;
	retain
		retain_acute_ip_advanced_illness
		retain_count_op_advanced_illness
		retain_diabetes
		retain_count_op_advanced_illness
	;
	if first.member_id then do;
		retain_acute_ip_advanced_illness = 0;
		retain_count_op_advanced_illness = 0;
		retain_diabetes = 0;
		retain_diabetes_exclusions = 0;
	end;


	format
		exclusion_category $32.
	;
	if (
		time_period eq 'current_year'
		and (
			hospice_encounter
			or hospice_intervention
		)
	)
	then exclusion_category = 'hospice';

	retain_acute_ip_advanced_illness = retain_acute_ip_advanced_illness + acute_ip_advanced_illness;
	retain_count_op_advanced_illness = retain_count_op_advanced_illness + any_outpatient_advanced_illness;
	retain_diabetes = retain_diabetes + diabetes;
	retain_diabetes_exclusions = retain_diabetes_exclusions + diabetes_exclusions;

	if (
		age ge 66
		and (
			time_period eq 'current_year'
			and (
				frailty_device
				or frailty_diagnosis
				or frailty_encounter
				or frailty_symptom
			)
		)
		and (
			retain_acute_ip_advanced_illness ge 1
			or retain_count_op_advanced_illness ge 2
			or denom_rx_excl_flag
		)
	)
	then exclusion_category = 'frailty_advanced_illness';

	if (
		last.member_id
		and retain_diabetes_exclusions
		and not retain_diabetes
	)
	then exclusion_category = 'diabetes_exclusions';

	if exclusion_category ne '' then output;
run;

proc sql;
	create table denom_exclusion_members
	as select
		distinct member_id
		,1 as denom_excl
	from denom_exclusions
	;
quit;


proc sql;
    create table member_time_denom_flags as
    select
        member_time.*
    from m150_tmp.member_time as member_time
    inner join denom_members
    on denom_members.member_id = member_time.member_id
    order by member_id, date_start, date_end
    ;

quit;

%let round_elig_date= %sysfunc(min(&date_latestpaid., &measure_end.));

%FindEligGaps(
    member_time_denom_flags
    ,member_elig_gaps
    ,global_date_end=&round_elig_date.
)

proc sql;
    create table member_denom_flags as
    select
        member_elig_gaps.member_id
        ,case
            when gap_days &days_enrollment_gap. then 0
            when gap_cnt &bad_number_gaps. then 0
			when denom_excl then 0
            else 1
            end
            as denom_flag
    from member_elig_gaps
	left join denom_exclusion_members as denom_excl on
	member_elig_gaps.member_id eq denom_excl.member_id
    ;
    create table member_numer_flags as
    select
        member_id
        ,case
            when &claims_filter_numerator. then 1
            else 0
            end
            as numer_flag
    from m030_out.inpDental as outclaims_prm
	where
		fromdate ge &measure_start.
		and fromdate le &measure_end.
    ;

    create table member_numer_flags_grouped as
    select
        member_id
        ,max(numer_flag) as numer_flag
    from member_numer_flags
    group by member_id
    ;

    create table m150_out.Results_&Measure_Name. as
    select
        members.member_id
        ,case
            when numer_flag = 1 then 1
            else 0
            end
            as numerator
        ,case
            when denom_flag = 1 then 1
            else 0
            end
            as denominator
    from m150_tmp.member as members
    left join member_numer_flags_grouped as numer
    on members.member_id = numer.member_id
    left join member_denom_flags as denom
    on members.member_id = denom.member_id
    where denom_flag eq 1
    ;
quit;

%put System Return Code = &syscc.;
