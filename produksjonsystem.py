#!/usr/bin/env python3

import sys
import time

from watchdog.observers import Observer
from watchdog.events import PatternMatchingEventHandler
from pathlib import Path

if sys.version_info[0] != 3:
    print("# This script requires Python version 3.x")
    sys.exit(1)

class MyHandler(PatternMatchingEventHandler):
    base = None
    queue = []
    
    def __init__(self, base):
        super(MyHandler, self).__init__()
        self.base = base
    
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
        
        book_in_queue = False
        for queue_item in self.queue:
            if queue_item['book'] == book:
                book_in_queue = True
                event_in_queue = False
                for queue_event in queue_item['events']:
                    if queue_event == book_event:
                        event_in_queue = True
                if not event_in_queue:
                    queue_item['events'].append(book_event)
                queue_item['last_event'] = int(time.time())
                break
        if not book_in_queue:
            self.queue.append({
                 'book': book,
                 'events': [ book_event ],
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
    
    def handle_book_events(self):
        x = [b['book'] + ": " + str(int(time.time()) - b['last_event']) for b in self.queue]
        
        books = [b for b in self.queue if int(time.time()) - b['last_event'] > 10]
        if not len(books):
            return
        book = books[0]
        
        new_queue = [b for b in self.queue if b is not book]
        self.queue = new_queue
        print("processing book: "+book['book'])
        

if __name__ == '__main__':
    args = sys.argv[1:]
    myHandler = MyHandler(args[0])
    observer = Observer()
    observer.schedule(myHandler, path=myHandler.base if args else '.', recursive=True)
    observer.start()
    
    try:
        while True:
            time.sleep(1)
            myHandler.handle_book_events()
    except KeyboardInterrupt:
        observer.stop()

    observer.join()
