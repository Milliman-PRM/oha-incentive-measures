/*
### CODE OWNERS: Chas Busenburg,

### OBJECTIVE:
	Calculate the initiation and engagement of alcohol and other drug abuse/dependence

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

%CacheWrapperPRM(035,150);
%CacheWrapperPRM(073,150);
%FindICDFieldNames()
%let Measure_Name = aod;

%let intake_period_start = %sysfunc(MDY(1, 1, %sysfunc(year(&measure_start))));
%let intake_period_end = %sysfunc(MDY(11, 13, %sysfunc(year(&measure_start))));
%put intake_period_start = %sysfunc(putn(&intake_period_start, yymmddd10.));
%put intake_period_end = %sysfunc(putn(&intake_period_end, yymmddd10.));

%let negative_diagnosis_history_days = -60;

%let intake_period_minus_sixty = %sysfunc(INTNX(days,&intake_period_start.,&negative_diagnosis_history_days., same));
%put intake_period_minus_sixty = %sysfunc(putn(&intake_period_minus_sixty, yymmddd10.));
%let measure_elig_period = (prm_fromdate ge &intake_period_minus_sixty. and prm_fromdate le &measure_end.);
%let measure_year_period = (prm_fromdate_case ge &measure_start. and prm_fromdate_case le &measure_end.);

%let direct_transfer_days = le 1;
%let age_stratefication = ge 18;

%let path_hedis_components = %sysget(OHA_INCENTIVE_MEASURES_HOME)scripts\hedis\measure_mapping.csv;
%put &=path_hedis_components.;
%let path_medication_components = %sysget(OHA_INCENTIVE_MEASURES_HOME)scripts\medications\measure_mapping.csv;
%put &=path_medication_components.;


data hedis_components;
	infile "&path_hedis_components." delimiter=',' TRUNCOVER DSD firstobs=2;
	input 
		Measure :$32.
		Value_Set_Name :$256.
		Component :$25.
	;
run;


data medication_components;
	infile "&path_medication_components." delimiter=',' TRUNCOVER DSD firstobs=2;
	input 
		Measure :$32.
		Medication_List_Name :$256.
		Component :$25.
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
	where measure eq "&measure_name." or measure eq "hosp_excl";
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

proc sql;
	create table outclaims_elig_period as
	select
		claims.*
	from m150_tmp.outclaims_prm as claims
	where &measure_elig_period.
	;
quit;

proc sql;
    create table members_ge_eighteen as
    select distinct
        member_id
		,floor(yrdif(dob, &measure_end., "age")) as age
        ,case
            when floor(yrdif(dob, &measure_end., "age")) &age_stratefication.
            then "Y"
            else "N"
            end
            as age_elig_flag
	,dob
    from m150_tmp.member
    order by member_id
    ;

    create view outclaims_prm as
    select
        claims.*
    from outclaims_elig_period as claims
    inner join members_ge_eighteen as ge_eighteen
    on ge_eighteen.member_id = claims.member_id
    where ge_eighteen.age_elig_flag = "Y"
    ;

    create view outpharmacy_prm as
    select
        claims.*
    from m150_tmp.outpharmacy_prm as claims
    inner join members_ge_eighteen as ge_eighteen
    on ge_eighteen.member_id = claims.member_id
    where ge_eighteen.age_elig_flag = "Y"
    ;
quit;

%put &=measure_elig_period.;


%macro flag_denom;
proc sql;
    create table denom_flags as
    select
        outclaims_prm.member_id
	,outclaims_prm.caseadmitid
        ,outclaims_prm.prm_fromdate
	,outclaims_prm.prm_fromdate_case
	,outclaims_prm.prm_todate_case
	,intck('days', &intake_period_start., prm_todate_case) as days_since_ips
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
    order by outclaims_prm.member_id asc, outclaims_prm.prm_fromdate_case asc, outclaims_prm.prm_todate_case asc 
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
		and lowcase(name) ne 'prm_fromdate_case'
	;
quit;
%put &=orig_flags_list.;

proc summary nway missing
	data = denom_flags;
	class
		member_id
		prm_fromdate_case
		claimid
	;
	var &orig_flags_list.;
	output
		out=denom_flags_claims (drop = _type_ _freq_)
		max=
	;
run;

data episodes;
	set denom_flags_claims;
	format
		alc_episode 12.
		opioid_episode 12.
		other_episode 12.
	;

	if (
		alc_abuse_dependence
		and (
			iet_standalone_visits
			or (iet_visits_grp_1 and iet_pos_grp_1)
			or (iet_visits_grp_2 and iet_pos_grp_2)
			or detox
			or ed
			or observation
			or ip_stay
			or telephone_visits
			or online_assessments
		)
	) 
	then alc_episode = 1;
	else alc_episode = 0;

	if (
		opioid_abuse_dependence
		and (
			iet_standalone_visits
			or (iet_visits_grp_1 and iet_pos_grp_1)
			or (iet_visits_grp_2 and iet_pos_grp_2)
			or detox
			or ed
			or observation
			or ip_stay
			or telephone_visits
			or online_assessments
		)
	)
	then opioid_episode = 1;
	else opioid_episode = 0;

	if (
		other_abuse_dependence
		and (
			iet_standalone_visits
			or (iet_visits_grp_1 and iet_pos_grp_1)
			or (iet_visits_grp_2 and iet_pos_grp_2)
			or detox
			or ed
			or observation
			or ip_stay
			or telephone_visits
			or online_assessments
		)
	)
	then other_episode = 1;
	else other_episode = 0;
			

run;

data  index_episodes;
	set episodes;
	where (alc_episode eq 1) or (opioid_episode eq 1) or (other_episode eq 1);
	by member_id;
	
	retain index_bool;

	if first.member_id then index_bool = 0;

	if (days_since_ips ge 0) and (index_bool eq 0)	
	then 
		do;
			index_episode = 1; 
			index_bool = 1;
		end;
	else index_episode = 0;

	/* if index_episode eq 1; */
	;

