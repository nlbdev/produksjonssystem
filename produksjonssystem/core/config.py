# -*- coding: utf-8 -*-

import hashlib
import json
import logging
import multiprocessing
import os
import threading
import time
from threading import RLock

from core.utils.busprocess import Bus


class Config:
    lock = None
    config = None
    initialized = False
    continuous_dump_file = None

    def __init__(self):
        self.lock = RLock()
        self.config = {}

        self.continuous_dump_file = None
        if os.environ.get("CONFIG_CONTINUOUS_DUMP_DIR"):
            logging.warn("Enabling continuous dumping of config to JSON files (CONFIG_CONTINUOUS_DUMP_DIR is set)."
                         "This is inefficient. Do not use in production.")
            process_name = multiprocessing.current_process().name
            thread_name = threading.current_thread().getName()
            self.continuous_dump_file = os.path.join(os.environ.get("CONFIG_CONTINUOUS_DUMP_DIR"), "{}-{}".format(process_name, thread_name))

        Bus.subscribe("config.set", self._set_listener)
        Bus.subscribe("config.init", self._init)
        Bus.send("config.init", None)

    def wait_until_initialized(self, while_true_or_missing="system.shouldRun"):
        # note: this will block forever if nothing is added to the config
        while True:
            if not self.get(while_true_or_missing, default=True):
                return False

            if bool(self.config):
                return True

            time.sleep(1)

    def _as_dict(self, name, value):
        # make a dict based on the name. for instance {"a.b": 1} becomes {"a": {"b": 1}}
        result = {}
        temp_dict = {}
        result = value
        for part in reversed(name.split(".")):
            temp_dict[part] = result
            result = temp_dict
            temp_dict = {}
        return result

    def set(self, name, value):
        # publish new config to other processes

        self._set(name, value)

        Bus.send("config.set", {"name": name, "value": value})

    def get(self, name, default=None):
        if not self.config:
            Bus.send("config.init", None)
            time.sleep(1)

        with self.lock:
            if not name:
                return None

            result = self.config
            for part in name.split("."):
                if part in result:
                    result = result[part]
                else:
                    result = default
                    break
            return result

    def _init(self, data):
        with self.lock:
            was_config = bool(self.config)

            if data is None:  # if someone on the bus requests a full copy of the config (data is None)
                if self.config:  # and we have config (self.config is true-ish)
                    Bus.send("config.init", self.config)  # then publish all our data.

            else:  # if someone on the bus publishes a full copy of the config (data is not None)
                Config._merge_dicts(self.config, data)

            is_config = bool(self.config)
            initialized = not was_config and is_config
            if initialized:
                logging.debug("config initialized")  # , config is now {}".format(self.config))

    def _set_listener(self, data):
        # store updated config in local buffer
        name = data["name"]
        value = data["value"]

        if not name:
            logging.warn("No name given in Config._set_listener: {}".format(data))
            return

        self._set(name, value)

    def _set(self, name, value):
        if not name:
            logging.warn("No name given in Config._set: {} / {}".format(name, value))
            return

        new_config_as_dict = self._as_dict(name, value)
        with self.lock:
            changed = Config._merge_dicts(self.config, new_config_as_dict)

            if changed:
                logging.debug("Setting {}".format(name))  # to {}".format(name, value))
                self._update_dump()

        if name == "logging" or name.startswith("logging."):
            self.init_logging(self)

    # merges dicts a and b, preferring content in b over content in a
    @staticmethod
    def _merge_dicts(a, b, report_change=True):
        hash_before = None

        if report_change:
            hash_before = Config._dict_hash(a)

        for key in b:
            if key in a and isinstance(a[key], dict) and isinstance(b[key], dict):
                Config._merge_dicts(a[key], b[key], report_change=False)

            else:
                a[key] = b[key]

        if report_change:
            hash_after = Config._dict_hash(a)
            return hash_before != hash_after

    @staticmethod
    def _dict_hash(target):
        return hashlib.md5(json.dumps(target, sort_keys=True).encode('utf-8')).hexdigest()

    def _update_dump(self):
        if self.continuous_dump_file:
            if not os.path.exists(self.continuous_dump_file):
                os.makedirs(os.path.dirname(self.continuous_dump_file), exist_ok=True)
            with open(self.continuous_dump_file, 'w') as dumpfile:
                json.dump(self.config, dumpfile, indent=4)

    @staticmethod
    def init_logging(config):
        level = config.get("logging.level")
        format = config.get("logging.format")

        logger = logging.getLogger()
        if level and format:
            logger.handlers = []  # empty list of handlers to avoid duplicates
            logger.setLevel(level)
            streamHandler = logging.StreamHandler()
            streamHandler.setLevel(level)
            streamHandler.setFormatter(logging.Formatter(format))
            logger.addHandler(streamHandler)
