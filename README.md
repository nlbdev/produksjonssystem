Produksjonssystem
=================

Python-skript for å sette opp et produksjonssystem
basert på overvåking av mapper og automatiske
konverteringer.


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

### Endre e-post instillinger

/Fellesdokumenter/IKT/produksjonssystem.yaml

- Legg til eller fjern e-post til pipeline
```yaml
nordic-epub-to-nlbpub:
  - Ola.Nordmann@nlb.no
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
    [ NlbpubToFormat(), "nlbpub", "format", "reports"],
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

## Calibre for ebook konvertering
- `sudo apt-get install calibre`
- Brukes til å konvertere ebok formater

## Teste system
### Automatisk sjekk av produksjonslinje
- `cd ~/Desktop/produksjonssystem`
- `python3 -m unittest tests.testProdsys.py`
- Sjekker at alle utformater blir produsert i løpet av en spesifisert tid

### Installasjon av XSpec
- Klon XSpec: git clone for eksempel på Desktop `https://github.com/expath/xspec.git`
- Last ned Saxon HE `https://sourceforge.net/projects/saxon/files/Saxon-HE/9.8/`
- `~/.bashrc` (legg til på slutten):
```bash
export PATH="$PATH:/home/DER-XSpec-ER/xspec/bin"
export SAXON_CP=/home/DER-SAXON-ER/saxon9he.jar
```
- Husk å gjøre XSpec.sh kjørbar

### For å kjøre XSpec testene i produksjonssystemet
- `cd ~/Desktop/produksjonssystem/xslt`
- chmod +x xspexTest.sh
- ./xspecTesh.sh
