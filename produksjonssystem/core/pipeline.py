#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
import time
import logging
import tempfile
import traceback

from pathlib import Path
from threading import Thread, RLock
from dotmap import DotMap

from core.utils.filesystem import Filesystem
from core.utils.report import Report, DummyReport

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
    
    _lock = RLock()
    _dir_trigger_obj = None # store TemporaryDirectory object in instance so that it's not cleaned up
    
    # The current book
    book = None
    
    # Directories
    dir_in = None
    dir_out = None
    dir_reports = None
    dir_trigger = None
    dir_base = None
    
    # This one is meant for use in static contexts (Pipeline.dirs[uid][in|out|reports|trigger])
    dirs = None
    
    # Other configuration
    config = None    # instance config
    environment = {} # global config
    
    # constants (set during instantiation)
    running = False
    shouldHandleBooks = True
    _inactivity_timeout = 10
    _bookHandlerThread = None
    _dirInAvailable = False
    _shouldRun = True
    _stopAfterFirstJob = False
    
    # dynamic (reset on stop(), changes over time)
    _queue = None
    _md5 = None
    
    # utility classes; reconfigured every time a book is processed to simplify function signatures
    utils = None
    
    # email settings
    email_settings = None
    
    # should be overridden when extending this class
    title = None
    
    def __init__(self):
        self.utils = DotMap()
        self.utils.report = None
        self.utils.filesystem = None
        self._queue = []
        logging.basicConfig(stream=sys.stdout, format="%(asctime)s %(levelname)-8s %(message)s")
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
                "sender": None,
                "recipients": []
            }
        if not dir_base:
            dir_base = os.getenv("BASE_DIR", dir_in)
        
        stop_after_first_job = os.getenv("STOP_AFTER_FIRST_JOB", False)
        
        assert dir_reports != None and len(dir_reports) > 0 and os.path.exists(dir_reports), "The environment variable DIR_REPORTS must be specified, and must point to a directory that exists."
        assert dir_base, "Base directory could not be determined"
        assert not stop_after_first_job or stop_after_first_job in [ "1", "true", "0", "false" ], "The environment variable STOP_AFTER_FIRST_JOB, if defined, must be \"true\"/\"false\" (or \"1\"/\"0\")."
        
        self._stopAfterFirstJob = False
        if stop_after_first_job in [ "true", "1" ]:
            self._stopAfterFirstJob = True
        
        if dir_in:
        self.dir_in = str(os.path.normpath(dir_in)) + '/'
        if dir_out:
        self.dir_out = str(os.path.normpath(dir_out)) + '/'
        self.dir_reports = str(os.path.normpath(dir_reports)) + '/'
        self.dir_base = str(os.path.normpath(dir_base)) + '/'
        self.email_settings = email_settings
        self.config = config if config else {}
        
        # make dirs available from static contexts
        if not Pipeline.dirs:
            Pipeline.dirs = {}
        if not self.uid in Pipeline.dirs:
            Pipeline.dirs[self.uid] = {}
        Pipeline.dirs[self.uid]["in"] = self.dir_in
        Pipeline.dirs[self.uid]["out"] = self.dir_out
        Pipeline.dirs[self.uid]["reports"] = self.dir_reports
        Pipeline.dirs[self.uid]["base"] = self.dir_base
        
    def start(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None, dir_base=None, config=None):
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" starting...")
        
        # common code shared with DummyPipeline
        self.start_common(inactivity_timeout=inactivity_timeout,
                          dir_in=dir_in,
                          dir_out=dir_out,
                          dir_reports=dir_reports,
                          email_settings=email_settings,
                          dir_base=dir_base,
                          config=config)
        
        assert self.dir_in != None and len(self.dir_in) > 0, "The environment variable DIR_IN must be specified, and must point to a directory."
        assert self.dir_out != None and len(self.dir_out) > 0 and os.path.exists(self.dir_out), "The environment variable DIR_OUT must be specified, and must point to a directory that exists."
        
        self.dir_trigger = os.getenv("TRIGGER_DIR")
        if self.dir_trigger:
            self.dir_trigger = os.path.join(self.dir_trigger, self.uid)
            try:
                if not os.path.exists(self.dir_trigger):
                    os.makedirs(self.dir_trigger)
            except Exception:
                logging.exception("[" + Report.thread_name() + "] " + "Could not create trigger directory: " + self.dir_trigger)
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
            logging.error("[" + Report.thread_name() + "] " + self.dir_in + " is the root of a mounted filesystem. Please use subdirectories instead, so that mounting/unmounting is not interpreted as file changes.")
            return
        if not os.path.isdir(self.dir_in):
            logging.error("[" + Report.thread_name() + "] " + self.dir_in + " is not available. Will not start watching.")
            return
        self._inactivity_timeout = inactivity_timeout
        
        self.shouldHandleBooks = True
        self._dirInAvailable = True
        
        self._md5 = {}
        for f in os.listdir(self.dir_in):
            self._update_md5(f)
        
        self._bookMonitorThread = Thread(target=self._monitor_book_events_thread)
        self._bookMonitorThread.setDaemon(True)
        self._bookMonitorThread.start()
        
        self._bookHandlerThread = Thread(target=self._handle_book_events_thread)
        self._bookHandlerThread.setDaemon(True)
        self._bookHandlerThread.start()
        
        self.running = True
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" started watching " + self.dir_in)
    
    def stop(self, exit=False):
        if self._bookHandlerThread:
            self._dirInAvailable = False
        if exit:
            self._shouldRun = False
        self._queue = []
        self.running = False
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" stopped")
    
    def run(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None, dir_base=None, config=None):
        """
        Run in a blocking manner (useful from command line)
        """
        self.start(inactivity_timeout, dir_in, dir_out, dir_reports, email_settings, dir_base, config)
        try:
            while self._shouldRun:
                if not os.path.isdir(self.dir_in):
                    if self._dirInAvailable:
                        logging.warn("[" + Report.thread_name() + "] " + self.dir_in + " is not available. Stop watching...")
                        self.stop()
                        
                    else:
                        logging.warn("[" + Report.thread_name() + "] " + self.dir_in + " is still not available...")
                        
                if not self._dirInAvailable and os.path.isdir(self.dir_in):
                    logging.info("[" + Report.thread_name() + "] " + self.dir_in + " is available again. Start watching...")
                    self.start(self._inactivity_timeout, self.dir_in, self.dir_out, self.dir_reports, self.email_settings, self.dir_base, config)
                
                time.sleep(1)
                
        except KeyboardInterrupt:
            pass
        self.stop()
    
    def trigger(self, name, auto=True):
        path = os.path.join(self.dir_trigger, name)
        if auto:
            with open(os.path.join(self.dir_trigger, name), "w") as triggerfile:
                print("autotriggered", file=triggerfile)
        else:
            Path(path).touch()
    
    def _add_book_to_queue(self, name, event_type):
        with self._lock:
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
                     'events': [ event_type ],
                     'last_event': int(time.time())
                })
                logging.debug("[" + Report.thread_name() + "] added book to queue: " + name)
    
    def _update_md5(self, name):
        path = os.path.join(self.dir_in, name)
        
        assert not "/" in name
        
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
    
    def _monitor_book_events_thread(self):
        while self._dirInAvailable and self._shouldRun:
            try:
                if self.shouldHandleBooks:
                    # books that are recently changed (check often in case of new file changes)
                    recently_changed = [f for f in self._md5 if time.time() - self._md5[f]["modified"] < self._inactivity_timeout]
                    if recently_changed:
                        for f in recently_changed:
                            deep_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_in, f), shallow=False)
                            self._md5[f]["deep_checked"] = int(time.time())
                            if deep_md5 != self._md5[f]["deep"]:
                                self._md5[f]["modified"] = int(time.time())
                                self._update_md5(f)
                                self._add_book_to_queue(f, "modified")
                                logging.debug("[" + Report.thread_name() + "] book modified (and was recently modified, might be in the middle of a copy operation): " + f)
                        
                        time.sleep(0.1) # a small nap
                        continue
                
                time.sleep(1) # unless anything has recently changed, give the system time to breathe between each iteration
                
                # Note: triggering books are allowed even when self.shouldHandleBooks is False
                if os.path.isdir(self.dir_trigger):
                    for f in os.listdir(self.dir_trigger):
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
                                logging.exception("[" + Report.thread_name() + "] An error occured while trying to delete triggerfile: " + triggerfile)
                
                if self.shouldHandleBooks:
                    # do a shallow check of files and folders (i.e. don't check file sizes, modification times etc. in subdirectories)
                    dirlist = os.listdir(self.dir_in)
                    for f in dirlist:
                        if not f in self._md5:
                            self._update_md5(f)
                            self._add_book_to_queue(f, "created")
                            logging.debug("[" + Report.thread_name() + "] book created: " + f)
                            continue
                        
                        shallow_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_in, f), shallow=True, expect=self._md5[f]["shallow"] if f in self._md5 else None)
                        if shallow_md5 != self._md5[f]["shallow"]:
                            self._update_md5(f)
                            self._add_book_to_queue(f, "modified")
                            logging.debug("[" + Report.thread_name() + "] book modified (top-level dir/file modified): " + f)
                            continue
                    
                    deleted = [f for f in self._md5 if f not in dirlist]
                    for f in deleted:
                        self._add_book_to_queue(f, "deleted")
                        logging.debug("[" + Report.thread_name() + "] book deleted: " + f)
                        del self._md5[f]
                    if deleted:
                        continue
                    
                    # do a deep check (size/time etc. of files in subdirectories) of up to 10 books that haven't been checked in a while
                    long_time_since_checked = sorted([{ "name": f, "md5": self._md5[f]} for f in self._md5 if time.time() - self._md5[f]["modified"] > self._inactivity_timeout], key=lambda f: f["md5"]["deep_checked"])
                    for b in long_time_since_checked[:10]:
                        f = b["name"]
                        deep_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_in, f), shallow=False, expect=self._md5[f]["deep"] if f in self._md5 else None)
                        if not f in self._md5:
                            self._update_md5(f)
                        else:
                            self._md5[f]["deep_checked"] = int(time.time())
                            if deep_md5 != self._md5[f]["deep"]:
                                self._md5[f]["modified"] = int(time.time())
                                self._update_md5(f)
                                self._add_book_to_queue(f, "modified")
                                logging.debug("[" + Report.thread_name() + "] book modified: " + f)
                
            
            except Exception:
                logging.exception("[" + Report.thread_name() + "] " + Pipeline._i18n["An error occured while monitoring of"] + " " + str(self.dir_in) + (" (" + self.book["name"] + ")" if self.book and "name" in self.book else ""))
                try:
                    Report.emailPlainText(Pipeline._i18n["An error occured while monitoring of"] + " " + str(self.dir_in) + (" (" + self.book["name"] + ")" if self.book and "name" in self.book else ""), traceback.format_exc(), self.email_settings["smtp"], self.email_settings["sender"], self.email_settings["recipients"])
                except Exception:
                    logging.exception("[" + Report.thread_name() + "] Could not e-mail exception")
    
    def _handle_book_events_thread(self):
        while self._dirInAvailable and self._shouldRun:
            try:
                if not os.path.isdir(self.dir_in):
                    # when base dir is not available we should stop watching the directory,
                    # this just catches a potential race condition
                    time.sleep(1)
                    continue
                
                self.book = None
                
                with self._lock:
                    books = [b for b in self._queue if int(time.time()) - b["last_event"] > self._inactivity_timeout]
                    books = sorted(books, key=lambda b: b["last_event"], reverse=True) # process recently modified books first
                    
                    # process books that were started manually first (manual trigger or book modification)
                    books_autotriggered = [b for b in books if "autotriggered" in b["events"]]
                    books_manual = [b for b in books if not "autotriggered" in b["events"]]
                    books = books_manual
                    books.extend(books_autotriggered)
                    
                    if books:
                        logging.info("[" + Report.thread_name() + "] queue: " + ", ".join([b["name"] for b in books][:5]) + (", ... ( " + str(len(books) - 5) + " more )" if len(books) > 5 else ""))
                    
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
                    
                    # trigger book event
                    else:
                        # configure utils before processing book
                        self.utils.report = Report(self)
                        self.utils.filesystem = Filesystem(self)
                        
                        try:
                            if event == "created":
                                self.on_book_created()
                            
                            elif event == "deleted":
                                self.on_book_deleted()
                            
                            else:
                                self.on_book_modified()
                            
                        except Exception:
                            self.utils.report.error("An error occured while handling the book")
                            self.utils.report.error(traceback.format_exc())
                            logging.exception("[" + Report.thread_name() + "] An error occured while handling the book")
                        
                        finally:
                            if self._stopAfterFirstJob:
                                self.stop(exit=True)
                            try:
                                if self.utils.report.should_email:
                                    logging.exception("[" + Report.thread_name() + "] Sending email")
                                    self.utils.report.email(self.email_settings["smtp"], self.email_settings["sender"], self.email_settings["recipients"])
                                else:
                                    logging.exception("[" + Report.thread_name() + "] Not sending email")
                            except Exception:
                                logging.exception("[" + Report.thread_name() + "] An error occured while sending email")
                            finally:
                                logpath = self.utils.report.attachLog()
                                logging.exception("[" + Report.thread_name() + "] Logfile: " + logpath)
                
            except Exception:
                logging.exception("[" + Report.thread_name() + "] " + Pipeline._i18n["An error occured while checking for book events"] + (": " + str(self.book["name"]) if self.book and "name" in self.book else ""))
                try:
                    Report.emailPlainText(Pipeline._i18n["An error occured while checking for book events"] + (": " + str(self.book["name"]) if self.book and "name" in self.book else ""), traceback.format_exc(), self.email_settings["smtp"], self.email_settings["sender"], self.email_settings["recipients"])
                except Exception:
                    logging.exception("[" + Report.thread_name() + "] Could not e-mail exception")
                
            finally:
                time.sleep(1)
    
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
        elif "autotriggered" in book["events"]:
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
        logging.info("[" + Report.thread_name() + "] Book created (unhandled book event): "+self.book['name'])
    
    # This should be overridden
    def on_book_modified(self):
        logging.info("[" + Report.thread_name() + "] Book modified (unhandled book event): "+self.book['name'])
    
    # This should be overridden
    def on_book_deleted(self):
        logging.info("[" + Report.thread_name() + "] Book deleted (unhandled book event): "+self.book['name'])

class DummyPipeline(Pipeline):
    uid = "dummy"
    title = "Dummy"
    book = {}
    
    utils = None
    running = False
    
    def __init__(self, title=None, uid=None, inherit_config_from=None):
        if title:
            self.title = title
        if uid:
            self.uid = uid
        elif title:
            self.uid = "dummy_{}".format(re.sub(r'[^a-z0-9]', '', title.lower()))
        self.utils = DotMap()
        self.utils.report = DummyReport(self)
        self.utils.filesystem = Filesystem(self)
        self._shouldRun = False
        
        if inherit_config_from:
            assert issubclass(inherit_config_from, Pipeline)
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
    
    def stop(self, *args, **kwargs):
        self._shouldRun = False
    
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
