#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# load python environment
if [ ! -d "prodsys-virtualenv" ]; then
    virtualenv prodsys-virtualenv
    pip install -r requirements.txt
fi
source prodsys-virtualenv/bin/activate

python -m unittest tests.test_pipeline "$@"
