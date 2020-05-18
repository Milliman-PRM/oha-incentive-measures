"""
### CODE OWNERS: Ben Copeland, Chas Busenburg

### OBJECTIVE:
  Define tasks for OHA quality metrics

### DEVELOPER NOTES:

"""
import os
from pathlib import Path

import oha_incentive_measures.reference
from indypy.nonstandard.ext_luigi import IndyPyLocalTarget, build_logfile_name
import prm.meta.project
from prm.ext_luigi.base_tasks import PRMSASTask, PRMPythonTask, RequirementsContainer

from prm.execute.definitions import (
    staging_membership,
    poweruser_detail_datamart,
    staging_emr,
    ancillary_inputs,
)

PATH_SCRIPTS = Path(os.environ['oha_incentive_measures_home']) / 'scripts'
PATH_REFDATA = Path(os.environ['oha_incentive_measures_pathref'])
PRM_META = prm.meta.project.parse_project_metadata()

# =============================================================================
# LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE
# =============================================================================


class ImportReferences(PRMPythonTask): # pragma: no cover
    """Run reference.py"""

    requirements = RequirementsContainer()

    def output(self):
        names_output = {
            'oha_abbreviations.parquet',
            'ecqm_value_sets.parquet',
            'hedis_codes.parquet',
            'medications.parquet',
            'oha_codes.parquet',
            'oha_abbreviations.sas7bdat',
            'ecqm_value_sets.sas7bdat',
            'hedis_codes.sas7bdat',
            'medications.sas7bdat',
            'oha_codes.sas7bdat',
        }
        return [
            IndyPyLocalTarget(PATH_REFDATA / name)
            for name in names_output
        ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = Path(oha_incentive_measures.reference.__file__)
        super().run(
            program,
            path_log=build_logfile_name(
                program,
                PATH_REFDATA,
            )
        )
        # pylint: enable=arguments-differ


class AdolescentWellCare(PRMSASTask):  # pragma: no cover
    """Run Prod02_Adolescent_Well_Care.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_adolescent_well_care.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod02_Adolescent_Well_Care.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class ColorectralCancerScreening(PRMSASTask):  # pragma: no cover
    """Run Prod03_Colorectal_Cancer_Screening.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_crc_screening.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod03_Colorectal_Cancer_Screening.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class DevelopmentalScreening(PRMSASTask):  # pragma: no cover
    """Run Prod04_Developmental_Screening.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_dev_screening.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod04_Developmental_Screening.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class EDVisits(PRMSASTask):  # pragma: no cover
    """Run Prod05_ED_Visits.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_ed_visits.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod05_ED_Visits.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class EffectiveContraceptive(PRMSASTask):  # pragma: no cover
    """Run Prod06_Effective_Contraceptive.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_eff_contra.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod06_Effective_Contraceptive.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ

class AssessmentsForDHSChildren(PRMSASTask):  # pragma: no cover
    """Run Prod08_Assessments_for_DHS_children.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_DHS_assessments.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod08_Assessments_for_DHS_children.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ

class EDVisitsMI(PRMSASTask):  # pragma: no cover
    """Run Prod13_ED_Visits_Mental_Illness.sas"""

    requirements = RequirementsContainer(
        EDVisits,
        staging_emr.Validation,
    )

    def output(self):
        names_output = {
            'results_ED_Visits_MI.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod13_ED_Visits_Mental_Illness.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ

class DentalSealant(PRMSASTask):  # pragma: no cover
    """Run Prod12_Dental_Sealant.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_Dental_Sealants.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod12_Dental_Sealant.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ

class DiabetesOralEval(PRMSASTask): # pragma: no cover
    """ Run Prod14_Diabetes_Oral_Eval.sas"""
    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_Diabetes_Oral_Eval.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod14_Diabetes_Oral_Eval.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )

class WellChildVisits(PRMSASTask): # pragma: no cover
    """ Run Prod15_well_child_visits.sas"""
    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_well_child_visits.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod15_well_child_visits.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )

class DentalServices(PRMSASTask): # pragma: no cover
    """ Run prod16_dental_services.sas"""
    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_prev_dental_1_to_5.sas7bdat',
            'results_prev_dental_6_to_14.sas7bdat',
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "prod16_dental_services.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,

class InjectCustomMeasures(PRMSASTask):  # pragma: no cover
    """Run prod41_inject_custom_measures.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        ancillary_inputs.Validation,
        AdolescentWellCare,
        ColorectralCancerScreening,
        DevelopmentalScreening,
        EDVisits,
        EffectiveContraceptive,
        EDVisitsMI,
        WellChildVisits,
    )

    def output(self):
        names_output = {
            'prod41_inject_custom_measures.sas.complete'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "prod41_inject_custom_measures.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class CombineAll(PRMSASTask):  # pragma: no cover
    """Run Prod42_Combine_All.sas"""

    requirements = RequirementsContainer(
        InjectCustomMeasures,
    )

    def output(self):
        names_output = {
            'oha_stacked_results_raw.sas7bdat'
            'ref_quality_measures.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod42_Combine_All.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


def inject_dhs_assessments(): #pragma: no cover
    """Inject DHS assessment tasks into InjectCustomMeasures"""
    InjectCustomMeasures.add_requirements(
        AssessmentsForDHSChildren,
    )


def inject_dental_measures(): #pragma: no cover
    """Inject Dental tasks into InjectCustomMeasures"""
    InjectCustomMeasures.add_requirements(
        DentalSealant,
        DiabetesOralEval,
        DentalServices,
    )


def inject_emr_measures():  # pragma: no cover
    """Inject EMR Mesure tasks into InjectCustomMeasures"""
    InjectCustomMeasures.add_requirements(
    )
