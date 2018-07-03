# -*- coding: utf-8 -*-

import os
import re
import sys
import time
import logging
import smtplib
import markdown
import pygments  # for markdown code highlighting
import tempfile

from dotmap import DotMap
from datetime import datetime, timezone
from email.message import EmailMessage
from core.utils.slack import Slack
from email.headerregistry import Address
from core.utils.filesystem import Filesystem


class Report():
    """Logging and reporting"""

    stdout_verbosity = 'INFO'
    pipeline = None
    title = None
    should_email = True
    _report_dir = None
    _messages = None

    _i18n = {
        "Links": "Lenker",
        "none": "ingen"
    }

    def __init__(self, pipeline, title=None, report_dir=None, dir_base=None, uid=None):
        self._messages = {
            "message": [],
            "attachment": []
        }
        self.title = title
        if pipeline:
            self.pipeline = pipeline
        else:
            assert report_dir, "report_dir must be specified when pipeline is missing"
            assert dir_base, "dir_base must be specified when pipeline is missing"
            assert uid, "uid must be specified when pipeline is missing"

            os.makedirs(report_dir, exist_ok=True)
            self._report_dir = report_dir

            self.pipeline = DotMap()
            self.pipeline.book = {}
            self.pipeline.uid = uid
            self.pipeline.dir_base = dir_base
        logging.basicConfig(stream=sys.stdout, format="%(asctime)s %(levelname)-8s [%(threadName)-40s] %(message)s")

    def reportDir(self):
        # Lag rapport-mappe
        if not self._report_dir:
            report_dir = os.path.join(self.pipeline.dir_reports, "logs", datetime.now(timezone.utc).strftime("%Y-%m"))
            timestring = datetime.now(timezone.utc).strftime("%F_%H-%M-%S.") + str(round((time.time() % 1) * 1000)).zfill(3)
            if self.pipeline and self.pipeline.book and "name" in self.pipeline.book:
                report_dir = os.path.join(report_dir, self.pipeline.book["name"], timestring + "-" + self.pipeline.uid)
            else:
                report_dir = os.path.join(report_dir, self.pipeline.uid, timestring)
            os.makedirs(report_dir, exist_ok=True)
            self._report_dir = report_dir
        return self._report_dir

    def add_message(self, severity, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        if severity == "DEBUG":
            logging.debug(message)
        elif severity == "INFO":
            logging.info(message)
        elif severity == "SUCCESS":
            logging.info(message)
        elif severity == "WARN":
            logging.warning(message)
        elif severity == "ERROR":
            logging.error(message)
        else:
            logging.warning("Unknown message severity: " + str(severity))
            logging.warning(message)

        lines = None
        if isinstance(message, list):
            lines = message
        else:
            lines = [message]

        if message_type not in self._messages:
            self._messages[message_type] = []

        lines = [l for line in lines for l in line.split("\n")]
        if add_empty_line_between:
            spaced_lines = []
            for line in lines:
                spaced_lines.append(line)
                spaced_lines.append("")
            lines = spaced_lines
        if add_empty_line_last:
            lines.append("")

        if preformatted is True:
            lines = [message]

        for line in lines:
            self._messages[message_type].append({'time': time.strftime("%Y-%m-%d %H:%M:%S"),
                                                 'severity': severity,
                                                 'text': line,
                                                 'time_seconds': (time.time()),
                                                 'preformatted': preformatted})

    def debug(self, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        self.add_message('DEBUG', message=message, message_type=message_type, preformatted=preformatted,
                         add_empty_line_last=add_empty_line_last, add_empty_line_between=add_empty_line_between)

    def info(self, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        self.add_message('INFO', message=message, message_type=message_type, preformatted=preformatted,
                         add_empty_line_last=add_empty_line_last, add_empty_line_between=add_empty_line_between)

    def success(self, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        self.add_message('SUCCESS', message=message, message_type=message_type, preformatted=preformatted,
                         add_empty_line_last=add_empty_line_last, add_empty_line_between=add_empty_line_between)

    def warn(self, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        self.add_message('WARN', message=message, message_type=message_type,  preformatted=preformatted,
                         add_empty_line_last=add_empty_line_last, add_empty_line_between=add_empty_line_between)

    def error(self, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        self.add_message('ERROR', message=message, message_type=message_type,  preformatted=preformatted,
                         add_empty_line_last=add_empty_line_last, add_empty_line_between=add_empty_line_between)

    @staticmethod
    def emailStringsToAddresses(addresses):
        # Build set of recipients as Address objects.
        # Names are generated based on the email-address.
        _addresses = []
        if isinstance(addresses, Address):
            return addresses
        elif isinstance(addresses, str):
            addresses = [addresses]
        elif isinstance(addresses, tuple):
            addresses = list(addresses)

        for a in addresses:
            if isinstance(a, Address):
                _addresses.append(a)
                continue
            name = []
            for n in a.split("@")[0].split("."):
                name.extend(re.findall("[A-Z]?[^A-Z]+", n))
            name = [n[0].upper() + n[1:] for n in name]
            name = " ".join(name)
            user = a.split("@")[0]
            domain = a.split("@")[1]
            _addresses.append(Address(name, user, domain))

        return tuple(_addresses)

    @staticmethod
    def emailPlainText(subject, message, smtp, sender, recipients):
        assert isinstance(subject, str)
        assert isinstance(message, str)
        assert isinstance(smtp, dict)
        assert isinstance(sender, str) or isinstance(sender, Address)
        assert isinstance(recipients, str) or isinstance(recipients, list)

        # 1. build e-mail
        msg = EmailMessage()
        msg['Subject'] = subject
        msg['From'] = sender if isinstance(sender, Address) else Report.emailStringsToAddresses(sender)
        msg['To'] = Report.emailStringsToAddresses(recipients)
        msg.set_content(message)

        # 2. send e-mail
        if not msg["To"]:
            logging.warning("Email with subject \"{}\" has no recipients".format(subject))
        else:
            logging.info("Sending email with subject \"{}\" to: {}".format(subject, ", ".join(recipients)))
            if "host" in smtp and "port" in smtp:
                with smtplib.SMTP(smtp["host"] + ":" + smtp["port"]) as s:
                    s.ehlo()
                    s.starttls()
                    if "user" in smtp and "pass" in smtp:
                        s.login(smtp["user"], smtp["pass"])
                    else:
                        logging.debug("email user/pass not configured")
                    s.send_message(msg)
            else:
                logging.warning("email host/port not configured")

        Slack.slack(text=subject, attachments=None)

    def email(self, smtp, sender, recipients, subject=None):
        if not subject:
            assert isinstance(self.title, str) or self.pipeline is not None, "either title or pipeline must be specified when subject is missing"
            subject = self.title if self.title else self.pipeline.title

        # 0. Create attachment with complete log (including DEBUG statements)
        self.attachLog()

        attachments = []
        for m in self._messages["attachment"]:
            smb, file, unc = Filesystem.networkpath(m["text"])
            base_path = Filesystem.get_base_path(m["text"], self.pipeline.dir_base)
            relpath = os.path.relpath(m["text"], base_path) if base_path else None
            if m["text"].startswith(self.reportDir()):
                relpath = os.path.relpath(m["text"], self.reportDir())
            if not [a for a in attachments if a["unc"] == unc]:
                attachments.append({
                    "title": "{}{}".format(relpath, ("/" if os.path.isdir(m["text"]) else "")),
                    "smb": smb,
                    "file": file,
                    "unc": unc,
                    "severity": m["severity"]
                })

        # Determine overall status
        status = "INFO"
        for message_type in self._messages:
            for m in self._messages[message_type]:

                if m["severity"] == "SUCCESS" and status in ["INFO"]:
                    status = "SUCCESS"
                elif m["severity"] == "WARN" and status in ["INFO", "SUCCESS"]:
                    status = "WARN"
                elif m["severity"] == "ERROR":
                    status = "ERROR"

        try:
            assert isinstance(smtp, dict), "smtp must be a dict"
            assert isinstance(sender, str) or isinstance(sender, Address), "sender must be a str or Address"
            assert isinstance(recipients, str) or isinstance(recipients, list), "recipients must be a str or list"
            assert isinstance(self.title, str) or self.pipeline and isinstance(self.pipeline.title, str), "title or pipeline.title must be a str"

            if isinstance(recipients, str):
                recipients = [recipients]

            if status == "ERROR":
                if "administrators" not in self.pipeline.common_config:
                    self.pipeline.common_config["administrators"] = []
                for key in self.pipeline.common_config["administrators"]:
                    if key not in recipients:
                        recipients.append(key)

            # 1. join lines with severity SUCCESS/INFO/WARN/ERROR
            markdown_text = []
            for m in self._messages["message"]:
                if m['preformatted'] is True:
                    markdown_text.append("<pre>{}</pre>".format(m['text']))
                elif m['severity'] != 'DEBUG':
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

            for attachment in attachments:
                # UNC links seems to be preserved when viewed in Outlook.
                # file: and smb: URIs are disallowed or removed.
                # So these links will only work in Windows.
                # If we need this to work cross-platform, we would have
                # to map the network share paths to a web server so that
                # the transfers go through http:. This could maybe be mapped
                # using environment variables.
                li = "<li>"
                li += "<span style=\"vertical-align: middle; font-size: 200%;\">" + attachment_styles[attachment["severity"]]["icon"] + "</span> "
                li += "<span style=\"vertical-align: middle; " + attachment_styles[attachment["severity"]]["style"] + "\">"
                li += "<a href=\"" + attachment["unc"] + "\">" + attachment["title"] + "</a></sup>"
                li += "</span>"
                li += "</li>"
                markdown_text.append(li)
            markdown_text.append("</ul>\n")
            markdown_text = "\n".join(markdown_text)

            # 2. parse string as Markdown and render as HTML
            markdown_html = markdown.markdown(markdown_text, extensions=['markdown.extensions.fenced_code', 'markdown.extensions.codehilite'])
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
            msg['From'] = sender if isinstance(sender, Address) else Report.emailStringsToAddresses(sender)
            msg['To'] = Report.emailStringsToAddresses(recipients)
            msg.set_content(markdown_text)
            msg.add_alternative(markdown_html, subtype="html")

            logging.info("E-mail with subject '{}' will be sent to: {}".format(msg['Subject'], ", ".join(recipients)))

            # 4. send e-mail
            if "host" in smtp and "port" in smtp:
                smtp_server = "{}:{}".format(smtp["host"], smtp["port"])
                logging.info("SMTP server: {}".format(smtp_server))
                with smtplib.SMTP(smtp_server) as s:
                    s.ehlo()
                    s.starttls()
                    if "user" in smtp and "pass" in smtp:
                        s.login(smtp["user"], smtp["pass"])
                    else:
                        logging.debug("email user/pass not configured")
                    s.send_message(msg)
            else:
                logging.warning("email host/port not configured")

            temp_md_obj = tempfile.NamedTemporaryFile(suffix=".md")
            temp_html_obj = tempfile.NamedTemporaryFile(suffix=".html")
            with open(temp_md_obj.name, "w") as f:
                f.write(markdown_text)
                logging.debug("email markdown: {}".format(temp_md_obj.name))
            with open(temp_html_obj.name, "w") as f:
                f.write(markdown_html)
                logging.debug("email html: {}".format(temp_html_obj.name))

        except AssertionError as e:
            logging.error(str(e))

        # 5. send message to Slack
        slack_attachments = []
        for attachment in attachments:
            color = None
            if attachment["severity"] == "SUCCESS":
                color = "good"
            elif attachment["severity"] == "WARN":
                color = "warning"
            elif attachment["severity"] == "ERROR":
                color = "danger"
            slack_attachments.append({
                "title_link": attachment["smb"],
                "title": attachment["title"],
                "fallback": attachment["title"],
                "color": color
            })
        Slack.slack(text=subject, attachments=slack_attachments)

    def attachLog(self):
        logpath = os.path.join(self.reportDir(), "log.txt")
        attach = []
        start_time = 0
        for m in self._messages["message"]:
            if start_time == 0:
                start_time = m["time_seconds"]
            if m["text"] == "":
                attach.append(m["text"])
            else:
                duration = "{0:.4f}".format(m["time_seconds"] - start_time)
                attach.append("[{}s] {}" .format(duration, m["text"]))
        self.attachment(attach, logpath, "DEBUG")
        return logpath

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

        if path in [m["text"] for m in self._messages["attachment"]]:
            self.debug("Skipping attachment; tried attaching same attachment twice: " + path)
            return

        if content:
            if isinstance(content, list):
                content = "\n".join(content)
            with open(path, "a") as f:
                f.write(content)
        if severity == "DEBUG":
            self.info(path, message_type="attachment", add_empty_line_last=False)
        elif severity == "INFO":
            self.info(path, message_type="attachment", add_empty_line_last=False)
        elif severity == "SUCCESS":
            self.success(path, message_type="attachment", add_empty_line_last=False)
        elif severity == "WARN":
            self.warn(path, message_type="attachment", add_empty_line_last=False)
        else:  # "ERROR"
            self.error(path, message_type="attachment", add_empty_line_last=False)

    # in case you want to override something
    def translate(self, english_text, translated_text):
        self._i18n[english_text] = translated_text


class DummyReport(Report):
    pipeline = None

    def add_message(self, severity, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        logging.debug("[" + str(severity) + "] " + str(message))

    def attachment(self, content, path, severity):
        logging.debug("attachment: " + (str(content)[:100]) + ("..." if len(str(content)) > 100 else "") + "|" + str(path) + "|" + str(severity))
