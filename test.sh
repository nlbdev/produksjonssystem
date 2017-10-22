#!/bin/bash

# fail and exit on first error
set -e

# go to script dir
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# make resource dir for testing and start produksjonsystem
mkdir -p target/resources
./produksjonsystem.py "$DIR/target/resources" &
sleep 1

# do some basic stuff
cd target/resources
touch foo.xml
sleep 0.5
echo bar >> foo.xml
sleep 0.5
mv foo.xml bar.xml
sleep 0.5
rm bar.xml
sleep 2

mkdir -p book1
sleep 0.5
touch book1/ncc.html
sleep 0.5
touch book1/audio1.mp3
sleep 0.5
touch book1/audio2.mp3
sleep 0.5
touch book1/content.html
sleep 0.5
touch book1/image.png
sleep 2

mkdir -p book2
sleep 0.5
touch book2/ncc.html
sleep 0.5
mv book1/image.png book2/image.png

sleep 15

rm * -r

# stop produksjonsystem
ps aux | grep produksjonsystem.py | grep -v grep | awk '{print $2}' | xargs kill
wait 2>/dev/null
sleep 1
