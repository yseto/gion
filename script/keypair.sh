#!/bin/bash

cd $(dirname $(readlink -f $0))
KEYS_DIR=../var/keys
mkdir -p $KEYS_DIR
openssl genrsa -out $KEYS_DIR/private.pem 4096
openssl rsa -in $KEYS_DIR/private.pem -pubout -out $KEYS_DIR/public.pem
