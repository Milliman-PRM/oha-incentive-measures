## Release Notes

A non-exhaustive list of what has changed in a more readable form than a commit history.

### v1.6.0
  - Retired measure calculations that are no longer incentivized:
    - Adolescent Well Care Visits
    - Colorectal Cancer Screening
    - ED Visits Utilization
    - Dental Sealants for Children
    - Development Screening in first 36 months
    - Effective Contraceptive Use
  - Added measure calculation and supporting files for:
    - Well Child Visits for Ages 3-6
    - Preventive Dental Services Ages 1-5, Preventive Dental Services Ages 6-14
    - Well Child Visits for Ages 3-6
    - Prenatal and Postpartum Care
    - Initiation and Engagement of Alcohol and Other Drug Abuse or Dependence Treatment

### v1.5.0
  - Added testing of reference data compilation as part of CI via `run_tests.bat`
  - Updated calculations to meet 2020 specifications:
    - Oral Evaluation for Adults with Diabetes
    - Disparity Measure: Emergency Department Utilization for Individuals Experiencing Mental Illness
    - Assessments for Children in DHS Custody

### v1.4.4
  - Fixes the calculation of the DHS Assessment measure start date to be November 1 of the year prior to the measurement year.

### v1.4.3
  - Now sourcing reference data from the environment variable `reference_data_pathref`. Currently only applies to Effective Contraceptive Use measure

### v1.4.2

  - Break out component SBIRT and Childhood Obesity measures so they can be displayed in the CCR.
  
### v1.4.1

  - Add New Measure Oral-Evaluation for Adults with Diabetes Measure to CCO Incentive Measures for 2019

### v1.4.0

 - Update Oregon Health Authority CCO Incentive Measures for 2019
   - Changes overview can be found in [CCO Incentive Measure Specification Changes between 2019 and 2019](https://www.oregon.gov/oha/HPA/ANALYTICS/CCOData/2019-incentive-measure-Specification-Changes-Summary.pdf)
     - Update Adolescent Well Care Codes and include hospice exclusion to denominator
     - Update Ambulatory Care: Emergency Department Utilization Codes and hospice exclusion logic
     - Update Assessments for Children in DHS Custody Codes
     - Update Cigarette Smoking Prevalence Codes and included year prior to measurement year in status derivation
     - Update Colorectal Cancer Screening codes and include frailty with advanced illness exclusion to denominator
     - Removal of Controlling Hypertension logic -> Source of Truth now 0273WOH
     - Removal of Depression Screening logic -> Source of Truth now 0273WOH
     - Removal of Diabetes: HbA1c Poor Control logic -> Source of Truth now 0273WOH
     - Update Disparity Measure: ED Utilization for Individuals Experiencing MI Codes
     - Update Effective Contraceptive Use Codes and include permanent contraceptives
     - Removal of Weight Assessment and Counseling In Children and Adolescents -> Source of Truth now 0273WOH
 - Added a workflow to pull eCQM code sets using UMLS Terminology Services (UTS) API in `scripts/value_sets`

### v1.3.1
 - Removed unnecessary `CopyReferenceFiles` class from Luigi pipeline
 -  Added missing read-write access to M150_Out in the `Prod42_Combine_All.sas program`

### v1.3.0
 - Added remaining WOH reference codesets

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
