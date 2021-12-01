#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import os
import sys
if os.environ.get("TEST", "false").lower() not in ["true", "1"]:
    logging.basicConfig(stream=sys.stdout,
                        level=logging.DEBUG,
                        format="%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s")

import datetime
import inspect
import math
import re
import tempfile
import threading
import time
import traceback
from copy import deepcopy
from threading import RLock, Thread

from dotmap import DotMap

from core.config import Config
from core.directory import Directory
from core.utils.filesystem import Filesystem
from core.utils.metadata import Metadata
from core.utils.report import DummyReport, Report

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Pipeline():
    """
    Base class for creating pipelines.
    Do not override methods or variables starting with underscore (_).
    """

    _queue_lock = None
    _md5_lock = None
    _group_locks = {}  # use this statically: Pipeline._group_locks

    _dir_trigger_obj = None  # store TemporaryDirectory object in instance so that it's not cleaned up
    pipelines = []

    # The current book
    book = None
    considering_retry_book = None

    # Directories
    dir_in_obj = None
    dir_out_obj = None
    dir_in = None
    dir_out = None
    dir_reports = None
    dir_trigger = None
    dir_base = None
    parentdirs = {}

    # These ones are meant for use in static contexts
    dirs = None  # dirs are built in Pipeline.start_common: Pipeline.dirs[uid][in|out|reports|trigger]

    # Other configuration
    config = None    # instance config
    environment = {}  # global config

    # constants (set during instantiation)
    running = False
    shouldHandleBooks = True
    should_retry_during_working_hours = False
    should_retry_during_night_and_weekend = True
    should_retry_only_when_idle = False
    _inactivity_timeout = 30
    _bookHandlerThread = None
    _bookRetryThread = None
    _bookMonitorThread = None
    _bookRetryInNotOutThread = None
    shouldRun = True
    stopAfterNJobs = -1

    # static (shared by all pipelines)
    _triggerDirThread = None

    # dynamic (reset on stop(), changes over time)
    _queue = None
    _md5 = None
    threads = None
    watchdogs = None
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
    gid = None
    title = None
    group_title = None
    labels = []
    publication_format = None

    def __init__(self,
                 retry_all=False,
                 retry_missing=False,
                 retry_old=False,
                 retry_complete=False,
                 check_identifiers=False,
                 overwrite=True,
                 during_working_hours=None,
                 during_night_and_weekend=None,
                 only_when_idle=None,
                 _uid=None,
                 _gid=None,
                 _title=None,
                 _group_title=None):

        # Parameters starting with underscore are only meant to be used in tests.
        if _uid:
            self.uid = _uid
        if _gid:
            self.gid = _gid
        if _title:
            self.title = _title
        if _group_title:
            self.group_title = _group_title

        self.utils = DotMap()
        self.utils.report = None
        self.utils.filesystem = None
        self.overwrite = overwrite
        self.retry_all = retry_all
        self.retry_missing = retry_missing
        self.retry_old = retry_old
        self.retry_complete = retry_complete
        self.check_identifiers = check_identifiers

        # By default, only retry during the night or during the weekend.
        # If during_working_hours is True but during_night_and_weekend is not specified,
        # then during_night_and_weekend are set to False. To process books both
        # during working hours as well as during the night and weekend:
        # set both variables explicitly.
        # To reduce server load, only_when_idle can be set to True, which will
        # only allow the pipeline to retry books when the whole system is idle.
        self.should_retry_during_working_hours = during_working_hours if isinstance(during_working_hours, bool) else True
        self.should_retry_during_night_and_weekend = during_night_and_weekend if isinstance(during_night_and_weekend, bool) else True
        self.should_retry_only_when_idle = only_when_idle if isinstance(only_when_idle, bool) else False

        self._queue_lock = RLock()
        self._md5_lock = RLock()
        if self.get_group_id() not in Pipeline._group_locks:
            Pipeline._group_locks[self.get_group_id()] = {"lock": RLock(), "current-uid": None}
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
                    "Base directories must be a space-separated list with name=path pairs. "
                    + "For instance: master=/media/archive. "
                    + "Note that paths can not contain space characters."
                    )
                archive_name = d.split("=")[0]
                archive_path = os.path.normpath(d.split("=")[1]) + "/"
                base_dirs[archive_name] = archive_path
            dir_base = base_dirs

        self.stopAfterNJobs = -1
        if stop_after_first_job in ["true", "1"]:
            self.stopAfterNJobs = 1

        self.dir_in_obj = None
        self.dir_out_obj = None
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

        assert (self.dir_in is None or os.path.isdir(self.dir_in)), "The input directory, if specified, must point to a directory."
        assert (self.dir_out is None or os.path.isdir(self.dir_out)), "The output directory, if specified, must point to a directory."

        if self.dir_out is not None:
            for p in self.parentdirs:
                os.makedirs(os.path.join(self.dir_out, self.parentdirs[p]), exist_ok=True)

        # TODO: The trigger directory mechanism is deprecated. Will be removed in the future.
        #       Use the trigger function or trigger API endpoint instead.
        self.dir_trigger = os.getenv("TRIGGER_DIR")
        if self.dir_trigger:
            self.dir_trigger = os.path.join(self.dir_trigger, "pipelines", self.uid)
            try:
                if not os.path.exists(self.dir_trigger):
                    os.makedirs(self.dir_trigger)
                with open(os.path.join(self.dir_trigger, "_name"), "w") as namefile:
                    namefile.write("{} # {}\n".format(self.uid, self.title))
            except Exception:
                logging.exception("Could not create trigger directory: " + self.dir_trigger)
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

        if self.dir_in is not None:
            if Filesystem.ismount(self.dir_in):
                logging.warning(self.dir_in
                                + " is the root of a mounted filesystem. "
                                + "Please use subdirectories instead, so that mounting/unmounting is not interpreted as file changes.")
            if not os.path.isdir(self.dir_in):
                logging.error(self.dir_in + " is not available. Will not start watching.")
                return
        self._inactivity_timeout = inactivity_timeout

        self.threads = []
        self.watchdogs = {}

        # start a directory watcher for the output directory
        if self.dir_out is not None:
            self.dir_out_obj = Directory.start_watching(self.dir_out)

        # start a directory watcher for the input directory
        if self.dir_in is not None:
            self.dir_in_obj = Directory.start_watching(self.dir_in, inactivity_timeout=self._inactivity_timeout)
            self.dir_in_obj.add_book_event_handler(self._add_book_to_queue)

        # wait for directory watchers to be ready
        while (self.dir_in_obj and self.dir_in_obj.is_starting()
                or self.dir_out_obj and self.dir_out_obj.is_starting()):
            self.progress_text = " , ".join([text for text in [
                self.dir_in_obj.get_status_text() if self.dir_in_obj else None,
                self.dir_out_obj.get_status_text() if self.dir_out_obj else None
            ] if text])

            time.sleep(1)

        self.progress_text = ""

        self.shouldHandleBooks = True

        if self.dir_in is not None:
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

        self._bookTriggerThread = Thread(target=self._monitor_book_triggers_thread, name="trigger in {}".format(self.uid))
        self._bookTriggerThread.setDaemon(True)
        self._bookTriggerThread.start()
        self.threads.append(self._bookTriggerThread)

        self._bookHandlerThread = Thread(target=self._handle_book_events_thread, name="book in {}".format(self.uid))
        self._bookHandlerThread.setDaemon(True)
        self._bookHandlerThread.start()
        self.threads.append(self._bookHandlerThread)

        if not Pipeline._triggerDirThread:
            Pipeline._triggerDirThread = Thread(target=Pipeline._trigger_dir_thread, name="trigger dir monitor")
            Pipeline._triggerDirThread.setDaemon(True)
            Pipeline._triggerDirThread.start()
            self.threads.append(Pipeline._triggerDirThread)

        if self.dir_in is not None:
            logging.info("Pipeline \"" + str(self.title) + "\" started watching " + self.dir_in)
        else:
            logging.info("Pipeline \"" + str(self.title) + "\" started")

    def stop(self):
        # Remove autotriggered books, as these may have mistakenly been added
        # because of a network station becoming unavailable.
        with self._queue_lock:
            new_queue = []
            for book in self._queue:
                if Pipeline.get_main_event(book) != "autotriggered":
                    new_queue.append(book)
            if len(new_queue) < len(self._queue):
                logging.info("Removed {} books from the queue that may have been added because the network station was unavailable.".format(
                    len(self._queue) - len(new_queue)))
                self._queue = new_queue

        self.shouldRun = False

        logging.info("Pipeline \"" + str(self.title) + "\" stopped")

    def run(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None, dir_base=None, config=None):
        """
        Run in a blocking manner (useful from command line)
        """
        self.start(inactivity_timeout, dir_in, dir_out, dir_reports, email_settings, dir_base, config)
        try:
            while self.shouldRun:
                time.sleep(1)

        except KeyboardInterrupt:
            pass

        self.stop()
        self.join()

    def join(self):
        with self._queue_lock:
            self._queue = []

        if self.dir_in is not None:
            Directory.stop(self.dir_in)

        if self.threads:
            for thread in self.threads:
                if thread:
                    logging.debug("joining {}".format(thread.name))
                    thread.join(timeout=60)

        if self._dir_trigger_obj:
            self._dir_trigger_obj.cleanup()

        is_alive = True
        join_start_time = time.time()
        while is_alive:
            is_alive = False
            if self.threads:
                for thread in self.threads:
                    if thread and thread != threading.current_thread() and thread.is_alive():
                        if time.time() - join_start_time > 60 * 50:
                            logging.info("Pipeline thread is still running (we've waited too long, let's ignore it): {}".format(thread.name))
                            thread.join(timeout=60)
                        else:
                            is_alive = True
                            logging.info("Pipeline thread is still running: {}".format(thread.name))
                            thread.join(timeout=60)

    def is_healthy(self):
        if self.threads:
            for thread in self.threads:
                if thread and thread != threading.current_thread():
                    if not thread.is_alive():
                        # found thread that is not running
                        logging.debug("not alive: {}".format(thread))
                        return False
                    if thread in self.watchdogs and time.time() - self.watchdogs[thread] > 21600:
                        # found thread that is frozen
                        logging.debug("frozen: {}".format(thread))
                        return False

        # no threads found that are not running
        return True

    def get_group_id(self):
        if self.gid:
            return self.gid
        else:
            return self.uid

    def get_group_title(self):
        current_pipeline = self.get_current_group_pipeline(default_self=False)
        if current_pipeline:
            return next(value for value in [current_pipeline.title, current_pipeline.uid] if value)
        else:
            return next(value for value in [self.group_title, self.title, self.gid, self.uid] if value)

    def get_current_group_pipeline(self, default_self=True):
        gid = self.get_group_id()
        if gid in Pipeline._group_locks:
            uid = Pipeline._group_locks[gid]["current-uid"]
            for p in Pipeline.pipelines:
                if p.uid == uid:
                    return p
        if default_self:
            return self
        else:
            return None

    def trigger(self, name, auto=True):
        self._add_book_to_queue(name, "autotriggered" if auto else "triggered")

    def get_queue(self):
        with self._queue_lock:
            return deepcopy(self._queue)

    def get_state(self):
        if self.shouldRun and not self.running:
            return "starting"
        elif not self.shouldRun and self.running:
            return "stopping"
        elif not self.running and not isinstance(self, DummyPipeline):
            return "stopped"
        elif self.book:
            return "processing"
        elif self.considering_retry_book:
            return "considering"
        elif isinstance(self, DummyPipeline):
            return "manual"
        else:
            return "waiting"

    def get_status(self):
        state = self.get_state()
        if state == "starting":
            return "Starter..."
        elif state == "stopping":
            return "Stopper..."
        elif state == "stopped":
            return "Stoppet"
        elif state == "processing":
            return str(Metadata.pipeline_book_shortname(self))
        elif state == "considering":
            return self.considering_retry_book
        elif state == "manual":
            return "Manuelt steg"
        elif state == "waiting":
            return "Venter"
        else:
            return state

    def is_idle(self):
        if self.get_state() in ["stopped", "manual", "waiting"]:
            return True

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
    def is_working_hours():
        if os.getenv("TEST", "").lower() in ["1", "true", "yes"]:
            return True
        if not (datetime.date.today().weekday() <= 4):
            return False
        if not (8 <= datetime.datetime.now().hour <= 15):
            return False
        return True

    # Whether or not to process autotriggered books
    def should_handle_autotriggered_books(self):
        if self.should_retry_only_when_idle and Config.get("system.idle", 0) < self._inactivity_timeout * 2:
            return False

        if Pipeline.is_working_hours():
            return self.should_retry_during_working_hours
        else:
            return self.should_retry_during_night_and_weekend

    # Whether or not to autotrigger a specific book
    def should_retry_book(self, source):
        return True

    # Whether or not input/output directories are available (in case of network problems)
    def dirsAvailable(self):
        if self.dir_in_obj and not self.dir_in_obj.is_available():
            # logging.debug("dirsAvailable failed on dir_in: {} and not {}".format(bool(self.dir_in_obj), self.dir_in_obj.is_available()))
            return False

        if self.dir_out_obj and not self.dir_out_obj.is_available():
            # logging.debug("dirsAvailable failed on dir_out: {} and not {}".format(bool(self.dir_out_obj), self.dir_out_obj.is_available()))
            return False

        return True

    def _add_book_to_queue(self, name, event_type):
        with self._queue_lock:
            book_in_queue = False
            for item in self._queue:
                if item['name'] == name:
                    book_in_queue = True
                    if event_type != "autotriggered":
                        item['last_event'] = int(time.time())
                    if event_type not in item['events']:
                        item['events'].append(event_type)
                    break
            if not book_in_queue:
                self._queue.append({
                     'name': name,
                     'source': os.path.join(self.dir_in, name) if self.dir_in is not None else None,
                     'events': [event_type],
                     'last_event': int(time.time())
                })
                logging.debug("added book to queue: " + name)

    def watchdog_bark(self):
        self.watchdogs[threading.current_thread()] = time.time()

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
                if pipeline.running or pipeline.shouldRun and pipeline.dir_in:
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

    def _monitor_book_triggers_thread(self):
        self.watchdog_bark()
        while self.shouldRun:
            time.sleep(5)
            self.watchdog_bark()

            if not os.path.isdir(self.dir_trigger):
                continue

            if not self.shouldHandleBooks:
                continue

            for f in os.listdir(self.dir_trigger):
                if not self.shouldRun:
                    break  # stop iterating if we're shutting down the system

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

    def _retry_all_books_thread(self):
        last_retry = 0

        self.watchdog_bark()
        while self.shouldRun:
            time.sleep(5)
            self.watchdog_bark()

            if not self.dirsAvailable():
                continue

            retry_interval = 2 * 60 * 60  # 2 hours

            if time.time() - last_retry < retry_interval:
                continue

            last_retry = time.time()
            for filename in Filesystem.list_book_dir(self.dir_in):
                if not (self.dirsAvailable() and self.shouldRun):
                    break  # break loop if we're shutting down the system or directory is not available
                self.trigger(filename)

    def _retry_missing_books_thread(self):
        last_rescan = 0

        self.watchdog_bark()
        while self.shouldRun:
            time.sleep(5)
            self.watchdog_bark()

            if not self.dirsAvailable():
                continue

            retry_interval = 60 * 60 * 2 # 2 hours
            rescan_interval = 60 * 60 * 2  # 2 hours
            last_retry = {}  # { "[path]": [last-retry] }

            if time.time() - last_rescan < rescan_interval:
                continue

            # Check if there are autotriggered books already in the queue,
            # and if so, wait 60 seconds until checking again.
            # If there are autotriggered books in the queue, then we want
            # the pipeline to finish processing them before we add more.
            with self._queue_lock:
                for book in self._queue:
                    if Pipeline.get_main_event(book) == "autotriggered":
                        last_rescan += 60
                        continue

            last_rescan = time.time()

            for path in list(last_retry.keys()):  # use .keys() to be able to delete from dict
                if time.time() - last_retry[path] > retry_interval:
                    del last_retry[path]  # a long time sice this path was retried

            filenames = None
            total = None
            try:
                # list files and directories
                filenames_in = Filesystem.list_book_dir(self.dir_in)
                filenames_out = Filesystem.list_book_dir(self.dir_out, subdirs=self.parentdirs)

                # only use file stems (i.e. "123" instead of "123.epub")
                identifiers_in = [filename.split(".")[0] for filename in filenames_in]
                identifiers_out = [filename.split("/")[-1].split(".")[0] for filename in filenames_out]

                # only use identifiers that exist in the catalog
                missing_identifiers = Metadata.filter_identifiers(identifiers_in, identifiers_out, format=self.publication_format)

                # exclude list of identifiers in output directory from identifiers in input directory
                missing_identifiers = Metadata.sort_identifiers(missing_identifiers)
                filenames = []
                for identifier in missing_identifiers:
                    if identifier in filenames_in:
                        filenames.append(identifier)
                    else:
                        # find full filename in case of file extensions (i.e. "123.epub" instead of "123")
                        for filename in filenames_in:
                            if identifier == filename.split(".")[0]:
                                filenames.append(filename)
                                break

                # make filenames into absolute paths
                filenames = [os.path.join(self.dir_in, filename) for filename in filenames]
                total = len(filenames)
            except Exception:
                logging.exception("En feil oppstod ved opplisting av filer i: {}".format(self.dir_in))
                continue
            counter = 0
            for path in filenames:
                counter += 1

                try:
                    filename = os.path.basename(path)

                    self.considering_retry_book = "Prøver {} ({} av {})".format(filename, counter, total)
                    logging.debug(self.considering_retry_book)

                    if path in last_retry:
                        continue  # This book was recently retried. Let's skip this one for now.

                    last_retry[path] = time.time()

                    self.watchdog_bark()  # iterating all books can take some time, so let's bark here

                    if not (self.dirsAvailable() and self.shouldRun):
                        break  # break loop if we're shutting down the system or directory is unavailable

                    should_retry = self.should_retry_book(path)

                    if should_retry:
                        logging.info(filename + " finnes ikke i ut-mappen. Trigger denne boken.")
                        self.trigger(filename)
                    else:
                        logging.info(filename + " finnes ikke i ut-mappen, men trigger alikevel ikke denne.")

                except Exception:
                    logging.exception("Retry missing-tråden feilet for: {}".format(self.title))
                    continue

            self.considering_retry_book = None

    def _handle_book_events_thread(self):
        self.watchdog_bark()
        while self.shouldRun:
            self.running = True
            self.watchdog_bark()

            if not self.dirsAvailable():
                time.sleep(5)
                continue

            self.book = None

            try:
                if self.dir_out_obj is not None and not self.dir_out_obj.is_available():
                    time.sleep(5)
                    continue

                if self.dir_in is not None and not os.path.isdir(self.dir_in):
                    # when base dir is not available we should stop watching the directory,
                    # this just catches a potential race condition
                    time.sleep(1)
                    continue

                with self._queue_lock:
                    # list all books where no book event have occured very recently (self._inactivity_timeout)
                    books = [b for b in self._queue if int(time.time()) - b["last_event"] > self._inactivity_timeout]


                    # COMMENTED OUT TO TRY A NEW AUTOTRIGGERED METHOD

                    # process books that were started manually first (manual trigger or book modification)
                    # process autotriggered books in the order they were cataloged in
           #         books_autotriggered = [b for b in books if Pipeline.get_main_event(b) == "autotriggered"]
           #         autotriggered_identifiers = [b["name"] for b in books]
            #        autotriggered_identifiers = Metadata.sort_identifiers(autotriggered_identifiers)
             #       books_autotriggered_sorted = []
             #       for identifier in autotriggered_identifiers:
              #          for b in books_autotriggered:
               #             if b["name"] == identifier:
                #                books_autotriggered_sorted.append(b)
                 #               break
                  #  books_autotriggered = books_autotriggered_sorted

                    books_autotriggered = [b for b in books if Pipeline.get_main_event(b) == "autotriggered"]
                    books_autotriggered = sorted(books_autotriggered, key=lambda b: b["last_event"], reverse=False)  # process recently autotriggered books last

                    books_manual = [b for b in books if Pipeline.get_main_event(b) != "autotriggered"]
                    books_manual = sorted(books_manual, key=lambda b: b["last_event"], reverse=True)  # process recently modified books first
                    books = books_manual
                    if self.should_handle_autotriggered_books():
                        # Don't handle autotriggered books unless should_handle_autotriggered_books() returns True
                        # This will make sure that certain pipelines only retry books
                        # during working hours, and make sure that certain other pipelines
                        # only process books outside of working hours.
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

                    # check if source directory or file should be ignored
                    elif (self.book["source"] is not None
                            and Filesystem.shutil_ignore_patterns(os.path.dirname(self.book["source"]), [os.path.basename(self.book["source"])])):
                        logging.info("Ignoring book: {}".format(self.book["source"]))

                    # trigger book event
                    else:
                        # configure utils before processing book
                        self.utils.report = Report(self)
                        self.utils.filesystem = Filesystem(self)
                        result = None

                        # get some basic metadata (identifier and title) from the book for reporting purposes
                        book_metadata = Metadata.get_metadata_from_book(self.utils.report, self.book["source"] if self.book["source"] else self.book["name"])

                        try:
                            self.progress_start = time.time()
                            self.utils.report.debug("Started: {}".format(time.strftime("%Y-%m-%d %H:%M:%S")))

                            with Pipeline._group_locks[self.get_group_id()]["lock"]:
                                Pipeline._group_locks[self.get_group_id()]["current-uid"] = self.uid

                                if event == "created":
                                    result = self.on_book_created()

                                elif event == "deleted":
                                    result = self.on_book_deleted()

                                else:
                                    result = self.on_book_modified()

                                Pipeline._group_locks[self.get_group_id()]["current-uid"] = None

                        except Exception:
                            self.utils.report.error("An error occured while handling the book")
                            self.utils.report.error(traceback.format_exc(), preformatted=True)
                            logging.exception("An error occured while handling the book")

                        finally:
                            if Pipeline._group_locks[self.get_group_id()]["current-uid"] == self.uid:
                                Pipeline._group_locks[self.get_group_id()]["current-uid"] = None

                            try:
                                Metadata.add_production_info(self.utils.report,
                                                             book_metadata["identifier"],
                                                             self.publication_format)
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

                            if not self.retry_old and Metadata.is_old(book_metadata["identifier"], report=self.utils.report):
                                self.utils.report.info("{} er gammel. Vi sender derfor ikke en e-post.".format(book_metadata["identifier"]))
                                self.utils.report.should_email = False

                            progress_end = time.time()
                            self.progress_log.append({"start": self.progress_start, "end": progress_end})
                            self.utils.report.debug("Finished: {}".format(time.strftime("%Y-%m-%d %H:%M:%S")))

                            if self.stopAfterNJobs > 0:
                                self.stopAfterNJobs -= 1
                            if self.stopAfterNJobs == 0:
                                self.stop()

                            try:
                                self.utils.report.email(Report.filterEmailAddresses(self.email_settings["recipients"],
                                                                                    library=book_metadata["library"] if "library" in book_metadata else None),
                                                        should_email=self.utils.report.should_email,
                                                        should_message_slack=self.utils.report.should_message_slack)
                            except Exception:
                                logging.exception("An error occured while sending email")
                            finally:
                                logpath = self.utils.report.attachLog()
                                logging.warning("Logfile: " + logpath)
                            if self.utils.report.should_email:
                                self.write_to_daily()

            except Exception:
                logging.exception("En feil oppstod ved håndtering av bokhendelse"
                                  + (": " + str(self.book["name"]) if self.book and "name" in self.book else ""))
                try:
                    Report.emailPlainText("En feil oppstod ved håndtering av bokhendelse"
                                          + (": " + str(self.book["name"]) if self.book and "name" in self.book else ""),
                                          traceback.format_exc(), self.email_settings["recipients"])
                except Exception:
                    logging.exception("Could not e-mail exception")

            finally:
                self.book = None
                time.sleep(1)

        self.running = False

    def daily_report(self, message):
        report_daily = Report(self)
        report_daily._messages["message"].append({'time': time.strftime("%Y-%m-%d %H:%M:%S"),
                                                  'severity': "INFO",
                                                  'text': message,
                                                  'time_seconds': (time.time()),
                                                  'preformatted': False})
        report_daily.title = "Dagsrapport for " + self.title
        recipients_daily = []

        if not self.config or not self.email_settings:
            logging.info("Missing configuration. Unable to send daily reports.")
            return

        for key in self.config:
            if key == "daily":
                for recipient_daily in self.config[key]:
                    recipients_daily.append(recipient_daily)

        for rec in self.email_settings["recipients"]:
            if "not-daily" in self.config:
                if rec not in self.config["not-daily"]:
                    recipients_daily.append(rec)
            else:
                recipients_daily.append(rec)
        try:
            report_daily.email(recipients_daily,
                               should_attach_log=False,
                               should_escape_chars=False)
        except Exception:
            logging.info("Failed sending daily email")
            logging.info(traceback.format_exc())

    def write_to_daily(self):
        error = ""
        attachment_unc = []
        attachment_smb = []
        attachment_title = []
        subject = self.utils.report.title
        for item in self.utils.report._messages["attachment"]:
            if (self.dir_out is not None and self.dir_out in item["text"]
                    or self.dir_in is not None and self.dir_in in item["text"]
                    or self.dir_reports in item["text"]):
                base_path = Filesystem.get_base_path(item["text"], self.dir_base)
                relpath = os.path.relpath(item["text"], base_path) if base_path else None
                attachment_title.append("{}{}".format(relpath, ("/" if os.path.isdir(item["text"]) else "")))
                smb, file, unc = Filesystem.networkpath(item["text"])
                attachment_unc.append(unc)
                attachment_smb.append(smb)
        for u in self.utils.report._messages["message"]:
            if (u["severity"] == "ERROR"):
                if not(u["text"] == ""):
                    for line in u["text"].split("\n"):
                        if line != "":
                            error = line
            elif(u["severity"] == "WARN") and (error == "") and not (u["text"] == ""):
                if not(u["text"] == ""):
                    for line in u["text"].split("\n"):
                        if line != "":
                            error = line
        timestring = datetime.datetime.now().strftime("%Y-%m-%d")
        dir = os.path.join(self.dir_reports, "logs", "dagsrapporter", timestring)
        if not os.path.isdir(dir):
            os.makedirs(dir)
        fail = False
        if "👍😄" in subject:
            loc = os.path.join(dir, self.uid + "-SUCCESS.txt")
        else:
            loc = os.path.join(dir, self.uid + "-FAIL.txt")
            fail = True

        try:
            epub_identifier = None
            with open(loc, Pipeline.append_write(loc)) as today_status_file:
                split_subject = subject.split()
                for split in split_subject:
                    if split.isnumeric():
                        epub_identifier = split
                        break
                if self.utils.report.mailpath != ():
                    today_status_file.write("\n[{}] {}: {} mail: {}, {}".format(
                                                time.strftime("%H:%M:%S"),
                                                epub_identifier,
                                                subject,
                                                self.utils.report.mailpath[2],
                                                self.utils.report.mailpath[0]))
                else:
                    today_status_file.write("\n[{}] {}: {}".format(time.strftime("%H:%M:%S"), epub_identifier, subject))
                if fail is True and error != "":
                    today_status_file.write("\n" + "(li) " + error)
                for attach_title, attach_unc, attach_smb in zip(attachment_title, attachment_unc, attachment_smb):
                    today_status_file.write("\n(href) {}, {}, {}".format(attach_title, attach_unc, attach_smb))
                today_status_file.write("\n")

        except Exception:
            logging.info(traceback.format_exc())

    @staticmethod
    def append_write(path):
        if os.path.exists(path):
            return 'a'  # append if already exists
        else:
            return 'w'  # make a new file if not

    @staticmethod
    def get_main_event(book):
        # always prefer "triggered" over other events
        if "triggered" in book["events"]:
            return "triggered"

        # only use "autotriggered" if there are no other known event
        if len(set(book["events"])) == 1 and book["events"][0] == "autotriggered":
            return "autotriggered"

        # remember in which order a book was created/deleted
        created_seq = []
        deleted_seq = []
        for e in range(0, len(book["events"])):
            if book["events"][e] == "created":
                created_seq.append(e)
            elif book["events"][e] == "deleted":
                deleted_seq.append(e)

        # use the event "crete_before_delete" if the book was first created and then deleted
        if created_seq and deleted_seq and min(created_seq) < min(deleted_seq) and max(deleted_seq) > max(created_seq):
            return "create_before_delete"

        if "created" in book["events"]:
            return "created"

        if "deleted" in book["events"]:
            return "deleted"

        # default to "modified"
        return "modified"

    # in case you want to override something
    @staticmethod
    def translate(english_text, translated_text):
        Pipeline._i18n[english_text] = translated_text

    # This should be overridden
    def on_book_created(self):
        logging.info("Book created (unhandled book event): " + self.book['name'])

    # This should be overridden
    def on_book_modified(self):
        logging.info("Book modified (unhandled book event): " + self.book['name'])

    # This should be overridden
    def on_book_deleted(self):
        logging.info("Book deleted (unhandled book event): " + self.book['name'])


