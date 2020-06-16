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
		,icdversion
		,&diag_fields_select.
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

data pregnancy_diags;
	set oha_ref.hedis_codes;

	where
		measure eq 'prenatal_postpartum_care'
		and component eq 'pregnancy_diagnosis'
		and codesystem eq: 'ICD'
	;

	format
		icdversion $2.
	;
	if codesystem eq 'ICD10CM-Diag' then icdversion = '10';

	format
		pregnancy_diagnosis 12.
	;
	pregnancy_diagnosis = 1;

	keep
		icdversion
		code
		pregnancy_diagnosis
	;
run;
%AssertNoNulls(pregnancy_diags, icdversion);

data denom_pregnancy_flag;
	set denom_flags;

	call missing(pregnancy_diagnosis);
	if _n_ = 1 then do;
 		declare hash hash_diag (dataset:  "pregnancy_diags", duplicate:  "ERROR");
 		rc_diag = hash_diag.DefineKey("code", "icdversion");
 		rc_diag = hash_diag.DefineData("pregnancy_diagnosis");
 		rc_diag = hash_diag.DefineDone();
 	end;

 	/*Hash on diag*/
	array icddiags icddiag:;

 	do over icddiags;
 		if icddiags ne "" then do;
 			code = icddiags;
 			rc_diag = hash_diag.find();
 		end;
 	end;

	pregnancy_diagnosis = coalesce(pregnancy_diagnosis, 0);
run;

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

data last_enrollment_segment;
	set delivery_member_time;
	by
		member_id
		delivery_date
		date_start
	;
	format
		enrollment_segment_id 12.
		last_date_end yymmddd10.
	;
	retain
		enrollment_segment_id
		last_date_end
	;
	if first.delivery_date then do;
		enrollment_segment_id = 0;
		last_date_end = .;
	end;

	if (
		not first.delivery_date
		and (date_start - last_date_end) ne 1
	)
	then enrollment_segment_id = enrollment_segment_id + 1;

	last_date_end = date_end;
run;

proc summary nway missing
	data = last_enrollment_segment;
	class
		member_id
		delivery_date
		enrollment_segment_id
	;
	var
		date_start
		date_end
	;
	output
		out = enrollment_segment_windows
		min(date_start)=enrollment_segment_start
		max(date_end)=enrollment_segment_end
	;
run;

%FindEligGaps(
	delivery_member_time
	,delivery_elig_gaps
	,varname_member_date_start=ce_start_date
	,varname_member_date_end=ce_end_date
	,extra_by_variables=delivery_date
);

proc sql;
	create table prenatal_last_enrollment_prep
	as select
		delivery.*
		,delivery.delivery_date - 280 as prenatal_start_date format = yymmddd10.
		,enroll.enrollment_segment_start
		,enroll.enrollment_segment_end
	from delivery_elig_gaps as delivery
	left join enrollment_segment_windows as enroll on
		delivery.member_id eq enroll.member_id
		and delivery.delivery_date eq enroll.delivery_date
	where
		enroll.enrollment_segment_start le delivery.delivery_date
		and enroll.enrollment_segment_end ge calculated prenatal_start_date
	order by
		delivery.member_id
		,delivery.delivery_date
		,enroll.enrollment_segment_start
	;
quit;

data prenatal_postpartum_dates;
	set prenatal_last_enrollment_prep;
	by
		member_id
		delivery_date
		enrollment_segment_start
	;
	if last.delivery_date;

	format
		prenatal_care_start_date yymmddd10.
		prenatal_care_end_date yymmddd10.
	;

	if (
		(delivery_date - enrollment_segment_start) le 219
	)
	then do;
		prenatal_care_start_date = enrollment_segment_start;
		prenatal_care_end_date = enrollment_segment_start + 42;
	end;

	else do;
		prenatal_care_start_date = delivery_date - 280;
		prenatal_care_end_date = delivery_date - 219;
	end;


	format
		postpartum_care_start_date yymmddd10.
		postpartum_care_end_date yymmddd10.
	;
	postpartum_care_start_date = delivery_date + 7;
	postpartum_care_end_date = delivery_date + 84;
run;

proc sql;
	create table denom_delivery_gaps
	as select
		denom.*
		,delivery.delivery_date
		,delivery.gap_cnt
		,dates.prenatal_care_start_date
		,dates.prenatal_care_end_date
		,dates.postpartum_care_start_date
		,dates.postpartum_care_end_date
	from denom_flags as denom
	left join delivery_elig_gaps as delivery on
		denom.member_id eq delivery.member_id
	left join prenatal_postpartum_dates as dates on
		denom.member_id eq dates.member_id
		and delivery.delivery_date eq dates.delivery_date
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
