#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import traceback
import time
import os

from watchdog.observers import Observer
from watchdog.events import PatternMatchingEventHandler
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

class Pipeline(PatternMatchingEventHandler):
    """
    Base class for creating pipelines.
    Do not override methods or variables starting with underscore (_), or methods marked with "DO NOT OVERRIDE".
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
    
    # dynamic (reset on stop(), changes over time)
    _queue = None
    
    # utility classes; reconfigured every time a book is processed to simplify function signatures
    utils = None
    
    # should be overridden when extending this class
    title = None
    
    def __init__(self):
        self.utils = DotMap()
        self.utils.report = None
        self.utils.epub = None
        self.utils.filesystem = None
        self._queue = []
        super().__init__()
    
    def start(self, inactivity_timeout=10):
        print("Pipeline \"" + str(self.title) + "\" starting...")
        
        dir_in = os.environ.get("DIR_IN")
        dir_out = os.environ.get("DIR_OUT")
        dir_reports = os.environ.get("DIR_REPORTS")
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
        
        if Filesystem.ismount(self.dir_in):
            print(self.dir_in + " is the root of a mounted filesystem. Please use subdirectories instead, so that mounting/unmounting is not interpreted as file changes.")
            return
        if not os.path.isdir(self.dir_in):
            print(self.dir_in + " is not available. Will not start watching.")
            return
        self._inactivity_timeout = inactivity_timeout
        self._observer = Observer()
        self._observer.schedule(self, path=self.dir_in, recursive=True)
        self._observer.start()
        self._shouldHandleBooks = True
        self._bookHandlerThread = Thread(target=self._handle_book_events_thread)
        self._bookHandlerThread.setDaemon(True)
        self._bookHandlerThread.start()
        print("Pipeline \"" + str(self.title) + "\" started")
    
    def stop(self):
        if self._bookHandlerThread:
            self._shouldHandleBooks = False
        if self._observer:
            try:
                self._observer.stop()
                self._observer.join()
            except Exception as e:
                print(e)
                traceback.print_tb(e.__traceback__)
            finally:
                self._observer = None
        self._queue = []
        print("Pipeline \"" + str(self.title) + "\" stopped")
    
    def run(self, inactivity_timeout=1):
        """
        Run in a blocking manner (useful from command line)
        """
        self.start(inactivity_timeout)
        try:
            while self._shouldRun:
                if not os.path.isdir(self.dir_in):
                    if self._shouldHandleBooks:
                        print(self.dir_in + " is not available. Stop watching...")
                        self.stop()
                        
                    else:
                        print(self.dir_in + " is still not available...")
                        
                if not self._shouldHandleBooks and os.path.isdir(self.dir_in):
                    print(self.dir_in + " is available again. Start watching...")
                    self.start(self._inactivity_timeout)
                
                time.sleep(1)
                
        except KeyboardInterrupt:
            pass
        self.stop()
    
    def _process(self, event):
        source_path = Path(event.src_path)
        source_path_relative = source_path.relative_to(self.dir_in)
        dest_path = None
        dest_path_relative = None
        if hasattr(event, 'dest_path'):
            dest_path = Path(event.dest_path)
            dest_path_relative = dest_path.relative_to(self.dir_in)
        
        if str(source_path_relative) == ".":
            return # ignore
        
        name = source_path_relative.parts[0]
        
        nicetext = event.event_type + " " + name
        if len(source_path_relative.parts) > 1 or dest_path_relative:
            nicetext += ':'
        if len(source_path_relative.parts) > 1:
            nicetext += ' directory ' if event.is_directory else ' file '
            nicetext += '/'.join(source_path_relative.parts[1:])
        if dest_path_relative:
            nicetext += ' to '
            if len(dest_path_relative.parts) > 1:
                nicetext += '/'.join(dest_path_relative.parts[1:]) + ' in '
            if source_path_relative.parts[0] != dest_path_relative.parts[0]:
                nicetext += ' book '+dest_path_relative.parts[0]
        nicetext = " ".join(nicetext.split())
        
        book_event = {
            'name':            name,
            'base':            str(self.dir_in),
            'source':          str(source_path)          + ("/" if event.is_directory else ""),
            'dest':            str(dest_path)            + ("/" if event.is_directory else ""),
            'source_relative': str(source_path_relative) + ("/" if event.is_directory else ""),
            'dest_relative':   str(dest_path_relative)   + ("/" if event.is_directory else ""),
            'nicetext':        nicetext,
            'event_type':      str(event.event_type),
            'is_directory':    event.is_directory
        }
        self._addBookEvent(book_event)
        if book_event['event_type'] == 'moved':
            book_event['name'] = dest_path_relative.parts[0]
            self._addBookEvent(book_event)
    
    def _addBookEvent(self, event):
        with self._lock:
            book_in_queue = False
            for item in self._queue:
                if item['name'] == event['name']:
                    book_in_queue = True
                    event_in_queue = False
                    for queue_event in item['events']:
                        if queue_event == event:
                            event_in_queue = True
                            break
                    if not event_in_queue:
                        item['events'].append(event)
                        print("filesystem event: "+event['nicetext'])
                    item['last_event'] = int(time.time())
                    break
            if not book_in_queue:
                self._queue.append({
                     'name': event['name'],
                     'base': event['base'],
                     'source': os.path.join(event['base'], event['name']),
                     'events': [ event ],
                     'last_event': int(time.time())
                })
                print("filesystem event: "+event['nicetext'])
    
    # Private method; DO NOT OVERRIDE
    def on_created(self, event):
        self._process(event)
    
    # Private method; DO NOT OVERRIDE
    def on_modified(self, event):
        self._process(event)
    
    # Private method; DO NOT OVERRIDE
    def on_moved(self, event):
        self._process(event)
    
    # Private method; DO NOT OVERRIDE
    def on_deleted(self, event):
        self._process(event)
    
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
                    x = [b['name'] + ": " + str(int(time.time()) - b['last_event']) for b in self._queue]
                    
                    books = [b for b in self._queue if int(time.time()) - b['last_event'] > self._inactivity_timeout]
                    books = sorted(books, key=lambda b: b['last_event'])
                    if not len(books):
                        self.book = None
                    else:
                        self.book = books[0]
                        
                        new_queue = [b for b in self._queue if b is not self.book]
                        self._queue = new_queue
                
                if self.book:
                    # configure utils before processing book
                    self.utils.report = Report(self)
                    self.utils.epub = Epub(self)
                    self.utils.filesystem = Filesystem(self)
                    
                    paths_all = []
                    paths_created = []
                    paths_modified = []
                    paths_moved = []
                    paths_deleted = []
                    
                    paths_all.append(self.book['source'])
                    for (dirpath, dirnames, filenames) in os.walk(self.book['source']):
                        for d in dirnames:
                            paths_all.append(dirpath+"/"+d+"/")
                        for f in filenames:
                            paths_all.append(dirpath+"/"+f)
                    
                    for event in self.book['events']:
                        if event['event_type'] == "created" and event['source'] not in paths_created:
                            paths_created.append(event['source'])
                        if event['event_type'] == "modified" and event['source'] not in paths_modified:
                            paths_modified.append(event['source'])
                        if event['event_type'] == "moved" and event['source'] not in paths_moved:
                            paths_moved.append(event['source'])
                        if event['event_type'] == "deleted" and event['source'] not in paths_deleted:
                            paths_deleted.append(event['source'])
                    
                    try:
                        # created all files in book ⇒ created
                        if set(paths_all) == set(paths_created):
                            self.on_book_created()
                        
                        # moved all files in book ⇒ moved
                        elif set(paths_all) == set(paths_moved):
                            self.on_book_moved()
                        
                        # deleted all files in book ⇒ deleted
                        elif set(paths_all) == set(paths_deleted):
                            self.on_book_deleted()
                        
                        # created, modified, moved and/or deleted some files in book ⇒ modified
                        else:
                            self.on_book_modified()
                        
                    except Exception as e:
                        print(e)
                        traceback.print_tb(e.__traceback__)
                    
                    finally:
                        if self._stopAfterFirstJob:
                            self._shouldRun = False
                
            except Exception as e:
                print(e)
                traceback.print_tb(e.__traceback__)
                
            finally:
                time.sleep(1)
    
    def on_book_created(self):
        print("Book created (unhandled book event): "+self.book['name'])
    
    def on_book_modified(self):
        print("Book modified (unhandled book event): "+self.book['name'])
    
    def on_book_moved(self):
        print("Book moved (unhandled book event): "+self.book['name'])
    
    def on_book_deleted(self):
        print("Book deleted (unhandled book event): "+self.book['name'])


if __name__ == '__main__':
    args = sys.argv[1:]
    pipeline = Pipeline(args[0])
    pipeline.run()
