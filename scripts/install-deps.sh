#!/bin/bash

apt-get update -qq && \
apt-get install -y --no-install-recommends \
        gdal-bin \
        python-gdal \
        build-essential \
        git \
        imagemagick
