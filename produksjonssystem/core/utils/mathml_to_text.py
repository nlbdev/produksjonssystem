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

        try:
            parser = etree.XMLParser(encoding='utf-8')
            tree = etree.parse(source, parser=parser)

            root = tree.getroot()
            map = {'epub': 'http://www.idpf.org/2007/ops', 'm': "http://www.w3.org/1998/Math/MathML"}

            mathML_elements = root.findall(".//m:math", map)

            for element in mathML_elements:
                parent = element.getparent()
                html_representation = self.mathML_transformation(etree.tostring(element, encoding='unicode', method='xml', with_tail=False))
                self.report.info("Inserting transformation: " + html_representation)

                stem_element = etree.fromstring(html_representation, parser=parser)

                if element.tail is not None:
                    stem_element.tail = element.tail
                parent.insert(parent.index(element) + 1, stem_element)
                parent.remove(element)

            self.report.info("Transformasjon ferdig, largrer fil.")
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
