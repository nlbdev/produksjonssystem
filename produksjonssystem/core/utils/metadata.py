import dateutil.parser
import datetime
import logging
import os
import re
import tempfile
import threading
import time

import requests
from lxml import etree as ElementTree
from difflib import SequenceMatcher

from core.config import Config
from core.utils.epub import Epub
from core.utils.filesystem import Filesystem
from core.utils.report import Report


class Metadata:
    uid = "core-utils-metadata"
    title = "Metadata"

    formats = ["EPUB", "DAISY 2.02", "XHTML", "Braille"]  # values used in dc:format

    max_update_interval = 60 * 30  # half hour
    max_metadata_emails_per_day = 5

    metadata_cache = {}
    _cache_update_lock = threading.RLock()

    signatures_cache = {}
    signatures_last_update = 0
    _signatures_cachelock = threading.RLock()

    old_books = []
    old_books_last_update = 0
    _old_books_cachelock = threading.RLock()

    creative_works = []
    creative_works_last_update = 0
    _creative_works_cachelock = threading.RLock()

    requests_cache = {}
    _requests_cachelock = threading.RLock()

    def requests_get(url, cache_timeout=30):
        # In some cases, the same URL will be requested multiple times almost simultaneously.
        # This should reduce the amount of requests done against the API.
        with Metadata._requests_cachelock:
            for cached_url in list(Metadata.requests_cache.keys()):
                if Metadata.requests_cache[cached_url]["timeout"] < time.time():
                    # delete any outdated data from the cache, so that it gets refreshed, and so that we don't store unnecessary data in the cache
                    del Metadata.requests_cache[cached_url]

                elif url == cached_url:
                    # hopefully responses are thread safe, as we give the same object to multiple threads here
                    logging.debug("Using cached response for: {}".format(url))
                    return Metadata.requests_cache[cached_url]["response"]

            # cache the response, and return it
            Metadata.requests_cache[url] = {
                "timeout": time.time() + cache_timeout,
                "response": requests.get(url),
            }
            return Metadata.requests_cache[url]["response"]

    @staticmethod
    def get_metadata_dir(identifier=None):
        if not Config.get("metadata_dir"):
            Metadata.metadata_tempdir_obj = tempfile.TemporaryDirectory(prefix="metadata-")
            logging.debug("Using temporary directory for metadata: " + Metadata.metadata_tempdir_obj.name)
            Config.set("metadata_dir", Metadata.metadata_tempdir_obj.name)

        if len(str(identifier)) > 0:
            return os.path.join(Config.get("metadata_dir"), str(identifier))
        else:
            return Config.get("metadata_dir")

    @staticmethod
    def get_dir_lock(dir):
        assert dir is not None, "get_dir_lock: dir missing"
        with Metadata._metadata_dirs_locks_lock:
            if dir not in Metadata._metadata_dirs_locks:
                Metadata._metadata_dirs_locks[dir] = threading.RLock()
            return Metadata._metadata_dirs_locks[dir]

    @staticmethod
    def get_edition_from_api(edition_identifier, format="json", report=logging, use_cache_if_possible=False):
        if format == "json" and use_cache_if_possible:
            cached_data = Metadata.get_creative_work_from_cache(edition_identifier, report=report)
            if cached_data and edition_identifier in cached_data["editions"]:
                return cached_data["editions"][edition_identifier]
            else:
                report.debug("Could not find the creative work for '{}' in the cache. Will have to try the API directly instead.".format(edition_identifier))

        if format == "json":
            edition_url = "{}/editions/{}".format(Config.get("nlb_api_url"), edition_identifier)
        else:
            edition_url = "{}/editions/{}/metadata?format={}".format(Config.get("nlb_api_url"), edition_identifier, format)

        import traceback
        report.debug("".join(traceback.format_stack()))

        report.debug("getting edition metadata from: {}".format(edition_url))
        response = Metadata.requests_get(edition_url)

        if response.status_code == 404 and len(edition_identifier) > 6:
            # fallback for as long as the API does not
            # support edition identifiers longer than 6 digits
            edition_identifier = edition_identifier[:6]
            report.debug("edition identifier is {} digits long, trying 6 first digits instead…".format(len(edition_identifier)))

            if format == "json":
                edition_url = "{}/editions/{}".format(Config.get("nlb_api_url"), edition_identifier)
            else:
                edition_url = "{}/editions/{}/metadata?format={}".format(Config.get("nlb_api_url"), edition_identifier, format)

            report.debug("getting edition metadata from: {}".format(edition_url))
            response = Metadata.requests_get(edition_url)

        if response.status_code == 200:
            if format == "json":
                return response.json()["data"]
            else:
                return response.text

        else:
            report.debug("Could not get metadata for {}".format(edition_identifier))
            return None

    @staticmethod
    def get_creative_work_from_api(edition_identifier, editions_metadata="simple", report=logging, use_cache_if_possible=False):
        if editions_metadata == "simple" and use_cache_if_possible:
            cached_data = Metadata.get_creative_work_from_cache(edition_identifier, report=report)
            if cached_data:
                return cached_data
            else:
                report.debug("Could not find the creative work for '{}' in the cache. Will have to try the API directly instead.".format(edition_identifier))

        edition = Metadata.get_edition_from_api(edition_identifier, report=report)

        if not edition:
            return None

        creative_work_url = "{}/creative-works/{}?editions-metadata={}".format(Config.get("nlb_api_url"), edition["creativeWork"], editions_metadata)

        report.debug("getting creative work metadata from: {}".format(creative_work_url))
        response = Metadata.requests_get(creative_work_url)
        if response.status_code == 200:
            return response.json()['data']

        else:
            report.debug("Could not get creative work metadata for {}".format(edition_identifier))
            return None

    @staticmethod
    def get_identifiers(edition_identifier, report=logging, use_cache_if_possible=False):
        creative_work = Metadata.get_creative_work_from_api(edition_identifier, report=report, use_cache_if_possible=use_cache_if_possible)

        issue = ""
        if len(edition_identifier) > 6:
            issue = edition_identifier[6:]

        identifiers = []

        if creative_work:
            for edition in creative_work["editions"]:
                report.debug("The creative work {} has the edition {} which is the format {}{}".format(
                    creative_work["identifier"],
                    edition["identifier"],
                    edition["format"],
                    " but it is marked as deleted" if edition["deleted"] else ""
                ))
                if not edition["deleted"]:
                    identifiers.append(edition["identifier"])

        # as long as the API only returns 6 digit identifiers, we need to append the issue digits ourselves
        identifiers = [i + issue if len(i) <= 6 else i for i in identifiers]

        return identifiers

    @staticmethod
    def metadata_is_valid(edition_identifier, report=logging):
        validation_report = Metadata.get_validation_report(edition_identifier, report=report)

        if validation_report is None:
            # didn't get a validation report, assume invalid
            return False

        elif "error" in [test["status"] for test in validation_report["tests"]]:
            # the report contains errors
            return False

        else:
            # the report does not contain any errors
            return True

    @staticmethod
    def refresh_old_books_cache_if_necessary(report=logging):
        with Metadata._old_books_cachelock:
            if time.time() - Metadata.old_books_last_update > 3600 * 24:
                editions_url = Config.get("nlb_api_url") + "/editions?limit=-1&editions-metadata=all"
                response = requests.get(editions_url)

                if response.status_code == 200:
                    old_books = []
                    for edition in response.json()["data"]:
                        date = None
                        try:
                            date = dateutil.parser.parse(edition["available"])
                        except Exception:
                            try:
                                date = dateutil.parser.parse(edition["registered"])
                            except Exception:
                                pass

                        if date is None:
                            continue

                        # if more than five years ago
                        if datetime.datetime.utcnow() - date > datetime.timedelta(days=(365.25 * 5)):
                            old_books.append(edition["identifier"])

                    Metadata.old_books = old_books
                    Metadata.old_books_last_update = time.time()
                    report.debug("List of old books has been cached. Found {} old books.".format(len(Metadata.old_books)))

                else:
                    report.debug("Could not update old books metadata from: {}".format(editions_url))

    @staticmethod
    def is_old(identifier, report=logging):
        Metadata.refresh_old_books_cache_if_necessary(report=report)

        with Metadata._old_books_cachelock:
            return identifier in Metadata.old_books

    @staticmethod
    def trigger_metadata_pipelines(report, book_id, exclude=None):
        archive_dirs = {}

        for pipeline_uid in report.pipeline.dirs:
            if report.pipeline.dirs[pipeline_uid]["in"] == Metadata.get_metadata_dir():
                archive_dir = report.pipeline.dirs[pipeline_uid]["out"]
                basepath = Filesystem.get_base_path(archive_dir, report.pipeline.dirs[pipeline_uid]["base"])
                relpath = os.path.relpath(report.pipeline.dirs[pipeline_uid]["out"], basepath)

                if archive_dir not in archive_dirs:
                    archive_dirs[archive_dir] = relpath

        for archive_dir in archive_dirs.keys():
            book_dir = os.path.join(archive_dir, book_id)
            relpath = archive_dirs[archive_dir]
            if not os.path.exists(book_dir):
                report.info("'{}' finnes ikke i '{}'; etterfølgende pipelines blir ikke trigget".format(book_id, relpath))
                del archive_dirs[archive_dir]

        for pipeline_uid in report.pipeline.dirs:
            if pipeline_uid == exclude:
                continue
            if report.pipeline.dirs[pipeline_uid]["in"] in archive_dirs:
                with open(os.path.join(report.pipeline.dirs[pipeline_uid]["trigger"], book_id), "w") as triggerfile:
                    triggerfile.write("autotriggered")
                report.info("Trigger: {}".format(pipeline_uid))

    @staticmethod
    def get_validation_report(edition_identifier, report=logging):
        edition_url = "{}/editions/{}/metadata-validation-report".format(Config.get("nlb_api_url"), edition_identifier)

        report.debug("getting edition metadata validation report from: {}".format(edition_url))
        response = Metadata.requests_get(edition_url)

        if response.status_code == 404 and len(edition_identifier) > 6:
            # fallback for as long as the API does not
            # support edition identifiers longer than 6 digits
            edition_identifier = edition_identifier[:6]
            report.debug("edition identifier is {} digits long, trying 6 first digits instead…".format(len(edition_identifier)))
            edition_url = "{}/editions/{}/metadata-validation-report".format(Config.get("nlb_api_url"), edition_identifier)

            report.debug("getting edition metadata validation report from: {}".format(edition_url))
            response = Metadata.requests_get(edition_url)

        if response.status_code == 200:
            return response.json()['data']

        else:
            report.debug("Could not get metadata validation report for {}".format(edition_identifier))
            return None

    @staticmethod
    def validate_metadata(report, edition_identifier, publication_format="", report_metadata_errors=True):
        # Lag separat rapport/e-post for Bibliofil-metadata
        normarc_report_dir = os.path.join(report.reportDir(), "normarc")
        normarc_report = None
        if report_metadata_errors:
            normarc_report = Report(None,
                                    title=Metadata.title,
                                    report_dir=normarc_report_dir,
                                    dir_base=report.pipeline.dir_base,
                                    uid=Metadata.uid)

        normarc_success = True
        signatureRegistration = None

        creative_work = Metadata.get_creative_work_from_api(edition_identifier, report=report)

        if creative_work is None:
            if report_metadata_errors:
                normarc_report.info("<h2>Katalogposten for {}:</h2>\n".format(edition_identifier))
                report.error("<p>Finner ikke katalogposten. Kan ikke validere.</p>")
            normarc_success = False

        else:
            all_identifiers = [edition["identifier"] for edition in creative_work["editions"]]

            found = False
            for edition in creative_work["editions"]:
                if edition["format"] == publication_format:
                    if report_metadata_errors:
                        normarc_report.info("<h2>Katalogposten for {}:</h2>\n".format(edition["identifier"]))

                    if edition["deleted"]:
                        if report_metadata_errors:
                            normarc_report.info("<p>Hopper over validering. Denne katalogposten ser ut til å være slettet.</p>")
                        continue

                    found = True
                    validation_report = Metadata.get_validation_report(edition["identifier"], report=(normarc_report if normarc_report else logging))

                    if validation_report is None:
                        if report_metadata_errors:
                            normarc_report.error("\n<p>Klarte ikke å validere katalogposten. Kanskje den ikke finnes?</p>")
                        continue

                    severity = "success"
                    for test in validation_report["tests"]:
                        if test["status"] == "warning":
                            severity = "warning"

                        elif test["status"] == "error":
                            severity = "error"
                            break  # break to avoid overwriting 'error' with 'warning'. 'error' is the most severe status.

                    if severity == "error":
                        normarc_success = False

                    if report_metadata_errors:
                        if severity == "success":
                            normarc_report.info("\n<p>Ingen feil eller advarsler. Katalogposten ser bra ut.</p>")

                        else:
                            if severity == "error":
                                normarc_report.info("\n<p>Katalogposten er ikke valid.</p>")
                            else:
                                normarc_report.info("\n<p>Katalogposten er valid, men inneholder advarsler.</p>")

                            normarc_report.info("\n<dl>")
                            for test in validation_report["tests"]:
                                if test["status"] == "error":
                                    normarc_report.error("<dt>Feil: {}</dt>".format(test["title"]))
                                    normarc_report.error("<dd>{}</dd>".format(test["message"]))
                                else:
                                    normarc_report.warning("<dt>Advarsel: {}</dt>".format(test["title"]))
                                    normarc_report.warning("<dd>{}</dd>".format(test["message"]))
                            normarc_report.info("</dl>")

            if not found:
                normarc_success = False
                if report_metadata_errors:
                    normarc_report.error("Finner ikke en katalogpost for {} i formatet '{}'. Disse formatene ble funnet:".format(
                        edition_identifier, publication_format))
                    if len(creative_work["editions"]) == 0:
                        normarc_report.info("<p>Ingen.</p>")
                    else:
                        normarc_report.info("<ul>")
                        for edition in creative_work["editions"]:
                            normarc_report.info("<li><strong>{}</strong>: {}{}</li>".format(edition["identifier"],
                                                                                            edition["format"] if edition["format"] else "ukjent format",
                                                                                            " (katalogposten er slettet)" if edition["deleted"] else ""))
                        normarc_report.info("</ul>")

                    suggestions = Metadata.suggest_similar_editions(edition_identifier, edition_format=publication_format, report=normarc_report)
                    normarc_report.info("Her er noen andre '{}'-katalogposter med lignende titler, ".format(publication_format)
                                        + "kanskje er det feil eller mangler i `596$f` eller `599` i disse:")

                    if len(suggestions) == 0:
                        normarc_report.info("(fant ingen katalogposter med lignende titler)")
                    else:
                        normarc_report.info("<dl>")
                        for suggestion in suggestions:
                            normarc_report.info("<dt>{}</dt>".format(suggestion["identifier"]))
                            normarc_report.info("<dd>{}</dd>".format(suggestion["title"]))
                        normarc_report.info("</dl>")

            if report_metadata_errors:
                signatureRegistration = Metadata.get_cataloging_signature_from_quickbase(all_identifiers, report=normarc_report)
                normarc_report.info("<strong>Ansvarlig for katalogisering</strong>: {}".format(signatureRegistration if signatureRegistration else "(ukjent)"))

        if not report_metadata_errors:
            return normarc_success

        # Send rapport
        normarc_report.attachLog()
        signatureRegistrationAddress = None
        if not normarc_success:
            if signatureRegistration:
                for addr in Config.get("librarians", default=[]):
                    if signatureRegistration == addr.lower():
                        signatureRegistrationAddress = addr
            if not signatureRegistrationAddress:
                normarc_report.warn("'{}' er ikke en aktiv bibliotekar, sender til hovedansvarlig istedenfor: {}".format(
                                                    signatureRegistration if signatureRegistration else "(ukjent)",
                                                    ", ".join([addr.lower() for addr in Config.get("default_librarian", default=[])])))
                normarc_report.debug("Aktive bibliotekarer: {}".format(
                                                    ", ".join([addr.lower() for addr in Config.get("librarians", default=[])])))
                signatureRegistrationAddress = Config.get("default_librarian", default=[])

        # Kopier Bibliofil-metadata-rapporten inn i samme rapport som resten av konverteringen
        for message_type in normarc_report._messages:
            for message in normarc_report._messages[message_type]:
                report._messages[message_type].append(message)

        if not normarc_success:
            library = None
            if creative_work is not None:
                for edition in creative_work["editions"]:
                    if edition["library"] is not None:
                        library = edition["library"]
                        break
            if not library:
                library = Metadata.get_library_from_identifier(edition_identifier)

            Metadata.add_production_info(normarc_report, edition_identifier, publication_format=publication_format)
            signatureRegistrationAddress = Report.filterEmailAddresses(signatureRegistrationAddress, library=library)

            normarc_report.email(signatureRegistrationAddress,
                                 subject="Validering av katalogpost: {}".format(edition_identifier))
            report.warn("Katalogposten i Bibliofil er ikke gyldig. E-post ble sendt til: {}".format(
                ", ".join([addr.lower() for addr in signatureRegistrationAddress])))

            return False

        return True

    @staticmethod
    def insert_metadata(report, epub, publication_format="", report_metadata_errors=True):
        if not isinstance(epub, Epub) or not epub.isepub():
            report.error("Kan bare oppdatere metadata for EPUB")
            return False

        is_valid = Metadata.validate_metadata(report,
                                              epub.identifier(),
                                              publication_format=publication_format,
                                              report_metadata_errors=report_metadata_errors)
        if not is_valid:
            return False

        creative_work = Metadata.get_creative_work_from_api(epub.identifier(), report=report)
        edition_identifier = None
        for edition in creative_work["editions"]:
            if edition["format"] == publication_format:
                edition_identifier = edition["identifier"]
        if edition_identifier is None:
            report.error("Fant ikke '{}'-boknummer for {}.".format(publication_format, epub.identifier()))
            return False

        # Get OPF/HTML metadata from Bibliofil

        opf_metadata = Metadata.get_edition_from_api(edition_identifier, format="opf")
        html_head = Metadata.get_edition_from_api(edition_identifier, format="html")

        # Add metadata from EPUB

        if epub.book_path is None or not os.path.isdir(epub.book_path):
            report.error("EPUB er ikke unzippet: {}".format(epub.book_path))
            return False
        opf_path = os.path.join(epub.book_path, epub.opf_path())
        if not os.path.isabs(opf_path) or not os.path.isfile(opf_path):
            report.error("OPF path is either not absolute or does not point to a file that exists: {}".format(opf_path))
            return False

        opf_element = epub.get_opf_package_element()

        ns = {"opf": "http://www.idpf.org/2007/opf"}

        opf_from_epub = ["", "    <!-- Metadata fra EPUBen -->"]
        html_from_epub = ["", "    <!-- Metadata fra EPUBen -->"]

        # copy metadata from old to new OPF: property="nordic:*", property="a11y:*" and name="cover"
        # copy metadata from OPF to HTML: property="nordic:*", property="a11y:*"
        for meta in opf_element.xpath("//opf:metadata/opf:meta", namespaces=ns):
            property = meta.attrib["property"] if "property" in meta.attrib else None
            name = meta.attrib["name"] if "name" in meta.attrib else None
            content = meta.attrib["content"] if "content" in meta.attrib else meta.text

            if ":" in property and property.split(":")[0] in ["nordic", "a11y"]:
                opf_from_epub.append("        <meta property=\"{}\">{}</meta>".format(property, content))
                html_from_epub.append("        <meta name=\"{}\" content=\"{}\"/>".format(property, content))

            if name == "cover":
                opf_from_epub.append("        <meta name=\"{}\" content=\"{}\"/>".format(name, content))

        # copy link elements from old to new OPF
        link_elements = opf_element.xpath("//opf:metadata/opf:link", namespaces=ns)
        link_ids = [link.attrib["id"] for link in link_elements if "id" in link]
        for link in link_elements:
            if "refines" in link.attrib and link.attrib["refines"][1:] not in link_ids:
                # We don't handle link referencing metadata other than links.
                # If it turns out to be necessary, we can come back to it
                # and handle it somewhere around here.
                continue

            line = "        <link href=\"{}\"".format(link.attrib["href"])
            if "id" in link.attrib:
                line += " id=\"{}\"".format(link.attrib["id"])
            if "media-type" in link.attrib:
                line += " media-type=\"{}\"".format(link.attrib["media-type"])
            if "properties" in link.attrib:
                line += " properties=\"{}\"".format(link.attrib["properties"])
            if "refines" in link.attrib:
                line += " refines=\"{}\"".format(link.attrib["refines"])
            if "rel" in link.attrib:
                line += " rel=\"{}\"".format(link.attrib["rel"])
            line += "/>"

            opf_from_epub.append(line)

        dcterms_modified = str(datetime.datetime.utcnow().isoformat()).split(".")[0] + "Z"

        # Append EPUB-metadata at the end of the metadata we got from Bibliofil
        opf_from_epub.append("")
        opf_from_epub.append("        <meta property=\"dcterms:modified\">{}</meta>".format(dcterms_modified))
        html_from_epub.append("")
        html_from_epub.append("        <meta name=\"dcterms:modified\" content=\"{}\"/>".format(dcterms_modified))

        opf_from_epub.append("    </metadata>")
        opf_from_epub = "\n".join(opf_from_epub)
        opf_metadata = opf_metadata.replace("</metadata>", opf_from_epub)

        html_from_epub.append("    </head>")
        html_from_epub = "\n".join(html_from_epub)
        html_head = html_head.replace("</head>", html_from_epub)

        opf_path = os.path.join(epub.book_path, epub.opf_path())
        if not os.path.exists(opf_path):
            report.error("Klarte ikke å lese OPF-filen. Kanskje EPUBen er zippet?")
            return False

        # Update metadata in OPF by replacing the existing <metadata>…</metadata> with `opf_metadata`

        opf_content = None
        with open(opf_path) as f:
            opf_content = "".join(f.readlines())

        opf_content = (
            opf_content[:opf_content.find("<metadata")].rstrip()
            + "\n"
            + opf_metadata
            + opf_content[opf_content.find("</metadata>") + len("</metadata>"):]
        )

        with open(opf_path, "w") as f:
            f.write(opf_content)

        html_paths = opf_element.xpath("/*/*[local-name()='manifest']/*[@media-type='application/xhtml+xml']/@href")

        for html_relpath in html_paths:
            html_path = os.path.normpath(os.path.join(os.path.dirname(opf_path), html_relpath))

            # Update metadata in HTML by replacing the existing <head>…</head> with `html_head`

            html_content = None
            with open(html_path) as f:
                html_content = "".join(f.readlines())

            html_content = (
                html_content[:html_content.find("<head")].rstrip()
                + "\n"
                + html_head
                + html_content[html_content.find("</head>") + len("</head>"):]
            )

            with open(html_path, "w") as f:
                f.write(html_content)

        epub.refresh_metadata()  # refresh cached metadata in the Epub object

        return True  # success

    @staticmethod
    def bibliofil_record_exists(report, book_id):
        report.debug("Sjekker om Bibliofil inneholder metadata for {}...".format(book_id))

        if len(book_id) > 6:
            book_id = book_id[:6]  # Bibliofil identifiers are always 6 digits long

        sru_url = "http://websok.nlb.no/cgi-bin/sru?version=1.2&operation=searchRetrieve&recordSchema=bibliofilmarcnoholdings&query=bibliofil.tittelnummer="
        sru_url += book_id
        sru_request = Metadata.requests_get(sru_url)
        marcxchange = str(sru_request.content, 'utf-8')

        if "<SRU:numberOfRecords>0</SRU:numberOfRecords>" in marcxchange:
            report.debug("Ingen katalogpost funnet for {}".format(book_id))
            return False

        if re.search(r"<marcxchange:controlfield[^>]*tag=\"000\"[^>]*>[^<]{5}d", marcxchange):
            report.debug("Katalogposten er slettet: {}".format(book_id))
            return False

        report.debug("Boken er tilgjengelig: {}".format(book_id))
        return True

    @staticmethod
    def add_production_info(report, identifier, publication_format=""):
        creative_work = Metadata.get_creative_work_from_api(identifier, report=report)
        identifiers = Metadata.get_identifiers(identifier)

        report.info("<h2>Signaturer</h2>")
        signatures = Metadata.get_signatures_from_quickbase(identifiers, report=report)

        if not signatures:
            report.info("<p>Fant ingen signaturer.</p>")
        else:
            report.info("<dl>")
            already_reported = {}
            for signature in signatures:
                if signature["source-id"] in already_reported and already_reported[signature["source-id"]] == signature["value"]:
                    continue
                else:
                    already_reported[signature["source-id"]] = signature["value"]

                report.info("<dt>{}</dt>".format(signature["source"]))
                report.info("<dd>{}</dd>".format(signature["value"]))
            report.info("</dl>")

        report.info("<h2>Lenker til katalogposter</h2>")
        bibliofil_url = "https://websok.nlb.no/cgi-bin/websok?tnr="
        if creative_work is None:
            report.error("<p>Finner ikke {} i Bibliofil.</p>".format(identifier))
            return
        else:
            report.info("<ul>")
            for edition in creative_work["editions"]:
                report.info("<li><a href=\"{}{}\">{}</a> ({})</li>".format(bibliofil_url, edition["identifier"][:6], edition["identifier"], edition["format"]))
            report.info("</ul>")

        if len(creative_work["editions"]) == 1:
            report.info("<p>Finner ingen andre katalogiserte formater tilhørende denne {}-boka.</p>".format(creative_work["editions"][0]["format"]))

    @staticmethod
    def should_produce(edition_identifier, edition_format, report=logging, skip_metadata_validation=False, use_cache_if_possible=False):
        if edition_identifier.upper().startswith("TEST"):
            report.info("Boknummeret starter med 'TEST'. Boka skal derfor produseres som '{}'.".format(edition_format))
            return True, True

        if not skip_metadata_validation:
            metadata_valid = Metadata.validate_metadata(report, edition_identifier, edition_format)
            if not metadata_valid:
                return False, False

        creative_work = Metadata.get_creative_work_from_api(edition_identifier, report=report, use_cache_if_possible=use_cache_if_possible)
        if not creative_work:
            report.info("Fant ikke metadata for '{}'. Boka skal derfor ikke produseres som '{}'.".format(edition_identifier, edition_format))
            return False, True

        found_but_deleted = False
        for edition in creative_work["editions"]:
            if edition["format"] == edition_format:
                if edition["deleted"]:
                    found_but_deleted = True
                    continue

                report.debug("Metadata exists in Bibliofil ({} is cataloged as the {}-edition of {} through either `596$f` or `599$b`). ".format(
                                edition["identifier"], edition_format, edition_identifier)
                             + "The book should be produced as {}.".format(edition_format))
                return True, True

        if found_but_deleted:
            report.info("Metadata for {} finnes i Bibliofil og er valid, men katalogposten er slettet. "
                        + "Boka skal derfor ikke produseres som '{}'.".format(edition_identifier, edition_format))
            return False, True

        report.info("Fant ikke en '{}'-versjon av '{}'. Boka skal derfor ikke produseres som '{}'.".format(edition_format, edition_identifier, edition_format))
        report.info("'{}' finnes i følgende formater: {}".format(
            edition_identifier,
            ", ".join(["{} ({})".format(edition["identifier"], edition["format"]) for edition in creative_work["editions"]])
        ))
        for suggestion in Metadata.suggest_similar_editions(edition_identifier, edition_format=edition_format, report=report):
            report.info("Forslag til lignende katalogpost som ikke er tilknyttet samme åndsverk: {}: {}".format(
                suggestion["identifier"], suggestion["title"]
            ))
        return False, True

    @staticmethod
    def production_complete(edition_identifier, publication_format, report=logging, use_cache_if_possible=False):
        creative_work = Metadata.get_creative_work_from_api(edition_identifier, report=report, use_cache_if_possible=use_cache_if_possible)

        if not creative_work:
            return False  # no creative work found, assume production is not complete

        found_format = False
        for edition in creative_work["editions"]:
            if edition["format"] == publication_format:
                if edition["available"]:
                    report.info("Boka '{}' ble gjort tilgjengelig for utlån som '{}' i formatet '{}' på datoen '{}'. ".format(
                                    edition_identifier, edition["identifier"], publication_format, edition["available"])
                                + "Boka er derfor ferdig produsert.")
                    return True
                else:
                    report.info("Boka '{}' er katalogisert som '{}' med formatet '{}' men den er ikke markert som klar til utlån. ".format(
                                    edition_identifier, edition["identifier"], publication_format)
                                + "Boka er derfor ikke ferdig produsert.")
                    found_format = True

        if not found_format:
            report.info("Finner ikke en {}-versjon av boka '{}'. Boka er derfor ikke ferdig produsert.".format(publication_format, edition_identifier))
            for suggestion in Metadata.suggest_similar_editions(edition_identifier, edition_format=publication_format, report=report):
                report.info("Forslag til lignende katalogpost som ikke er tilknyttet samme åndsverk: {}: {}".format(
                    suggestion["identifier"], suggestion["title"]
                ))

        return False

    @staticmethod
    def get_metadata_from_book(pipeline, path, force_update=False):
        book_metadata = Metadata._get_metadata_from_book(pipeline, path, force_update)

        # if not explicitly defined in the metadata, assign library based on the identifier
        if "library" not in book_metadata and "identifier" in book_metadata:
            book_metadata["library"] = Metadata.get_library_from_identifier(book_metadata["identifier"], report=pipeline.utils.report)

        return book_metadata

    @staticmethod
    def get_library_from_identifier(identifier, report=logging):
        library = None
        if identifier[:2] in ["85", "86", "87", "88"]:
            library = "StatPed"
        elif identifier[:2] in ["80", "81", "82", "83", "84"]:
            library = "KABB"
        else:
            library = "NLB"

        report.info("Velger '{}' som bibliotek basert på boknummer: {}".format(library, identifier))

        return library

    @staticmethod
    def _get_metadata_from_book(pipeline, path, force_update):
        # Initialize book_metadata with the identifier based on the filename
        book_metadata = {
            "identifier": re.sub(r"\.[^\.]*$", "", os.path.basename(path))
        }

        # if there's no "/" in the path, then we assume it's a filename,
        # and we just return the filename as the identifier.
        if "/" not in path:
            return book_metadata

        with Metadata._cache_update_lock:
            # remove old metadata from cache
            if not Metadata.metadata_cache:
                Metadata.metadata_cache = {}
            for p in list(Metadata.metadata_cache.keys()):
                if time.time() - Metadata.metadata_cache[p]["cache_time"] > 3600:
                    del Metadata.metadata_cache[p]
            if force_update and path in Metadata.metadata_cache:
                del Metadata.metadata_cache[path]

            # return cached metadata if cached metadata is not old
            if path in Metadata.metadata_cache:
                return Metadata.metadata_cache[path]["metadata"]

        # Try getting EPUB metadata
        if os.path.exists(path):
            epub = Epub(pipeline, path)
            if epub.isepub(report_errors=False):
                book_metadata["identifier"] = epub.identifier()
                book_metadata["title"] = epub.meta("dc:title")
                with Metadata._cache_update_lock:
                    Metadata.metadata_cache[path] = {
                        "cache_time": time.time(),
                        "metadata": book_metadata
                    }
                    return book_metadata

        # Try getting HTML or DAISY 2.02 metadata
        html_files = []
        for root, dirs, files in os.walk(path):
            for file in files:
                if file.endswith("html"):
                    html_files.append(os.path.join(root, file))

        # Try getting DTBook metadata
        xml_files = []
        for root, dirs, files in os.walk(path):
            for file in files:
                if file.endswith(".xml"):
                    xml_files.append(os.path.join(root, file))

        # Try getting PEF metadata
        pef_files = []
        for root, dirs, files in os.walk(path):
            for file in files:
                if file.endswith(".pef"):
                    pef_files.append(os.path.join(root, file))

        if (os.path.isfile(os.path.join(path, "ncc.html"))
                or os.path.isfile(os.path.join(path, "metadata.html"))
                or len(html_files)):
            file = os.path.join(path, "ncc.html")
            if not os.path.isfile(file):
                file = os.path.join(path, "metadata.html")
            if not os.path.isfile(file):
                file = os.path.join(path, os.path.basename(path) + ".xhtml")
            if not os.path.isfile(file):
                file = os.path.join(path, os.path.basename(path) + ".html")
            if not os.path.isfile(file):
                file = [f for f in html_files if re.match(r"^\d+\.x?html$", os.path.basename(f))]
                if len(file) > 0:
                    file = file[0]
            if not file:
                file = html_files[0]

            html = ElementTree.parse(file).getroot()
            head = html.xpath("/*[local-name()='head']") + html.xpath("/*/*[local-name()='head']")
            head = head[0] if head else None
            if head is not None:
                book_title = [e.text for e in head.xpath(
                    "/*/*[local-name()='head']/*[local-name()='title']")]
                book_title = book_title[0] if book_title else None
                book_identifier = [e.attrib["content"] for e in head.xpath(
                    "/*/*[local-name()='head']/*[local-name()='meta' and @name='dc:identifier']") if "content" in e.attrib]
                book_identifier = book_identifier[0] if book_identifier else None

            if book_title:
                book_metadata["title"] = book_title
            if book_identifier:
                book_metadata["identifier"] = book_identifier

        elif len(xml_files) > 0:
            dtbook = None
            for file in xml_files:
                xml = ElementTree.parse(file).getroot()
                if xml.xpath("namespace-uri()") == "http://www.daisy.org/z3986/2005/dtbook/":
                    dtbook = xml
                    break

            if dtbook is not None:
                head = dtbook.xpath("/*[local-name()='head']") + dtbook.xpath("/*/*[local-name()='head']")
                head = head[0] if head else None
                if head is not None:
                    book_title = [e.attrib["content"] for e in head.xpath(
                        "/*/*[local-name()='head']/*[local-name()='meta' and @name='dc:Title']") if "content" in e.attrib]
                    book_title = book_title[0] if book_title else None
                    book_identifier = [e.attrib["content"] for e in head.xpath(
                        "/*/*[local-name()='head']/*[local-name()='meta' and @name='dc:Identifier']") if "content" in e.attrib]
                    book_identifier = book_identifier[0] if book_identifier else None

                if book_title:
                    book_metadata["title"] = book_title
                if book_identifier:
                    book_metadata["identifier"] = book_identifier

        elif len(pef_files) > 0:
            pef = None
            nsmap = {
                'pef': 'http://www.daisy.org/ns/2008/pef',
                'dc': 'http://purl.org/dc/elements/1.1/',
                'nlb': 'http://www.nlb.no/ns/pipeline/xproc'
            }
            for file in pef_files:
                xml = ElementTree.parse(file).getroot()
                if xml.xpath("namespace-uri()") == nsmap["pef"]:
                    pef = xml
                    break

            if pef is not None:
                head = pef.xpath("/*/pef:head/pef:meta", namespaces=nsmap)
                head = head[0] if head else None
                if head is not None:
                    book_title = [e.text for e in head.xpath("dc:title", namespaces=nsmap)]
                    book_title = book_title[0] if book_title else None
                    book_identifier = [e.text for e in head.xpath("dc:identifier", namespaces=nsmap)]
                    book_identifier = book_identifier[0] if (book_identifier and re.match(r"^(TEST)?\d+$", book_identifier[0])) else None

                    for e in head.xpath("/*/pef:head/dc:*", namespaces=nsmap):
                        name = e.xpath("name()", namespaces=nsmap)
                        value = e.text
                        if ":" in name:
                            book_metadata[name] = value

                if book_title:
                    book_metadata["title"] = book_title
                if book_identifier:
                    book_metadata["identifier"] = book_identifier

        with Metadata._cache_update_lock:
            Metadata.metadata_cache[path] = {
                "cache_time": time.time(),
                "metadata": book_metadata
            }
        return book_metadata

    @staticmethod
    def pipeline_book_shortname(pipeline):
        name = pipeline.book["name"] if pipeline.book else ""

        if pipeline.book and pipeline.book["source"]:
            book_metadata = Metadata.get_metadata_from_book(pipeline, pipeline.book["source"])
            if "title" in book_metadata:
                name += ": " + book_metadata["title"][:25] + ("…" if len(book_metadata["title"]) > 25 else "")

        return name

    @staticmethod
    def get_signatures_from_quickbase(edition_identifiers, library=None, report=logging):
        if not edition_identifiers:
            return []

        if library is None:
            library = Metadata.get_library_from_identifier(edition_identifiers[0])

        bookguru_dumps = [
            {
                "path": os.getenv("QUICKBASE_RECORDS_PATH_NLB", "/opt/quickbase/records.xml"),
                "id-rows": ["13", "20", "24", "28", "31", "32", "38"],
            },
            {
                "path": os.getenv("QUICKBASE_RECORDS_PATH_STATPED", "/opt/quickbase/records-statped.xml"),
                "id-rows": ["13", "24", "28", "32", "500"],
            },
        ]

        # try the statped dump first, if library is "StatPed"
        if library.lower() == "statped":
            bookguru_dumps = list(reversed(bookguru_dumps))

        sources = {
            "314": "Signatur etterarbeid DAISY 2.02",
            "315": "Signatur etterarbeid DAISY 2.02 TTS",
            "316": "Signatur etterarbeid punktskrift",
            "317": "Signatur etterarbeid E-bok",
            "321": "Signatur etterarbeid punktklubb",
            "323": "Signatur tilrettelegging",
            "324": "Signatur DAISY 2.02 klargjort for utlån",
            "325": "Signatur E-bok klargjort for utlån",
            "326": "Signatur punktskrift klargjort for utlån",
            "329": "Signatur punktklubb klargjort for utån",
            "344": "Signatur DTBook bestilt",
            "353": "Signatur etterarbeid ekstern produksjon",
            "360": "Signatur levert innleser",
            "377": "Signatur taktilt trykk ferdig produsert",
            "378": "Signatur taktilt trykk klar for utlån",
            "418": "Signatur for nedlasting",
            "426": "Signatur godkjent produksjon",
            "427": "Signatur returnert produksjon",
            "436": "Signatur honorering",
            "437": "Signatur registrering",
            "465": "Signatur for påbegynt etterarbeid",
            "468": "Signatur honorarkrav behandlet",
            "489": "Signatur kontroll påbegynt",
        }
        sources_xpath_filter = " or ".join(["@id = '{}'".format(s) for s in sources])

        with Metadata._signatures_cachelock:
            if time.time() - Metadata.signatures_last_update > 3600:
                Metadata.signatures_cache = {}

                for dump in bookguru_dumps:
                    Metadata.signatures_cache[dump["path"]] = {}

                    if not os.path.isfile(dump["path"]):
                        report.warning("Quickbase-dump finnes ikke. Kan ikke hente ut e-postsignaturer: {}")
                        report.debug("Quickbase-dump path: {}".format(dump["path"]))
                        continue

                    report.debug("Updating signatures cache from: {}".format(dump["path"]))

                    lusers = {}
                    id_xpath_filter = " or ".join(["@id = '{}'".format(i) for i in dump["id-rows"]])
                    f = open(dump["path"], "rb")
                    context = ElementTree.iterparse(f)  # use a streaming parser for big XML files

                    for action, elem in context:
                        if elem.tag == "lusers":
                            for luser in elem.xpath("luser"):
                                lusers[luser.get("id")] = luser.text

                        if elem.tag != "record":
                            continue

                        identifiers = elem.xpath(f"*[{id_xpath_filter}]/text()")

                        signatures = []
                        for signature in elem.xpath(f"*[{sources_xpath_filter}]"):
                            luser = signature.text
                            if luser and luser in lusers and lusers[luser]:
                                signatures.append({
                                    "source-id": signature.get("id"),
                                    "source": sources[signature.get("id")],
                                    "value": lusers[luser]
                                })
                        for identifier in identifiers:
                            Metadata.signatures_cache[dump["path"]][identifier] = signatures

                Metadata.signatures_last_update = time.time()

            for dump in bookguru_dumps:
                # iterate in order of `bookguru_dumps`, which means Statped gets checked first
                # when library=StatPed, and NLB gets checked first when library=NLB
                for identifier in Metadata.signatures_cache[dump["path"]]:
                    if identifier in edition_identifiers:
                        return Metadata.signatures_cache[dump["path"]][identifier]

        return []

    @staticmethod
    def get_cataloging_signature_from_quickbase(identifiers, report=logging):
        signatures = Metadata.get_signatures_from_quickbase(identifiers, report=report)

        for signature in signatures:
            if signature["source-id"] == "437":
                return signature["value"]

        return None

    @staticmethod
    def refresh_creative_work_cache_if_necessary(report=logging):
        with Metadata._creative_works_cachelock:
            if time.time() - Metadata.creative_works_last_update > 3600:
                creative_works_url = Config.get("nlb_api_url") + "/creative-works?limit=-1&editions-metadata=simple"
                response = requests.get(creative_works_url)

                if response.status_code == 200:
                    Metadata.creative_works = response.json()["data"]
                    Metadata.creative_works_last_update = time.time()

                else:
                    report.debug("Could not update creative works metadata from: {}".format(creative_works_url))


    @staticmethod
    def get_creative_work_from_cache(edition_identifier, report=logging):
        Metadata.refresh_creative_work_cache_if_necessary(report=report)

        with Metadata._creative_works_cachelock:
            for cw in Metadata.creative_works:
                for edition in cw["editions"]:
                    if (
                        edition["identifier"] == edition_identifier
                        or edition["identifier"] == edition_identifier[:6]  # …since the API doesn't fully support longer edition identifiers yet
                    ):
                        return cw

        report.debug("{} was not found in cache".format(edition_identifier))
        return None

    @staticmethod
    def suggest_similar_editions(edition_identifier, edition_format=None, limit=10, report=logging):
        Metadata.refresh_creative_work_cache_if_necessary(report=report)

        creative_work = Metadata.get_creative_work_from_cache(edition_identifier, report=report)

        if not creative_work:
            report.debug("Creative work could not be found in the cache, unable to determine the title of the work.")
            return []

        if not isinstance(creative_work["title"], str):
            report.debug("Creative work title is not a string, unable to search for similar titles.")
            return []

        matches = []
        with Metadata._creative_works_cachelock:
            for cw in Metadata.creative_works:
                if not isinstance(cw["title"], str):
                    continue

                ratio = SequenceMatcher(a=creative_work["title"], b=cw["title"]).ratio()
                if ratio > 0.9:
                    for e in cw["editions"]:
                        if e["format"] == edition_format or edition_format is None:
                            matches.append((ratio,
                                            {
                                                "identifier": e["identifier"],
                                                "title": cw["title"],
                                                "format": e["format"]
                                            }))
        matches = sorted(matches, key=lambda match: match[0])
        matches = [match[1] for match in matches]
        matches = matches[:limit]

        return matches