run;


data AOD_abuse_dep_meds;
	set denom_flags_claims;
	where (aod_abuse_dependence eq 1) or (aod_med_treatment eq 1);
	;
run;
proc sql;
	create table hospice_members as
	select distinct member_id
	from denom_flags_claims
	where ((hospice_encounter eq 1) or (hospice_intervention eq 1)) and &measure_year_period.;
	;
quit;

data only_index_episodes;
	set index_episodes;
	where index_episode eq 1;
	;
run;

proc sql;
	create table negative_history_members as
	select distinct only_index_episodes.member_id
	from only_index_episodes as index_eps
	left join AOD_abuse_dep_meds on 
		only_index_episodes.member_id eq AOD_abuse_dep_meds.member_id
	where 
		(intck('days',AOD_abuse_dep_meds.prm_fromdate_case,only_index_episodes.prm_fromdate_case) lt 60) 
		and (intck('days', AOD_abuse_dep_meds.prm_fromdate_case,only_index_episodes.prm_fromdate_case) gt 0);
	;
quit;

proc sql;
	create table denom_med_members as
	select distinct only_index_episodes.member_id
		,1 as denom_med
		,negative_history_members.member_id as neg_hist_member_id
		,hospice_members.member_id as hosp_member_id
	from only_index_episodes
	left join negative_history_members on
		only_index_episodes.member_id eq negative_history_members.member_id
	left join hospice_members on
		only_index_episodes.member_id eq hospice_members.member_id
	where negative_history_members.member_id eq '' and hospice_members.member_id eq ''
	;
quit;

	
proc sql;
	create table qualifying_visits as
	select
		members.member_id
		,'Y' as numer_included_yn
		,case
			when denom_med_members.denom_med eq 1 then 'Y'
			else 'N'
			end
			as denom_included_yn
	from members_ge_eighteen as members
	left join denom_med_members
		on members.member_id eq denom_med_members.member_id
	where members.age_elig_flag eq "Y"
	;
quit;

proc sql;
	create table members_with_flags_init as
	select visits.*
	from m150_tmp.member as members
	left join qualifying_visits as visits on 
		members.member_id eq visits.member_id
	;
quit;

proc sql;
	create table members_with_flags_engage as
	select visits.*
	from m150_tmp.member as members
	left join qualifying_visits as visits on 
		members.member_id eq visits.member_id
	;
quit;
		

proc sql;
	create table M150_Out.Results_&Measure_Name._init as
	select
		members_init.Member_ID
		,case
			when members_init.numer_included_yn eq 'Y' then 1
			else 0
			end
			as Numerator
		,case
			when members_init.denom_included_yn eq 'Y' then 1
			else 0
			end
			as Denominator
		,"No Qualifying Visit" as comment format = $128. length = 128
		,&measure_end as comp_quality_date_actionable format = YYMMDDd10.
	from members_with_flags_init as members_init
	;
quit;

proc sql;
	create table M150_Out.Results_&Measure_Name._engage as
	select
		members_engage.Member_ID
		,case
			when members_engage.numer_included_yn eq 'Y' then 1
			else 0
			end
			as Numerator
		,case
			when members_engage.denom_included_yn eq 'Y' then 1
			else 0
			end
			as Denominator
		,"No Qualifying Visit" as comment format = $128. length = 128
		,&measure_end as comp_quality_date_actionable format = YYMMDDd10.
	from members_with_flags_engage as members_engage
	;
quit;
