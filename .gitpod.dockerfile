FROM gitpod/workspace-full

# Install dependencies.
RUN sudo apt-get update -qq && \
    sudo apt-get install -y \
                    gdal-bin \
                    ruby \
                    zlib1g-dev \
                    imagemagick \
                    ruby-sinatra \
                    ruby-kramdown \
                    ruby-nokogiri \
                    bundler \
                    gdal-bin
