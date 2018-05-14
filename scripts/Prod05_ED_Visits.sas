/*
### CODE OWNERS: Ben Copeland, Neil Schneider, Kyle Baird

### OBJECTIVE:
	Calculate the Ambulatory Care: Emergency Dept Utilization quality measure 
	so it can be included in the reports.

### DEVELOPER NOTES:
	<none>
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2;

/* Libnames */
libname M015_Out "&M015_Out." access=readonly;
libname M150_Out "&M150_Out.";
libname M150_Tmp "&M150_Tmp.";
%CacheWrapperPRM(035,150)
%CacheWrapperPRM(073,150)
%FindICDFieldNames()

%let measure_name = ed_visits;
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_cpt
	,Reference_Source=m015_out.oha_codes);
%CodeGenClaimsFilter(
	&measure_name.
	,component=Numer_rev
	,Reference_Source=m015_out.oha_codes);
%CodeGenClaimsFilter(
	&measure_name.
	,component=Numer_procs
	,Reference_Source=m015_out.oha_codes
	);
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_excl_mh
	,Reference_Source=m015_out.oha_codes
	);
%CodeGenClaimsFilter(
	&measure_name.
	,component=numer_excl_pysch
	,Reference_Source=m015_out.oha_codes
	);
%CodeGenClaimsFilter(
	&measure_name.
	,component=Numer_Excl_IP_Stay
	,Reference_Source=m015_out.oha_codes
	);

%let max_er_comments = 3;

/*Bring in predictions in order to decorate comments*/
%let path_file_pred_source = &M130_Out.custom.pred.pop.sas;
%put path_file_pred_source = &path_file_pred_source.;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/

/* Determine denominator member months */
proc sql;
	create table denom_memmos
	as select distinct
		member_ID
		,sum(memmos) as memmos
	from m150_tmp.member_time
	where 
		elig_month ge &Measure_Start.
		and elig_month le &Measure_End.
		and elig_month lt &runout_start.
		and cover_medical eq 'Y'
	group by member_ID
	order by member_ID
	;
quit;

/*Define ER visits by spec (not HCG grouper). CPT exclusions need to be merged on separately
by claimID since these will appear on different claim lines. Assuming claims resulting
in IP encounters will be caught by grouper/prm_line*/
proc sql;
	create table all_ed_visits
	as select distinct
		clm.member_ID
		,clm.prm_fromdate
		,clm.prm_line
		,clm.claimID
		,clm.HCPCS
		,clm.POS
		,clm.icddiag1
		,case
			when ip.prm_fromdate ne . then 1
			else 0 
		end as ip_following
		,case
			when excl.claimid is not null then 1
			else 0 
		end as cpt_exclusion_flag
		,clm.icddiag_excl
		,case
			when clm.prm_fromdate ge &measure_start.
				and clm.prm_fromdate le &Measure_End.
				then 1
			else 0
			end
			as in_current_measure_year
		,case
			when calculated in_current_measure_year eq 1
				and clm.prm_fromdate ge &runout_start.
				then 1
			else 0
			end
			as in_runout_period
		,case 
			when denied.claimid is not null then 1
			else 0 end
		as denied_excl
	from 
		(select 
			member_ID
			,prm_fromdate
			,prm_line
			,claimID
			,HCPCS
			,POS
			,icddiag1
			,case 
				when (&claims_filter_numer_excl_mh.) then 1
				else 0 end
			as icddiag_excl

		from m150_tmp.outclaims_prm
		where 
			((&claims_filter_numer_cpt.)
			or (&claims_filter_numer_rev.)
			or (&claims_filter_numer_procs.))
		) as clm
	left join
		(select distinct
			member_ID
			,prm_fromdate
			,claimID
		from m150_tmp.outclaims_prm
		where 
			(&claims_filter_numer_excl_pysch.)
		) as excl
	on 
		clm.member_ID = excl.member_ID
		and clm.claimID = excl.claimID
	left join
		(select distinct
			member_ID
			,prm_fromdate
		from m150_tmp.outclaims_prm
		where (&claims_filter_Numer_Excl_IP_Stay.)
		) as ip
	on 
		clm.member_ID = ip.member_ID
		and (ip.prm_fromdate - clm.prm_fromdate le 1 and ip.prm_fromdate - clm.prm_fromdate ge 0)
	left join
		(select distinct
			member_ID
			,claimid
		from m150_tmp.outclaims_prm
		where prm_denied_yn eq 'Y'
		) as denied
	on 
		clm.member_ID = denied.member_ID
		and clm.claimid = denied.claimid
	;
quit;

