#!/usr/bin/env python3

import sys
import time

from watchdog.observers import Observer
from watchdog.events import PatternMatchingEventHandler
from pathlib import Path
from threading import Thread, RLock

if sys.version_info[0] != 3:
    print("# This script requires Python version 3.x")
    sys.exit(1)

class Pipeline(PatternMatchingEventHandler):
    lock = RLock()
    
    # constants (set during instantiation)
    inactivity_timeout = 10
    observer = None
    base = None
    bookHandlerThread = None
    bookHandlerThreadShouldRun = False
    
    # dynamic (reset on stop(), changes over time)
    queue = []
    
    # other
    
    def __init__(self, base):
        self.queue = [] # discards pre-existing files
        self.base = base
        super(Pipeline, self).__init__()
    
    def start(self, inactivity_timeout=10):
        self.inactivity_timeout = inactivity_timeout
        self.observer = Observer()
        self.observer.schedule(self, path=self.base, recursive=True)
        self.observer.start()
        self.bookHandlerThreadShouldRun = True
        self.bookHandlerThread = Thread(target=self.handle_book_events_thread)
        self.bookHandlerThread.setDaemon(True)
        self.bookHandlerThread.start()
    
    def stop(self):
        if self.bookHandlerThread:
            self.bookHandlerThreadShouldRun = False
        if self.observer:
            self.observer.stop()
            self.observer.join()
            self.observer = None
    
    def process(self, event):
        source_path = Path(event.src_path).relative_to(self.base)
        dest_path = None
        if hasattr(event, 'dest_path'):
            dest_path = Path(event.dest_path).relative_to(self.base)
        
        if str(source_path) == ".":
            return # ignore
        
        book = source_path.parts[0]
        
        nicetext = event.event_type + " " + book
        if len(source_path.parts) > 1 or dest_path:
            nicetext += ':'
        if len(source_path.parts) > 1:
            nicetext += ' directory ' if event.is_directory else ' file '
            nicetext += '/'.join(source_path.parts[1:])
        if dest_path:
            nicetext += ' to '
            if len(dest_path.parts) > 1:
                nicetext += '/'.join(dest_path.parts[1:]) + ' in '
            if source_path.parts[0] != dest_path.parts[0]:
                nicetext += ' book '+dest_path.parts[0]
        nicetext = " ".join(nicetext.split())
        print(nicetext)
        
        book_event = {
            'book': book,
            'source': str(source_path),
            'dest': str(dest_path),
            'nicetext': nicetext,
            'event_type': str(event.event_type),
            'is_directory': event.is_directory
        }
        self.addBookEvent(book_event)
        if book_event['event_type'] == 'moved':
            book_event['book'] = dest_path.parts[0]
            self.addBookEvent(book_event)
    
    def addBookEvent(self, event):
        with self.lock:
            book_in_queue = False
            for item in self.queue:
                if item['book'] == event['book']:
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
                self.queue.append({
                     'book': event['book'],
                     'events': [ event ],
                     'last_event': int(time.time())
                })
    
    def on_created(self, event):
        self.process(event)
    
    def on_modified(self, event):
        self.process(event)
    
    def on_moved(self, event):
        self.process(event)
    
    def on_deleted(self, event):
        self.process(event)
    
    def handle_book_events_thread(self):
        while self.bookHandlerThreadShouldRun:
            try:
                self.handle_book_events()
                time.sleep(1)
            except:
                print("Unexpected error:", sys.exc_info()[0])
    
    def handle_book_events(self):
        book = None
        
        with self.lock:
            x = [b['book'] + ": " + str(int(time.time()) - b['last_event']) for b in self.queue]
            
            books = [b for b in self.queue if int(time.time()) - b['last_event'] > self.inactivity_timeout]
            if not len(books):
                return
            book = books[0]
            
            new_queue = [b for b in self.queue if b is not book]
            self.queue = new_queue
        
        print("processing book: "+book['book'])


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
