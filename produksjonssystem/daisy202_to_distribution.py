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
from mutagen.mp3 import MP3

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.bibliofil import Bibliofil
from core.config import Config
from core.utils.filesystem import Filesystem
from core.utils.metadata import Metadata

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Daisy202ToDistribution(Pipeline):
    uid = "daisy202-to-distribution"
    title = "Daisy 2.02 til validering"
    labels = ["Lydbok", "Statped"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 550
    dp1_home = ""
    validator_script = ""
    nlbsamba_out = ""

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.should_email = False
        self.utils.report.title = self.title + " kilde slettet: " + self.book['name']

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book(self):
        self.utils.report.info("Validerer Daisy 2.02 lydbok")

        if self.dp1_home == "" or self.validator_script == "":
            if not self.init_environment():
                self.utils.report.error("Pipeline1 ble ikke funnet. Avbryter..")
                return False

        folder = self.book["name"]
        if self.book["name"].isnumeric() is False:
            self.utils.report.warn(f"{folder} er ikke et tall, prosesserer ikke denne boka. Mulig det er en multivolum bok.")
            self.utils.report.should_email = False
            return False

        if os.path.isdir(os.path.join(self.dir_out, folder)):
            self.utils.report.error(f"{folder} finnes allerede på share, avbryter.")
            return False

        if self.nlbsamba_out == "":
            self.nlbsamba_out = Config.get("nlbsamba.dir")
        if self.nlbsamba_out is None:
            self.nlbsamba_out = ""

        temp_obj = tempfile.TemporaryDirectory()
        temp_dir = temp_obj.name
        Filesystem.copy(self.utils.report, self.book["source"], temp_dir)

        if not os.path.isfile(os.path.join(temp_dir, "ncc.html")):
            self.utils.report.error("Finner ikke ncc fila")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎. Er dette en daisy 2.02 lydbok med en ncc.html fil?"
            return False
        try:
            ncc_tree = ElementTree.parse(os.path.join(temp_dir, "ncc.html"))
            ncc_encoding = ncc_tree.docinfo.encoding.lower()
            nccdoc = ncc_tree.getroot()

        except Exception:
            self.utils.report.info("Klarte ikke lese ncc fila. Sjekk loggen for detaljer.")
            self.utils.report.debug(traceback.format_exc(), preformatted=True)
            return False

        edition_identifier = ""
        audio_title = ""
        audio_title = nccdoc.xpath("string(//*[@name='dc:title']/@content)")
        edition_identifier = nccdoc.xpath("string(//*[@name='dc:identifier']/@content)")

        if ncc_encoding != 'utf-8':
            self.utils.report.error(self.book["name"] + ": Encodingen til filen er ikke utf-8, (f{ncc_encoding}) avbryter.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        str_edition_identifier = str(edition_identifier)
        str_book_name = str(self.book["name"])
        if edition_identifier == ("") or str_edition_identifier != str_book_name:
            self.utils.report.error(self.book["name"] + f": Klarte ikke å bestemme boknummer basert på dc:identifier. dc:identifier: {str_edition_identifier} mappenavn: {str_book_name}")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        self.utils.report.info("Henter metadata fra api.nlb.no")
        creative_work_metadata = None
        edition_metadata = None

        timeout = 0
        while creative_work_metadata is None and timeout < 5:

            timeout = timeout + 1
            creative_work_metadata = Metadata.get_creative_work_from_api(edition_identifier, editions_metadata="all", use_cache_if_possible=True, creative_work_metadata="all")
            edition_metadata = Metadata.get_edition_from_api(edition_identifier)
            if creative_work_metadata is not None:
                break

        if creative_work_metadata is None:
            self.utils.report.warning("Klarte ikke finne et åndsverk tilknyttet denne utgaven. Prøver igjen senere.")
            return False

        library = edition_metadata["library"].lower()

        # in case of wrong upper lower cases
        if library == "nlb":
            library = "NLB"
        elif library == "statped":
            library = "Statped"
        elif library == "kabb":
            library = "KABB"

        periodical = False
        if creative_work_metadata["newspaper"] is True or creative_work_metadata["magazine"] is True:
            periodical = True
            if len(edition_identifier) != 12:
                self.utils.report.error(f"Boka {edition_identifier} er en avis eller et magasin, men utgavenummeret har ikke 12 siffer")
                return False
        else:
            if len(edition_identifier) != 6:
                self.utils.report.error(f"Boka {edition_identifier} har ikke 6 siffer")
                return False

        root_directory = Path(temp_dir)
        max_size = 702545920 - 20971520
        size = sum(f.stat().st_size for f in root_directory.glob('**/*') if f.is_file())
        multi_volume = False
        if size >= max_size:
            self.utils.report.info(f"{edition_identifier} er på størrelse {size}, sjekker om det er en multivolum bok.")
            multi_volume = True
        else:
            self.utils.report.info(f"{edition_identifier} er på størrelse {size} bytes")

        multi_volume_dirs = []
        if multi_volume:
            files_dir = os.listdir(self.dir_in)

            for file in files_dir:
                if file.startswith(self.book["name"]) and file[-1].isdigit() and file[-2] == "_":
                    self.utils.report.info(f"{file} er en del av multi volum boka {edition_identifier}")
                    multi_volume_dirs.append(file)
                    multi_volume_directory = Path(os.path.join(self.dir_in, file))
                    multi_volume_size = size = sum(f.stat().st_size for f in multi_volume_directory.glob('**/*') if f.is_file())
                    if multi_volume_size >= max_size:
                        self.utils.report.info(f" Multi volum mappen {file} er på størrelse {multi_volume_size}, dette er for stort")
                        self.utils.report.title = self.title + ": " + self.book["name"] + " Lydbok feilet 😭👎"
                        return False
                    else:
                        multi_volume_files = os.listdir(multi_volume_directory)
                        self.utils.report.info(f"Validerer filer til multi volum {file}...")
                        if self.check_files(edition_identifier, multi_volume_files, library, multi_volume_directory, multi_volume) is False:
                            return False

            if len(multi_volume_dirs) <= 0:
                self.utils.report.error(f"{edition_identifier} bør være en multivolum bok, men har ikke flere multivolum mapper. Avbryter.")
                self.utils.report.title = self.title + ": " + self.book["name"] + "Lydbok feilet 😭👎"
                return False

        files_book = os.listdir(temp_dir)

        if "default.css" in files_book and library != "Statped":
            self.utils.report.info("Erstatter default.css med en tom fil")
            open(os.path.join(temp_dir, "default.css"), 'w').close()

        self.utils.report.info("Validerer filer...")
        if self.check_files(edition_identifier, files_book, library, temp_dir, False) is False:
            return False

        dc_creator = nccdoc.xpath("string(//*[@name='dc:creator']/@content)")
        if not len(dc_creator) >= 1:
            self.utils.report.error(f"{edition_identifier} finner ikke dc:creator, dette må boka ha")
            return False

        dc_narrator = nccdoc.xpath("string(//*[@name='ncc:narrator']/@content)")
        if not len(dc_narrator) >= 1:
            self.utils.report.error(f"{edition_identifier} finner ikke ncc:narrator, dette må boka ha")
            return False

        multimedia_types = ["audioOnly", "audioNcc", "audioPartText", "audioFullText", "textPartAudio", "textNcc"]
        ncc_multimedia_type = nccdoc.xpath("string(//*[@name='ncc:multimediaType']/@content)")
        if ncc_multimedia_type not in multimedia_types:
            self.utils.report.error(f"{edition_identifier} har ikke en valid ncc:multimediaType, dette må boka ha. Multimediatype er {ncc_multimedia_type}")
            return False

        first_head_class = nccdoc.xpath("string(//*[local-name()='h1'][1]/@class)")
        second_head = nccdoc.xpath("string(//*[local-name()='h1'][2])").lower()

        accepted_second_head = ["lydbokavtalen", "audiobook agreement", "the audiobook agreement", "tigar announcement", "nlb"]

        if first_head_class != "title":
            self.utils.report.error(f"{edition_identifier} første heading {first_head_class} er ikke title")
            return False

        if second_head not in accepted_second_head and library != "Statped" and creative_work_metadata["newspaper"] is False and not (creative_work_metadata["magazine"] is True and library == "KABB"):
            self.utils.report.error(f"{edition_identifier} andre heading {second_head} er ikke Lydbokavtalen, Audiobook agreement, eller Tigar announcement")
            return False

        if library != "Statped":
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
                if self.nlbsamba_out != "":
                    archived_path_samba_multi, stored_samba_multi = self.utils.filesystem.storeBook(os.path.join(self.dir_in, folder), folder, dir_out=self.nlbsamba_out)
                    self.utils.report.attachment(None, archived_path_samba_multi, "DEBUG")
                shutil.rmtree(os.path.join(self.dir_in, folder))

        if library == "Statped":
            css_format = "Statped"
        elif edition_metadata["includesText"] is True:
            css_format = "daisy202"
        else:
            css_format = "daisy202-ncc"
        self.utils.report.info(f"Inserting CSS: {css_format}")
        if library != "Statped":
            self.utils.filesystem.insert_css(os.path.join(temp_dir, "default.css"), library, css_format)

        files_temp = os.listdir(temp_dir)
        archived_path, stored = self.utils.filesystem.storeBook(temp_dir, edition_identifier)
        if self.nlbsamba_out != "":
            archived_path_samba, stored_samba = self.utils.filesystem.storeBook(temp_dir, edition_identifier, dir_out=self.nlbsamba_out)
            self.utils.report.attachment(None, archived_path_samba, "DEBUG")

        files_out = os.listdir(os.path.join(self.dir_out, edition_identifier))
        if self.nlbsamba_out != "":
            if len(files_temp) == len(os.listdir(os.path.join(self.nlbsamba_out, edition_identifier))):
                with open(os.path.join(self.nlbsamba_out, edition_identifier, '.donedaisy'), 'w') as file:
                    self.utils.report.debug(".donedaisy created")
            else:
                self.utils.report.error(f"MANGLER FILER i {self.nlbsamba_out}, sjekk utmappa")
                return False
        if len(files_temp) == len(files_out):
            with open(os.path.join(self.dir_out, edition_identifier, '.donedaisy'), 'w') as file:
                self.utils.report.debug(".donedaisy created")
        else:
            self.utils.report.error(f"MANGLER FILER i {self.dir_out}, sjekk utmappa")
            return False

        self.utils.report.info("Boka er godkjent og overført")

        if periodical:
            available_title = ""
            if creative_work_metadata["newspaper"] is False:
                available_title = audio_title
            Bibliofil.book_available("DAISY 2.02", edition_identifier, title=available_title)

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

        if self.dp1_home == "":
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

    def check_files(self, edition_identifier, files_book, library, temp_dir, multi_volume):
        playlist_extensions = ["m3u", "m3u8", "pls", "wpl", "xspf"]
        contains_playlist = False
        small_file = False
        for file_book in files_book:
            file_book_path = os.path.join(temp_dir, file_book)
            self.utils.report.debug(f"Checking file: {file_book}")
            if file_book == "_nettleserbok.html":
                self.utils.report.info(f"Sletter {file_book}")
                os.remove(file_book_path)
                continue
            if file_book == "nettleserbok.min.css":
                self.utils.report.info(f"Sletter {file_book}")
                os.remove(file_book_path)
                continue
            if os.path.isdir(file_book_path):
                if file_book != "images":
                    self.utils.report.error(f"Boka {edition_identifier} inneholder en annen undermappe ({file_book}) enn images, avbryter")
                    return False
            elif file_book.endswith(".mp3") and library != "Statped":
                if file_book.startswith("temp"):
                    os.remove(file_book_path)
                else:
                    audio_file = os.path.join(temp_dir, file_book)
                    segment = AudioSegment.from_mp3(audio_file)
                    if segment.channels != 1:
                        self.utils.report.error(f"Boka {edition_identifier} har en lydfil ({file_book}) som ikke er single channel")
                        return False
                    accepted_sample_rate = [22050, 44100]
                    accepted_bitrate = [31, 32, 33, 47, 48, 49, 63, 64, 65]  # kbps
                    sample_rate = segment.frame_rate
                    if sample_rate not in accepted_sample_rate:
                        self.utils.report.error(f"Boka {edition_identifier} har en lydfil ({file_book}) som ikke har en riktig sample rate ({sample_rate})")
                        return False
                    f = MP3(audio_file)
                    bitrate = round(f.info.bitrate/1000)
                    if bitrate not in accepted_bitrate:
                        self.utils.report.error(f"Boka {edition_identifier} har en lydfil ({file_book}) som ikke har en riktig bitrate ({bitrate} kbps)")
                        return False
                    file_size = os.path.getsize(audio_file)
                    if file_size >= 102400 and file_size <= 8388608:
                        small_file = True
                    if file_size >= 104857600:
                        self.utils.report.error(f"Boka {edition_identifier} har en lydfil ({file_book}) som er større enn 100MB")
                        return False

            elif file_book.endswith(".wav"):
                self.utils.report.error(f"Boka {edition_identifier} inneholder .wav filer, avbryter")
                return False

            else:
                for ext in playlist_extensions:
                    if file_book.endswith(ext):
                        contains_playlist = True
                        os.rename(file_book_path, os.path.join(temp_dir, edition_identifier + "." + ext))

        if contains_playlist is False and library != "Statped" and library != "KABB" and multi_volume is False:
            self.utils.report.error(f"Boka {edition_identifier} inneholder ingen playlist filer")
            return False
        if small_file is False and library != "Statped":
            self.utils.report.error(f"Boka {edition_identifier} inneholder ingen lydfil mellom 0.1-8 MB")
            return False
        return True


if __name__ == "__main__":
    Daisy202ToDistribution().run()
