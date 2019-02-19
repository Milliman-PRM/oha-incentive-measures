## Documentation

This is a home for pulling eCQM value set information from [Unified Medical Language System](https://uts.nlm.nih.gov/home.html) (UMLS) using the UMLS Terminology Services (UTS) API.

## Usage Steps

  1. Obtain a UMLS username and password, currently residing with Katherine Castro
  2. Set up the value set input file, which determines which value sets will be requested from the API
	  - Requires `measure_name`, `value_set_name`, and `value_set_oid` columns.
	  - `measure_name` is intended to be the OHA incentive measure name
	  - `value_set_name` and `value_set_oid` can be parsed from the "Terminology" section of an eCQM specification (e.g. https://ecqi.healthit.gov/system/files/ecqm/measures/CMS122v7.html)
  3. Set up python environment in a shell using `setup_env.bat` in the root of this repository
  4. Call the `pull_value_sets.py` program from the shell, specifying the appropriate parameters
	  - Required parameters can be displayed by calling `python pull_value_sets.py --help`
	  - Example execution: `python pull_value_sets.py -u "test_username" -p "test_password" -i "in_value_sets.csv" -o "out_value_sets.csv"`
