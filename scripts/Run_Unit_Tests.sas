/*
### CODE OWNERS: Ben Copeland

### OBJECTIVE:
  Execute all the SAS unit tests embedded in the code base.

### DEVELOPER NOTES:
  This program *should* reach completion in a matter of minutes.
  It should also be ran via Continuous Integration on at least every Pull Request.
  At this time, it should not depend on any external data.
*/
%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes mprint;
%let dir_logs_local = %sysget(UserProfile)\prm_local\OHA_Incentive_Measures_Logs\;
%put dir_logs_local = &dir_logs_local.;
%CreateFolder(&dir_logs_local.Error_Check\)
libname lib_log "&dir_logs_local.";

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/




%RunProductionPrograms(
/* Where the code is      */ dir_program_src          = %sysget(OHA_INCENTIVE_MEASURES_HOME)\scripts\;
/* Where the logs go      */ ,dir_log_lst_output      = &dir_logs_local.
/* Where this log goes    */ ,library_process_log     = lib_log
/* Scrape subfolders      */ ,bool_traverse_subdirs   = True
/* Suppress Success Email */ ,bool_notify_success     = False
/* Program prefix to run  */ ,prefix_program_name     = Unit
/* Onboarding Whitelist   */ ,keyword_whitelist       = %str()
/* Onboarding Blacklist   */ ,keyword_blacklist       = %str()
/* CC'd Email Recepients  */ ,list_cc_email           = %str()
/* Email Subject Prefix   */ ,prefix_email_subject    = PRM Notification:
)

%put System Return Code = &syscc.;
