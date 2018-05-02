# -*- coding: utf-8 -*-

import os
import traceback
import subprocess

from core.utils.filesystem import Filesystem
from core.utils.daisy_pipeline import DaisyPipelineJob


class Xslt():
    """Class used to run XSLTs"""

    # treat as class variables
    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../..", "xslt"))
    saxon_jar = None
    _i18n = {
        "The XSLT": "XSLTen",
        "took too long time and was therefore stopped.": "tok for lang tid og ble derfor stoppet.",
    }

    @staticmethod
    def init_environment():
        DaisyPipelineJob.init_environment()
        Xslt.saxon_jar = os.path.join(DaisyPipelineJob.dp2_home, "system/framework/org.daisy.libs.saxon-he-9.5.1.5.jar")

    def __init__(self, pipeline=None, stylesheet=None, source=None, target=None, parameters={}, template=None, stdout_level="INFO", stderr_level="INFO", report=None, cwd=None):
        assert pipeline or cwd and report
        assert stylesheet
        assert source or template
        assert target

        if not report:
            report = pipeline.utils.report

        if not cwd:
            cwd = report.pipeline.dir_in

        self.success = False

        Xslt.init_environment()

        try:
            command = ["java", "-jar", Xslt.saxon_jar]
            if source:
                command.append("-s:" + source)
            else:
                command.append("-it:" + template)
            command.append("-xsl:" + stylesheet)
            command.append("-o:" + target)
            for param in parameters:
                command.append(param + "=" + parameters[param])

            report.debug("Running XSLT")
            Filesystem.run_static(command, cwd, report, stdout_level=stdout_level, stderr_level=stderr_level)
            self.success = True

        except subprocess.TimeoutExpired:
            report.error(Xslt._i18n["The XSLT"] + " " + stylesheet + " " + Xslt._i18n["took too long time and was therefore stopped."])

        except Exception:
            report.debug(traceback.format_exc())
            report.error("An error occured while running the XSLT (" + str(stylesheet) + ")")

    # in case you want to override something
    @staticmethod
    def translate(english_text, translated_text):
        Filesystem._i18n[english_text] = translated_text
