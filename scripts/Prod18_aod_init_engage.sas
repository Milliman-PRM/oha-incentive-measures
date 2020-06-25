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
	where measure eq "&measure_name." or measure eq "aod_init_engage" or measure eq "hosp_excl";
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

proc sql;
    create table denom_flags_rxclaims as
    select
        member_id
		,claimid
		,prm_fromdate
        ,prm_fromdate as prm_fromdate_case
        ,prm_fromdate as prm_todate_case
		,ndc
		,case
			when (&filter_alcohol_treatment_meds.)
			then 1
			else 0
		end as alcohol_rx_treatment
		,case
			when (&filter_opioid_treatment_meds.)
			then 1
			else 0
		end as opioid_rx_treatment
    from outpharmacy_prm
	;
quit;
		
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
	set
		denom_flags_claims (in = med)
		denom_flags_rxclaims (in = rx)
	;
	format
		claim_source $4.
		alc_episode 12.
		opioid_episode 12.
		other_episode 12.
	;
	if med then claim_source = 'med';
	else claim_source = 'rx';

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
		(alc_abuse_dependence
		and (
			iet_standalone_visits
			or (iet_visits_grp_1 and iet_pos_grp_1)
			or (iet_visits_grp_2 and iet_pos_grp_2)
			or observation
			or ip_stay
			or telephone_visits
			or online_assessments
		))
	) 
	then alc_treatment = 1;
	else alc_treatment = 0;

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
		(opioid_abuse_dependence
		and (
			iet_standalone_visits
			or (iet_visits_grp_1 and iet_pos_grp_1)
			or (iet_visits_grp_2 and iet_pos_grp_2)
			or observation
			or ip_stay
			or telephone_visits
			or online_assessments
		))
	) 
	then opioid_treatment = 1;
	else opioid_treatment = 0;

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

	if (
		other_abuse_dependence
		and (
			iet_standalone_visits
			or (iet_visits_grp_1 and iet_pos_grp_1)
			or (iet_visits_grp_2 and iet_pos_grp_2)
			or observation
			or ip_stay
			or telephone_visits
			or online_assessments
		)
	) 
	then other_treatment = 1;
	else other_treatment = 0;

	if (
		aod_med_treatment
		or alcohol_rx_treatment
	)
	then alc_rx_treatment = 1;
	else alc_rx_treatment = 0;

	if (
		aod_med_treatment
		or opioid_rx_treatment
	)
	then opioid_rx_treatment = 1;
	else opioid_rx_treatment = 0;

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
	;

run;


data AOD_abuse_dep_meds;
	set episodes;
	where 
		(aod_abuse_dependence eq 1) 
		or (aod_med_treatment eq 1) 
		or (alc_rx_treatment eq 1)
		or (opioid_rx_treatment eq 1)
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
	create table member_time_index_eps as
	select
		index_eps.*
		,member_time.date_start
		,member_time.date_end
		,index_eps.prm_todate_case - 60 as cont_elig_start
		,index_eps.prm_todate_case + 48 as cont_elig_end
	from only_index_episodes as index_eps
	left join M150_tmp.member_time as member_time
		on member_time.member_id eq index_eps.member_id
	order by index_eps.member_id, index_eps.prm_todate_case,member_time.date_start
	;
quit;
	

%FindEligGaps(
	member_time_index_eps
	,index_eps_elig_gaps
	,varname_member_date_start=cont_elig_start
	,varname_member_date_end=cont_elig_end
	,extra_by_variables=prm_todate_case
)


proc sql;
	create table denom_med_members as
	select distinct only_index_episodes.member_id
		,only_index_episodes.claimid
		,1 as denom_med
		,negative_history_members.member_id as neg_hist_member_id
		,hospice_members.member_id as hosp_member_id
		,only_index_episodes.prm_todate_case as iesd
		,only_index_episodes.alc_episode
		,only_index_episodes.opioid_episode
		,only_index_episodes.other_episode
	from only_index_episodes
	left join negative_history_members on
		only_index_episodes.member_id eq negative_history_members.member_id
	left join hospice_members on
		only_index_episodes.member_id eq hospice_members.member_id
	left join index_eps_elig_gaps on
		only_index_episodes.member_id eq index_eps_elig_gaps.member_id
	where negative_history_members.member_id eq '' and hospice_members.member_id eq '' and index_eps_elig_gaps.gap_cnt eq 0
	;
quit;

proc sql;
	create table numer_members_init as
	select 
		denom_med_members.*
		,episodes.prm_fromdate_case
		,episodes.prm_todate_case
		,episodes.prm_fromdate - denom_med_members.iesd as days_since_iesd
		,case
			when 
				denom_med_members.alc_episode 
				and (
					episodes.alc_treatment 
					or episodes.alc_rx_treatment
				)
			then 1
			when 
				denom_med_members.opioid_episode 
				and (
					episodes.opioid_treatment
					or episodes.alc_rx_treatment
				)
			then 1
			when denom_med_members.other_episode and episodes.other_treatment
			then 1
			else 0
		end as init_treatment
		,case
			when 
				calculated init_treatment 
				and (calculated days_since_iesd lt 14 and calculated days_since_iesd gt 0) 
				and (episodes.claimid ne denom_med_members.claimid)
			then 1
			else 0
		end as numer_init_treatment
		,episodes.alc_treatment
		,episodes.opioid_treatment
		,episodes.other_treatment
		,episodes.alc_rx_treatment
		,episodes.opioid_rx_treatment
	from denom_med_members
	left join episodes
		on episodes.member_id eq denom_med_members.member_id
	where calculated numer_init_treatment eq 1
	order by denom_med_members.member_id
		,episodes.prm_fromdate_case
		,episodes.prm_todate_case desc
	;
