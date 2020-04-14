#!/bin/bash

apt-get update -qq && \
apt-get install -y \
        gdal-bin \
        python-gdal \
        build-essential \
        git \
        pandoc \
        imagemagick