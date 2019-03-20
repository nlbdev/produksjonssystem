#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import logging
import os
import shutil
import sys
import tempfile
import threading
import time

from dotmap import DotMap
from core.utils.filesystem import Filesystem
from core.utils.report import Report
from core.pipeline import DummyPipeline, Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NewspaperSchibsted(Pipeline):
    uid = "newspaper-schibsted"
    title = "Avisproduksjon Schibsted"
    labels = ["Daisy 2.02"]
    logPipeline = None
    year_month = ""
    publication_format = "Lydbok"
    expected_processing_time = 20
    parentdirs = {
                      "latest": "latest",
                      "archive": "archive"
                      }

    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self._triggerNewspaperThread = threading.Thread(target=self._trigger_Newspaper_thread, name="Newspaper thread")
        self._triggerNewspaperThread.setDaemon(True)
        self._triggerNewspaperThread.start()

        logging.info("Pipeline \"" + str(self.title) + "\" started watching for todays schibsted newspapers")

    def stop(self, *args, **kwargs):
        super().stop(*args, **kwargs)

        if self._triggerNewspaperThread and self._triggerNewspaperThread != threading.current_thread():
            self._triggerNewspaperThread.join()

        logging.info("Pipeline \"" + str(self.title) + "\" stopped")

    def _trigger_Newspaper_thread(self):
        last_check = 0
        # If feed found trigger newspaper
        while self._dirsAvailable and self._shouldRun:
            time.sleep(5)
            max_update_interval = 60 * 5
            if time.time() - last_check < max_update_interval:
                continue

            last_check = time.time()
            today = time.strftime('%Y-%m-%d')
            if today in os.listdir(self.dir_in):
                logging.info("Lager avis for: " + today)
                self.trigger(today)

    def on_book_deleted(self):
        return True

    def on_book_modified(self):
        if "autotriggered" not in self.book["events"]:
            self.utils.report.should_email = False
            return True
        return self.on_book()

    def on_book_created(self):
        return True

    def on_book(self):
        today = time.strftime('%Y%m%d')
        newspapers = {"Aftenposten": "611823", "Bergens_tidende": "618720", "Faedrelandsvennen": "618363", "Stavanger_aftenblad": "618360"}
        files = os.listdir(self.book["source"])
        newspapers_config = {}
        for paper in newspapers:
            files_paper = ""
            for file in files:
                if file.startswith(paper):
                    files_paper += file + ","
            newspapers_config[paper] = files_paper

        # Use xslt to transform to correct dc:identifier
        for paper in newspapers_config:
            self.utils.report.info("Henter feed for " + paper)
            temp_xml_obj = tempfile.NamedTemporaryFile()
            temp_xml = temp_xml_obj.name
            self.utils.report.info("Setter sammen feed for " + paper)
            xslt = Xslt(self,
                        parameters={"files": newspapers_config[paper], "basepath": self.book["source"]},
                        stylesheet=os.path.join(Xslt.xslt_dir, self.uid, "schibsted-join.xsl"),
                        template="main",
                        target=temp_xml)

            if not xslt.success:
                self.utils.report.error("Transformering av html for {} med xslt feilet".format(paper))
                self.utils.report.title = self.title + ": feilet 😭👎"
                return False

            temp_dtbook_obj = tempfile.NamedTemporaryFile()
            temp_dtbook = temp_dtbook_obj.name
            self.utils.report.info("Lager dtbook med xslt for " + paper)
            xslt = Xslt(self,
                        stylesheet=os.path.join(Xslt.xslt_dir, self.uid, "schibsted-to-dtbook.xsl"),
                        source=temp_xml,
                        target=temp_dtbook)

            if not xslt.success:
                self.utils.report.error("Transformering av html for {} med xslt feilet".format(paper))
                self.utils.report.title = self.title + ": feilet 😭👎"
                return False

            archived_path, stored = self.utils.filesystem.storeBook(temp_dtbook,
                                                                    newspapers[paper] + today,
                                                                    parentdir=self.parentdirs["archive"],
                                                                    file_extension="xml")
            self.utils.report.attachment(None, archived_path, "DEBUG")
            archived_path, stored = self.utils.filesystem.storeBook(temp_dtbook,
                                                                    paper,
                                                                    parentdir=self.parentdirs["latest"],
                                                                    file_extension="xml")
            self.utils.report.attachment(None, archived_path, "DEBUG")

        self.utils.filesystem.deleteSource()
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info("Dagens Schibsted aviser er ferdig produsert")
        self.utils.report.title = self.title + ": " + " dagens Schibsted aviser ble produsert 👍😄"
        return True


if __name__ == "__main__":
    NewspaperSchibsted().run()
