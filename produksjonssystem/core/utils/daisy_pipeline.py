# -*- coding: utf-8 -*-

import os
import re
import time
import psutil
import tempfile
import traceback
import subprocess

from core.utils.timeout_lock import TimeoutLock


class DaisyPipelineJob():
    """Class used to run DAISY Pipeline 2 jobs"""

    # treat as class variables
    dp2_home = None
    dp2_cli = None
    _i18n = {
        "Starting Pipeline 2": "Oppstart av Pipeline 2",
        "The DAISY Pipeline 2 job": "DAISY Pipeline 2-jobben",
        "took too long time and was therefore stopped.": "tok for lang tid og ble derfor stoppet.",
        "An error occured when starting Pipeline 2": "En feil oppstod når Pipeline 2 startet",
        "Let's wait a few seconds and try again...": "Vi venter noen sekunder og prøver igjen...",
        "Could not delete the DAISY Pipeline 2 job with ID": "Klarte ikke å slette Pipeline 2 jobb med ID"
    }

    # treat as instance variables
    _dir_output_obj = None  # store TemporaryDirectory object in instance so that it's not cleaned up
    dir_output = None
    job_id = None
    pipeline = None
    status = None
    pid = None

    start_lock = TimeoutLock()

    @staticmethod
    def stop_engine(pipeline):
        procs = DaisyPipelineJob.list_processes()
        for p in procs:
            try:
                p.terminate()
            except psutil._exceptions.NoSuchProcess:
                pass
        gone, alive = psutil.wait_procs(procs,
                                        timeout=10,
                                        callback=lambda p: pipeline.utils.report.warn("Pipeline 2 process {} terminated with exit code {}".format(
                                            p,
                                            p.returncode
                                        )))
        if len(alive) > 0:
            pipeline.utils.report.warn("Killing {} remaining Pipeline 2 processes that didn't terminate".format(len(alive)))
        for p in alive:
            p.kill()
        DaisyPipelineJob.pid = None

    @staticmethod
    def start_engine(pipeline, retries=10):
        running = False
        with DaisyPipelineJob.start_lock.acquire_timeout(300) as locked:
            if locked:
                pipeline.utils.report.debug("acquired DP2 start lock")
                while not running and retries > 0:
                    retries -= 1
                    procs = DaisyPipelineJob.list_processes()
                    if DaisyPipelineJob.pid:
                        procs = [p for p in procs if p.pid != DaisyPipelineJob.pid]  # keep DaisyPipelineJob.pid
                    if len(procs) > 0:
                        pipeline.utils.report.debug("found at least one unexpected Pipeline 2 instance")
                        for p in procs:
                            try:
                                p.terminate()
                            except psutil._exceptions.NoSuchProcess:
                                pass
                        gone, alive = psutil.wait_procs(procs,
                                                        timeout=10,
                                                        callback=lambda p: pipeline.utils.report.warn("Pipeline 2 process {} terminated with exit code {}".format(
                                                            p,
                                                            p.returncode
                                                        )))
                        if len(alive) > 0:
                            pipeline.utils.report.warn("Killing {} remaining Pipeline 2 processes that didn't terminate".format(len(alive)))
                        for p in alive:
                            p.kill()

                    procs = DaisyPipelineJob.list_processes()
                    running = len(procs) == 1
                    if len(procs) == 0:
                        pipeline.utils.report.debug("no running DP2 process")
                        try:
                            # start engine if it's not started already
                            pipeline.utils.report.info("Starting Pipeline 2 engine...")
                            pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "help"], shell=True)

                        except subprocess.TimeoutExpired:
                            pipeline.utils.report.info("{} {}".format(
                                DaisyPipelineJob._i18n["Starting Pipeline 2"],
                                DaisyPipelineJob._i18n["took too long time and was therefore stopped."]
                            ))

                        except subprocess.CalledProcessError:
                            pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                            pipeline.utils.report.warn("{}. {}".format(
                                DaisyPipelineJob._i18n["An error occured when starting Pipeline 2"],
                                DaisyPipelineJob._i18n["Let's wait a few seconds and try again..."]
                            ))
                            time.sleep(10)
                            try:
                                # start engine if it's not started already
                                pipeline.utils.report.info("Starting Pipeline 2 engine...")
                                pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "help"], shell=True)

                            except subprocess.TimeoutExpired:
                                pipeline.utils.report.info("{} {}".format(
                                    DaisyPipelineJob._i18n["Starting Pipeline 2"],
                                    DaisyPipelineJob._i18n["took too long time and was therefore stopped."]
                                ))

                            except subprocess.CalledProcessError:
                                pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                                pipeline.utils.report.error(DaisyPipelineJob._i18n["An error occured when starting Pipeline 2"] + ".")

                        # Save PID for Pipeline 2 engine
                        procs = DaisyPipelineJob.list_processes()
                        if procs:
                            pipeline.utils.report.debug("found newly started process")
                            DaisyPipelineJob.pid = procs[0].pid
                            running = True
                        else:
                            pipeline.utils.report.debug("newly started process not found")

                        time.sleep(5)  # Wait a few seconds after starting Pipeline 2 before releasing the lock

                pipeline.utils.report.debug("releasing DP2 start lock")
                return running

            else:
                pipeline.utils.report.debug("unable to acquire DP2 start lock")

        return False

    @staticmethod
    def init_environment():
        from core.pipeline import Pipeline
        if "PIPELINE2_HOME" in Pipeline.environment:
            DaisyPipelineJob.dp2_home = Pipeline.environment["PIPELINE2_HOME"]
        else:
            DaisyPipelineJob.dp2_home = os.getenv("PIPELINE2_HOME", "/opt/daisy-pipeline2")
        DaisyPipelineJob.dp2_cli = DaisyPipelineJob.dp2_home + "/cli/dp2"

    def __init__(self, pipeline, script, arguments):
        self.pipeline = pipeline
        self.script = script
        self.arguments = arguments

    def __enter__(self):
        DaisyPipelineJob.init_environment()

        self._dir_output_obj = tempfile.TemporaryDirectory(prefix="produksjonssystem-", suffix="-daisy-pipeline-output")
        self.dir_output = self._dir_output_obj.name

        if DaisyPipelineJob.start_engine(self.pipeline):
            try:
                command = [DaisyPipelineJob.dp2_cli, self.script]
                for arg in self.arguments:
                    command.extend(["--" + arg, self.arguments[arg]])
                command.extend(["--background"])

                self.pipeline.utils.report.debug("Posting job")
                process = self.pipeline.utils.filesystem.run(command)

                # Get DAISY Pipeline 2 job ID
                self.job_id = None
                for line in process.stdout.decode("utf-8").split("\n"):
                    # look for: Job {id} sent to the server
                    m = re.match("^Job (.*) sent to the server$", line)
                    if m:
                        self.job_id = m.group(1)
                        break
                assert self.job_id, "Could not find the DAISY Pipeline 2 job ID"

                self.status = "IDLE"
                idle_start = time.time()
                running_start = time.time()
                idle_timeout = 3600
                running_timeout = 3600
                while (self.status == "IDLE" and time.time() - idle_start < idle_timeout
                        or self.status == "RUNNING" and time.time() - running_start < running_timeout):
                    time.sleep(5)

                    if self.status == "IDLE":
                        running_start = time.time()

                    # get job status
                    self.pipeline.utils.report.debug("Getting job status")
                    process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "status", self.job_id])
                    for line in process.stdout.decode("utf-8").split("\n"):
                        # look for: Job {id} sent to the server
                        m = re.match("^Status: (.*)$", line)
                        if m:
                            self.status = m.group(1)
                            break

                    self.pipeline.utils.report.debug("Pipeline 2 status: " + self.status)

                if (self.status is "IDLE" and time.time() - idle_start >= idle_timeout
                        or self.status is "RUNNING" and time.time() - running_start >= running_timeout):
                    self.pipeline.utils.report.warn("Pipeline 2 job timed out. Stopping Pipeline 2 engine.")
                    DaisyPipelineJob.stop_engine(self.pipeline)
                    raise subprocess.TimeoutExpired(self.status)

                # get job log (the run method will log stdout/stderr as debug output)
                self.pipeline.utils.report.debug("Getting job log")
                process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "log", self.job_id])

                # get results
                if self.status and self.status != "ERROR":
                    self.pipeline.utils.report.debug("Getting job results")
                    process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "results", "--output", self.dir_output, self.job_id])

            except subprocess.TimeoutExpired:
                self.pipeline.utils.report.error("{} {} {}".format(
                    DaisyPipelineJob._i18n["The DAISY Pipeline 2 job"],
                    self.job_id,
                    DaisyPipelineJob._i18n["took too long time and was therefore stopped."]
                ))
                self.status = None

            except Exception:
                self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                self.pipeline.utils.report.error("An error occured while running the DAISY Pipeline 2 job (" + str(self.job_id) + ")")

        else:
            self.pipeline.utils.report.error("Could not start DAISY Pipeline 2.")

        return self

    def __exit__(self, exc_type, exc_value, traceback):
        if self.job_id:
            try:
                process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "delete", self.job_id])
                self.pipeline.utils.report.debug(self.job_id + " was deleted")
            except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
                self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                self.pipeline.utils.report.warn(DaisyPipelineJob._i18n["Could not delete the DAISY Pipeline 2 job with ID"] + " " + self.job_id)

    @staticmethod
    def list_processes():
        procs = []
        for proc in psutil.process_iter(attrs=[]):
            try:
                cmdline = " ".join(proc.cmdline())
                if "java" in cmdline and "daisy-pipeline" in cmdline and "felix" in cmdline and "webui" not in cmdline:
                    procs.append(proc)
            except psutil.NoSuchProcess:
                # Process does not exist anymore; ignore
                pass
        procs = list(sorted(procs, key=lambda p: p.create_time()))
        return procs

    # in case you want to override something
    @staticmethod
    def translate(english_text, translated_text):
        DaisyPipelineJob._i18n[english_text] = translated_text
