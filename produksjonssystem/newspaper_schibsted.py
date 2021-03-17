#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import os
import re
import sys
import tempfile
import threading
import time

from core.pipeline import DummyPipeline, Pipeline
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NewspaperSchibsted(Pipeline):
    uid = "newspaper-schibsted"
    title = "Avisproduksjon Schibsted"
    labels = ["Daisy 2.02"]
    logPipeline = None
    publication_format = "Lydbok"
    expected_processing_time = 300

    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self._triggerNewspaperThread = threading.Thread(target=self._trigger_Newspaper_thread, name=self.uid + "-watcher")
        self._triggerNewspaperThread.setDaemon(True)
        self._triggerNewspaperThread.start()

        logging.info("Pipeline \"" + str(self.title) + "\" started watching for todays schibsted newspapers")

    def stop(self, *args, **kwargs):
        super().stop(*args, **kwargs)

        if self._triggerNewspaperThread and self._triggerNewspaperThread != threading.current_thread():
            self._triggerNewspaperThread.join()

        logging.info("Pipeline \"" + str(self.title) + "\" stopped")

    def _trigger_Newspaper_thread(self):
        logging.info("Started watching for Schibsted newspapers")
        last_check = 0
        # If feed found trigger newspaper

        self.watchdog_bark()
        while self.shouldRun:
            time.sleep(5)
            self.watchdog_bark()

            if not self.dirsAvailable():
                logging.info("Directory with Schibsted newspapers are not available")
                continue

            max_update_interval = 300
            if time.time() - last_check < max_update_interval:
                continue

            last_check = time.time()
            for date in os.listdir(self.dir_in):
                if not self.shouldRun:
                    logging.error("Systemet er i ferd med å slå seg av, og avistråden blir derfor ikke ferdig kjørt.")
                    break

                if re.match(r"^\d\d\d\d-\d\d-\d\d$", date):
                    date_numbers = re.sub(r"^\d\d(\d\d)-(\d\d)-(\d\d)$", r"\1\2\3", date)
                    already_produced = False
                    for book in os.listdir(self.dir_out):
                        if book.endswith(date_numbers+".xml"):
                            already_produced = True
                    if not already_produced:
                        logging.info("Lager avis for: " + date)
                        self.trigger(date)

        logging.info("Stopped watching for Schibsted newspapers")

    def on_book_deleted(self):
        self.utils.report.should_email = False
        if self.stopAfterNJobs > 0:
            self.stopAfterNJobs += 1
        return True

    def on_book_modified(self):
        # Produce newspaper only when it was automatically triggered (by the newspaper trigger thread)
        main_event = Pipeline.get_main_event(self.book)
        if main_event != "autotriggered":
            self.utils.report.should_email = False
            self.utils.report.info("Newpaper was not automatically triggered. Ignoring '{}' event.".format(main_event))
            if self.stopAfterNJobs > 0:
                self.stopAfterNJobs += 1
            return True

        return self.on_book()

    def on_book_created(self):
        self.utils.report.should_email = False
        self.utils.report.info("Newpaper was not automatically triggered. Ignoring 'created' event.")
        if self.stopAfterNJobs > 0:
            self.stopAfterNJobs += 1
        return True

    def on_book(self):
        date_iso = self.book["name"]
        if not re.match(r"^\d\d\d\d-\d\d-\d\d$", date_iso):
            self.utils.report.error("Ugyldig mappenavn: {}".format(self.book["name"]))
            return False
        date_numbers = re.sub(r"^\d\d(\d\d)-(\d\d)-(\d\d)$", r"\1\2\3", date_iso)

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
            if len(newspapers[paper]["files"]) == 0:
                self.utils.report.info("Ingen artikler for {} i dag. {} blir ikke produsert for {}.".format(newspapers[paper]["title"],
                                                                                                            newspapers[paper]["title"],
                                                                                                            date_iso))
                continue

            self.utils.report.info("Henter feed for " + paper)
            temp_xml_obj = tempfile.NamedTemporaryFile()
            temp_xml = temp_xml_obj.name
            if os.path.isdir("/tmp"):
                temp_xml = "/tmp/{}_{}_joined.xml".format(date_iso, paper)  # for easier debugging
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
                            "date": date_iso
                        },
                        stylesheet=os.path.join(Xslt.xslt_dir, self.uid, "schibsted-to-dtbook.xsl"),
                        source=temp_xml,
                        target=temp_dtbook)

            if not xslt.success:
                self.utils.report.error("Transformering av html for {} med xslt feilet".format(paper))
                self.utils.report.title = self.title + ": feilet 😭👎"
                return False

            archived_path, stored = self.utils.filesystem.storeBook(temp_dtbook,
                                                                    newspapers[paper]["id"] + date_numbers,
                                                                    file_extension="xml")
            self.utils.report.attachment(None, archived_path, "DEBUG")

        self.utils.report.info("Dagens Schibsted-aviser er ferdig produsert")
        self.utils.report.title = self.title + ": " + " dagens Schibsted-aviser ble produsert 👍😄"
        return True


class DummyTtsNewspaperSchibsted(DummyPipeline):
    working_dir = None

    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self.working_dir = os.path.normpath(os.path.join(self.dir_in, '..', 'daisy'))

    def get_status(self):
        if self.working_dir and os.path.isdir(self.working_dir):
            for newspaper in os.listdir(self.working_dir):
                temp_dir = os.path.join(self.working_dir, newspaper, "pipeline__temp", "speechgen")
                if not os.path.isdir(temp_dir):
                    continue
                try:
                    for root, dirs, files in os.walk(temp_dir):
                        for file in files:
                            path = os.path.join(root, file)
                            if not file.endswith(".wav"):
                                # ignore non-audio file
                                continue
                            if not os.path.isfile(path):
                                # skip file if it's been deleted (mitigate race condition)
                                continue
                            if time.time() - os.stat(path).st_mtime > 60:
                                # ignore old file
                                continue

                            # this newspaper has a newly modified wav file: assume that it's currently being produced
                            return newspaper
                except FileNotFoundError:
                    pass  # ignore

        return super().get_status()

    def get_progress(self):
        newspaper = self.get_status()  # status is the name of the newspaper, if a newspaper is being processed

        if self.working_dir and os.path.isdir(self.working_dir) and newspaper in os.listdir(self.working_dir):
            temp_dir = os.path.join(self.working_dir, newspaper, "pipeline__temp", "speechgen")
            if os.path.isdir(temp_dir):
                done = 0
                not_done = 0
                for root, dirs, files in os.walk(temp_dir):
                    for file in files:
                        path = os.path.join(root, file)
                        if not file.endswith(".wav"):
                            # ignore non-audio file
                            continue

                        if os.path.isfile(path):  # mitigate race condition where files are deleted
                            if os.stat(path).st_size == 0:
                                not_done += 1
                            else:
                                done += 1

                total = done + not_done
                if total > 0:
                    return "{} %".format(round(done / total * 100))

        return super().get_progress()


if __name__ == "__main__":
    NewspaperSchibsted().run()
