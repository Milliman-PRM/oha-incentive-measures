## Release Notes

A non-exhaustive list of what has changed in a more readable form than a commit history.

### v1.2.0
 - Updated `Emergency Dept Utilization for Individuals Experiencing Mental Illness` to `ED Utilization Among Members with Mental Illness`

### v1.1.0

- Updated Oregon Health Authority CCO Incentive Measures for 2018.
    - Changes overview can be found in [CCO Incentive Measure Specification Changes Between 2017 and 2018](http://www.oregon.gov/oha/HPA/ANALYTICS/CCOData/2018%20Incentive%20Measure%20Specification%20Changes%20Summary.pdf)
      - Updated Ambulatory Care Codes
      - Adjust start of inclusion period for assessments for children in DHS custody from Jan 1 -> Nov 1
      - Updated Colorectal Cancer Screen Codes
      - Updated Effective Contraceptive use incentive measure range age from 18-50 years -> 15-50 years
      - Updated Diabetes: HbA1c Poor Control Codes
    - Added calculation of "Disparity Measure: Emergency Department Utilization for Individuals Experiencing Mental Illness"

### v1.0.2
  - Logic in the Effective Contraceptive Use program has been updated to correctly account for Numerator & Denominator Exclusions.

### v1.0.1

  - Standard measure calculations are now requirements of the custom measure injection, since our current custom measures use/overwrite the standard measure calculations

### v1.0.0

  - Initial release of product component
    - Set up python library for promotion, reference data creation, and Luigi pipeline
    - Moved measure calculation scripts and related reference data into this component
    - Updated measure calculation scripts to work with compiled reference data
    - Moved unit test scripts into this component
    - Set up CI framework
