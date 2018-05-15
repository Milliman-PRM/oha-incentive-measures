"""
### CODE OWNERS: Chas Busenburg

### OBJECTIVE:
  Compile the oha_incentive_measures reference data into convenient downstream formats

### DEVELOPER NOTES:
  This is not actually intended to be ran during a true production run.
  The value of os.environ['OHA_INCENTIVE_MEASURES_PATHREF`] guides where this writes to.
"""
import logging
import os
import typing
from pathlib import Path

from pyspark.sql.functions import col, when

import prm.meta.project
from prm.spark.app import SparkApp
from prm.spark.io_sas import write_sas_data
from prm.spark.io_txt import build_structtype_from_csv

LOGGER = logging.getLogger(__name__)
PATH_INPUT = Path(os.environ['OHA_INCENTIVE_MEASURES_HOME']) / 'references'
PATH_OUTPUT = Path(os.environ['OHA_INCENTIVE_MEASURES_PATHREF'])

# pylint: disable=unsubscriptable-object

# =============================================================================
# LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE
# =============================================================================


def import_flatfile_references(sparkapp: SparkApp) -> typing.Mapping[str, "DataFrame"]:
    """Import the reference data into parquet"""
    refs = dict()
    for _file in (PATH_INPUT / '_data').iterdir():
        name = _file.stem.lower()
        LOGGER.info("Loading %s and saving as '%s'", _file, name)
        schema_temp = build_structtype_from_csv(
            PATH_INPUT / '_schemas' / (_file.stem + '.csv'),
            )
        refs[name] = sparkapp.session.read.csv(
            str(_file),
            schema=schema_temp,
            sep=',',
            mode='FAILFAST',
            header=True,
            ignoreLeadingWhiteSpace=True,
            ignoreTrailingWhiteSpace=True,
            )

    return refs

def assert_references(refs: typing.Mapping) -> None:
    """OHA Code Sets should have a few fail early assertions associated with them."""

    for column_name in ['measure_abbreviation', 'measure_description']:
        try:
            refs['oha_abbreviations'].validate.assert_unique(column_name)
        except AssertionError as error:
            error.args = ("Abbreviation reference table is not well structured",)
            raise

    try:
        refs['oha_codes'].validate.assert_values({
            'measure': [row.measure_abbreviation for row in refs['oha_abbreviations'].collect()],
        })
    except AssertionError as error:
        error.args = ("Not all OHA code entries have a matching measure name abbreviation.",)
        raise

    try:
        refs['oha_codes'].select('measure', 'component', 'grouping_id').distinct().filter(
            refs['oha_codes'].grouping_id.isNotNull()
        ).validate.assert_unique('component', 'grouping_id')
    except AssertionError as error:
        error.args = ("OHA_Codes have Grouping_IDs that are not unique by Component",)
        raise


    try:
        refs['oha_codes'].validate.assert_values({
            'codesystem':[
                'CPT',
                'HCPCS',
                'ICD9CM-Proc',
                'ICD9CM-Diag',
                'ICD10CM-Proc',
                'ICD10CM-Diag',
                'ICD10CM-Proc',
                'UBREV',
                'POS',
                'NDC',
                'CDT',
                'MODIFIER',
                'SNOMEDCT',
                'DENTAL',
                'TOOTH',
            ]
        })
    except AssertionError as error:
        error.args = ('Unsupported code systems were specified',)
        raise

    assert len(refs['oha_codes'].filter(
        (col('codesystem').isin({'ICD9CM-Diag', 'ICD10CM-Diag'})
         & ~col('diag_type').isin({'', 'All', 'Primary', 'Secondary'}))
        |
        (~col('codesystem').isin({'ICD9CM-Diag', 'ICD10CM-Diag'})
         & (col('diag_type') != ''))
    ).head(1)) == 0, 'Unsupported diag types were specified'

    try:
        refs['oha_codes'].select(
            'measure',
            'component',
            'grouping_id',
            'code_raw',
        ).distinct().filter(
            col('grouping_id').isNotNull()
            & col('codesystem').isin({'ICD9CM-Diag', 'ICD10CM-Diag'})
            & (col('diag_type') == 'Primary')
        ).validate.assert_unique('measure', 'component', 'grouping_id')
    except AssertionError as error:
        error.args = ('Multiple primary diagnosis codes were specified with the same Grouping_ID',)
        raise

    try:
        refs['oha_codes'].select(
            'measure',
            'component',
            when(col('codesystem') == 'NDC', 'Outpharmacy').otherwise('Outclaims')
        ).distinct().validate.assert_unique('measure', 'component')
    except AssertionError as error:
        error.args = ('Multiple aliased source tables will appear in same filter macro variable.',)
        raise


def main() -> int:  # pragma: no cover
    """Import the oha incentive measures reference files and write to parquet"""
    LOGGER.info('Compiling oha incentive measures reference files')
    sparkapp = SparkApp('ref_oha_incentive_measures',allow_local_io=True)
    sparkapp.spark_sql_shuffle_partitions = 3

    LOGGER.info("Serializing reference data")
    refs = import_flatfile_references(
        sparkapp,
        )

    LOGGER.info("Running assertions against reference files")
    assert_references(refs)

    LOGGER.info('Writing compiled reference data to %s', PATH_OUTPUT)
    for name, dataframe in refs.items():
        sparkapp.save_df(
            dataframe,
            PATH_OUTPUT / '{}.parquet'.format(name),
            )
        write_sas_data(
            dataframe,
            PATH_OUTPUT / '{}.sas7bdat'.format(name),
            allow_local_io=sparkapp.kwargs_init['allow_local_io'],
            )

    sparkapp.sql_shuffle_partitions_multiplier = 1

    return 0


if __name__ == '__main__':  # pragma: no cover
    # pylint: disable=wrong-import-position, wrong-import-order, ungrouped-imports
    import sys
    import prm.utils.logging_ext

    prm.utils.logging_ext.setup_logging_stdout_handler()

    with SparkApp('ref_waste_calculator'):
        RETURN_CODE = main()

    sys.exit(RETURN_CODE)
