@echo off
rem ### CODE OWNERS: Ben Copeland, Shea Parkes
rem
rem ### OBJECTIVE:
rem   Compile the reference data for local testing/development.
rem
rem ### DEVELOPER NOTES:
rem   <None>
SETLOCAL ENABLEDELAYEDEXPANSION

echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Compiling reference data for OHA Incentive Measure solution
echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Running from %~f0

echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Setting up testing environment
call "%~dp0setup_env.bat"

echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Seeding error level to zero
set FINAL_ERRORLEVEL=0

echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Beginning compilation of reference data
python -m oha_incentive_measures.reference
if !errorlevel! neq 0 set FINAL_ERRORLEVEL=!errorlevel!
echo %~nx0 !DATE:~-4!-!DATE:~4,2!-!DATE:~7,2! !TIME!: Reference data compilation finished with ErrorLevel=!FINAL_ERRORLEVEL!
exit /b !FINAL_ERRORLEVEL!
