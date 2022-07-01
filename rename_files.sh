#!/bin/bash

# rename _index.md to <parent_dir>.md
find . -iname '*_index*' -exec bash -c 'mv $1 $(dirname $1)/$(basename $(dirname $1)).md' _ {} \;
