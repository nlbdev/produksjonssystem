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

            epub_dir = os.path.join(Directory.dirs_flat["epub-ebook"], identifier)
            has_epub = os.path.isdir(epub_dir)
            has_html = has_epub  # generated based on the EPUB on the fly
            # has_docx = has_epub  # generated based on the EPUB on the fly
            has_mobi = has_epub  # generated based on the EPUB on the fly

            size = 0
            if has_epub:
                for root, dirs, files in os.walk(epub_dir):
                    for file in files:
                        size += os.path.getsize(os.path.join(root, file))

                filesize_xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
                filesize_xml += "<root>\n"
                filesize_xml += "<folder><name>{}</name><sizedata>{}</sizedata></folder>\n".format(identifier, size)
                filesize_xml += "</root>\n"

                logging.info("Sending filesize-e-mail to {} with content:".format(Config.get("email.filesize.address")))
                logging.info(filesize_xml)
                Report.emailPlainText("filesize: " + identifier,
                                      filesize_xml,
                                      Config.get("email.filesize.address"))

            if has_epub:
                lines.append("{};{};{};{}".format(identifier, "epub", "dl", "EPUB"))

            if has_html:
                lines.append("{};{};{};{}".format(identifier, "html", "dl", "HTML"))

            if has_mobi:
                lines.append("{};{};{};{}".format(identifier, "mobi", "dl", "Mobi / Kindle Format"))

            if has_epub:
                lines.append("{};{};{};{}".format(identifier, "epub", "no", "Til Lydhør/online-spiller"))

            if has_epub:
                lines.append("{};{};{};{}".format(identifier, "epub", "st", "Til Nettleserbok"))

            if has_mobi and size < 20 * 10**6:  # 20 MB
                lines.append("{};{};{};{}".format(identifier, "mobi", "ki", "Til Kindle/PocketBook"))

            if library is None or library.upper() != "NLB":
                report.debug("book_available: only NLB books should have distribution methods: {} / {}".format(identifier, library))
                lines = []

            logging.info("Sending formatklar-e-mail to {} with content:".format(Config.get("email.formatklar.address")))
            logging.info("\n".join(lines))
            Report.emailPlainText("formatklar: " + identifier,
                                  "\n".join(lines),
                                  Config.get("email.formatklar.address"))

        else:
            report.debug("book_available: unknown format: {}".format(format))
            return
