Produksjonssystem
=================

Et produksjonssystem basert på overvåking av mapper og automatiske konverteringer.

## Øvrig dokumentasjon

- [Oppdater metadata](docs/update-metadata/README.md)
- [Lag innlesingsklar EPUB fra NLBPUB](docs/nlbpub-to-narration-epub/README.md)

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

- sett opp tilgang til bibliofil CSV for `*596$f`:
    - Sett miljøvariabelen `ORIGINAL_ISBN_CSV` til å peke på en CSV-fil som inneholder to kolonner: "boknummer" (`*001`) og "ISBN" (`*596$f`)
    - Denne filen blir automatisk generert og lagret på dokumentlageret som `Fellesdokumenter/IKT/original-isbn.csv`. I drift leses det direkte fra denne filen. For testing er det nok enklere å ta en lokal kopi av filen. Standardinnstillingene i `set-test-env.sh` forutsetter at du har en lokal kopi lagret på skrivebordet.
    - Hvis miljøvariabelen ikke er satt, eller filen den peker på ikke finnes, så blir dette ignorert. Denne måten å slå opp boknummer basert på `*596$f` i katalogen er kun nyttig for bøker som ikke ligger i Quickbase.

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

## Endre innstillinger for e-postvarsling

### Definere en ny e-postadresse

Definer kortnavn, navn, og e-postadresse:

```python
email = {
    #...
    "recipients": {
        #...
        "kortnavn":   Address("Navn Navnesen", "Navn.Navnesen", "nlb.no"),
    }
}
```

### Sett opp varsling på e-post:

Legg til kortnavn på slutten av lista:

```python
pipelines = [
    #...
    [ NlbpubToFormat(), "nlbpub", "format", "reports", ["enperson","annenperson","kortnavn"]],
]
```

## Lage en ny pipeline

### Definer pipeline i `run.py`

Definer en ny mappe sammen med de andre mappene, og definer en ny pipeline sammen med de andre pipeline'ene, og sett riktig inn-/ut-mappe.

**`produksjonssystem/run.py`**
```python
dirs = {
    #...
    "format": os.path.join(book_archive_dir, "distribusjonsformater/Format")
}

pipelines = [
    #...
    [ NlbpubToFormat(), "nlbpub", "format", "reports", ["kortnavn"]],
]
```

### Implementer pipeline

Lag en ny Python-fil for pipeline'en i mappen "produksjonssystem". Ta gjerne utgangspunkt i en annen eksisterende pipeline, eller følg den følgende malen:

**`produksjonssystem/nlbpub_to_format.py`**
```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class NlbpubToFormat(Pipeline):
    uid = "..."
    title = "..."
    
    def on_book_deleted(self):
        pass
    
    def on_book_modified(self):
        pass
    
    def on_book_created(self):
        pass


if __name__ == "__main__":
    NlbpubToFormat().run()

```
