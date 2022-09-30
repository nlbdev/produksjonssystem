#!/bin/bash

echo "First, load the correct python environment:"
echo "source prodsys-virtualenv/bin/activate"
echo
echo "If you haven't already, install pipreqs and pip-tools."
echo "You'll have to reload your environment after installing."
echo "pip install pipreqs pip-tools"
echo "source prodsys-virtualenv/bin/activate"
echo 
echo "Then, modify requirements.in manually."
echo "You can also recreate it automatically, but you should"
echo "then manually inspect it afterwards:"
echo "pipreqs produksjonssystem --force --print | sed 's/=.*//' | sort > requirements.in"
echo
echo "Finally, compile a new requirements.txt:"
echo "pip-compile requirements.in > requirements.txt"
