FROM gitpod/workspace-full

# Install dependencies.
RUN apt-get update -qq && \
    apt-get install -y \
                    gdal-bin \
                    ruby \
                    zlib1g-dev \
                    imagemagick \
                    ruby-sinatra \
                    ruby-kramdown \
                    ruby-nokogiri \
                    bundler \
                    python-gdal
