FROM node:buster-slim AS build-env
WORKDIR /app
COPY package*json /app/
RUN npm install
COPY .eslintrc webpack.config.js ./js/ /app/
COPY js/ /app/js/
RUN npm run build

FROM perl:5.30-buster

RUN cpanm Carton \
    && mkdir -p /app
WORKDIR /app

COPY cpanfile* /app/
RUN carton install --deployment

COPY . /app
COPY --from=build-env /app/public/gion.js /app/public/gion.js
