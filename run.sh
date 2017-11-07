#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

. ~/config/set-env.sh

PRODSYS_REPORTS="$BOOK_ARCHIVE_MOUNTPOINT/test-new-system/reports"
PRODSYS_NORDIC="$BOOK_ARCHIVE_MOUNTPOINT/test-new-system/nordic-epub-in"
PRODSYS_MASTER="$BOOK_ARCHIVE_MOUNTPOINT/test-new-system/master"
PRODSYS_DTBOOK="$BOOK_ARCHIVE_MOUNTPOINT/test-new-system/dtbook"
PRODSYS_HTML="$BOOK_ARCHIVE_MOUNTPOINT/test-new-system/html"
#PRODSYS_HTML_NARRATION="$BOOK_ARCHIVE_MOUNTPOINT/test-new-system/html-narration"
#PRODSYS_NCC="$BOOK_ARCHIVE_MOUNTPOINT/test-new-system/ncc"

mkdir -p "$PRODSYS_REPORTS" "$PRODSYS_MASTER" "$PRODSYS_NORDIC"
mkdir -p "$PRODSYS_DTBOOK" "$PRODSYS_HTML"
#mkdir -p "$PRODSYS_HTML_NARRATION" "$PRODSYS_NCC"

trap 'kill $(jobs -p)' EXIT


export DIR_REPORTS="$PRODSYS_REPORTS" # same for all pipelines
DIR_IN="$PRODSYS_NORDIC" DIR_OUT="$PRODSYS_MASTER" ./produksjonssystem/incoming-nordic.py &
DIR_IN="$PRODSYS_MASTER" DIR_OUT="$PRODSYS_DTBOOK" ./produksjonssystem/epub-to-dtbook.py &
DIR_IN="$PRODSYS_MASTER" DIR_OUT="$PRODSYS_HTML" ./produksjonssystem/epub-to-html.py &


# wait for all forks to complete
for job in `jobs -p` ; do
    wait $job || echo "failed to stop process #$job"
done
ps aux | grep python | grep DIR_IN | awk '{print $2}' | xargs kill
