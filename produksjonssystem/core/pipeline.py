#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import traceback
import time
import os
import sys
import logging

from pathlib import Path
from threading import Thread, RLock
from dotmap import DotMap

from core.utils.epub import Epub
from core.utils.filesystem import Filesystem
from core.utils.report import Report

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

# Notes:
# - the watchdog python module uses inotify for monitoring files. inotify needs to be configured allow watching enough files/folders
# - inotify seems to use 100MB (± 50MB ?) RAM to monitor about 500k files
# - there are currently 7499 DTBooks in our DTBook archive, which consists of a total of 258210 files/folders (⇒ 35 files/folders per book)
# - system should support 100k books per format, which means it needs to monitor about 3.5M files/folders per format (⇒ 1GB)
# - system should support 20 formats, which means it needs to monitor about 70M files/folders in total (⇒ 21GB)
# - so inotify probably needs to have 21 GB RAM available for monitoring 100k books in 20 formats
# - to mitigate:
#   - in the beginning we'll probably watch at most 5 formats, and we won't have more 10-20k books for a while
#     - meaning we need 1 GB for inotify
#     - inotify needs to be configured to watch at least 3,5M files/folders
#   - in the future, each pipeline can run in its own docker container,
#     i.e. inotify only needs to handle one format (TODO files/folders ⇒ TODO MB)
#   - a custom implementation that is not based on inotify could be implemented,
#     for instance by iterating all top-level files/folders in the watched directory,
#     checking 1 per second, doing a MD5 checksum of the file/folder, and comparing
#     with a previously calculated MD5 checksum to see if something has changed.
#     checksums doesn't have to be stored between each run since the pipeline should
#     also be able to be triggered manually from slack if needed.
# 
# UPDATE: it seems that inotify doesn't report changes when the change happens on a remote filesystem,
#         so a custom mechanism has to be implemented.

