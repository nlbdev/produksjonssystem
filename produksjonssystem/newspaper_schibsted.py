#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import logging
import os
import re
import shutil
import sys
import tempfile
import threading
import time

from dotmap import DotMap

from core.pipeline import DummyPipeline, Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.filesystem import Filesystem
from core.utils.report import Report
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
            for date in os.listdir(self.dir_in):
                if re.match(r"^\d\d\d\d-\d\d-\d\d$", date):
                    logging.info("Lager avis for: " + date)
                    self.trigger(date)

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
        date = re.sub(r"[^\d]", "", self.book["name"])
        if len(date) <= 0:
            self.utils.report.error("Ingen tall i mappenavn: {}".format(self.book["name"]))
            return False

        newspapers = {
            "Aftenposten": {
                "id": "611823",
                "title": "Aftenposten"
            },
            "Bergens_Tidende": {
                "id": "618720",
                "title": "Bergens Tidende"
            },
            "Faedrelandsvennen": {
                "id": "618363",
                "title": "Fædrelandsvennen"
            },
            "Stavanger_Aftenblad": {
                "id": "618360",
                "title": "Stavanger Aftenblad"
            }
        }
        files = os.listdir(self.book["source"])
        for paper in newspapers:
            files_paper = ""
            for file in files:
                if file.startswith(paper):
                    files_paper += file + ","
            newspapers[paper]["files"] = files_paper

        # Use xslt to transform to correct dc:identifier
        for paper in newspapers:
            self.utils.report.info("Henter feed for " + paper)
            temp_xml_obj = tempfile.NamedTemporaryFile()
            temp_xml = temp_xml_obj.name
            self.utils.report.info("Setter sammen feed for " + paper)
            xslt = Xslt(self,
                        parameters={"files": newspapers[paper]["files"], "basepath": self.book["source"]},
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
                        parameters={
                            "identifier": newspapers[paper]["id"],
                            "title": newspapers[paper]["title"],
                            "date": time.strftime('%Y-%m-%d')
                        },
                        stylesheet=os.path.join(Xslt.xslt_dir, self.uid, "schibsted-to-dtbook.xsl"),
                        source=temp_xml,
                        target=temp_dtbook)

            if not xslt.success:
                self.utils.report.error("Transformering av html for {} med xslt feilet".format(paper))
                self.utils.report.title = self.title + ": feilet 😭👎"
                return False

            archived_path, stored = self.utils.filesystem.storeBook(temp_dtbook,
                                                                    newspapers[paper]["id"] + date,
                                                                    parentdir=self.parentdirs["archive"],
                                                                    file_extension="xml")
            self.utils.report.attachment(None, archived_path, "DEBUG")

            if date == time.strftime('%Y%m%d'):
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
