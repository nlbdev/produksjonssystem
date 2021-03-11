# -*- coding: utf-8 -*-

import os
import subprocess
import tempfile
import traceback

from core.utils.epub import Epub
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
                 cwd=None):
        assert pipeline
        assert source

        if not cwd:
            cwd = tempfile.gettempdir()

        self.success = False

        Epubcheck.init_environment()

        # epubcheck works better when the input is zipped
        if source.lower().endswith(".opf"):
            pipeline.utils.report.debug("EPUB is not zipped, zipping…")
            root_path = os.path.dirname(source)
            while True:
                assert root_path != os.path.dirname(root_path), "No mimetype file or META-INF directory found in the EPUB, unable to determine root directory"
                is_root = False
                for filename in os.listdir(root_path):
                    if filename == "mimetype" or filename == "META-INF":
                        is_root = True
                        break
                if is_root:
                    break
                else:
                    root_path = os.path.dirname(root_path)

            epub = Epub(pipeline.utils.report, root_path)
            source = epub.asFile()

        try:
            command = ["java", "-jar", Epubcheck.epubcheck_jar]
            command.append(source)

            pipeline.utils.report.debug("Running Epubcheck")
            process = Filesystem.run_static(command, cwd, pipeline.utils.report, stdout_level=stdout_level, stderr_level=stderr_level)
            self.success = process.returncode == 0

        except subprocess.TimeoutExpired:
            pipeline.utils.report.error("Epubcheck for {} took too long and were therefore stopped.".format(os.path.basename(source)))

        except Exception:
            pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
            pipeline.utils.report.error("An error occured while running Epubcheck (for " + str(source) + ")")
