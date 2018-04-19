#!/bin/bash

# script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export BOOK_ARCHIVE_DIRS="master=/tmp/book-archive share=/tmp/book-archive-share"
export TRIGGER_DIR="/tmp/trigger-produksjonssystem"
export PIPELINE2_HOME="$HOME/Desktop/daisy-pipeline"
export ORIGINAL_ISBN_CSV="$HOME/Desktop/original-isbn.csv"

if [ -f "$HOME/Desktop/produksjonssystem.yaml" ]; then
    export CONFIG_FILE="$HOME/Desktop/produksjonssystem.yaml"
else
    export CONFIG_FILE="$DIR/produksjonssystem.yaml"
fi
