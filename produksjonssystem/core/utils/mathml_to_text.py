# -*- coding: utf-8 -*-

import os
import subprocess
import traceback
import requests
from lxml import etree

from core.config import Config
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.filesystem import Filesystem


class Mathml_to_text():
    """Class used to transform MathML in xhtml documents"""

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
        assert source or template
        assert target

        if not report:
            self.report = pipeline.utils.report
        else:
            self.report = report

        self.success = False
        self.properties = None

        try:
            tree = etree.parse(source)

            root = tree.getroot()
            map = {'epub': 'http://www.idpf.org/2007/ops', 'm': "http://www.w3.org/1998/Math/MathML"}

            mathML_elements = root.findall(".//m:math", map)
            if len(mathML_elements) is 0:
                self.report.info("No MathML elements found in document")

            for element in mathML_elements:
                parent = element.getparent()
                html_representation = self.mathML_transformation(etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                self.report.info("Inserting transformation: " + html_representation)

                stem_element = etree.fromstring(html_representation)

                if element.tail is not None:
                    stem_element.tail = element.tail
                parent.insert(parent.index(element) + 1, stem_element)
                parent.remove(element)

            self.report.info("Transformasjon ferdig, lagrer fil.")
            tree.write(target, method='XML', xml_declaration=True, encoding='UTF-8', pretty_print=False)

            self.success = True

        except Exception:
            self.report.warn(traceback.format_exc(), preformatted=True)
            self.report.error("An error occured during the MathML transformation")

    def mathML_transformation(self, mathml):
        try:
            url = Config.get("nlb_api_url") + "/stem/math"
            payload = mathml
            headers = {
                'Accept': "application/json",
                'Content-Type': 'text/html;charset=utf-8',
                }

            response = requests.request("POST", url, data=payload.encode('utf-8'), headers=headers)

            data = response.json()

            html = data["generated"]["html"]
            return html
        except Exception:
            self.report.warn("Error returning MathML transformation. Check STEM result")
            self.report.warn(traceback.format_exc(), preformatted=True)
            return "<span>Matematisk formel</span>"


class Mathml_validator():
    """Class used to check MathML in xhtml documents"""

    def __init__(self,
                 pipeline=None,
                 stylesheet=None,
                 source=None,
                 parameters={},
                 template=None,
                 stdout_level="INFO",
                 stderr_level="INFO",
                 report=None,
                 cwd=None):
        assert pipeline or report
        assert source or template

        if not report:
            self.report = pipeline.utils.report
        else:
            self.report = report

        self.success = True

        try:
            tree = etree.parse(source)

            root = tree.getroot()
            self.map = {'epub': 'http://www.idpf.org/2007/ops', 'm': "http://www.w3.org/1998/Math/MathML"}

            mathML_elements = root.findall(".//m:math", self.map)

            if len(mathML_elements) is 0:
                self.report.info("No MathML elements found in document")
                return

            for element in mathML_elements:
                parent = element.getparent()

                if etree.QName(parent).localname == "p":
                    if element.getprevious() is None and element.getnext() is None and parent.text is None:
                        if element.tail is None or element.tail.isspace:
                            self.success = False
                            self.report.error("A MathML element cannot be the only element inside parent <p>")
                            self.report.debug("Parent element: \n" + etree.tostring(parent, encoding='unicode', method='xml', with_tail=False))
                            self.report.info("MathML element: \n" + etree.tostring(element, encoding='unicode', method='xml', with_tail=False))

                if "altimg" not in element.attrib:
                    self.success = False
                    self.report.info(etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                    self.report.error("MathML element does not contain the required attribute altimg")

                if "display" not in element.attrib:
                    self.success = False
                    self.report.info(etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                    self.report.error("MathML element does not contain the required attribute display")

                else:
                    display_attrib = element.attrib["display"]
                    suggested_display_attribute = self.inline_or_block(element, parent)
                    if display_attrib != suggested_display_attribute and suggested_display_attribute != "flow":
                        self.success = False
                        self.report.debug("Parent element: \n" + etree.tostring(parent, encoding='unicode', method='xml', with_tail=False))
                        self.report.info("MathML element: \n" + etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                        self.report.error(f"MathML element has the wrong display attribute. Display = {display_attrib}, should be {suggested_display_attribute}")

            if self.success is True:
                self.report.info("No errors found in MathML validation")
            else:
                self.report.error("MathML validation failed. Check log for details.")

        except Exception:
            self.report.warn(traceback.format_exc(), preformatted=True)
            self.report.error("An error occured during the MathML validation")

    def inline_or_block(self, element, parent, check_siblings=True):
        flow_tags = ["figcaption", "dd", "li", "caption", "th", "td", "p"]
        inline_elements = ["a", "abbr", "bdo", "br", "code", "dfn", "em", "img", "kbd", "q", "samp", "span", "strong", "sub", "sup"]

        parent_text = parent.text
        sibling_text_not_empty = False
        sibling_is_inline = False
        parent_is_inline = False

        if check_siblings:
            if parent_text is not None and parent_text.isspace() is not True:
                sibling_text_not_empty = True

            elif element.tail is not None and element.tail.isspace() is not True:
                sibling_text_not_empty = True

            for inline_element in inline_elements:
                inline_elements_in_element = parent.findall(inline_element, self.map)
                if len(inline_elements_in_element) != 0:
                    sibling_is_inline = True

        if parent.getparent() is not None:
            parent_display = self.inline_or_block(parent, parent.getparent(), check_siblings=False)
            if parent_display == "inline":
                parent_is_inline = True

        if sibling_is_inline or sibling_text_not_empty or parent_is_inline:
            return "inline"

        if etree.QName(parent).localname in flow_tags:
            if element.getprevious() is not None or element.getnext() is not None:
                return "block"
            else:
                return "inline"

        return "block"