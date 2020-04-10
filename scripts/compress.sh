#!/bin/bash

# Compress png file
#  - Input: ./static/original_images/
#  - Output: ./static/images/
#---
# Specification
#  - compress all files using
#  - resize the file used in the index page that starts with t-
#---
# Prerequirement
#   - docker
#   - bash

SRC=$(pwd)/../static/original_images
DST=$(pwd)/../static/images

docker run --name png --rm -v ${SRC}:/tmp/src -v ${DST}:/tmp/dst emiketic/image-processing \
  bash -cx 'for i in $(ls /tmp/src | grep .png); do cp /tmp/src/$i /tmp/dst/; if [[ "$i" =~ ^t- ]]; then mogrify -resize 1024x /tmp/dst/$i; fi; pngquant /tmp/dst/$i -f --ext .png --speed 1; done'