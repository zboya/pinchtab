#!/bin/bash
set -o nounset
set -o errexit

# Check if dist directory exists
if [ ! -d "dist" ]; then
    printf "Error: dist directory does not exist.\n" >&2
    exit 1
fi

# Copy all files from dist to the current directory, overwriting existing files
rsync -a --exclude='.git' dist/ ./

printf "Done: all files from dist/ have been copied to the current directory.\n"
