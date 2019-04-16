# -*- coding: utf-8 -*-

import logging
import multiprocessing
import threading
import traceback
from multiprocessing import Pipe, Process
from threading import RLock, Thread


class Bus():

    # static variables
    current_process = None  # used to check if we need to initialize static variables
    listeners_lock = None  # lock for listeners variable
    listeners = None  # list of subscribed functions

    # static variables used in child process
    connection = None  # connection to parent process
    child_thread = None  # thread in child process that handles the connection to the parent process

    # static variables used in parent process
    connections_lock = None  # lock for connections variable
    connections = None  # list of connections to child processes

    def __init__(self):
        logging.debug("initializing Bus instance (should not happen!)")
        raise Exception("Bus should not be instantiated.")

    @staticmethod
    def get_unique_thread_name(prefix=None, suffix=None, max_length=11):
        # give the thread a descriptive and unique name
        thread_names = [t.getName() for t in threading.enumerate()]
        for i in range(0, max(0, 10**(max_length - (len(prefix)+1 if prefix else 0) - (len(suffix)+1 if suffix else 0)))):
            new_thread_name = "{}{}{}".format("{}-".format(prefix) if prefix else "",
                                              i,
                                              "-{}".format(suffix) if suffix else "")
            if new_thread_name not in thread_names:
                return new_thread_name
        return None

    @staticmethod
    def init(connection=None):
        if Bus.current_process == multiprocessing.current_process():
            #logging.debug("Bus is already initialized for process: {}".format(multiprocessing.current_process()))
            return
        logging.debug("Initializing bus with {} as upstream connection".format(connection))

        Bus.current_process = multiprocessing.current_process()

        Bus.listeners_lock = RLock()
        Bus.listeners = []

        Bus.connections_lock = RLock()
        Bus.connections = []

        Bus.connection = {"pipe": connection, "open": bool(connection)}
        if Bus.connection["open"]:
            Bus.child_thread = Thread(target=Bus._recv_down,
                                      daemon=True,
                                      name=Bus.get_unique_thread_name(prefix="bus_down"),
                                      args=())
            Bus.child_thread.start()

    @staticmethod
    def subscribe(topic, fn):
        """Register a function to handle messages about the given topic. Starts a listener that runs in the child process."""
        Bus.init()
        logging.debug("Subscribing {} to topic {}".format(fn, topic))
        with Bus.listeners_lock:
            Bus.listeners.append({
                "topic": topic,
                "function": fn
            })

    @staticmethod
    def send(topic, data):
        """Send data to the bus on the given topic."""
        Bus.init()
        if Bus.connection["open"]:
            # sends to parent process
            #logging.debug("Send data to parent process for topic {} from process {}".format(topic, multiprocessing.current_process()))
            Bus.connection["pipe"].send([topic, data])
        else:
            # sends to current process and child processes
            #logging.debug("Send data to current and child process(es) for topic {} from process {}".format(topic, multiprocessing.current_process()))
            Bus.send_down([topic, data])

    @staticmethod
    def send_down(data):
        Bus.init()
        #logging.debug("Send data downwards in process {}".format(multiprocessing.current_process()))

        # sends to all child processes
        with Bus.connections_lock:
            # iterate using position and in reverse order so that we can delete connections while iterating
            for i in list(reversed(range(0, len(Bus.connections)))):
                connection = Bus.connections[i]
                try:
                    #logging.debug("Send data downwards in process {} through connection {}".format(multiprocessing.current_process(), connection))
                    connection["pipe"].send(data)
                except BrokenPipeError:
                    logging.warn("Broken pipe, unable to send message down the bus.")
                    connection["open"] = False
                    del Bus.connections[i]

        # sends to all subscribed functions in current process
        assert isinstance(data, list), "Message bus data must be a list"
        assert len(data) == 2, "Message bus data must have to items: [topic, data]"
        [topic, data] = data
        with Bus.listeners_lock:
            for listener in Bus.listeners:
                if listener["topic"] == topic:
                    listener["function"](data)

    @staticmethod
    def _recv(connection, kill_process=None):
        """Thread that listens for messages sent from the child process and broadcasts it to all processes. Runs in parent process."""
        Bus.init()
        connection = {"pipe": connection, "open": bool(connection)}
        logging.debug("Start listening for messages sent from child process on connection {}".format(connection))
        if threading.current_thread().getName().startswith("Thread-"):
            logging.debug("{}".format("".join(traceback.format_stack())))
        while connection["open"]:
            try:
                data = connection["pipe"].recv()  # Blocks until there is something to receive from the process
                #logging.debug("Received data from child process on connection {} in process {}".format(connection, multiprocessing.current_process()))
                assert isinstance(data, list), "Message bus data must be a list"
                assert len(data) == 2, "Message bus data must have to items: [topic, data]"
                [topic, data] = data
                Bus.send(topic, data)

            except EOFError:
                logging.warn("Pipe was closed from other end of connection.")
                connection["open"] = False
            except ConnectionResetError as e:
                logging.exception("Pipe was reset", e)
                connection["open"] = False
            except BrokenPipeError as e:
                logging.exception("Broken pipe", e)
                connection["open"] = False

        del connection["pipe"]
        if kill_process:
            kill_process.terminate()

    @staticmethod
    def _recv_down():
        """Thread that listens for messages sent from the parent process and forwards it to all listeners. Runs in child process."""
        Bus.init()
        logging.debug("Start listening for messages sent from parent process on connection {}".format(Bus.connection))
        while True:
            try:
                data = Bus.connection["pipe"].recv()  # Blocks until there is something to receive
                #logging.debug("Received data from parent process on connection {} in process {}".format(Bus.connection, multiprocessing.current_process()))
                Bus.send_down(data)

            except EOFError:
                logging.warn("Pipe was closed from other end of connection")
                Bus.connection["open"] = False
                break
            except ConnectionResetError:
                logging.warn("Pipe was reset")
                Bus.connection["open"] = False
                raise
                #break
            except BrokenPipeError:
                logging.warn("Broken pipe")
                Bus.connection["open"] = False
                raise
                #break

        del Bus.connection["pipe"]

    @staticmethod
    def join():
        # TODO
        pass

