#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import logging
import os
import sys
import threading
import time

from core.pipeline import DummyPipeline, Pipeline
from core.utils.epub import Epub
from core.utils.metadata import Metadata

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class UpdateMetadata(Pipeline):
    uid = "update-metadata"
    title = "Oppdater metadata"
    labels = []
    publication_format = None
    expected_processing_time = 180

    min_update_interval = 60 * 60 * 24  # 1 day
    max_metadata_emails_per_day = 5

    # if UpdateMetadata is not loaded, use a temporary directory
    # for storing metadata so that the static methods still work
    metadata_tempdir_obj = None

    logPipeline = None

    _metadataWatchThread = None

    metadata = None

    throttle_metadata_emails = True  # if enabled, will only send up to N automated metadata error emails per day, and only in working hours

    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self.shouldHandleBooks = False

        self.logPipeline = DummyPipeline(uid=self.uid + "-auto", title=self.title + " automatisk", inherit_config_from=UpdateMetadata)

        logging.info("Pipeline \"" + str(self.title) + "\" starting to watch metadata...")

        if not self.metadata:
            self.metadata = {}

        self._metadataWatchThread = threading.Thread(target=self._watch_metadata_thread, name="metadata watcher")
        self._metadataWatchThread.setDaemon(True)
        self._metadataWatchThread.start()

        logging.info("Pipeline \"" + str(self.title) + "\" started watching metadata (cache in " + self.dir_in + ")")

    def stop(self, *args, **kwargs):
        super().stop(*args, **kwargs)

        if self._metadataWatchThread and self._metadataWatchThread != threading.current_thread():
            self._metadataWatchThread.join()

        if self.logPipeline:
            self.logPipeline.stop()

        logging.info("Pipeline \"" + str(self.title) + "\" stopped watching metadata")

    def get_queue(self):
        return Metadata.queue

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
                        while len(Metadata.last_metadata_errors) > 0 and Metadata.last_metadata_errors[0] < now - 3600*24:
                            Metadata.last_metadata_errors = Metadata.last_metadata_errors[1:]
                        if len(Metadata.last_metadata_errors) >= Metadata.max_metadata_emails_per_day:
                            break  # only process N erroneous books per day (avoid getting flooded with errors)

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
                                logging.exception("Could not parse " + str(book_id) + "/last_updated")

                    if not last_updated or now - last_updated > self.min_update_interval:
                        needs_update = True

                    if needs_update:
                        self.logPipeline.utils.report.debug("Updating metadata for {}, since it's been a long time since last it was updated".format(book_id))

                        epub = Epub(self.logPipeline, os.path.join(Pipeline.dirs[UpdateMetadata.uid]["out"], book_id))
                        Metadata.get_metadata(self.logPipeline, epub)

                        now = int(time.time())
                        if book_id not in self.metadata:
                            self.metadata[book_id] = {}
                        self.metadata[book_id]["last_updated"] = now
                        if not os.path.exists(metadata_dir):
                            os.makedirs(metadata_dir)
                        with open(last_updated_path, "w") as last_updated_file:
                            last_updated_file.write(str(now))

            except Exception:
                logging.exception("An error occured while checking for updates in metadata")

        self.running = False

    def on_book_deleted(self):
        self.utils.report.should_email = False
        return True

    def on_book_modified(self):
        if "triggered" not in self.book["events"]:
            self.utils.report.should_email = False
            return False

        book_path = os.path.join(Pipeline.dirs[UpdateMetadata.uid]["out"], self.book["name"])
        if not os.path.exists(book_path):
            self.utils.report.error("Boken finnes ikke: {}".format(self.book["name"]))
            return False

        epub = Epub(self, book_path)
        if Metadata.update(self, epub, insert=False, force_update=True):
            Metadata.trigger_metadata_pipelines(self, self.book["name"])

        return True

    def on_book_created(self):
        self.utils.report.should_email = False
        return True


if __name__ == "__main__":
    UpdateMetadata().run()
