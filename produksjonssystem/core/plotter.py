#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import shutil
import logging

from graphviz import Digraph
from core.pipeline import Pipeline, DummyPipeline
from core.utils.report import Report
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class Plotter():
    """
    Generates a HTML page displaying the current state of the system, for use on dashboards.
    """
    
    pipelines = None # [ [pipeline,in,out,reports,[recipients,...], ...]
    report_dir = None
    buffered_network_paths = {}
    buffered_network_hosts = {}
    should_run = True
    
    def __init__(self, pipelines, report_dir):
        self.pipelines = pipelines
        self.report_dir = report_dir
    
    def plot(self, uids, name):
        dot = Digraph(name="Produksjonssystem", format="png")
        
        for pipeline in self.pipelines:
            if not pipeline[0].uid in uids:
                continue
            
            pipeline_id = pipeline[0].uid
            title = pipeline[0].title if pipeline[0].title else pipeline_id 
            queue = pipeline[0].get_queue()
            
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
            
            queue_size = len(queue) if queue else 0
            book = pipeline[0].current_book_name()
            
            relpath_in = None
            netpath_in = ""
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
            label_in = "< <font point-size='16'>{}</font>{} >".format(relpath_in, "\n<br/><i>{}</i>".format(netpath_in.replace("\\", "\\\\")) if netpath_in else "")
            
            relpath_out = None
            netpath_out = ""
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
            label_out = "< <font point-size='16'>{}</font>{} >".format(relpath_out, "\n<br/><i>{}</i>".format(netpath_out.replace("\\", "\\\\")) if netpath_out else "")
            
            status = ""
            start_text = ""
            if pipeline[0]._shouldRun and not pipeline[0].running:
                status = "Starter..."
                start_text = pipeline[0].start_text
            elif not pipeline[0]._shouldRun and pipeline[0].running:
                status = "Stopper..."
            elif not pipeline[0].running and not isinstance(pipeline[0], DummyPipeline):
                status = "Stoppet"
                queue_string = ""
            elif book:
                status = str(book)
            elif isinstance(pipeline[0], DummyPipeline):
                status = "Manuelt steg"
            else:
                status = "Venter"
            pipeline_label = "< <font point-size='18'>{}</font>{} >".format(title, "".join(["\n<br/><i>{}</i>".format(val) for val in [queue_string, start_text, status] if val]))
            
            fillcolor = "lightskyblue1"
            if book or queue_size:
                fillcolor = "lightslateblue"
            if not pipeline[0].running or isinstance(pipeline[0], DummyPipeline):
                fillcolor = "white"
            dot.attr("node", shape="box", style="filled", fillcolor=fillcolor)
            dot.node(pipeline_id, pipeline_label.replace("\\", "\\\\"))
            
            dot.attr("node", shape="folder", style="filled", fillcolor="wheat")
            if relpath_in:
                dot.node(pipeline[1], label_in)
                dot.edge(pipeline[1], pipeline_id)
            if relpath_out:
                dot.node(pipeline[2], label_out)
                dot.edge(pipeline_id, pipeline[2])
        
        dot.render(os.path.join(self.report_dir, name + "_"))
        
        # there seems to be some race condition when doing this across a mounted network drive,
        # so if we get a FileNotFoundError we just retry a few times and it should work.
        for t in reversed(range(10)):
            try:
                os.rename(os.path.join(self.report_dir, name + "_.png"), os.path.join(self.report_dir, name + ".png"))
                break
            except FileNotFoundError as e:
                logging.debug("[" + Report.thread_name() + "]" + " Unable to rename plot image: {}".format(os.path.join(self.report_dir, name + "_.png")))
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
        while self.should_run:
            time.sleep(1)
            try:
                self.plot([p[0].uid for p in self.pipelines], "dashboard")
                
                for p in self.pipelines:
                    self.plot([p[0].uid], p[0].uid)
                
            except Exception:
                logging.exception("[" + Report.thread_name() + "] " + "An error occurred while generating plot")
