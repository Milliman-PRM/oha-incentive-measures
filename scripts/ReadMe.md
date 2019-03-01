## Documentation

Home for scripts that calculate or orchestrate the calculation of OHA Quality Metrics

## Notes

This module should aid in calculating a portion of the Oregon Office of Health Analytics (OHA) Quality/Incentive Measures for Coordinated Care Organizations (CCOs).  Details of these metrics can be found [here](http://www.oregon.gov/oha/analytics/Pages/CCO-Baseline-Data.aspx).

No external, useful table of abbreviations could be found, so please refer to our internal reference data for a consistent list of abbreviations.

### Results formats

The current design pattern is for each measure program to produce a single `Results_(Measure_Name)` file.  This file would have the following fields:

| Field Name | Field Description |
| :--------- | :---------------- |
| `Member_ID` | Member level identifier.  Only one record per member should be included. |
| `Denominator` | This member's contribution to the measure denominator.  Will often (but not always) be `1` or `0`. |
| `Numerator` | This member's contribution to the measure numerator.  Will often (but not always) be `1` or `0`. |
| `Comments` | Free text that provides useful information about a member's numerator/denominator status. |
| `comp_quality_date_actionable` | Date that the member's contribution can be modified by |

### Injecting custom quality measure calculations

In order to support eCQM based quality measures (and because we do not currently have all information needed to calculate these measures in our existing EMR schema), custom quality measure programs can be "injected" into the outputs. To do this, we will sweep the onboarding code location for any programs prefixed with `QM` and execute at module run-time.

~Rules for these programs:

  * Must execute cleanly without error (just like all other current onboarding code)
  * Results must be presented in the format described above
  * Additional reference data manipulation may be necessary (if the measure is not included in main pipeline)
    * If the measure is not included reference file `[module 015 code]/Flatfile_Sources/Ref028_OHA_Abbreviations.csv`, you will need to append any entry for the measure to the resulting output file `[module 015 out]/OHA_Abbreviations.sas7bdat`
    * If the measure is not included in reference file `[Module 036 out]/Targets_quality_measures.sas7bdat`, targets will need to be added
    * The process will fail if a measure is calculated but not contained within these reference data sets
    * Any required reference data update must be complete prior to combining of all measures (currently `Prod042` in module 150)
  * Program names must be prefixed with `QM` and stored in the same directory as other onboarding code
  * Programs will execute in an isolated subprocess. They should be able to execute independently
  * Programs will execute in the `150` module. Programs can be expected to have access to PUDD, and other shared functions defined in the analytics pipeline
  * Programs will not be executed for demo runs (to protect any non-anonymized ePHI use by custom program)

### Where are the Clinical Measures?

Due to the Clinical Measures needing EMR, we only have one client currently that can calculate these measures, and they do all the calculations within their post-boarding process. As such, the code represented here was very outdated, and did produce as expected. They were removed in [Remove Clinical Measures](https://indy-github.milliman.com/PRM/oha-incentive-measures/62).

The Current Clinical Measures are located in the [WOH Repo](https://indy-github.milliman.com/PRM-Productions/0273WOH_Medicaid)

  - `Hypertension`
  - `Diabetes_HbA1c`
  - `Depression_Screening`
  - `Tobacco_Prevalence`
  - `Childhood_Obesity`
  - `Alcohol SBIRT`
  - `BMI_Screening`
