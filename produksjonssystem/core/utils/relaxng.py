# -*- coding: utf-8 -*-

import os

from core.utils.xslt import Xslt


class Relaxng():
    """Class used to validate XML documents using RELAXNG"""

    uid = "core-utils-relaxng"
    if Xslt.jing_jar is None:
        Xslt.init_environment()

    relaxng_dir = os.path.join(Xslt.xslt_dir, uid)

    def __init__(self, pipeline=None, relaxng=None, source=None, report=None, cwd=None, attach_report=True):
        assert pipeline or report and cwd
        assert relaxng and "/" in relaxng and os.path.isfile(relaxng)
        assert source and "/" in source and os.path.isfile(source)

        if not report:
            report = pipeline.utils.report

        if not cwd:
            assert report.pipeline.dir_in is not None, (
                "RelaxNG: for pipelines with no input directory, "
                + "the current working directory needs to be explicitly set."
            )
            cwd = report.pipeline.dir_in

        self.success = False
        if not(Xslt.jing_jar is None):
            process = pipeline.utils.filesystem.run(["java", "-jar", Xslt.jing_jar, "-t", relaxng, source])

            if process.returncode == 0:
                self.success = True

        process_string = (process.stdout.decode("utf-8").strip())
        lines = process_string.splitlines()
        process_html = """
        """

        for line in lines:
            newline = """
               <tr>
                    <td class="info">""" + line + """</td>
               </tr>
               """
            process_html += newline + "\n"

        # HTML String to attach
        html = """<!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
           <head>
              <meta charset="utf-8">
              <title>Rapport</title><style>
                  html{font-family:Arial, Helvetica, sans-serif; overflow-y:scroll; min-width:1000px;}
                  table{text-align:left;min-width:50%;}
                </style></head>
           <body>
              <h1>Valideringsrapport</h1>
              <div>
                <table class="results">
                """ + process_html + """
                </table>
              </div>
           </body>
        </html>
        """
        if attach_report:
            relaxng_report_dir = os.path.join(report.reportDir(), "relaxng")
            os.makedirs(relaxng_report_dir, exist_ok=True)
            name = ".".join(os.path.basename(relaxng).split(".")[:-1])
            available_path = os.path.join(relaxng_report_dir, "{}.html".format(name))
            if os.path.exists(available_path):
                for i in range(2, 100000):
                    available_path = os.path.join(relaxng_report_dir, "{}-{}.html".format(name, i))  # assumes we won't have move than 1000 reports
                    if not os.path.exists(available_path):
                        break
            if os.path.exists(available_path):
                report.warn("Klarte ikke å finne et tilgjengelig filnavn for rapporten")
            else:
                report.debug("Lagrer rapport som {}".format(available_path))
                report.attachment(html, available_path, "SUCCESS" if self.success else "ERROR")
