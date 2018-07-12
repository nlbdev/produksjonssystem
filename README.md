Produksjonssystem
=================

Python-skript for å sette opp et produksjonssystem
basert på overvåking av mapper og automatiske
konverteringer.

![Animasjon som viser produksjonssystemet](dashboard-demo.gif)

## Øvrig dokumentasjon

- [Oppdater metadata](docs/update-metadata/README.md)
- [Lag innlesingsklar EPUB fra NLBPUB](docs/nlbpub-to-narration-epub/README.md)

## Utviklingsmiljø

Anbefaler:

- [GitKraken](https://www.gitkraken.com/) med GitHub-innlogging
- Lag en snarvei til bokarkivet på skrivebordet: `ln --symbolic /tmp/book-archive /home/$USER/Desktop/book-archive`
- [oXygen](https://www.oxygenxml.com/) for XML-filer
- For eksempel [atom.io](https://atom.io/) for redigering av Python-filer

På "master"-grenen i git vil vi unngå merge commits. Dette er for å holde historikken ren og oversiktlig. Sett derfor opp git til å bruke "rebase" istedenfor "merge" når man gjør en "pull".

Fra kommandolinja, skriv følgende for å sette "rebase" som standard for "git pull":

```bash
git config --global pull.rebase true
```

I GitKraken, trykk på pilen ved siden av "Pull", og trykk deretter på den lille rundingen ved siden av "Pull (rebase)".

![Skjermbilde som viser hvor i GitKraken man skal trykke](gitkraken-pull-rebase.png)

## Installasjon

- installer java 8 JDK: `sudo apt install openjdk-8-jdk`

- installer DAISY Pipeline 2
    - Hvis du ikke har en mappe som heter "Desktop" i hjemmemappen, kjør: `ln --symbolic $HOME/Skrivebord Desktop`
    - last ned og unzip DAISY Pipeline 2 fra http://repo.nlb.no/pipeline/pipeline2_minimal.zip til `~/Desktop/daisy-pipeline`
    - i `etc/system.properties`, sett `org.daisy.pipeline.procs` til 4 for å kunne kjøre flere jobber på en gang (valgfritt)
    - kjør: `updater/linux/pipeline-updater -service="http://repo.nlb.no/pipeline/" -install-dir=$HOME/Desktop/daisy-pipeline/ -descriptor=$HOME/Desktop/daisy-pipeline/etc/releaseDescriptor.xml -version=current -force`
    - opprett `cli/config.yml` med følgende innhold:
        ```
        host: http://localhost
        port: 8181
        ws_path: ws
        ws_timeup: 25
        exec_line: ../bin/pipeline2
        local: true
        client_key: clientid
        client_secret: supersecret
        timeout: 60
        debug: false
        starting: true
        ```

- installer ACE:
    - `sudo apt install nodejs npm`
    - `sudo npm install @daisy/ace -g`
    - hvis ikke `/usr/bin/ace` finnes: `sudo ln --symoblic /usr/local/bin/ace /usr/bin/ace`

- installer Calibre:
    - `sudo apt-get install calibre`

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
    - `sudo apt install python3 python3-pip python3-dev`
    - `sudo apt install graphviz` # for plotting
    - `sudo apt install ffmpeg libavcodec-extra` # for lydutdrag
    - `pip3 install -r requirements.txt`

## Konfigurasjon

Konfigurasjon av passord og lignende som vi ikke vil ha lagret i Git legges i en konfiguratsjonsfil utenfor git repo'et.

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
- `cd ~/Desktop/produksjonssystem` (eventuelt hold musa over "produksjonssystem" øverst til venstre i GitKraken for å se hvor du har lagret produksjonssystemet)
- For å kjøre tester:
  - `./test.sh`
- For å starte produksjonssystemet:
  - sett miljøvariabler i terminalen for testing: `source set-test-env.sh` (gjerne legg til dette i `.bashrc`, så slipper du å skrive det hver gang)
    - `set-test-env.sh` definerer blant annet at bokarkivet skal ligge i en midlertidig mappe kalt `/tmp/book-archive`.
      En liste med lenke til dashboard'et samt bokarkiv-mappene som brukes, vises i terminalvinduet når man starter produksjonssystemet.
  - start systemet: `./produksjonssystem/run.py`
  - stopp systemet: CTRL+C eller `touch /tmp/trigger-produksjonssystem/stop`

## Endre innstillinger for e-postvarsling

### Endre e-post instillinger

E-postadresser defineres i 'produksjonssystem.yaml' (definert med miljøvariabelen `CONFIG_FILE` i `set-test-env.sh`):

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

## Teste system

For å kjøre alle testene:

```
./test.sh
```

Eventuelt kan man teste hele systemet, kjøre alle XSpec-testene, eller alle Python unit test'ene som følger:

```
./test_system.py
./test_xspec.py
./test_unit.py
```
