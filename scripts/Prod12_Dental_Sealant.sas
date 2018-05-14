/*
### CODE OWNERS: Scott Cox, Ben Copeland

### OBJECTIVE:
	Calculate the Dental Sealants on Permanent Molars for Children measure and provide a list of members inlcuded in the measure. 

### DEVELOPER NOTES:
	Design pattern borrowed from Shea Parkes, Aaron Hoch, Neil Schneider.
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
libname M030_Out "&M030_Out.";

%AssertDataSetExists(M030_Out.InpDental, 
					 ReturnMessage=M030_Out.InpDental does not exist., 
					 FailAction=EndActiveSASSession)
					 ;

%CacheWrapperPRM(035,150);
%CacheWrapperPRM(073,150);
%FindICDFieldNames()

%let Measure_Name = Dental_Sealants;
%let Age_Adolescent_Between = 6 and 14;
%CodeGenClaimsFilter(&Measure_Name.,Component = Numer_Seals, Name_Header = sealants,Reference_Source=m015_out.oha_codes);
%CodeGenClaimsFilter(&Measure_Name.,Component = Numer_Dental_Claim_Code, Name_Header = sealants,Reference_Source=m015_out.oha_codes);
%CodeGenClaimsFilter(&Measure_Name.,Component = Numer_Dental_Tooth_Code, Name_Header = sealants,Reference_Source=m015_out.oha_codes);
%let sealants_numer_dental = &sealants_numer_dental_claim_code. and &sealants_numer_dental_tooth_code.;
%put &=sealants_numer_dental.;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/



/**** FIND ELIGIBILITY GAPS ****/


proc sql;
	create table elig_gap_prep as
	select
		 time.member_id
		,time.date_start
		,time.date_end
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

/* Denominator */
proc sql;
	create table members_denominator as
	select
		gaps.member_id
	from elig_gaps as gaps
	inner join (
		/*Check that they had any eligibility at all in the measure period.*/
		select distinct member_id
		from elig_gap_prep
		where
			date_start le &Measure_End.
			and date_end ge &Measure_Start.
		) as any_elig on
		gaps.member_id eq any_elig.member_id
	where
		gaps.gap_cnt le 1
		and gaps.gap_days le 45
		and elig_on_anchor_yn = 'Y'
	;
quit;

/* Numerator */
proc sql;
	create table dental_qualified_all as
	select distinct
		member_id
		,fromdate
		,hcpcs
		,tooth
		,case
			when (&sealants_numer_dental_claim_code.) then 1
			else 0
			end
			as had_correct_claim_code
		,case
			when (&sealants_numer_dental_tooth_code.) then 1
			else 0
			end
			as had_correct_tooth_code
		,case
			when fromdate between &Measure_Start. and &Measure_End. then 1
			else 0
			end
			as in_current_measure_period
		,case
			when calculated had_correct_claim_code eq 1
				and calculated had_correct_tooth_code eq 1
				and calculated in_current_measure_period eq 1
				then 1
			else 0
			end
			as numerator
	from M030_Out.Inpdental as dental_data
	where calculated had_correct_claim_code eq 1
	order by
		member_id
		,calculated numerator desc /*Show numerator hits first*/
		,fromdate desc
	;	
quit;

data dental_qualified;
	set dental_qualified_all;
	by
		member_id
		descending numerator
		descending fromdate
		;
	if first.member_id;
	format comments $128.;
	comments = cat(
		"Sealant on "
		,putn(fromdate,"MMDDYYs10.")
		);
	if had_correct_tooth_code eq 0
		or in_current_measure_period eq 0 then comments = cat(strip(comments)," (");

	if had_correct_tooth_code eq 0
		and in_current_measure_period eq 0 then comments = cat(strip(comments),"non-molar, not in performance year");
	else if had_correct_tooth_code eq 0 then  comments = cat(strip(comments),"non-molar");
	else if in_current_measure_period eq 0 then  comments = cat(strip(comments),"not in performance year");

	if had_correct_tooth_code eq 0
		or in_current_measure_period eq 0 then comments = cat(strip(comments),")");

	keep
		member_id
		fromdate
		numerator
		comments
		;
run;

proc sql;
   	create table outclaims_qualified_all as
   	select
		member_id
		,FromDate
		,case
			when outclaims_prm.FromDate between &Measure_Start. and &Measure_End. then 1
			else 0
			end
			as in_current_measure_period
		,case
			when calculated in_current_measure_period eq 1 then 1
			else 0
			end
			as numerator
   	from M150_Tmp.outclaims_prm as outclaims_prm
   	where (&Sealants_Numer_Seals.)
	order by
		member_id
		,calculated numerator desc /*Show numerator hits first*/
		,FromDate desc
   ;
quit;

data outclaims_qualified;
	set outclaims_qualified_all;
	by
		member_id
		descending numerator
		descending fromdate
		;
	if first.member_id;
	format comments $128.;
	comments = cat(
		"Sealant service on "
		,putn(fromdate,"MMDDYYs10.")
		);
	if in_current_measure_period eq 0 then comments = cat(
		strip(comments)
		," (not in performance year)"
		);

	keep
		member_id
		fromdate
		numerator
		comments
		;
run;

data qualified_claims;
	set
		dental_qualified (in = dental)
		outclaims_qualified (in = medical)
		;
	if dental then source_priority = 1;
	else if medical then source_priority = 2;
run;

proc sort data = qualified_claims out = qualified_claims_sort;
	by
		member_id
		descending numerator
		descending fromdate
		source_priority
		;
run;

data members_numeratorish;
	set qualified_claims_sort;
	by
		member_id
		descending numerator
		descending fromdate
		source_priority
		;
	if first.member_id;
	drop
		fromdate
		source_priority
		;
run;

/* Output */
proc sql;
	create table M150_Out.Results_&Measure_Name. as
	select
		denom.Member_ID
		,1 as Denominator
		,coalesce(numer.numerator,0) as numerator
		,numer.comments
		,case calculated numerator
			when 0 then &measure_end.
			else .
			end
			as comp_quality_date_actionable format = YYMMDDd10.
	from members_denominator as denom
	left join members_numeratorish as numer on
		denom.Member_ID eq numer.Member_ID
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
