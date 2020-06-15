/*
### CODE OWNERS: Ben Copeland

### OBJECTIVE:
    Calculate the Timeliness of Prenatal and Postpartum Care

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

%let Measure_Name = prenatal_postpartum_care;

%let intake_period_start = %sysfunc(INTNX(days,&measure_start.,-85));
%put intake_period_start=%sysfunc(putn(&intake_period_start, yymmddd10.));
%let intake_period_end = %eval(%sysfunc(INTNX(year,&intake_period_start.,1, same)) - 1);
%put intake_period_end=%sysfunc(putn(&intake_period_end, yymmddd10.));

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
	where
		measure eq "&measure_name."
		and lowcase(component) not in (
			"pregnancy_diagnosis" /*too long to fit in macro*/
			,"cervical_cytology_result" /*no valid claims codes*/
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
	;
quit;
%put &=list_components;

%macro flag_denom;
proc sql;
    create table denom_flags as
    select
        member_id
        ,prm_fromdate
		,prm_todate
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
    from m150_tmp.outclaims_prm
    ;
quit;
%mend flag_denom;
%flag_denom;

proc sql;
	create table deliveries
	as select distinct
		member_id
		,prm_fromdate
		,prm_todate
		,prm_todate + 60 as delivery_window_end format = yymmddd10.
	from denom_flags
	where 
		deliveries eq 1
		and prm_todate ge &intake_period_start.
		and prm_todate le &intake_period_end.
	order by
		member_id
		,prm_fromdate
		,prm_todate
	;
quit;

data delivery_ids;
	set deliveries;
	by
		member_id
		prm_fromdate
		prm_todate
	;

	format
		delivery_id 12.
		retain_window_end yymmddd10.
	;
	retain
		delivery_id
		retain_window_end
	;
	if first.member_id then do;
		delivery_id = 0;
		retain_window_end = delivery_window_end;
	end;

	if (
		not first.member_id
		and prm_todate gt retain_window_end
	)
	then do;
		delivery_id = delivery_id + 1;
		retain_window_end = delivery_window_end;
	end;
run;

proc summary nway missing
	data = delivery_ids;
	class
		member_id
		delivery_id
	;
	var
		prm_todate
	;
	output
		out = delivery_dates (rename = (prm_todate = delivery_date))
		max=
	;
run;

data cont_enroll_deliveries;
	set delivery_dates;

	format
		ce_start_date yymmddd10.
		ce_end_date yymmddd10.
	;
	ce_start_date = prm_todate - 43;
	ce_end_date = prm_todate + 60;
run;

proc sql;
	create table delivery_member_time
	as select
		deliveries.*
		,member_time.date_start
		,member_time.date_end
	from cont_enroll_deliveries as deliveries
	left join m150_tmp.member_time on
		deliveries.member_id eq member_time.member_id
	where
		member_time.cover_medical eq 'Y'
	order by
		deliveries.member_id
		,deliveries.delivery_date
		,member_time.date_start
	;
quit;

%FindEligGaps(
	delivery_member_time
	,delivery_elig_gaps
	,varname_member_date_start=ce_start_date
	,varname_member_date_end=ce_end_date
	,extra_by_variables=delivery_date
);

proc sql;
	create table denom_delivery_gaps
	as select
		denom.*
		,delivery.delivery_date
		,delivery.gap_cnt
	from denom_flags as denom
	left join delivery_elig_gaps as delivery on
		denom.member_id eq delivery.member_id
	;
quit;


data denom_derived_flags;
	set denom_flags;

	format
		live_birth 12.
		prenatal_visit 12.
		postpartum_visit 12.
		hospice 12.
	;
run;
%put System Return Code = &syscc.;
