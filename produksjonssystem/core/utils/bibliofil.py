import logging
import os

import requests

from core.config import Config
from core.directory import Directory
from core.utils.report import Report


class Bibliofil:

    @staticmethod
    def update_list_of_books(format, identifiers, report=logging):
        if format == "XHTML":  # "XHTML" means e-book (we're reusing identifiers previously reserved for XHTML files)

            catalogoue_changes_needed_filesize = 0
            catalogoue_changes_needed_formatklar = 0

            editions = Bibliofil.list_all_editions()
            filesize_xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
            filesize_xml += "<root>\n"

            for book in editions:
                identifier = book["identifier"]
                library = book["library"]

                if identifier in identifiers:
                    lines_formatklar = []

                    epub_dir = os.path.join(Directory.dirs_flat["epub-ebook"], book["identifier"])
                    has_epub = os.path.isdir(epub_dir)
                    if not has_epub:
                        continue
                    has_html = has_epub  # generated based on the EPUB on the fly
                    # has_docx = has_epub  # generated based on the EPUB on the fly
                    has_mobi = has_epub  # generated based on the EPUB on the fly

                    size = 0
                    if has_epub:
                        for root, dirs, files in os.walk(epub_dir):
                            for file in files:
                                size += os.path.getsize(os.path.join(root, file))
                        size_catalogue = 0
                        if book["fileSize"] is not None:
                            size_catalogue = int(book["fileSize"])
                        if size != size_catalogue and size != 0:
                            logging.info(f"Filesize for edition: {identifier} is not correct, will update. New filesize: {size} vs old {size_catalogue}")
                            catalogoue_changes_needed_filesize += 1
                            filesize_xml += "<folder><name>{}</name><sizedata>{}</sizedata></folder>\n".format(book["identifier"], size)

                    distribution_formats = ["epub", "html", "mobi"]
                    distribution_formats_catalogue = []
                    for dist_method in book["distribution"]:
                        dist_format = dist_method["format"]
                        if dist_format not in distribution_formats_catalogue:
                            distribution_formats_catalogue.append(dist_format)

                    distribution_formats.sort()
                    distribution_formats_catalogue.sort()

                    if distribution_formats != distribution_formats_catalogue:

                        catalogoue_changes_needed_formatklar += 1
                        logging.info(f"Distribution formats for edition {identifier} is not correct, will update. Distribution formats: {distribution_formats} vs old {distribution_formats_catalogue}")

                    if has_epub:
                        lines_formatklar.append("{};{};{};{}".format(identifier, "epub", "no", "Til Lydhør/online-spiller"))

                    if has_epub:
                        lines_formatklar.append("{};{};{};{}".format(identifier, "epub", "st", "Til Nettleserbok"))

                    if has_epub:
                        lines_formatklar.append("{};{};{};{}".format(identifier, "epub", "dl", "EPUB"))

                    if has_html:
                        lines_formatklar.append("{};{};{};{}".format(identifier, "html", "dl", "HTML"))

                    if has_mobi and size < 20 * 10**6:  # 20 MB
                        lines_formatklar.append("{};{};{};{}".format(identifier, "mobi", "ki", "Til Kindle/PocketBook"))

                    if has_mobi:
                        lines_formatklar.append("{};{};{};{}".format(identifier, "mobi", "dl", "MOBI/Kindle-format"))

                        if library is None or library.upper() != "NLB":
                            report.debug("book_available: only NLB books should have distribution methods: {} / {}".format(identifier, library))
                            lines_formatklar = []
            if catalogoue_changes_needed_filesize > 0:
                logging.info(f"{catalogoue_changes_needed_filesize} filesize catalogue changes needed")
                filesize_xml += "</root>\n"
                logging.info("Sending filesize-e-mail to {} with content:".format(Config.get("email.filesize.address")))
                logging.info(filesize_xml)
                Report.emailPlainText("filesize: ",
                                      filesize_xml,
                                      Config.get("email.filesize.address"))

            if catalogoue_changes_needed_formatklar > 0:
                logging.info(f"{catalogoue_changes_needed_filesize} formatklar catalogue changes needed")
                Report.emailPlainText("formatklar: ",
                                      "\n".join(lines_formatklar),
                                      Config.get("email.formatklar.address"))
            if catalogoue_changes_needed_filesize == catalogoue_changes_needed_formatklar == 0:
                logging.info(f"No catalog changes needed for format {format}")

        else:
            report.debug("unknown format: {}".format(format))
            return


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
                lines.append("{};{};{};{}".format(identifier, "epub", "no", "Til Lydhør/online-spiller"))

            if has_epub:
                lines.append("{};{};{};{}".format(identifier, "epub", "st", "Til Nettleserbok"))

            if has_epub:
                lines.append("{};{};{};{}".format(identifier, "epub", "dl", "EPUB"))

            if has_html:
                lines.append("{};{};{};{}".format(identifier, "html", "dl", "HTML"))

            if has_mobi and size < 20 * 10**6:  # 20 MB
                lines.append("{};{};{};{}".format(identifier, "mobi", "ki", "Til Kindle/PocketBook"))

            if has_mobi:
                lines.append("{};{};{};{}".format(identifier, "mobi", "dl", "MOBI/Kindle-format"))

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

    @staticmethod
    def list_all_editions():
        logging.info("Henter oversikt over alle utgaver")
        try:
            url = os.path.join(Config.get("nlb_api_url"), "editions")
            params = {
                'limit': '-1',
                'start': '0',
                'order': 'any',
                'include-deleted': 'false',
                'library': 'NLB',
                'creative-work-metadata': 'none',
                'editions-metadata': 'all',
            }
            headers = {
                'Accept': "application/json",
                'Content-Type': "application/json",
                }
            logging.info(url)
            response = requests.request("GET", url, headers=headers, params=params)
            data = response.json()
            editions = data["data"]
            return editions
        except Exception:
            logging.exception("Klarte ikke returnere en liste over alle utgaver")
            return []
