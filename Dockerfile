# Debian base
FROM debian:buster

MAINTAINER Sebastian Silva <sebastian@fuentelibre.org>

# Install the application.
RUN apt-get update -qq && apt-get install -y gdal-bin ruby imagemagick ruby-sinatra ruby-kramdown ruby-nokogiri ruby-fog bundler git

# Install production dependencies.
ADD . /app
WORKDIR /app
ENV BUNDLE_FROZEN=true
RUN bundle install

# Copy local code to the container image.


CMD bundle exec ruby app.rb -o 0.0.0.0 -p $PORT