class BusProcess(Process):
    """
    A thin wrapper around multiprocessing.Process that lets you set up a message bus between processes.

    A Connection object will be passed as the keyword argument "bus_connection" to the process function.
    Use it to initialize the Bus class in your process function, and you'll be able to interface with
    other processes on the bus:

    Bus.init(bus_connection)
    Bus.subscribe(…, …)
    Bus.send(…, …)
    """

    # instance variables
    bus_parent_thread = None

    def __init__(self, kwargs={}, *args, **keyword_args):
        threading.current_thread().setName("main")
        logging.debug("Initializing new BusProcess")
        parentConnection, childConnection = Pipe()
        logging.debug("Creating Pipe pair {} / {}".format(parentConnection, childConnection))

        kwargs["bus_connection"] = childConnection
        kill_when_broken_bus_connection = True
        if "kill_when_broken_bus_connection" in kwargs:
            kill_when_broken_bus_connection = bool(kwargs["kill_when_broken_bus_connection"])
            del kwargs["kill_when_broken_bus_connection"]

        super().__init__(*args, kwargs=kwargs, **keyword_args)

        Bus.init()
        with Bus.connections_lock:
            logging.debug("Appending {} to set of connections".format(parentConnection))
            Bus.connections.append({"pipe": parentConnection, "open": True})

        self.bus_parent_thread = Thread(target=Bus._recv,
                                        daemon=True,
                                        name=Bus.get_unique_thread_name(prefix="bus_kill"),
                                        args=(parentConnection, self if kill_when_broken_bus_connection else None))
        self.bus_parent_thread.start()

    def run(self):
        Bus.init(self._kwargs.pop("bus_connection", None))
        logging.debug("Recieved bus connection {}".format(Bus.connection["pipe"]))
        super().run()
        # TODO: close connection here after run?
