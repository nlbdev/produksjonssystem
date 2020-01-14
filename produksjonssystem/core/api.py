#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import os
import threading
from pathlib import Path
from random import random

import pybrake.flask
import requests
from flask import Flask, Response, jsonify, redirect, request

from core.directory import Directory
from core.pipeline import DummyPipeline, Pipeline
from core.utils.filesystem import Filesystem
from core.utils.metadata import Metadata
from datetime import datetime, timezone
from dateutil.relativedelta import relativedelta


class API():
    """
    API for communicating with the production system.
    """
    version = 1

    app = None
    base_url = None
    host = None
    port = None
    root_path = None
    airbrake_config = None

    kill_endpoint = "/kill{}/".format(str(random()).split(".")[-1])  # random endpoint to discourage explicit external usage
    shutdown_function = None

    buffered_network_paths = {}
    buffered_network_hosts = {}

    def __init__(self, root_path="/prodsys", include_version=True, shutdown_function=None, airbrake_config=None):
        self.airbrake_config = airbrake_config

        self.app = Flask(__name__)
        self.host = os.getenv("API_HOST", default="0.0.0.0")
        self.port = os.getenv("API_PORT", default=3875)
        self.root_path = "{}{}".format(root_path, "/v{}".format(API.version) if include_version else "")
        self.base_url = "http://{}{}{}".format(self.host,
                                               ":{}".format(self.port) if self.port != 80 else "",
                                               self.root_path)

        # declaring endpoints here, as instance decorators doesn't seem to work

        # root endpoint
        self.app.add_url_rule(self.root_path+"/", "root", self.root)

        # forward endpoints "above" the root, to the root (i.e. /prodsys/ and /prodsys/v1/)
        if self.root_path != "":
            self.app.add_url_rule("/", "root", self.root)
            parts = [part for part in self.root_path.split("/") if part]
            endpoints_above = ["/".join(parts[0:i+1]) for i in range(0, len(parts)-1)]
            for endpoint in endpoints_above:
                self.app.add_url_rule("/{}/".format(endpoint), "root", self.root)

        # the easiest way to shut down Flask is through an instance of request,
        # so we create this endpoint which gives us a request instance
        self.app.add_url_rule(self.root_path + API.kill_endpoint, "kill", self.kill, methods=["POST"])

        if shutdown_function:
            self.shutdown_function = shutdown_function
            self.app.add_url_rule(self.root_path+"/shutdown/",
                                  "shutdown",
                                  self.shutdown,
                                  methods=["GET", "PUT"])

        self.app.add_url_rule(self.root_path+"/update/",
                              "update",
                              self.update,
                              methods=["GET", "PUT"])

        self.app.add_url_rule(self.root_path+"/creative-works/",
                              "creative-works",
                              self.creativeWorks)

        self.app.add_url_rule(self.root_path+"/pipelines/",
                              "pipelines",
                              self.pipelines)

        self.app.add_url_rule(self.root_path+"/pipelines/<pipeline_id>/",
                              "pipeline",
                              self.pipeline)

        self.app.add_url_rule(self.root_path+"/pipelines/<pipeline_id>/creative-works/",
                              "pipeline_creativeWorks",
                              self.pipeline_creativeWorks)

        self.app.add_url_rule(self.root_path+"/pipelines/<pipeline_id>/editions/",
                              "pipeline_editions",
                              self.pipeline_editions)

        self.app.add_url_rule(self.root_path+"/pipelines/<pipeline_id>/editions/<edition_id>/",
                              "pipeline_edition",
                              self.pipeline_edition)

        self.app.add_url_rule(self.root_path+"/pipelines/<pipeline_id>/editions/<edition_id>/trigger/",
                              "pipeline_trigger",
                              self.pipeline_trigger,
                              methods=["GET", "POST"])

        self.app.add_url_rule(self.root_path+"/directories/",
                              "directories",
                              self.directories)

        self.app.add_url_rule(self.root_path+"/directories/<directory_id>/",
                              "directory",
                              self.directory)

        self.app.add_url_rule(self.root_path+"/directories/<directory_id>/editions/",
                              "directory_editions",
                              self.directory_editions)

        self.app.add_url_rule(self.root_path+"/editions/<edition_id>/reports/",
                              "reports",
                              self.reports)

        self.app.add_url_rule(self.root_path+"/editions/<edition_id>/reports/<production_id>",
                              "report",
                              self.report)

        self.app.add_url_rule(self.root_path+"/directories/<directory_id>/editions/<edition_id>/",
                              "directory_edition",
                              self.directory_edition)

        self.app.add_url_rule(self.root_path+"/directories/<directory_id>/editions/<edition_id>/trigger/",
                              "directory_trigger",
                              self.directory_trigger,
                              methods=["GET", "POST"])

    def start(self, hot_reload=False):
        """
        Start thread
        """

        if self.airbrake_config is not None:
            self.app.config['PYBRAKE'] = self.airbrake_config
            self.app = pybrake.flask.init_app(self.app)

        # app.run should ideally not be used in production, but oh well…
        self.thread = threading.Thread(target=self.app.run, name="api", kwargs={
            "debug": hot_reload,
            "host": self.host,
            "port": self.port
        })
        self.thread.setDaemon(True)
        self.thread.start()

        logging.info("Started API on {}".format(self.base_url))

    def join(self):
        """
        Stop thread
        """

        requests.post(self.base_url + API.kill_endpoint)

        logging.debug("joining {}".format(self.thread.name))
        self.thread.join(timeout=60)

        if self.thread.isAlive():
            logging.debug("The API thread is still running. Let's ignore it and continue shutdown…")

    # endpoint: /shutdown
    def shutdown(self):
        # true | false
        if self.shutdown_function:
            self.shutdown_function()
            return "true"
        else:
            logging.error("Shutdown function is not defined.")
            return "false"

    # endpoint: /update
    def update(self):
        project_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

        process = Filesystem.run_static(["git", "pull"], cwd=project_dir)

        if process.returncode == 0:
            return jsonify(process.stdout.decode("utf-8")), 200
        else:
            return jsonify(process.stderr.decode("utf-8")), 500

    # endpoint: /creative-works
    def creativeWorks(self):
        # [ "<isbn>", "<isbn>", "<isbn>", "-<edition_id>", "-<edition_id>", "-<edition_id>" ]
        return "TODO"

    # endpoint: /pipelines
    def pipelines(self):
        result = {}
        for pipeline in Pipeline.pipelines:
            result[pipeline.uid] = pipeline.title
        return jsonify(result)

    # endpoint: /pipelines/<pipeline_id>
    def pipeline(self, pipeline_id):
        pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == pipeline_id]
        pipeline = pipeline[0] if pipeline else None

        if not pipeline:
            return Response(None, status=404)

        dir_in_id = None
        dir_out_id = None
        for dir in Directory.dirs_flat:
            if pipeline.dir_in and os.path.normpath(pipeline.dir_in) == os.path.normpath(Directory.dirs_flat[dir]):
                dir_in_id = dir
            if pipeline.dir_out and os.path.normpath(pipeline.dir_out) == os.path.normpath(Directory.dirs_flat[dir]):
                dir_out_id = dir

        return jsonify({
            "uid": pipeline.uid,
            "title": pipeline.title,
            "dir_in": dir_in_id,
            "dir_out": dir_out_id,
            "parentdirs": pipeline.parentdirs,
            "labels": pipeline.labels,
            "publication_format": pipeline.publication_format,
            "expected_processing_time": pipeline.expected_processing_time,
            "state": pipeline.get_state(),
            "queue": pipeline.get_queue()
        })

    # endpoint: /pipelines/<pipeline_id>/creative-works
    def pipeline_creativeWorks(self, pipeline_id):
        # { "<edition_id>": }
        return "TODO"

    # endpoint: /pipelines/<pipeline_id>/editions
    def pipeline_editions(self, pipeline_id):
        pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == pipeline_id]
        pipeline = pipeline[0] if pipeline else None

        if not pipeline:
            return Response(None, status=404)

        else:
            directory_id = [dir for dir in Directory.dirs_flat if os.path.normpath(Directory.dirs_flat[dir]) == os.path.normpath(pipeline.dir_out)][:1]
            directory_id = directory_id[0] if directory_id else None
            return self.directory_editions(directory_id)

    # endpoint: /pipelines/<pipeline_id>/editions/<edition_id>
    def pipeline_edition(self, pipeline_id, edition_id):
        pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == pipeline_id]
        pipeline = pipeline[0] if pipeline else None

        if not pipeline:
            return Response(None, status=404)

        else:
            directory_id = [dir for dir in Directory.dirs_flat if os.path.normpath(Directory.dirs_flat[dir]) == os.path.normpath(pipeline.dir_out)][:1]
            directory_id = directory_id[0] if directory_id else None
            return self.directory_edition(directory_id, edition_id)

    # endpoint: /pipelines/<pipeline_id>/editions/<edition_id>/trigger
    def pipeline_trigger(self, pipeline_id, edition_id):
        pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == pipeline_id]
        pipeline = pipeline[0] if pipeline else None

        if not pipeline:
            return Response(None, status=404)

        else:
            pipeline.trigger(edition_id, auto=False)
            return jsonify([pipeline_id])

    # endpoint: /directories
    def directories(self):
        structure = request.args.get('structure', 'simple')

        if structure == "ranked":
            return jsonify(Directory.dirs_ranked)

        elif structure == "resolved":
            dirs = {}

            for dir in Directory.dirs_flat:
                if dir not in self.buffered_network_paths:
                    smb, file, unc = Filesystem.networkpath(Directory.dirs_flat[dir])
                    host = Filesystem.get_host_from_url(smb)
                    self.buffered_network_paths[dir] = smb
                    self.buffered_network_hosts[dir] = host
                dirs[dir] = self.buffered_network_paths[dir]

            return jsonify(dirs)

        else:
            return jsonify(Directory.dirs_flat)

    # endpoint: /directories/<directory_id>
    def directory(self, directory_id):
        path = os.path.normpath(Directory.dirs_flat[directory_id]) if directory_id in Directory.dirs_flat else None
        if path:
            result = {
                "path": Directory.dirs_flat.get(directory_id, None),
                "input_pipelines": [],
                "output_pipelines": []
            }
            for pipeline in Pipeline.pipelines:
                if pipeline.dir_out and os.path.normpath(pipeline.dir_out) == path:
                    result["input_pipelines"].append(pipeline.uid)
                if pipeline.dir_in and os.path.normpath(pipeline.dir_in) == path:
                    result["output_pipelines"].append(pipeline.uid)
            return jsonify(result)
        else:
            return Response(None, status=404)

    # endpoint: /directories/<directory_id>/editions
    def directory_editions(self, directory_id):
        path = Directory.dirs_flat.get(directory_id, None)
        if not path:
            return Response(None, status=404)

        elif not os.path.isdir(path):
            return Response(None, status=404)

        else:
            return jsonify([Path(file).stem for file in Filesystem.list_book_dir(path)])

    # endpoint: /directories/<directory_id>/editions/<edition_id>
    def directory_edition(self, directory_id, edition_id):
        path = os.path.normpath(Directory.dirs_flat[directory_id]) if directory_id in Directory.dirs_flat else None

        if not path:
            return Response(None, status=404)

        book_path = None
        for name in Filesystem.list_book_dir(path):
            if Path(name).stem == edition_id:
                book_path = os.path.join(path, name)
                break

        if not book_path:
            return Response(None, status=404)

        force_update = request.args.get('force_update', "false").lower() == "true"
        extend_with_cached_rdf_metadata = request.args.get('extend_with_cached_rdf_metadata', "true").lower() == "true"

        return jsonify(Metadata.get_metadata_from_book(DummyPipeline(),
                                                       book_path,
                                                       force_update=force_update,
                                                       extend_with_cached_rdf_metadata=extend_with_cached_rdf_metadata))

    # endpoint: /directories/<directory_id>/editions/<edition_id>/trigger
    def directory_trigger(self, directory_id, edition_id):
        path = os.path.normpath(Directory.dirs_flat[directory_id]) if directory_id in Directory.dirs_flat else None

        if not path:
            return Response(None, status=404)

        file_stems = [Path(file).stem for file in Filesystem.list_book_dir(path)]
        if edition_id not in file_stems:
            return Response(None, status=404)

        result = []
        for pipeline in Pipeline.pipelines:
            if pipeline.dir_in and os.path.normpath(pipeline.dir_in) == path:
                pipeline.trigger(edition_id, auto=False)
                result.append(pipeline.uid)
        return jsonify(result)

    def reports(self, edition_id):
        path = os.environ.get("DIR_REPORTS")

        if not path:
            return Response(None, status=404)
        result = []
        current_month = datetime.now(timezone.utc)

        # Finding reports for last 3 months
        for i in range(0, 3):
            month = (current_month - relativedelta(months=i)).strftime("%Y-%m")

            path_reports = os.path.join(path, "logs", month, edition_id)
            if not os.path.exists(path_reports):
                continue
            dirs = os.listdir(path_reports)
            for dir in dirs:
                dir_split = dir.split("-")
                pipeline_id = dir_split[len(dir_split) - 2] + "-" + dir_split[len(dir_split) - 1]
                pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == pipeline_id]
                pipeline = pipeline[0] if pipeline else None
                result.append({
                    "edition_id": edition_id,
                    "pipeline_id": pipeline_id,
                    "production_id": dir,
                    "title": pipeline.title,
                    "labels": pipeline.labels,
                    "format": pipeline.publication_format
                    })
        if result == []:
            return jsonify("No results found for edition: " + edition_id)
        return jsonify(result)

    def report(self, edition_id, production_id):
        path = os.environ.get("DIR_REPORTS")

        if not path:
            return Response(None, status=404)

        path_report = os.path.join(path, "logs", (datetime.now(timezone.utc).strftime("%Y-%m")), edition_id, production_id, "log.txt")
        if not os.path.exists(path_report):
            return Response("No report for edition: " + edition_id, status=404)
        result = []
        with open(path_report, 'r') as report:
            result = report.read()
        return jsonify(result)

    # endpoint: /
    def root(self):
        """
        Root endpoint. Lists all possible endpoints.
        """

        endpoint = request.url[len(request.url_root)-1:]
        if endpoint != self.root_path+"/":
            return redirect(self.root_path+"/", code=302)
        else:
            rules = []
            for rule in self.app.url_map.iter_rules():
                path = str(rule)[len(self.root_path)+1:]
                if not path or path.startswith("kill") or "/" not in path:
                    continue
                rules.append(path)  # strips self.root_path, making the result a path relative to root
            return jsonify(rules)

    # endpoint: /kill
    def kill(self):
        """
        Used internally for shutting down. Should not be used by exernal applications.
        """
        # See:
        # - http://flask.pocoo.org/snippets/67/
        # - https://stackoverflow.com/a/26788325/281065

        shutdown = request.environ.get("werkzeug.server.shutdown")
        if shutdown is None:
            raise RuntimeError("Not running with the Werkzeug Server")
        shutdown()
        return "Shutting down…"
