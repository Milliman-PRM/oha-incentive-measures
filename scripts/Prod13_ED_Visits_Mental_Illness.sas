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