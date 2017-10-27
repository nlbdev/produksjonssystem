#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import tempfile
import time
from datetime import datetime, timezone
import subprocess

from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class IncomingNordic(Pipeline):
    title = "Automatisk validering av Nordic EPUB 3 ved mottak"
    
    epub_in = None
    valid_out = None
    invalid_out = None
    report_out = None
    
    def __init__(self, epub_in, valid_out, invalid_out, report_out):
        self.queue = [] # discards pre-existing files
        self.epub_in = epub_in
        self.valid_out = valid_out
        self.invalid_out = invalid_out
        self.report_out = report_out
        super().__init__(epub_in)
    
    def on_book_moved(self, book):
        pass # do nothing
    
    def on_book_deleted(self, book):
        pass # do nothing
    
    def on_book_modified(self, book):
        self.on_book_created(book)
    
    def on_book_created(self, book):
        print("Book created: "+book['name'])
        
        dp2_home = "/opt/daisy-pipeline2"
        dp2_cli = dp2_home + "/cli/dp2"
        saxon_cli = "java -jar " + dp2_home + "/system/framework/org.daisy.libs.saxon-he-9.5.1.5.jar"
        
        # temp while testing
        dp2_home = "echo"
        dp2_cli = "echo"
        saxon_cli = "echo"
        
        # Unik identifikator for denne jobben
        uid = datetime.now(timezone.utc).strftime("%F_%H-%M-%S.") + str(round((time.time() % 1) * 1000)).zfill(3)
        
        # Bruk sub-mapper for å unngå overskriving og filnavn-kollisjoner
        workspace_dir_object = tempfile.TemporaryDirectory()
        workspace_dir = workspace_dir_object.name
        invalid_dir = self.invalid_out + "/" + uid + "/"
        
        book_id = book["name"]
        book_dir = workspace_dir + book_id + "/"
        source = os.path.join(book["base"], book["name"])
        
        # unzip EPUB hvis den er zippet
        if os.path.isfile(source) and book["name"].endswith(".epub"):
            book_id = book["name"].replace(".epub","")
            book_dir = workspace_dir + book_id + "/"
            self.utils.report.info("pakker ut " + book["name"])
            os.makedirs(book_dir)
            self.utils.epub.unzip(None, None)
            self.utils.epub.unzip(source, book_dir)
        return
            
