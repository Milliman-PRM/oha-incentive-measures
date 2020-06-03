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
%let Measure_Name = aod_init_engage;

%let intake_period_start = %sysfunc(MDY(1, 1, %sysfunc(year(&measure_start))));
%let intake_period_end = %sysfunc(MDY(11, 13, %sysfunc(year(&measure_start))));
%put intake_period_start = %sysfunc(putn(&intake_period_start, yymmddd10.));
%put intake_period_end = %sysfunc(putn(&intake_period_end, yymmddd10.));

%let negative_diagnosis_history_days = -60;

%let intake_period_minus_sixty = %sysfunc(INTNX(days,&intake_period_start.,&negative_diagnosis_history_days., same));
%put intake_period_minus_sixty = %sysfunc(putn(&intake_period_minus_sixty, yymmddd10.));
%let measure_elig_period = (prm_fromdate ge &intake_period_minus_sixty. and prm_fromdate le &intake_period_end.);

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
    create table members_ge_eighteen as
    select distinct
        member_id
		,floor(yrdif(dob, &measure_end., "age")) as age
        ,case
            when floor(yrdif(dob, &measure_end., "age")) &age_stratefication.
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

%put &=measure_elig_period.;

/* %macro flag_denom; */
/* proc sql; */
/*     create table denom_flags as */
/*     select */
/*         member_id */
/*         ,prm_fromdate */
/* 		,claimid */
/* 		%let component_cnt = %eval(%sysfunc(countc(&list_components.,%str(~))) + 1); */
/* 		%do i_component = 1 %to &component_cnt.; */
/* 			%let component_current = %scan(&list_components.,&i_component.,%str(~)); */
/* 	        ,case */
/* 	            when (&&filter_&component_current.) */
/* 	            then 1 */
/* 	            else 0 */
/* 	            end */
/* 	            as &component_current. */

/* 		%end; */
/*     from outclaims_prm */
/*     where &measure_elig_period. */
/*     ; */
/* quit; */
/* %mend flag_denom; */

/* %flag_denom; */
/* %put &=filter_detox.; */
/* ,case */
/* 	when denom.denom_included_yn eq 'Y' then 1 */
/* 	else 0 */
/* 	end */
/* 	as Denominator */
/* ,case */
/* 	when numer.numer_included_yn eq 'Y' then 1 */
/* 	else 0 */
/* 	end */
/* 	as Numerator */

proc sql;
	create table M150_Out.Results_&Measure_Name. as
	select
		members.Member_ID
		,0 as Denominator
		,0 as Numerator
		,"No Qualifying Visit" as comment format = $128. length = 128
		,&measure_end as comp_quality_date_actionable format = YYMMDDd10.
	from members_ge_eighteen as members
	;
quit;
