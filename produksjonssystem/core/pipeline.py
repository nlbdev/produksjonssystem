#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import time
import os

from watchdog.observers import Observer
from watchdog.events import PatternMatchingEventHandler
from pathlib import Path
from threading import Thread, RLock

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class Pipeline(PatternMatchingEventHandler):
    """
    Base class for creating pipelines.
    Do not override methods or variables starting with underscore (_), or methods marked with "DO NOT OVERRIDE".
    """
    
    _lock = RLock()
    
    # constants (set during instantiation)
    _inactivity_timeout = 10
    _observer = None
    _base = None
    _bookHandlerThread = None
    _bookHandlerThreadShouldRun = False
    
    # dynamic (reset on stop(), changes over time)
    _queue = []
    
    # other
    
    def __init__(self, base):
        self._queue = [] # discards pre-existing files
        self._base = str(os.path.normpath(base))
        super().__init__()
    
    def start(self, inactivity_timeout=10):
        self._inactivity_timeout = inactivity_timeout
        self._observer = Observer()
        self._observer.schedule(self, path=self._base, recursive=True)
        self._observer.start()
        self._bookHandlerThreadShouldRun = True
        self._bookHandlerThread = Thread(target=self._handle_book_events_thread)
        self._bookHandlerThread.setDaemon(True)
        self._bookHandlerThread.start()
    
    def stop(self):
        if self._bookHandlerThread:
            self._bookHandlerThreadShouldRun = False
        if self._observer:
            self._observer.stop()
            self._observer.join()
            self._observer = None
    
    def run(self, inactivity_timeout=10):
        """
        Run in a blocking manner (useful from command line)
        """
        self.start(inactivity_timeout)
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
        self.stop()
    
    def _process(self, event):
        source_path = Path(event.src_path)
        source_path_relative = source_path.relative_to(self._base)
        dest_path = None
        dest_path_relative = None
        if hasattr(event, 'dest_path'):
            dest_path = Path(event.dest_path)
            dest_path_relative = dest_path.relative_to(self._base)
        
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
        print("filesystem event: "+nicetext)
        
        book_event = {
            'name':            name,
            'base':            str(self._base)           +  "/",
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
                    item['last_event'] = int(time.time())
                    break
            if not book_in_queue:
                self._queue.append({
                     'name': event['name'],
                     'base': event['base'],
                     'events': [ event ],
                     'last_event': int(time.time())
                })
    
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
        while self._bookHandlerThreadShouldRun:
            try:
                book = None
                
                with self._lock:
                    x = [b['name'] + ": " + str(int(time.time()) - b['last_event']) for b in self._queue]
                    
                    books = [b for b in self._queue if int(time.time()) - b['last_event'] > self._inactivity_timeout]
                    books = sorted(books, key=lambda b: b['last_event'])
                    if not len(books):
                        book = None
                    else:
                        book = books[0]
                        
                        new_queue = [b for b in self._queue if b is not book]
                        self._queue = new_queue
                
                if book:
                    paths_all = []
                    paths_created = []
                    paths_modified = []
                    paths_moved = []
                    paths_deleted = []
                    
                    paths_all.append(book['base']+book['name'])
                    for (dirpath, dirnames, filenames) in os.walk(book['base']+book['name']):
                        for d in dirnames:
                            paths_all.append(dirpath+"/"+d+"/")
                        for f in filenames:
                            paths_all.append(dirpath+"/"+f)
                    
                    for event in book['events']:
                        if event['event_type'] == "created" and event['source'] not in paths_created:
                            paths_created.append(event['source'])
                        if event['event_type'] == "modified" and event['source'] not in paths_modified:
                            paths_modified.append(event['source'])
                        if event['event_type'] == "moved" and event['source'] not in paths_moved:
                            paths_moved.append(event['source'])
                        if event['event_type'] == "deleted" and event['source'] not in paths_deleted:
                            paths_deleted.append(event['source'])
                    
                    # created all files in book => created
                    if set(paths_all) == set(paths_created):
                        self.on_book_created(book)
                    
                    # moved all files in book => moved
                    elif set(paths_all) == set(paths_moved):
                        self.on_book_moved(book)
                    
                    # deleted all files in book => deleted
                    elif set(paths_all) == set(paths_deleted):
                        self.on_book_deleted(book)
                    
                    # created, modified, moved and/or deleted some files in book => modified
                    else:
                        self.on_book_modified(book)
                
                time.sleep(1)
            except:
                print("Unexpected error:", sys.exc_info()[0])
    
    def on_book_created(self, book):
        print("Book created (unhandled book event): "+book['name'])
    
    def on_book_modified(self, book):
        print("Book modified (unhandled book event): "+book['name'])
    
    def on_book_moved(self, book):
        print("Book moved (unhandled book event): "+book['name'])
    
    def on_book_deleted(self, book):
        print("Book deleted (unhandled book event): "+book['name'])


if __name__ == '__main__':
    args = sys.argv[1:]
    pipeline = Pipeline(args[0])
    pipeline.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    pipeline.stop()
