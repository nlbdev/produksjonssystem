# -*- coding: utf-8 -*-

import os
import shutil
import tempfile
import traceback

from lxml import etree as ElementTree

from core.utils.xslt import Xslt


class CompareWithReference(object):
    """Class used to validate XML documents using CompareWithReference"""

    uid = "core-utils-compare-with-reference"

    def __init__(self, pipeline=None, reference=None, source=None, report=None, attach_report=True):
        assert pipeline or report, "either a pipeline or a report must be specified"
        assert reference and "/" in reference and os.path.isfile(reference), "reference must point to a reference file"
        assert (
            isinstance(source, str) and "/" in source and os.path.isfile(source) or
            isinstance(source, list) and False not in ["/" in s and os.path.isfile(s) for s in source]
            ), "source must refer to one or more absolute file paths"

        if not report:
            report = pipeline.utils.report

        if isinstance(source, str):
            source = [source]

        self.success = False

        temp_referanseoversikt_obj = tempfile.NamedTemporaryFile()
        temp_referanseoversikt = temp_referanseoversikt_obj.name

        report.debug("Lager referanseoversikt")
        xslt = Xslt(report=report,
                    stylesheet=os.path.join(Xslt.xslt_dir, CompareWithReference.uid, "generer-markupoversikt.xsl"),
                    source=reference,
                    target=temp_referanseoversikt,
                    stdout_level="INFO",
                    stderr_level="INFO")
        if not xslt.success:
            return

        try:
            for source_file in source:
                this_success = False

                temp_oversikt_obj = tempfile.NamedTemporaryFile()
                temp_oversikt = temp_oversikt_obj.name

                temp_rapport_obj = tempfile.NamedTemporaryFile()
                temp_rapport = temp_rapport_obj.name

                report.debug("Lager oversikt")
                xslt = Xslt(report=report,
                            stylesheet=os.path.join(Xslt.xslt_dir, CompareWithReference.uid, "generer-markupoversikt.xsl"),
                            source=source_file,
                            target=temp_oversikt,
                            stdout_level="INFO",
                            stderr_level="INFO")
                if not xslt.success:
                    return

                report.debug("Sammenligner oversikt med referanseoversikt")
                xslt = Xslt(report=report,
                            stylesheet=os.path.join(Xslt.xslt_dir, CompareWithReference.uid, "sammenlign-markupoversikter.xsl"),
                            template="start",
                            stdout_level="INFO",
                            stderr_level="INFO",
                            parameters={
                                "filA": "file://" + temp_oversikt,
                                "filB": "file://" + temp_referanseoversikt,
                                "rapport": "file://" + temp_rapport
                            })
                if not xslt.success:
                    return

                # Count number of errors
                ns = {"html": "http://www.w3.org/1999/xhtml", "re": "http://exslt.org/regular-expressions"}
                shutil.copy(temp_rapport, "/tmp/rapport.xhtml")
                report_document = ElementTree.parse(temp_rapport).getroot()
                errors = report_document.xpath("//*[re:match(@class,'(^|\s)error(\s|$)')]", namespaces=ns)
                if len(errors) == 0:
                    this_success = True
                    self.success = self.success and this_success

                # Create HTML report
                if temp_rapport and "/" in temp_rapport and attach_report:
                    compare_with_reference_report_dir = os.path.join(report.reportDir(), "compare-with-reference")
                    os.makedirs(compare_with_reference_report_dir, exist_ok=True)
                    name = ".".join(os.path.basename(reference).split(".")[:-1])
                    available_path = os.path.join(compare_with_reference_report_dir, "{}.html".format(name))
                    if os.path.exists(available_path):
                        for i in range(2, 100000):
                            # assumes we won't have move than 1000 reports
                            available_path = os.path.join(compare_with_reference_report_dir, "{}-{}.html".format(name, i))
                            if not os.path.exists(available_path):
                                break
                    if os.path.exists(available_path):
                        report.warn("Klarte ikke å finne et tilgjengelig filnavn for rapporten")
                    else:
                        report.debug("Lagrer rapport som {}".format(available_path))
                        with open(temp_rapport, 'r') as result_report:
                            report.attachment(result_report.readlines(),
                                              available_path,
                                              "SUCCESS" if this_success else "ERROR")

        except Exception:
            report.debug(traceback.format_exc(), preformatted=True)
            report.error("An error occured while running the CompareWithReference (" + str(reference) + ")")
