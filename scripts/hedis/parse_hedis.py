"""
### CODE OWNERS: Ben Copeland

### OBJECTIVE:
  Convert HEDIS codes list into repository-standard schema

### DEVELOPER NOTES:
  Input measure mapping requires "Measure", "Value Set Name", and "Component"
"""

import os
import sys
from pathlib import Path

import pandas as pd

PATH_ENV = Path(os.environ['oha_incentive_measures_home'])
PATH_MEASURE_MAPPING = PATH_ENV / 'scripts' / 'hedis' / 'measure_mapping.csv'
PATH_CODES_LIST = PATH_ENV / 'scripts' / 'hedis' / 'hedis_codes.csv'
PATH_OUTPUT = PATH_ENV / 'references' / '_data' / 'hedis_codes.csv'

# pylint: disable=no-member

# LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE

def main() -> int:
    """Contains business logic"""
    measure_mapping = pd.read_csv(
        PATH_MEASURE_MAPPING,
        header=0,
        index_col=None,
    )
    codes_list = pd.read_csv(
        PATH_CODES_LIST,
        header=0,
        index_col=None,
        low_memory=False,
    )

    mapped_codes = codes_list.merge(
        measure_mapping,
        on='Value Set Name',
        how='inner',
    )

    code_system_map = {
        'SNOMED CT US Edition': 'SNOMEDCT',
        'CPT': 'CPT',
        'HCPCS': 'HCPCS',
        'ICD10CM': 'ICD10CM-Diag',
        'ICD10PCS': 'ICD10CM-Proc',
        'ICD9CM': 'ICD9CM-Diag',
        'ICD9PCS': 'ICD9CM-Proc',
        'LOINC':'LOINC',
        'UBREV': 'UBREV',
        'RXNORM': 'RXNORM',
    }
    mapped_codes_skinny = mapped_codes[[
        'Measure',
        'Component',
        'Code',
        'Code System',
    ]].assign(
        CodeSystem=lambda df: df['Code System'].map(code_system_map),
        Grouping_ID='',
        Diag_Type='',
    )[[
        'Measure',
        'Component',
        'CodeSystem',
        'Code',
        'Grouping_ID',
        'Diag_Type',
    ]]
    mapped_codes_skinny.to_csv(
        str(PATH_OUTPUT),
        header=True,
        index=False,
    )
    return 0

if __name__ == '__main__':
    sys.exit(main())
