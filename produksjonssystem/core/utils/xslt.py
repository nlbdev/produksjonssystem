# -*- coding: utf-8 -*-

import os
import re
import time
import logging
import tempfile
import subprocess

from core.utils.daisy_pipeline import DaisyPipelineJob

class Xslt():
    """Class used to run XSLTs"""
    
    # treat as class variables
    saxon_jar = os.path.join(DaisyPipelineJob.dp2_home, "system/framework/org.daisy.libs.saxon-he-9.5.1.5.jar")
    _i18n = {
        "The XSLT": "XSLTen",
        "took too long time and was therefore stopped.": "tok for lang tid og ble derfor stoppet.",
    }
    
    # treat as instance variables
    pipeline = None
    
    def __init__(self, pipeline=None, stylesheet=None, source=None, target=None, parameters={}):
        assert pipeline
        assert stylesheet
        assert source
        assert target
        
        self.pipeline = pipeline
        
        try:
            command = ["java", "-jar", self.saxon_jar, "-s:" + source, "-xsl:" + stylesheet, "-o:" + target]
            for param in parameters:
                command.extend([param + "=" + parameters[param]])
            
            self.pipeline.utils.report.debug("Running XSLT")
            process = self.pipeline.utils.filesystem.run(command)
            
        except subprocess.TimeoutExpired as e:
            self.pipeline.utils.report.error(Xslt._i18n["The XSLT"] + " " + stylesheet + " " + Xslt._i18n["took too long time and was therefore stopped."])
            self.status = None
            
        except Exception:
            logging.exception("An error occured while running the XSLT (" + str(stylesheet) + ")")
            self.pipeline.utils.report.error("An error occured while running the XSLT (" + str(stylesheet) + ")")
    
    # in case you want to override something
    @staticmethod
    def translate(english_text, translated_text):
        Filesystem._i18n[english_text] = translated_text
    