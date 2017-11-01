# -*- coding: utf-8 -*-

import tempfile
import re

class Report():
    """Logging and reporting"""
    
    stdout_verbosity = 'INFO'
    book = None
    report_dir = None
    _report_dir_object = None # store this in the instance so it's not garbage collected before the instance
    _messages = []
    
    def __init__(self, book, report_dir=None):
        self.book = book
        if not report_dir:
            self._report_dir_object = tempfile.TemporaryDirectory()
            self.report_dir = self._report_dir_object.name
        else:
            self.report_dir = report_dir
    
    def _add_message(self, severity, message, add_empty_line):
        lines = None
        if isinstance(message, list):
            lines = message
        else:
            lines = [ message ]
        
        lines = [l for line in lines for l in line.split("\n")]
        if add_empty_line:
            lines.append("")
        
        for line in lines:
            self._messages.append({ 'severity': severity, 'text': line })
            
            if (self.stdout_verbosity == 'DEBUG' or
                self.stdout_verbosity == 'INFO' and severity in [ 'INFO', 'WARN', 'ERROR' ] or
                self.stdout_verbosity == 'WARN' and severity in [ 'WARN', 'ERROR' ] or
                severity == 'ERROR'):
                print("["+severity+"] "+line)
    
    def debug(self, message, add_empty_line=True):
        self._add_message('DEBUG', message, add_empty_line)
    
    def info(self, message, add_empty_line=True):
        self._add_message('INFO', message, add_empty_line)
    
    def warn(self, message, add_empty_line=True):
        self._add_message('WARN', message, add_empty_line)
    
    def error(self, message, add_empty_line=True):
        self._add_message('ERROR', message, add_empty_line)
    
    def email(self, message):
        # TODO
        # markdown to html?
        # def html-to-text(): combine on one line | remove head | remove inline tags | replace all other tags with a newline
        print("E-mail: "+message)
    
    def slack(self, message):
        print("TODO: send message to Slack")
    
    def fromHtml(html):
        # TODO
        print("Convert from HTML to Markdown: "+html)
