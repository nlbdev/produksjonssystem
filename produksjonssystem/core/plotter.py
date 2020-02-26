#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import logging
import os
import shutil
import threading
import time

from graphviz import Digraph

from core.directory import Directory
from core.pipeline import DummyPipeline, Pipeline
from core.utils.filesystem import Filesystem
from core.utils.metadata import Metadata


class Plotter():
    """
    Generates a HTML page displaying the current state of the system, for use on dashboards.
    """

    pipelines = None  # [ [pipeline,in,out,reports,[recipients,...], ...]
    report_dir = None
    buffered_network_paths = {}
    buffered_network_hosts = {}
    should_run = True
    book_count = {}
    threads = None

    debug_logging = False

    def __init__(self, pipelines, report_dir):
        self.pipelines = pipelines
        self.report_dir = report_dir

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
        for rank in Directory.dirs_ranked:
            if rank["id"] == rank_id:
                return rank["name"]
        return None

    def next_rank(self, rank_id):
        use_next = False
        for rank in Directory.dirs_ranked:
            if use_next:
                return rank["id"]
            elif rank["id"] == rank_id:
                use_next = True
        return None

    def plot(self, uids, name):
        dot = Digraph(name="Produksjonssystem", format="png")
        dot.graph_attr["bgcolor"] = "transparent"

        node_ranks = {}
        for rank in Directory.dirs_ranked:
            node_ranks[rank["id"]] = []

        # remember edges so that we don't plot them twice
        edges = {}

        for uid in uids:
            pipeline = None
            for p in self.pipelines:
                if p[0].uid == uid:
                    pipeline = p
                    break
            if not pipeline:
                continue

            group_pipeline = pipeline[0].get_current_group_pipeline()

            title = group_pipeline.get_group_title()
            pipeline_id = group_pipeline.get_group_id()  # re.sub(r"[^a-z\d]", "", title.lower())

            queue = group_pipeline.get_queue()

            queue_created = len([book for book in queue if Pipeline.get_main_event(book) == "created"]) if queue else 0
            queue_deleted = len([book for book in queue if Pipeline.get_main_event(book) == "deleted"]) if queue else 0
            queue_modified = len([book for book in queue if Pipeline.get_main_event(book) == "modified"]) if queue else 0
            queue_triggered = len([book for book in queue if Pipeline.get_main_event(book) == "triggered"]) if queue else 0
            queue_autotriggered = len([book for book in queue if Pipeline.get_main_event(book) == "autotriggered"]) if queue else 0
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
                if not group_pipeline.should_handle_autotriggered_books():
                    queue_size -= queue_autotriggered
            book = Metadata.pipeline_book_shortname(group_pipeline)

            relpath_in = None
            netpath_in = ""
            rank_in = None
            if pipeline[0].dir_in:
                for rank in Directory.dirs_ranked:
                    for dir in rank["dirs"]:
                        if os.path.normpath(pipeline[0].dir_in) == os.path.normpath(rank["dirs"][dir]):
                            rank_in = rank["id"]
                            break
            if pipeline[0].dir_in and not pipeline[0].dir_base:
                relpath_in = os.path.basename(os.path.dirname(pipeline[0].dir_in))
            elif pipeline[0].dir_in and pipeline[0].dir_base:
                base_path = Filesystem.get_base_path(pipeline[0].dir_in, pipeline[0].dir_base)
                relpath_in = os.path.relpath(pipeline[0].dir_in, base_path)
                if "master" in pipeline[0].dir_base and pipeline[0].dir_base["master"] == base_path:
                    pass
                else:
                    if pipeline[0].dir_in not in self.buffered_network_paths:
                        smb, file, unc = Filesystem.networkpath(pipeline[0].dir_in)
                        host = Filesystem.get_host_from_url(smb)
                        self.buffered_network_paths[pipeline[0].dir_in] = smb
                        self.buffered_network_hosts[pipeline[0].dir_in] = host
                    netpath_in = self.buffered_network_hosts[pipeline[0].dir_in]
                    if not netpath_in:
                        netpath_in = self.buffered_network_paths[pipeline[0].dir_in]
            book_count_in = self.get_book_count(pipeline[0].dir_in)
            label_in = "< <font point-size='24'>{}</font>{}{} >".format(
                relpath_in,
                "\n<br/><i><font point-size='20'>{} {}</font></i>".format(book_count_in, "bok" if book_count_in == 1 else "bøker"),
                "\n<br/><i><font point-size='20'>{}</font></i>".format(netpath_in.replace("\\", "\\\\")) if netpath_in else "")

            relpath_out = None
            netpath_out = ""
            rank_out = None
            if pipeline[0].dir_out:
                for rank in Directory.dirs_ranked:
                    for dir in rank["dirs"]:
                        if os.path.normpath(pipeline[0].dir_out) == os.path.normpath(rank["dirs"][dir]):
                            rank_out = rank["id"]
                            break
            if pipeline[0].dir_out and not pipeline[0].dir_base:
                relpath_out = os.path.basename(os.path.dirname(pipeline[0].dir_out))
            elif pipeline[0].dir_out and pipeline[0].dir_base:
                base_path = Filesystem.get_base_path(pipeline[0].dir_out, pipeline[0].dir_base)
                relpath_out = os.path.relpath(pipeline[0].dir_out, base_path)
                if "master" in pipeline[0].dir_base and pipeline[0].dir_base["master"] == base_path:
                    pass
                else:
                    if pipeline[0].dir_out not in self.buffered_network_paths:
                        smb, file, unc = Filesystem.networkpath(pipeline[0].dir_out)
                        host = Filesystem.get_host_from_url(smb)
                        self.buffered_network_paths[pipeline[0].dir_out] = unc
                        self.buffered_network_hosts[pipeline[0].dir_out] = host
                    netpath_out = self.buffered_network_hosts[pipeline[0].dir_out]
                    if not netpath_out:
                        netpath_out = self.buffered_network_paths[pipeline[0].dir_out]
            book_count_out = self.get_book_count(pipeline[0].dir_out, pipeline[0].parentdirs)
            label_out = "< <font point-size='24'>{}</font>{}{} >".format(
                relpath_out,
                "\n<br/><i><font point-size='20'>{} {}</font></i>".format(book_count_out, "bok" if book_count_out == 1 else "bøker"),
                "\n<br/><i><font point-size='20'>{}</font></i>".format(netpath_out.replace("\\", "\\\\")) if netpath_out else "")

            if rank_out:
                node_ranks[rank_out].append(pipeline_id)
            elif rank_in:
                next_rank = self.next_rank(rank_in)
                if next_rank:
                    node_ranks[next_rank].append(pipeline_id)
                else:
                    node_ranks[rank_in].append(pipeline_id)

            state = group_pipeline.get_state()
            status = group_pipeline.get_status()
            progress_text = group_pipeline.get_progress()
            pipeline_label = "< <font point-size='26'>{}</font>{} >".format(
                title,
                "".join(["\n<br/><i><font point-size='22'>{}</font></i>".format(val) for val in [queue_string, progress_text, status] if val]))

            fillcolor = "lightskyblue1"
            if book or queue_size:
                fillcolor = "lightslateblue"
            elif state == "considering":
                fillcolor = "lightskyblue3"
            elif not group_pipeline.running:
                fillcolor = "white"
            elif isinstance(group_pipeline, DummyPipeline):
                fillcolor = "snow"
            dot.attr("node", shape="box", style="filled", fillcolor=fillcolor)
            dot.node(pipeline_id, pipeline_label.replace("\\", "\\\\"))

            if relpath_in:
                fillcolor = "wheat"
                if not pipeline[0].dir_in_obj or not pipeline[0].dir_in_obj.is_available():
                    fillcolor = "white"
                dot.attr("node", shape="folder", style="filled", fillcolor=fillcolor)
                dot.node(pipeline[1], label_in)
                if pipeline[1] not in edges:
                    edges[pipeline[1]] = []
                if pipeline_id not in edges[pipeline[1]]:
                    edges[pipeline[1]].append(pipeline_id)
                    dot.edge(pipeline[1], pipeline_id)
                node_ranks[rank_in].append(pipeline[1])

            if relpath_out:
                fillcolor = "wheat"
                if not pipeline[0].dir_out_obj or not pipeline[0].dir_out_obj.is_available():
                    fillcolor = "white"
                dot.attr("node", shape="folder", style="filled", fillcolor=fillcolor)
                dot.node(pipeline[2], label_out)
                if pipeline_id not in edges:
                    edges[pipeline_id] = []
                if pipeline[2] not in edges[pipeline_id]:
                    edges[pipeline_id].append(pipeline[2])
                    dot.edge(pipeline_id, pipeline[2])
                node_ranks[rank_out].append(pipeline[2])

        for rank in node_ranks:
            subgraph = Digraph("cluster_" + rank, graph_attr={"style": "dotted"})
            subgraph.graph_attr["bgcolor"] = "#FFFFFFAA"

            if node_ranks[rank]:
                subgraph.attr("node", shape="none", style="filled", fillcolor="transparent")
                subgraph.node("_ranklabel_" + rank, "< <i><font point-size='28'>{}</font></i> >".format(" <br/>".join(str(self.rank_name(rank)).split(" "))))

            for dir in node_ranks[rank]:
                subgraph.node(dir)

            dot.subgraph(subgraph)

        dot.render(os.path.join(self.report_dir, name + "_"))

        # there seems to be some race condition when doing this across a mounted network drive,
        # so if we get an exception we retry a few times and hope that it works.
        # see: https://github.com/nlbdev/produksjonssystem/issues/81
        for t in reversed(range(10)):
            try:
                shutil.copyfile(os.path.join(self.report_dir, name + "_.png"), os.path.join(self.report_dir, name + ".png"))
                with open(os.path.join(self.report_dir, name + ".js"), "w") as javascript_file:
                    javascript_file.write("setTime(\"{}\");".format(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
                break
            except Exception as e:
                logging.debug(" Unable to copy plot image: {}".format(os.path.join(self.report_dir, name + "_.png")))
                time.sleep(0.5)
                if t == 0:
                    raise e

        dashboard_file = os.path.join(self.report_dir, name + ".html")
        if not os.path.isfile(dashboard_file):
            dashboard_template = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '../../dashboard.html'))
            if not os.path.exists(self.report_dir):
                os.makedirs(self.report_dir)
            shutil.copyfile(dashboard_template, dashboard_file)

    def run(self):
        self.threads = []

        plotter_thread = threading.Thread(target=self._generate_plots_thread, name="graph plotter")
        plotter_thread.setDaemon(True)
        plotter_thread.start()
        self.threads.append(plotter_thread)

        book_count_thread = threading.Thread(target=self._update_book_count_thread, name="graph book count updater")
        book_count_thread.setDaemon(True)
        book_count_thread.start()
        self.threads.append(book_count_thread)

        while self.should_run:
            time.sleep(1)

        self.join()

    def join(self):
        for thread in self.threads:
            if thread:
                logging.debug("joining {}".format(thread.name))
                thread.join(timeout=60)

        is_alive = True
        while is_alive:
            is_alive = False
            for thread in self.threads:
                if thread and thread != threading.current_thread() and thread.is_alive():
                    is_alive = True
                    logging.info("Plotter thread is still running: {}".format(thread.name))
                    thread.join(timeout=60)

    def _generate_plots_thread(self):
        try:
            for name in os.listdir(self.report_dir):
                path = os.path.join(self.report_dir, name)
                if os.path.isfile(path) and path.endswith(".html"):
                    try:
                        os.remove(path)
                    except Exception:
                        logging.exception("An error occurred while deleting existing HTML file")
        except Exception:
            logging.exception("An error occurred while deleting existing HTML files")

        while self.should_run:
            time.sleep(1)
            try:
                self.debug_logging = False
                times = []

                if not isinstance(self.pipelines, list):
                    logging.warn("self.pipelines is not a list: {}".format(self.pipelines))

                # Main dashboard
                time_start = time.time()
                self.plot([p[0].uid for p in self.pipelines], "dashboard")
                times.append("dashboard: {}s".format(round(time.time() - time_start, 1)))
                if not self.should_run:
                    break

                # Dashboard for labels
                time_start = time.time()
                labels = {}
                for p in self.pipelines:
                    for l in p[0].labels:
                        if l not in labels:
                            labels[l] = []
                        labels[l].append(p[0].uid)
                for l in labels:
                    self.plot(labels[l], l)
                    if not self.should_run:
                        break
                times.append("labels: {}s".format(round(time.time() - time_start, 1)))
                if not self.should_run:
                    break

                if int(time.time()) % 300 == 0:
                    # print only when mod time is 0 so that this is not logged all the time
                    logging.info(", ".join(times))

            except Exception:
                logging.exception("An error occurred while generating plot")

    def _update_book_count_thread(self):
        while self.should_run:
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
                                books += Filesystem.list_book_dir(d)
                        self.book_count[dir]["modified"] = time.time()
                        self.book_count[dir]["count"] = len(set(books))

                    if not self.should_run:
                        break

            except Exception:
                logging.exception("An error occurred while updating book count")
