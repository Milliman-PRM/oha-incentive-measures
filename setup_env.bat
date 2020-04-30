@echo off
rem ### CODE OWNERS: Shea Parkes, Chas Busenburg
rem
rem ### OBJECTIVE:
rem   Setup the environment for CI, Development and promotion purposes.
rem
rem ### DEVELOPER NOTES:
rem   Not intended to be ran during production situations.

echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Setting up environment (mostly for testing)
echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Running from %~f0

rem ### LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE


echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Starting from last promoted pipeline_components_env.bat
call S:\PRM\Pipeline_Components_Env\pipeline_components_env.bat
echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Overwriting code base location with current local copy
set OHA_INCENTIVE_MEASURES_HOME=%~dp0
echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Putting local python package at front of PythonPath
set PYTHONPATH=%OHA_INCENTIVE_MEASURES_HOME%\python;%PYTHONPATH%

echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Setting up local OHA_INCENTIVE_MEASURES_PATHREF
rem !!!This PathRef is intentionally overwritten during the promotion process!!!
set OHA_INCENTIVE_MEASURES_PATHREF=%~dp0\_ci_compiled_reference_data
mkdir %OHA_INCENTIVE_MEASURES_PATHREF%
echo %~nx0 !DATE:~-4!-!DATE:~4,2!-!DATE:~7,2! !TIME!: OHA_INCENTIVE_MEASURES_PATHREF=%OHA_INCENTIVE_MEASURES_PATHREF%


echo %~nx0 %DATE:~-4%-%DATE:~4,2%-%DATE:~7,2% %TIME%: Finished setting up environment
