# -*- coding: utf-8 -*-

import os
import subprocess
import tempfile
import traceback

from core.utils.filesystem import Filesystem


class KindleGen():
    """Class used to run KindleGen"""

    # treat as class variables
    kindlegen_home = None
    kindlegen_cmd = None

    @staticmethod
    def init_environment():
        from core.pipeline import Pipeline
        if "KINDLEGEN_HOME" in Pipeline.environment:
            KindleGen.kindlegen_home = Pipeline.environment["KINDLEGEN_HOME"]
        else:
            KindleGen.kindlegen_home = os.getenv("KINDLEGEN_HOME", "/opt/kindlegen")
        KindleGen.kindlegen_cmd = KindleGen.kindlegen_home + "/kindlegen"

    @staticmethod
    def isavailable():
        KindleGen.init_environment()
        return isinstance(KindleGen.kindlegen_cmd, str) and os.path.isfile(KindleGen.kindlegen_cmd)

    def __init__(self,
                 pipeline=None,
                 source=None,  # [filename.opf/.htm/.html/.epub/.zip or directory]
                 target=None,  # NOTE: file will be created in the same directory as that of input file
                 stdout_level="INFO",
                 stderr_level="INFO",
                 cwd=None,
                 report=None):
        assert pipeline or report, "a pipeline or report object must be specified"
        assert source, "source must be specified"
        assert target, "target must be specified"

        assert os.path.isdir(os.path.dirname(target)), "{} does not exist or is not a directory".format(os.path.dirname(target))
        assert not os.path.exists(target), "{} already exists".format(os.path.dirname(target))

        kindlegen_target = os.path.join(os.path.dirname(source), os.path.basename(target))
        assert not os.path.exists(kindlegen_target), "{} already exists".format(kindlegen_target)

        if not report:
            report = pipeline.utils.report

        if not cwd:
            cwd = tempfile.gettempdir()

        self.success = False

        KindleGen.init_environment()

        try:
            command = [KindleGen.kindlegen_cmd, source, "-verbose", "-o", os.path.basename(target)]

            report.debug("Running KindleGen")
            process = Filesystem.run_static(command, cwd, report, stdout_level=stdout_level, stderr_level=stderr_level)
            self.success = process.returncode == 0 and os.path.isfile(kindlegen_target)

            if os.path.exists(kindlegen_target):
                os.rename(kindlegen_target, target)

        except subprocess.TimeoutExpired:
            report.error("KindleGen for {} took too long and were therefore stopped.".format(os.path.basename(source)))

        except Exception:
            report.debug(traceback.format_exc(), preformatted=True)
            report.error("An error occured while running KindleGen (for " + str(source) + ")")
