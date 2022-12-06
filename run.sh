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
    if [ "`which python3.7`" = "" ]; then
	echo "Python 3.7 not installed. Please install Pyton 3.7 before continuing. Suggestion:"
        echo "sudo apt install software-properties-common -y"
        echo "sudo add-apt-repository ppa:deadsnakes/ppa -y"
        echo "sudo apt update"
        echo "sudo apt install python3.7 python3.7-distutils"
    fi
    virtualenv --python="`which python3.7`" prodsys-virtualenv
    pip install -r requirements.txt
fi
source prodsys-virtualenv/bin/activate

python produksjonssystem/run.py "$@"
