/*
### CODE OWNERS: Chas Busenburg

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
%let measure_start_minus_one_year = %sysfunc(INTNX(year,&measure_start.,-1));
%let measure_elig_period = (prm_fromdate ge &measure_start_minus_one_year. and prm_fromdate le &measure_end.);

%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=numerator
    ,Reference_Source=oha_ref.oha_codes
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_excl_temp
    ,Reference_Source=oha_ref.hedis_codes
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_medication
    ,Reference_Source=oha_ref.medications
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_one_visit
    ,Reference_Source=oha_ref.hedis_codes
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_diabetes
    ,Reference_Source=oha_ref.hedis_codes
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_two_visits
    ,Reference_Source=oha_ref.hedis_codes
    );

	
proc sql;
    create table members_ge_eighteen as
    select distinct
        member_id
		,case
			when floor(yrdif(dob, &measure_end., "age")) &age_limit_expression.
			then 1
			else 0
			end
			as age_elig_flag
    from m150_tmp.member
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


    create view denom_exclusion_flags_claims as
    select
        member_id
		,prm_fromdate
        ,case
            when &claims_filter_denom_diabetes.
            then 1
            else 0
            end
            as diab_all_settings
        ,case
            when &claims_filter_denom_excl_temp.
            then 1
            else 0
            end
            as temp_diab_flag
        ,case
            when 
				(&claims_filter_denom_two_visits.)
				and (&claims_filter_denom_diabetes.)
            then 1
            else 0
            end
            as two_visits_flag
        ,case
            when 
				(&claims_filter_denom_one_visit.)
				and (&claims_filter_denom_diabetes.)
            then 1
            else 0
            end
            as one_visit_flag
    from outclaims_prm
	where &measure_elig_period.
    ;
	create view denom_grouped_date as
	select
		member_id
		,prm_fromdate
		,max(diab_all_settings) as diab_all_settings
		,max(temp_diab_flag) as temp_diab_flag
		,max(two_visits_flag) as two_visits_flag
		,max(one_visit_flag) as one_visit_flag
	from denom_exclusion_flags_claims
	group by member_id, prm_fromdate
	;
	
	create view denom_grouped_summed as
	select
		member_id
		,sum(diab_all_settings) as diab_all_settings
		,sum(temp_diab_flag) as temp_diab_flag
		,sum(two_visits_flag) as two_visits_flag
		,sum(one_visit_flag) as one_visit_flag
	from denom_grouped_date
	group by member_id
	;

	create view denom_flags_rxclaims as
	select distinct
		member_id
		,case
			when &claims_filter_denom_medication.
			then 1
			else 0
			end
			as denom_flag
	from outpharmacy_prm
	where &claims_filter_denom_medication
	;
	create view denom_flags_claims as
	select
		member_id
		,case
			when (two_visits_flag ge 2) and (denom_diab_flag ge 1) then 1
			when (one_visit_flag ge 1) and (denom_diab_flag ge 1) then 1
			when (temp_diab_flag ge 1) and (denom_diab_flag ge 1) then 1
			else 0
			end
			as denom_flag
	from denom_grouped_summed
	;

	create view denom_flags as
	select
		member_id
		,max(denom_flag) as denom_flag
	from(
		select * from denom_flags_claims
		union
		select * from denom_flags_rxclaims
	)
	group by member_id
	;

	create table member_time_denom_flags as
	select
		member_time.*
	from m150_tmp.member_time as member_time
	left join denom_flags
	on denom_flags.member_id = member_time.member_id
	where denom_flag = 1
	;

quit;

%FindEligGaps(
	member_time_denom_flags
	,member_elig_gaps
)

proc sql;
	create table member_denom_flags as
	select
		member_id
		,case
			when gap_days &days_enrollment_gap. then 0
			when gap_cnt &bad_number_gaps. then 0
			else 1
			end
			as denom_flag
	from member_elig_gaps
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
	;
quit;
