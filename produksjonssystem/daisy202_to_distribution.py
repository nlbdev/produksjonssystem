#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import subprocess
import tempfile
import traceback
from pathlib import Path
from pydub import AudioSegment
from pydub.utils import mediainfo

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.filesystem import Filesystem
from core.utils.metadata import Metadata

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Daisy202ToDistribution(Pipeline):
    uid = "daisy202-to-distribution"
    title = "Daisy 2.02 til Distribusjon"
    labels = ["Lydbok", "Statped"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 550
    dp1_home = ""
    validator_script = ""

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " EPUB-kilde slettet: " + self.book['name']

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book(self):
        if self.dp1_home is "" or self.validator_script is "":
            if not self.init_environment():
                self.utils.report.error("Pipeline1 ble ikke funnet. Avbryter..")
                return False

        folder = self.book["name"]
        if self.book["name"].isnumeric() is False:
            self.utils.report.warn(f"{folder} er ikke et tall, prosesserer ikke denne boka. Mulig det er en multivolum bok.")
            self.utils.report.should_email = False
            return False

        temp_obj = tempfile.TemporaryDirectory()
        temp_dir = temp_obj.name
        Filesystem.copy(self.utils.report, self.book["source"], temp_dir)

        if not os.path.isfile(os.path.join(temp_dir, "ncc.html")):
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎. Er dette en daisy 2.02 lydbok med en ncc.html fil?"
            return False
        try:
            ncc_tree = ElementTree.parse(os.path.join(temp_dir, "ncc.html"))
            ncc_encoding = ncc_tree.docinfo.encoding.lower()
            nccdoc = ncc_tree.getroot()

        except Exception:
            self.utils.report.info("Klarte ikke lese ncc fila. Sjekk loggen for detaljer.")
            self.utils.report.debug(traceback.format_exc(), preformatted=True)

        edition_identifier = ""
        audio_title = ""
        audio_title = " (" + nccdoc.xpath("string(//*[@name='dc:title']/@content)") + ") "
        edition_identifier = nccdoc.xpath("string(//*[@name='dc:identifier']/@content)")

        if ncc_encoding != 'utf-8':
            self.utils.report.error(self.book["name"] + ": Encodingen til filen er ikke utf-8, (f{ncc_encoding}) avbryter.")
            self.utils.report.title = self.title + ": " + self.book["name"] + "Lydbok feilet 😭👎"
            return False

        if edition_identifier == ("") or str(edition_identifier) != str(self.book["name"]):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + "Lydbok feilet 😭👎"
            return False

        root_directory = Path(temp_dir)
        size = sum(f.stat().st_size for f in root_directory.glob('**/*') if f.is_file())
        multi_volume = False
        if size >= 702545920:
            self.utils.report.info(f"{edition_identifier} er på størrelse {size}, sjekker om det er en multivolum bok.")
            multi_volume = True

        multi_volume_dirs = []
        if multi_volume:
            files_dir = os.listdir(self.dir_in)

            for file in files_dir:
                if file.startswith(self.book["name"]) and file[-1].isdigit() and file[-2] == "_":
                    self.utils.report.info(f"{file} er en del av multi volum boka {edition_identifier}")
                    multi_volume_dirs.append(file)

            if len(multi_volume_dirs) <= 1:
                self.utils.report.error(f"{edition_identifier} bør være en multivolum bok, men har ikke flere multivolum mapper. Avbryter.")
                self.utils.report.title = self.title + ": " + self.book["name"] + "Lydbok feilet 😭👎"
            return False

        creative_work_metadata = None

        timeout = 0
        while creative_work_metadata is None and timeout < 5:

            timeout = timeout + 1
            creative_work_metadata = Metadata.get_creative_work_from_api(edition_identifier, editions_metadata="all", use_cache_if_possible=True, creative_work_metadata="all")
            if creative_work_metadata is not None:
                break

        if creative_work_metadata is None:
            self.utils.report.warning("Klarte ikke finne et åndsverk tilknyttet denne utgaven. Prøver igjen senere.")
            return False

        periodical = False
        if creative_work_metadata["newspaper"] is True or creative_work_metadata["magazine"] is True:
            periodical = True
            if len(edition_identifier) is not 12:
                self.utils.report.error(f"Boka {edition_identifier} er en avis eller et magasin, men utgavenummeret har ikke 12 siffer")
                return False
        else:
            if len(edition_identifier) is not 6:
                self.utils.report.error(f"Boka {edition_identifier} har ikke 6 siffer")
                return False

        files_book = os.listdir(temp_dir)
        playlist_extensions = ["m3u", "m3u8", "pls", "wpl", "xspf"]

        for file_book in files_book:
            file_book_path = os.path.join(temp_dir, file_book)
            if os.path.isdir(file_book):
                if file_book != "images":
                    self.utils.report.error(f"Boka {edition_identifier} inneholder en annen undermappe (f{file_book}) enn images, avbryter")
                    return False
            elif file_book.endswith(".mp3"):
                if file_book.startswith("temp"):
                    os.remove(file_book)
                else:
                    audio_file = os.path.join(temp_dir, file_book)
                    segment = AudioSegment.from_mp3(audio_file)
                    if segment.channels != 1:
                        self.utils.report.error(f"Boka {edition_identifier} har en lydfil ({file_book}) som ikke er single channel")
                        return False
                    accepted_sample_rate = [22050, 44100]
                    accepted_bitrate = [32, 48, 64] # kbps
                    sample_rate = segment.frame_rate
                    if sample_rate not in accepted_sample_rate:
                        self.utils.report.error(f"Boka {edition_identifier} har en lydfil ({file_book}) som ikke har en riktig sample rate ({sample_rate})")
                        return False
                    bitrate = int(float(mediainfo(audio_file)["bit_rate"])/1000)
                    if bitrate not in accepted_bitrate:
                        self.utils.report.error(f"Boka {edition_identifier} har en lydfil ({file_book}) som ikke har en riktig bitrate ({bitrate})")
                        return False

            elif file_book.endswith(".wav"):
                self.utils.report.error(f"Boka {edition_identifier} inneholder .wav filer, avbryter")
                return False
            contains_playlist = False
            for ext in playlist_extensions:
                if file_book.endswith(ext):
                    contains_playlist = True
                    os.rename(file_book_path, os.path.join(temp_dir, audio_title + ext))

            if contains_playlist is False:
                self.utils.report.error(f"Boka {edition_identifier} inneholder ingen playlist filer")
                return False

        dc_creator = nccdoc.xpath("string(//*[@name='dc:creator']/@content)")
        if not len(dc_creator) >= 1:
            self.utils.report.error(f"{edition_identifier} finner ikke dc:creator, dette må boka ha")
            return False

      #  dc_rights = nccdoc.xpath("string(//*[@name='dc:rights']/@content)")
      #  if not len(dc_rights) >= 1:
      #          self.utils.report.error(f"{edition_identifier} finner ikke dc:rights, dette må boka ha")
      #          return False

        dc_narrator = nccdoc.xpath("string(//*[@name='ncc:narrator']/@content)")
        if not len(dc_narrator) >= 1:
            self.utils.report.error(f"{edition_identifier} finner ikke ncc:narrator, dette må boka ha")
            return False

        multimedia_types = ["audioOnly", "audioNcc", "audioPartText", "audioFullText", "textPartAudio", "textNcc"]
        ncc_multimedia_type = nccdoc.xpath("string(//*[@name='ncc:multimediaType']/@content)")
        if ncc_multimedia_type not in multimedia_types:
            self.utils.report.error(f"{edition_identifier} har ikke en valid ncc:multimediaType, dette må boka ha. Multimediatype er {ncc_multimedia_type}")
            return False
       # print(ElementTree.tostring(nccdoc, encoding='utf8', method='xml'))
        first_head_class = nccdoc.xpath("string(//*[local-name()='h1'][1]/@class)")
        second_head = nccdoc.xpath("string(//*[local-name()='h1'][2])")

        accepted_second_head = ["Lydbokavtalen", "Audiobook agreement", "Tigar announcement"]

        if first_head_class != "title":
            self.utils.report.error(f"{edition_identifier} første heading {first_head_class} er ikke title")
            return False

        if second_head not in accepted_second_head:
            self.utils.report.error(f"{edition_identifier} andre heading {second_head} er ikke Lydbokavtalen, Audiobook agreement, eller Tigar announcement")
            return False

        status = self.validate_book(os.path.join(temp_dir, "ncc.html"))
        if status == "ERROR" or status is False:
            self.utils.report.error("Pipeline validator: Boka er ikke valid. Se rapport.")
            return False
        self.utils.report.info("Pipeline validator: Boka er valid")

        if multi_volume:
            for folder in multi_volume_dirs:
                self.utils.report.debug(f"Flytter multivolum fil {folder}")
                archived_path_multi, stored = self.utils.filesystem.storeBook(os.path.join(self.dir_in, folder), folder)
                self.utils.report.attachment(None, archived_path_multi, "DEBUG")
                shutil.rmtree(os.path.join(self.dir_in, folder))

        self.utils.filesystem.insert_css(os.path.join(temp_dir, "default.css"), "nlb", "daisy202")

        # TODO: Kopiere over til nlbsamba også
        archived_path, stored = self.utils.filesystem.storeBook(temp_dir, edition_identifier)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + edition_identifier + " er valid 👍😄" + audio_title
        self.utils.filesystem.deleteSource()
        return True

    def init_environment(self):
        if os.environ.get("PIPELINE1_HOME"):
            self.dp1_home = os.environ.get("PIPELINE1_HOME")
        else:
            self.dp1_home = "/opt/pipeline1/pipeline.sh"
        self.validator_script = os.path.join(os.path.dirname(self.dp1_home),
                                             "scripts", "verify", "Daisy202DTBValidator.taskScript")
        if os.path.isfile(self.validator_script):
            return True
        else:
            return False

    def validate_book(self, path_ncc):

        if self.dp1_home is "":
            self.utils.report.error("Pipeline1 ble ikke funnet. Avslutter..")
            return False
        input = "--input=" + path_ncc
        report = os.path.join(self.utils.report.reportDir(), "report.xml")
        report_command = "--validatorOutputXMLReport=" + report

        try:
            self.utils.report.info("Kjører Daisy 2.02 validator i Pipeline1...")
            process = self.utils.filesystem.run([self.dp1_home, self.validator_script, input, report_command], stdout_level='DEBUG')
            if process.returncode != 0:
                self.utils.report.debug(traceback.format_stack())

            status = "DEBUG"
            error_message = []
            for line in self.utils.report._messages["message"]:
                if "[ERROR" in line["text"]:
                    status = "ERROR"
                    error_message.append(line["text"])
            if status == "ERROR":
                for line_error in error_message:
                    self.utils.report.error(line_error)
            self.utils.report.attachment(None, os.path.join(self.utils.report.reportDir(), "report.xml"), status)
            self.utils.report.info("Daisy 2.02 validator ble ferdig.")
            return status
        except subprocess.TimeoutExpired:
            self.utils.report.error("Det tok for lang tid å kjøre Daisy 2.02 validator og den ble derfor stoppet.")
            self.utils.report.title = self.title
            return False


if __name__ == "__main__":
    Daisy202ToDistribution().run()
