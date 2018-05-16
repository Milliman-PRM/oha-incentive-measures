/*
### CODE OWNERS: Kyle Baird, Ben Copeland

### OBJECTIVE:
	Calculate the Developmental Screening quality measure so it can be included
	in the reports.

### DEVELOPER NOTES:
	The measure year is determined at the member level and is defined as 12 months prior to
	an individuals birthday.
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

%let name_measure = dev_screening;
%let age_limit_expression = between 1 and 3;
%CodeGenClaimsFilter(&name_measure.,component=numerator,Reference_Source=oha_ref.oha_codes)

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




/*** DERIVE LAST CREDIBLE ELIGIBILITY DATE ***/
proc sql;
	create table elig_date_end_freq as
	select
		elig_date_end
		,count(*) as memcnt format = comma12.
	from (
		select
			member_id
			,max(date_end) as elig_date_end format = YYMMDDd10.
		from M150_tmp.member_time
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
%let empirical_elig_date_end = %sysfunc(min(&empirical_elig_date_end.,&measure_end.));
%put empirical_elig_date_end = &empirical_elig_date_end. %sysfunc(putn(&empirical_elig_date_end.,YYMMDDd10.));

/*** AGE RESTRICTIONS ***/
data members_meeting_age;
	set M150_tmp.member (
		keep =
			member_id
			dob
		);
	where floor(yrdif(dob,&measure_end.,"age")) &age_limit_expression.;
	format
		age_year_end best12.
		member_measure_start YYMMDDd10.
		member_measure_end YYMMDDd10.
		member_elig_end YYMMDDd10.
		date_anchor YYMMDDd10.
		;

	age_year_end = floor(yrdif(dob,&measure_end.,"age"));

	member_measure_start = intnx('year', dob, age_year_end - 1, 'same');
	member_measure_end = intnx('year', dob, age_year_end, 'same');
	member_elig_end = min(
		member_measure_end
		, &empirical_elig_date_end.
		); *Cap end dates at the point which we have data, so we do not throw away member, just because our data does not extend to their birthday.;

	date_anchor = member_elig_end; 

run;

/*** CHECK FOR GAPS IN ELIGIBILITY ***/
proc sql;
	create table member_elig_windows as
	select
		mem_time.member_id
		,mem_time.date_start
		,mem_time.date_end
		,members.member_measure_start
		,members.member_elig_end
		,members.date_anchor
		,members.dob
	from M150_tmp.member_time as mem_time
	inner join members_meeting_age as members
		on mem_time.member_id eq members.member_id
	order by
		mem_time.member_id
		,mem_time.date_end
	;
quit;

%FindEligGaps(
	dataset_input=member_elig_windows
	,dataset_output=member_elig_gaps
	,varname_member_date_start=member_measure_start
	,varname_member_date_end=member_elig_end
	,varname_member_date_anchor=date_anchor
	)

/*** FLAG DENOMINATOR ***/
proc sql;
	create table members_denominator
	as select
		gaps.member_id
		,age.dob
		,cat('DOB: ', put(age.dob,MMDDYYs10.)) as denom_comment format = $128. length = 128
		,case
			when age.member_measure_end gt &date_latestpaid. then age.member_measure_end
			else .
			end
			as comp_quality_date_actionable format = YYMMDDd10.
	from member_elig_gaps as gaps
	left join members_meeting_age as age
		on gaps.member_id = age.member_id
	where
		gap_cnt le 1
		and gap_days le 45
		and upcase(elig_on_anchor_yn) eq 'Y'
	order by
		gaps.member_id
	;
quit;

/*** FLAG NUMERATOR ***/
proc sql;
	create table potential_numerator_claims as
	select
		denom.member_id
		,member_windows.age_year_end
		,member_windows.member_measure_start
		,member_windows.member_measure_end
		,potential_numerator_claims.prm_fromdate
		,case
			when potential_numerator_claims.prm_fromdate between member_windows.member_measure_start and member_windows.member_measure_end then 1
			else 0
			end
			as numerator_potential
	from members_denominator as denom
	inner join (
		select distinct
			member_id
			,prm_fromdate
		from M150_tmp.outclaims_prm
		where (&claims_filter_numerator.)
		) as potential_numerator_claims
		on denom.member_id eq potential_numerator_claims.member_id
	left join members_meeting_age as member_windows
		on denom.member_id eq member_windows.member_id
	;
quit;

proc sql;
	create table visit_dates as
	select
		member_id
		,age_year_end
		,member_measure_start
		,member_measure_end
		,numerator_potential
		,max(prm_fromdate) as visit_date format = YYMMDDd10.
	from potential_numerator_claims
	group by
		member_id
		,age_year_end
		,member_measure_start
		,member_measure_end
		,numerator_potential
	;
quit;

proc sql;
	create table numerator_flag as
	select
		member_id
		,max(numerator_potential) as numerator
	from visit_dates
	group by member_id
	;
quit;

data add_comments;
	merge
		visit_dates
		numerator_flag
		;
	by member_id;

	format comments $128.;
	if numerator_potential eq 1 then do;
		comments = catx(" ","Recent qualifying visit date:",putn(visit_date,"MMDDYYs10."));
	end;
	else if numerator_potential eq 0 then do;
		comments = catx(" ","Recent visit date:",putn(visit_date,"MMDDYYs10."));
		if visit_date gt member_measure_end then do;
			comments = cat(strip(comments)," (after DOB");
			if age_year_end lt 3 then comments = cat(strip(comments),", qualifies next performance year");
			else if numerator eq 0 then comments = cat(strip(comments),", too old next performance year");
			comments = cat(strip(comments),")");
		end;
		else if visit_date lt member_measure_start then do;
			if numerator eq 0 then comments = cat(strip(comments)," (prior to performance year)");
			else comments = ""; /*No need to inform of prior performance year if they have already qualified.*/
		end;
	end;
run;

proc sort data = add_comments;
	by member_id descending numerator_potential;
run;

/*** COMBINE AND OUTPUT ***/
data members_numerator;
	set add_comments (rename = (comments = comments_original));
	by member_id descending numerator_potential;

	format comments $128.;
	retain comments;
	if first.member_id then comments = comments_original;
	else do;
		if lengthn(comments) gt 0 then comments = catx("; ",comments,comments_original);
		else comments = comments_original;
	end;

	if last.member_id then output;

	keep
		member_id
		numerator
		comments
		;
run;

data M150_out.results_&name_measure.;
	merge
		members_denominator (in = denom)
		members_numerator
		;
	by member_id;
	if denom;
	denominator = 1;
	numerator = coalesce(numerator,0);
	if numerator ne 0 then comp_quality_date_actionable = .; /*Members who have hit the measure are not actionable anymore*/
	comments = coalescec(comments,denom_comment);
	drop denom_comment dob;
run;
%LabelDataSet(M150_out.results_&name_measure.)

%put System Return Code = &syscc.;
