/*
### Code Owners: Shea Parkes, Neil Schneider, Aaron Hoch, David Pierce

### Objective:
  Calculate the Alcohol and Drug Misuse (SBIRT) measure and provide a list of members inlcuded in the measure. 

### Developer Notes:
	
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

%let Measure_Name = Alcohol_SBIRT;
%Let Age_Adult = 12;
%CodeGenClaimsFilter(&Measure_Name.,Reference_Source=oha_ref.oha_codes)
%CodeGenClaimsFilter(&Measure_Name.,Component = Numerator,Reference_Source=oha_ref.oha_codes)
%CodeGenClaimsFilter(&Measure_Name.,Component = Denominator,Reference_Source=oha_ref.oha_codes)
%CodeGenClaimsFilter(&measure_name.,component = Numer_Excl,Reference_Source=oha_ref.oha_codes)
%CodeGenClaimsFilter(&measure_name.,component = Numer_Excl_Procs,Reference_Source=oha_ref.oha_codes)

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/


/*Grab all interesting claims that might identify numerator/denominator*/
proc sql;
	create table claims_interesting as
	select
		outclaims_prm.member_id
		,outclaims_prm.claimID
		,outclaims_prm.LineNum
		,outclaims_prm.fromdate
		,outclaims_prm.PRM_Denied_YN
		,outclaims_prm.hcpcs
		,outclaims_prm.POS
		,outclaims_prm.RevCode
		,&diag_fields_select.
		,&proc_fields_select.
	from M150_Tmp.Outclaims_PRM as Outclaims_PRM
	inner join M150_Tmp.Member as Member on
		Outclaims_PRM.Member_ID eq Member.Member_ID
	where
		intck('year', dob, &Measure_End., 'c') ge &Age_Adult.
		and FromDate between &Measure_Start. and &Measure_End.
		and (&claims_filter_All.)
	;
quit;

*Then select only the members in denominator;
proc sql;
	create table denom_Alcohol_SBIRT as
	select
		denom.Member_ID
		,1 as Denominator
	from (
		select distinct member_id
		from claims_interesting as Outclaims_PRM
		where 
			(&claims_filter_Denominator.)
			and PRM_Denied_YN eq 'N'
		) as denom
	order by denom.member_id
	;
quit;

*Now select the members in numerator and flag the members in numerator exclusion;
proc sql;
	create table numer_SBIRT_claim_level as
	select distinct
		numer.Member_ID
		,numer.ClaimID
		,numer.LineNum
		,numer.fromdate
		,numer.HCPCS
		,numer.RevCode
		,numer.POS
		,case
			when excl.LineNum is not null then 1
			else 0 
			end as exclusion_flag
		,case
			when calculated exclusion_flag eq 1 then 0
			else 1
			end
			as Numerator

	from 
	   (select distinct
			member_id
			,claimID
			,LineNum
			,fromdate
			,HCPCS
			,RevCode
			,POS
		from claims_interesting as OutClaims_PRM
		where
			(&claims_filter_Numerator.)
		) as numer

	left join
		(select distinct
			member_id
			,claimID
			,LineNum
			,fromdate
			,HCPCS
			,RevCode
			,POS
		from claims_interesting as OutClaims_PRM
		where 
		 	 (&claims_filter_Numer_Excl.)
		 or (&claims_filter_Numer_Excl_Procs.)
		) as excl
	on 
		numer.member_ID = excl.member_ID
		and numer.claimID = excl.claimID
		and numer.fromdate = excl.fromdate
		and numer.LineNum = excl.LineNum

	order by
		numer.member_id
		,calculated numerator desc /*Prioritize claims that hit numerator*/
		,numer.fromdate desc
		,calculated exclusion_flag /*Allow any portion of claim not excluded to count*/
	;
quit;

data numerator_detail;
	set numer_SBIRT_claim_level;
	by
		member_id
		descending numerator
		descending fromdate
		exclusion_flag
		;
	if first.member_id;
	format comments $128.;
	comments = cat("Recent screening on ",putn(fromdate,"MMDDYYs10."));
	if exclusion_flag eq 1 then comments = cat(
		strip(comments)
		," (occured in ED setting)"
		);
run;

*Merge the denomitor table and numerator table without numerator exclusion flag;
proc sql;
	create table M150_Out.Results_Alcohol_SBIRT
	as select distinct
		denom.member_ID
		,denom.Denominator
		,coalesce(numer.Numerator,0) as Numerator
		,numer.comments
		,case calculated numerator
			when 0 then &measure_end.
			else .
			end
			as comp_quality_date_actionable format = YYMMDDd10.

	from denom_Alcohol_SBIRT as denom

	left join numerator_detail as numer
		on denom.member_ID = numer.member_ID

	order by 
		denom.member_ID
	;
quit;

%LabelDataset(M150_Out.Results_Alcohol_SBIRT);

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
