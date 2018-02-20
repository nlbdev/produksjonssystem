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
from threading import Thread

from core.pipeline import Pipeline, DummyPipeline
from core.utils.epub import Epub
from core.utils.xslt import Xslt
from core.utils.report import Report
from core.utils.schematron import Schematron
from core.utils.daisy_pipeline import DaisyPipelineJob

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class UpdateMetadata(Pipeline):
    uid = "update-metadata"
    title = "Oppdater metadata"
    
    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "xslt"))
    
    # if UpdateMetadata is not loaded, use a temporary directory
    # for storing metadata so that the static methods still work
    metadata_tempdir_obj = None
    
    quickbase_record_id_rows = [ "13", "20", "24", "28", "31", "32", "38" ]
    quickbase_isbn_id_rows = [ "7" ]
    
    logPipeline = DummyPipeline(uid=uid, title=title)
    
    _metadataWatchThread = None
    _shouldWatchMetadata = True
    
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
                day = 60 * 60 * 24
                
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
                    
                    if not last_updated or now - last_updated > 1 * day:
                        needs_update = True
                    
                    if needs_update:
                        epub = Epub(self.logPipeline, os.path.join(os.path.join(Pipeline.dirs[UpdateMetadata.uid]["out"], book_id)))
                        
                        try:
                            UpdateMetadata.update(self.logPipeline, epub)
                        except Exception:
                            logging.exception("[" + Report.thread_name() + "] An unexpected error occured while updating metadata for " + str(book_id))
                        
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
    def update(pipeline, epub):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only update metadata in EPUBs")
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
        metadata_dir = None
        if UpdateMetadata.uid in Pipeline.dirs:
            metadata_dir = os.path.join(Pipeline.dirs[UpdateMetadata.uid]["in"], edition_identifier)
        else:
            if not UpdateMetadata.metadata_tempdir_obj:
                UpdateMetadata.metadata_tempdir_obj = tempfile.TemporaryDirectory(prefix="metadata-")
                pipeline.utils.report.info("Using temporary directory for metadata: " + UpdateMetadata.metadata_tempdir_obj.name)
            metadata_dir = os.path.join(UpdateMetadata.metadata_tempdir_obj.name, edition_identifier)
        pipeline.utils.report.attachment(None, metadata_dir, "DEBUG")
        os.makedirs(metadata_dir, exist_ok=True)
        os.makedirs(metadata_dir + '/quickbase', exist_ok=True)
        os.makedirs(metadata_dir + '/bibliofil', exist_ok=True)
        
        with open(os.path.join(metadata_dir, "last_updated"), "w") as last_updated:
            last_updated.write(str(int(time.time())))
        
        rdf_files = []
        
        opf_path = os.path.join(epub.book_path, epub.opf_path())
        if not os.path.exists(opf_path):
            pipeline.utils.report.error("Could not read OPF file. Maybe the EPUB is zipped?")
            return False
        
        
        # ========== Collect and combine metadata from sources ==========
        
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
        
        pipeline.utils.report.debug("rdf-join.xsl")
        pipeline.utils.report.debug("    metadata-dir = " + metadata_dir + "/")
        pipeline.utils.report.debug("    rdf-files    = " + " ".join(rdf_files))
        pipeline.utils.report.debug("    target       = " + os.path.join(metadata_dir, "metadata.rdf"))
        xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "rdf-join.xsl"),
                              template="main",
                              target=os.path.join(metadata_dir, "metadata.rdf"),
                              parameters={
                                  "metadata-dir": metadata_dir + "/",
                                  "rdf-files": " ".join(rdf_files)
                              })
        if not xslt.success:
            return False
        
        pipeline.utils.report.debug("rdf-to-opf.xsl")
        opf_metadata = os.path.join(metadata_dir, "metadata.opf")
        pipeline.utils.report.debug("    source = " + os.path.join(metadata_dir, "metadata.rdf"))
        pipeline.utils.report.debug("    target = " + opf_metadata)
        xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "rdf-to-opf.xsl"),
                              source=os.path.join(metadata_dir, "metadata.rdf"),
                              target=opf_metadata)
        if not xslt.success:
            return False
        
        pipeline.utils.report.debug("opf-to-html.xsl")
        html_head = os.path.join(metadata_dir, "metadata.html")
        pipeline.utils.report.debug("    source = " + opf_metadata)
        pipeline.utils.report.debug("    target = " + html_head)
        xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "opf-to-html.xsl"),
                              source=opf_metadata,
                              target=html_head)
        if not xslt.success:
            return False
        
        
        # ========== Validate metadata ==========
        
        pipeline.utils.report.debug("validate-opf.sch")
        sch = Schematron(pipeline, schematron=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "validate-opf.sch"),
                                   source=opf_metadata)
        if not sch.success:
            pipeline.utils.report.error("Schematron validation failed")
            return False
        
        
        # ========== Update metadata in EPUB ==========
        
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
        if not new_identifier == edition_identifier:
            pipeline.utils.report.error("Expected identifier to be '{}', but in the updated metadata is was '{}'".format(edition_identifier, new_identifier))
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
            pipeline.utils.report.debug("    html_head = " + html_head)
            xslt = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "update-html.xsl"),
                                  source=html_path,
                                  target=updated_file,
                                  parameters={
                                    "html_head": html_head,
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
            pipeline.utils.report.info("Metadata in {} was updated".format(edition_identifier))
            
        else:
            pipeline.utils.report.info("Metadata in {} is already up to date".format(edition_identifier))
        
        return bool(updates)
    
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
    
    def on_book_deleted(self):
        self.utils.report.should_email = False
    
    def on_book_modified(self):
        if "triggered" not in self.book["events"]:
            self.utils.report.should_email = False
            return
        
        try:
            book_path = os.path.join(self.dir_out, self.book["name"])
            if not os.path.exists(book_path):
                self.utils.report.error("Book \"" + self.book["name"] + "\" does not exist in " + self.dir_out)
                return
            epub = Epub(self, os.path.join(self.dir_out, self.book["name"]))
            UpdateMetadata.update(self, epub)
        except Exception:
            logging.exception("[" + Report.thread_name() + "] An unexpected error occured while updating metadata for " + self.book["name"])
            self.utils.report.error("An unexpected error occured while updating metadata for " + self.book["name"])
    
    def on_book_created(self):
        self.utils.report.should_email = False

if __name__ == "__main__":
    UpdateMetadata().run()
