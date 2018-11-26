# -*- coding: utf-8 -*-

import os
import subprocess
import traceback

from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.filesystem import Filesystem


class Xslt():
    """Class used to run XSLTs"""

    # treat as class variables
    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../..", "xslt"))
    saxon_jar = None
    jing_jar = None

    @staticmethod
    def init_environment():
        DaisyPipelineJob.init_environment()
        for dirPath, subdirList, fileList in os.walk(DaisyPipelineJob.dp2_home):
            for file in fileList:
                if file.endswith(".jar") and "saxon-he" in file:
                    Xslt.saxon_jar = os.path.join(dirPath, file)
                elif file.endswith(".jar") and "jing" in file:
                    Xslt.jing_jar = os.path.join(dirPath, file)

    def __init__(self,
                 pipeline=None,
                 stylesheet=None,
                 source=None,
                 target=None,
                 parameters={},
                 template=None,
                 stdout_level="INFO",
                 stderr_level="INFO",
                 report=None,
                 cwd=None):
        assert pipeline or report
        assert stylesheet
        assert source or template

        if not report:
            report = pipeline.utils.report

        if not cwd:
            cwd = self.xslt_dir

        self.success = False

        Xslt.init_environment()

        try:
            command = ["java", "-jar", Xslt.saxon_jar]
            if source:
                command.append("-s:" + source)
            else:
                command.append("-it:" + template)
            command.append("-xsl:" + stylesheet)
            if target:
                command.append("-o:" + target)
            for param in parameters:
                command.append(param + "=" + parameters[param])

            report.debug("Running XSLT")
            process = Filesystem.run_static(command, cwd, report, stdout_level=stdout_level, stderr_level=stderr_level)
            self.success = process.returncode == 0

        except subprocess.TimeoutExpired:
            report.error("XSLTen {} tok for lang tid og ble derfor stoppet.".format(stylesheet))

        except Exception:
            report.debug(traceback.format_exc(), preformatted=True)
            report.error("An error occured while running the XSLT (" + str(stylesheet) + ")")
