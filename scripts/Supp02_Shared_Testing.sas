/*
### Code Owners: Shea Parkes, Neil Schneider, Scott Cox
  
### Objective:
  Consolidate some of the Unit testing boilerplate into here

### Developer Notes:
  None
*/


/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/


%macro SetupMockLibraries();
	%MockLibrary(oha_ref, pollute_global=True)
	%MockLibrary(M025_Out, pollute_global=True)
	%MockLibrary(M035_Out, pollute_global=True)
	%MockLibrary(M036_Out, pollute_global=True)
	%MockLibrary(M073_Out, pollute_global=True)
	%MockLibrary(M150_Tmp, pollute_global=True)
	%MockLibrary(M150_Out, pollute_global=True)
	%MockLibrary(M030_Out, pollute_global=True)
%mend;

%macro CompareResults(
	dset_expected=m150_tmp.member
	,dset_compare=m150_out.Results_&Measure_Name.
	);
	proc sql noprint;
		create table Unexpected_results as
			select
				exp.*
				,coalesce(act.Denominator, 0) as Actual_Denominator
				,coalesce(act.Numerator, 0) as Actual_Numerator
		from &dset_expected. as exp
		left join &dset_compare. as act
			on exp.member_ID = act.member_ID
		where 
			round(exp.anticipated_denominator,.0001) ne round(calculated Actual_Denominator,.0001)
			or round(exp.anticipated_numerator,.0001) ne round(calculated Actual_Numerator,.0001)
		;
	quit;

	%AssertDataSetNotPopulated(Unexpected_results, ReturnMessage=The &Measure_Name. results are not as expected.  Aborting...)
%mend;

%macro DeleteWorkAndResults();
	proc datasets nolist library=work kill;
	proc datasets nolist library=M150_Out kill;
	quit;
%mend;


%put System Return Code = &syscc.;
