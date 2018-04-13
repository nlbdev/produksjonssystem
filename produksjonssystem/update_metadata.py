#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
import json
import time
import shutil
import logging
import zipfile
import datetime
import requests
import tempfile
import threading
import traceback
import subprocess

from lxml import etree as ElementTree
from pathlib import Path
from core.pipeline import Pipeline, DummyPipeline
from core.utils.epub import Epub
from core.utils.xslt import Xslt
from core.utils.report import Report
from core.utils.filesystem import Filesystem
from core.utils.schematron import Schematron
from core.utils.daisy_pipeline import DaisyPipelineJob

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class UpdateMetadata(Pipeline):
    uid = "update-metadata"
    title = "Oppdater metadata"
    
    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "xslt"))
    
    min_update_interval = 60 * 60 * 24 # 1 day
    max_update_interval = 60 * 30 # half hour
    max_metadata_emails_per_day = 5
    
    # if UpdateMetadata is not loaded, use a temporary directory
    # for storing metadata so that the static methods still work
    metadata_tempdir_obj = None
    
    quickbase_record_id_rows = [ "13", "20", "24", "28", "31", "32", "38" ]
    quickbase_isbn_id_rows = [ "7" ]
    
    formats = ["EPUB", "DAISY 2.02", "XHTML", "Braille"] # values used in dc:format
    
    logPipeline = None
    
    _metadataWatchThread = None
    
    update_lock = threading.RLock()
    
    metadata = None
    sources = {
        "quickbase": {
            "records": "/opt/quickbase/records.xml",
            "isbn": "/opt/quickbase/isbn.xml",
            "forlag": "/opt/quickbase/forlag.xml",
            "last_updated": 0
        },
        "bibliofil": {}
    }
    
    queue = []
    
    throttle_metadata_emails = True # if enabled, will only send up to N automated metadata error emails per day, and only in working hours
    last_metadata_errors = [] # timestamps for last automated metadata updates
    
    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self.shouldHandleBooks = False
        
        self.logPipeline = DummyPipeline(uid=self.uid + "-auto", title=self.title + " automatisk", inherit_config_from=UpdateMetadata)
        
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" starting to watch metadata...")
        
        if not self.metadata:
            self.metadata = {}
        
        self._metadataWatchThread = threading.Thread(target=self._watch_metadata_thread)
        self._metadataWatchThread.setDaemon(True)
        self._metadataWatchThread.start()
        
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" started watching metadata (cache in " + self.dir_in + ")")
        
    def stop(self, *args, **kwargs):
        super().stop(*args, **kwargs)
        
        if self._metadataWatchThread and self._metadataWatchThread != threading.current_thread():
            self._metadataWatchThread.join()
        
        if self.logPipeline:
            self.logPipeline.stop()
        
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" stopped watching metadata")
    
    def get_queue(self):
        return UpdateMetadata.queue
    
    def current_book_name(self):
        return UpdateMetadata.queue[0]["name"] if len(UpdateMetadata.queue) > 0 else ""
    
    def _watch_metadata_thread(self):
        while self._shouldRun:
            self.running = True
            
            try:
                time.sleep(1)
                
                if self._stopAfterFirstJob:
                    self.stop(exit=True)
                
                if self.throttle_metadata_emails:
                    # only update metadata in working hours
                    if not (datetime.date.today().weekday() <= 4):
                        continue
                    if not (8 <= datetime.datetime.now().hour <= 15):
                        continue
                
                # find a book_id where we haven't retrieved updated metadata in a while
                for book_id in os.listdir(self.dir_out):
                    if not self._shouldRun:
                        break
                    
                    now = int(time.time())
                    metadata_dir = os.path.join(self.dir_in, book_id)
                    
                    if self.throttle_metadata_emails:
                        while len(UpdateMetadata.last_metadata_errors) > 0 and UpdateMetadata.last_metadata_errors[0] < now - 3600*24:
                            UpdateMetadata.last_metadata_errors = UpdateMetadata.last_metadata_errors[1:]
                        if len(UpdateMetadata.last_metadata_errors) >= UpdateMetadata.max_metadata_emails_per_day:
                            break # only process N erroneous books per day (avoid getting flooded with errors)
                    
                    last_updated = self.metadata[book_id]["last_updated"] if book_id in self.metadata else None
                    
                    needs_update = False
                    
                    if not os.path.exists(metadata_dir):
                        needs_update = True
                    
                    last_updated_path = os.path.join(metadata_dir, "last_updated")
                    if not last_updated and os.path.exists(last_updated_path):
                        with open(last_updated_path, "r") as last_updated_file:
                            try:
                                last = int(last_updated_file.readline().strip())
                                last_updated = last
                            except Exception:
                                logging.exception("[" + Report.thread_name() + "] Could not parse " + str(book_id) + "/last_updated")
                    
                    if not last_updated or now - last_updated > self.min_update_interval:
                        needs_update = True
                    
                    if needs_update:
                        self.logPipeline.utils.report.debug("Updating metadata for {}, since it's been a long time since last it was updated".format(book_id))
                        
                        epub = Epub(self.logPipeline, os.path.join(Pipeline.dirs[UpdateMetadata.uid]["out"], book_id))
                        UpdateMetadata.get_metadata(self.logPipeline, epub)
                        
                        now = int(time.time())
                        if not book_id in self.metadata:
                            self.metadata[book_id] = {}
                        self.metadata[book_id]["last_updated"] = now
                        if not os.path.exists(metadata_dir):
                            os.makedirs(metadata_dir)
                        with open(last_updated_path, "w") as last_updated_file:
                            last_updated_file.write(str(now))
                
            except Exception:
                logging.exception("[" + Report.thread_name() + "] An error occured while checking for updates in metadata")
        
        self.running = False
    
    @staticmethod
    def update(*args, **kwargs):
        # Only update one book at a time, to avoid potentially overwriting metadata while it's being used
        
        ret = False
        with UpdateMetadata.update_lock:
            ret = UpdateMetadata._update(*args, **kwargs)
            UpdateMetadata.queue = []
        return ret
    
    @staticmethod
    def _update(pipeline, epub, publication_format="", insert=True, force_update=False):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only read and update metadata from EPUBs")
            return False
        
        # make a queue for plotting purposes
        queue_book = {}
        queue_book["name"] = epub.identifier()
        queue_book["source"] = os.path.join(UpdateMetadata.get_metadata_dir(), queue_book["name"])
        queue_book["events"] = [ "autotriggered" ]
        queue_book["last_event"] = int(time.time())
        UpdateMetadata.queue = [ queue_book ]
        
        last_updated = 0
        last_updated_path = os.path.join(UpdateMetadata.get_metadata_dir(), epub.identifier(), "last_updated")
        if os.path.exists(last_updated_path):
            with open(last_updated_path, "r") as last_updated_file:
                try:
                    last = int(last_updated_file.readline().strip())
                    last_updated = last
                except Exception:
                    logging.exception("[" + Report.thread_name() + "] Could not parse " + last_updated_path)
        
        # Get updated metadata for a book, but only if the metadata is older than max_update_interval minutes
        now = int(time.time())
        if now - last_updated > UpdateMetadata.max_update_interval or force_update:
            success = UpdateMetadata.get_metadata(pipeline, epub, publication_format=publication_format)
            if not success:
                return False
        elif not UpdateMetadata.validate_metadata(pipeline, epub, publication_format=publication_format):
            return False
        
        if insert:
            return UpdateMetadata.insert_metadata(pipeline, epub, publication_format=publication_format)
        else:
            return True
    
    @staticmethod
    def get_metadata(pipeline, epub, publication_format=""):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only read metadata from EPUBs")
            return False
        
        # get path to OPF in EPUB (unzip if necessary)
        opf = epub.opf_path()
        opf_obj = None # if tempfile is needed
        if os.path.isdir(epub.book_path):
            opf = os.path.join(epub.book_path, opf)
        else:
            opf_obj = tempfile.NamedTemporaryFile()
            with zipfile.ZipFile(epub.book_path, 'r') as archive, open(opf, "wb") as opf_file:
                opf_file.write(archive.read(opf))
            opf = opf_obj.name
        
        # Publication and edition identifiers are the same except for periodicals
        edition_identifier = epub.identifier()
        pub_identifier = edition_identifier
        if len(pub_identifier) > 6:
            pub_identifier = pub_identifier[:6]
        
        # path to directory with metadata from Quickbase / Bibliofil / Bokbasen
        metadata_dir = os.path.join(UpdateMetadata.get_metadata_dir(), edition_identifier)
        pipeline.utils.report.attachment(None, metadata_dir, "DEBUG")
        os.makedirs(metadata_dir, exist_ok=True)
        os.makedirs(metadata_dir + '/quickbase', exist_ok=True)
        os.makedirs(metadata_dir + '/bibliofil', exist_ok=True)
        os.makedirs(metadata_dir + '/epub', exist_ok=True)
        
        with open(os.path.join(metadata_dir, "last_updated"), "w") as last_updated:
            last_updated.write(str(int(time.time())))
        
        rdf_files = []
        
        opf_path = os.path.join(epub.book_path, epub.opf_path())
        if not os.path.exists(opf_path):
            pipeline.utils.report.error("Could not read OPF file. Maybe the EPUB is zipped?")
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
        xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "nlbpub-opf-to-rdf.xsl"),
                              source=opf_path,
                              target=rdf_path,
                              parameters={ "include-source-reference": "true" })
        if not xslt.success:
            return False
        rdf_files.append('epub/' + os.path.basename(rdf_path))
        
        pipeline.utils.report.debug("quickbase-record-to-rdf.xsl")
        rdf_path = os.path.join(metadata_dir, 'quickbase/record.rdf')
        pipeline.utils.report.debug("    source = " + os.path.join(metadata_dir, 'quickbase/record.xml'))
        pipeline.utils.report.debug("    target = " + os.path.join(metadata_dir, 'quickbase/record.html'))
        pipeline.utils.report.debug("    rdf    = " + rdf_path)
        success = UpdateMetadata.get_quickbase_record(pipeline, edition_identifier, os.path.join(metadata_dir, 'quickbase/record.xml'))
        if not success:
            return False
        xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "quickbase-record-to-rdf.xsl"),
                              source=os.path.join(metadata_dir, 'quickbase/record.xml'),
                              target=os.path.join(metadata_dir, 'quickbase/record.html'),
                              parameters={
                                "rdf-xml-path": rdf_path,
                                "include-source-reference": "true"
                              })
        if not xslt.success:
            return False
        rdf_files.append('quickbase/' + os.path.basename(rdf_path))
        
        rdf = ElementTree.parse(rdf_path).getroot()
        identifiers = rdf.xpath("//nlbprod:*[starts-with(local-name(),'identifier.')]", namespaces=rdf.nsmap)
        identifiers = [e.text for e in identifiers if re.match("^[\dA-Za-z._-]+$", e.text)]
        if not identifiers:
            pipeline.utils.report.warn("{} er ikke katalogisert i Quickbase".format(edition_identifier))
        
        identifiers.append(edition_identifier)
        
        # Find book IDs with the same ISBN in *596$f (input is "bookId,isbn" CSV dump)
        original_isbn = {}
        original_isbn_csv = str(os.path.normpath(os.environ.get("ORIGINAL_ISBN_CSV"))) if os.environ.get("ORIGINAL_ISBN_CSV") else None
        if original_isbn_csv and os.path.isfile(original_isbn_csv):
            pipeline.utils.report.debug("Leter etter bøker med samme ISBN som {} i {}...".format(edition_identifier, original_isbn_csv))
            with open(original_isbn_csv) as f:
                for line in f:
                    line_split = line.split(",")
                    if len(line_split) == 1:
                        pipeline.utils.report.warn("'{}' mangler ISBN og format".format(line_split[0]))
                        continue
                    elif len(line_split) == 2:
                        pipeline.utils.report.warn("'{}' ({}) mangler format".format(line_split[0], line_split[1]))
                        continue
                    b = line_split[0]                            # book id
                    i = line_split[1].strip()                    # isbn
                    i_normalized = re.sub(r"[^\d]", "", i)
                    f = sorted(list(set(line_split[2].split()))) # formats
                    fmt = " ".join(f)
                    if i_normalized not in original_isbn:
                        original_isbn[i_normalized] = { "pretty": i, "books": {} }
                    
                    for old_fmt in original_isbn[i_normalized]["books"]:
                        if len([val for val in old_fmt.split() if val in f]):
                            # same format; rename dict key
                            f = sorted(list(set(f + [b])))
                            fmt = " ".join(f)
                            if fmt in original_isbn[i_normalized]["books"]:
                                original_isbn[i_normalized]["books"][old_fmt] += original_isbn[i_normalized]["books"][fmt]
                            original_isbn[i_normalized]["books"][fmt] = original_isbn[i_normalized]["books"].pop(old_fmt)
                    
                    if fmt not in original_isbn[i_normalized]["books"]:
                        original_isbn[i_normalized]["books"][fmt] = []
                    original_isbn[i_normalized]["books"][fmt].append(b)
                    original_isbn[i_normalized]["books"][fmt] = sorted(list(set(original_isbn[i_normalized]["books"][fmt])))
        else:
            pipeline.utils.report.warn("Finner ikke liste over boknummer og ISBN fra `*596$f` (\"{}\")".format(original_isbn_csv))
        for i in original_isbn:
            data = original_isbn[i]
            match = True in [edition_identifier in data["books"][fmt] or pub_identifier in data["books"][fmt] for fmt in data["books"]]
            if not match:
                continue
            for fmt in data["books"]:
                if len(data["books"][fmt]) > 1:
                    ignored = [val for val in data["books"][fmt] if val not in identifiers]
                    pipeline.utils.report.warn("Det er flere bøker med samme original-ISBN/ISSN og samme format: {}".format(", ".join(data["books"][fmt])))
                    if len(ignored):
                        pipeline.utils.report.warn("Følgende bøker blir ikke behandlet: {}".format(", ".join(ignored)))
                    continue
                else:
                    fmt_bookid = data["books"][fmt][0]
                    if not fmt_bookid in identifiers:
                        pipeline.utils.report.info("{} har samme ISBN/ISSN i `*596$f` som {}; legger til {} som utgave".format(fmt_bookid, edition_identifier, fmt_bookid))
                        identifiers.append(fmt_bookid)
        
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
            UpdateMetadata.get_bibliofil(pipeline, format_pub_identifier, marcxchange_path)
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "normarc/marcxchange-to-opf.xsl"),
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
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "normarc/bibliofil-to-rdf.xsl"),
                                  source=current_opf_path,
                                  target=html_path,
                                  parameters={ "rdf-xml-path": rdf_path })
            if not xslt.success:
                return False
            rdf_files.append('bibliofil/' + os.path.basename(rdf_path))
            
            pipeline.utils.report.debug("quickbase-isbn-to-rdf.xsl")
            rdf_path = os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '.rdf')
            pipeline.utils.report.debug("    source = " + os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '.xml'))
            pipeline.utils.report.debug("    target = " + os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '.html'))
            pipeline.utils.report.debug("    rdf    = " + rdf_path)
            success = UpdateMetadata.get_quickbase_isbn(pipeline, format_edition_identifier, os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '.xml'))
            if not success:
                return False
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "quickbase-isbn-to-rdf.xsl"),
                                  source=os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '.xml'),
                                  target=os.path.join(metadata_dir, 'quickbase/isbn-' + format_edition_identifier + '.html'),
                                  parameters={
                                    "rdf-xml-path": rdf_path,
                                    "include-source-reference": "true"
                                  })
            if not xslt.success:
                return False
            rdf_files.append('quickbase/' + os.path.basename(rdf_path))
        
        
        # ========== Combine metadata ==========
        
        rdf_metadata = os.path.join(metadata_dir, "metadata.rdf")
        opf_metadata = {"": rdf_metadata.replace(".rdf",".opf")}
        html_metadata = {"": rdf_metadata.replace(".rdf",".html")}
        
        for f in UpdateMetadata.formats:
            format_id = re.sub(r"[^a-z0-9]", "", f.lower())
            opf_metadata[f] = os.path.join(metadata_dir, "metadata-{}.opf".format(format_id))
            html_metadata[f] = opf_metadata[f].replace(".opf",".html")
        
        pipeline.utils.report.debug("rdf-join.xsl")
        pipeline.utils.report.debug("    metadata-dir = " + metadata_dir + "/")
        pipeline.utils.report.debug("    rdf-files    = " + " ".join(rdf_files))
        pipeline.utils.report.debug("    target       = " + rdf_metadata)
        xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "rdf-join.xsl"),
                              template="main",
                              target=rdf_metadata,
                              parameters={
                                  "metadata-dir": metadata_dir + "/",
                                  "rdf-files": " ".join(rdf_files)
                              })
        if not xslt.success:
            return False
        
        xslt_success = True
        for f in opf_metadata:
            pipeline.utils.report.debug("rdf-to-opf.xsl")
            pipeline.utils.report.debug("    source = " + rdf_metadata)
            pipeline.utils.report.debug("    target = " + opf_metadata[f])
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "rdf-to-opf.xsl"),
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
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "opf-to-html.xsl"),
                                  source=opf_metadata[f],
                                  target=html_metadata[f])
            if not xslt.success:
                xslt_success = False
        
        if not xslt_success:
            return False
        
        # ========== Validate metadata ==========
        
        if not UpdateMetadata.validate_metadata(pipeline, epub, publication_format=publication_format):
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
            UpdateMetadata.trigger_metadata_pipelines(pipeline, epub.identifier(), exclude=pipeline.uid)
        else:
            pipeline.utils.report.debug("Metadata for '{}' has not changed".format(epub.identifier()))
        
        return True
    
    @staticmethod
    def validate_metadata(pipeline, epub, publication_format=""):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only update metadata in EPUBs")
            return False
        
        assert not publication_format or publication_format in UpdateMetadata.formats, "Format for validating metadata, when specified, must be one of: {}".format(", ".join(UpdateMetadata.formats))
        
        metadata_dir = os.path.join(UpdateMetadata.get_metadata_dir(), epub.identifier())
        
        rdf_metadata = os.path.join(metadata_dir, "metadata.rdf")
        opf_metadata = {"": rdf_metadata.replace(".rdf",".opf")}
        html_metadata = {"": rdf_metadata.replace(".rdf",".html")}
        
        for f in UpdateMetadata.formats:
            format_id = re.sub(r"[^a-z0-9]", "", f.lower())
            if not publication_format or f == publication_format or f == "EPUB":
                opf_metadata[f] = os.path.join(metadata_dir, "metadata-{}.opf".format(format_id))
                html_metadata[f] = opf_metadata[f].replace(".opf",".html")
        
        # Lag separat rapport/e-post for Bibliofil-metadata
        normarc_pipeline = DummyPipeline(uid=UpdateMetadata.uid, title=UpdateMetadata.title, inherit_config_from=UpdateMetadata)
        for util in pipeline.utils:
            if util != "report":
                normarc_pipeline.utils[util] = pipeline.utils[util]
        normarc_pipeline.utils.report = Report(normarc_pipeline)
        
        signatureRegistration = ElementTree.parse(rdf_metadata).getroot()
        nsmap = {
            'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
            'nlbprod': 'http://www.nlb.no/production'
        }
        signatureRegistration = signatureRegistration.xpath("/rdf:RDF/rdf:Description[rdf:type/@rdf:resource='http://schema.org/CreativeWork']/nlbprod:signatureRegistration/text()", namespaces=nsmap)
        signatureRegistration = signatureRegistration[0].lower() if signatureRegistration else None
        normarc_pipeline.utils.report.info("*Ansvarlig for katalogisering*: {}".format(signatureRegistration if signatureRegistration else "(ukjent)"))
        
        # Valider Bibliofil-metadata
        normarc_success = True
        marcxchange_paths = []
        for f in os.listdir(os.path.join(metadata_dir, "bibliofil")):
            if f.endswith(".xml"):
                marcxchange_paths.append(os.path.join(metadata_dir, "bibliofil", f))
        for marcxchange_path in marcxchange_paths:
            format_from_normarc, marc019b = UpdateMetadata.get_format_from_normarc(normarc_pipeline, marcxchange_path)
            if not format_from_normarc:
                normarc_pipeline.utils.report.warn("Katalogpost {} har et ukjent format i `*019$b`: \"{}\"".format(marcxchange_path.split("/")[-1].split(".")[0], marc019b))
            if publication_format and format_from_normarc and format_from_normarc not in [publication_format, "EPUB"]:
                continue
            
            normarc_pipeline.utils.report.info("**Validerer NORMARC ({})**".format(os.path.basename(marcxchange_path).split(".")[0]))
            sch = Schematron(normarc_pipeline, schematron=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "validate-normarc.sch"),
                                               source=marcxchange_path)
            if not sch.success:
                normarc_pipeline.utils.report.error("Validering av Bibliofil-metadata feilet")
                normarc_success = False
        
        # Send rapport
        normarc_pipeline.utils.report.attachLog()
        if not normarc_success:
            UpdateMetadata.last_metadata_errors.append(int(time.time()))
            signatureRegistrationAddress = None
            if signatureRegistration:
                for addr in UpdateMetadata.config["librarians"]:
                    if signatureRegistration == addr.addr_spec.lower():
                        signatureRegistrationAddress = addr
            if not signatureRegistrationAddress:
                normarc_pipeline.utils.report.warn("'{}' er ikke en aktiv bibliotekar, sender til hovedansvarlig istedenfor: '{}'".format(signatureRegistration if signatureRegistration else "(ukjent)", UpdateMetadata.config["default_librarian"].addr_spec.lower()))
                normarc_pipeline.utils.report.debug("Aktive bibliotekarer: {}".format(", ".join([addr.addr_spec.lower() for addr in UpdateMetadata.config["librarians"]])))
                signatureRegistrationAddress = UpdateMetadata.config["default_librarian"]
            UpdateMetadata.add_production_info(normarc_pipeline, epub.identifier(), publication_format=publication_format)
            normarc_pipeline.utils.report.email(UpdateMetadata.email_settings["smtp"],
                                                UpdateMetadata.email_settings["sender"],
                                                signatureRegistrationAddress,
                                                subject="Validering av katalogpost: {} og tilhørende utgaver".format(epub.identifier()))
        
        # Kopier Bibliofil-metadata-rapporten inn i samme rapport som resten av konverteringen
        for message_type in normarc_pipeline.utils.report._messages:
            for message in normarc_pipeline.utils.report._messages[message_type]:
                if message_type == "attachment" and os.path.exists(message["text"]):
                    new_attachment = os.path.join(pipeline.utils.report.reportDir(), "normarc", os.path.basename(message["text"]))
                    os.makedirs(os.path.dirname(new_attachment), exist_ok=True)
                    shutil.copy(message["text"], new_attachment)
                    message["text"] = new_attachment
                pipeline.utils.report._messages[message_type].append(message)
        
        if not normarc_success:
            return False
        
        for f in opf_metadata:
            if os.path.isfile(opf_metadata[f]):
                pipeline.utils.report.info("Validerer OPF-metadata for " + (f if f else "åndsverk"))
                sch = Schematron(pipeline, schematron=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "validate-opf.sch"),
                                           source=opf_metadata[f])
                if not sch.success:
                    pipeline.utils.report.error("Validering av OPF-metadata feilet")
                    return False
            
            if os.path.isfile(html_metadata[f]):
                pipeline.utils.report.info("Validerer HTML-metadata for " + (f if f else "åndsverk"))
                sch = Schematron(pipeline, schematron=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "validate-html-metadata.sch"),
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
            pipeline.utils.report.error("Could not read OPF file. Maybe the EPUB is zipped?")
            return False
        
        assert publication_format == "" or publication_format in UpdateMetadata.formats, "Format for updating metadata, when specified, must be one of: {}".format(", ".join(UpdateMetadata.formats))
        
        # ========== Update metadata in EPUB ==========
        
        metadata_dir = os.path.join(UpdateMetadata.get_metadata_dir(), epub.identifier())
        
        format_id = re.sub(r"[^a-z0-9]", "", publication_format.lower())
        opf_metadata = os.path.join(metadata_dir, "metadata-{}.opf".format(format_id))
        html_metadata = opf_metadata.replace(".opf",".html")
        
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
        xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "update-opf.xsl"),
                              source=opf_path,
                              target=updated_file,
                              parameters={
                                "opf_metadata": opf_metadata,
                                "modified": dcterms_modified
                              })
        if not xslt.success:
            return False
        
        xml = ElementTree.parse(opf_path).getroot()
        old_modified = xml.xpath("/*/*[local-name()='metadata']/*[@property='dcterms:modified'][1]/text()")
        old_modified = old_modified[0] if old_modified else None
        
        xml = ElementTree.parse(updated_file).getroot()
        new_modified = xml.xpath("/*/*[local-name()='metadata']/*[@property='dcterms:modified'][1]/text()")
        new_modified = new_modified[0] if new_modified else None
        
        ## Check that the new metadata is usable
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
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "update-html.xsl"),
                                  source=html_path,
                                  target=updated_file,
                                  parameters={
                                    "html_head": html_metadata,
                                    "modified": dcterms_modified
                                  })
            if not xslt.success:
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
    def get_metadata_dir():
        metadata_dir = None
        if UpdateMetadata.uid in Pipeline.dirs:
            return Pipeline.dirs[UpdateMetadata.uid]["in"]
        else:
            if not UpdateMetadata.metadata_tempdir_obj:
                UpdateMetadata.metadata_tempdir_obj = tempfile.TemporaryDirectory(prefix="metadata-")
                pipeline.utils.report.info("Using temporary directory for metadata: " + UpdateMetadata.metadata_tempdir_obj.name)
            return UpdateMetadata.metadata_tempdir_obj.name
    
    @staticmethod
    def get_quickbase_record(pipeline, book_id, target):
        pipeline.utils.report.info("Henter metadata fra Quickbase (Records) for " + str(book_id) + "...")
        
        # Book id rows:
        #     13: Tilvekstnummer EPUB
        #     20: Tilvekstnummer DAISY 2.02 Skjønnlitteratur
        #     24: Tilvekstnummer DAISY 2.02 Studielitteratur
        #     28: Tilvekstnummer Punktskrift
        #     31: Tilvekstnummer DAISY 2.02 Innlest fulltekst
        #     32: Tilvekstnummer e-bok
        #     38: Tilvekstnummer ekstern produksjon
        
        xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "quickbase-get.xsl"),
                              source=UpdateMetadata.sources["quickbase"]["records"],
                              target=target,
                              parameters={ "book-id-rows": str.join(" ", UpdateMetadata.quickbase_record_id_rows), "book-id": book_id })
        return xslt.success
    
    @staticmethod
    def get_quickbase_isbn(pipeline, book_id, target):
        pipeline.utils.report.info("Henter metadata fra Quickbase (ISBN) for " + str(book_id) + "...")
        
        # Book id rows:
        #     7: "Tilvekstnummer"
        
        xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "quickbase-get.xsl"),
                              source=UpdateMetadata.sources["quickbase"]["isbn"],
                              target=target,
                              parameters={ "book-id-rows": str.join(" ", UpdateMetadata.quickbase_isbn_id_rows), "book-id": book_id })
        return xslt.success
    
    @staticmethod
    def get_bibliofil(pipeline, book_id, target):
        pipeline.utils.report.info("Henter metadata fra Bibliofil for " + str(book_id) + "...")
        url = "http://websok.nlb.no/cgi-bin/sru?version=1.2&operation=searchRetrieve&recordSchema=bibliofilmarcnoholdings&query="
        url += book_id
        request = requests.get(url)
        with open(target, "wb") as target_file:
            target_file.write(request.content)
    
    @staticmethod
    def get_format_from_normarc(pipeline, marcxchange_path):
        xml = ElementTree.parse(marcxchange_path).getroot()
        nsmap = { 'marcxchange': 'info:lc/xmlns/marcxchange-v1' }
        marc019b = xml.xpath("//marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()", namespaces=nsmap)
        marc019b = marc019b[0] if marc019b else ""
        
        if not marc019b:
            pipeline.utils.report.debug("Fant ikke `*019$b` for {}".format(os.path.basename(marcxchange_path)))
            return None, marc019b
        
        split = marc019b.split(",")
        
        if [val for val in split if val in ['za','c']]:
            return "Braille", marc019b
        
        if [val for val in split if val in ['dc','dj']]:
            return "DAISY 2.02", marc019b
        
        if [val for val in split if val in ['la']]:
            return "XHTML", marc019b
        
        if [val for val in split if val in ['gt']]:
            return "EPUB", marc019b
        
        pipeline.utils.report.warn("Ukjent format i `*019$b` for {}: {}".format(os.path.basename(marcxchange_path), marc019b))
        return None, marc019b
    
    @staticmethod
    def trigger_metadata_pipelines(pipeline, book_id, exclude=None):
        if not os.path.exists(os.path.join(Pipeline.dirs[UpdateMetadata.uid]["out"], book_id)):
            pipeline.utils.report.info("'{}' does not exist in '{}'; no downstream pipelines will be triggered".format(book_id, Pipeline.dirs[UpdateMetadata.uid]["out"].split(Pipeline.dirs[UpdateMetadata.uid]["base"])[-1]))
            return  
        for pipeline_uid in Pipeline.dirs:
            if pipeline_uid == exclude:
                continue
            if Pipeline.dirs[pipeline_uid]["in"] == Pipeline.dirs[UpdateMetadata.uid]["out"]:
                with open(os.path.join(Pipeline.dirs[pipeline_uid]["trigger"], book_id), "w") as triggerfile:
                    print("autotriggered", file=triggerfile)
                pipeline.utils.report.info("Trigger: {}".format(pipeline_uid))
    
    @staticmethod
    def add_production_info(pipeline, identifier, publication_format=""):
        metadata_dir = os.path.join(UpdateMetadata.get_metadata_dir(), identifier)
        rdf_path = os.path.join(metadata_dir, "metadata.rdf")
        if not os.path.isfile(rdf_path):
            pipeline.utils.report.debug("Metadata om produksjonen finnes ikke: {}".format(identifier))
            return
        
        rdf = ElementTree.parse(rdf_path).getroot()
        
        pipeline.utils.report.info("<h2>Signaturer</h2>")
        signaturesWork = rdf.xpath("/*/*[rdf:type/@rdf:resource='http://schema.org/CreativeWork']/nlbprod:*[starts-with(local-name(),'signature')]", namespaces=rdf.nsmap)
        signaturesPublication = rdf.xpath("/*/*[rdf:type/@rdf:resource='http://schema.org/Book' and {}]/nlbprod:*[starts-with(local-name(),'signature')]".format("dc:format/text()='{}'".format(publication_format) if publication_format else 'true()'), namespaces=rdf.nsmap)
        signatures = signaturesWork + signaturesPublication
        if not signaturesWork and not signaturesPublication:
            pipeline.utils.report.info("Fant ingen signaturer.")
        else:
            pipeline.utils.report.info("<dl>")
            for e in signatures:
                source = e.attrib["{http://www.nlb.no/}metadata-source"]
                source = source.replace("Quickbase Record@{} ".format(identifier), "")
                value = e.attrib["{http://schema.org/}name"] if "{http://schema.org/}name" in e.attrib else e.text
                pipeline.utils.report.info("<dt>{}</dt>".format(source))
                pipeline.utils.report.info("<dd>{}</dd>".format(value))
            pipeline.utils.report.info("<dl>")
    
    @staticmethod
    def should_produce(pipeline, epub, publication_format):
        if not UpdateMetadata.update(pipeline, epub, publication_format=publication_format, insert=False):
            pipeline.utils.report.warn("Klarte ikke å hente metadata: {}".format(epub.identifier()))
            return False
        
        metadata_dir = os.path.join(UpdateMetadata.get_metadata_dir(), epub.identifier())
        rdf_path = os.path.join(metadata_dir, "metadata.rdf")
        if not os.path.isfile(rdf_path):
            pipeline.utils.report.debug("Metadata om produksjonen finnes ikke: {}".format(epub.identifier()))
            return False
        
        rdf = ElementTree.parse(rdf_path).getroot()
        production_formats = rdf.xpath("//nlbprod:*[starts-with(local-name(),'format')]", namespaces=rdf.nsmap)
        exists_in_quickbase = bool(production_formats)
        production_formats = [f.xpath("local-name()") for f in production_formats if (f.text == "true" or "{http://schema.org/}name" in f.attrib and f.attrib["{http://schema.org/}name"] == "true")]
        
        exists_in_bibliofil = False
        for i in rdf.xpath("//dc:identifier", namespaces=rdf.nsmap):
            value = i.attrib["{http://schema.org/}name"] if "{http://schema.org/}name" in i.attrib else i.text
            if epub.identifier() == value and "bibliofil" in i.attrib["{http://www.nlb.no/}metadata-source"].lower():
                exists_in_bibliofil = True
                break
        
        if not exists_in_quickbase and exists_in_bibliofil:
            pipeline.utils.report.info("{} finnes i Bibliofil men ikke i Quickbase. Antar at den skal produseres som {}.".format(epub.identifier(), publication_format))
            return True
        
        if publication_format == "Braille":
            if [f for f in production_formats if f in [
                "formatBraille",                  # Punktskrift
                "formatBrailleClub",              # Punktklubb
                "formatBraillePartialProduction", # Punktskrift delproduksjon
                "formatNotes",                    # Noter
                "formatTactilePrint",             # Taktil trykk
            ]]:
                return True
        
        elif publication_format == "DAISY 2.02":
            if [f for f in production_formats if f in [
                "formatDaisy202narrated",             # DAISY 2.02 Innlest Skjønn
                "formatDaisy202narratedFulltext",     # DAISY 2.02 Innlest fulltekst
                "formatDaisy202narratedStudent",      # DAISY 2.02 Innlest Studie
                "formatDaisy202tts",                  # DAISY 2.02 TTS Skjønn
                "formatDaisy202ttsStudent",           # DAISY 2.02 TTS Studie
                "formatDaisy202wips",                 # DAISY 2.02 WIPS
                "formatAudioCDMP3ExternalProduction", # Audio CD MP3 ekstern produksjon
                "formatAudioCDWAVExternalProduction", # Audio CD WAV ekstern produksjon
                "formatDaisy202externalProduction",   # DAISY 2.02 ekstern produksjon
            ]]:
                return True
        
        elif publication_format == "XHTML":
            if [f for f in production_formats if f in [
                "formatEbook",                   # E-bok
                "formatEbookExternalProduction", # E-bok ekstern produksjon
            ]]:
                return True
        
        elif publication_format == "EPUB":
            return True
        
        else:
            pipeline.utils.report.warn("Ukjent format: {}. {} blir ikke produsert.".format(publication_format, epub.identifier()))
            return False
        
        return False
    
    def on_book_deleted(self):
        self.utils.report.should_email = False
    
    def on_book_modified(self):
        if "triggered" not in self.book["events"]:
            self.utils.report.should_email = False
            return
        
        epub = Epub(self, os.path.join(Pipeline.dirs[UpdateMetadata.uid]["out"], self.book["name"]))
        if UpdateMetadata.update(self, epub, insert=False, force_update=True):
            UpdateMetadata.trigger_metadata_pipelines(self, self.book["name"])
    
    def on_book_created(self):
        self.utils.report.should_email = False

if __name__ == "__main__":
    UpdateMetadata().run()
