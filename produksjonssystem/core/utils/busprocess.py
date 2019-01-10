# -*- coding: utf-8 -*-

import multiprocessing
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
        raise Exception("Bus should not be instantiated.")

    @staticmethod
    def init(connection=None):
        if Bus.current_process == multiprocessing.current_process():
            return

        Bus.current_process = multiprocessing.current_process()

        Bus.listeners_lock = RLock()
        Bus.listeners = []

        Bus.connections_lock = RLock()
        Bus.connections = []

        Bus.connection = connection
        if Bus.connection:
            Bus.child_thread = Thread(target=Bus._recv_down, args=(), daemon=True)
            Bus.child_thread.start()


    @staticmethod
    def subscribe(topic, fn):
        """Register a function to handle messages about the given topic. Starts a listener that runs in the child process."""
        Bus.init()
        with Bus.listeners_lock:
            Bus.listeners.append({
                "topic": topic,
                "function": fn
            })

    @staticmethod
    def send(topic, data):
        """Send data to the bus on the given topic."""
        Bus.init()
        if Bus.connection:
            # sends to parent process
            Bus.connection.send([topic, data])
        else:
            # sends to current process and child processes
            Bus.send_down([topic, data])

    @staticmethod
    def send_down(data):
        Bus.init()

        # sends to all child processes
        with Bus.connections_lock:
            for connection in Bus.connections:
                connection.send(data)

        # sends to all subscribed functions in current process
        assert isinstance(data, list), "Message bus data must be a list"
        assert len(data) == 2, "Message bus data must have to items: [topic, data]"
        [topic, data] = data
        with Bus.listeners_lock:
            for listener in Bus.listeners:
                if listener["topic"] == topic:
                    listener["function"](data)

    @staticmethod
    def _recv(connection):
        """Thread that listens for messages sent from the child process and broadcasts it to all processes. Runs in parent process."""
        Bus.init()
        while True:
            try:
                data = connection.recv()  # Blocks until there is something to receive from the process
                assert isinstance(data, list), "Message bus data must be a list"
                assert len(data) == 2, "Message bus data must have to items: [topic, data]"
                [topic, data] = data
                Bus.send(topic, data)

            except EOFError:
                print("Pipe was closed from other end of connection")
                break

    @staticmethod
    def _recv_down():
        """Thread that listens for messages sent from the parent process and forwards it to all listeners. Runs in child process."""
        Bus.init()
        while True:
            try:
                data = Bus.connection.recv()  # Blocks until there is something to receive
                Bus.send_down(data)

            except EOFError:
                print("Pipe was closed from other end of connection")
                break


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
        parentConnection, childConnection = Pipe()

        kwargs["bus_connection"] = childConnection

        super().__init__(*args, kwargs=kwargs, **keyword_args)

        Bus.init()
        with Bus.connections_lock:
            Bus.connections.append(parentConnection)

        self.bus_parent_thread = Thread(target=Bus._recv, args=(parentConnection,), daemon=True)
        self.bus_parent_thread.start()
