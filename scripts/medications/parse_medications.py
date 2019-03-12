"""
### CODE OWNERS: Ben Copeland

### OBJECTIVE:
  Convert medications list into repository-standard schema

### DEVELOPER NOTES:
  Input measure mapping requires "measure", "medication list", and "component"
"""

import os
from pathlib import Path

import pandas as pd

PATH_ENV = Path(os.environ['oha_incentive_measures_home'])
PATH_MEASURE_MAPPING = PATH_ENV / 'scripts' / 'medications' / 'measure_mapping.csv'
PATH_MEDICATION_LIST = PATH_ENV / 'scripts' / 'medications' / 'medications_list.csv'
PATH_OUTPUT = PATH_ENV / 'references' / '_data' / 'medications.csv'

# LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE

def main() -> int:
    """Contains business logic"""
    measure_mapping = pd.read_csv(
        PATH_MEASURE_MAPPING,
        header=0,
        index_col=None,
    )
    medication_list = pd.read_csv(
        PATH_MEDICATION_LIST,
        header=0,
        index_col=None,
        dtype={
            'NDC Code': 'object',
        },
        low_memory=False,
    )
    mapped_medications = medication_list.merge(
        measure_mapping,
        on='Medication List',
        how='inner',
    )
    mapped_medications_skinny = mapped_medications[[
        'Measure',
        'Component',
        'NDC Code',
    ]].assign(
        Grouping_ID='',
        Diag_Type='',
        CodeSystem='NDC',
    ).rename(
        columns={
            'NDC Code': 'Code',
        },
    )[[
        'Measure',
        'Component',
        'CodeSystem',
        'Code',
        'Grouping_ID',
        'Diag_Type',
    ]]
    mapped_medications_skinny.to_csv(
        str(PATH_OUTPUT),
        header=True,
        index=False,
    )
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
