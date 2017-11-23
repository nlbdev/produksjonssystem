#!/bin/bash

pipreqs . --force --print | sort > requirements.txt