/*Tag what we will count as an ~visit*/
proc sql;
	create table add_min_fromdate as
	select
		base.*
		,agg.min_fromdate format = YYMMDDd10.
	from all_ed_visits as base
	left join (
		select
			member_id
			,claimid
			,min(prm_fromdate) as min_fromdate
		from all_ed_visits
		group by
			member_id
			,claimid
		) as agg
		on base.member_id eq agg.member_id
			and base.claimid eq agg.claimid
	order by
		base.member_ID
		,base.prm_fromdate
		,base.claimID
	;
quit;

/*Roll up to ~visit*/
proc sql;
	create table qualifying_visits as
	select
		member_ID
		,min_fromdate
		,max(in_current_measure_year) as in_current_measure_year /*If any portion of the visit counts, count it*/
		,min(in_runout_period) as in_runout_period /*If any portion is in the reporting period, don't flag the claim as being in the run-out period*/
		,max(denied_excl) as denied
	from add_min_fromdate
	where 
		ip_following eq 0 
		and icddiag_excl eq 0 
		and cpt_exclusion_flag eq 0
		and upcase(prm_line) net 'I'
	group by
		member_ID
		,min_fromdate
	having calculated denied ne 1
	order by
		member_ID
		,min_fromdate desc
	;
quit;

/*Quick aside to bring in predictions so we can decorate people who failed numerator
  with predicted ER probability.*/
%conditional_predictions(
	path_file_pred_source=&path_file_pred_source.
	,field_name=er_visits_pred_prob
	,name_output_dset=predicted_er_probabilities
	)

/*Add comments for denominator members*/
proc sql;
	create table members_denominator as
	select
		denom.*
		,dates.visit_date
		,probs.er_visits_pred_prob
		,(denom.memmos / 1000) as denominator
		,case
			when dates.visit_date is not null then cat(
				"Most Recent Visit: "
				,putn(dates.visit_date,"MMDDYYs10.")
				)
			else ""
			end
			as comment_dates length = 64 format = $64.
		,case
			when probs.er_visits_pred_prob is not null then cat(
				"Probability of ED Visit Next 6 Months: "
				,strip(putn(probs.er_visits_pred_prob,"percent6."))
				)
			else ""
			end
			as comment_probs length = 64 format = $64.
		,case
			when calculated comment_dates is not null
				and calculated comment_probs is not null
				then catx("; ",calculated comment_dates,calculated comment_probs)
			when calculated comment_dates is not null then calculated comment_dates
			when calculated comment_probs is not null then calculated comment_probs
			else ""
			end
			as comments length = 128 format = $128.
	from denom_memmos as denom 
	left join (
		select
			member_id
			,max(min_fromdate) as visit_date format = YYMMDDd10.
		from qualifying_visits
		where in_current_measure_year eq 0
		group by member_id
		) as dates
		on dates.member_id eq denom.member_id
	left join predicted_er_probabilities as probs
		on denom.member_id eq probs.member_id
	order by denom.member_id
	;
quit;

/*Calculate numerator and add separate comments*/
data members_numerator;
	set qualifying_visits;
	where in_current_measure_year eq 1;
	by member_ID descending min_fromdate;
	format
		numerator best12.
		comments $128.
		date_separator $2.
		date_counter best12.
		;
	retain
		numerator
		comments
		date_counter
		;
	if first.member_id then do;
		numerator = 0;
		comments = "Recent Visit(s):";
		date_separator = "";
		date_counter = 0;
	end;
	else date_separator = ", ";
	if not(in_runout_period) then numerator = sum(numerator,1);
	date_counter = sum(date_counter,1);
	if date_counter le &max_er_comments. then do;
		comments = cat(
			strip(comments)
			,date_separator
			,putn(min_fromdate,"MMDDYYs10.")
			);
		if in_runout_period then comments = cat(
			strip(comments)
			," (will qualify soon)"
			);
	end;
	if last.member_id then output;
	keep
		member_id
		numerator
		comments
		;
run;

proc sql;
	create table m150_out.results_&measure_name. as
	select
		denom.member_id
		,coalesce(numer.numerator,0) as numerator
		,denom.denominator
		/*
			,numer.comments as comments_numer
			,denom.comments as comments_denom
		*/
		,coalesce(numer.comments,denom.comments) as comments
		,case calculated numerator
			when 0 then
				case
					when denom.er_visits_pred_prob ge 0.50 then &measure_end.
					else .
					end
			else
				case
					when denom.er_visits_pred_prob ge 0.25 then &measure_end.
					else .
					end
			end
			as comp_quality_date_actionable format = YYMMDDd10.
	from members_denominator as denom
	left join members_numerator as numer
		on denom.member_id eq numer.member_id
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
