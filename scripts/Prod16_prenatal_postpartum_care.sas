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

proc sql;
	create table deliveries
	as select distinct
		member_id
		,prm_todate
	from m150_tmp.outclaims_prm
	where 
		(&filter_deliveries.)
		and prm_todate ge &intake_period_start.
		and prm_todate le &intake_period_end.
	;
quit;

%put System Return Code = &syscc.;
