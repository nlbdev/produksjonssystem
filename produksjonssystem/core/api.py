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
from core.config import Config


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
        self.app.url_map.strict_slashes = False
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

        if self.thread.is_alive():
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
