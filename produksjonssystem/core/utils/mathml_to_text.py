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
                 source=None,
                 target=None,
                 report=None):
        assert pipeline or report
        assert source
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
            map = {
                'epub': 'http://www.idpf.org/2007/ops',
                'm': "http://www.w3.org/1998/Math/MathML",
                None: 'http://www.w3.org/1999/xhtml',
                "xml": "http://www.w3.org/XML/1998/namespace"
            }

            mathML_elements = root.findall(".//m:math", map)

            if len(mathML_elements) == 0:
                self.report.info("No MathML elements found in document")
            else:
                self.report.info("Replacing MathML elements in document with spoken math")

                for element in mathML_elements:
                    if not pipeline.shouldRun:
                        # converting all MathML elements can take a long time,
                        # so if we're shutting down the system while converting
                        # MathML, we'll just make this conversion fail.
                        self.success = False
                        break

                    # converting all MathML elements can take a long time,
                    # so run watchdog_bark here.
                    pipeline.watchdog_bark()

                    parent = element.getparent()

                    if "{http://www.w3.org/XML/1998/namespace}lang" not in element.attrib:
                        element.set("{http://www.w3.org/XML/1998/namespace}lang", find_xml_lang(element))

                    html_representation = self.mathML_transformation(etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                    self.report.debug("Inserting transformation: " + html_representation)

                    stem_element = etree.fromstring(html_representation)

                    if element.tail is not None:
                        stem_element.tail = element.tail
                    parent.insert(parent.index(element) + 1, stem_element)
                    parent.remove(element)

                self.report.info("Transformasjon ferdig, lagrer fil.")
                tree.write(target, method='XML', xml_declaration=True, encoding='UTF-8', pretty_print=False)

            self.success = True

        except Exception:
            self.report.warning(traceback.format_exc(), preformatted=True)
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
            self.report.warning("Error returning MathML transformation. Check STEM result")
        #    self.report.warning(traceback.format_exc(), preformatted=True)
            element = etree.fromstring(mathml)
            display_attrib = element.attrib["display"]
            lang_attrib = element.attrib["{http://www.w3.org/XML/1998/namespace}lang"]
            if display_attrib == "inline":
                if lang_attrib == "nb" or lang_attrib == "nob" or lang_attrib == "nn":
                    return "<span>Matematisk formel</span>"
                else:
                    return "<span>Mathematical formula</span>"
            else:
                if lang_attrib == "nb" or lang_attrib == "nob" or lang_attrib == "nn":
                    return "<p>Matematisk formel</p>"
                else:
                    return "<p>Mathematical formula</p>"


class Mathml_validator():
    """Class used to check MathML in xhtml documents"""
    """NOTE: WHEN THE VALIDATOR IS UPDATED - ALSO UPDATE /docs/mathml_to_text/nlb_mathml_validator.py"""

    def __init__(self,
                 pipeline=None,
                 source=None,
                 report_errors_max=10,
                 report=None):
        assert pipeline or report
        assert source

        if not report:
            self.report = pipeline.utils.report
        else:
            self.report = report

        self.success = True
        self.error_count = 0

        try:
            tree = etree.parse(source)

            root = tree.getroot()
            self.map = {'epub': 'http://www.idpf.org/2007/ops', 'm': "http://www.w3.org/1998/Math/MathML", None: 'http://www.w3.org/1999/xhtml', "xml": "http://www.w3.org/XML/1998/namespace"}

            asciimath_elements = root.findall(".//*[@class='asciimath']", self.map)
            if len(asciimath_elements) >= 1:
                self.report.warning("This document may contain asciimath. This should be investigated")

            mathML_elements = root.findall(".//m:math", self.map)
            if len(mathML_elements) == 0:
                mathML_elements = root.findall(".//math", self.map)

            if len(mathML_elements) == 0:
                self.report.info("No MathML elements found in document")
                return

            for element in mathML_elements:

                element_success = True
                # prevent sending too many errors to the main report
                if self.error_count < report_errors_max:
                    debug = self.report.debug
                    info = self.report.info
                    warning = self.report.warning
                    error = self.report.error
                else:
                    debug = self.report.debug
                    info = self.report.debug
                    warning = self.report.debug
                    error = self.report.debug

                parent = element.getparent()

                if etree.QName(parent).localname == "p":
                    if element.getprevious() is None and element.getnext() is None and parent.text is None:
                        if element.tail is None or element.tail.isspace():
                            element_success = False
                            error("A MathML element cannot be the only element inside parent <p>")
                            debug("Parent element: \n" + etree.tostring(parent, encoding='unicode', method='xml', with_tail=False))
                            info("MathML element: \n" + etree.tostring(element, encoding='unicode', method='xml', with_tail=False))

                if "altimg" not in element.attrib:
                    element_success = False
                    info(etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                    error("MathML element does not contain the required attribute altimg")

                if "alttext" not in element.attrib:
                    element_success = False
                    info(etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                    error("MathML element does not contain the required attribute alttext")

                alttext = element.attrib["alttext"]
                if len(alttext) <= 1 and len(etree.tostring(element, encoding='unicode', method='xml', with_tail=False)) >= 500 or len(alttext) == 0:
                    element_success = False
                    info(etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                    error("MathML element does not contain a correct alttext")

                if "display" not in element.attrib:
                    element_success = False
                    info(etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                    error("MathML element does not contain the required attribute display")

                else:
                    display_attrib = element.attrib["display"]
                    suggested_display_attribute = self.inline_or_block(element, parent)
                    if display_attrib != suggested_display_attribute:
                        element_success = False
                        debug("Parent element: \n" + etree.tostring(parent, encoding='unicode', method='xml', with_tail=False))
                        info("MathML element: \n" + etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                        error(f"MathML element has the wrong display attribute. Display = {display_attrib}, should be {suggested_display_attribute}")

                if not element_success:
                    self.error_count += 1
                    self.success = False

            if self.success is True:
                self.report.info("No errors found in MathML validation")
            else:
                self.report.error("MathML validation failed. Check log for details.")

        except Exception:
            self.success = False
            self.report.warning(traceback.format_exc(), preformatted=True)
            self.report.error("An error occured during the MathML validation")

    def inline_or_block(self, element, parent, check_siblings=True):
        flow_tags = ["figcaption", "dd", "li", "caption", "th", "td", "p"]
        inline_elements = ["a", "abbr", "bdo", "br", "code", "dfn", "em", "img", "kbd", "q", "samp", "span", "strong", "sub", "sup"]

        parent_text = parent.text
        sibling_text_not_empty = False
        sibling_is_inline = False
        parent_is_inline = False

        if check_siblings:

            for elem in list(parent):
                if elem.tail is not None and elem.tail.isspace() is not True:
                    sibling_is_inline = True

            if parent_text is not None and parent_text.isspace() is not True:
                sibling_text_not_empty = True

            elif element.tail is not None and element.tail.isspace() is not True:
                sibling_text_not_empty = True

            for inline_element in inline_elements:
                inline_elements_in_element = parent.findall(inline_element, self.map)
                if len(inline_elements_in_element) > 0:
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


def find_xml_lang(element):
    lang = (element.get("{http://www.w3.org/XML/1998/namespace}lang"))
    if lang is not None:
        return lang

    parent = element.getparent()
    if parent is not None:
        return find_xml_lang(parent)
    return False
