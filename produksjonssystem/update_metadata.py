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
from core.utils.daisy_pipeline import DaisyPipelineJob

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class UpdateMetadata(Pipeline):
    uid = "update-metadata"
    title = "Oppdater metadata"
    
    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "xslt"))
    dp2_home = os.getenv("PIPELINE2_HOME", "/opt/daisy-pipeline2")
    dp2_cli = dp2_home + "/cli/dp2"
    saxon_cli = "java -jar " + os.path.join(dp2_home, "system/framework/org.daisy.libs.saxon-he-9.5.1.5.jar")
    
    quickbase_record_id_rows = [ "13", "20", "24", "28", "31", "32", "38" ]
    quickbase_isbn_id_rows = [ "7" ]
    
    logPipeline = DummyPipeline(uid=uid, title=title)
    
    first_job = True # Will be set to false after first job is triggered
    
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
                day = 10 # 60 * 60 * 24
                
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
                        epub = Epub(None, os.path.join(os.path.join(Pipeline.dirs[UpdateMetadata.uid]["out"], book_id)))
                        
                        try:
                            UpdateMetadata.update(self.logPipeline, epub)
                        except Exception:
                            logging.exception("[" + Report.thread_name() + "] An unexpected error occured while updating metadata for " + str(book_id))
                        
                        now = int(time.time())
                        if not book_id in self.metadata:
                            self.metadata[book_id] = {}
                        self.metadata[book_id]["last_updated"] = now
                        with open(last_updated_path, "w") as last_updated_file:
                            last_updated_file.write(str(now))
                
            except Exception:
                logging.exception("[" + Report.thread_name() + "] An error occured while checking for updates in metadata")
    
    @staticmethod
    def update(pipeline, epub):
        if not isinstance(epub, Epub) or not epub.isepub():
            pipeline.utils.report.error("Can only update metadata in EPUBs")
            return
        
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
        
        # path to directory with metadata from Quickbase / Bibliofil / Bokbasen
        metadata_dir = os.path.join(Pipeline.dirs[UpdateMetadata.uid]["in"], epub.identifier())
        if not os.path.exists(metadata_dir):
            os.makedirs(metadata_dir)
        
        with open(os.path.join(metadata_dir, "last_updated"), "w") as last_updated:
            last_updated.write(str(int(time.time())))
        
        rdf_files = []
        
        pipeline.utils.report.info("quickbase-record-to-rdf.xsl")
        rdf_path = os.path.join(metadata_dir, 'quickbase-record.rdf')
        pipeline.utils.report.info("    source = " + os.path.join(metadata_dir, 'quickbase-record.xml'))
        pipeline.utils.report.info("    target = " + os.path.join(metadata_dir, 'quickbase-record.html'))
        pipeline.utils.report.info("    rdf    = " + rdf_path)
        UpdateMetadata.get_quickbase_record(pipeline, epub.identifier(), os.path.join(metadata_dir, 'quickbase-record.xml'))
        Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "quickbase-record-to-rdf.xsl"),
                       source=os.path.join(metadata_dir, 'quickbase-record.xml'),
                       target=os.path.join(metadata_dir, 'quickbase-record.html'),
                       parameters={ "rdf-xml-path": rdf_path })
        rdf_files.append(os.path.basename(rdf_path))
        
        qb_record = ElementTree.parse(rdf_path).getroot()
        identifiers = qb_record.xpath("//nlbprod:*[starts-with(local-name(),'identifier.')]", namespaces=qb_record.nsmap)
        identifiers = [e.text for e in identifiers if re.match("^[\dA-Za-z._-]+$", e.text)]
        
        for identifier in identifiers:
            pipeline.utils.report.info("bibliofil-to-rdf.xsl")
            rdf_path = os.path.join(metadata_dir, 'bibliofil-' + identifier + '.rdf')
            pipeline.utils.report.info("    source = " + os.path.join(metadata_dir, 'bibliofil-' + identifier + '.xml'))
            pipeline.utils.report.info("    target = " + os.path.join(metadata_dir, 'bibliofil-' + identifier + '.html'))
            pipeline.utils.report.info("    rdf    = " + rdf_path)
            UpdateMetadata.get_bibliofil(pipeline, identifier, os.path.join(metadata_dir, 'bibliofil-' + identifier + '.xml'))
            Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "bibliofil-to-rdf.xsl"),
                           source=os.path.join(metadata_dir, 'bibliofil-' + identifier + '.xml'),
                           target=os.path.join(metadata_dir, 'bibliofil-' + identifier + '.html'),
                           parameters={ "rdf-xml-path": rdf_path })
            rdf_files.append(os.path.basename(rdf_path))
            
            pipeline.utils.report.info("quickbase-isbn-to-rdf.xsl")
            rdf_path = os.path.join(metadata_dir, 'quickbase-isbn-' + identifier + '.rdf')
            pipeline.utils.report.info("    source = " + os.path.join(metadata_dir, 'quickbase-isbn-' + identifier + '.xml'))
            pipeline.utils.report.info("    target = " + os.path.join(metadata_dir, 'quickbase-isbn-' + identifier + '.html'))
            pipeline.utils.report.info("    rdf    = " + rdf_path)
            UpdateMetadata.get_quickbase_isbn(pipeline, identifier, os.path.join(metadata_dir, 'quickbase-isbn-' + identifier + '.xml'))
            Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "quickbase-isbn-to-rdf.xsl"),
                           source=os.path.join(metadata_dir, 'quickbase-isbn-' + identifier + '.xml'),
                           target=os.path.join(metadata_dir, 'quickbase-isbn-' + identifier + '.html'),
                           parameters={ "rdf-xml-path": rdf_path })
            rdf_files.append(os.path.basename(rdf_path))
        
        pipeline.utils.report.info("rdf-join.xsl")
        pipeline.utils.report.info("    metadata-dir = " + metadata_dir + "/")
        pipeline.utils.report.info("    rdf-files    = " + " ".join(rdf_files))
        pipeline.utils.report.info("    target       = " + os.path.join(metadata_dir, "metadata.rdf"))
        Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "rdf-join.xsl"),
                       template="main",
                       target=os.path.join(metadata_dir, "metadata.rdf"),
                       parameters={
                           "metadata-dir": metadata_dir + "/",
                           "rdf-files": " ".join(rdf_files)
                       })
        
        # TODO
        pipeline.utils.report.info(epub.identifier() + ": TODO: oppdater metadata")
        pipeline.utils.report.info("OPF: " + opf)
        pipeline.utils.report.info("metadata: " + metadata_dir)
    
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
        
        xslt_job = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "quickbase-get.xsl"),
                                  source=UpdateMetadata.sources["quickbase"]["records"],
                                  target=target,
                                  parameters={ "book-id-rows": str.join(" ", UpdateMetadata.quickbase_record_id_rows), "book-id": book_id })
    
    @staticmethod
    def get_quickbase_isbn(pipeline, book_id, target):
        pipeline.utils.report.info("Henter metadata fra Quickbase (ISBN) for " + str(book_id) + "...")
        
        # Book id rows:
        #     7: "Tilvekstnummer"
        
        xslt_job = Xslt(pipeline, stylesheet=os.path.join(UpdateMetadata.xslt_dir, UpdateMetadata.uid, "quickbase-get.xsl"),
                                  source=UpdateMetadata.sources["quickbase"]["isbn"],
                                  target=target,
                                  parameters={ "book-id-rows": str.join(" ", UpdateMetadata.quickbase_isbn_id_rows), "book-id": book_id })
    
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
