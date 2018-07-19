/*
### CODE OWNERS: Katherine Castro

### OBJECTIVE:
	Calculate the Disparity Measure: Emergency Department Utilization for Individuals
	Experiencing Mental Illness quality measure so it can be included in the reports.

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2;

/* Libnames */
libname oha_ref "%sysget(OHA_INCENTIVE_MEASURES_PATHREF)" access=readonly;
libname M150_Out "&M150_Out.";
libname M150_Tmp "&M150_Tmp.";
%CacheWrapperPRM(035,150)
%CacheWrapperPRM(073,150)
%FindICDFieldNames()

%let measure_name = ed_visits_mi;
%CodeGenClaimsFilter(
	&measure_name.
	,component=Denominator
	,Reference_Source=oha_ref.oha_codes);
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_cpt
	,Reference_Source=oha_ref.oha_codes);
%CodeGenClaimsFilter(
	&measure_name.
	,component=Numer_rev
	,Reference_Source=oha_ref.oha_codes);
%CodeGenClaimsFilter(
	&measure_name.
	,component=Numer_procs
	,Reference_Source=oha_ref.oha_codes
	);
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_excl_mh
	,Reference_Source=oha_ref.oha_codes
	);
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_excl_psych
	,Reference_Source=oha_ref.oha_codes
	);
%CodeGenClaimsFilter(
	&measure_name.
	,component=Numer_Excl_IP_Stay
	,Reference_Source=oha_ref.oha_codes
	);

%let max_er_comments = 3;
%let age_limit_expression = ge 18;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/

/* Create list of members in the denominator */
/* OHA uses claims with a 36-month rolling look back period, */
/* and the members who had two or more visits with any of the diagnoses */
/* in the Members Experiencing Mental Illness Value Set are identified */
/* for inclusion in the denominator. */
%macro wrap_denom();
proc sql;
	create table members_denom as
	select
		members_age.member_id,
		members_mi.cnt
	from
	(select
		member_id,
		count(distinct claimid) as cnt
	from
		M150_tmp.outclaims_prm
	where
		outclaims_prm.prm_fromdate gt %sysfunc(intnx(month,&measure_end.,-36,same))
		and
		outclaims_prm.prm_fromdate lt &measure_end.
		and
		(&claims_filter_denominator.)
	group by member_id) members_mi
	inner join
			(
			select member_id
			from M150_tmp.member
			where floor(yrdif(dob,&measure_end.,"age")) &age_limit_expression.
			) members_age
	on members_age.member_id = members_mi.member_id
	where
		members_mi.cnt gt 2
	order by member_id
;
quit;
%mend wrap_denom;
%wrap_denom()

/* Create member-level results table */
proc sql;
	create table M150_Out.results_ed_visits_mi as
	select
		denom.member_id
		,coalesce(ed.numerator,0) as numerator
		,ed.denominator
		,ed.comments
		,ed.comp_quality_date_actionable
	from members_denominator as denom
	inner join M150_Out.results_ed_visits as ed
		on denom.member_id eq ed.member_id
	;
quit;

/* Calculate metric */
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
	from M150_Out.results_ed_visits_mi
	;
quit;
%put sum_numerator = &sum_numerator.;
%put sum_denominator = &sum_denominator.;
%put measure_rate = &measure_rate.;


%put System Return Code = &syscc.;
