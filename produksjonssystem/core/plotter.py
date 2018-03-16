#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import shutil
import logging

from graphviz import Digraph
from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class Plotter():
    """
    Generates a HTML page displaying the current state of the system, for use on dashboards.
    """
    
    pipelines = None # [ [pipeline,in,out,reports,[recipients,...], ...]
    report_dir = None
    should_run = True
    
    def __init__(self, pipelines, report_dir):
        self.pipelines = pipelines
        self.report_dir = report_dir
        dashboard_html_file = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '../../dashboard.html'))
        if not os.path.exists(report_dir):
            os.makedirs(report_dir)
        shutil.copyfile(dashboard_html_file, os.path.join(report_dir, 'dashboard.html'))
    
    def run(self):
        while self.should_run:
            time.sleep(1)
            try:
                dot = Digraph(name="Produksjonssystem", format="png")
                
                for pipeline in self.pipelines:
                    pipeline_id = pipeline[0].uid
                    title = pipeline[0].title if pipeline[0].title else pipeline_id 
                    
                    queue_created = len([book for book in pipeline[0]._queue if Pipeline.get_main_event(book) == "created"]) if pipeline[0]._queue else 0
                    queue_deleted = len([book for book in pipeline[0]._queue if Pipeline.get_main_event(book) == "deleted"]) if pipeline[0]._queue else 0
                    queue_modified = len([book for book in pipeline[0]._queue if Pipeline.get_main_event(book) == "modified"]) if pipeline[0]._queue else 0
                    queue_triggered = len([book for book in pipeline[0]._queue if Pipeline.get_main_event(book) == "triggered"]) if pipeline[0]._queue else 0
                    queue_autotriggered = len([book for book in pipeline[0]._queue if Pipeline.get_main_event(book) == "autotriggered"]) if pipeline[0]._queue else 0
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
                    
                    queue_size = len(pipeline[0]._queue) if pipeline[0]._queue else 0
                    book = pipeline[0].book["name"] if pipeline[0].book else ""
                    
                    relpath_in = "in"
                    if pipeline[0].dir_in and not pipeline[0].dir_base:
                        relpath_in = os.path.basename(os.path.dirname(pipeline[0].dir_in))
                    elif pipeline[0].dir_in and pipeline[0].dir_base:
                        relpath_in = os.path.relpath(pipeline[0].dir_in, pipeline[0].dir_base)
                    
                    relpath_out = "out"
                    if pipeline[0].dir_out and not pipeline[0].dir_base:
                        relpath_out = os.path.basename(os.path.dirname(pipeline[0].dir_out))
                    elif pipeline[0].dir_out and pipeline[0].dir_base:
                        relpath_out = os.path.relpath(pipeline[0].dir_out, pipeline[0].dir_base)
                    
                    pipeline_label = title + "\n" + queue_string + "\n" + ("Behandler: " + str(book) if book else "(venter)" if pipeline[0].running else "")
                    
                    fillcolor = "lightskyblue1"
                    if book or queue_size:
                        fillcolor = "lightslateblue"
                    if not pipeline[0].running:
                        fillcolor = "white"
                    dot.attr("node", shape="box", style="filled", fillcolor=fillcolor)
                    dot.node(pipeline_id, pipeline_label)
                    
                    dot.attr("node", shape="folder", style="filled", fillcolor="wheat")
                    dot.node(pipeline[1], relpath_in)
                    dot.node(pipeline[2], relpath_out)
                    dot.edge(pipeline[1], pipeline_id)
                    dot.edge(pipeline_id, pipeline[2])
                
                dot.render(os.path.join(self.report_dir, 'graph_'))
                shutil.move(os.path.join(self.report_dir, 'graph_.png'), os.path.join(self.report_dir, 'graph.png'))
                
            except Exception:
                logging.exception("An error occured while generating plot")
