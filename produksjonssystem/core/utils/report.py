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
    _messages = {}
    
    def __init__(self, book):
        self.book = book
    
    def _add_message(self, severity, message, message_type, add_empty_line):
        lines = None
        if isinstance(message, list):
            lines = message
        else:
            lines = [ message ]
        
        if message_type not in self._messages:
            self._messages[message_type] = []
        
        lines = [l for line in lines for l in line.split("\n")]
        if add_empty_line:
            lines.append("")
        
        for line in lines:
            self._messages[message_type].append({ 'severity': severity, 'text': line })
            
            if (self.stdout_verbosity == 'DEBUG' or
                self.stdout_verbosity == 'INFO' and severity in [ 'INFO', 'SUCCESS', 'WARN', 'ERROR' ] or
                self.stdout_verbosity == 'SUCCESS' and severity in [ 'SUCCESS', 'WARN', 'ERROR' ] or
                self.stdout_verbosity == 'WARN' and severity in [ 'WARN', 'ERROR' ] or
                severity == 'ERROR'):
                print("["+severity+"] "+line)
    
    def debug(self, message, message_type="message", add_empty_line=True):
        self._add_message('DEBUG', message, message_type, add_empty_line)
    
    def info(self, message, message_type="message", add_empty_line=True):
        self._add_message('INFO', message, message_type, add_empty_line)
    
    def success(self, message, message_type="message", add_empty_line=True):
        self._add_message('SUCCESS', message, message_type, add_empty_line)
    
    def warn(self, message, message_type="message", add_empty_line=True):
        self._add_message('WARN', message, message_type, add_empty_line)
    
    def error(self, message, message_type="message", add_empty_line=True):
        self._add_message('ERROR', message, message_type, add_empty_line)
    
    def email(self, subject, recipients=[]):
        assert subject
        assert recipients
        
        # 1. join lines with severity INFO/WARN/ERROR
        markdown_text = []
        for message_type in [ "message", "report", "log" ]:
            if markdown_text:
                markdown_text.append("\n----\n")
            if message_type == "report":
                markdown_text.append("\n# Rapporter\n")
                if message_type in self._messages:
                    markdown_text.append("\n<ul>")
            if message_type == "log":
                markdown_text.append("\n# Logg\n")
            if message_type in self._messages:
                for m in self._messages[message_type]:
                    if message_type == "report": # TODO: icon+color based on severity INFO/WARN/ERROR
                        unc = "\\\\"+os.getenv("SERVER_NAME", "example")+m["text"].replace("/","\\")
                        markdown_text.append("<li><a href=\""+unc+"\">"+unc+"</a> <sup><a href=\"file:///"+os.getenv("SERVER_NAME", "example")+m["text"]+"\">🐧</a></sup></li>")
                    elif m['severity'] != 'DEBUG' or message_type == "log":
                        markdown_text.append(m['text'])
            else:
                markdown_text.append("*(ingen)*")
            if message_type == "report" and message_type in self._messages:
                markdown_text.append("</ul>\n")
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
        msg['To'] = recipients if isinstance(recipients, Address) else tuple(recipients)
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
    
    def infoHtml(self, html, message_type="message"):
        """ wash the HTML before reporting it """
        
        if isinstance(html, list):
            html = "\n".join(html)
        html = re.sub("^.*<body[^>]*>", "", html, flags=re.DOTALL)
        html = re.sub("</body.*$", "", html, flags=re.DOTALL)
        html = re.sub("<script[^>]*(/>|>.*?</script>)", "", html, flags=re.DOTALL)
        html = "\n".join([line.strip() for line in html.split("\n")])
        self.info(html)
    
    def attachReport(self, content, filename, severity):
        assert filename
        # TODO
        if severity == "INFO":
            self.info(os.path.join("/tmp/TODO", filename), message_type="report")
        elif severity == "WARN":
            self.warn(os.path.join("/tmp/TODO", filename), message_type="report")
        else: # "ERROR"
            self.error(os.path.join("/tmp/TODO", filename), message_type="report")
    