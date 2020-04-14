#!/bin/bash

apt-get update -qq && \
apt-get install -y \
        gdal-bin \
        python-gdal \
        pandoc \
        ruby-kramdown \
        ruby-nokogiri \
        imagemagick