class DummyPipeline(Pipeline):
    uid = "dummy"
    title = "Dummy"
    labels = []
    publication_format = None
    book = {}
    considering_retry_book = None

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
        self.shouldRun = False
        self.book = None
        self.considering_retry_book = None

        if inherit_config_from:
            assert (inspect.isclass(inherit_config_from) and issubclass(inherit_config_from, Pipeline)
                    or not inspect.isclass(inherit_config_from) and issubclass(type(inherit_config_from), Pipeline))
            self.dir_in = inherit_config_from.dir_in
            self.dir_out = inherit_config_from.dir_out
            self.dir_in_obj = inherit_config_from.dir_in_obj
            self.dir_out_obj = inherit_config_from.dir_out_obj
            self.dir_reports = inherit_config_from.dir_reports
            self.dir_base = inherit_config_from.dir_base
            self.email_settings = inherit_config_from.email_settings
            self.config = inherit_config_from.config

    def start(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None, dir_base=None, config=None):
        self.shouldRun = True

        self.start_common(inactivity_timeout=inactivity_timeout,
                          dir_in=dir_in,
                          dir_out=dir_out,
                          dir_reports=dir_reports,
                          email_settings=email_settings,
                          dir_base=dir_base,
                          config=config)

        self.running = True

    def stop(self, *args, **kwargs):
        self.shouldRun = False
        self.running = False

    def run(self, *args, **kwargs):
        self.start(*args, **kwargs)
        while self.shouldRun:
            if self.stopAfterNJobs == 0:
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
