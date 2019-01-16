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

from dotmap import DotMap
from core.utils.filesystem import Filesystem
from core.utils.report import Report
from core.pipeline import DummyPipeline, Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Newsletter(Pipeline):
    uid = "newsletter-to-braille"
    title = "Nyhetsbrev punkt"
    labels = ["Punktskrift"]
    logPipeline = None
    newsletter_identifier = ""
    year_month = ""
    publication_format = "Braille"
    expected_processing_time = 20

    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self._triggerNewsletterThread = threading.Thread(target=self._trigger_newsletter_thread, name="Newsletter thread")
        self._triggerNewsletterThread.setDaemon(True)
        self._triggerNewsletterThread.start()

        logging.info("Pipeline \"" + str(self.title) + "\" started watching for newsletters")

    def stop(self, *args, **kwargs):
        super().stop(*args, **kwargs)

        if self._triggerNewsletterThread and self._triggerNewsletterThread != threading.current_thread():
            self._triggerNewsletterThread.join()

        logging.info("Pipeline \"" + str(self.title) + "\" stopped")

    def _trigger_newsletter_thread(self):
        last_check = 0
        # If no newsletter this month, trigger newsletter
        while self._dirsAvailable and self._shouldRun:
            time.sleep(5)
            max_update_interval = 60 * 60

            if time.time() - last_check < max_update_interval:
                continue

            last_check = time.time()
            self.newsletter_identifier = "120209"
            self.newsletter_identifier += time.strftime("%m%Y")
            self.year_month = datetime.datetime.today().strftime('%Y-%m')
            if self.newsletter_identifier not in os.listdir(self.dir_out):
                logging.info("Lager nyhetsbrev for: " + self.year_month)
                self.trigger(self.newsletter_identifier)

    def on_book_deleted(self):
        return True

    def on_book_modified(self):
        self.utils.report.info("Nyhetsbrev: " + self.newsletter_identifier)
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Nyhetsbrev: " + self.newsletter_identifier)
        return self.on_book()

    def on_book(self):

        self.utils.report.info("Lager nyhetsbrev for punktskrift i pipeline2")
        with DaisyPipelineJob(self, "nlb:catalog-month", {"month": self.year_month, "make-email": "false"}) as dp2_job_newsletter:
            if dp2_job_newsletter.status == "DONE":
                newsletter = None
                for file in os.listdir(os.path.join(dp2_job_newsletter.dir_output, "output-dir")):
                    if file.endswith(".xhtml"):
                        newsletter = file
                        break
                if not newsletter:
                    self.utils.report.error("Could not find html")
                    return False
                os.mkdir(os.path.join(dp2_job_newsletter.dir_output, "output-dir", self.newsletter_identifier))
                html_file = os.path.join(dp2_job_newsletter.dir_output, "output-dir", newsletter)
                os.rename(html_file, os.path.join(os.path.dirname(html_file), self.newsletter_identifier, self.newsletter_identifier + ".html"))
                html_file = os.path.join(os.path.dirname(html_file), self.newsletter_identifier, self.newsletter_identifier + ".html")

            if dp2_job_newsletter.status != "DONE":
                self.utils.report.info("Klarte ikke å konvertere boken")
                self.utils.report.title = self.title + " feilet 😭👎"
                return False
            temp_html_obj = tempfile.NamedTemporaryFile()
            temp_html = temp_html_obj.name

            # Use xslt to transform to correct dc:identifier
            xslt = Xslt(self,
                        parameters={"identifier": self.newsletter_identifier},
                        stylesheet=os.path.join(Xslt.xslt_dir, self.uid, "newsletter-id.xsl"),
                        source=html_file,
                        target=temp_html)

            if not xslt.success:
                self.utils.report.error("Transformering av html med xslt feilet")
                self.utils.report.title = self.title + ": " + self.newsletter_identifier + " feilet 😭👎"
                return False
            shutil.copy(temp_html, html_file)

        archived_path, stored = self.utils.filesystem.storeBook(os.path.dirname(html_file), self.newsletter_identifier)

        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info("Nyhetsbrev punktskrift ble produsert i pipeline2")
        self.utils.report.title = self.title + ": " + self.newsletter_identifier + " ble produsert 👍😄"
        return True


if __name__ == "__main__":
    Newsletter().run()