quit;

data  numer_members_init_distinct;
	set numer_members_init;
	by member_id;
	
	if first.member_id;
	;
run;

proc sql;
	create table numer_init_results as
	select
		denom_med_members.*
		,numer_members_init_distinct.prm_todate_case as engage_start_date
		,coalesce(numer_members_init_distinct.numer_init_treatment,0) as numer_init_treatment
		,numer_members_init_distinct.alc_treatment
		,numer_members_init_distinct.opioid_treatment
		,numer_members_init_distinct.other_treatment
		,numer_members_init_distinct.alc_rx_treatment
		,numer_members_init_distinct.opioid_rx_treatment
	from denom_med_members
	left join numer_members_init_distinct
		on denom_med_members.member_id eq numer_members_init_distinct.member_id
	;
quit;


data denom_members_engage;
	set numer_init_results;
	where numer_init_treatment eq 1;
run;

proc sql;
	create table time_limited_engage as
	select
		episodes.*
		,episodes.prm_fromdate_case - denom_members_engage.engage_start_date as days_since_init
	from denom_members_engage
	left join episodes
		on denom_members_engage.member_id eq episodes.member_id
	where calculated days_since_init gt 0 and calculated days_since_init le 34
	;
quit;

proc sql;
	create table numer_engage_agg as
	select
		time_limited_engage.member_id
		,sum(time_limited_engage.alc_rx_treatment) as sum_alc_rx
		,sum(time_limited_engage.opioid_rx_treatment) as sum_opioid_rx
		,sum(time_limited_engage.alc_treatment) as sum_alc_treatment
		,sum(time_limited_engage.opioid_treatment) as sum_opioid_treatment
		,sum(time_limited_engage.other_treatment) as sum_other_treatment
	from time_limited_engage
	group by time_limited_engage.member_id
	;
quit;

proc sql;
	create table numer_engage_results as
	select
		denom_members_engage.member_id
		,case 
			when denom_members_engage.alc_episode
			then numer_engage_agg.sum_alc_treatment

			when denom_members_engage.opioid_episode
			then numer_engage_agg.sum_opioid_treatment

			when denom_members_engage.other_episode
			then numer_engage_agg.sum_other_treatment

			else 0
			end as numer_engage_visits
		,case
			when denom_members_engage.alc_episode
			then numer_engage_agg.sum_alc_rx

			when denom_members_engage.opioid_episode
			then numer_engage_agg.sum_opioid_rx

			else 0
			end as numer_engage_medications
		,case 
			when 
				denom_members_engage.alc_rx_treatment 
				or denom_members_engage.opioid_rx_treatment
			then 1
			else 0
			end as rx_event
		,case
			when 
				calculated rx_event 
				and (calculated numer_engage_visits ge 1) 
				and ((calculated numer_engage_visits + calculated numer_engage_medications) ge 2)
			then 1
			when
				not calculated rx_event
				and (
					(calculated numer_engage_medications ge 1)	
					or (calculated numer_engage_visits ge 2)
				)
			then 1
			else 0
		end as numer_engage_treatment
	from denom_members_engage
	left join numer_engage_agg
		on denom_members_engage.member_id eq numer_engage_agg.member_id
	;
quit;
	

proc sql;
	create table qualifying_visits as
	select
		members.member_id
		,members.age_elig_flag
		,case
			when numer_init_results.numer_init_treatment eq 1 then 'Y'
			else 'N'
			end
			as numer_included_yn_init
		,case
			when denom_med_members.denom_med eq 1 then 'Y'
			else 'N'
			end
			as denom_included_yn_init
		,case 
			when denom_members_engage.numer_init_treatment eq 1 then 'Y'
			else 'N'
			end
			as denom_included_yn_engage
		,case when numer_engage_results.numer_engage_treatment eq 1 then 'Y'
			else 'N'
			end
			as numer_included_yn_engage
		
	from members_ge_eighteen as members
	left join denom_med_members
		on members.member_id eq denom_med_members.member_id
	left join numer_init_results
		on members.member_id eq numer_init_results.member_id
	left join denom_members_engage
		on members.member_id eq denom_members_engage.member_id
	left join numer_engage_results
		on members.member_id eq numer_engage_results.member_id
	where members.age_elig_flag eq "Y"
	;
quit;

proc sql;
	create table members_with_flags_init as
	select 
		members.member_id
		,numer_included_yn_init as numer_included_yn
		,denom_included_yn_init as denom_included_yn
	from m150_tmp.member as members
	left join qualifying_visits as visits on 
		members.member_id eq visits.member_id
	;
quit;

proc sql;
	create table members_with_flags_engage as
	select 
		members.member_id
		,numer_included_yn_engage as numer_included_yn
		,denom_included_yn_engage as denom_included_yn
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
