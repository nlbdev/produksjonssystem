#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile
import time

from core.pipeline import Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Newsletter(Pipeline):
    uid = "newsletter-to-braille"
    title = "Nyhetsbrev punkt"
    labels = ["Punktskrift"]
    publication_format = "Braille"
    expected_processing_time = 20

    def on_book_deleted(self):
        return True

    def on_book_modified(self):
        self.utils.report.info("Nyhetsbrev: " + self.book['name'])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Nyhetsbrev: " + self.book['name'])
        return self.on_book()

    def on_book(self):

        self.utils.report.info("Lager nyhetsbrev for punktskrift i pipeline2")
        newsletter = ""
        newsletter_identifier = "120209"
        newsletter_identifier += time.strftime("%m%Y")
        with DaisyPipelineJob(self, "nlb:catalog-month", {"month": self.book["name"]}) as dp2_job_newsletter:
            if dp2_job_newsletter.status == "DONE":
                for file in os.listdir(os.path.join(dp2_job_newsletter.dir_output, "output-dir")):
                    if file.endswith(".xhtml"):
                        newsletter = file
                        break
                if newsletter == "":
                    self.utils.report.error("Could not find html")
                    return False
                os.mkdir(os.path.join(dp2_job_newsletter.dir_output, "output-dir", newsletter_identifier))
                html_file = os.path.join(dp2_job_newsletter.dir_output, "output-dir", newsletter)
                os.rename(html_file, os.path.join(os.path.dirname(html_file), newsletter_identifier, newsletter_identifier + ".html"))
                html_file = os.path.join(os.path.dirname(html_file), newsletter_identifier, newsletter_identifier + ".html")

            if dp2_job_newsletter.status != "DONE":
                self.utils.report.info("Klarte ikke å konvertere boken")
                self.utils.report.title = self.title + " feilet 😭👎"
                return False
            temp_html_obj = tempfile.NamedTemporaryFile()
            temp_html = temp_html_obj.name

            xslt = Xslt(self,
                        parameters={"identifier": newsletter_identifier},
                        stylesheet=os.path.join(Xslt.xslt_dir, self.uid, "newsletter-id.xsl"),
                        source=html_file,
                        target=temp_html)

            if not xslt.success:
                self.utils.report.title = self.title + ": " + newsletter_identifier + " feilet 😭👎"
                return False
            shutil.copy(temp_html, html_file)

        archived_path = self.utils.filesystem.storeBook(os.path.dirname(html_file), newsletter_identifier)

        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info("Nyhetsbrev punktskrift ble produsert i pipeline2")
        self.utils.report.title = self.title + ": " + newsletter_identifier + " ble produsert 👍😄"
        return True


if __name__ == "__main__":
    Newsletter().run()
