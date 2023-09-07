FROM python:3.7

WORKDIR /app

COPY requirements.txt .

RUN pip install --upgrade pip && \
    pip install -r requirements.txt

WORKDIR /app/jar

RUN wget -O saxon9he.jar https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/9.5.1-5/Saxon-HE-9.5.1-5.jar
RUN wget -O jing.jar https://repo1.maven.org/maven2/io/github/relaxng/jing/20161127/jing-20161127.jar

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    virtualenv && \
    rm -rf /var/lib/apt/lists/* && \
    virtualenv --python=python3.7 prodsys-virtualenv && \
    . prodsys-virtualenv/bin/activate

COPY . .

CMD ["python", "produksjonssystem/run.py"]
