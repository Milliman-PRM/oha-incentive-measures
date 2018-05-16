/*
### CODE OWNERS: Ben Copeland, Shea Parkes

### OBJECTIVE:
	Copy reference files forward so that external modifications can be made
	here rather than in the source data

### DEVELOPER NOTES:
	
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options
	compress = yes
	;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2; 

/* Libnames */
libname oha_ref "%sysget(OHA_INCENTIVE_MEASURES_PATHREF)" access = readonly;
libname M150_Out "&M150_Out.";

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/

data m150_out.oha_abbreviations;
	set oha_ref.oha_abbreviations;
run;

%put System Return Code = &syscc.;
