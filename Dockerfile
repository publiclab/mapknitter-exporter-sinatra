# Debian base
FROM debian:buster

MAINTAINER Sebastian Silva <sebastian@fuentelibre.org>

# Install the application.
RUN apt-get update -qq && apt-get install -y gdal-bin ruby imagemagick ruby-sinatra ruby-kramdown bundler git

# Install production dependencies.
WORKDIR /app
COPY .bundle Gemfile Gemfile.lock ./
ENV BUNDLE_FROZEN=true
RUN bundle install

# Copy local code to the container image.
COPY . .

CMD bundle exec ruby app.rb -o 0.0.0.0 -p $PORT
