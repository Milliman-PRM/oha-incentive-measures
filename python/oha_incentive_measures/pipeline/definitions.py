"""
### CODE OWNERS: Steve Gredell, Chas Busenburg

### OBJECTIVE:
  Define tasks for OHA quality metrics

### DEVELOPER NOTES:

"""

from indypy.nonstandard.ext_luigi import IndyPyLocalTarget, build_logfile_name
import prm.meta.project
from prm.ext_luigi.base_tasks import PRMSASTask, RequirementsContainer

from prm.execute.definitions import (
    ref_product,
    staging_membership,
    poweruser_detail_datamart,
    staging_emr,
)

PRM_META = prm.meta.project.parse_project_metadata()

# =============================================================================
# LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE
# =============================================================================


class AlcoholSBIRT(PRMSASTask):  # pragma: no cover
    """Run Prod01_Alcohol_SBIRT.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod01_Alcohol_SBIRT.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class AdolescentWellCare(PRMSASTask):  # pragma: no cover
    """Run Prod02_Adolescent_Well_Care.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod02_Adolescent_Well_Care.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class ColorectralCancerScreening(PRMSASTask):  # pragma: no cover
    """Run Prod03_Colorectal_Cancer_Screening.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod03_Colorectal_Cancer_Screening.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class DevelopmentalScreening(PRMSASTask):  # pragma: no cover
    """Run Prod04_Developmental_Screening.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod04_Developmental_Screening.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class EDVisits(PRMSASTask):  # pragma: no cover
    """Run Prod05_ED_Visits.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod05_ED_Visits.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class EffectiveContraceptive(PRMSASTask):  # pragma: no cover
    """Run Prod06_Effective_Contraceptive.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod06_Effective_Contraceptive.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class FollowUpMentalHospitialization(PRMSASTask):  # pragma: no cover
    """Run Prod07_follow_up_mental_hospitalization.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
        staging_membership.DeriveParamsFromMembership,
        poweruser_detail_datamart.ExportSAS,
    )

    def output(self):
        names_output = {
            'results_fuh_mental.sas7bdat'
        }
        return [
            IndyPyLocalTarget(PRM_META[(150, 'out')] / name)
            for name in names_output
            ]

    def run(self):  # pylint: disable=arguments-differ
        """Run the Luigi job"""
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod07_follow_up_mental_hospitalization.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class AssessmentsForDHSChildren(PRMSASTask):  # pragma: no cover
    """Run Prod08_Assessments_for_DHS_children.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod08_Assessments_for_DHS_children.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class Hypertension(PRMSASTask):  # pragma: no cover
    """Run Prod09_Hypertension.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod09_Hypertension.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class DiabetesHbA1c(PRMSASTask):  # pragma: no cover
    """Run Prod10_Diabetes_HbA1c.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod10_Diabetes_HbA1c.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class Tobacco(PRMSASTask):  # pragma: no cover
    """Run Prod11_Tobacco.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod11_Tobacco.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class DentalSealant(PRMSASTask):  # pragma: no cover
    """Run Prod12_Dental_Sealant.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod12_Dental_Sealant.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class CopyReferenceFiles(PRMSASTask):  # pragma: no cover
    """Run Prod40_Copy_Reference_Files.sas"""

    requirements = RequirementsContainer(
        ref_product.OHACodeSets,
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
        program = PRM_META[(150, 'code')] / "OHA_Incentive_Measures" \
                  / "Prod40_Copy_Reference_Files.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


class CombineAll(PRMSASTask):  # pragma: no cover
    """Run Prod42_Combine_All.sas"""

    requirements = RequirementsContainer(
        ancillary_inputs.Validation,
        quality_metrics_oha.CopyReferenceFiles,
        quality_metrics_oha.AlcoholSBIRT,
        quality_metrics_oha.AdolescentWellCare,
        quality_metrics_oha.ColorectralCancerScreening,
        quality_metrics_oha.DevelopmentalScreening,
        quality_metrics_oha.EDVisits,
        quality_metrics_oha.EffectiveContraceptive,
        quality_metrics_oha.FollowUpMentalHospitialization,
        quality_metrics_oha.AssessmentsForDHSChildren,
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
        program = PRM_META[(150, 'code')]  / "OHA_Incentive_Measures" \
                  / "Prod42_Combine_All.sas"
        super().run(
            program,
            path_log=build_logfile_name(program, PRM_META[(150, 'log')] / "OHA_Incentive_Measures"),
            create_folder=True,
        )
        # pylint: enable=arguments-differ


def inject_emr_measures():  # pragma: no cover
    """Inject EMR Mesure tasks into CombineAllOHA"""
    CombineAll.add_requirements(
        quality_metrics_oha.Hypertension,
        quality_metrics_oha.DiabetesHbA1c,
        quality_metrics_oha.Tobacco,
    )


