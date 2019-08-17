FROM perl:5.30-buster

RUN cpanm Carton \
    && mkdir -p /app
WORKDIR /app

COPY cpanfile* /app/
RUN carton install

COPY . /app
