# -*- coding: utf-8 -*-

import tempfile

class Report():
    """Logging and reporting"""
    
    book = None
    report_dir = None
    report_dir_object = None # store this in the instance so it's not garbage collected before the instance
    
    def __init__(self, book, report_dir=None):
        self.book = book
        if not report_dir:
            self.report_dir_object = tempfile.TemporaryDirectory()
            self.report_dir = self.report_dir_object.name
        else:
            self.report_dir = report_dir
    
    def debug(self, message):
        # TODO
        if isinstance(message, list):
            for line in message:
                print("Report [DEBUG]: ".rstrip())
        else:
            print("Report [DEBUG]: "+message.rstrip())
    
    def info(self, message):
        # TODO
        if isinstance(message, list):
            for line in message:
                print("Report: ".rstrip())
        else:
            print("Report: "+message.rstrip())
    
    def warn(self, message):
        # TODO
        if isinstance(message, list):
            for line in message:
                print("Report [WARN]: ".rstrip())
        else:
            print("Report [WARN]: "+message.rstrip())
    
    def error(self, message):
        # TODO
        if isinstance(message, list):
            for line in message:
                print("Report [ERROR]: ".rstrip())
        else:
            print("Report [ERROR]: "+message.rstrip())
    
    def email(self, message):
        # TODO
        # markdown to html?
        # def html-to-text(): combine on one line | remove head | remove inline tags | replace all other tags with a newline
        print("E-mail: "+message)
    
    def slack(self, message):
        # TODO
        print("Slack: "+message)
    
    def fromHtml(html):
        # TODO
        print("Convert from HTML to Markdown: "+html)
