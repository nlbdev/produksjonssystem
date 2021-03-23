# -*- coding: utf-8 -*-

import pathlib
import logging
import base64
import datetime
import hashlib
import hmac
import os
import random
import re
import shutil
import subprocess
import tempfile
import time
import traceback
import urllib
import zipfile

import psutil
import requests
from lxml import etree as ElementTree
from requests_toolbelt.multipart.encoder import MultipartEncoder

from core.utils.timeout_lock import TimeoutLock
from core.utils.filesystem import Filesystem


class DaisyPipelineJob():
    """Class used to run DAISY Pipeline 2 jobs"""

    # treat these as instance variables
    _dir_output_obj = None  # store TemporaryDirectory object in instance so that it's not cleaned up
    dir_output = None
    job_id = None
    pipeline = None
    status = None
    engine = None
    script = None
    arguments = None
    context = None
    priority = None
    found_pipeline_version = None
    found_script_version = None

    # treat these as class variables, specific for local jobs
    pid = None
    start_lock = TimeoutLock()
    dp2_home = None
    dp2_cli = None

    # treat these as class variables
    engines = None
    engine_lock = TimeoutLock()
    engine_jobs = None  # for cleaning up old jobs

    dp2_ws_namespace = {"d": 'http://www.daisy.org/ns/pipeline/data'}

    @staticmethod
    def init_environment():
        from core.pipeline import Pipeline

        DaisyPipelineJob.engines = []

        if "PIPELINE2_HOME" in Pipeline.environment:
            DaisyPipelineJob.dp2_home = Pipeline.environment["PIPELINE2_HOME"]
        else:
            DaisyPipelineJob.dp2_home = os.getenv("PIPELINE2_HOME", "/opt/daisy-pipeline2")
        DaisyPipelineJob.dp2_cli = DaisyPipelineJob.dp2_home + "/cli/dp2"

        if os.path.isfile(DaisyPipelineJob.dp2_cli):
            if not os.getenv("JAVA_HOME"):
                logging.warning(
                    "JAVA_HOME is not set! It should be set to a Java 8 installation, for instance:\n"
                    + "export \"/usr/lib/jvm/java-8-openjdk-amd64\""
                )

            DaisyPipelineJob.engines.append({
                "endpoint": "http://localhost:8181/ws",
                "authentication": "false",
                "key": "none",
                "secret": "none",
                "local": True,
            })
        else:
            DaisyPipelineJob.dp2_cli = None

        if "REMOTE_PIPELINE2_WS_ENDPOINTS" in os.environ:
            endpoints = re.sub(r"\s+", " ", os.getenv("REMOTE_PIPELINE2_WS_ENDPOINTS", "")).strip().split(" ")
            authentication = re.sub(r"\s+", " ", os.getenv("REMOTE_PIPELINE2_WS_AUTHENTICATION", "")).strip().split(" ")
            keys = re.sub(r"\s+", " ", os.getenv("REMOTE_PIPELINE2_WS_AUTHENTICATION_KEYS", "")).strip().split(" ")
            secrets = re.sub(r"\s+", " ", os.getenv("REMOTE_PIPELINE2_WS_AUTHENTICATION_SECRETS", "")).strip().split(" ")
            for e in range(0, len(endpoints)):
                DaisyPipelineJob.engines.append({
                    "endpoint": endpoints[e],
                    "authentication": authentication[e] if e < len(authentication) else "false",
                    "key": keys[e] if e < len(keys) else None,
                    "secret": secrets[e] if e < len(secrets) else None,
                    "local": False,
                })

    @staticmethod
    def local_stop_engine(pipeline):
        procs = DaisyPipelineJob.local_list_processes()
        for p in procs:
            try:
                pipeline.utils.report.debug("Stopping: {}".format(p))
                p.terminate()
            except psutil.NoSuchProcess:
                pass
            except psutil.AccessDenied:
                pipeline.utils.report.debug("Could not kill Pipeline 2 instance (PID: {})".format(p.pid))
        gone, alive = psutil.wait_procs(procs,
                                        timeout=10,
                                        callback=lambda p: pipeline.utils.report.warn("Lokal Pipeline 2-process {} terminerte med koden {}".format(
                                            p,
                                            p.returncode
                                        )))
        if len(alive) > 0:
            pipeline.utils.report.warn("Dreper {} gjenværende Pipeline 2-prosesser som ikke ble terminert".format(len(alive)))
        for p in alive:
            pipeline.utils.report.debug("Killing: {}".format(p))
            try:
                p.kill()
            except psutil.NoSuchProcess:
                pass
            except psutil.AccessDenied:
                pipeline.utils.report.debug("Could not kill Pipeline 2 instance (PID: {})".format(p.pid))
        DaisyPipelineJob.pid = None
        time.sleep(1)
        pipeline.utils.report.debug("Pipeline 2 processes after stopping/killing: {}".format(len(DaisyPipelineJob.local_list_processes())))

    def local_start_engine(self, retries=10):
        running = False
        self.pipeline.utils.report.debug("[local_start_engine] trying to acquire DP2 start lock")
        with DaisyPipelineJob.start_lock.acquire_timeout(3000) as locked:
            if locked:
                self.pipeline.utils.report.debug("[local_start_engine] acquired DP2 start lock")
                while not running and retries > 0:
                    if not self.pipeline.shouldRun:
                        break  # exit this function if we're shutting down the system

                    retries -= 1
                    procs = DaisyPipelineJob.local_list_processes()
                    if DaisyPipelineJob.pid:
                        procs = [p for p in procs if p.pid != DaisyPipelineJob.pid]  # keep DaisyPipelineJob.pid
                    if len(procs) > 0:
                        self.pipeline.utils.report.debug("found at least one unexpected Pipeline 2 instance")
                        for p in procs:
                            try:
                                self.pipeline.utils.report.debug("Stopping: {}".format(p))
                                p.terminate()
                            except psutil.NoSuchProcess:
                                pass
                            except psutil.AccessDenied:
                                self.pipeline.utils.report.debug("Could not kill Pipeline 2 instance (PID: {})".format(p.pid))
                        gone, alive = psutil.wait_procs(procs,
                                                        timeout=10,
                                                        callback=lambda p: self.pipeline.utils.report.warn(
                                                            "Pipeline 2-prosess {} terminerte med koden {}".format(
                                                                p,
                                                                p.returncode
                                                            )))
                        if len(alive) > 0:
                            self.pipeline.utils.report.warn("Dreper {} gjenstående Pipeline 2-prosesser som ikke terminerte".format(len(alive)))
                        for p in alive:
                            self.pipeline.utils.report.debug("Killing: {}".format(p))
                            try:
                                p.kill()
                            except psutil.NoSuchProcess:
                                pass
                            except psutil.AccessDenied:
                                self.pipeline.utils.report.debug("Could not kill Pipeline 2 instance (PID: {})".format(p.pid))
                        time.sleep(1)
                        self.pipeline.utils.report.debug("Pipeline 2 processes after stopping/killing: {}".format(len(DaisyPipelineJob.local_list_processes())))

                    procs = DaisyPipelineJob.local_list_processes()
                    running = len(procs) == 1
                    if len(procs) == 0:
                        self.pipeline.utils.report.debug("no running DP2 process")
                        lockfiles = [
                            os.path.join(DaisyPipelineJob.dp2_home, "data", "db", "db.lck"),
                            os.path.join(DaisyPipelineJob.dp2_home, "data", "db", "dbex.lck")
                        ]
                        for lockfile in lockfiles:
                            if os.path.isfile(lockfile):
                                try:
                                    os.remove(lockfile)
                                except Exception:
                                    self.pipeline.utils.report.debug(traceback.format_exc())
                                    self.pipeline.utils.report.debug("Could not remove Pipeline 2 lockfile")
                        try:
                            # start engine if it's not started already
                            self.pipeline.utils.report.info("Starter lokal instans av Pipeline 2…")
                            process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "help"], shell=True, cwd=DaisyPipelineJob.dp2_home)
                            if process.returncode != 0:
                                self.pipeline.utils.report.error("En feil oppstod når Pipeline 2 forsøkte å starte")
                                continue

                        except subprocess.TimeoutExpired:
                            self.pipeline.utils.report.info("Oppstart av Pipeline 2 tok for lang tid og ble derfor stoppet")
                            continue

                        except subprocess.CalledProcessError:
                            self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                            self.pipeline.utils.report.warn("En feil oppstod når Pipeline 2 startet. Vi venter noen sekunder og prøver igjen...")
                            time.sleep(5)
                            try:
                                # start engine if it's not started already
                                self.pipeline.utils.report.info("Starter lokal instans av Pipeline 2…")
                                process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "help"], shell=True, cwd=DaisyPipelineJob.dp2_home)
                                if process.returncode != 0:
                                    self.pipeline.utils.report.error("En feil oppstod når Pipeline 2 startet")
                                    continue

                            except subprocess.TimeoutExpired:
                                self.pipeline.utils.report.info("Oppstart av Pipeline 2 tok for lang tid og ble derfor stoppet")
                                continue

                            except subprocess.CalledProcessError:
                                self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                                self.pipeline.utils.report.error("En feil oppstod når Pipeline 2 forsøkte å starte")
                                continue

                        # Save PID for Pipeline 2 engine
                        procs = DaisyPipelineJob.local_list_processes()
                        if procs:
                            self.pipeline.utils.report.debug("found newly started process")
                            DaisyPipelineJob.pid = procs[0].pid
                            running = True
                        else:
                            self.pipeline.utils.report.debug("newly started process not found")

                        time.sleep(5)  # Wait a few seconds after starting Pipeline 2 before releasing the lock

                self.pipeline.utils.report.debug("[local_start_engine] releasing DP2 start lock")
                return running

            else:
                self.pipeline.utils.report.error("Ventet for lenge på tilgang til Pipeline 2")
                self.pipeline.utils.report.debug("[local_start_engine] could not acquire DP2 start lock")

        return False

    def __init__(self, pipeline, script, arguments, context={}, priority="medium", pipeline_and_script_version=None):
        if isinstance(pipeline_and_script_version, tuple):
            pipeline_and_script_version = [pipeline_and_script_version]

        self.pipeline = pipeline
        self.script = script
        self.arguments = arguments
        self.context = context
        self.priority = priority
        self.pipeline_and_script_version = pipeline_and_script_version

    def __enter__(self):
        DaisyPipelineJob.init_environment()

        self._dir_output_obj = tempfile.TemporaryDirectory(prefix="produksjonssystem-", suffix="-daisy-pipeline-output")
        self.dir_output = self._dir_output_obj.name

        if self.choose_engine():
            try:
                self.post_job()

                self.status = "IDLE"
                idle_start = time.time()
                running_start = time.time()
                idle_timeout = 3600 * 2.5
                running_timeout = 3600 * 2
                timed_out = False
                engine_died = False
                while not timed_out and self.status in ["IDLE", "RUNNING"]:
                    if not self.pipeline.shouldRun:
                        self.pipeline.utils.report.error("Systemet er i ferd med å slå seg av, og Pipeline 2-jobben ble derfor ikke ferdig.")
                        self.status = None
                        break

                    timed_out = self.status == "IDLE" and time.time() - idle_start > idle_timeout or time.time() - running_start > running_timeout
                    time.sleep(5)

                    if self.status == "IDLE":
                        self.pipeline.watchdog_bark()  # keep pipeline alive while waiting in queue
                        running_start = time.time()

                    is_alive = False
                    for retry in range(10):
                        is_alive = DaisyPipelineJob.is_alive(self.engine)
                        if is_alive:
                            break
                        time.sleep(5)
                    if not is_alive:
                        engine_died = True
                        self.pipeline.utils.report.error("Pipeline 2 kjører ikke lenger. Avbryter…")
                        break

                    # get job status
                    self.pipeline.utils.report.debug("Getting job status")
                    self.get_status()

                    self.pipeline.utils.report.debug("Pipeline 2 status: " + self.status)

                if timed_out:
                    self.pipeline.utils.report.error("Pipeline 2 brukte for lang tid")
                    self.status = None

                    # if we're using a local engine, we should stop the engine as it might have crashed
                    if self.engine["local"]:
                        DaisyPipelineJob.local_stop_engine(self.pipeline)

                elif engine_died:
                    pass  # Nothing we can do

                else:
                    # get job log (the run method will log stdout/stderr as debug output)
                    self.pipeline.utils.report.debug("Getting job log")
                    self.pipeline.utils.report.debug(self.get_log())

                    # get job results
                    self.pipeline.utils.report.debug("Getting job results")
                    self.get_results()

            except subprocess.TimeoutExpired:
                self.pipeline.utils.report.error("Pipeline 2-jobben {} tok for lang tid og ble derfor stoppet".format(self.job_id))
                self.status = None

            except Exception:
                self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                self.pipeline.utils.report.error("En feil oppstod ved kjøring av Pipeline 2-jobben (" + str(self.job_id) + ")")
                self.status = None

        else:
            self.pipeline.utils.report.error("Pipeline 2 er ikke tilgjengelig")

        return self

    def choose_engine(self, use_local=False):
        self.pipeline.utils.report.debug("[choose_engine] trying to aquire DP2 engine lock")
        with DaisyPipelineJob.engine_lock.acquire_timeout(600) as locked:
            if locked:
                self.pipeline.utils.report.debug("[choose_engine] aquired DP2 engine lock")

                self.engine = None
                min_queue_size = float('Inf')
                has_local = False

                # always start a local engine, even if we're not using it (Pipeline 2 Web UI currently depends on having it running)
                # we should remove this when we've moved the Web UI over to using another Pipeline 2 instance.
                local_engines = [e for e in DaisyPipelineJob.engines if e["local"]]
                if len(local_engines) > 0 and not DaisyPipelineJob.is_alive(local_engines[0]):
                    self.local_start_engine()

                (self.found_pipeline_version, self.found_script_version) = (None, None)

                for (pipeline_version, script_version) in self.pipeline_and_script_version:
                    if (pipeline_version, script_version) != self.pipeline_and_script_version[0]:
                        self.pipeline.utils.report.warning("Desired version of Pipeline 2 engine and version of script not found.")
                        self.pipeline.utils.report.warning(
                            "Trying Pipeline 2 engine version '{}' and script version '{}' instead…".format(pipeline_version, script_version)
                        )

                    for engine in DaisyPipelineJob.engines:
                        if not self.pipeline.shouldRun:
                            self.pipeline.utils.report.error("Systemet er i ferd med å slå seg av, og Pipeline 2-jobben ble derfor ikke startet.")
                            self.status = None
                            break

                        if engine["local"]:
                            has_local = True

                        if engine["local"] and not use_local:
                            # we're looking for remote engines: skip local engines
                            continue

                        if not engine["local"] and use_local:
                            # we're looking for local engines: skip remote engines
                            continue

                        if not self.script_available(engine, pipeline_version=pipeline_version, script_version=script_version):
                            # desired script is not available or engine is not available: don't use this engine
                            continue

                        queue_size = self.get_queue_size(engine)
                        if queue_size < min_queue_size:
                            # smaller queue than any previously found: use this engine
                            self.engine = engine
                            (self.found_pipeline_version, self.found_script_version) = (pipeline_version, script_version)
                        if queue_size == 0:
                            # empty queue: no point checking other engines
                            break

                    if self.engine:
                        break  # if we've found an appropriate engine, don't try alternative versions

                # Only start a local engine if no other engine is available
                if not self.engine and has_local:
                    self.pipeline.utils.report.warning("No remote version of the Pipeline 2 engine with the desired engine and script version were found.")
                    self.pipeline.utils.report.warning("Trying local Pipeline 2 engine instead…")

                    if self.local_start_engine():
                        self.choose_engine(use_local=True)

                if self.engine:
                    self.pipeline.utils.report.info("Bruker Pipeline 2-instans på: {}".format(self.engine["endpoint"]))
                    self.pipeline.utils.report.info("Pipeline 2-versjon: {}".format(self.found_pipeline_version))
                    self.pipeline.utils.report.info("Versjon av {}: {}".format(self.script, self.found_script_version))
                else:
                    self.pipeline.utils.report.warning("Fant ingen brukbar Pipeline 2-instans")

                self.pipeline.utils.report.debug("[choose_engine] releasing DP2 engine lock")
                return self.engine is not None

            else:
                self.pipeline.utils.report.error("Ventet for lenge på tilgang til Pipeline 2")
                self.pipeline.utils.report.debug("[choose_engine] could not aquire DP2 engine lock")
                return None

    def script_available(self, engine, pipeline_version, script_version):
        alive = None
        scripts = None

        try:
            self.pipeline.utils.report.debug(DaisyPipelineJob.encode_url(engine, "/alive", {}))
            alive = requests.get(DaisyPipelineJob.encode_url(engine, "/alive", {}))
            if alive.ok:
                alive = str(alive.content, 'utf-8')
                alive = ElementTree.XML(alive.split("?>")[-1])
            else:
                alive = None
        except Exception:
            alive = None

        if alive is None:
            self.pipeline.utils.report.warning("Pipeline 2 kjører ikke på: {}".format(engine["endpoint"]))
            return False

        # find engine version
        engine_pipeline_version = alive.attrib.get("version")

        # test for correct engine version
        if pipeline_version is not None and pipeline_version != engine_pipeline_version:
            self.pipeline.utils.report.debug("Incorrect version of Pipeline 2. Looking for {} but found {}.".format(pipeline_version,
                                                                                                                    engine_pipeline_version))
            return False

        try:
            scripts = requests.get(DaisyPipelineJob.encode_url(engine, "/scripts", {}))
            if scripts.ok:
                scripts = str(scripts.content, 'utf-8')
                scripts = ElementTree.XML(scripts.split("?>")[-1])
            else:
                scripts = None
        except Exception:
            scripts = None

        if scripts is None:
            self.pipeline.utils.report.warning("Klarte ikke å hente liste over skript fra Pipeline 2 på: {}".format(engine["endpoint"]))
            return False

        # find script
        engine_script = scripts.xpath("/d:scripts/d:script[@id='{}']".format(self.script), namespaces=DaisyPipelineJob.dp2_ws_namespace)
        engine_script = engine_script[0] if len(engine_script) else None

        # test if script was found
        if engine_script is None:
            self.pipeline.utils.report.debug("Script not found: {}".format(self.script))
            return False

        # find script version
        engine_script_version = engine_script.xpath("d:version", namespaces=DaisyPipelineJob.dp2_ws_namespace) if len(engine_script) else None
        engine_script_version = engine_script_version[0].text if len(engine_script_version) else None

        # test if script version is correct
        if script_version is not None and script_version != engine_script_version:
            self.pipeline.utils.report.debug("Incorrect version of Pipeline 2. Looking for {} but found {}.".format(script_version,
                                                                                                                    engine_script_version))
            return False

        return True

    def __exit__(self, exc_type, exc_value, trace):
        if self.job_id:
            self.delete_job(self.engine, self.job_id)

    def post_job(self):
        self.pipeline.utils.report.debug("Posting job")

        script_href = DaisyPipelineJob.encode_url(self.engine, "/scripts/{}".format(self.script), {})
        response = requests.get(script_href)
        response = str(response.content, 'utf-8')
        script = ElementTree.XML(response.split("?>")[-1])

        jobRequest = ElementTree.XML("<jobRequest xmlns=\"http://www.daisy.org/ns/pipeline/data\"/>")
        jobRequest.append(ElementTree.XML("<priority xmlns=\"http://www.daisy.org/ns/pipeline/data\">{}</priority>".format(self.priority)))
        jobRequest.append(ElementTree.XML("<script href=\"{}\" xmlns=\"http://www.daisy.org/ns/pipeline/data\"/>".format(script_href)))

        for input in script.xpath("/d:script/d:input", namespaces=DaisyPipelineJob.dp2_ws_namespace):
            if input.attrib["name"] in self.arguments:
                values = []
                argument = self.arguments[input.attrib["name"]]
                if not isinstance(argument, list):
                    argument = [argument]
                for argument_value in argument:
                    value = argument_value

                    if self.engine["local"] and self.context:
                        # we're dealing with a local Pipeline 2 instance, which we assume are running with localfs=true,
                        # so that we need to use file: URIs
                        for href in self.context:
                            if value == href:
                                value = self.context[href]
                                value = pathlib.PurePath(value) if value[0] == "/" else pathlib.PureWindowsPath(value)
                                value = value.as_uri()

                    values.append(value)

                input_xml = "<input name=\"{}\" xmlns=\"http://www.daisy.org/ns/pipeline/data\">".format(input.attrib["name"])
                for value in values:
                    input_xml += "<item value=\"{}\"/>".format(value)
                input_xml += "</input>"
                jobRequest.append(ElementTree.XML(input_xml))

        for option in script.xpath("/d:script/d:option", namespaces=DaisyPipelineJob.dp2_ws_namespace):
            if option.attrib["name"] in self.arguments:
                values = []
                argument = self.arguments[option.attrib["name"]]
                if not isinstance(argument, list):
                    argument = [argument]
                for argument_value in argument:
                    value = argument_value

                    if self.engine["local"] and self.context and option.attrib.get("type") in ["anyFileURI", "anyDirURI"]:
                        # we're dealing with a local Pipeline 2 instance, which we assume are running with localfs=true,
                        # so that we need to use file: URIs
                        for href in self.context:
                            if value == href:
                                value = self.context[href]
                                value = pathlib.PurePath(value) if value[0] == "/" else pathlib.PureWindowsPath(value)
                                value = value.as_uri()

                    values.append(value)

                option_xml = "<option name=\"{}\" xmlns=\"http://www.daisy.org/ns/pipeline/data\">".format(option.attrib["name"])
                if len(values) == 1:
                    option_xml += values[0]
                else:
                    for value in values:
                        option_xml += "<item value=\"{}\"/>".format(value)
                option_xml += "</option>"
                jobRequest.append(ElementTree.XML(option_xml))

        # Temporary files
        jobRequest_file_obj = tempfile.NamedTemporaryFile(suffix=".xml")
        context_file_obj = tempfile.NamedTemporaryFile(suffix=".zip")

        multipart_fields = {}

        response = None
        jobRequest_file = None
        context_file = None

        try:  # use `try`/`except` instead of `with` for `open`ing the files

            # Save jobRequest as a file
            jobRequest_path = jobRequest_file_obj.name
            jobRequest_document = ElementTree.ElementTree(jobRequest)
            jobRequest_document.write(jobRequest_path, xml_declaration=True, encoding='UTF-8', pretty_print=True)
            jobRequest_file = open(jobRequest_path, 'rb')
            multipart_fields["job-request"] = ('jobRequest.xml', jobRequest_file, 'application/xml')
            with open(jobRequest_path) as f:
                self.pipeline.utils.report.debug("Job request: " + "".join(f.readlines()))

            # URL to POST to
            url = DaisyPipelineJob.encode_url(self.engine, "/jobs", {})

            # If there's a context, zip it and POST the request as a multipart request
            if self.context and not self.engine["local"]:
                context_path = context_file_obj.name
                """Zip the contents of `dir`"""
                with zipfile.ZipFile(context_path, 'w') as archive:
                    for href in self.context:
                        file = self.context[href]
                        self.pipeline.utils.report.debug("zipping context: " + href + " from " + str(file))
                        archive.write(str(file), href, compress_type=zipfile.ZIP_DEFLATED)

                context_file = open(context_path, 'rb')
                multipart_fields["job-data"] = ('context.zip', context_file, 'application/zip')

                multipart = MultipartEncoder(fields=multipart_fields)

                response = requests.post(url, data=multipart, headers={"Content-Type": multipart.content_type})

            else:  # there's no context documents; do a normal POST
                response = requests.post(url, data=jobRequest_file, headers={"Content-Type": "application/xml"})

            response = str(response.content, 'utf-8')

        finally:
            try:
                if jobRequest_file is not None:
                    jobRequest_file.close()
            finally:
                if context_file is not None:
                    context_file.close()

        try:
            job = ElementTree.XML(response.split("?>")[-1])
            self.job_id = job.attrib["id"]
        except Exception as e:
            logging.debug(response)
            raise e

        return self.job_id

    def get_status(self):
        url = DaisyPipelineJob.encode_url(self.engine, "/jobs/{}".format(self.job_id), {})
        try:
            response = requests.get(url)
            if not response.ok:
                return self.status  # avoid failing if there's a single failed status request (return previous response instead)
        except Exception:
            return self.status  # avoid failing if there's a single failed status request (return previous response instead)

        response = str(response.content, 'utf-8')
        xml = ElementTree.XML(response.split("?>")[-1])
        self.status = xml.attrib["status"]
        if self.status == "DONE":
            self.status = "SUCCESS"

        return self.status

    def delete_job(self, engine, job_id):
        self.pipeline.utils.report.debug("[delete_job] trying to aquire DP2 engine lock")
        with DaisyPipelineJob.engine_lock.acquire_timeout(600) as locked:
            if locked:
                self.pipeline.utils.report.debug("[delete_job] aquired DP2 engine lock")
                url = DaisyPipelineJob.encode_url(engine, "/jobs/{}".format(job_id), {})
                try:
                    response = requests.delete(url)

                    if response.ok:
                        self.pipeline.utils.report.debug("Job deleted: {} @ {}".format(job_id, engine["endpoint"]))
                    else:
                        self.pipeline.utils.report.warning("Klarte ikke å slette Pipeline 2-jobb: {} @ {}".format(job_id, engine["endpoint"]))

                    self.pipeline.utils.report.debug("[delete_job] releasing DP2 engine lock")
                    return response.ok

                except Exception:
                    self.pipeline.utils.report.exception("Klarte ikke å slette Pipeline 2-jobb: {} @ {}".format(job_id, engine["endpoint"]))
                    self.pipeline.utils.report.debug("[delete_job] releasing DP2 engine lock")
                    return False

            else:
                self.pipeline.utils.report.error("Ventet for lenge på tilgang til Pipeline 2")
                self.pipeline.utils.report.debug("[delete_job] could not aquire DP2 engine lock")
                return False

    def get_log(self):
        url = DaisyPipelineJob.encode_url(self.engine, "/jobs/{}/log".format(self.job_id), {})
        response = requests.get(url)
        return str(response.content, 'utf-8')

    def get_results(self):
        result_obj = tempfile.NamedTemporaryFile(prefix="daisy-pipeline-results-", suffix=".zip")
        result = result_obj.name

        url = DaisyPipelineJob.encode_url(self.engine, "/jobs/{}/result".format(self.job_id), {})

        with requests.get(url, stream=True) as r:
            with open(result, 'wb') as f:
                shutil.copyfileobj(r.raw, f)

        if os.path.isfile(result) and os.path.getsize(result) > 0:
            Filesystem.unzip(self.pipeline.utils.report, result, self.dir_output)

    @staticmethod
    def is_alive(engine):
        url = DaisyPipelineJob.encode_url(engine, "/alive", {})
        try:
            response = requests.get(url)
            return response.ok
        except Exception:
            return False

    def get_queue_size(self, engine):
        url = DaisyPipelineJob.encode_url(engine, "/jobs", {})
        try:
            response = requests.get(url)
            if not response.ok:
                return 10  # assume many jobs instead of failing
        except Exception:
            return 10  # assume many jobs instead of failing

        response = str(response.content, 'utf-8')
        xml = ElementTree.XML(response.split("?>")[-1])

        queue_size = 0
        jobs = xml.xpath("/d:jobs/d:job", namespaces=DaisyPipelineJob.dp2_ws_namespace)
        job_ids = []
        for job in jobs:
            job_ids.append(job.attrib.get("id"))

            # possible Pipeline 2 job statuses: IDLE, RUNNING, SUCCESS, ERROR, FAIL
            if job.attrib.get("status") in ["IDLE", "RUNNING"]:
                queue_size += 1

        self.delete_old_jobs(engine, job_ids)

        return queue_size

    def delete_old_jobs(self, engine, job_ids):
        # initialize engine_jobs if necessary
        if DaisyPipelineJob.engine_jobs is None:
            DaisyPipelineJob.engine_jobs = {}
        if engine["endpoint"] not in DaisyPipelineJob.engine_jobs:
            DaisyPipelineJob.engine_jobs[engine["endpoint"]] = {}

        # add newly found jobs
        for job_id in job_ids:
            if job_id not in DaisyPipelineJob.engine_jobs[engine["endpoint"]]:
                DaisyPipelineJob.engine_jobs[engine["endpoint"]][job_id] = time.time()

        # remove jobs that are no longer present in the engine
        for job_id in list(DaisyPipelineJob.engine_jobs[engine["endpoint"]].keys()):
            if job_id not in job_ids:
                del DaisyPipelineJob.engine_jobs[engine["endpoint"]][job_id]

        # delete old jobs
        for job_id in DaisyPipelineJob.engine_jobs[engine["endpoint"]]:
            age = time.time() - DaisyPipelineJob.engine_jobs[engine["endpoint"]][job_id]
            if age > 3600*3:
                self.delete_job(engine, job_id)

    @staticmethod
    def encode_url(engine, endpoint, parameters):
        if engine["authentication"] == "true":
            iso8601 = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
            nonce = str(random.randint(10**29, 10**30-1))  # 30 digits

            parameters["authid"] = engine["key"]
            parameters["time"] = iso8601
            parameters["nonce"] = nonce

        url = engine["endpoint"] + endpoint
        if parameters:
            url += "?" + urllib.parse.urlencode(parameters)

        if engine["authentication"] == "true":
            # Use RFC 2104 HMAC for keyed hashing of the URL
            hash = hmac.new(engine["secret"].encode('utf-8'),
                            url.encode('utf-8'),
                            digestmod=hashlib.sha1)

            # Use base 64 encoding
            hash = base64.b64encode(hash.digest()).decode('utf-8')

            # Base64 encoding uses + which we have to encode in URL parameters.
            hash = hash.replace("+", "%2B")

            # Append hash as parameter to the end of the URL
            url += "&sign=" + hash

        return url

    @staticmethod
    def local_list_processes():
        procs = []
        for proc in psutil.process_iter(attrs=[]):
            try:
                cmdline = " ".join(proc.cmdline())
                if ("java" in cmdline and
                        "daisy-pipeline" in cmdline and
                        "felix.jar" in cmdline and
                        "org.apache.felix.main.Main" in cmdline and
                        "webui" not in cmdline):
                    procs.append(proc)
            except psutil.NoSuchProcess:
                # Process does not exist anymore; ignore
                pass
        procs = list(sorted(procs, key=lambda p: p.create_time()))
        return procs
