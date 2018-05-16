/*
### CODE OWNERS: Kyle Baird, Steve Gredell

### OBJECTIVE:
	Calculate the controlling hypertension quality measure so we can display
	in reports

### DEVELOPER NOTES:
	Depends on availablity and reliability of EHR data
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2;

%put WARNING: METRIC CALCULATION CODE BELOW IS LIKELY STALE. USERS SHOULD CONSIDER THIS BEFORE ENABLING PROGRAM FOR PRODUCTION PURPOSES;

/* Libnames */
libname oha_ref "%sysget(OHA_INCENTIVE_MEASURES_PATHREF)" access=readonly;
libname M033_Out "&M033_Out." access=readonly;
libname M150_Tmp "&M150_Tmp.";
libname M150_Out "&M150_Out.";

%AssertDataSetExists(
	M033_out.emr_vitals
	,ReturnMessage=EMR data must be present to calculate hypertension measure.
	,FailAction=EndActiveSASSession
	)
%sysfunc(ifc(%symexist(suppress_parser)
	,%str()
	,%nrstr(%AssertRecordCount(
		M033_out.emr_vitals
		,gt
		,42
		,ReturnMessage=EMR data must be populated to calculate hypertension measure.
		,FailAction=EndActiveSASSession
		))
	));

%CacheWrapperPRM(033,150)
%CacheWrapperPRM(035,150)
%CacheWrapperPRM(073,150)

%let measure_name = hypertension;
%let age_limit_expression = between 18 and 85;

%FindICDFieldNames()

%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_hypertens
	,Reference_Source=oha_ref.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_service
	,Reference_Source=oha_ref.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_excl_disease
	,Reference_Source=oha_ref.oha_codes
	)
%CodeGenClaimsFilter(
	&measure_name.
	,component=denom_excl_renal
	,Reference_Source=oha_ref.oha_codes
	)

proc sql noprint;
	select count(distinct component)
	into :cnt_pregnancy_components trimmed
	from oha_ref.oha_codes
	where upcase(measure) eq "%upcase(&measure_name.)"
		and upcase(component) eqt "DENOM_EXCL_PREGO"
	;
quit;
%put &=cnt_pregnancy_components.;

%macro wrap_codegen_preggers();
	%do i_component = 1 %to &cnt_pregnancy_components.;
		%CodeGenClaimsFilter(
			&measure_name.
			,component=denom_excl_prego&i_component.
			,Reference_Source=oha_ref.oha_codes
			)
	%end;
%mend wrap_codegen_preggers;
%wrap_codegen_preggers()

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




%macro wrap_denom();
	proc sql;
		create table members_denom as
		select members_age.member_id
		from (
			select member_id
			from M150_tmp.member
			where floor(yrdif(dob,&measure_end.,"age")) &age_limit_expression.
			) members_age
		inner join (
			select distinct member_id
			from M150_tmp.outclaims_prm
			where outclaims_prm.prm_fromdate lt %sysfunc(intnx(month,&measure_start.,6,same))
				and (&claims_filter_denom_hypertens.)
			) as members_hyper
			on members_age.member_id eq members_hyper.member_id
		inner join (
			select distinct member_id
			from M150_tmp.outclaims_prm
			where outclaims_prm.prm_todate ge &measure_start.
				and outclaims_prm.prm_fromdate le &measure_end.
				and (&claims_filter_denom_service.)
			) as member_denom_service
			on members_age.member_id eq member_denom_service.member_id
		left join (
			select distinct member_id
			from M150_tmp.outclaims_prm
			where (&claims_filter_denom_excl_disease.)
			) as members_excluded_disease
			on members_age.member_id eq members_excluded_disease.member_id
		left join (
			select distinct member_id
			from M150_tmp.outclaims_prm
			where outclaims_prm.prm_fromdate le &measure_end.
				and (&claims_filter_denom_excl_renal.)
			) as members_excluded_renal
			on members_age.member_id eq members_excluded_renal.member_id
		left join (
			select distinct member_id
			from M150_tmp.outclaims_prm
			where outclaims_prm.prm_todate ge &measure_start.
				and outclaims_prm.prm_fromdate le &measure_end.
				and
			%if &cnt_pregnancy_components. gt 0 %then %do;
				%do i_component = 1 %to &cnt_pregnancy_components.;
					(&&claims_filter_denom_excl_prego&i_component..)
					%if &i_component. lt &cnt_pregnancy_components. %then %do;
						%str( or )
					%end;
				%end;
			%end;
			) as member_excluded_pregnancy
			on members_age.member_id eq member_excluded_pregnancy.member_id
		where members_excluded_disease.member_id is null
			and members_excluded_renal.member_id is null
			and member_excluded_pregnancy.member_id is null
		order by members_age.member_id
		;
	quit;
%mend wrap_denom;
%wrap_denom()

proc sql;
	create table all_bp_reading as
	select 
		vitals.member_id
		,vitals.vitals_date
		,vitals.systolic
		,vitals.diastolic
		,case
			when vitals.systolic lt 140
				and vitals.diastolic lt 90 then 1
			else 0
			end
			as bp_controlled
		,case
			when vitals.vitals_date between &measure_start. and &measure_end. then 1
			else 0
			end
			as in_current_measure_year
		,case
			when calculated bp_controlled eq 1
				and calculated in_current_measure_year eq 1 then 1
			else 0
			end as numerator_eligible
	from M150_tmp.emr_vitals as vitals
	where vitals.systolic is not null
		and vitals.diastolic is not null
	order by
		vitals.member_id
		,vitals.vitals_date
		,calculated numerator_eligible /*Benefit of doubt if multiple reading on same day*/
	;
quit;

data recent_bp_reading;
	set all_bp_reading;
	by
		member_id
		vitals_date
		numerator_eligible
		;
	retain
		numerator
	;
	if first.member_id then numerator = 0;
	if in_current_measure_year eq 1 then numerator = numerator_eligible;
	format comments $128.;
	comments = cat(
		"Recent BP reading on "
		,putn(vitals_date,"MMDDYYs10.")
		," of "
		,strip(put(systolic,8.))
		,"/"
		,strip(put(diastolic,8.))
		);
	keep
		member_id
		numerator
		comments
		;
	if last.member_id;
run;

data M150_out.results_&measure_name.;
	merge
		members_denom (in = denom)
		recent_bp_reading
		;
	by member_id;
	if denom;
	denominator = 1;
	numerator = coalesce(numerator,0);
	format comp_quality_date_actionable YYMMDDd10.;
	if numerator eq 0 then comp_quality_date_actionable = &measure_end.;
run;
%LabelDataSet(M150_out.results_&measure_name.)

proc sql noprint;
	select
		sum(numerator) as sum_numerator
		,sum(denominator) as sum_denominator
		,case
			when calculated sum_denominator gt 0 then round(coalesce(calculated sum_numerator,0) / calculated sum_denominator,0.0001)
			else 0
			end
			as measure_rate
	into :sum_numerator trimmed
		,:sum_denominator trimmed
		,:measure_rate trimmed
	from M150_out.results_&measure_name.
	;
quit;
%put sum_numerator = &sum_numerator.;
%put sum_denominator = &sum_denominator.;
%put measure_rate = &measure_rate.;

%put System Return Code = &syscc.;
