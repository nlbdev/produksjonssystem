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

from core.utils.filesystem import Filesystem

class Report():
    """Logging and reporting"""
    
    stdout_verbosity = 'INFO'
    book = None
    _messages = {}
    
    _i18n = {
        "Links": "Lenker",
        "none": "ingen"
    }
    
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
    
    def email(self, subject, sender, recipients, smtp, logpath):
        assert subject
        assert sender
        assert recipients
        assert smtp
        
        # 0. Create attachment with complete log (including DEBUG statements)
        self.attachment([m["text"] for m in self._messages["message"]], logpath, "DEBUG")
        
        # Determine overall status
        status = "INFO"
        for message_type in self._messages:
            for m in self._messages[message_type]:

                if m["severity"] == "SUCCESS" and status in [ "INFO" ]:
                    status = "SUCCESS"
                elif m["severity"] == "WARN" and status in [ "INFO", "SUCCESS" ]:
                    status = "WARN"
                elif m["severity"] == "ERROR":
                    status = "ERROR"
        
        
        # 1. join lines with severity SUCCESS/INFO/WARN/ERROR
        markdown_text = []
        for m in self._messages["message"]:
            if m['severity'] != 'DEBUG':
                markdown_text.append(m['text'])
        markdown_text.append("\n----\n")
        markdown_text.append("\n# "+self._i18n["Links"]+"\n")
        markdown_text.append("\n<ul style=\"list-style: none;\">")
        
        # Pick icon and style for INFO-attachments
        attachment_styles = {
            "DEBUG": {
                "icon": "🗎",
                "style": ""
            },
            "INFO": {
                "icon": "🛈",
                "style": ""
            },
            "SUCCESS": {
                "icon": "😄",
                "style": "background-color: #bfffbf;"
            },
            "WARN": {
                "icon": "😟",
                "style": "background-color: #ffffbf;"
            },
            "ERROR": {
                "icon": "😭",
                "style": "background-color: #ffbfbf;"
            }
        }
            
        for m in self._messages["attachment"]:
            smb, file, unc = Filesystem.networkpath(m["text"])
            # UNC links seems to be preserved when viewed in Outlook.
            # file: and smb: URIs are disallowed or removed.
            # So these links will only work in Windows.
            # If we need this to work cross-platform, we would have
            # to map the network share paths to a web server so that
            # the transfers go through http:. This could maybe be mapped
            # using environment variables.
            li = "<li>"
            li += "<span style=\"vertical-align: middle; font-size: 200%;\">" + attachment_styles[m["severity"]]["icon"] + "</span> "
            li += "<span style=\"vertical-align: middle; " + attachment_styles[m["severity"]]["style"] + "\">"
            li += "<a href=\"" + unc + "\">" + os.path.basename(file) + "</a></sup>"
            li += "</span>"
            li += "</li>"
            markdown_text.append(li)
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
        msg['From'] = sender
        msg['To'] = recipients if isinstance(recipients, Address) else tuple(recipients)
        msg.set_content(markdown_text)
        msg.add_alternative(markdown_html, subtype="html")
        
        # 4. send e-mail
        with smtplib.SMTP(smtp["host"] + ":" + smtp["port"]) as s:
            s.ehlo()
            s.starttls()
            s.login(smtp["user"], smtp["pass"])
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
    
    def attachment(self, content, path, severity):
        assert path and os.path.isabs(path), "Links must have an absolute path."
        assert not content or isinstance(content, list) or isinstance(content, str), "Attachment content must be a string or list when given."
        if content:
            if isinstance(content, list):
                content = "\n".join(content)
            with open(path, "x") as f:
                f.write(content)
        if severity == "INFO":
            self.info(path, message_type="attachment", add_empty_line=False)
        elif severity == "SUCCESS":
            self.success(path, message_type="attachment", add_empty_line=False)
        elif severity == "WARN":
            self.warn(path, message_type="attachment", add_empty_line=False)
        else: # "ERROR"
            self.error(path, message_type="attachment", add_empty_line=False)
    
    # in case you want to override something
    def translate(self, english_text, translated_text):
        self._i18n[english_text] = translated_text
    