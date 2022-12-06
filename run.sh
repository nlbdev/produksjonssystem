#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# load python environment
if [ "`which virtualenv`" = "" ]; then
    echo "virtualenv not installed."
    echo "Install with:"
    echo "  pip3 install virtualenv"
    exit 1
fi
if [ ! -d "prodsys-virtualenv" ]; then
    virtualenv prodsys-virtualenv
    pip install -r requirements.txt
fi
source prodsys-virtualenv/bin/activate

python produksjonssystem/run.py "$@"
