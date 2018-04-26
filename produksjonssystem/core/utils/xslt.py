# -*- coding: utf-8 -*-

import os
import re
import time
import tempfile
import subprocess

from core.utils.daisy_pipeline import DaisyPipelineJob

class Xslt():
    """Class used to run XSLTs"""
    
    # treat as class variables
    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../..", "xslt"))
    saxon_jar = None
    _i18n = {
        "The XSLT": "XSLTen",
        "took too long time and was therefore stopped.": "tok for lang tid og ble derfor stoppet.",
    }
    
    # treat as instance variables
    pipeline = None
    
    @staticmethod
    def init_environment():
        DaisyPipelineJob.init_environment()
        Xslt.saxon_jar = os.path.join(DaisyPipelineJob.dp2_home, "system/framework/org.daisy.libs.saxon-he-9.5.1.5.jar")
    
    def __init__(self, pipeline=None, stylesheet=None, source=None, target=None, parameters={}, template=None, stdout_level="INFO", stderr_level="INFO"):
        assert pipeline
        assert stylesheet
        assert source or template
        assert target
        
        self.pipeline = pipeline
        self.success = False
        
        Xslt.init_environment()
        
        try:
            command = ["java", "-jar", Xslt.saxon_jar]
            if source:
                command.append("-s:" + source)
            else:
                command.append("-it:" + template)
            command.append("-xsl:" + stylesheet)
            command.append("-o:" + target)
            for param in parameters:
                command.append(param + "=" + parameters[param])
            
            self.pipeline.utils.report.debug("Running XSLT")
            process = self.pipeline.utils.filesystem.run(command, stdout_level=stdout_level, stderr_level=stderr_level)
            self.success = True
            
        except subprocess.TimeoutExpired as e:
            self.pipeline.utils.report.error(Xslt._i18n["The XSLT"] + " " + stylesheet + " " + Xslt._i18n["took too long time and was therefore stopped."])
            
        except Exception:
            self.pipeline.utils.report.error("An error occured while running the XSLT (" + str(stylesheet) + ")")
    
    # in case you want to override something
    @staticmethod
    def translate(english_text, translated_text):
        Filesystem._i18n[english_text] = translated_text
    