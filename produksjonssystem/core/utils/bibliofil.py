import logging
import os

import requests

from core.config import Config
from core.directory import Directory
from core.utils.report import Report


class Bibliofil:

    @staticmethod
    def book_available(format, identifier, report=logging):
        library = None

        # get the appropriate book identifier(s)
        logging.info("{}/editions/{}?edition-metadata=all".format(Config.get("nlb_api_url"), identifier))
        response = requests.get("{}/editions/{}?edition-metadata=all".format(Config.get("nlb_api_url"), identifier))
        if response.status_code == 200:
            data = response.json()['data']
            library = data["library"]

        if format == "XHTML":  # "XHTML" means e-book (we're reusing identifiers previously reserved for XHTML files)
            lines = []

            has_epub = os.path.isdir(os.path.join(Directory.dirs_flat["epub-ebook"], identifier))
            has_html = has_epub  # generated based on the EPUB on the fly
            has_docx = has_epub  # generated based on the EPUB on the fly
            has_mobi = has_epub  # generated based on the EPUB on the fly

            if has_epub:
                lines.append("{};{};{};{}".format(identifier, "epub", "dl", "EPUB"))

            if has_html:
                lines.append("{};{};{};{}".format(identifier, "html", "dl", "HTML"))

            if has_docx and library == "Statped":
                lines.append("{};{};{};{}".format(identifier, "docx", "dl", "DOCX (Word)"))

            if has_mobi:
                lines.append("{};{};{};{}".format(identifier, "mobi", "ki", "Send til Kindle"))

            if has_epub:
                lines.append("{};{};{};{}".format(identifier, "epub", "no", "Legg til på bokhylle"))

            if has_epub:
                lines.append("{};{};{};{}".format(identifier, "epub", "st", "Vis i nettleseren"))

            logging.info("Sending formatklar-e-mail to {} with content:".format(Config.get("email.formatklar.address")))
            logging.info("\n".join(lines))
            Report.emailPlainText("formatklar: " + identifier,
                                  "\n".join(lines),
                                  Config.get("email.formatklar.address"))

        else:
            report.debug("book_available: unknown format: {}".format(format))
            return
