/*
### CODE OWNERS: Chas Busenburg

### OBJECTIVE:
    Calculate the Oral-Evaluation for Adults with Diabetes

### DEVELOPER NOTES:

*/

%include "%sysget(INDYHEALTH_LIBRARY_HOME)\include_sas_macros.sas" / source2;
options compress = yes;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\010_Master\Supp01_Parser.sas" / source2;
%include "%sysget(ANALYTICS_PIPELINE_HOME)\150_Quality_Metrics\Supp01_Shared.sas" / source2;

libname oha_ref "%sysget(OHA_INCENTIVE_MEASURES_PATHREF)" access=readonly;
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
%let Measure_Name = diabetes_oral_eval;
%let Age_Adult = ge 18;
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=numerator
    ,Reference_Source=oha_ref.oha_codes
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_exclusion
    ,Reference_Source=oha_ref.oha_codes
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_medication
    ,Reference_Source=oha_ref.medications
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_one_visit
    ,Reference_Source=oha_ref.hedis_codes
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_diabetes
    ,Reference_Source=oha_ref.hedis_codes
    );
%CodeGenClaimsFilter(
    &Measure_Name.
    ,Component=denom_two_visits
    ,Reference_Source=oha_ref.hedis_codes
    );
