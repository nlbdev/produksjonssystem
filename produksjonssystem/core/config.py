import multiprocessing
import time
from threading import RLock
from core.utils.busprocess import Bus


class Config:
    lock = None
    config = None

    def __init__(self):
        self.lock = RLock()
        self.config = {}

        Bus.subscribe("config.set", self._set)
        Bus.subscribe("config.init", self._init)
        Bus.send("config.init", None)

    def set(self, name, value):
        # publish new config to other processes
        Bus.send("config.set", {"name": name, "value": value})

    def get(self, name, default=None):
        if not self.config:
            Bus.send("config.init", None)
            time.sleep(1)

        with self.lock:
            return self.config[name] if name in self.config else default

    def _init(self, data):
        with self.lock:
            if self.config and data is None:
                Bus.send("config.init", self.config)

            elif not self.config and data is not None:
                for name in data:
                    if name not in self.config:
                        self.config[name] = data[name]
                print("{}, Initialized: {}".format(multiprocessing.current_process(), self.config))

    def _set(self, data):
        # store updated config in local buffer
        name = data["name"]
        value = data["value"]
        with self.lock:
            if name in self.config and self.config[name] == value:
                return
            else:
                print("{}, Setting {} to {}".format(multiprocessing.current_process(), name, value))
                self.config[name] = value
