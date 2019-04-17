#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import os
import shutil
import sys
import threading
import time

from graphviz import Digraph

from core.config import Config
from core.utils.filesystem import Filesystem
from core.utils.metadata import Metadata

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Plotter():
    """
    Generates a HTML page displaying the current state of the system, for use on dashboards.
    """

    pipelines = None  # [ [pipeline,in,out,reports,[recipients,...], ...]
    reports_dir = None
    buffered_network_paths = {}
    buffered_network_hosts = {}
    book_count = {}
    threads = None
    config = None

    debug_logging = False

    def __init__(self):
        self.config = Config()

        self.threads = []

        plotter_thread = threading.Thread(target=self._generate_plots_thread, name="plotter")
        plotter_thread.setDaemon(True)
        plotter_thread.start()
        self.threads.append(plotter_thread)

        #book_count_thread = threading.Thread(target=self._update_book_count_thread, name="plotcounter")
        #book_count_thread.setDaemon(True)
        #book_count_thread.start()
        #self.threads.append(book_count_thread)

    def get_book_count(self, dir, parentdirs=None):
        if not isinstance(dir, str):
            return 0
        if dir not in self.book_count:
            self.book_count[dir] = {
                "parentdirs": parentdirs,
                "count": 0,
                "modified": 0
            }
        if parentdirs:
            self.book_count[dir]["parentdirs"] = parentdirs
        return self.book_count[dir]["count"]

    def rank_name(self, rank_id):
        for rank in self.config.get("dirs_ranked"):
            if rank["id"] == rank_id:
                return rank["name"]
        return None

    def next_rank(self, rank_id):
        use_next = False
        for rank in self.config.get("dirs_ranked"):
            if use_next:
                return rank["id"]
            elif rank["id"] == rank_id:
                use_next = True
        return None

    def plot(self, uids, name):
        self.reports_dir = self.config.get("dir.reports.path")
        if not self.reports_dir:
            logging.info("no reports dir, skipping plot")

        dot = Digraph(name="Produksjonssystem", format="png")
        dot.graph_attr["bgcolor"] = "transparent"

        node_ranks = {}
        for rank in self.config.get("dirs_ranked"):
            node_ranks[rank["id"]] = []

        # remember edges so that we don't plot them twice
        edges = {}

        for uid in uids:
            pipeline = self.config.get("pipeline.{}".format(uid))
            if not pipeline:
                continue

            pipeline_id = uid
            title = pipeline.get("title", "(ukjent)")
            should_retry = pipeline.get("should_retry", True)
            queue = pipeline.get("queue", [])
            dir_in_name = self.config.get("pipeline.{}.dir.in.name".format(uid))
            dir_in_path = self.config.get("pipeline.{}.dir.in.path".format(uid))
            dir_out_name = self.config.get("pipeline.{}.dir.out.name".format(uid))
            dir_out_path = self.config.get("pipeline.{}.dir.out.path".format(uid))
            dir_base = self.config.get("book_archive_dirs")

            queue_created = len([book for book in queue if book["main_event"] == "created"]) if queue else 0
            queue_deleted = len([book for book in queue if book["main_event"] == "deleted"]) if queue else 0
            queue_modified = len([book for book in queue if book["main_event"] == "modified"]) if queue else 0
            queue_triggered = len([book for book in queue if book["main_event"] == "triggered"]) if queue else 0
            queue_autotriggered = len([book for book in queue if book["main_event"] == "autotriggered"]) if queue else 0
            queue_string = []
            if queue_created:
                queue_string.append("nye:"+str(queue_created))
            if queue_modified:
                queue_string.append("endret:"+str(queue_modified))
            if queue_deleted:
                queue_string.append("slettet:"+str(queue_deleted))
            if queue_triggered:
                queue_string.append("trigget:"+str(queue_triggered))
            if queue_autotriggered:
                queue_string.append("autotrigget:"+str(queue_autotriggered))
            queue_string = ", ".join(queue_string)

            queue_size = 0
            if queue:
                queue_size = len(queue)
                if not should_retry:
                    queue_size -= queue_autotriggered
            book = Metadata.pipeline_book_shortname(pipeline.get("book", None))

            # if there's a input directory, get some info about it
            relpath_in = None
            netpath_in = ""
            rank_in = None
            if dir_in_name:
                # determine dir "rank" (for instance "incoming", "master", etc. - the way pipelines are grouped in the graph)
                for rank in self.config.get("dirs_ranked"):
                    for dir in rank["dirs"]:
                        if dir_in_name == dir:
                            rank_in = rank["id"]
                            break

                # determine relative path in book archive
                base_path = Filesystem.get_base_path(dir_in_path, dir_base)
                relpath_in = os.path.relpath(dir_in_path, base_path)

                # determine network host/path
                if dir_in_path not in self.buffered_network_paths:
                    smb, file, unc = Filesystem.networkpath(dir_in_path)
                    host = Filesystem.get_host_from_url(smb)
                    self.buffered_network_paths[dir_in_path] = smb
                    self.buffered_network_hosts[dir_in_path] = host
                netpath_in = self.buffered_network_hosts[dir_in_path]
                if not netpath_in:
                    netpath_in = self.buffered_network_paths[dir_in_path]
            book_count_in = self.get_book_count(dir_in_path)
            label_in = "< <font point-size='24'>{}</font>{}{} >".format(
                relpath_in,
                "\n<br/><i><font point-size='20'>{} {}</font></i>".format(book_count_in, "bok" if book_count_in == 1 else "bøker"),
                "\n<br/><i><font point-size='20'>{}</font></i>".format(netpath_in.replace("\\", "\\\\")) if netpath_in else "")

            # if there's a output directory, get some info about it
            relpath_out = None
            netpath_out = ""
            rank_out = None
            if dir_out_path:
                # determine dir "rank" (for instance "incoming", "master", etc. - the way pipelines are grouped in the graph)
                for rank in self.config.get("dirs_ranked"):
                    for dir in rank["dirs"]:
                        if dir_out_name == dir:
                            rank_out = rank["id"]
                            break

                # determine relative path in book archive
                base_path = Filesystem.get_base_path(dir_out_path, dir_base)
                relpath_out = os.path.relpath(dir_out_path, base_path)

                # determine network host/path
                if dir_out_path not in self.buffered_network_paths:
                    smb, file, unc = Filesystem.networkpath(dir_out_path)
                    host = Filesystem.get_host_from_url(smb)
                    self.buffered_network_paths[dir_out_path] = unc
                    self.buffered_network_hosts[dir_out_path] = host
                netpath_out = self.buffered_network_hosts[dir_out_path]
                if not netpath_out:
                    netpath_out = self.buffered_network_paths[dir_out_path]
            book_count_out = self.get_book_count(dir_out_path, pipeline.get("parentdirs"))
            label_out = "< <font point-size='24'>{}</font>{}{} >".format(
                relpath_out,
                "\n<br/><i><font point-size='20'>{} {}</font></i>".format(book_count_out, "bok" if book_count_out == 1 else "bøker"),
                "\n<br/><i><font point-size='20'>{}</font></i>".format(netpath_out.replace("\\", "\\\\")) if netpath_out else "")

            # add pipeline to rank (i.e. group of pipelines to be plotted at the same level/rank)
            if rank_out:
                node_ranks[rank_out].append(pipeline_id)
            elif rank_in:
                next_rank = self.next_rank(rank_in)
                if next_rank:
                    node_ranks[next_rank].append(pipeline_id)
                else:
                    node_ranks[rank_in].append(pipeline_id)

            # get som info about the pipeline itself, useful for plotting
            status = pipeline.get("status")
            progress_text = pipeline.get("progress")
            pipeline_label = "< <font point-size='26'>{}</font>{} >".format(
                title,
                "".join(["\n<br/><i><font point-size='22'>{}</font></i>".format(val) for val in [queue_string, progress_text, status] if val]))

            fillcolor = "lightskyblue1"
            if book or queue_size:
                fillcolor = "lightslateblue"
            if not pipeline.get("running") or "DummyPipeline" in pipeline.get("instance"):
                fillcolor = "white"
            dot.attr("node", shape="box", style="filled", fillcolor=fillcolor)
            dot.node(pipeline_id, pipeline_label.replace("\\", "\\\\"))

            if dir_in_name:
                fillcolor = "wheat"
                if not pipeline.get("directory_watchers_ready", {}).get("dir_in"):
                    fillcolor = "white"
                dot.attr("node", shape="folder", style="filled", fillcolor=fillcolor)
                dot.node(dir_in_name, label_in)
                if dir_in_name not in edges:
                    edges[dir_in_name] = []
                if pipeline_id not in edges[dir_in_name]:
                    edges[dir_in_name].append(pipeline_id)
                    dot.edge(dir_in_name, pipeline_id)
                node_ranks[rank_in].append(dir_in_name)

            if dir_out_name:
                fillcolor = "wheat"
                if not pipeline.get("directory_watchers_ready", {}).get("dir_out"):
                    fillcolor = "white"
                dot.attr("node", shape="folder", style="filled", fillcolor=fillcolor)
                dot.node(dir_out_name, label_out)
                if pipeline_id not in edges:
                    edges[pipeline_id] = []
                if dir_out_name not in edges[pipeline_id]:
                    edges[pipeline_id].append(dir_out_name)
                    dot.edge(pipeline_id, dir_out_name)
                node_ranks[rank_out].append(dir_out_name)

        for rank in node_ranks:
            subgraph = Digraph("cluster_" + rank, graph_attr={"style": "dotted"})
            subgraph.graph_attr["bgcolor"] = "#FFFFFFAA"

            if node_ranks[rank]:
                subgraph.attr("node", shape="none", style="filled", fillcolor="transparent")
                subgraph.node("_ranklabel_" + rank, "< <i><font point-size='28'>{}</font></i> >".format(" <br/>".join(str(self.rank_name(rank)).split(" "))))

            for dir in node_ranks[rank]:
                subgraph.node(dir)

            dot.subgraph(subgraph)

        dot.render(os.path.join(self.reports_dir, name + "_"))

        # there seems to be some race condition when doing this across a mounted network drive,
        # so if we get an exception we retry a few times and hope that it works.
        # see: https://github.com/nlbdev/produksjonssystem/issues/81
        for t in reversed(range(10)):
            try:
                shutil.copyfile(os.path.join(self.reports_dir, name + "_.png"), os.path.join(self.reports_dir, name + ".png"))
                break
            except Exception as e:
                logging.debug(" Unable to copy plot image: {}".format(os.path.join(self.reports_dir, name + "_.png")))
                time.sleep(0.5)
                if t == 0:
                    raise e

        dashboard_file = os.path.join(self.reports_dir, name + ".html")
        if not os.path.isfile(dashboard_file):
            dashboard_template = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '../../dashboard.html'))
            if not os.path.exists(self.reports_dir):
                os.makedirs(self.reports_dir)
            shutil.copyfile(dashboard_template, dashboard_file)

    @staticmethod
    def run():
        plotter = Plotter()

        while plotter.config.get("system.shouldRun", default=True):
            time.sleep(1)

        plotter.join()

    def join(self):
        for thread in Plotter.threads:
            if thread:
                logging.debug("joining {}".format(thread.name))
                thread.join(timeout=60)

        is_alive = True
        while is_alive:
            is_alive = False
            for thread in Plotter.threads:
                if thread and thread != threading.current_thread() and thread.is_alive():
                    is_alive = True
                    logging.info("Thread is still running: {}".format(thread.name))
                    thread.join(timeout=60)

    def _generate_plots_thread(self):
        reports_dir = self.config.get("dir.reports.path")

        # while loop that waits until reports_dir is available
        while True:
            if not self.config.get("system.shouldRun", default=True):
                # stop if system shouldn't run
                logging.debug("stop if system shouldn't run")
                return
            else:
                logging.info("system.shouldRun: {}".format(self.config.get("system.shouldRun")))

            reports_dir = self.config.get("dir.reports.path")
            if not reports_dir:
                logging.debug("wait for reports_dir to be available: {}".format(reports_dir))
                # wait for reports_dir to be available
                time.sleep(1)
            else:
                logging.debug("break loop when reports_dir is available")
                # break loop when reports_dir is available
                break

        # remove old HTML files, so that we can be sure that they are based on the newest version of the HTML template
        try:
            for name in os.listdir(reports_dir):
                path = os.path.join(reports_dir, name)
                if os.path.isfile(path) and path.endswith(".html"):
                    try:
                        os.remove(path)
                    except Exception:
                        logging.exception("An error occurred while deleting existing HTML file")
        except Exception:
            logging.exception("An error occurred while deleting existing HTML files")

        while self.config.get("system.shouldRun", True):
            time.sleep(1)
            try:
                self.debug_logging = False
                times = []

                self.pipelines = self.config.get("pipeline")

                if not isinstance(self.pipelines, dict):
                    logging.warn("self.pipelines is not a dictionary: {}".format(self.pipelines))

                # Main dashboard
                time_start = time.time()
                self.plot([uid for uid in self.pipelines], "dashboard")
                times.append("dashboard: {}s".format(round(time.time() - time_start, 1)))
                if not self.config.get("system.shouldRun", True):
                    break

                # Dashboard for labels
                time_start = time.time()
                labels = {}
                for p in self.pipelines:
                    for l in self.pipelines[p].get("labels", []):
                        if l not in labels:
                            labels[l] = []
                        labels[l].append(p)
                for l in labels:
                    #print("plotting...")
                    self.plot(labels[l], l)
                    if not self.config.get("system.shouldRun", True):
                        break
                times.append("labels: {}s".format(round(time.time() - time_start, 1)))
                if not self.config.get("system.shouldRun", True):
                    break

                if int(time.time()) % 300 == 0:
                    # print only when mod time is 0 so that this is not logged all the time
                    logging.info(", ".join(times))

            except Exception:
                logging.exception("An error occurred while generating plot")

    def _update_book_count_thread(self):
        while self.config.get("system.shouldRun", True):
            logging.info("_update_book_count_thread is running")
            time.sleep(1)
            try:
                for dir in list(self.book_count.keys()):
                    dirs = []
                    parentdirs = self.book_count[dir]["parentdirs"]
                    if parentdirs:
                        for parentdir in parentdirs:
                            dirs.append(os.path.join(dir, parentdirs[parentdir]))
                    else:
                        dirs.append(dir)
                    if (self.book_count[dir]["modified"] + 15 < time.time()):
                        books = []
                        for d in dirs:
                            if os.path.isdir(d):
                                books += [name for name in os.listdir(d) if name[0] in "0123456789" or name.startswith("TEST")]
                        self.book_count[dir]["modified"] = time.time()
                        self.book_count[dir]["count"] = len(set(books))

                    if not self.config.get("system.shouldRun", True):
                        break

            except Exception:
                logging.exception("An error occurred while updating book count")
