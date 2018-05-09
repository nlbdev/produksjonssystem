#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import shutil
import tempfile
import traceback
from pydub import AudioSegment
from lxml import etree as ElementTree
from core.pipeline import Pipeline
from core.utils.epub import Epub

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Audio_Abstract(Pipeline):
    uid = "create-abstracts"
    title = "Hent ut lydutdrag"
    labels = ["Lydbok", "Innlesing", "Talesyntese"]

    parentdirs = {
                  "abstracts": "excerpt",
                  "back-cover": "back-cover",
                  "test-audio": "sample"
                  }

    def on_book_deleted(self):
        if not(len(self.book["name"]) <= 6):
            self.utils.report.should_email = False
        self.utils.report.info("Slettet lydbok i mappa: " + self.book['name'])
        self.utils.report.title = "Lydbok slettet: " + self.book['name']

    def on_book_modified(self):
        self.utils.report.info("Endret lydbok i mappa: " + self.book['name'])
        self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny lydbok i mappa: " + self.book['name'])
        self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")

        temp_absdir_obj = tempfile.TemporaryDirectory()
        temp_absdir = temp_absdir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_absdir)

        file_exists = {
                       "abstracts": False,
                       "back-cover": False,
                       "test-audio": False
                      }

        if(self.book["name"].endswith(".txt")):
            self.utils.report.should_email = False
            return False
        if not os.path.isfile(os.path.join(temp_absdir, "ncc.html")):
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎. Er dette en daisy 2.02 lydbok med en ncc.html fil?"
            return False
        try:
            nccdoc = ElementTree.parse(os.path.join(temp_absdir, "ncc.html")).getroot()

        except Exception:
            self.utils.report.error("Klarte ikke lese ncc fila. Sjekk loggen for detaljer. Avbryter...")
            self.utils.report.debug(traceback.format_exc())
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet. 😭👎. ncc.html er invalid"
            return False

        audio_identifier = ""
        audio_title = ""
        audio_title = " (" + nccdoc.xpath("string(//*[@name='dc:title']/@content)") + ") "
        audio_identifier = nccdoc.xpath("string(//*[@name='dc:identifier']/@content)")
        audio_identifier = audio_identifier[0:6]

        if audio_identifier == (""):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + "Lydbok feilet 😭👎"
            return False

        try:
            smilFile = nccdoc.xpath("substring-before(//*[text()='Bokomtale' or text()='Baksidetekst' or text()='Omslagstekst']/@href,'#')")
            smilFile_Id = nccdoc.xpath("substring-after(//*[text()='Bokomtale' or text()='Baksidetekst' or text()='Omslagstekst']/@href,'#')")

        except Exception:
            self.utils.report.debug(traceback.format_exc())
            self.utils.report.error("Det oppstod en feil for" + audio_identifier + " under lasting av smilfilene. Sjekk loggen for detaljer.")
            return
        # Back-cover

        if (smilFile != ""):
            try:
                smildoc = ElementTree.parse(os.path.join(temp_absdir, smilFile)).getroot()
                mp3File = smildoc.xpath("string((//audio/@src)[1])")
                mp3File_start = smildoc.xpath("substring-before(substring-after(((//par[@id='{0}' or text/@id='{0}']//audio)[1]/@clip-begin),'='),'s')".format(smilFile_Id))
                mp3File_end = smildoc.xpath("substring-before(substring-after(((//par[@id='{0}' or text/@id='{0}']//audio)[last()]/@clip-end),'='),'s')".format(smilFile_Id))
                if mp3File_start == mp3File_end:
                    self.utils.report.error("Klarte ikke å bestemme start-/slutt-tid for baksidetekst")

                # Creates audio segment in milliseconds from start to end of the abstract file
                mp3 = AudioSegment.from_mp3(os.path.join(temp_absdir,mp3File))
                new_mp3 = mp3[float(mp3File_start)*1000:float(mp3File_end)*1000]
                new_mp3.export(os.path.join(temp_absdir, "Baksidetekst.mp3"))
                self.utils.report.info("Baksidetekst eksportert fra: "+mp3File)
                file_exists["back-cover"] = True

            except Exception:
                self.utils.report.debug(traceback.format_exc())
                self.utils.report.warn("Klarte ikke hente ut baksidetekst for " + audio_identifier + " sjekk loggen for detaljer.")
        else:
            self.utils.report.warn("Baksidetekst ikke funnet for " + audio_identifier)

        # creates abstract from ncc --> smil --> mp3
        several_smilFiles = []
        several_smilFiles_id = []
        try:
            number_of_smilfiles = int(nccdoc.xpath("count(//@href)"))
            for i in range(number_of_smilfiles):
                several_smilFiles.append(nccdoc.xpath("substring-before((//@href)[{0}],'#')".format(i+1)))
                several_smilFiles_id.append(nccdoc.xpath("substring-after((//@href)[{0}],'#')".format(i+1)))
        except Exception:
            self.utils.report.debug(traceback.format_exc())
            self.utils.report.warn("Klarte ikke hente ut .smil filene for " + audio_identifier + audio_title)

        timeout = time.time() + 60 * 2
        duration = 0
        num = 0
        try:
            while(duration <= 50 and time.time() < timeout and int(number_of_smilfiles/2+num) < int(number_of_smilfiles * 0.9)):
                smilFile_abstract = several_smilFiles[int(number_of_smilfiles * 0.5+num)]
                smilFile_abstract_id = several_smilFiles_id[int(number_of_smilfiles * 0.5+num)]
                smildoc_abstract = ElementTree.parse(os.path.join(temp_absdir, smilFile_abstract)).getroot()

                mp3File_abstract_start = float(smildoc_abstract.xpath("substring-before(substring-after(((//par[@id='{0}' or text/@id='{0}']//audio)[1]/@clip-begin),'='),'s')".format(smilFile_abstract_id)))

                if (smilFile_abstract == several_smilFiles[int(number_of_smilfiles * 0.5+num)+1]):
                    smilFile_abstract_id = several_smilFiles_id[int(number_of_smilfiles * 0.5+num)+1]

                mp3File_abstract_end = float(smildoc_abstract.xpath("substring-before(substring-after(((//par[@id='{0}' or text/@id='{0}']//audio)[last()]/@clip-end),'='),'s')".format(smilFile_abstract_id)))
                duration = mp3File_abstract_end - mp3File_abstract_start
                num = num + 1
            mp3File_abstract = smildoc_abstract.xpath("string((//audio/@src)[1])")
        except Exception:
            self.utils.report.debug(traceback.format_exc())
            self.utils.report.warn("Lydutdrag fra smilfiler feilet. Sjekk loggen for detaljer.")

        if (duration >= 75):
            mp3File_abstract_end = mp3File_abstract_start+75

        # As a last resort, just use an mp3 of sufficient length

        if (duration < 50):
                try:
                    for item in os.listdir(temp_absdir):
                        if (item.endswith(".mp3")):
                            try_mp3 = AudioSegment.from_mp3(os.path.join(temp_absdir, item))
                            if (len(try_mp3) > 120000):
                                mp3File_abstract = item
                                mp3File_abstract_start = 0.0
                                mp3File_abstract_end = 75.0
                                break
                except Exception:
                    self.utils.report.debug(traceback.format_exc())
                    self.utils.report.warn("Klarte ikke hente ut lydutdrag basert på mp3 filene i mappa. Sjekk loggen for detaljer.")

        # Export abstract
        try:
            mp3_abstract = AudioSegment.from_mp3(os.path.join(temp_absdir, mp3File_abstract))
            new_mp3_abstract = mp3_abstract[mp3File_abstract_start*1000:mp3File_abstract_end*1000]
            final_mp3 = new_mp3_abstract.fade_out(3000)
            final_mp3.export(os.path.join(temp_absdir, "Lydutdrag.mp3"))
            self.utils.report.info("Lydutdrag eksportert fra: " + mp3File_abstract)
            file_exists["abstracts"] = True

        except Exception:
            self.utils.report.debug(traceback.format_exc())
            self.utils.report.warn("Klarte ikke eksportere Lydutdrag.mp3. Har du ffmpeg kodeken for .mp3 filer?")

        # Copies abstract and back cover to dir_out
        if (os.path.isfile(os.path.join(temp_absdir, "Lydutdrag.mp3")) or os.path.isfile(os.path.join(temp_absdir, "Baksidetekst.mp3"))):

            if (file_exists["back-cover"]):
                shutil.copy(os.path.join(temp_absdir, "Baksidetekst.mp3"), os.path.join(temp_absdir, "Testlytt.mp3"))
                file_exists["test-audio"] = True
                if (self.parentdirs["abstracts"]):
                    self.utils.report.info("Baksidetekst og lydutdrag funnet. Kopierer til lydsnutter")
                else:
                    self.utils.report.info("Baksidetekst funnet. Kopierer til lydsnutter")
            elif (self.parentdirs["abstracts"]):
                shutil.copy(os.path.join(temp_absdir, "Lydutdrag.mp3"), os.path.join(temp_absdir, "Testlytt.mp3"))
                file_exists["test-audio"] = True
                self.utils.report.info("Lydutdrag funnet. Kopierer til lydsnutter")

            for key in self.parentdirs:
                if(file_exists[key]):
                    archived_path = self.utils.filesystem.storeBook(os.path.join(temp_absdir, self.parentdirs[key]+".mp3"), audio_identifier, parentdir=self.parentdirs[key], file_extension="mp3")
                    self.utils.report.attachment(None, archived_path, "DEBUG")

            self.utils.report.title = self.title + ": " + audio_identifier + " lydutdrag ble eksportert 👍😄" + audio_title
        else:
            self.utils.report.title("Klarte ikke hente ut hverken baksidetekst eller lydutdrag 😭👎. ") + audio_title


if __name__ == "__main__":
    Audio_Abstract().run()
