# -*- coding: utf-8 -*-

import tempfile
import re
import markdown
import pygments # for markdown code highlighting
import os
import smtplib

from email.message import EmailMessage
from email.headerregistry import Address
from email.utils import make_msgid


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
    
    def email(self, subject, recipients=[]):
        assert subject
        
        # 1. join lines with severity INFO/WARN/ERROR
        markdown_text = []
        for m in self._messages:
            if m['severity'] != 'DEBUG':
                markdown_text.append(m['text'])
        markdown_text = "\n".join(markdown_text)
        
        # 2. parse string as Markdown and render as HTML
        markdown_html = markdown.markdown(markdown_text, extensions=['fenced_code', 'codehilite'])
        markdown_html = '''<!DOCTYPE html>
<html>
<head>
<meta charset=\"utf-8\"/>
<title>"+subject+"</title>
</head>
<body>
''' + markdown_html + '''
</body>
</html>
'''
        
        # 3. build e-mail
        msg = EmailMessage()
        msg['Subject'] = subject
        msg['From'] = Address("NLB", "noreply@nlb.no")
        msg['To'] = tuple(recipients)
        msg.set_content(markdown_text)
        msg.add_alternative(markdown_html, subtype="html")
        
        # 4. send e-mail
        with smtplib.SMTP('smtp.gmail.com:587') as s:
            s.ehlo()
            s.starttls()
            s.login(os.environ["GMAIL_USERNAME"], os.environ["GMAIL_PASSWORD"])
            s.send_message(msg)
        
        with open('/tmp/email.md', "w") as f:
            f.write(markdown_text)
            print("email markdown: /tmp/email.md")
        with open('/tmp/email.html', "w") as f:
            f.write(markdown_html)
            print("email html: /tmp/email.html")
    
    def slack(self, message):
        print("TODO: send message to Slack")
    
    def infoHtml(self, html):
        """ wash the HTML before reporting it """
        
        if isinstance(html, list):
            html = "\n".join(html)
        html = re.sub("^.*<body[^>]*>", "", html, flags=re.DOTALL)
        html = re.sub("</body.*$", "", html, flags=re.DOTALL)
        html = re.sub("<script[^>]*(/>|>.*?</script>)", "", html, flags=re.DOTALL)
        html = "\n".join([line.strip() for line in html.split("\n")])
        self.info(html)
    