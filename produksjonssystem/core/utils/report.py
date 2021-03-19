# -*- coding: utf-8 -*-

import logging
import os
import re
import shutil
import smtplib
import tempfile
import time

from datetime import datetime, timedelta, timezone
from email.headerregistry import Address
from email.message import EmailMessage
from pprint import pformat

import markdown
from dotmap import DotMap

from core.config import Config
from core.utils.filesystem import Filesystem
from core.utils.slack import Slack


class Report():
    """Logging and reporting"""

    stdout_verbosity = 'INFO'
    pipeline = None
    title = None
    should_email = True
    should_message_slack = True
    mailpath = ()  # smb, file, unc
    _report_dir = None
    _messages = None
    img_string = ("<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAYCAYAAADzoH0MAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA"
                  "sTAAALEwEAmpwYAAAAB3RJTUUH4goFCTApeBNtqgAAA2pJREFUOMt1lF1rI2UYhu/JfCST6bRp2kyCjmWzG0wllV1SULTSyoLpcfHU5jyLP6IUQX+"
                  "DLqw/wBbPWiUeaLHBlijpiZbNR9PdDUPKSjL5mszX48Ha6U6HveGBeeGd67nf+3lnGCIi3FKv10e9/hQMw+Du3XuYn4/hjaJbqtVqtL29Tfn8KuXz"
                  "q1QsFqlardKb5AFs26ZyuUzZbJZUVSVFUUgQBBIEgTKZDB0cHJDjOEGAaZrU6XTo6OiICoUCqapKxWKRdnd3aXZ2liRJIkmSaHNzkzqdThDw5Mn3t"
                  "La2Rul0mmKxGOXzq3R4eEiNRoMWFxdJlmWSZZkymQxVKpUAgFtaUvH5w3t43jLx429jXF62sb+/j6urK9i2DZZlAQCu68IwjECG3MbGp7h//wFedp"
                  "9Bc77BTz+Xsbe3BwDeywAgCALC4XAAEGJZFgsLC3j3vQcoPfoSiqKAZdlADYdDnJ2dBQDszs7OzvVCVVXE4/MwXv4NnmMxI8/AcUOwbRuu60LXdWx"
                  "tbYHn+RsHPjuhEBJxEV9/McK3JQsPV+dfnZPjwHEczs/PUS7/4j/C64tut4uZyA9Y+sRG8kMWf/zjwLZthEIhhEIhWJaFx4+/84XpAWzbRvvyL7z/"
                  "cQvMOzKO2wq07r9e9+tqNpuo1WpBQK/XgyQ/gyh8BGADv/+agOu6gTBN00SlUrkZ4/WDruuIzX4ABp9hqA/R6XzlC+t1XVxcYDweIxqN3jgwTRMC/"
                  "xZc+22MR3GY5qvuHMdBEASfi36/j8lk4ncwnU7Bshwsy4JlWV76kiSB4zj0+33Pgeu6cBzHDyAiOI6N6ZQBy7KQJAk8zyORSMAwDIxGIw8giiI4jv"
                  "eH6LouRqMRDGMChmGQTqcRDoeRyWQQDofB87xX8Xgc0ajodyAIAgaDgdelUChA0zTkciuo1+vgOG8rUqkUIpGIHxCPx9FqtbyNc3NzKJVK0DQNROS"
                  "biKIkg2NMJpPQdR2NRhOpVNL7Eh3HgSAIPoBhTEBEYBjmBsCyLJaXlyHLMk5PTyGKIkRRRCQSgaIoGI/HHuD4+Bi5XA4rKytgbv+VNU1Dtfon6vWn"
                  "4Hked+6k0ev1cHJyghcvnnsjlmUZ6+vrQYDjOLAsC5OJAdd1EI1G/78nJtrtCzSaTQz0AVKpJLLZLP4DF17fodMaIVYAAAAASUVORK5CYII")
    # + siste del: "=\" alt=\"DATA\">")

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

    def reportDir(self):
        # Lag rapport-mappe
        if not self._report_dir:
            report_dir = os.path.join(self.pipeline.dir_reports, "logs", datetime.now(timezone.utc).strftime("%Y-%m"))
            timestring = datetime.now(timezone.utc).strftime("%F_%H-%M-%S.") + str(round((time.time() % 1) * 1000)).zfill(3)
            if self.pipeline and self.pipeline.book and "name" in self.pipeline.book:
                book_name = self.pipeline.book["name"]
                book_name = os.path.splitext(book_name)[0]
                report_dir = os.path.join(report_dir, book_name, timestring + "-" + self.pipeline.uid)
            else:
                report_dir = os.path.join(report_dir, self.pipeline.uid, timestring)
            os.makedirs(report_dir, exist_ok=True)
            self._report_dir = report_dir
        return self._report_dir

    def log_to_logging(self, severity, message):
        if severity == "DEBUG":
            logging.debug(message)
        elif severity == "INFO":
            logging.info(message)
        elif severity == "SUCCESS":
            logging.info(message)
        elif severity == "WARN":
            logging.warning(message)
        elif severity == "ERROR":
            logging.warning(message)  # note that errors in the report, are logged to the logger using the warning level
        else:
            logging.warning("Unknown message severity: " + str(severity))
            logging.warning(message)

    def add_message(self, severity, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        self.log_to_logging(severity, message)

        lines = None
        if isinstance(message, list):
            lines = message
        else:
            lines = [message]
        lines = [line if isinstance(line, str) else pformat(line) for line in lines]  # make everything into a string

        if message_type not in self._messages:
            self._messages[message_type] = []

        lines = [subline for line in lines for subline in line.split("\n")]
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

    def warning(self, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        self.add_message('WARN', message=message, message_type=message_type,  preformatted=preformatted,
                         add_empty_line_last=add_empty_line_last, add_empty_line_between=add_empty_line_between)

    def warn(self, *args, **kwargs):
        # alias for `warning(…)`
        self.warning(*args, **kwargs)

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
            if not isinstance(a, str) or "@" not in a:
                logging.debug("not an e-mail address: {} ({})".format(a, type(a)))
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
    def filterEmailAddresses(addresses, library=None):
        if isinstance(addresses, Address):
            return addresses
        elif isinstance(addresses, str):
            addresses = [addresses]
        elif isinstance(addresses, tuple):
            addresses = list(addresses)

        if not library:
            logging.info("[e-mail] No library to filter on. Using unfiltered list of e-mail addresses.")
            return tuple(addresses)

        filtered = []
        library = library.lower()
        for address in addresses:
            second_level_domain = address.lower().split("@")[-1].split(".")[-2]
            if second_level_domain == library:
                filtered.append(address)

        if filtered:
            logging.info("[e-mail] Filtered e-mail addresses. Only sending to: {}".format(library))
            return tuple(filtered)
        else:
            logging.info("[e-mail] No addresses remaining after filtering. Using unfiltered list of e-mail addresses.")
            return tuple(addresses)

    @staticmethod
    def emailPlainText(subject, message, recipients, should_email=True):
        assert isinstance(subject, str), "subject must be a str, was: {}".format(type(subject))
        assert isinstance(message, str), "message must be a str, was: {}".format(type(message))

        if recipients is None:
            logging.info("No recipients given, e-mail won't be sent: '" + subject + "'")
            return

        assert isinstance(recipients, str) or isinstance(recipients, list), (
            "recipients must be a str or list, was: {}".format(type(recipients))
        )

        smtp = {
            "host": Config.get("email.smtp.host", None),
            "port": Config.get("email.smtp.port", None),
            "user": Config.get("email.smtp.user", None),
            "pass": Config.get("email.smtp.pass", None)
        }
        sender = Address(Config.get("email.sender.name", "undefined"), addr_spec=Config.get("email.sender.address", "undefined@example.net"))

        if isinstance(recipients, str):
            recipients = [recipients]

        if not should_email:
            logging.info("[e-mail] Not sending plain text email")
        else:
            if Config.get("test"):
                subject = "[test] " + subject
                filtered_recipients = []
                for recipient in recipients:
                    if recipient in Config.get("email.allowed_email_addresses_in_test"):
                        filtered_recipients.append(recipient)
                recipients = filtered_recipients

            # 1. build e-mail
            msg = EmailMessage()
            msg['Subject'] = subject
            msg['From'] = sender
            msg['To'] = Report.emailStringsToAddresses(recipients)
            msg.set_content(message)

            # 2. send e-mail
            if not msg["To"]:
                logging.warning("[e-mail] Email with subject \"{}\" has no recipients".format(subject))
            else:
                logging.info("[e-mail] Sending email with subject \"{}\" to: {}".format(subject, ", ".join(recipients)))
                if isinstance(smtp["host"], str) and isinstance(smtp["port"], str):
                    with smtplib.SMTP(smtp["host"] + ":" + smtp["port"]) as s:
                        s.ehlo()
                        # s.starttls()
                        if smtp["user"] and smtp["pass"]:
                            s.login(smtp["user"], smtp["pass"])
                        else:
                            logging.debug("[e-mail] user/pass not configured")
                        logging.debug("[e-mail] sending…")
                        s.send_message(msg)
                        logging.debug("[e-mail] sending complete.")
                else:
                    logging.warning("[e-mail] host/port not configured")

        Slack.slack(text=subject, attachments=None)

    def email(self, recipients, subject=None, should_email=True, should_message_slack=True, should_attach_log=True, should_escape_chars=True):
        if not subject:
            assert isinstance(self.title, str) or self.pipeline is not None, "either title or pipeline must be specified when subject is missing"
            subject = self.title if self.title else self.pipeline.title

        smtp = {
            "host": Config.get("email.smtp.host", None),
            "port": Config.get("email.smtp.port", None),
            "user": Config.get("email.smtp.user", None),
            "pass": Config.get("email.smtp.pass", None)
        }
        sender = Address(Config.get("email.sender.name", "undefined"), addr_spec=Config.get("email.sender.address", "undefined@example.net"))

        # 0. Create attachment with complete log (including DEBUG statements)
        if should_attach_log is True:
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
            assert isinstance(sender, Address), "sender must be a Address"
            assert isinstance(recipients, str) or isinstance(recipients, list) or isinstance(recipients, tuple), "recipients must be a str, list or tuple"
            assert isinstance(self.title, str) or self.pipeline and isinstance(self.pipeline.title, str), "title or pipeline.title must be a str"

            if isinstance(recipients, str):
                recipients = [recipients]
            elif isinstance(recipients, tuple):
                recipients = list(recipients)

            if status == "ERROR":
                for key in Config.get("administrators", default=[]):
                    if key not in recipients:
                        recipients.append(key)

            # when testing, only allow e-mail addresses defined in the ALLOWED_EMAIL_ADDRESSES_IN_TEST env var
            if Config.get("test"):
                subject = "[test] " + subject
                filtered_recipients = []
                for recipient in recipients:
                    if recipient in Config.get("email.allowed_email_addresses_in_test"):
                        filtered_recipients.append(recipient)
                recipients = filtered_recipients

            # 1. join lines with severity SUCCESS/INFO/WARN/ERROR
            markdown_text = []
            for m in self._messages["message"]:
                if should_escape_chars:
                    text = m['text'].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                else:
                    text = m['text']
                if m['preformatted'] is True:
                    markdown_text.append("<pre>{}</pre>".format(text))
                elif m['severity'] != 'DEBUG':
                    markdown_text.append(text)
            if attachments != [] or should_attach_log is True:
                markdown_text.append("\n----\n")
                markdown_text.append("\n# Lenker\n")
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
                    li += "<a href=\"file:///" + attachment["unc"] + "\">" + attachment["title"] + "</a> "
                    li += "<a href=\"" + attachment["smb"] + "\">" + self.img_string + "=\" alt=\"" + attachment["smb"] + "\"/>" + "</a> "
                    li += "</span>"
                    li += "</li>"
                    markdown_text.append(li)
                markdown_text.append("</ul>\n")
                label_string = ""
                for label in self.pipeline.labels:
                    label_string += "[{}] ".format(label)
                markdown_text.append("\n[{}] {} [{}] [status:{}]".format(self.pipeline.uid, label_string, self.pipeline.publication_format, status))
            markdown_text = "\n".join(markdown_text)

            # 2. parse string as Markdown and render as HTML
            if should_escape_chars:
                markdown_html = markdown.markdown(markdown_text, extensions=['markdown.extensions.fenced_code', 'markdown.extensions.codehilite'])
            else:
                markdown_html = markdown_text
            markdown_html = '''<!DOCTYPE html>
<html>
<head>
<meta charset=\"utf-8\"/>
<title>''' + subject.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") + '''</title>
</head>
<body>
''' + markdown_html + '''
</body>
</html>
'''

            if not should_email:
                logging.info("[e-mail] Not sending email")
            else:
                # 3. build e-mail
                msg = EmailMessage()
                msg['Subject'] = re.sub(r"\s", " ", subject).strip()
                msg['From'] = sender
                msg['To'] = Report.emailStringsToAddresses(recipients)
                msg.set_content(markdown_text)
                msg.add_alternative(markdown_html, subtype="html")
                logging.info("[e-mail] E-mail with subject '{}' will be sent to: {}".format(msg['Subject'], ", ".join(recipients)))

                # 4. send e-mail
                if smtp["host"] and smtp["port"]:
                    smtp_server = "{}:{}".format(smtp["host"], smtp["port"])
                    logging.info("[e-mail] SMTP server: {}".format(smtp_server))
                    with smtplib.SMTP(smtp_server) as s:
                        s.ehlo()
                        # s.starttls()
                        if smtp["user"] and smtp["pass"]:
                            s.login(smtp["user"], smtp["pass"])
                        else:
                            logging.debug("[e-mail] user/pass not configured")
                        logging.debug("[e-mail] sending…")
                        s.send_message(msg)
                        logging.debug("[e-mail] sending complete.")
                else:
                    logging.warning("[e-mail] host/port not configured")

                temp_md_obj = tempfile.NamedTemporaryFile(suffix=".md")
                temp_html_obj = tempfile.NamedTemporaryFile(suffix=".html")
                with open(temp_md_obj.name, "w") as f:
                    f.write(markdown_text)
                    logging.debug("[e-mail] markdown: {}".format(temp_md_obj.name))
                with open(temp_html_obj.name, "w") as f:
                    f.write(markdown_html)
                    logging.debug("[e-mail] html: {}".format(temp_html_obj.name))
                if should_attach_log is True:
                    path_mail = os.path.join(self.reportDir(), "email.html")
                    shutil.copy(temp_html_obj.name, path_mail)
                    self.mailpath = Filesystem.networkpath(path_mail)
                else:
                    yesterday = datetime.now() - timedelta(1)
                    yesterday = str(yesterday.strftime("%Y-%m-%d"))
                    path_mail = os.path.join(self.pipeline.dir_reports, "logs", "dagsrapporter", yesterday, self.pipeline.uid + ".html")
                    shutil.copy(temp_html_obj.name, path_mail)
                    self.mailpath = Filesystem.networkpath(path_mail)

        except AssertionError as e:
            logging.error("[e-mail] " + str(e))
        if not should_message_slack:
            logging.warning("Not sending message to slack")
        else:
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


class DummyReport(Report):
    pipeline = None

    def add_message(self, severity, message, message_type="message", preformatted=False, add_empty_line_last=True, add_empty_line_between=False):
        self.log_to_logging(severity, str(message))

    def attachment(self, content, path, severity):
        logging.info("attachment: " + (str(content)[:100]) + ("..." if len(str(content)) > 100 else "") + "|" + str(path) + "|" + str(severity))
