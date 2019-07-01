@echo off
rem ### CODE OWNERS: Ben Copeland, Shea Parkes
rem
rem ### OBJECTIVE:
rem   Run the tests for this solution.
rem
rem ### DEVELOPER NOTES:
rem   <None>
SETLOCAL ENABLEDELAYEDEXPANSION

echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Running tests for the OHA Incentive Measures
echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Running from %~f0

echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Setting up testing environment
call "%~dp0setup_env.bat"

echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Seeding error level to zero
set CI_ERRORLEVEL=0

SET REFERENCE_DATA_PATHREF=K:\PHI\0273ZDM\3.000-0273ZDM02\xx-dev\test_reference_data\_testing_refdata\REFERENCE_DATA

echo %~nx0 !DATE:~-4!-!DATE:~4,2!-!DATE:~7,2! !TIME!: Running SAS unit tests
python "%PATH_HOTWARE_DRIVE%\Jenkins\batch_submit_sas_and_tail_log.py" scripts\Run_Unit_Tests.sas
if !errorlevel! neq 0 set CI_ERRORLEVEL=!errorlevel!
echo %~nx0 !DATE:~-4!-!DATE:~4,2!-!DATE:~7,2! !TIME!: SAS unit tests finished with ErrorLevel=!ERRORLEVEL!


echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Finshed running tests for the OHA Incentive Measures with ErrorLevel=!CI_ERRORLEVEL!
exit /b !CI_ERRORLEVEL!
