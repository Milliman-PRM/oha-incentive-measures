# Readme

Files:
  - `ecqm_value_sets.csv` - Value sets that are able to be pulled through the ecqm API [eCQI Resource Center](https://ecqi.healthit.gov/) primarily clical measures. Generated using `scripts/value_sets/pull_value_sets.py` in conjunction with the definitions in `in_value_sets.csv`
  - `OHA_Abbreviations.csv` - Effectively the mapping between our measure abbreviation and the actual measure description.
  - `OHA_Codes.csv` - All codes necessary for oha-incentive-measures that are not in the `ecqm_value_sets.csv` file.
