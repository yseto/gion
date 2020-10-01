#!/bin/bash

cd $(dirname $(readlink -f $0))
cd ../

script/keypair.sh
exec carton exec -- script/process.pl
