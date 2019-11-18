# -*- coding: utf-8 -*-

import os
import subprocess
import tempfile
import traceback

from core.utils.filesystem import Filesystem


class Epubcheck():
    """Class used to run Epubcheck"""

    # treat as class variables
    epubcheck_home = None
    epubcheck_jar = None

    @staticmethod
    def init_environment():
        from core.pipeline import Pipeline
        if "EPUBCHECK_HOME" in Pipeline.environment:
            Epubcheck.epubcheck_home = Pipeline.environment["EPUBCHECK_HOME"]
        else:
            Epubcheck.epubcheck_home = os.getenv("EPUBCHECK_HOME", "/opt/epubcheck")
        Epubcheck.epubcheck_jar = Epubcheck.epubcheck_home + "/epubcheck.jar"

    @staticmethod
    def isavailable():
        Epubcheck.init_environment()
        return isinstance(Epubcheck.epubcheck_jar, str) and os.path.isfile(Epubcheck.epubcheck_jar)

    def __init__(self,
                 pipeline=None,
                 source=None,
                 stdout_level="INFO",
                 stderr_level="INFO",
                 report=None,
                 cwd=None):
        assert pipeline or report
        assert source

        if not report:
            report = pipeline.utils.report

        if not cwd:
            cwd = tempfile.gettempdir()

        self.success = False

        Epubcheck.init_environment()

        try:
            command = ["java", "-jar", Epubcheck.epubcheck_jar]
            command.append(source)
            if source.lower().endswith(".opf"):
                command += ["--mode", "opf"]

            report.debug("Running Epubcheck")
            process = Filesystem.run_static(command, cwd, report, stdout_level=stdout_level, stderr_level=stderr_level)
            self.success = process.returncode == 0

        except subprocess.TimeoutExpired:
            report.error("Epubcheck for {} took too long and were therefore stopped.".format(os.path.basename(source)))

        except Exception:
            report.debug(traceback.format_exc(), preformatted=True)
            report.error("An error occured while running Epubcheck (for " + str(source) + ")")
