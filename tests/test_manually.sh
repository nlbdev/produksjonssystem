#!/bin/bash
set -e

DIR="/tmp/produksjonssystem"
mkdir -p "$DIR"

PRODSYS_REPORTS="$DIR/reports"
PRODSYS_NORDIC="$DIR/nordic_epub_in"
PRODSYS_MASTER="$DIR/master"
PRODSYS_DTBOOK="$DIR/dtbook"
PRODSYS_HTML="$DIR/html"
PRODSYS_HTML_NARRATION="$DIR/html_narration"
PRODSYS_NCC="$DIR/ncc"
mkdir -p "$PRODSYS_REPORTS" "$PRODSYS_NORDIC" "$PRODSYS_MASTER"
mkdir -p "$PRODSYS_DTBOOK" "$PRODSYS_HTML" "$PRODSYS_HTML_NARRATION" "$PRODSYS_NCC"

trap 'kill $(jobs -p)' EXIT

export DIR_REPORTS="$PRODSYS_REPORTS" # same for all
DIR_IN="$PRODSYS_NORDIC" DIR_OUT="$PRODSYS_MASTER" ./produksjonssystem/incoming-nordic.py &
DIR_IN="$PRODSYS_MASTER" DIR_OUT="$PRODSYS_DTBOOK" ./produksjonssystem/epub-to-dtbook.py &

# wait for all forks to complete
for job in `jobs -p` ; do
    wait $job || echo "failed to stop process #$job"
done
ps aux | grep python | grep DIR_IN | awk '{print $2}' | xargs kill

rm "$DIR" -rf
