#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import logging
import os
import shutil
import sys
import tempfile
import threading
import time

from core.pipeline import Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.filesystem import Filesystem
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class MagazinesToValidation(Pipeline):
    uid = "magazines-to-validation"
    title = "Nyhetsbrev punkt"
    labels = ["Punktskrift"]
    uid = "magazines-to-validation"
    title = "Tidsskrift til validering"
    labels = ["Lydbok"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 5

    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self._triggerMagazinesThread = threading.Thread(target=self._trigger_magazines_thread, name="Magazines thread")
        self._triggerMagazinesThread.setDaemon(True)
        self._triggerMagazinesThread.start()

        logging.info("Pipeline \"" + str(self.title) + "\" started watching for magazines")

    def stop(self, *args, **kwargs):
        super().stop(*args, **kwargs)

        if self._triggerMagazinesThread and self._triggerMagazinesThread != threading.current_thread():
            self._triggerMagazinesThread.join()

        logging.info("Pipeline \"" + str(self.title) + "\" stopped")

    def _trigger_magazines_thread(self):
        last_check = 0

        self.watchdog_bark()
        while self.shouldRun:
            time.sleep(5)
            self.watchdog_bark()

            if not self.dirsAvailable():
                continue

            max_update_interval = 60
            if time.time() - last_check < max_update_interval:
                continue

            last_check = time.time()
            magazines = os.listdir(self.dir_in)
            for magazine in magazines:
                identifier = magazine[:6]
                logging.info(f"Examining {identifier}...")
                magazines_with_identifier = []
                for mag in magazines:
                    if mag.startswith(identifier):
                        magazines_with_identifier.append(mag)
                        magazines_with_identifier.sort
                        logging.info(magazines_with_identifier)


    def on_book_deleted(self):
        return True

    def on_book_modified(self):
        return True

    def on_book_created(self):
        return True

    def on_book(self):
        return True


if __name__ == "__main__":
    MagazinesToValidation().run()
