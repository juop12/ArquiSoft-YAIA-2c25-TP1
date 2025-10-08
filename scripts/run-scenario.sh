#!/bin/sh
cd "$(dirname "$0")"
npm run artillery -- run $1.yaml -e $2
