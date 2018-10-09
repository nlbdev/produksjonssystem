# -*- coding: utf-8 -*-

import os
import re
import subprocess
import tempfile
import time
import traceback

import psutil
from core.utils.timeout_lock import TimeoutLock


class DaisyPipelineJob():
    """Class used to run DAISY Pipeline 2 jobs"""

    # treat as class variables
    dp2_home = None
    dp2_cli = None

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
                pipeline.utils.report.debug("Stopping: {}".format(p))
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
            pipeline.utils.report.debug("Killing: {}".format(p))
            p.kill()
        DaisyPipelineJob.pid = None
        time.sleep(1)
        pipeline.utils.report.debug("Pipeline 2 processes after stopping/killing: {}".format(len(DaisyPipelineJob.list_processes())))

    @staticmethod
    def start_engine(pipeline, retries=10):
        running = False
        with DaisyPipelineJob.start_lock.acquire_timeout(600) as locked:
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
                                pipeline.utils.report.debug("Stopping: {}".format(p))
                                p.terminate()
                            except psutil._exceptions.NoSuchProcess:
                                pass
                        gone, alive = psutil.wait_procs(procs,
                                                        timeout=10,
                                                        callback=lambda p: pipeline.utils.report.warn(
                                                            "Pipeline 2 process {} terminated with exit code {}".format(
                                                                p,
                                                                p.returncode
                                                            )))
                        if len(alive) > 0:
                            pipeline.utils.report.warn("Killing {} remaining Pipeline 2 processes that didn't terminate".format(len(alive)))
                        for p in alive:
                            pipeline.utils.report.debug("Killing: {}".format(p))
                            p.kill()
                        time.sleep(1)
                        pipeline.utils.report.debug("Pipeline 2 processes after stopping/killing: {}".format(len(DaisyPipelineJob.list_processes())))

                    procs = DaisyPipelineJob.list_processes()
                    running = len(procs) == 1
                    if len(procs) == 0:
                        pipeline.utils.report.debug("no running DP2 process")
                        lockfiles = [
                            os.path.join(DaisyPipelineJob.dp2_home, "data", "db", "db.lck"),
                            os.path.join(DaisyPipelineJob.dp2_home, "data", "db", "dbex.lck")
                        ]
                        for lockfile in lockfiles:
                            if os.path.isfile(lockfile):
                                try:
                                    os.remove(lockfile)
                                except Exception:
                                    pipeline.utils.report.debug(traceback.format_exc())
                                    pipeline.utils.report.debug("Could not remove Pipeline 2 lockfile")
                        try:
                            # start engine if it's not started already
                            pipeline.utils.report.info("Starting Pipeline 2 engine...")
                            process = pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "help"], shell=True)
                            if process.returncode != 0:
                                pipeline.utils.report.error("En feil oppstod når Pipeline 2 startet")
                                continue

                        except subprocess.TimeoutExpired:
                            pipeline.utils.report.info("Oppstart av Pipeline 2 tok for lang tid og ble derfor stoppet.")
                            continue

                        except subprocess.CalledProcessError:
                            pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                            pipeline.utils.report.warn("En feil oppstod når Pipeline 2 startet. Vi venter noen sekunder og prøver igjen...")
                            time.sleep(10)
                            try:
                                # start engine if it's not started already
                                pipeline.utils.report.info("Starting Pipeline 2 engine...")
                                process = pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "help"], shell=True)
                                if process.returncode != 0:
                                    pipeline.utils.report.error("En feil oppstod når Pipeline 2 startet")
                                    continue

                            except subprocess.TimeoutExpired:
                                pipeline.utils.report.info("Oppstart av Pipeline 2 tok for lang tid og ble derfor stoppet.")
                                continue

                            except subprocess.CalledProcessError:
                                pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                                pipeline.utils.report.error("En feil oppstod når Pipeline 2 startet.")
                                continue

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
                pipeline.utils.report.error("timed out while waiting to acquire DP2 start lock")

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
                assert process.returncode == 0, "An error occured when posting the Pipeline 2 job"

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
                timed_out = False
                while not timed_out and self.status in ["IDLE", "RUNNING"]:
                    timed_out = self.status == "IDLE" and time.time() - idle_start > idle_timeout or time.time() - running_start > running_timeout
                    time.sleep(5)

                    if self.status == "IDLE":
                        running_start = time.time()

                    procs = DaisyPipelineJob.list_processes()
                    if len(procs) == 0:
                        self.pipeline.utils.report.error("Pipeline 2 is no longer running. Aborting.")
                        break
                    if len(procs) > 1:
                        self.pipeline.utils.report.error("Multiple Pipeline 2 instances found. Aborting.")
                        break

                    # get job status
                    self.pipeline.utils.report.debug("Getting job status")
                    process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "status", self.job_id])
                    assert process.returncode == 0, "An error occured when getting the Pipeline 2 job status"
                    for line in process.stdout.decode("utf-8").split("\n"):
                        # look for: Job {id} sent to the server
                        m = re.match("^Status: (.*)$", line)
                        if m:
                            self.status = m.group(1)
                            break

                    self.pipeline.utils.report.debug("Pipeline 2 status: " + self.status)

                if timed_out:
                    self.pipeline.utils.report.error("Pipeline 2 job timed out. Stopping Pipeline 2 engine.")
                    self.status = None
                    DaisyPipelineJob.stop_engine(self.pipeline)

                else:
                    # get job log (the run method will log stdout/stderr as debug output)
                    self.pipeline.utils.report.debug("Getting job log")
                    process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "log", self.job_id])
                    assert process.returncode == 0, "An error occured when getting the Pipeline 2 job log"

                    # get results
                    if self.status and self.status != "ERROR":
                        self.pipeline.utils.report.debug("Getting job results")
                        process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "results", "--output", self.dir_output, self.job_id])
                        assert process.returncode == 0, "An error occured when posting the results from the Pipeline 2 job"

            except subprocess.TimeoutExpired:
                self.pipeline.utils.report.error("DAISY Pipeline 2-jobben {} tok for lang tid og ble derfor stoppet.".format(self.job_id))
                self.status = None

            except Exception:
                self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                self.pipeline.utils.report.error("An error occured while running the DAISY Pipeline 2 job (" + str(self.job_id) + ")")
                self.status = None

        else:
            self.pipeline.utils.report.error("Could not start DAISY Pipeline 2.")

        return self

    def __exit__(self, exc_type, exc_value, trace):
        if self.job_id:
            try:
                process = self.pipeline.utils.filesystem.run([DaisyPipelineJob.dp2_cli, "delete", self.job_id])
                if process.returncode == 0:
                    self.pipeline.utils.report.debug(self.job_id + " was deleted")
                else:
                    self.pipeline.utils.report.debug(traceback.format_stack())
                    self.pipeline.utils.report.warn("Klarte ikke å slette Pipeline 2 jobb med ID " + self.job_id)
            except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
                self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                self.pipeline.utils.report.warn("Klarte ikke å slette Pipeline 2 jobb med ID " + self.job_id)

    @staticmethod
    def list_processes():
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