class Pipeline():
    """
    Base class for creating pipelines.
    Do not override methods or variables starting with underscore (_).
    """
    
    _lock = RLock()
    
    # The current book
    book = None
    
    # Directories
    dir_in = None
    dir_out = None
    dir_reports = None
    
    # constants (set during instantiation)
    _inactivity_timeout = 10
    _observer = None
    _bookHandlerThread = None
    _shouldHandleBooks = False
    _shouldRun = True
    _stopAfterFirstJob = False
    _loglevel = None
    
    # dynamic (reset on stop(), changes over time)
    _queue = None
    _md5 = None
    
    # utility classes; reconfigured every time a book is processed to simplify function signatures
    utils = None
    
    # email settings
    email_settings = None
    
    # should be overridden when extending this class
    title = None
    
    def __init__(self, loglevel=None):
        self.utils = DotMap()
        self.utils.report = None
        self.utils.epub = None
        self.utils.filesystem = None
        self._queue = []
        self._loglevel = logging.INFO if not None else loglevel
        logging.basicConfig(stream=sys.stdout, level=self._loglevel)
        super().__init__()
    
    def start(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None):
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" starting...")
        
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
        stop_after_first_job = os.environ.get("STOP_AFTER_FIRST_JOB")
        
        assert dir_in != None and len(dir_in) > 0, "The environment variable DIR_IN must be specified, and must point to a directory."
        assert dir_out != None and len(dir_out) > 0 and os.path.exists(dir_out), "The environment variable DIR_OUT must be specified, and must point to a directory that exists."
        assert dir_reports != None and len(dir_reports) > 0 and os.path.exists(dir_reports), "The environment variable DIR_REPORTS must be specified, and must point to a directory that exists."
        assert not stop_after_first_job or stop_after_first_job in [ "1", "true", "0", "false" ], "The environment variable STOP_AFTER_FIRST_JOB, if defined, must be \"true\"/\"false\" (or \"1\"/\"0\")."
        
        self._stopAfterFirstJob = False
        if stop_after_first_job in [ "true", "1" ]:
            self._stopAfterFirstJob = True
        
        self.dir_in = str(os.path.normpath(dir_in)) + '/'
        self.dir_out = str(os.path.normpath(dir_out)) + '/'
        self.dir_reports = str(os.path.normpath(dir_reports)) + '/'
        self.email_settings = email_settings
        
        if Filesystem.ismount(self.dir_in):
            logging.error("[" + Report.thread_name() + "] " + self.dir_in + " is the root of a mounted filesystem. Please use subdirectories instead, so that mounting/unmounting is not interpreted as file changes.")
            return
        if not os.path.isdir(self.dir_in):
            logging.error("[" + Report.thread_name() + "] " + self.dir_in + " is not available. Will not start watching.")
            return
        self._inactivity_timeout = inactivity_timeout
        
        self._shouldHandleBooks = True
        
        self._md5 = {}
        for f in os.listdir(self.dir_in):
            self._update_md5(f)
        
        self._bookMonitorThread = Thread(target=self._monitor_book_events_thread)
        self._bookMonitorThread.setDaemon(True)
        self._bookMonitorThread.start()
        
        self._bookHandlerThread = Thread(target=self._handle_book_events_thread)
        self._bookHandlerThread.setDaemon(True)
        self._bookHandlerThread.start()
        
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" started watching " + self.dir_in)
    
    def stop(self, exit=False):
        if self._bookHandlerThread:
            self._shouldHandleBooks = False
        if exit:
            self._shouldRun = False
        if self._observer:
            try:
                self._observer.stop()
                self._observer.join()
            except Exception:
                logging.exception("[" + Report.thread_name() + "] Failed to start watching \"" + self.dir_in + "\"")
            finally:
                self._observer = None
        self._queue = []
        logging.info("[" + Report.thread_name() + "] Pipeline \"" + str(self.title) + "\" stopped")
    
    def run(self, inactivity_timeout=10, dir_in=None, dir_out=None, dir_reports=None, email_settings=None):
        """
        Run in a blocking manner (useful from command line)
        """
        self.start(inactivity_timeout, dir_in, dir_out, dir_reports, email_settings)
        try:
            while self._shouldRun:
                if not os.path.isdir(self.dir_in):
                    if self._shouldHandleBooks:
                        logging.warn("[" + Report.thread_name() + "] " + self.dir_in + " is not available. Stop watching...")
                        self.stop()
                        
                    else:
                        logging.warn("[" + Report.thread_name() + "] " + self.dir_in + " is still not available...")
                        
                if not self._shouldHandleBooks and os.path.isdir(self.dir_in):
                    logging.info("[" + Report.thread_name() + "] " + self.dir_in + " is available again. Start watching...")
                    self.start(self._inactivity_timeout, self.dir_in, self.dir_out, self.dir_reports)
                
                time.sleep(1)
                
        except KeyboardInterrupt:
            pass
        self.stop()
    
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
        assert os.path.exists(path)
        
        shallow_md5, _ = Filesystem.path_md5(path=path, shallow=True)
        deep_md5, modified = Filesystem.path_md5(path=path, shallow=False)
        modified = max(modified if modified else 0, self._md5[name]["modified"] if name in self._md5 else 0)
        self._md5[name] = {
            "shallow": shallow_md5,
            "shallow_checked": int(time.time()),
            "deep": deep_md5,
            "deep_checked": int(time.time()),
            "modified": modified,
        }
    
    def _monitor_book_events_thread(self):
        while self._shouldHandleBooks and self._shouldRun:
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
                continue
            
            time.sleep(1) # unless anything has recently changed, give the system time to breathe between each iteration
            
            # do a shallow check of files and folders (i.e. don't check file sizes, modification times etc. in subdirectories)
            dirlist = os.listdir(self.dir_in)
            for f in dirlist:
                if not f in self._md5:
                    self._update_md5(f)
                    self._add_book_to_queue(f, "created")
                    logging.debug("[" + Report.thread_name() + "] book created: " + f)
                    continue
                
                shallow_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_in, f), shallow=True)
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
                deep_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_in, f), shallow=False)
                self._md5[f]["deep_checked"] = int(time.time())
                if deep_md5 != self._md5[f]["deep"]:
                    self._md5[f]["modified"] = int(time.time())
                    self._update_md5(f)
                    self._add_book_to_queue(f, "modified")
                    logging.debug("[" + Report.thread_name() + "] book modified: " + f)
    
    def _handle_book_events_thread(self):
        while self._shouldHandleBooks and self._shouldRun:
            if not os.path.isdir(self.dir_in):
                # when base dir is not available we should stop watching the directory,
                # this just catches a potential race condition
                time.sleep(1)
                continue
            
            try:
                self.book = None
                
                with self._lock:
                    books = [b for b in self._queue if int(time.time()) - b["last_event"] > self._inactivity_timeout]
                    books = sorted(books, key=lambda b: b["last_event"])
                    
                    self.book = None
                    if len(books):
                        self.book = books[0]
                        
                        new_queue = [b for b in self._queue if b is not self.book]
                        self._queue = new_queue
                
                # If the book was both created and deleted within a short time interval; then ignore it
                if self.book and "created" in self.book["events"] and "deleted" in self.book["events"]:
                    self.book = None
                
                if self.book:
                    # configure utils before processing book
                    self.utils.report = Report(self)
                    self.utils.epub = Epub(self)
                    self.utils.filesystem = Filesystem(self)
                    
                    try:
                        if "created" in self.book["events"]:
                            self.on_book_created()
                        
                        elif "deleted" in self.book["events"]:
                            self.on_book_deleted()
                        
                        else:
                            self.on_book_modified()
                        
                    except Exception:
                        logging.exception("[" + Report.thread_name() + "] An error occured while handling the book event")
                        logpath = self.utils.report.attachLog()
                        logging.exception("[" + Report.thread_name() + "] Logfile: " + logpath)
                    
                    finally:
                        if self._stopAfterFirstJob:
                            self._shouldRun = False
                
            except Exception:
                logging.exception("[" + Report.thread_name() + "] An error occured while checking for book events")
                
            finally:
                time.sleep(1)
    
    # This should be overridden
    def on_book_created(self):
        logging.info("[" + Report.thread_name() + "] Book created (unhandled book event): "+self.book['name'])
    
    # This should be overridden
    def on_book_modified(self):
        logging.info("[" + Report.thread_name() + "] Book modified (unhandled book event): "+self.book['name'])
    
    # This should be overridden
    def on_book_deleted(self):
        logging.info("[" + Report.thread_name() + "] Book deleted (unhandled book event): "+self.book['name'])


if __name__ == '__main__':
    args = sys.argv[1:]
    pipeline = Pipeline(args[0])
    pipeline.run()
