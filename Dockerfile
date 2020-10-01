FROM node:buster-slim AS build-env
WORKDIR /app
COPY package*json /app/
RUN npm install
COPY .eslintrc webpack.config.js ./js/ /app/
COPY js/ /app/js/
RUN npm run build

FROM perl:5.30-buster

RUN cpanm Carton
RUN useradd app -s /usr/sbin/nologin
RUN mkdir /app && chown app:app /app/
WORKDIR /app
USER app
ENV PERL_CPANM_HOME=/tmp/.cpanm/
EXPOSE 5000

COPY --chown=app:app cpanfile* /app/
RUN carton install --deployment

HEALTHCHECK CMD ss -tln | grep ":5000"

COPY --chown=app:app . /app

COPY --from=build-env /app/public/gion.js /app/public/gion.js
