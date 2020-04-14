FROM ruby:2.4.6-slim-buster as main-image
MAINTAINER Sebastian Silva <sebastian@fuentelibre.org>

FROM python:2.7 as gdal-builder

# Install the application.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        gdal-bin \
        python-gdal

FROM main-image

COPY --from=gdal-builder /usr/share /usr/share
COPY --from=gdal-builder /usr/bin /usr/bin

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        imagemagick

# Configure ImageMagick
COPY ./nolimit.xml /etc/ImageMagick-6/policy.xml

# Copy local code to the container image.
ADD . /app
WORKDIR /app

# Install production dependencies.
ENV BUNDLE_FROZEN=true
RUN bundle install

CMD bundle exec ruby app.rb -o 0.0.0.0 -p $PORT
