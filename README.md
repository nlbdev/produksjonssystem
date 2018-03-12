Produksjonssystem
=================

Et produksjonssystem basert på overvåking av mapper og automatiske konverteringer.

## Utviklingsmiljø

Anbefaler:

- GitKraken med GitHub-innlogging
- Lag en snarvei til bokarkivet på skrivebordet: `ln --symbolic /tmp/book-archive /home/$USER/Desktop/book-archive`
- oXygen for XML-filer
- For eksempel atom.io for redigering av Python-filer

## Installasjon

- installer java 8 JDK: `sudo apt install openjdk-8-jdk`

- last ned og unzip DAISY Pipeline 2 fra `https://daisy.github.io/pipeline` til `~/Desktop/daisy-pipeline`
    - rediger `etc/system.properties` og endre update url til `http://repo.nlb.no/pipeline/`
    - kjør: `updater/pipeline-updater -service="http://repo.nlb.no/pipeline/" -install-dir=$HOME/Desktop/daisy-pipeline/ -descriptor=$HOME/Desktop/daisy-pipeline/etc/releaseDescriptor.xml -version=current`

- installer ACE:
    - `sudo apt install nodejs npm`
    - `sudo npm install @daisy/ace -g`
    - hvis ikke `/usr/bin/ace` finnes: `sudo ln --symoblic /usr/local/bin/ace /usr/bin/ace`

- installer og konfigurer quickbase-dump-skript:
    - `sudo apt install git maven`
    - `sudo mkdir /opt/quickbase`
    - `sudo chown $USER:$USER /opt/quickbase`
    - last ned https://github.com/nlbdev/ansible/blob/master/src/quickbase/get-latest.sh til `/opt/quickbase/get-latest.sh`
    - `chmod +x /opt/quickbase/get-latest.sh`
    - åpne ny terminal, eller `source ~/config/set-env.sh`

- installer produksjonssystem:
    - klon git repository, enten via GitKraken, eller via kommandolinja (`https://github.com/nlbdev/produksjonssystem`)
    - `pip3 install -r requirements.txt`
    - `sudo apt install graphviz`

## Konfigurasion

`~/config/set-env.sh`:

```bash
export SLACK_TOKEN="…"
export QUICKBASE_APP_TOKEN="…"
export QUICKBASE_DOMAIN="dtbook.quickbase.com"
export QUICKBASE_USERNAME="…@nlb.no"
export QUICKBASE_PASSWORD="…"
export QUICKBASE_DUMP_DIR="/opt/quickbase"
```

`~/.bashrc` (legg til på slutten):

```bash
source $HOME/config/set-env.sh
```

## Kjør produksjonssystem

- for å oppdatere quickbase-database (gjør innimellom, eller etter behov for nyere bøker):
    - `/opt/quickbase/get-latest.sh`

- `cd ~/Desktop/produksjonssystem`
- sett miljøvariabler i terminalen for testing: `source set-test-env.sh` (gjerne legg til dette i `.bashrc`, så slipper du å skrive det hver gang)
- start systemet: `./produksjonssystem/run.py`
- stopp systemet: CTRL+C eller `touch /tmp/trigger-produksjonssystem/stop`
