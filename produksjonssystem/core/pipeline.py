#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import inspect
import logging
import math
import os
import re
import sys
import tempfile
import threading
import time
import traceback
from copy import deepcopy
from pathlib import Path
from threading import RLock, Thread

from core.utils.epub import Epub
from core.utils.filesystem import Filesystem
from core.utils.metadata import Metadata
from core.utils.report import DummyReport, Report
from dotmap import DotMap

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Pipeline():
    """
    Base class for creating pipelines.
    Do not override methods or variables starting with underscore (_).
    """

    _i18n = {
        "An error occured while monitoring of": "En feil oppstod ved overvåking av",
        "An error occured while checking for book events": "En feil oppstod ved håndtering av bokhendelse"
    }

    _queue_lock = None
    _md5_lock = None

    _dir_trigger_obj = None  # store TemporaryDirectory object in instance so that it's not cleaned up
    pipelines = []

    # The current book
    book = None

    # Directories
    dir_in = None
    dir_out = None
    dir_reports = None
    dir_trigger = None
    dir_base = None
    parentdirs = {}

    # These ones are meant for use in static contexts
    dirs = None  # dirs are built in Pipeline.start_common: Pipeline.dirs[uid][in|out|reports|trigger]
    dirs_ranked = None  # dirs_ranked are built by the coordinator thread (i.e. Produksjonssystem in run.py)

    # Other configuration
    config = None    # instance config
    environment = {}  # global config

    # constants (set during instantiation)
    running = False
    shouldHandleBooks = True
    _inactivity_timeout = 10
    _bookHandlerThread = None
    _bookRetryThread = None
    _bookMonitorThread = None
    _bookRetryInNotOutThread = None
    _dirsAvailable = False
    _shouldRun = True
    _stopAfterFirstJob = False

    # static (shared by all pipelines)
    _triggerDirThread = None

    # dynamic (reset on stop(), changes over time)
    _queue = None
    _md5 = None
    threads = None
    progress_text = None
    progress_log = None
    progress_start = None
    expected_processing_time = 60  # can be overridden in each pipeline

    # utility classes; reconfigured every time a book is processed to simplify function signatures
    utils = None

    # email settings
    email_settings = None

    # should be overridden when extending this class
    uid = None
    title = None
    labels = []
    publication_format = None

    def __init__(self, retry_all=False, retry_missing=False, overwrite=True):
        self.utils = DotMap()
        self.utils.report = None
        self.utils.filesystem = None
        self.overwrite = overwrite
        self.retry_all = retry_all
        self.retry_missing = retry_missing
        self._queue_lock = RLock()
        self._md5_lock = RLock()
        with self._queue_lock:
            self._queue = []
        super().__init__()

    def start_common(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None, dir_base=None, config=None):
        if not dir_in:
            dir_in = os.environ.get("DIR_IN")
        if not dir_out:
            dir_out = os.environ.get("DIR_OUT")
        if not dir_reports:
            dir_reports = os.environ.get("DIR_REPORTS")
        if not email_settings:
            email_settings = {
                "smtp": {},
                "sender": "prodsys@example.org",
                "recipients": []
            }
        if not dir_base:
            dir_base = os.getenv("BASE_DIR", dir_in)

        stop_after_first_job = os.getenv("STOP_AFTER_FIRST_JOB", False)

        assert (
            dir_reports is not None and len(dir_reports) > 0 and os.path.exists(dir_reports)
            ), "The environment variable DIR_REPORTS must be specified, and must point to a directory that exists."
        assert isinstance(dir_base, str) or isinstance(dir_base, dict), "Base directories could not be determined"
        assert (
            not stop_after_first_job or stop_after_first_job in ["1", "true", "0", "false"]
            ), "The environment variable STOP_AFTER_FIRST_JOB, if defined, must be \"true\"/\"false\" (or \"1\"/\"0\")."

        if isinstance(dir_base, str):
            base_dirs = {}
            for d in dir_base.split(" "):
                assert "=" in d, (
                    "Base directories must be a space-separated list with name=path pairs. " +
                    "For instance: master=/media/archive. " +
                    "Note that paths can not contain space characters."
                    )
                archive_name = d.split("=")[0]
                archive_path = os.path.normpath(d.split("=")[1]) + "/"
                base_dirs[archive_name] = archive_path
            dir_base = base_dirs

        self._stopAfterFirstJob = False
        if stop_after_first_job in ["true", "1"]:
            self._stopAfterFirstJob = True

        if dir_in:
            self.dir_in = str(os.path.normpath(dir_in)) + '/'
        if dir_out:
            self.dir_out = str(os.path.normpath(dir_out)) + '/'
        self.dir_reports = str(os.path.normpath(dir_reports)) + '/'
        self.dir_base = dir_base
        self.email_settings = email_settings
        self.config = config if config else {}

        # progress variable for this pipeline instance
        self.progress_text = ""
        self.progress_log = []
        self.progress_start = -1

        # make dirs available from static contexts
        if not Pipeline.dirs:
            Pipeline.dirs = {}
        if self.uid not in Pipeline.dirs:
            Pipeline.dirs[self.uid] = {}
        Pipeline.dirs[self.uid]["in"] = self.dir_in
        Pipeline.dirs[self.uid]["out"] = self.dir_out
        Pipeline.dirs[self.uid]["reports"] = self.dir_reports
        Pipeline.dirs[self.uid]["base"] = self.dir_base

    def start(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None, dir_base=None, config=None):
        logging.info("Pipeline \"" + str(self.title) + "\" starting...")

        # common code shared with DummyPipeline
        self.start_common(inactivity_timeout=inactivity_timeout,
                          dir_in=dir_in,
                          dir_out=dir_out,
                          dir_reports=dir_reports,
                          email_settings=email_settings,
                          dir_base=dir_base,
                          config=config)

        assert (
            self.dir_in is not None and len(self.dir_in) > 0
            ), "The environment variable DIR_IN must be specified, and must point to a directory."
        assert (
            self.dir_out is not None and len(self.dir_out) > 0 and os.path.exists(self.dir_out)
            ), "The environment variable DIR_OUT must be specified, and must point to a directory that exists."

        for p in self.parentdirs:
            os.makedirs(os.path.join(self.dir_out, self.parentdirs[p]), exist_ok=True)

        self.dir_trigger = os.getenv("TRIGGER_DIR")
        if self.dir_trigger:
            self.dir_trigger = os.path.join(self.dir_trigger, "pipelines", self.uid)
            try:
                if not os.path.exists(self.dir_trigger):
                    os.makedirs(self.dir_trigger)
                with open(os.path.join(self.dir_trigger, "_name"), "w") as namefile:
                    namefile.write("{} # {}\n".format(self.uid, self.title))
            except Exception:
                logging.exception("" + "Could not create trigger directory: " + self.dir_trigger)
        else:
            self._dir_trigger_obj = tempfile.TemporaryDirectory(prefix="produksjonssystem-", suffix="-trigger-" + self.uid)
            self.dir_trigger = self._dir_trigger_obj.name

        # make trigger dir available from static contexts
        Pipeline.dirs[self.uid]["trigger"] = self.dir_trigger

        type(self).dir_in = self.dir_in
        type(self).dir_out = self.dir_out
        type(self).dir_reports = self.dir_reports
        type(self).dir_base = self.dir_base
        type(self).email_settings = self.email_settings
        type(self).config = self.config

        if Filesystem.ismount(self.dir_in):
            logging.debug(self.dir_in +
                          " is the root of a mounted filesystem. " +
                          "Please use subdirectories instead, so that mounting/unmounting is not interpreted as file changes.")
        if not os.path.isdir(self.dir_in):
            logging.error(self.dir_in +
                          " is not available. Will not start watching.")
            return
        self._inactivity_timeout = inactivity_timeout

        self.threads = []

        with self._md5_lock:
            self._md5 = {}
        dir_list = os.listdir(self.dir_in)
        md5_count = 0
        self.progress_text = "0 / {}".format(len(dir_list))
        for f in dir_list:
            if not (self._dirsAvailable and self._shouldRun):
                with self._md5_lock:
                    self._md5 = {}
                return  # break loop if we're shutting down the system
            self._update_md5(f)
            md5_count += 1
            self.progress_text = "{} / {}".format(md5_count, len(dir_list))
        self.progress_text = ""

        self.shouldHandleBooks = True
        self._dirsAvailable = True

        self._bookMonitorThread = Thread(target=self._monitor_book_events_thread, name="event in {}".format(self.uid))
        self._bookMonitorThread.setDaemon(True)
        self._bookMonitorThread.start()
        self.threads.append(self._bookMonitorThread)

        self._bookHandlerThread = Thread(target=self._handle_book_events_thread, name="book in {}".format(self.uid))
        self._bookHandlerThread.setDaemon(True)
        self._bookHandlerThread.start()
        self.threads.append(self._bookHandlerThread)

        if (self.retry_all):
            self._bookRetryThread = Thread(target=self._retry_all_books_thread, name="retry all for {}".format(self.uid))
            self._bookRetryThread.setDaemon(True)
            self._bookRetryThread.start()
            self.threads.append(self._bookRetryThread)

        if (self.retry_missing):
            self._bookRetryInNotOutThread = Thread(target=self._retry_missing_books_thread, name="retry missing for {}".format(self.uid))
            self._bookRetryInNotOutThread.setDaemon(True)
            self._bookRetryInNotOutThread.start()
            self.threads.append(self._bookRetryInNotOutThread)

        if not Pipeline._triggerDirThread:
            Pipeline._triggerDirThread = Thread(target=Pipeline._trigger_dir_thread, name="trigger dir monitor")
            Pipeline._triggerDirThread.setDaemon(True)
            Pipeline._triggerDirThread.start()
            self.threads.append(Pipeline._triggerDirThread)

        logging.info("Pipeline \"" + str(self.title) + "\" started watching " + self.dir_in)

    def stop(self, exit=False):
        self._dirsAvailable = False

        # Remove autotriggered books, as these may have mistakenly been added
        # because of a network station becoming unavailable.
        with self._queue_lock:
            new_queue = []
            if len(new_queue) < len(self._queue):
                logging.info("Removed {} books from the queue that may have been added because the network station was unavailable.".format(len(self._queue) - len(new_queue)))
                self._queue = new_queue

        if exit:
            self._shouldRun = False

        logging.info("Pipeline \"" + str(self.title) + "\" stopped")

    def run(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None, dir_base=None, config=None):
        """
        Run in a blocking manner (useful from command line)
        """
        self.start(inactivity_timeout, dir_in, dir_out, dir_reports, email_settings, dir_base, config)
        try:
            while self._shouldRun:

                available = {
                    self.dir_in: False,
                    self.dir_out: False
                }
                for dir in available:
                    is_mount = Filesystem.ismount(dir)
                    contains_books = False
                    if is_mount:
                        for entry in os.scandir(dir):
                            contains_books = True
                            break
                    mount_is_mounted = not is_mount or contains_books
                    available[dir] = os.path.isdir(self.dir_in) and mount_is_mounted

                if False in [available[dir] for dir in available]:
                    if self._dirsAvailable:
                        for dir in [d for d in available if not available[d]]:
                            logging.warning("{} is not available. Stop watching...".format(dir))
                        self.stop()

                    else:
                        for dir in [d for d in available if not available[d]]:
                            logging.warning("{} is still not available...".format(dir))

                if not self._dirsAvailable and os.path.isdir(self.dir_in) and mount_is_mounted:
                    logging.info("All directories are available again. Start watching...")
                    for dir in [d for d in available if not available[d]]:
                        logging.debug("Available: {}".format(dir))
                    self.start(self._inactivity_timeout, self.dir_in, self.dir_out, self.dir_reports, self.email_settings, self.dir_base, config)

                time.sleep(1)

        except KeyboardInterrupt:
            pass

        self.stop()
        self.join()

    def join(self):
        with self._queue_lock:
            self._queue = []

        for thread in self.threads:
            if thread:
                logging.debug("joining {}".format(thread.name))
                thread.join(timeout=60)

        if self._dir_trigger_obj:
            self._dir_trigger_obj.cleanup()

        is_alive = True
        while is_alive:
            is_alive = False
            for thread in self.threads:
                if thread and thread != threading.current_thread() and thread.is_alive():
                    is_alive = True
                    logging.info("Thread is still running: {}".format(thread.name))
                    thread.join(timeout=60)

    def trigger(self, name, auto=True):
        path = os.path.join(self.dir_trigger, name)
        if auto:
            with open(path, "w") as triggerfile:
                triggerfile.write("autotriggered")
        else:
            Path(path).touch()
            with self._md5_lock:
                if name not in self._md5:
                    self._update_md5(name)
                else:
                    self._md5[name]["modified"] = time.time()

    def get_queue(self):
        with self._queue_lock:
            return deepcopy(self._queue)

    def current_book_name(self):
        name = self.book["name"] if self.book else ""

        try:
            if self.book and self.book["source"] and os.path.isdir(self.book["source"]):
                epub = Epub(self, self.book["source"])

                if epub.isepub(report_errors=False):
                    title = epub.meta("dc:title")
                    if title:
                        name += ": " + title[:25] + ("…" if len(title) > 25 else "")

        except Exception:
            logging.exception("An error occured while trying to extract the title of the book")

        return name

    def get_status(self):
        if self._shouldRun and not self.running:
            return "Starter..."
        elif not self._shouldRun and self.running:
            return "Stopper..."
        elif not self.running and not isinstance(self, DummyPipeline):
            return "Stoppet"
        elif self.book:
            return str(self.current_book_name())
        elif isinstance(self, DummyPipeline):
            return "Manuelt steg"
        else:
            return "Venter"

    def get_progress(self):
        # exactly 10 messages in log
        if len(self.progress_log) > 10:
            self.progress_log = self.progress_log[-10:]
        while len(self.progress_log) < 10:
            self.progress_log.append({"start": 0, "end": self.expected_processing_time})

        if self.progress_text:
            return self.progress_text

        elif self.progress_start >= self.progress_log[-1]["end"]:

            average_duration = 0
            for p in self.progress_log:
                average_duration += p["end"] - p["start"]
            average_duration /= 10

            duration = time.time() - self.progress_start

            percentage = math.floor((1 - math.exp(-duration/average_duration/2)) * 100)
            return "{} %".format(percentage)

        else:
            return ""

    @staticmethod
    def directory_watchers_ready(directory):
        if directory is None:
            return True

        for p in Pipeline.pipelines:
            if directory == p.dir_in and p._shouldRun and not p.running:
                return False

        return True

    def _add_book_to_queue(self, name, event_type):
        with self._queue_lock:
            book_in_queue = False
            for item in self._queue:
                if item['name'] == name:
                    book_in_queue = True
                    item['last_event'] = int(time.time())
                    if event_type not in item['events']:
                        item['events'].append(event_type)
                    break
            if not book_in_queue:
                self._queue.append({
                     'name': name,
                     'source': os.path.join(self.dir_in, name),
                     'events': [event_type],
                     'last_event': int(time.time())
                })
                logging.debug("added book to queue: " + name)

    def _update_md5(self, name):
        path = os.path.join(self.dir_in, name)

        assert "/" not in name

        with self._md5_lock:
            shallow_md5, _ = Filesystem.path_md5(path=path, shallow=True, expect=self._md5[name]["shallow"] if name in self._md5 else None)
            deep_md5, modified = Filesystem.path_md5(path=path, shallow=False, expect=self._md5[name]["deep"] if name in self._md5 else None)
            modified = max(modified if modified else 0, self._md5[name]["modified"] if name in self._md5 else 0)
            self._md5[name] = {
                "shallow": shallow_md5,
                "shallow_checked": int(time.time()),
                "deep": deep_md5,
                "deep_checked": int(time.time()),
                "modified": modified,
            }

    @staticmethod
    def _trigger_dir_thread():
        _trigger_dir_obj = None
        trigger_dir = os.getenv("TRIGGER_DIR")
        if not trigger_dir:
            _trigger_dir_obj = tempfile.TemporaryDirectory(prefix="produksjonssystem-", suffix="-trigger-dirs")
            trigger_dir = _trigger_dir_obj.name
        trigger_dir = os.path.join(trigger_dir, "dirs")

        dirs = None
        while True:
            time.sleep(5)

            ready = 0
            for pipeline in Pipeline.pipelines:
                if pipeline.running or pipeline._shouldRun and pipeline.dir_in:
                    ready += 1

            if ready == 0:
                logging.info("stopping dir trigger thread")
                break

            if ready < len(Pipeline.pipelines):
                # all pipelines are still not running; wait a bit...
                continue

            if not dirs:
                dirs = {}
                for pipeline in Pipeline.pipelines:
                    if not pipeline.dir_in:
                        continue

                    relpath = os.path.relpath(pipeline.dir_in, Filesystem.get_base_path(pipeline.dir_in, pipeline.dir_base))

                    if ".." in relpath:
                        continue

                    if relpath not in dirs:
                        dirs[relpath] = [pipeline.uid]
                        os.makedirs(os.path.join(trigger_dir, relpath), exist_ok=True)
                    else:
                        dirs[relpath].append(pipeline.uid)

            for relpath in dirs:
                path = os.path.join(trigger_dir, relpath)
                if os.path.isdir(path):
                    for name in os.listdir(path):
                        if name == "_name":
                            continue
                        triggerfile = os.path.join(path, name)
                        if os.path.isfile(triggerfile):
                            autotriggered = False
                            try:
                                with open(triggerfile, "r") as tf:
                                    first_line = tf.readline().strip()
                                    if first_line == "autotriggered":
                                        autotriggered = True
                                os.remove(triggerfile)

                            except Exception:
                                logging.exception("An error occured while trying to delete triggerfile: " + triggerfile)

                            for pipeline in Pipeline.pipelines:
                                if pipeline.uid in dirs[relpath]:
                                    pipeline.trigger(name, auto=autotriggered)
        if _trigger_dir_obj:
            _trigger_dir_obj.cleanup()

    def _monitor_book_events_thread(self):
        while self._dirsAvailable and self._shouldRun:
            try:
                if self.shouldHandleBooks:
                    # books that are recently changed (check often in case of new file changes)
                    with self._md5_lock:
                        recently_changed = sorted([f for f in self._md5 if time.time() - self._md5[f]["modified"] < self._inactivity_timeout],
                                                  key=lambda rc: self._md5[rc]["modified"])
                        if recently_changed:
                            for f in recently_changed:
                                deep_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_in, f), shallow=False)
                                self._md5[f]["deep_checked"] = int(time.time())
                                if deep_md5 != self._md5[f]["deep"]:
                                    self._md5[f]["modified"] = int(time.time())
                                    self._update_md5(f)
                                    self._add_book_to_queue(f, "modified")
                                    logging.debug("book modified (and was recently modified, might be in the middle of a copy operation): " + f)

                            time.sleep(0.1)  # a small nap
                            continue

                time.sleep(1)  # unless anything has recently changed, give the system time to breathe between each iteration

                # Note: triggering books are allowed even when self.shouldHandleBooks is False
                if os.path.isdir(self.dir_trigger):
                    for f in os.listdir(self.dir_trigger):
                        if f == "_name":
                            continue
                        triggerfile = os.path.join(self.dir_trigger, f)
                        if os.path.isfile(triggerfile):
                            try:
                                autotriggered = False
                                with open(triggerfile, "r") as tf:
                                    first_line = tf.readline().strip()
                                    if first_line == "autotriggered":
                                        autotriggered = True
                                os.remove(triggerfile)
                                self._add_book_to_queue(f, "autotriggered" if autotriggered else "triggered")
                            except Exception:
                                logging.exception("An error occured while trying to delete triggerfile: " + triggerfile)

                if self.shouldHandleBooks:
                    # do a shallow check of files and folders (i.e. don't check file sizes, modification times etc. in subdirectories)
                    dirlist = os.listdir(self.dir_in)
                    for f in dirlist:
                        if not (self._dirsAvailable and self._shouldRun):
                            break  # break loop if we're shutting down the system

                        with self._md5_lock:
                            if not os.path.exists(os.path.join(self.dir_in, f)):
                                # iterating over all books can take a lot of time,
                                # and the book may have been deleted by the time we get to it.
                                self._add_book_to_queue(f, "deleted")
                                logging.debug("book deleted: " + f)
                                del self._md5[f]
                                continue

                            if f not in self._md5:
                                self._update_md5(f)
                                self._add_book_to_queue(f, "created")
                                logging.debug("book created: " + f)
                                continue

                            shallow_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_in, f),
                                                                 shallow=True,
                                                                 expect=self._md5[f]["shallow"] if f in self._md5 else None)
                            if shallow_md5 != self._md5[f]["shallow"]:
                                self._update_md5(f)
                                self._add_book_to_queue(f, "modified")
                                logging.debug("book modified (top-level dir/file modified): " + f)
                                continue

                    with self._md5_lock:
                        deleted = [f for f in self._md5 if f not in dirlist]
                        for f in deleted:
                            self._add_book_to_queue(f, "deleted")
                            logging.debug("book deleted: " + f)
                            del self._md5[f]
                        if deleted:
                            continue

                    # do a deep check (size/time etc. of files in subdirectories) of up to 10 books that haven't been checked in a while
                    with self._md5_lock:
                        long_time_since_checked = sorted([{"name": f, "md5": self._md5[f]} for f in self._md5
                                                          if time.time() - self._md5[f]["modified"] > self._inactivity_timeout],
                                                         key=lambda f: f["md5"]["deep_checked"])
                        for b in long_time_since_checked[:10]:
                            if not (self._dirsAvailable and self._shouldRun):
                                break  # break loop if we're shutting down the system

                            f = b["name"]
                            deep_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_in, f),
                                                              shallow=False,
                                                              expect=self._md5[f]["deep"] if f in self._md5 else None)
                            if f not in self._md5:
                                self._update_md5(f)
                            else:
                                self._md5[f]["deep_checked"] = int(time.time())
                                if deep_md5 != self._md5[f]["deep"]:
                                    self._md5[f]["modified"] = int(time.time())
                                    self._update_md5(f)
                                    self._add_book_to_queue(f, "modified")
                                    logging.debug("book modified: " + f)

            except Exception:
                logging.exception(Pipeline._i18n["An error occured while monitoring of"] + " " +
                                  str(self.dir_in) + (" (" + self.book["name"] + ")" if self.book and "name" in self.book else ""))
                try:
                    Report.emailPlainText(Pipeline._i18n["An error occured while monitoring of"] + " " +
                                          str(self.dir_in) + (" (" + self.book["name"] + ")" if self.book and "name" in self.book else ""),
                                          traceback.format_exc(), self.email_settings["smtp"], self.email_settings["sender"], self.email_settings["recipients"])
                except Exception:
                    logging.exception("Could not e-mail exception")

    def _retry_all_books_thread(self):
        last_check = 0

        while self._dirsAvailable and self._shouldRun:
            time.sleep(5)
            max_update_interval = 60 * 60  # 1 hour

            if time.time() - last_check < max_update_interval:
                continue

            if not (datetime.date.today().weekday() <= 4):
                continue
            if not (8 <= datetime.datetime.now().hour <= 15):
                continue

            last_check = time.time()
            for filename in os.listdir(self.dir_in):
                if not (self._dirsAvailable and self._shouldRun):
                    break  # break loop if we're shutting down the system
                self.trigger(filename)

    def _retry_missing_books_thread(self):
        last_check = 0
        while self._dirsAvailable and self._shouldRun:
            time.sleep(5)
            max_update_interval = 60 * 60 * 4

            if time.time() - last_check < max_update_interval:
                continue

            if not (datetime.date.today().weekday() <= 4):
                continue
            if not (8 <= datetime.datetime.now().hour <= 15):
                continue

            last_check = time.time()

            for fileName in os.listdir(self.dir_in):

                if not (self._dirsAvailable and self._shouldRun):
                    break  # break loop if we're shutting down the system
                file_name = Path(fileName).stem
                edition = [file_name]

                # if input file is an epub (starts with 5), find all possible identifiers
                try:
                    if file_name.startswith("5"):
                        self.pipelineDummy = DummyPipeline(uid=self.uid + "-auto", title=self.title + file_name + " retry")
                        edition, publication = Metadata.get_identifiers(self.pipelineDummy.utils.report, file_name)
                        edition = list(set(edition) | set(publication))
                except Exception:
                    logging.info("Metadata feilet under get_identifiers for file_name")
                # TODO Maybe if not epub and not daisy202 find epub identifier from metadata then call to Metadata to find editions
                file_exists = False

                try:
                    if self.parentdirs:
                        for key in self.parentdirs:
                            for fileInDirOut in os.listdir(os.path.join(self.dir_out, self.parentdirs[key])):

                                if not (self._dirsAvailable and self._shouldRun):
                                    break  # break loop if we're shutting down the system
                                if Path(fileInDirOut).stem in edition:
                                    file_exists = True
                                    break
                    else:
                        for fileInOut in os.listdir(self.dir_out):

                            if not (self._dirsAvailable and self._shouldRun):
                                break  # break loop if we're shutting down the system
                            if Path(fileInOut).stem in edition:
                                file_exists = True
                                break

                except Exception:
                    logging.info("Retry missing-tråden feilet under søking etter filer i ut-mappa for: " + self.title)

                if not file_exists:
                    logging.info(fileName + " finnes ikke i ut-mappen. Trigger denne boken.")
                    self.trigger(fileName)

    def _handle_book_events_thread(self):
        while self._dirsAvailable and self._shouldRun:
            self.running = True

            try:
                if not Pipeline.directory_watchers_ready(self.dir_out):
                    time.sleep(10)
                    continue

                if not os.path.isdir(self.dir_in):
                    # when base dir is not available we should stop watching the directory,
                    # this just catches a potential race condition
                    time.sleep(1)
                    continue

                self.book = None

                with self._queue_lock:
                    books = [b for b in self._queue if int(time.time()) - b["last_event"] > self._inactivity_timeout]
                    books = sorted(books, key=lambda b: b["last_event"], reverse=True)  # process recently modified books first

                    # process books that were started manually first (manual trigger or book modification)
                    books_autotriggered = [b for b in books if "autotriggered" in b["events"]]
                    books_manual = [b for b in books if "autotriggered" not in b["events"]]
                    books = books_manual
                    books.extend(books_autotriggered)

                    if books:
                        logging.info("queue: " + ", ".join(
                            [b["name"] for b in books][:5]) + (", ... ( " + str(len(books) - 5) + " more )" if len(books) > 5 else ""))

                    self.book = None
                    if len(books):
                        self.book = books[0]

                        new_queue = [b for b in self._queue if b is not self.book]
                        self._queue = new_queue

                if self.book:
                    # Determine order of creation/deletion, as well as type of book event
                    event = Pipeline.get_main_event(self.book)

                    # created first, then deleted => ignore
                    if event == "create_before_delete":
                        pass

                    # source directory or file should be ignored
                    elif Filesystem.shutil_ignore_patterns(os.path.dirname(self.book["source"]), [os.path.basename(self.book["source"])]):
                        logging.info("Ignoring book: {}".format(self.book["source"]))
                        pass

                    # trigger book event
                    else:
                        # configure utils before processing book
                        self.utils.report = Report(self)
                        self.utils.filesystem = Filesystem(self)
                        result = None

                        # get some basic metadata (identifier and title) from the book for reporting purposes
                        book_metadata = Metadata.get_metadata_from_book(self, self.book["source"])

                        try:
                            self.progress_start = time.time()
                            self.utils.report.debug("Started: {}".format(time.strftime("%Y-%m-%d %H:%M:%S")))

                            if event == "created":
                                result = self.on_book_created()

                            elif event == "deleted":
                                result = self.on_book_deleted()

                            else:
                                result = self.on_book_modified()

                        except Exception:
                            self.utils.report.error("An error occured while handling the book")
                            self.utils.report.error(traceback.format_exc(), preformatted=True)
                            logging.exception("An error occured while handling the book")

                        finally:
                            try:
                                Metadata.add_production_info(self.utils.report, book_metadata["identifier"], self.publication_format)
                            except Exception:
                                self.utils.report.error("An error occured while retrieving production info")
                                self.utils.report.error(traceback.format_exc(), preformatted=True)
                                logging.exception("An error occured while retrieving production info")

                            if self.utils.report.title is None:
                                book_title = " ({})".format(book_metadata["title"]) if "title" in book_metadata else ""
                                if result is True:
                                    self.utils.report.title = self.title + ": " + self.book["name"] + " lyktes 👍😄" + book_title
                                else:
                                    self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + book_title

                            epub_identifier = None
                            if "nlbprod:identifier.epub" in book_metadata:
                                epub_identifier = book_metadata["nlbprod:identifier.epub"]
                            elif book_metadata["identifier"].startswith("5"):
                                epub_identifier = book_metadata["identifier"]
                            if epub_identifier and not Metadata.is_in_quickbase(self.utils.report, epub_identifier):
                                self.utils.report.info("{} finnes ikke i Quickbase. Vi sender derfor ikke en e-post.".format(epub_identifier))
                                self.utils.report.should_email = False

                            progress_end = time.time()
                            self.progress_log.append({"start": self.progress_start, "end": progress_end})
                            self.utils.report.debug("Finished: {}".format(time.strftime("%Y-%m-%d %H:%M:%S")))

                            if self._stopAfterFirstJob:
                                self.stop(exit=True)
                            try:
                                self.utils.report.email(self.email_settings["smtp"],
                                                        self.email_settings["sender"],
                                                        self.email_settings["recipients"],
                                                        should_email=self.utils.report.should_email,
                                                        should_message_slack=self.utils.report.should_message_slack)
                            except Exception:
                                logging.exception("An error occured while sending email")
                            finally:
                                logpath = self.utils.report.attachLog()
                                logging.exception("Logfile: " + logpath)

            except Exception:
                logging.exception(Pipeline._i18n["An error occured while checking for book events"] +
                                  (": " + str(self.book["name"]) if self.book and "name" in self.book else ""))
                try:
                    Report.emailPlainText(Pipeline._i18n["An error occured while checking for book events"] +
                                          (": " + str(self.book["name"]) if self.book and "name" in self.book else ""),
                                          traceback.format_exc(), self.email_settings["smtp"], self.email_settings["sender"], self.email_settings["recipients"])
                except Exception:
                    logging.exception("Could not e-mail exception")

            finally:
                time.sleep(1)

        self.running = False

    @staticmethod
    def get_main_event(book):
        created_seq = []
        deleted_seq = []
        event = "modified"

        for e in range(0, len(book["events"])):
            event = book["events"][e]
            if event == "created":
                created_seq.append(e)
            elif event == "deleted":
                deleted_seq.append(e)

        if created_seq and deleted_seq:
            if max(deleted_seq) > max(created_seq) or not os.path.exists(book["source"]):
                event = "deleted"
            else:
                event = "created"
        elif "created" in book["events"]:
            event = "created"
        elif "deleted" in book["events"]:
            event = "deleted"
        elif "autotriggered" in book["events"] and len(set(book["events"])) == 1:
            event = "autotriggered"
        elif "triggered" in book["events"]:
            event = "triggered"

        if created_seq and deleted_seq and min(created_seq) < min(deleted_seq) and max(deleted_seq) > max(created_seq):
            event = "create_before_delete"

        return event

    # in case you want to override something
    @staticmethod
    def translate(english_text, translated_text):
        Pipeline._i18n[english_text] = translated_text

    # This should be overridden
    def on_book_created(self):
        logging.info("Book created (unhandled book event): "+self.book['name'])

    # This should be overridden
    def on_book_modified(self):
        logging.info("Book modified (unhandled book event): "+self.book['name'])

    # This should be overridden
    def on_book_deleted(self):
        logging.info("Book deleted (unhandled book event): "+self.book['name'])


