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
            'oha_codes.parquet',
            'oha_abbreviations.sas7bdat',
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


class AlcoholSBIRT(PRMSASTask):  # pragma: no cover
    """Run Prod01_Alcohol_SBIRT.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_Alcohol_SBIRT.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod01_Alcohol_SBIRT.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
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


class Hypertension(PRMSASTask):  # pragma: no cover
    """Run Prod09_Hypertension.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        staging_emr.Validation,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_hypertension.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod09_Hypertension.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class DiabetesHbA1c(PRMSASTask):  # pragma: no cover
    """Run Prod10_Diabetes_HbA1c.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        staging_emr.Validation,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_Diabetes_HbA1c.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod10_Diabetes_HbA1c.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class Tobacco(PRMSASTask):  # pragma: no cover
    """Run Prod11_Tobacco.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
        staging_membership.DeriveParamsFromMembership,
        staging_emr.Validation,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_tobacco.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod11_Tobacco.sas"
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


class CopyReferenceFiles(PRMSASTask):  # pragma: no cover
    """Run Prod40_Copy_Reference_Files.sas"""

    requirements = RequirementsContainer(
        ImportReferences,
    )

    def output(self):
        names_output = {
            'oha_abbreviations.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PATH_SCRIPTS / "Prod40_Copy_Reference_Files.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class InjectCustomMeasures(PRMSASTask):  # pragma: no cover
    """Run prod41_inject_custom_measures.sas"""

    requirements = RequirementsContainer(
        CopyReferenceFiles,
        ancillary_inputs.Validation,
        CopyReferenceFiles,
        AlcoholSBIRT,
        AdolescentWellCare,
        ColorectralCancerScreening,
        DevelopmentalScreening,
        EDVisits,
        EffectiveContraceptive,
        FollowUpMentalHospitialization,
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

	
def inject_dental_sealant(): #pragma: no cover
    """Inject Dental Sealants tasks into InjectCustomMeasures"""
    InjectCustomMeasures.add_requirements(
        DentalSealant,
    )


def inject_emr_measures():  # pragma: no cover
    """Inject EMR Mesure tasks into InjectCustomMeasures"""
    InjectCustomMeasures.add_requirements(
        Hypertension,
        DiabetesHbA1c,
        Tobacco,
    )
