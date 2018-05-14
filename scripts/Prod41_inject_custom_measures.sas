/*
### CODE OWNERS: Kyle Baird, Shea Parkes

### OBJECTIVE:
	Execute any client specific program that may contain custom quality measure
	calculations

### DEVELOPER NOTES:
	Run after all quality measures to allow for overwrites of existing calculations
	Suppressed for demos because we do not expect onboarding to have an anonymization
		process in place
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options
	compress = yes
	;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2; 

%AssertThat(%upcase(&quality_metrics.),eq, OHA_INCENTIVE_MEASURES
			,ReturnMessage=The user has not chosen to run OHA Incentive Measures.  This program does not need run.
			,FailAction = EndActiveSASSession 
			);

%AssertThat(
	%upcase(&anonymize.)
	,eq
	,FALSE
	,ReturnMessage=Custom quality measures are only allowed for non-demo runs to protect ePHI.
	,FailAction=EndActiveSASSession
	)

/* Libnames */
libname M150_Log "&M150_Log.";

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




%RunProductionPrograms(
	dir_program_src=&path_onboarding_code.
	,dir_log_lst_output=&M150_Log.
	,name_python_environment=&python_environment.
	,library_process_log=M150_Log
	,bool_traverse_subdirs=True
	,bool_notify_success=False
	,prefix_program_name=QM
	,list_cc_email=%sysfunc(ifc("%upcase(&Launcher_Email_CClist.)" ne "ERROR"
		,&launcher_email_cclist.
		,%str()
		))
	,prefix_email_subject=&notification_email_prefix.
	)

%put System Return Code = &syscc.;
