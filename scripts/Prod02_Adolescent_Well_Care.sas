/*
### Code Owners: Shea Parkes, Aaron Hoch, Neil Schneider
 
### Objective:
  Calculate the Adolescent Well-Care measure and provide a list of members inlcuded in the measure. 

Developer Notes:

*/


%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%GetParentFolder(1)Supp01_Shared.sas" / source2;

%AssertThat(%upcase(&quality_metrics.),eq, OHA_INCENTIVE_MEASURES
			,ReturnMessage=The user has not chosen to run OHA Incentive Measures.  This program does not need run.
			,FailAction = EndActiveSASSession 
			);

libname M015_Out "&M015_Out." access=readonly;
libname M150_Out "&M150_Out.";
libname M150_Tmp "&M150_Tmp.";
%CacheWrapperPRM(035,150);
%CacheWrapperPRM(073,150);
%FindICDFieldNames()

%let Measure_Name = Adolescent_Well_Care;
%let Age_Adolescent_Between = 12 and 21;
%CodeGenClaimsFilter(&Measure_Name.,Component = Numerator,Reference_Source=m015_out.oha_codes)

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/






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
	where intck('year', mem.dob, &Measure_End., 'c') between &Age_Adolescent_Between.
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
		,cat(
			'Most recent visit performed '
			,put(calculated most_recent_visit,MMDDYYs10.)
			,case
				when not (calculated most_recent_visit between &Measure_Start. and &Measure_End.) then " (not in performance year)"
				else ""
				end
			) as comment format = $128. length = 128
	from M150_Tmp.outclaims_prm as outclaims_prm
	inner join members_denominator as elig
		on outclaims_prm.member_ID = elig.member_ID
	where (&claims_filter_numerator.)
	group by
		outclaims_prm.Member_ID
	;
quit;

proc sql;
	create table M150_Out.Results_&Measure_Name. as
	select
		denom.Member_ID
		,1 as Denominator
		,coalesce(visits.numerator,0) as numerator
		,coalesce(
			visits.comment
			,"No qualifying visit"
			) as comments format = $128. length = 128
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
