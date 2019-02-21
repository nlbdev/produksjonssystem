# -*- coding: utf-8 -*-

import os
import tempfile
import traceback
from threading import RLock

from lxml import etree as ElementTree

from core.utils.xslt import Xslt


class Schematron():
    """Class used to validate XML documents using Schematron"""

    uid = "core-utils-schematron"
    schematron_dir = os.path.join(Xslt.xslt_dir, uid, "schematron/trunk/schematron/code")

    # static
    cache = {}
    _cache_lock = RLock()

    def __init__(self, pipeline=None, schematron=None, source=None, report=None, cwd=None, attach_report=True):
        assert pipeline or report and (report.pipeline or cwd)
        assert schematron and "/" in schematron and os.path.isfile(schematron)
        assert source and "/" in source and os.path.isfile(source)

        if not report:
            report = pipeline.utils.report

        if not cwd:
            assert report.pipeline.dir_in is not None, (
                "Schematron: for pipelines with no input directory, " +
                "the current working directory needs to be explicitly set."
            )
            cwd = report.pipeline.dir_in

        self.success = False

        try:
            compiled_schematron = Schematron.compile_schematron(schematron, cwd, report)
            if not compiled_schematron:
                return

            temp_xml_report_obj = tempfile.NamedTemporaryFile()
            temp_xml_report = temp_xml_report_obj.name

            report.debug("Validating against compiled Schematron ({} + {}): {}".format(
                "iso_svrl_for_xslt2.xsl",
                os.path.basename(source),
                os.path.basename(temp_xml_report)))
            xslt = Xslt(report=report,
                        cwd=cwd,
                        stylesheet=compiled_schematron,
                        source=source,
                        target=temp_xml_report,
                        stdout_level="DEBUG",
                        stderr_level="DEBUG")
            if not xslt.success:
                return

            # Count number of errors
            svrl_schematron_output = ElementTree.parse(temp_xml_report).getroot()
            errors = svrl_schematron_output.findall('{http://purl.oclc.org/dsdl/svrl}failed-assert')
            errors.extend(svrl_schematron_output.findall('{http://purl.oclc.org/dsdl/svrl}successful-report'))
            if len(errors) == 0:
                self.success = True
            else:
                max_errors = 20
                e = 0
                pattern_title = None
                for element in svrl_schematron_output.getchildren():
                    if element.tag == '{http://purl.oclc.org/dsdl/svrl}active-pattern':
                        pattern_title = element.attrib["name"] if "name" in element.attrib else None
                        continue

                    if element.tag == '{http://purl.oclc.org/dsdl/svrl}failed-assert' or element.tag == '{http://purl.oclc.org/dsdl/svrl}successful-report':

                        location = element.attrib["location"] if "location" in element.attrib else None
                        test = element.attrib["test"] if "test" in element.attrib else None
                        text = element.find('{http://purl.oclc.org/dsdl/svrl}text')
                        text = text.text if text is not None and text.text else "(missing description)"

                        if e < max_errors:
                            report.error((pattern_title + ": " if pattern_title else "") + text)
                        report.debug((pattern_title + ": " if pattern_title else "") + text + (" ({})".format(location) if location else "") +
                                     (" ({})".format(test) if test else ""))

                        e += 1

            # Create HTML report
            if temp_xml_report and "/" in temp_xml_report:
                html_report_obj = tempfile.NamedTemporaryFile()
                html_report = html_report_obj.name
                report.debug("Creating HTML report for Schematron validation ({} + {}): {}".format(
                    "iso_svrl_for_xslt2.xsl", os.path.basename(temp_xml_report), os.path.basename(html_report)))
                xslt = Xslt(report=report,
                            cwd=cwd,
                            stylesheet=os.path.join(Xslt.xslt_dir, Schematron.uid, "svrl-to-html.xsl"),
                            source=temp_xml_report,
                            target=html_report)
                if not xslt.success:
                    return

                if attach_report:
                    schematron_report_dir = os.path.join(report.reportDir(), "schematron")
                    os.makedirs(schematron_report_dir, exist_ok=True)
                    name = ".".join(os.path.basename(schematron).split(".")[:-1])
                    available_path = os.path.join(schematron_report_dir, "{}.html".format(name))
                    if os.path.exists(available_path):
                        for i in range(2, 100000):
                            available_path = os.path.join(schematron_report_dir, "{}-{}.html".format(name, i))  # assumes we won't have move than 1000 reports
                            if not os.path.exists(available_path):
                                break
                    if os.path.exists(available_path):
                        report.warn("Klarte ikke å finne et tilgjengelig filnavn for rapporten")
                    else:
                        report.debug("Lagrer rapport som {}".format(available_path))
                        with open(html_report, 'r') as result_report:
                            report.attachment(result_report.readlines(),
                                              available_path,
                                              "SUCCESS" if self.success else "ERROR")

        except Exception:
            report.debug(traceback.format_exc(), preformatted=True)
            report.error("An error occured while running the Schematron (" + str(schematron) + ")")

    def compile_schematron(schematron, cwd, report):
        with Schematron._cache_lock:
            if schematron in Schematron.cache and Schematron.cache[schematron] and os.path.isfile(Schematron.cache[schematron].name):
                return Schematron.cache[schematron].name

        try:
            temp_xml_1_obj = tempfile.NamedTemporaryFile()
            temp_xml_1 = temp_xml_1_obj.name

            temp_xml_2_obj = tempfile.NamedTemporaryFile()
            temp_xml_2 = temp_xml_2_obj.name

            temp_xml_3_obj = tempfile.NamedTemporaryFile()
            temp_xml_3 = temp_xml_3_obj.name

            report.debug("Compiling schematron ({} + {}): {}".format("iso_dsdl_include.xsl", os.path.basename(schematron), os.path.basename(temp_xml_1)))
            xslt = Xslt(report=report,
                        cwd=cwd,
                        stylesheet=os.path.join(Schematron.schematron_dir, "iso_dsdl_include.xsl"),
                        source=schematron,
                        target=temp_xml_1,
                        stdout_level="DEBUG",
                        stderr_level="DEBUG")
            if not xslt.success:
                return None

            report.debug("Compiling schematron ({} + {}): {}".format("iso_abstract_expand.xsl", os.path.basename(schematron), os.path.basename(temp_xml_2)))
            xslt = Xslt(report=report,
                        cwd=cwd,
                        stylesheet=os.path.join(Schematron.schematron_dir, "iso_abstract_expand.xsl"),
                        source=temp_xml_1,
                        target=temp_xml_2,
                        stdout_level="DEBUG",
                        stderr_level="DEBUG")
            if not xslt.success:
                return None

            report.debug("Compiling schematron ({} + {}): {}".format("iso_svrl_for_xslt2.xsl", os.path.basename(schematron), os.path.basename(temp_xml_3)))
            xslt = Xslt(report=report,
                        cwd=cwd,
                        stylesheet=os.path.join(Schematron.schematron_dir, "iso_svrl_for_xslt2.xsl"),
                        source=temp_xml_2,
                        target=temp_xml_3,
                        stdout_level="DEBUG",
                        stderr_level="DEBUG")
            if not xslt.success:
                return None

            with Schematron._cache_lock:
                Schematron.cache[schematron] = temp_xml_3_obj
                return Schematron.cache[schematron].name

        except Exception:
            report.debug(traceback.format_exc(), preformatted=True)
            report.error("An error occured while compiling the Schematron (" + str(schematron) + ")")

        return None
