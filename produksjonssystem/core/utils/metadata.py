import datetime
import logging
import os
import re
import shutil
import tempfile
import threading
import time
import zipfile

import requests
from lxml import etree as ElementTree

from core.config import Config
from core.utils.epub import Epub
from core.utils.filesystem import Filesystem
from core.utils.report import Report
from core.utils.schematron import Schematron
from core.utils.xslt import Xslt


class Metadata:
    uid = "core-utils-metadata"
    title = "Metadata"

    formats = ["EPUB", "DAISY 2.02", "XHTML", "Braille"]  # values used in dc:format

    max_update_interval = 60 * 30  # half hour
    max_metadata_emails_per_day = 5

    quickbase_id_rows = {
        "records": ["13", "20", "24", "28", "31", "32", "38"],
        "records-statped": ["13", "24", "28", "32", "500"],
        "isbn": ["7"],
        "isbn-statped": ["7"]
    }
    sources = {
        "quickbase": {
            "records": "/opt/quickbase/records.xml",
            "records-statped": "/opt/quickbase/records-statped.xml",
            "isbn": "/opt/quickbase/isbn.xml",
            "isbn-statped": "/opt/quickbase/isbn-statped.xml",
            "last_updated": 0
        },
        "bibliofil": {}
    }
    original_isbn = None
    original_isbn_last_update = 0
    _original_isbn_lock = threading.RLock()

    queue = []
    last_validation_results = {}
    last_metadata_errors = []  # timestamps for last automated metadata updates
    metadata_tempdir_obj = None

    _update_lock = threading.RLock()

    metadata_cache = {}
    _cache_update_lock = threading.RLock()

    @staticmethod
    def get_metadata_dir():
        if not Config.get("metadata_dir"):
            Metadata.metadata_tempdir_obj = tempfile.TemporaryDirectory(prefix="metadata-")
            logging.info("Using temporary directory for metadata: " + Metadata.metadata_tempdir_obj.name)
            Config.set("metadata_dir", Metadata.metadata_tempdir_obj.name)

        return Config.get("metadata_dir")

    @staticmethod
    def update(*args, **kwargs):
        # Only update one book at a time, to avoid potentially overwriting metadata while it's being used

        ret = False
        with Metadata._update_lock:
            ret = Metadata._update(*args, **kwargs)
            Metadata.queue = []
        return ret

    @staticmethod
    def get_metadata(*args, **kwargs):
        # Only get metadata from one book at a time, to avoid potentially overwriting metadata while it's being used

        ret = False
        with Metadata._update_lock:
            ret = Metadata._get_metadata(*args, **kwargs)
            Metadata.queue = []
        return ret

    @staticmethod
    def validate_metadata(*args, **kwargs):
        # Only get metadata from one book at a time, to avoid potentially overwriting metadata while it's being used

        ret = False
        with Metadata._update_lock:
            ret = Metadata._validate_metadata(*args, **kwargs)
            Metadata.queue = []
        return ret

    @staticmethod
    def get_identifiers(report, epub_edition_identifier):
        report.debug("Finner boknummer for {}...".format(epub_edition_identifier))
        edition_identifier = epub_edition_identifier
        pub_identifier = edition_identifier
        if len(pub_identifier) > 6:
            pub_identifier = pub_identifier[:6]
            report.debug("Boknummer for selve utgaven er (seks første siffer): {}".format(pub_identifier))

        edition_identifiers = [edition_identifier]
        publication_identifiers = [pub_identifier]
        edition_identifiers, publication_identifiers = Metadata.get_quickbase_identifiers(report, edition_identifiers, publication_identifiers)
        edition_identifiers, publication_identifiers = Metadata.get_bibliofil_identifiers(report, edition_identifiers, publication_identifiers)

        return sorted(edition_identifiers), sorted(publication_identifiers)

    @staticmethod
    def get_quickbase_identifiers(report, edition_identifiers, publication_identifiers):
        quickbase_edition_identifiers = []
        for edition_identifier in edition_identifiers:
            report.debug("Finner andre boknummer for {} i Quickbase...".format(edition_identifier))
            metadata_dir = os.path.join(Metadata.get_metadata_dir(), edition_identifier)
            for library in [None, "statped"]:
                rdf_path = os.path.join(metadata_dir, 'quickbase/record{}.rdf'.format("-"+library if library else ""))
                if os.path.isfile(rdf_path):
                    rdf = ElementTree.parse(rdf_path).getroot()
                    identifiers = rdf.xpath("//nlbprod:*[starts-with(local-name(),'identifier.')]", namespaces=rdf.nsmap)
                    identifiers = [e.text for e in identifiers if re.match("^[\dA-Za-z._-]+$", e.text)]
                    quickbase_edition_identifiers.extend(identifiers)
                    if identifiers:
                        report.debug("Andre boknummer for {} i {}-Quickbase: {}".format(edition_identifier,
                                                                                        library if library else "NLB",
                                                                                        ", ".join(identifiers)))
                    else:
                        report.warn("{} er ikke katalogisert i {}-Quickbase.".format(edition_identifier, library if library else "NLB"))
                else:
                    report.warn("Finner ikke lokal metadata for {} i {}-Quickbase.".format(edition_identifier, library if library else "NLB"))

        edition_identifiers = sorted(set(edition_identifiers + quickbase_edition_identifiers))
        publication_identifiers = sorted(set([i[:6] for i in edition_identifiers if len(i) >= 6]))
        return edition_identifiers, publication_identifiers

    @staticmethod
    def is_in_quickbase(report, identifiers):
        if isinstance(identifiers, str):
            identifiers = [identifiers]
        metadata_dir_exists = False
        for identifier in identifiers:
            report.info("Ser etter {} i Quickbase...".format(identifier))
            metadata_dir = os.path.join(Metadata.get_metadata_dir(), identifier)
            rdf_paths = [os.path.join(metadata_dir, 'quickbase/record{}.rdf'.format("-"+library if library else "")) for library in [None, "statped"]]
            if os.path.isdir(metadata_dir):
                metadata_dir_exists = True
            else:
                continue
            found_rdf_file = False
            identifiers = []
            for rdf_path in rdf_paths:
                if os.path.isfile(rdf_path):
                    found_rdf_file = True
                    rdf = ElementTree.parse(rdf_path).getroot()
                    identifiers.append(rdf.xpath("//nlbprod:*[starts-with(local-name(),'identifier.')]", namespaces=rdf.nsmap))
            if not found_rdf_file:
                report.info("Finner ikke Quickbase-metadata for {}.".format(identifier))
            elif identifiers:
                report.info("{} finnes i Quickbase".format(identifier))
                return True
            else:
                report.info("{} finnes ikke i Quickbase".format(identifier))
        return True if not metadata_dir_exists else False

    @staticmethod
    def get_bibliofil_identifiers(report, edition_identifiers, publication_identifiers):
        with Metadata._original_isbn_lock:
            # Find book IDs with the same ISBN in *596$f (input is "bookId,isbn" CSV dump)
            Metadata.original_isbn_csv = str(os.path.normpath(os.environ.get("ORIGINAL_ISBN_CSV"))) if os.environ.get("ORIGINAL_ISBN_CSV") else None
            if not Metadata.original_isbn or time.time() - Metadata.original_isbn_last_update > 600:
                report.debug("Oppdaterer oversikt over ISBN fra {}...".format(Metadata.original_isbn_csv))
                Metadata.original_isbn_last_update = time.time()
                Metadata.original_isbn = {}
                if Metadata.original_isbn_csv and os.path.isfile(Metadata.original_isbn_csv):
                    with open(Metadata.original_isbn_csv) as f:
                        for line in f:
                            line_split = line.split(",")
                            if len(line_split) == 1:
                                report.warn("'{}' mangler ISBN og format".format(line_split[0]))
                                continue
                            elif len(line_split) == 2:
                                report.warn("'{}' ({}) mangler format".format(line_split[0], line_split[1]))
                                continue
                            b = line_split[0]                             # book id
                            i = line_split[1].strip()                     # isbn
                            i_normalized = re.sub(r"[^\d]", "", i)
                            f = sorted(list(set(line_split[2].split())))  # formats
                            fmt = " ".join(f)
                            if i_normalized not in Metadata.original_isbn:
                                Metadata.original_isbn[i_normalized] = {"pretty": i, "books": {}}

                            for old_fmt in Metadata.original_isbn[i_normalized]["books"]:
                                if len([val for val in old_fmt.split() if val in f]):
                                    # same format; rename dict key
                                    f = sorted(list(set(f + [b])))
                                    fmt = " ".join(f)
                                    if fmt in Metadata.original_isbn[i_normalized]["books"]:
                                        Metadata.original_isbn[i_normalized]["books"][old_fmt] += Metadata.original_isbn[i_normalized]["books"][fmt]
                                    Metadata.original_isbn[i_normalized]["books"][fmt] = Metadata.original_isbn[i_normalized]["books"].pop(old_fmt)

                            if fmt not in Metadata.original_isbn[i_normalized]["books"]:
                                Metadata.original_isbn[i_normalized]["books"][fmt] = []
                            Metadata.original_isbn[i_normalized]["books"][fmt].append(b)
                            Metadata.original_isbn[i_normalized]["books"][fmt] = sorted(list(set(Metadata.original_isbn[i_normalized]["books"][fmt])))
            if not Metadata.original_isbn_csv or not os.path.isfile(Metadata.original_isbn_csv):
                report.warn("Finner ikke liste over boknummer og ISBN fra `*596$f` (\"{}\")".format(Metadata.original_isbn_csv))
                return edition_identifiers, publication_identifiers

            report.debug("Leter etter bøker med samme ISBN som {} i {}...".format("/".join(edition_identifiers), Metadata.original_isbn_csv))
            for i in Metadata.original_isbn:
                data = Metadata.original_isbn[i]
                match = True in [bool(set(edition_identifiers) & set(data["books"][book_format])) or
                                 bool(set(publication_identifiers) & set(data["books"][book_format]))
                                 for book_format in data["books"]]
                if not match:
                    continue
                for fmt in data["books"]:
                    if len(data["books"][fmt]) > 1:
                        ignored = [val for val in data["books"][fmt] if val not in edition_identifiers and val not in publication_identifiers]
                        report.warn("Det er flere bøker med samme original-ISBN/ISSN og samme format: {}".format(", ".join(data["books"][fmt])))
                        if len(ignored):
                            report.warn("Følgende bøker blir ikke behandlet: {}".format(", ".join(ignored)))
                        continue
                    else:
                        fmt_bookid = data["books"][fmt][0]
                        if fmt_bookid not in publication_identifiers and fmt_bookid not in edition_identifiers:
                            report.info("{} har samme ISBN/ISSN i `*596$f` som {}".format(
                                fmt_bookid,
                                ("en av: " if len(edition_identifiers) >= 2 else "") +
                                "/".join(edition_identifiers)))
                            report.info("Legger til {} som utgave".format(fmt_bookid))
                            edition_identifiers.append(fmt_bookid)
                            publication_identifiers.append(fmt_bookid[:6])

            return sorted(set(edition_identifiers)), sorted(set(publication_identifiers))

    @staticmethod
    def _update(pipeline, epub, publication_format="", insert=True, force_update=False):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only read and update metadata from EPUBs")
            return False

        # make a queue for plotting purposes
        queue_book = {}
        queue_book["name"] = epub.identifier()
        queue_book["source"] = os.path.join(Metadata.get_metadata_dir(), queue_book["name"])
        queue_book["events"] = ["autotriggered"]
        queue_book["last_event"] = int(time.time())
        Metadata.queue = [queue_book]

        last_updated = 0
        last_updated_path = os.path.join(Metadata.get_metadata_dir(), epub.identifier(), "last_updated")
        if os.path.exists(last_updated_path):
            with open(last_updated_path, "r") as last_updated_file:
                try:
                    last = int(last_updated_file.readline().strip())
                    last_updated = last
                except Exception:
                    logging.exception("Could not parse " + last_updated_path)

        # Get updated metadata for a book, but only if the metadata is older than max_update_interval minutes
        now = int(time.time())
        if now - last_updated > Metadata.max_update_interval or force_update:
            success = Metadata.get_metadata(pipeline, epub, publication_format=publication_format)
            if epub.identifier() in Metadata.last_validation_results:
                del Metadata.last_validation_results[epub.identifier()]
            if not success:
                pipeline.utils.report.error("Klarte ikke å hente metadata")
                return False

        # If metadata has changed; re-validate the metadata
        if not epub.identifier() in Metadata.last_validation_results:
            Metadata.last_validation_results[epub.identifier()] = Metadata.validate_metadata(pipeline, epub, publication_format=publication_format)

        if not Metadata.last_validation_results[epub.identifier()]:
            pipeline.utils.report.error("Metadata er ikke valide")
            return False  # metadata is not valid

        if insert:
            # Return whether or not insertion of metadata was successful
            return Metadata.insert_metadata(pipeline, epub, publication_format=publication_format)
        else:
            return True  # metadata is valid

    @staticmethod
    def _get_metadata(pipeline, epub, publication_format=""):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only read metadata from EPUBs")
            return False

        # get path to OPF in EPUB (unzip if necessary)
        opf = epub.opf_path()
        opf_obj = None  # if tempfile is needed
        opf_path = None
        if os.path.isdir(epub.book_path):
            opf_path = os.path.join(epub.book_path, opf)
        else:
            opf_obj = tempfile.NamedTemporaryFile()
            with zipfile.ZipFile(epub.book_path, 'r') as archive, open(opf_obj.name, "wb") as opf_file:
                opf_file.write(archive.read(opf))
            opf_path = opf_obj.name

        # Publication and edition identifiers are the same except for periodicals
        edition_identifier = epub.identifier()
        pub_identifier = edition_identifier
        if len(pub_identifier) > 6:
            pub_identifier = pub_identifier[:6]

        # path to directory with metadata from Quickbase / Bibliofil / Bokbasen
        metadata_dir = os.path.join(Metadata.get_metadata_dir(), edition_identifier)
        pipeline.utils.report.attachment(None, metadata_dir, "DEBUG")
        os.makedirs(metadata_dir, exist_ok=True)
        os.makedirs(metadata_dir + '/quickbase', exist_ok=True)
        os.makedirs(metadata_dir + '/bibliofil', exist_ok=True)
        os.makedirs(metadata_dir + '/epub', exist_ok=True)

        with open(os.path.join(metadata_dir, "last_updated"), "w") as last_updated:
            last_updated.write(str(int(time.time())))

        rdf_files = []

        if not os.path.exists(opf_path):
            pipeline.utils.report.error("Klarte ikke å lese OPF-filen.")
            return False

        md5_before = []
        metadata_paths = []
        for f in os.listdir(metadata_dir):
            path = os.path.join(metadata_dir, f)
            if os.path.isfile(path) and (f.endswith(".opf") or f.endswith(".html")):
                metadata_paths.append(path)
        metadata_paths.sort()
        for path in metadata_paths:
            md5_before.append(Filesystem.file_content_md5(path))

        # ========== Collect metadata from sources ==========

        pipeline.utils.report.debug("nlbpub-opf-to-rdf.xsl")
        rdf_path = os.path.join(metadata_dir, 'epub/opf.rdf')
        pipeline.utils.report.debug("    source = " + opf_path)
        pipeline.utils.report.debug("    target = " + rdf_path)
        xslt = Xslt(pipeline,
                    stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "nlbpub-opf-to-rdf.xsl"),
                    source=opf_path,
                    target=rdf_path,
                    parameters={"include-source-reference": "true"})
        if not xslt.success:
            return False
        rdf_files.append('epub/' + os.path.basename(rdf_path))

        for library in [None, "statped"]:
            pipeline.utils.report.debug("quickbase-record-to-rdf.xsl (RDF/A)")
            pipeline.utils.report.debug("    source = " + os.path.join(metadata_dir, 'quickbase/record{}.xml'.format("-"+library if library else "")))
            pipeline.utils.report.debug("    target = " + os.path.join(metadata_dir, 'quickbase/record{}.html'.format("-"+library if library else "")))
            success = Metadata.get_quickbase(pipeline, "records", edition_identifier,
                                             os.path.join(metadata_dir, 'quickbase/record{}.xml'.format("-"+library if library else "")), library=library)
            if not success:
                return False
            xslt = Xslt(pipeline,
                        stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "bookguru", "quickbase-record-to-rdf.xsl"),
                        source=os.path.join(metadata_dir, 'quickbase/record{}.xml'.format("-"+library if library else "")),
                        target=os.path.join(metadata_dir, 'quickbase/record{}.html'.format("-"+library if library else "")),
                        parameters={"output-rdfa": "true", "include-source-reference": "true"})
            if not xslt.success:
                return False
            pipeline.utils.report.debug("quickbase-record-to-rdf.xsl (RDF/XML)")
            rdf_path = os.path.join(metadata_dir, 'quickbase/record{}.rdf'.format("-"+library if library else ""))
            pipeline.utils.report.debug("    source = " + os.path.join(metadata_dir, 'quickbase/record{}.xml'.format("-"+library if library else "")))
            pipeline.utils.report.debug("    target = " + rdf_path)
            xslt = Xslt(pipeline,
                        stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "bookguru", "quickbase-record-to-rdf.xsl"),
                        source=os.path.join(metadata_dir, 'quickbase/record{}.xml'.format("-"+library if library else "")),
                        target=rdf_path,
                        parameters={"include-source-reference": "true"})
            if not xslt.success:
                return False
            rdf_files.append('quickbase/' + os.path.basename(rdf_path))

        identifiers, publication_identifiers = Metadata.get_quickbase_identifiers(pipeline.utils.report, [edition_identifier], [pub_identifier])
        identifiers, publication_identifiers = Metadata.get_bibliofil_identifiers(pipeline.utils.report, identifiers, publication_identifiers)

        for format_edition_identifier in identifiers:
            format_pub_identifier = format_edition_identifier
            if len(format_pub_identifier) > 6:
                format_pub_identifier = format_pub_identifier[:6]

            pipeline.utils.report.debug("normarc/marcxchange-to-opf.xsl")
            marcxchange_path = os.path.join(metadata_dir, 'bibliofil/' + format_pub_identifier + '.xml')
            current_opf_path = os.path.join(metadata_dir, 'bibliofil/' + format_pub_identifier + '.opf')
            html_path = os.path.join(metadata_dir, 'bibliofil/' + format_pub_identifier + '.html')
            rdf_path = os.path.join(metadata_dir, 'bibliofil/' + format_pub_identifier + '.rdf')

            pipeline.utils.report.debug("    source = " + marcxchange_path)
            pipeline.utils.report.debug("    target = " + current_opf_path)
            Metadata.get_bibliofil(pipeline, format_pub_identifier, marcxchange_path)
            xslt = Xslt(pipeline,
                        stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "normarc/marcxchange-to-opf.xsl"),
                        source=marcxchange_path,
                        target=current_opf_path,
                        parameters={
                          "nested": "true",
                          "include-source-reference": "true",
                          "identifier": format_edition_identifier
                        })
            if not xslt.success:
                return False
            pipeline.utils.report.debug("normarc/bibliofil-to-rdf.xsl")
            pipeline.utils.report.debug("    source = " + current_opf_path)
            pipeline.utils.report.debug("    target = " + html_path)
            pipeline.utils.report.debug("    rdf    = " + rdf_path)
            xslt = Xslt(pipeline,
                        stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "normarc/bibliofil-to-rdf.xsl"),
                        source=current_opf_path,
                        target=html_path,
                        parameters={"rdf-xml-path": rdf_path})
            if not xslt.success:
                return False
            rdf_files.append('bibliofil/' + os.path.basename(rdf_path))

            for library in [None, "statped"]:
                pipeline.utils.report.debug("quickbase-isbn-to-rdf.xsl (RDF/A)")
                pipeline.utils.report.debug("    source = " + os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '{}.xml'.format(
                                                                               "-"+library if library else "")))
                pipeline.utils.report.debug("    target = " + os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '{}.html'.format(
                                                                               "-"+library if library else "")))
                success = Metadata.get_quickbase(pipeline, "isbn", format_edition_identifier,
                                                 os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '{}.xml'.format(
                                                     "-"+library if library else "")),
                                                 library=library)
                if not success:
                    return False
                xslt = Xslt(pipeline,
                            stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "bookguru", "quickbase-isbn-to-rdf.xsl"),
                            source=os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '{}.xml'.format("-"+library if library else "")),
                            target=os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '{}.html'.format("-"+library if library else "")),
                            parameters={"output-rdfa": "true", "include-source-reference": "true"})
                if not xslt.success:
                    return False
                pipeline.utils.report.debug("quickbase-isbn-to-rdf.xsl (RDF/XML)")
                rdf_path = os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '{}.rdf'.format("-"+library if library else ""))
                pipeline.utils.report.debug("    source = " + os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '{}.xml'.format(
                                                                                                                "-"+library if library else "")))
                pipeline.utils.report.debug("    target = " + rdf_path)
                xslt = Xslt(pipeline,
                            stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "bookguru", "quickbase-isbn-to-rdf.xsl"),
                            source=os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '{}.xml'.format(
                                                                                                                "-"+library if library else "")),
                            target=rdf_path,
                            parameters={"include-source-reference": "true"})
                if not xslt.success:
                    return False
                rdf_files.append('quickbase/' + os.path.basename(rdf_path))

        # ========== Combine metadata ==========

        rdf_metadata = os.path.join(metadata_dir, "metadata.rdf")
        opf_metadata = {"": rdf_metadata.replace(".rdf", ".opf")}
        html_metadata = {"": rdf_metadata.replace(".rdf", ".html")}

        for f in Metadata.formats:
            format_id = re.sub(r"[^a-z0-9]", "", f.lower())
            opf_metadata[f] = os.path.join(metadata_dir, "metadata-{}.opf".format(format_id))
            html_metadata[f] = opf_metadata[f].replace(".opf", ".html")

        pipeline.utils.report.debug("rdf-join.xsl")
        pipeline.utils.report.debug("    metadata-dir = " + metadata_dir + "/")
        pipeline.utils.report.debug("    rdf-files    = " + " ".join(rdf_files))
        pipeline.utils.report.debug("    target       = " + rdf_metadata)
        xslt = Xslt(pipeline,
                    stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "rdf-join.xsl"),
                    template="main",
                    target=rdf_metadata,
                    parameters={
                        "metadata-dir": metadata_dir + "/",
                        "rdf-files": " ".join(rdf_files)
                    })
        if not xslt.success:
            return False

        # ========== Enrich dc:language information ==========

        temp_rdf_file_obj = tempfile.NamedTemporaryFile()
        temp_rdf_file = temp_rdf_file_obj.name

        pipeline.utils.report.debug("iso-639.xsl")
        pipeline.utils.report.debug("    source    = " + rdf_metadata)
        pipeline.utils.report.debug("    target       = " + temp_rdf_file)
        xslt = Xslt(pipeline,
                    stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "normarc", "iso-639.xsl"),
                    source=rdf_metadata,
                    target=temp_rdf_file)
        if not xslt.success:
            return False
        shutil.copy(temp_rdf_file, rdf_metadata)

        # ========== Convert to OPF ==========

        xslt_success = True
        for f in opf_metadata:
            pipeline.utils.report.debug("rdf-to-opf.xsl")
            pipeline.utils.report.debug("    source = " + rdf_metadata)
            pipeline.utils.report.debug("    target = " + opf_metadata[f])
            xslt = Xslt(pipeline,
                        stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "rdf-to-opf.xsl"),
                        source=rdf_metadata,
                        target=opf_metadata[f],
                        parameters={
                            "format": f,
                            "update-identifier": "true"
                        })

            if not xslt.success:
                xslt_success = False

            xml = ElementTree.parse(opf_metadata[f]).getroot()
            if not xml.xpath("/*[local-name()='metadata']/*[name()='dc:identifier']"):
                pipeline.utils.report.warn("Ingen boknummer for {}. Kan ikke klargjøre metadata for dette formatet.".format(f))
                os.remove(opf_metadata[f])
                if os.path.isfile(html_metadata[f]):
                    os.remove(html_metadata[f])
                continue

            pipeline.utils.report.debug("opf-to-html.xsl")
            pipeline.utils.report.debug("    source = " + opf_metadata[f])
            pipeline.utils.report.debug("    target = " + html_metadata[f])
            xslt = Xslt(pipeline,
                        stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "opf-to-html.xsl"),
                        source=opf_metadata[f],
                        target=html_metadata[f])
            if not xslt.success:
                xslt_success = False

        if not xslt_success:
            return False

        # ========== Validate metadata ==========

        if not Metadata.validate_metadata(pipeline, epub, publication_format=publication_format):
            return False

        # ========== Trigger conversions if necessary ==========

        md5_after = []
        metadata_paths = []
        for f in os.listdir(metadata_dir):
            path = os.path.join(metadata_dir, f)
            if os.path.isfile(path) and (f.endswith(".opf") or f.endswith(".html")):
                metadata_paths.append(path)
        metadata_paths.sort()
        for path in metadata_paths:
            md5_after.append(Filesystem.file_content_md5(path))

        md5_before = "".join(md5_before)
        md5_after = "".join(md5_after)

        if md5_before != md5_after:
            pipeline.utils.report.info("Metadata for '{}' has changed".format(epub.identifier()))
            Metadata.trigger_metadata_pipelines(pipeline, epub.identifier(), exclude=pipeline.uid)
        else:
            pipeline.utils.report.debug("Metadata for '{}' has not changed".format(epub.identifier()))

        return True

    @staticmethod
    def trigger_metadata_pipelines(pipeline, book_id, exclude=None):
        archive_dirs = {}

        for pipeline_uid in pipeline.dirs:
            if pipeline.dirs[pipeline_uid]["in"] == Metadata.get_metadata_dir():
                archive_dir = pipeline.dirs[pipeline_uid]["out"]
                basepath = Filesystem.get_base_path(archive_dir, pipeline.dirs[pipeline_uid]["base"])
                relpath = os.path.relpath(pipeline.dirs[pipeline_uid]["out"], basepath)

                if archive_dir not in archive_dirs:
                    archive_dirs[archive_dir] = relpath

        for archive_dir in archive_dirs.keys():
            book_dir = os.path.join(archive_dir, book_id)
            relpath = archive_dirs[archive_dir]
            if not os.path.exists(book_dir):
                pipeline.utils.report.info("'{}' does not exist in '{}'; downstream pipelines will not be triggered".format(book_id, relpath))
                del archive_dirs[archive_dir]

        for pipeline_uid in pipeline.dirs:
            if pipeline_uid == exclude:
                continue
            if pipeline.dirs[pipeline_uid]["in"] in archive_dirs:
                with open(os.path.join(pipeline.dirs[pipeline_uid]["trigger"], book_id), "w") as triggerfile:
                    triggerfile.write("autotriggered")
                pipeline.utils.report.info("Trigger: {}".format(pipeline_uid))

    @staticmethod
    def _validate_metadata(pipeline, epub, publication_format=""):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only update metadata in EPUBs")
            return False

        assert not publication_format or publication_format in Metadata.formats, "Format for validating metadata, when specified, must be one of: {}".format(
            ", ".join(Metadata.formats))

        metadata_dir = os.path.join(Metadata.get_metadata_dir(), epub.identifier())

        rdf_metadata = os.path.join(metadata_dir, "metadata.rdf")
        opf_metadata = {"": rdf_metadata.replace(".rdf", ".opf")}
        html_metadata = {"": rdf_metadata.replace(".rdf", ".html")}

        if not os.path.isfile(rdf_metadata):
            if not Metadata.get_metadata(pipeline, epub, publication_format=publication_format):
                pipeline.utils.report.error("Could not retrieve metadata; metadata.rdf does not exist")
                return False

        for f in Metadata.formats:
            format_id = re.sub(r"[^a-z0-9]", "", f.lower())
            if not publication_format or f == publication_format or f == "EPUB":
                opf_metadata[f] = os.path.join(metadata_dir, "metadata-{}.opf".format(format_id))
                html_metadata[f] = opf_metadata[f].replace(".opf", ".html")

        # Lag separat rapport/e-post for Bibliofil-metadata
        normarc_report_dir = os.path.join(pipeline.utils.report.reportDir(), "normarc")
        normarc_report = Report(None,
                                title=Metadata.title,
                                report_dir=normarc_report_dir,
                                dir_base=pipeline.dir_base,
                                uid=Metadata.uid)

        signatureRegistration = ElementTree.parse(rdf_metadata).getroot()
        nsmap = {
            'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
            'nlbprod': 'http://www.nlb.no/production'
        }
        signatureRegistration = signatureRegistration.xpath("/rdf:RDF/rdf:Description[rdf:type/@rdf:resource='http://schema.org/CreativeWork']" +
                                                            "/nlbprod:signatureRegistration/text()", namespaces=nsmap)
        signatureRegistration = signatureRegistration[0].lower() if signatureRegistration else None
        normarc_report.info("*Ansvarlig for katalogisering*: {}".format(signatureRegistration if signatureRegistration else "(ukjent)"))

        # Valider Bibliofil-metadata
        normarc_success = True
        marcxchange_paths = []
        for f in os.listdir(os.path.join(metadata_dir, "bibliofil")):
            if f.endswith(".xml"):
                marcxchange_paths.append(os.path.join(metadata_dir, "bibliofil", f))
        for marcxchange_path in marcxchange_paths:
            normarc_report.info("**Validerer NORMARC ({})**".format(os.path.basename(marcxchange_path).split(".")[0]))
            format_from_normarc, marc019b = Metadata.get_format_from_normarc(normarc_report, marcxchange_path)
            if not format_from_normarc and marc019b:
                normarc_report.warn("Katalogpost {} har et ukjent format i `*019$b`: \"{}\"".format(marcxchange_path.split("/")[-1].split(".")[0], marc019b))
            if publication_format and format_from_normarc and format_from_normarc not in [publication_format, "EPUB"]:
                continue

            sch = Schematron(report=normarc_report,
                             cwd=metadata_dir,
                             schematron=os.path.join(Xslt.xslt_dir, Metadata.uid, "validate-normarc.sch"),
                             source=marcxchange_path)
            if not sch.success:
                normarc_report.error("Validering av Bibliofil-metadata feilet")
                normarc_success = False

        # Send rapport
        normarc_report.attachLog()
        signatureRegistrationAddress = None
        if not normarc_success:
            Metadata.last_metadata_errors.append(int(time.time()))
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
                pipeline.utils.report._messages[message_type].append(message)

        if not normarc_success:
            cached_rdf_metadata = Metadata.get_cached_rdf_metadata(epub.identifier())
            library = [m for m in cached_rdf_metadata if m["publication"] in [None, epub.identifier()] and m["property"] == "schema:library"]
            library = library[0]["value"] if len(library) > 0 else None

            Metadata.add_production_info(normarc_report, epub.identifier(), publication_format=publication_format)
            normarc_report.email(self.config.get("email.smtp"),
                                 Address(*self.config.get("email.sender")),
                                 Report.filterEmailAddresses(signatureRegistrationAddress, library=library),
                                 subject="Validering av katalogpost: {} og tilhørende utgaver".format(epub.identifier()))
            pipeline.utils.report.warn("Katalogposten i Bibliofil er ikke gyldig. E-post ble sendt til: {}".format(
                                       ", ".join([addr.lower() for addr in signatureRegistrationAddress])))
            return False

        for f in opf_metadata:
            if os.path.isfile(opf_metadata[f]):
                pipeline.utils.report.info("Validerer OPF-metadata for " + (f if f else "åndsverk"))
                sch = Schematron(pipeline=pipeline,
                                 schematron=os.path.join(Xslt.xslt_dir, Metadata.uid, "validate-opf.sch"),
                                 source=opf_metadata[f])
                if not sch.success:
                    pipeline.utils.report.error("Validering av OPF-metadata feilet")
                    return False

            if os.path.isfile(html_metadata[f]):
                pipeline.utils.report.info("Validerer HTML-metadata for " + (f if f else "åndsverk"))
                sch = Schematron(pipeline=pipeline,
                                 schematron=os.path.join(Xslt.xslt_dir, Metadata.uid, "validate-html-metadata.sch"),
                                 source=html_metadata[f])
                if not sch.success:
                    pipeline.utils.report.error("Validering av HTML-metadata feilet")
                    return False

        return True

    @staticmethod
    def insert_metadata(pipeline, epub, publication_format=""):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only update metadata in EPUBs")
            return False

        opf_path = os.path.join(epub.book_path, epub.opf_path())
        if not os.path.exists(opf_path):
            pipeline.utils.report.error("Klarte ikke å lese OPF-filen. Kanskje EPUBen er zippet?")
            return False

        assert publication_format == "" or publication_format in Metadata.formats, "Format for updating metadata, when specified, must be one of: {}".format(
            ", ".join(Metadata.formats))

        # ========== Update metadata in EPUB ==========

        metadata_dir = os.path.join(Metadata.get_metadata_dir(), epub.identifier())

        format_id = re.sub(r"[^a-z0-9]", "", publication_format.lower())
        opf_metadata = os.path.join(metadata_dir, "metadata-{}.opf".format(format_id))
        html_metadata = opf_metadata.replace(".opf", ".html")

        if not os.path.exists(opf_metadata) or not os.path.exists(html_metadata):
            pipeline.utils.report.error("Finner ikke metadata for formatet \"{}\".".format(publication_format))
            return False

        updated_file_obj = tempfile.NamedTemporaryFile()
        updated_file = updated_file_obj.name

        dcterms_modified = str(datetime.datetime.utcnow().isoformat()).split(".")[0] + "Z"

        pipeline.utils.report.debug("update-opf.xsl")
        pipeline.utils.report.debug("    source       = " + opf_path)
        pipeline.utils.report.debug("    target       = " + updated_file)
        pipeline.utils.report.debug("    opf_metadata = " + opf_metadata)
        xslt = Xslt(pipeline,
                    stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "update-opf.xsl"),
                    source=opf_path,
                    target=updated_file,
                    parameters={
                        "opf_metadata": opf_metadata,
                        "modified": dcterms_modified
                    })
        if not xslt.success:
            pipeline.utils.report.error("Klarte ikke å oppdatere OPF")
            return False

        xml = ElementTree.parse(opf_path).getroot()
        old_modified = xml.xpath("/*/*[local-name()='metadata']/*[@property='dcterms:modified'][1]/text()")
        old_modified = old_modified[0] if old_modified else None

        xml = ElementTree.parse(updated_file).getroot()
        new_modified = xml.xpath("/*/*[local-name()='metadata']/*[@property='dcterms:modified'][1]/text()")
        new_modified = new_modified[0] if new_modified else None

        # Check that the new metadata is usable
        new_identifier = xml.xpath("/*/*[local-name()='metadata']/*[local-name()='identifier' and not(@refines)][1]/text()")
        new_identifier = new_identifier[0] if new_identifier else None
        if not new_identifier:
            pipeline.utils.report.error("Could not find identifier in updated metadata")
            return False

        updates = []

        if old_modified != new_modified:
            pipeline.utils.report.info("Updating OPF metadata")
            updates.append({
                            "updated_file_obj": updated_file_obj,
                            "updated_file": updated_file,
                            "target": opf_path
                          })

        html_paths = xml.xpath("/*/*[local-name()='manifest']/*[@media-type='application/xhtml+xml']/@href")

        for html_relpath in html_paths:
            html_path = os.path.normpath(os.path.join(os.path.dirname(opf_path), html_relpath))

            updated_file_obj = tempfile.NamedTemporaryFile()
            updated_file = updated_file_obj.name

            pipeline.utils.report.debug("update-html.xsl")
            pipeline.utils.report.debug("    source    = " + html_path)
            pipeline.utils.report.debug("    target    = " + updated_file)
            pipeline.utils.report.debug("    html_head = " + html_metadata)
            xslt = Xslt(pipeline,
                        stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "update-html.xsl"),
                        source=html_path,
                        target=updated_file,
                        parameters={
                            "html_head": html_metadata,
                            "modified": dcterms_modified
                        })
            if not xslt.success:
                pipeline.utils.report.error("Klarte ikke å oppdatere HTML")
                return False

            xml = ElementTree.parse(html_path).getroot()
            old_modified = xml.xpath("/*/*[local-name()='head']/*[@name='dcterms:modified'][1]/@content")
            old_modified = old_modified[0] if old_modified else None

            xml = ElementTree.parse(updated_file).getroot()
            new_modified = xml.xpath("/*/*[local-name()='head']/*[@name='dcterms:modified'][1]/@content")
            new_modified = new_modified[0] if new_modified else None

            if old_modified != new_modified:
                pipeline.utils.report.info("Updating HTML metadata for " + html_relpath)
                updates.append({
                                "updated_file_obj": updated_file_obj,
                                "updated_file": updated_file,
                                "target": html_path
                              })

        if updates:
            # do all copy operations at once to avoid triggering multiple modification events
            for update in updates:
                shutil.copy(update["updated_file"], update["target"])
            pipeline.utils.report.info("Metadata in {} was updated".format(epub.identifier()))

        else:
            pipeline.utils.report.info("Metadata in {} is already up to date".format(epub.identifier()))

        return bool(updates)

    @staticmethod
    def get_quickbase(pipeline, table, book_id, target, library=None):
        pipeline.utils.report.info("Henter metadata fra Quickbase ({}) for {}...".format(library, str(book_id)))

        # Records book id rows:
        #     13: Tilvekstnummer EPUB
        #     20: Tilvekstnummer DAISY 2.02 Skjønnlitteratur
        #     24: Tilvekstnummer DAISY 2.02 Studielitteratur
        #     28: Tilvekstnummer Punktskrift
        #     31: Tilvekstnummer DAISY 2.02 Innlest fulltekst
        #     32: Tilvekstnummer e-bok
        #     38: Tilvekstnummer ekstern produksjon
        #
        # ISBN book id rows:
        #     7: "Tilvekstnummer"

        xslt = Xslt(pipeline,
                    stylesheet=os.path.join(Xslt.xslt_dir, Metadata.uid, "bookguru", "quickbase-get.xsl"),
                    source=Metadata.sources["quickbase"]["{}-{}".format(table, library) if library else table],
                    target=target,
                    parameters={"book-id-rows": str.join(" ", Metadata.quickbase_id_rows["{}-{}".format(table, library) if library else table]),
                                "book-id": book_id})
        return xslt.success

    @staticmethod
    def get_bibliofil(pipeline, book_id, target):
        pipeline.utils.report.info("Henter metadata fra Bibliofil for " + str(book_id) + "...")
        url = "http://websok.nlb.no/cgi-bin/sru?version=1.2&operation=searchRetrieve&recordSchema=bibliofilmarcnoholdings&query=bibliofil.tittelnummer="
        url += book_id
        request = requests.get(url)
        with open(target, "wb") as target_file:
            target_file.write(request.content)

    @staticmethod
    def get_format_from_normarc(report, marcxchange_path):
        xml = ElementTree.parse(marcxchange_path).getroot()
        nsmap = {'marcxchange': 'info:lc/xmlns/marcxchange-v1'}
        marc019b = xml.xpath("//marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()", namespaces=nsmap)
        marc019b = marc019b[0] if marc019b else ""

        if not marc019b:
            report.debug("Fant ikke `*019$b` for {}".format(os.path.basename(marcxchange_path)))
            return None, marc019b

        split = marc019b.split(",")

        if [val for val in split if val in ['za', 'c']]:
            return "Braille", marc019b

        if [val for val in split if val in ['dc', 'dj']]:
            return "DAISY 2.02", marc019b

        if [val for val in split if val in ['la']]:
            return "XHTML", marc019b

        if [val for val in split if val in ['gt', 'nb']]:
            return "EPUB", marc019b

        report.warn("Ukjent format i `*019$b` for {}: {}".format(os.path.basename(marcxchange_path), marc019b))
        return None, marc019b

    @staticmethod
    def add_production_info(report, identifier, publication_format=""):
        metadata_dir = os.path.join(Metadata.get_metadata_dir(), identifier)
        rdf_path = os.path.join(metadata_dir, "metadata.rdf")
        rdf = ElementTree.parse(rdf_path).getroot() if os.path.isfile(rdf_path) else None

        report.info("<h2>Signaturer</h2>")
        if rdf is not None:
            signaturesWork = rdf.xpath("/*/*[rdf:type/@rdf:resource='http://schema.org/CreativeWork']/nlbprod:*[starts-with(local-name(),'signature')]",
                                       namespaces=rdf.nsmap)
            signaturesPublication = rdf.xpath(
                "/*/*[rdf:type/@rdf:resource='http://schema.org/Book' and {}]/nlbprod:*[starts-with(local-name(),'signature')]"
                .format("dc:format/text()='{}'".format(publication_format) if publication_format else 'true()'), namespaces=rdf.nsmap)
            signatures = signaturesWork + signaturesPublication
            if not signaturesWork and not signaturesPublication:
                report.info("Fant ingen signaturer.")
            else:
                report.info("<dl>")
                for e in signatures:
                    source = e.attrib["{http://www.nlb.no/}metadata-source"]
                    source = source.replace("Quickbase Record@{} ".format(identifier), "")
                    value = e.attrib["{http://schema.org/}name"] if "{http://schema.org/}name" in e.attrib else e.text
                    report.info("<dt>{}</dt>".format(source))
                    report.info("<dd>{}</dd>".format(value))
                report.info("</dl>")
        else:
            report.info("Metadata om produksjonen er ikke tilgjengelig: {}".format(identifier))

        report.info("<h2>Lenker til katalogposter</h2>")
        edition_identifiers, publication_identifiers = Metadata.get_identifiers(report, identifier)
        identifiers = list(set(edition_identifiers + publication_identifiers))
        bibliofil_url = "https://websok.nlb.no/cgi-bin/websok?tnr="
        report.info("<ul>")
        for i in sorted(identifiers):
            report.info("<li><a href=\"{}{}\">{}</a></li>".format(bibliofil_url, i[:6], i))
            # TODO: Her bør det i tillegg stå:
            # - format
            # - hvorvidt boken er katalogisert i Bibliofil
            # - kanskje også en lenke til Quickbase-oppføringen
        report.info("</ul>")
        if identifier.startswith("5") and len(identifiers) == 1:
            report.warn("Finner ingen tilhørende boknummer.")
        elif len(identifiers) == 1:
            report.info("Andre boknummer er ikke tilgjengelig.")

    @staticmethod
    def should_produce(pipeline, epub, publication_format):
        force_metadata_update = False
        if pipeline.book and pipeline.book["events"] and "triggered" in pipeline.book["events"]:
            # Hvis steget ble trigget manuelt: sørg for at metadataen er oppdatert
            # Merk at metadataen fortsatt kan være utdatert avhengig av hvordan den hentesself.
            # For eksempel så hentes Quickbase-metadata via en cron-jobb én gang i timen.
            force_metadata_update = True

        if not Metadata.update(pipeline, epub, publication_format=publication_format, insert=False, force_update=force_metadata_update):
            library = epub.meta("schema:library")
            if library is None or library.lower() != "statped":
                pipeline.utils.report.warn("Klarte ikke å hente metadata: {}".format(epub.identifier()))
                return False, False

        library = epub.meta("schema:library")
        if library is not None and library.lower() == "statped":
            pipeline.utils.report.info("Alle Statped-bøker skal produseres i alle formater")
            return True, True

        metadata_dir = os.path.join(Metadata.get_metadata_dir(), epub.identifier())
        rdf_path = os.path.join(metadata_dir, "metadata.rdf")
        if not os.path.isfile(rdf_path):
            pipeline.utils.report.warn("Metadata om produksjonen finnes ikke: {}".format(epub.identifier()))
            return False, False

        rdf = ElementTree.parse(rdf_path).getroot()
        metadata = Metadata.get_cached_rdf_metadata(epub.identifier())
        production_formats = [meta for meta in metadata if meta["property"].startswith("nlbprod:format")]
        exists_in_quickbase = bool(production_formats)

        exists_in_bibliofil = False
        for i in rdf.xpath("//dc:identifier", namespaces=rdf.nsmap):
            value = i.attrib["{http://schema.org/}name"] if "{http://schema.org/}name" in i.attrib else i.text
            if epub.identifier() == value and "bibliofil" in i.attrib["{http://www.nlb.no/}metadata-source"].lower():
                exists_in_bibliofil = True
                break

        if not exists_in_quickbase and exists_in_bibliofil:
            pipeline.utils.report.info("{} finnes i Bibliofil men ikke i Quickbase. Antar at den skal produseres som {}."
                                       .format(epub.identifier(), publication_format))
            return True, True

        result = False
        if publication_format == "Braille":
            production_formats = [f for f in production_formats if f["property"] in [
                "nlbprod:formatBraille",                   # Punktskrift
                "nlbprod:formatBrailleClub",               # Punktklubb
                "nlbprod:formatBraillePartialProduction",  # Punktskrift delproduksjon
                "nlbprod:formatNotes",                     # Noter
                "nlbprod:formatTactilePrint",              # Taktil trykk
            ]]
            if "true" in [f["value"] for f in production_formats]:
                result = True

        elif publication_format == "DAISY 2.02":
            production_formats = [f for f in production_formats if f["property"] in [
                "nlbprod:formatDaisy202narrated",              # DAISY 2.02 Innlest Skjønn
                "nlbprod:formatDaisy202narratedFulltext",      # DAISY 2.02 Innlest fulltekst
                "nlbprod:formatDaisy202narratedStudent",       # DAISY 2.02 Innlest Studie
                "nlbprod:formatDaisy202tts",                   # DAISY 2.02 TTS Skjønn
                "nlbprod:formatDaisy202ttsStudent",            # DAISY 2.02 TTS Studie
                "nlbprod:formatDaisy202wips",                  # DAISY 2.02 WIPS
                "nlbprod:formatAudioCDMP3ExternalProduction",  # Audio CD MP3 ekstern produksjon
                "nlbprod:formatAudioCDWAVExternalProduction",  # Audio CD WAV ekstern produksjon
                "nlbprod:formatDaisy202externalProduction",    # DAISY 2.02 ekstern produksjon
            ]]
            if "true" in [f["value"] for f in production_formats]:
                result = True

        elif publication_format == "XHTML":
            production_formats = [f for f in production_formats if f["property"] in [
                "nlbprod:formatEbook",                    # E-bok
                "nlbprod:formatEbookExternalProduction",  # E-bok ekstern produksjon
            ]]
            if "true" in [f["value"] for f in production_formats]:
                result = True

        elif publication_format == "EPUB":
            production_formats = []
            pipeline.utils.report.info("EPUB skal alltid produseres.".format())
            return True, True

        else:
            production_formats = []
            pipeline.utils.report.warn("Ukjent format: {}. {} blir ikke produsert.".format(publication_format, epub.identifier()))
            return False, False

        if production_formats:
            if result is True:
                pipeline.utils.report.info(
                    "<p><strong>{} skal produseres som {} fordi følgende felter er huket av i BookGuru:</strong></p>".format(
                        epub.identifier(), publication_format))
                production_formats = [f for f in production_formats if f["value"] == "true"]
            else:
                pipeline.utils.report.info(
                    "<p><strong>{} skal ikke produseres som {} fordi følgende felter ikke er huket av i BookGuru:</strong></p>".format(
                        epub.identifier(), publication_format))

            pipeline.utils.report.info("<ul>")
            for f in production_formats:
                pipeline.utils.report.info("<li>{}</li>".format(f["source"]))
            pipeline.utils.report.info("</ul>")

            if result is False:
                pipeline.utils.report.info("<p><strong>Merk at det kan ta opptil en time fra du huker av i BookGuru, " +
                                           "til produksjonssystemet ser at det har blitt huket av.</strong></p>")
        else:
            pipeline.utils.report.warn("Ingen informasjon i BookGuru om produksjon av formatet \"{}\".".format(publication_format))

        return result, True

    @staticmethod
    def get_metadata_from_book(pipeline, path, force_update=False, extend_with_cached_rdf_metadata=True):
        book_metadata = Metadata._get_metadata_from_book(pipeline, path, force_update)
        if extend_with_cached_rdf_metadata:
            cached_rdf_metadata = Metadata.get_cached_rdf_metadata(book_metadata["identifier"],
                                                                   simplified=True,
                                                                   filter_identifiers=[None, book_metadata["identifier"]])
            for meta in cached_rdf_metadata:
                if meta not in book_metadata:
                    book_metadata[meta] = cached_rdf_metadata[meta]
        return book_metadata

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

            # return cached metadata
            if path in Metadata.metadata_cache:
                return Metadata.metadata_cache[path]["metadata"]

            Metadata.metadata_cache[path] = {
                "cache_time": time.time(),
                "metadata": book_metadata
            }

            # Try getting EPUB metadata
            if os.path.exists(path):
                epub = Epub(pipeline, path)
                if epub.isepub(report_errors=False):
                    book_metadata["identifier"] = epub.identifier()
                    book_metadata["title"] = epub.meta("dc:title")
                    Metadata.metadata_cache[path]["metadata"] = book_metadata
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

            if (os.path.isfile(os.path.join(path, "ncc.html")) or
                    os.path.isfile(os.path.join(path, "metadata.html")) or
                    len(html_files)):
                file = os.path.join(path, "ncc.html")
                if not os.path.isfile(file):
                    file = os.path.join(path, "metadata.html")
                if not os.path.isfile(file):
                    file = os.path.join(path, os.path.basename(path) + ".xhtml")
                if not os.path.isfile(file):
                    file = os.path.join(path, os.path.basename(path) + ".html")
                if not os.path.isfile(file):
                    file = [f for f in html_files if re.match(r"^\d+\.x?html$", os.path.basename(f))][0]
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

            Metadata.metadata_cache[path]["metadata"] = book_metadata
            return book_metadata

    @staticmethod
    def get_cached_rdf_metadata(epub_identifier, simplified=False, filter_identifiers=None):
        cached_rdf_metadata = Metadata._get_cached_rdf_metadata(epub_identifier)

        if filter_identifiers:
            new_cached_rdf_metadata = []
            for meta in cached_rdf_metadata:
                if meta["publication"] in filter_identifiers:
                    new_cached_rdf_metadata.append(meta)
            cached_rdf_metadata = new_cached_rdf_metadata

        if simplified:
            simplified = {}
            for meta in cached_rdf_metadata:
                count = len([m for m in cached_rdf_metadata if m["property"] == meta["property"]])
                if count == 1:
                    simplified[meta["property"]] = meta["value"]
            return simplified
        else:
            return cached_rdf_metadata

    def _get_cached_rdf_metadata(epub_identifier):
        metadata = []

        rdf_file = os.path.join(Metadata.get_metadata_dir(), epub_identifier, "metadata.rdf")
        if not os.path.isfile(rdf_file):
            return metadata

        rdf = None
        try:
            rdf = ElementTree.parse(rdf_file).getroot()
        except ElementTree.XMLSyntaxError:
            logging.exception("Could not parse {}".format(rdf_file))
            return metadata

        creativeWork = rdf.xpath("/rdf:RDF/rdf:Description[rdf:type/@rdf:resource='http://schema.org/CreativeWork']", namespaces=rdf.nsmap)
        publications = rdf.xpath("/rdf:RDF/rdf:Description[dc:identifier]", namespaces=rdf.nsmap)
        if creativeWork:
            for meta in list(creativeWork[0]):
                property = meta.xpath("name()")
                if property == "rdf:type":
                    continue
                value = meta.xpath("@schema:name", namespaces=meta.nsmap) + meta.xpath("text()[1]")
                value = value[0] if value else ""
                metadata.append({
                    "property": property,
                    "value": value,
                    "publication": None,
                    "source": meta.xpath("string(@nlb:metadata-source)", namespaces=meta.nsmap)
                })
        for publication in publications:
            identifier = publication.xpath("dc:identifier[1]/@schema:name", namespaces=publication.nsmap) + publication.xpath("dc:identifier[1]/text()[1]",
                                                                                                                              namespaces=publication.nsmap)
            identifier = identifier[0] if identifier else None
            if identifier:
                for meta in list(publication):
                    property = meta.xpath("name()")
                    if property == "rdf:type":
                        continue
                    value = meta.xpath("@schema:name", namespaces=meta.nsmap) + meta.xpath("text()[1]")
                    value = value[0] if value else ""
                    metadata.append({
                        "property": property,
                        "value": value,
                        "publication": identifier,
                        "source": meta.xpath("string(@nlb:metadata-source)", namespaces=meta.nsmap)
                    })

        return metadata

    @staticmethod
    def pipeline_book_shortname(pipeline):
        name = pipeline.book["name"] if pipeline.book else ""

        if pipeline.book and pipeline.book["source"]:
            book_metadata = Metadata.get_metadata_from_book(pipeline, pipeline.book["source"])
            if "title" in book_metadata:
                name += ": " + book_metadata["title"][:25] + ("…" if len(book_metadata["title"]) > 25 else "")

        return name