#        # eller bare kopier filesettet hvis den ikke er zippet
#        elif os.path.isdir(book["source"]):
#            self.utils.filesystem.copy(book["source"], book_dir)
#            
#        # hvis det hverken er en EPUB eller en mappe så er noe galt; avbryt
#        else:
#            self.utils.report.info(book_id + " er hverken en \".epub\"-fil eller en mappe.")
#            shutil.move(book["source"], invalid_dir)
#            return
        
        # EPUBen må inneholde en "EPUB/package.opf"-fil (en ekstra sjekk for å være sikker på at dette er et EPUB-filsett)
        if not os.path.isfile(book_dir + "EPUB/package.opf"):
            self.utils.report.info(book_id + "EPUB/package.opf eksisterer ikke; kan ikke validere EPUB.")
            shutil.move(book["source"], invalid_dir)
            report.email(book_id + ": ERROR")
            return
        
        # sørg for at filrettighetene stemmer
        os.chmod(book_dir, 0o777)
        for root, dirs, files in os.walk(book_dir):
            for d in dirs:
                os.chmod(os.path.join(root, d), 0o777)
            for f in files:
                os.chmod(os.path.join(root, f), 0o666)
        
        book_file = book_dir + ".epub"
        
        # lag en zippet versjon av EPUBen også
        self.utils.report.info("Pakker sammen " + book_id + "...")
        self.utils.epub.zip(book_dir, book_file)
        
        # -- Kommer vi hit så er vi ganske sikre på at vi har med et EPUB-filsett å gjøre. --
        
        job_dir  = workspace_dir + "nordic-epub3-validate/"
        os.makedirs(job_dir)

        result_log = job_dir + "log.txt"
        result_report = job_dir + "report.html"
        result_dir = job_dir + "result/"
        
        job_id = None
        result_status = None
        
        try:
            # run validator
            process = self.utils.filesystem.run([dp2_cli, "nordic-epub3-validate", "--epub", book_file, "--output", result_dir, "-p"], book["source"])
            
            # get dp2 job id
            process = self.utils.filesystem.run("cat " + job_dir + "stdout.txt | grep Job | grep sent | head -n 1 | sed 's/^Job \\(.*\\) sent.*$/\\1/'", book["source"])
            job_id = process.stdout.decode("utf-8").strip()
            
            # get validation log
            process = self.utils.filesystem.run([dp2_cli, "log", "--output", result_log, job_id], book["source"])
            
            # get validation status
            process = self.utils.filesystem.run(dp2_cli + " status " + job_id + " | grep Status | sed 's/.*Status: //'")
            result_status = process.stdout.decode("utf-8").strip()
            
            # get validation report
            process = self.utils.filesystem.run("find " + result_dir + "html-report/ -type f | head -n 1")
            result_report_temp = process.stdout.decode("utf-8").strip()
            shutil.move(result_report_temp, result_report)
            
            with open(job_dir + "status.txt", "a") as f:
                f.write("status: "+str(result_status))
            self.utils.report.info("status: " + result_status)
            self.utils.report.info("report: " + result_report)
            self.utils.report.info("log: " + result_log)
            
            process = self.utils.filesystem.run([dp2_cli, "delete", job_id], book["source"])
            
        except subprocess.TimeoutExpired as e:
            self.utils.report.info("Validering av " + book_id + " tok for lang tid og ble derfor stoppet.")
            shutil.move(book["source"], invalid_dir)
            report.email(book_id + ": ERROR")
            return
        
        self.utils.report.info(Report.fromHtml(result_report))
        
        if result_status != "DONE":
            self.utils.report.info("Klarte ikke å validere boken")
            shutil.move(book["source"], invalid_dir)
            report.email(book_id + ": ERROR")
            return
        
        self.utils.report.info("Boken er valid")
        
        self.utils.report.info("########## Kopierer til master-arkiv ##########")
        
        self.utils.filesystem.moveBook(self.valid_out, book_dir, book_id)
        self.utils.report.info("$BOOK_ID ble lagt til i master-arkivet.")
        report.email(book_id + ": DONE")
        return
        
        # TODO:
        # - self.utils.epubCheck på mottatt EPUB
        # - EPUB 3 Accessibility Checker på mottatt EPUB
        # - separat pipeline(?):
        #   - Konverter til NLBPUB
        #       if self.utils.epub.meta(book_dir, "nordic:guidelines") == "2015-1":
        #           nordic-epub3-to-nlbpub (= preprocessing + epub-to-nlbpub ?)
        #       else:
        #           epub-to-nlbpub
        #   - self.utils.epubCheck på NLBPUB
        #   - EPUB 3 Accessibility Checker på NLBPUB
        # - separat pipeline: EPUB til DTBook
        # - separat pipeline: EPUB til HTML
        # - separat pipeline: EPUB til innlesnings-EPUB
        # - separat pipeline: Zippet versjon av EPUB-master

if __name__ == "__main__":
    epub_in = os.environ.get("DIR_IN")
    valid_out = os.environ.get("DIR_OUT_VALID")
    invalid_out = os.environ.get("DIR_OUT_INVALID")
    report_out = os.environ.get("DIR_OUT_REPORT")
    
    assert epub_in != None and len(epub_in) > 0 and os.path.exists(epub_in), "The DIR_IN environment variable must be specified and the target must exist."
    assert valid_out != None and len(valid_out) > 0 and os.path.exists(valid_out), "The DIR_OUT_VALID environment variable must be specified and the target must exist."
    assert invalid_out != None and len(invalid_out) > 0 and os.path.exists(invalid_out), "The DIR_OUT_INVALID environment variable must be specified and the target must exist."
    assert report_out != None and len(report_out) > 0 and os.path.exists(report_out), "The DIR_OUT_REPORT environment variable must be specified and the target must exist."
    
    pipeline = IncomingNordic(epub_in, valid_out, invalid_out, report_out)
    
    pipeline.run()
