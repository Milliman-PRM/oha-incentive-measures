/*
### Code Owners: Ben Copeland
 
### Objective:
  Calculate the Well Child Visits measure and provide a list of members inlcuded in the measure. 

Developer Notes:

*/


%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2;

libname oha_ref "%sysget(OHA_INCENTIVE_MEASURES_PATHREF)" access=readonly;
libname M150_Out "&M150_Out.";
libname M150_Tmp "&M150_Tmp.";
%CacheWrapperPRM(035,150);
%CacheWrapperPRM(073,150);
%FindICDFieldNames()

%let Measure_Name = well_child_visits;
%let filter_age_between = 3 and 6;
%CodeGenClaimsFilter(
	&Measure_Name.
	,Component = well_care
	,Reference_Source=oha_ref.hedis_codes
);
%CodeGenClaimsFilter(
	&Measure_Name.
	,Component = hospice_encounter
	,Reference_Source=oha_ref.hedis_codes
	,name_output_var=hospice_encounter
);
%CodeGenClaimsFilter(
	&Measure_Name.
	,Component = hospice_intervention
	,Reference_Source=oha_ref.hedis_codes
	,name_output_var=hospice_intervention
);
%CodeGenClaimsFilter(
	&Measure_Name.
	,Component = telehealth_modifier
	,Reference_Source=oha_ref.hedis_codes
	,name_output_var=telehealth_modifier
);
%CodeGenClaimsFilter(
	&Measure_Name.
	,Component = telehealth_pos
	,Reference_Source=oha_ref.hedis_codes
	,name_output_var=telehealth_pos
);

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/


/*Find denom claim exclusions*/
proc sql;
	create table denom_excl
	as select distinct
		member_id
	from m150_tmp.outclaims_prm
	where
		fromdate ge &measure_start.
		and fromdate le &measure_end.
		and (
			(&hospice_encounter.)
			or (&hospice_intervention.)
		)
	;
quit;



/**** FIND ELIGIBILITY GAPS ****/

proc sql;
	create table elig_gap_prep as
	select
		time.member_id
		,time.date_start
		,time.date_end
		,mem.dob
	from M150_Tmp.Member_Time as time
	inner join M150_Tmp.Member as mem on
		time.Member_ID eq mem.Member_ID
	where intck('year', mem.dob, &Measure_End., 'c') between &filter_age_between.
	order by
		time.member_id
		,time.date_end
		;
quit;

proc sql;
	create table elig_date_end_freq as
	select
		elig_date_end
		,count(*) as memcnt format=comma12.
	from (
		select
			member_id
			,max(date_end) as elig_date_end format=YYMMDDd10.
		from elig_gap_prep
		group by member_id
	)
	group by elig_date_end
	order by elig_date_end desc
	;
quit;

%sysfunc(ifc(%symexist(empirical_elig_date_end)
	,%nrstr(%put empirical_elig_date_end already present, likely from test mocking.;)
	,%nrstr(
		proc sql noprint;
			select max(elig_date_end)
			into :empirical_elig_date_end trimmed
			from elig_date_end_freq
			where memcnt ge 42
			;
		quit;
		)
	))
%let empirical_elig_date_end = %sysfunc(min(&empirical_elig_date_end., &Measure_End.));
%put empirical_elig_date_end = &empirical_elig_date_end. (i.e. %sysfunc(putn(&empirical_elig_date_end., yymmdd10.)));

%FindEligGaps(
	elig_gap_prep
	,elig_gaps
	,global_date_end=&empirical_elig_date_end.
	)



/*** DETERMINE COMPONENTS AND RESULTS ***/

proc sql;
	create table members_denominator as
	select
		gaps.member_id
		,any_elig.dob
		,case
			when denom_excl.member_id is not null then 'Y'
			else 'N'
			end
			as denom_excluded_yn
	from elig_gaps as gaps
	inner join (
		/*Check that they had any eligibility at all in the measure period.*/
		select distinct 
			member_id
			,dob
		from elig_gap_prep
		where
			date_start le &Measure_End.
			and date_end ge &Measure_Start.
		) as any_elig on
		gaps.member_id eq any_elig.member_id
	left join denom_excl on
		gaps.member_id eq denom_excl.member_id
	where
		gaps.gap_cnt le 1
		and gaps.gap_days le 45
	;
quit;

proc sql;
	create table qualifying_visits as
	select distinct 
		outclaims_prm.Member_ID
		,max(outclaims_prm.fromdate) as most_recent_visit format = YYMMDDd10.
		,max(
			case
				when outclaims_prm.fromdate between &Measure_Start. and &Measure_End. then 1
				else 0
				end
		) as numerator
	from M150_Tmp.outclaims_prm as outclaims_prm
	where (
		(&claims_filter_well_care.)
		and not (&telehealth_modifier.)
		and not (&telehealth_pos.)
	)
	group by
		outclaims_prm.Member_ID
	;
quit;

proc sql;
	create table M150_Out.Results_&Measure_Name. as
	select
		denom.Member_ID
		,case
			when denom.denom_excluded_yn eq 'Y' then 0
			else 1
			end
			as Denominator
		,coalesce(visits.numerator,0) as numerator
		,case
			when denom.denom_excluded_yn eq 'Y' then 'Excluded due to hospice status'
			when visits.most_recent_visit ne . then cat(
				'Most recent visit performed '
				,put(most_recent_visit,MMDDYYs10.)
				,case
					when not (most_recent_visit between &Measure_Start. and &Measure_End.) then " (not in performance year)"
					else ""
					end
				)
			else "No qualifying visit"
			end as comments format = $128. length = 128
		,case calculated numerator
			when 0 then &measure_end.
			else .
			end
			as comp_quality_date_actionable format = YYMMDDd10.
	from members_denominator as denom
	left join qualifying_visits as visits on
		denom.Member_ID eq visits.Member_ID
	;
quit;
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
