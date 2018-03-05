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
import traceback
import subprocess

from lxml import etree as ElementTree
from pathlib import Path
from threading import Thread, RLock
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
    
    # if UpdateMetadata is not loaded, use a temporary directory
    # for storing metadata so that the static methods still work
    metadata_tempdir_obj = None
    
    quickbase_record_id_rows = [ "13", "20", "24", "28", "31", "32", "38" ]
    quickbase_isbn_id_rows = [ "7" ]
    
    formats = ["EPUB", "DAISY 2.02", "XHTML", "Braille"] # values used in dc:format
    
    logPipeline = DummyPipeline(uid=uid, title=title)
    
    _metadataWatchThread = None
    _shouldWatchMetadata = True
    
    update_lock = RLock()
    
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
    
    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self.shouldHandleBooks = False
        
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" starting to watch metadata...")
        
        if not self.metadata:
            self.metadata = {}
        
        self._metadataWatchThread = Thread(target=self._watch_metadata_thread)
        self._metadataWatchThread.setDaemon(True)
        self._metadataWatchThread.start()
        
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" started watching metadata (cache in " + self.dir_in + ")")
        
    
    def stop(self, *args, **kwargs):
        self._shouldWatchMetadata = False
        if self._metadataWatchThread:
            self._metadataWatchThread.join()
        
        self.logPipeline.stop()
        
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" stopped watching metadata")
        
        super().stop(*args, **kwargs)
    
    def _watch_metadata_thread(self):
        while self._shouldWatchMetadata:
            try:
                time.sleep(1)
                
                # find a book_id where we haven't retrieved updated metadata in a while
                for book_id in os.listdir(self.dir_out):
                    now = int(time.time())
                    metadata_dir = os.path.join(self.dir_in, book_id)
                    
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
    
    @staticmethod
    def update(*args, **kwargs):
        # Only update one book at a time, to avoid potentially overwriting metadata while it's being used
        
        ret = False
        with UpdateMetadata.update_lock:
            ret = UpdateMetadata._update(*args, **kwargs)
        return ret
    
    @staticmethod
    def _update(pipeline, epub, publication_format="", insert=True):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only read and update metadata from EPUBs")
            return False
        
        last_updated = 0
        last_updated_path = os.path.join(UpdateMetadata.get_metadata_dir(), epub.identifier(), "last_updated")
        if os.path.exists(last_updated_path):
            with open(last_updated_path, "r") as last_updated_file:
                try:
                    last = int(last_updated_file.readline().strip())
                    last_updated = last
                except Exception:
                    logging.exception("[" + Report.thread_name() + "] Could not parse " + last_updated_path)
        
        # Get updated metadata for a book, but only if the metadata is older than 5 minutes
        now = int(time.time())
        if now - last_updated > 300:
            success = UpdateMetadata.get_metadata(pipeline, epub)
            if not success:
                return False
        elif not UpdateMetadata.validate_metadata(pipeline, epub):
            return False
        
        if insert:
            return UpdateMetadata.insert_metadata(pipeline, epub, publication_format)
        else:
            return True
    
    @staticmethod
    def get_metadata(pipeline, epub):
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
        
        qb_record = ElementTree.parse(rdf_path).getroot()
        identifiers = qb_record.xpath("//nlbprod:*[starts-with(local-name(),'identifier.')]", namespaces=qb_record.nsmap)
        identifiers = [e.text for e in identifiers if re.match("^[\dA-Za-z._-]+$", e.text)]
        
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
        
        rdf_metadata = {"": os.path.join(metadata_dir, "metadata.rdf")}
        opf_metadata = {"": rdf_metadata[""].replace(".rdf",".opf")}
        html_metadata = {"": rdf_metadata[""].replace(".rdf",".html")}
        
        for f in UpdateMetadata.formats:
            format_id = re.sub(r"[^a-z0-9]", "", f.lower())
            rdf_metadata[f] = os.path.join(metadata_dir, "metadata-{}.rdf".format(format_id))
            opf_metadata[f] = rdf_metadata[f].replace(".rdf",".opf")
            html_metadata[f] = rdf_metadata[f].replace(".rdf",".html")
        
        for f in rdf_metadata:
            pipeline.utils.report.debug("rdf-join.xsl")
            pipeline.utils.report.debug("    metadata-dir = " + metadata_dir + "/")
            pipeline.utils.report.debug("    rdf-files    = " + " ".join(rdf_files))
            pipeline.utils.report.debug("    target       = " + rdf_metadata[f])
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "rdf-join.xsl"),
                                  template="main",
                                  target=rdf_metadata[f],
                                  parameters={
                                      "metadata-dir": metadata_dir + "/",
                                      "rdf-files": " ".join(rdf_files)
                                  })
            if not xslt.success:
                return False
            
            pipeline.utils.report.debug("rdf-to-opf.xsl")
            pipeline.utils.report.debug("    source = " + rdf_metadata[f])
            pipeline.utils.report.debug("    target = " + opf_metadata[f])
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "rdf-to-opf.xsl"),
                                  source=rdf_metadata[f],
                                  target=opf_metadata[f],
                                  parameters={
                                      "format": f,
                                      "update-identifier": "true"
                                  })
            if not xslt.success:
                return False
            
            pipeline.utils.report.debug("opf-to-html.xsl")
            pipeline.utils.report.debug("    source = " + opf_metadata[f])
            pipeline.utils.report.debug("    target = " + html_metadata[f])
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "opf-to-html.xsl"),
                                  source=opf_metadata[f],
                                  target=html_metadata[f])
            if not xslt.success:
                return False
        
        
        # ========== Validate metadata ==========
        
        if not UpdateMetadata.validate_metadata(pipeline, epub):
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
    def validate_metadata(pipeline, epub):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only update metadata in EPUBs")
            return False
        
        metadata_dir = os.path.join(UpdateMetadata.get_metadata_dir(), epub.identifier())
        
        rdf_metadata = {"": os.path.join(metadata_dir, "metadata.rdf")}
        opf_metadata = {"": rdf_metadata[""].replace(".rdf",".opf")}
        html_metadata = {"": rdf_metadata[""].replace(".rdf",".html")}
        
        for f in UpdateMetadata.formats:
            format_id = re.sub(r"[^a-z0-9]", "", f.lower())
            rdf_metadata[f] = os.path.join(metadata_dir, "metadata-{}.rdf".format(format_id))
            opf_metadata[f] = rdf_metadata[f].replace(".rdf",".opf")
            html_metadata[f] = rdf_metadata[f].replace(".rdf",".html")
        
        # Lag separat rapport/e-post for Bibliofil-metadata
        normarc_pipeline = DummyPipeline(uid=UpdateMetadata.uid, title=UpdateMetadata.title)
        normarc_pipeline.dir_reports = UpdateMetadata.dir_reports
        normarc_pipeline.dir_base = UpdateMetadata.dir_base
        normarc_pipeline.email_settings = UpdateMetadata.email_settings
        for util in pipeline.utils:
            if util != "report":
                normarc_pipeline.utils[util] = pipeline.utils[util]
        normarc_pipeline.utils.report = Report(normarc_pipeline)
        
        # Valider Bibliofil-metadata
        normarc_success = True
        marcxchange_paths = []
        for f in os.listdir(os.path.join(metadata_dir, "bibliofil")):
            if f.endswith(".xml"):
                marcxchange_paths.append(os.path.join(metadata_dir, "bibliofil", f))
        for marcxchange_path in marcxchange_paths:
            normarc_pipeline.utils.report.info("Validerer NORMARC ({})".format(os.path.basename(marcxchange_path).split(".")[0]))
            sch = Schematron(normarc_pipeline, schematron=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "validate-normarc.sch"),
                                       source=marcxchange_path)
            if not sch.success:
                normarc_pipeline.utils.report.error("Validering av Bibliofil-metadata feilet")
                normarc_success = False
        
        # Send rapport
        normarc_pipeline.utils.report.attachLog()
        if not normarc_success:
            normarc_pipeline.utils.report.email(UpdateMetadata.email_settings["smtp"],
                                                UpdateMetadata.email_settings["sender"],
                                                UpdateMetadata.config["librarians"],
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
        
        for f in rdf_metadata:
            pipeline.utils.report.info("Validerer ny OPF-metadata for " + (f if f else "åndsverk"))
            sch = Schematron(pipeline, schematron=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "validate-opf.sch"),
                                       source=opf_metadata[f])
            if not sch.success:
                pipeline.utils.report.error("Validering av OPF-metadata feilet")
                return False
            
            pipeline.utils.report.info("Validerer ny HTML-metadata for " + (f if f else "åndsverk"))
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
        
        assert not publication_format or publication_format in UpdateMetadata.formats, "Format for updating metadata, when specified, must be one of: {}".format(", ".join(UpdateMetadata.formats))
        
        # ========== Update metadata in EPUB ==========
        
        metadata_dir = os.path.join(UpdateMetadata.get_metadata_dir(), epub.identifier())
        
        format_id = re.sub(r"[^a-z0-9]", "", publication_format.lower())
        rdf_metadata = os.path.join(metadata_dir, "metadata-{}.rdf".format(format_id))
        opf_metadata = rdf_metadata.replace(".rdf",".opf")
        html_metadata = rdf_metadata.replace(".rdf",".html")
        
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
    
    def on_book_deleted(self):
        self.utils.report.should_email = False
    
    def on_book_modified(self):
        if "triggered" not in self.book["events"]:
            self.utils.report.should_email = False
            return
        
        epub = Epub(self, os.path.join(Pipeline.dirs[UpdateMetadata.uid]["out"], self.book["name"]))
        if UpdateMetadata.update(self, epub, insert=False):
            UpdateMetadata.trigger_metadata_pipelines(self, self.book["name"])
    
    @staticmethod
    def on_book_created(self):
        self.utils.report.should_email = False

if __name__ == "__main__":
    UpdateMetadata().run()