class DummyPipeline(Pipeline):
    uid = "dummy"
    title = "Dummy"
    labels = []
    publication_format = None
    book = {}

    utils = None
    running = True

    def __init__(self, title=None, uid=None, inherit_config_from=None, labels=[]):
        if title:
            self.title = title
        if uid:
            self.uid = uid
        elif title:
            self.uid = "dummy_{}".format(re.sub(r'[^a-z0-9]', '', title.lower()))
        self.labels = labels
        self.utils = DotMap()
        self.utils.report = DummyReport(self)
        self.utils.filesystem = Filesystem(self)
        self._queue_lock = RLock()
        self._md5_lock = RLock()
        self._shouldRun = False

        if inherit_config_from:
            assert (inspect.isclass(inherit_config_from) and issubclass(inherit_config_from, Pipeline) or
                    not inspect.isclass(inherit_config_from) and issubclass(type(inherit_config_from), Pipeline))
            self.dir_in = inherit_config_from.dir_in
            self.dir_out = inherit_config_from.dir_out
            self.dir_reports = inherit_config_from.dir_reports
            self.dir_base = inherit_config_from.dir_base
            self.email_settings = inherit_config_from.email_settings
            self.config = inherit_config_from.config

    def start(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None, dir_base=None, config=None):
        self._shouldRun = True

        self.start_common(inactivity_timeout=inactivity_timeout,
                          dir_in=dir_in,
                          dir_out=dir_out,
                          dir_reports=dir_reports,
                          email_settings=email_settings,
                          dir_base=dir_base,
                          config=config)

        self.running = True

    def stop(self, *args, **kwargs):
        self._shouldRun = False
        self.running = False

    def run(self, *args, **kwargs):
        self.start(*args, **kwargs)
        while self._shouldRun:
            if self._stopAfterFirstJob:
                self.stop()
                break
            time.sleep(1)

    def on_book_deleted(self):
        self.utils.report.should_email = False

    def on_book_modified(self):
        self.utils.report.should_email = False

    def on_book_created(self):
        self.utils.report.should_email = False


if __name__ == '__main__':
    args = sys.argv[1:]
    pipeline = Pipeline(args[0])
    pipeline.run()
