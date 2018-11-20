/*
### CODE OWNERS: Shea Parkes, Ben Copeland

### OBJECTIVE:
	Bring all the OHA Quality Metric results together and export them.

### DEVELOPER NOTES:
	Separate outputs are generated for ancillary reporting and PUAD consumption.
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2;
%include "&M008_cde.Func06_build_metadata_table.sas" / source2;

%AssertThat(%upcase(&quality_metrics.),eq, OHA_INCENTIVE_MEASURES
			,ReturnMessage=The user has not chosen to run OHA Incentive Measures.  This program does not need run.
			,FailAction = EndActiveSASSession 
			);

/* Libnames */
libname oha_ref "%sysget(OHA_INCENTIVE_MEASURES_PATHREF)" access = readonly;
libname M035_Out "&M035_Out." access=readonly;
libname M036_Out "&M036_Out." access=readonly;
libname M150_Out "&M150_Out.";

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/

data OHA_Abbreviations;
	set oha_ref.OHA_Abbreviations;
	format comp_quality_dual 12.;
	comp_quality_dual = _N_;
run;

proc sql;
	create table errors_qm_targets as
	select src.*
	from M036_Out.targets_quality_measures as src
	left join oha_abbreviations as ref on
		upcase(src.measure_name_short) eq upcase(ref.Measure_Abbreviation)
	where ref.measure_name is null
	;
quit;
%AssertDataSetNotPopulated(errors_qm_targets,ReturnMessage=Targets were provided for measures which are not reported.)

proc sql;
	create table observed_outputs as
	select
		found.*
		,ref.Measure_Name
		,ref.comp_quality_dual
	from (
		select
			memname
			,substr(upcase(memname)
					,find(memname,"_") + 1
					,length(memname) - find(memname,"_")
					) as Measure_Abbreviation format=$32. length=32
			,libname
		from dictionary.tables
		where
			upcase(libname) eq 'M150_OUT'
			and scan(upcase(memname), 1, '_') eq 'RESULTS'
		) as found
	left join OHA_Abbreviations as ref on
		upcase(found.Measure_Abbreviation) eq upcase(ref.Measure_Abbreviation)
	order by ref.comp_quality_dual
	;
quit;

%AssertNoNulls(work.observed_outputs, Measure_Name, ReturnMessage= Results tables were found that did not have matching reference data.);


proc sql;
	create table missing_targets as
	select
		src.*
	from observed_outputs as src
	left join m036_out.targets_quality_measures as target
		on upcase(src.measure_abbreviation) = upcase(target.measure_name_short)
	where target.measure_target_value is null
	;
quit;
%AssertDataSetNotPopulated(work.missing_targets, ReturnMessage= Targets were not found for matching results tables.);

proc sql noprint;
	select
		catx(' '
			,catx('.', libname, memname)
			,'( in ='
			,Measure_Abbreviation
			,')'
			)
		,catx(' '
			,'if'
			,Measure_Abbreviation
			,'then Measure_Abbreviation = '
			,quote(strip(Measure_Abbreviation))
			,';'
			)
	into
		:codegen_stack_set separated by ' '
		,:codegen_stack_identify separated by ' '
	from observed_outputs
	;
quit;
%put codegen_stack_set = &codegen_stack_set.;
%put codegen_stack_identify = %bquote(&codegen_stack_identify.);


/*Output once prior to CCR limiting for ancillary reporting purposes*/
data M150_Out.oha_stacked_results_raw;
	format Measure_Abbreviation $32.;
	set &codegen_stack_set.;
	&codegen_stack_identify.;
run;
%LabelDataSet(M150_Out.oha_stacked_results_raw)



/*Now decorate/limit and hit exact PUAD schema.*/

proc sql;
	create table results_decor as
	select
		results.*
		,roster.mem_report_hier_1
		,ref.Measure_Abbreviation as comp_quality_short
		,. as comp_quality_date_last /*TODO: Retain something appropriate in each quality metric calculation.*/
	from M150_Out.oha_stacked_results_raw(
			rename=(
				denominator = comp_quality_denominator
				numerator = comp_quality_numerator
				comments = comp_quality_comments
				)
			) as results
	inner join M035_Out.Member as roster on
		results.member_id eq roster.member_id
	left join OHA_Abbreviations as ref on
		upcase(results.Measure_Abbreviation) eq upcase(ref.Measure_Abbreviation)
	;
quit;

%build_metadata_table(PowerUser_Agg_DataMart,/PUAD\d{2}_comp_quality/i)
proc sql noprint;
	select 
		catx(' '
			,name_field
			,sas_format
			)
		,name_field
	into 
		:codegen_output_format separated by ' '
		,:codegen_output_spaces separated by ' '
	from meta_data
	order by field_position
	;
quit;
%put codegen_output_format = &codegen_output_format.;
%put codegen_output_spaces = &codegen_output_spaces.;

data M150_out.quality_measures (keep = &codegen_output_spaces.);
	format &codegen_output_format.;
	set results_decor;
run;
%LabelDataSet(M150_out.quality_measures)


proc sql;
	create table quality_ref
	as select
		ref.measure_abbreviation as comp_quality_short
		,ref.comp_quality_dual
		,ref.Measure_Name as comp_quality
		,'CCO Incentive Measures' as comp_quality_category format=$128.
		,target.measure_direction as comp_quality_direction
		,target.measure_target_value as comp_quality_target_value
		,ref.Measure_Format as comp_quality_format_code
		,ref.measure_calculation_type as comp_quality_calculation_type
	from OHA_Abbreviations as ref
	left join m036_out.targets_quality_measures as target
		on upcase(ref.measure_abbreviation) = upcase(target.measure_name_short)
	order by ref.comp_quality_dual
	;
quit;

%build_metadata_table(PowerUser_Agg_DataMart,/PUAD\d{2}ref_comp_quality/i)
proc sql noprint;
	select 
		catx(' '
			,name_field
			,sas_format
			)
		,name_field
	into 
		:codegen_output_ref_format separated by ' '
		,:codegen_output_ref_spaces separated by ' '
	from meta_data
	order by field_position
	;
quit;
%put codegen_output_ref_format = &codegen_output_ref_format.;
%put codegen_output_ref_spaces = &codegen_output_ref_spaces.;

data M150_Out.ref_quality_measures (keep = &codegen_output_ref_spaces.);
	format &codegen_output_ref_format.;
	set quality_ref;
run;
%LabelDataSet(M150_Out.ref_quality_measures)

/*** DETERMINE ELIGIBLE MEMBERS ***/

%put System Return Code = &syscc.;
