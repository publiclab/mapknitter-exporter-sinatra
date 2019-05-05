# Debian base
FROM debian:buster

MAINTAINER Sebastian Silva <sebastian@fuentelibre.org>

# Install the application.
RUN apt-get update -qq && apt-get install -y gdal-bin ruby imagemagick ruby-sinatra ruby-kramdown ruby-nokogiri bundler git python-gdal

# Configure ImageMagick
COPY ./nolimit.xml /etc/ImageMagick-6/policy.xml

# Copy local code to the container image.
ADD . /app
WORKDIR /app

# Install production dependencies.
ENV BUNDLE_FROZEN=true
RUN bundle install

CMD bundle exec ruby app.rb -o 0.0.0.0 -p $PORT
