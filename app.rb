# Copyright 2015 Google, Inc
# Copyright 2019 Public Lab
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "mapknitterExporter"
require "sinatra"
require "sinatra/cors"

set :allow_origin, "*"
set :allow_methods, "GET,HEAD,POST"
set :allow_headers, "content-type,if-modified-since"
set :expose_headers, "location,link"

require "json"
require "yaml"
require "erb"
require "open-uri"
require "fog/google.rb"
require "fog/local.rb"

get "/" do
  markdown :landing
end

# alt route to show files to follow mapknitter-exporter path conventions
get '/public/warps/:export_id/:filename' do
  connection = Fog::Storage.new(YAML.load(ERB.new(File.read('files.yml')).result))

  directory = connection.directories.get("mapknitter-exports-warps")
  stat = directory.files.get("#{params[:export_id]}/#{params[:filename]}")

  redirect stat.public_url  
end

# for testing
get '/working/:id/:filename' do
  send_file File.join(settings.public_folder, "warps/#{params[:id]}/#{params[:filename]}")
end

# Show files
get '/id/:export_id/:filename' do
  connection = Fog::Storage.new(YAML.load(ERB.new(File.read('files.yml')).result))

  directory = connection.directories.get("mapknitter-exports-warps")
  stat = directory.files.get("#{params[:export_id]}/#{params[:filename]}")

  redirect stat.public_url + '?' + request.query_string
end

get '/export' do
  if params[:collection]
    @images_json = params[:collection]
  else
    @images_json = open(params[:url]).read
  end
  @images_json = JSON.parse(@images_json)
  run_export(@images_json)
end

post '/export' do
  if params[:collection]
    if params[:collection] == String
      @images_json = JSON.parse(params[:collection]) 
    else
      @images_json = params[:collection]
    end
  else
    unless params[:metadata] &&
         (tmpfile = params[:metadata][:tempfile]) &&
         (name = params[:metadata][:filename])
      @error = "No file selected"
      return markdown :landing
    end
    STDERR.puts "Uploading file, original name #{name.inspect}"
    @images_json = JSON.parse(tmpfile.read)
  end
  run_export(@images_json)
end

def run_export(images_json)
  export = Export.new
  export.export_id = Time.now.to_i

  images_json = images_json.keep_if do |w|
    w['nodes'] && w['nodes'].length > 0 && w['cm_per_pixel'] && w['cm_per_pixel'].to_f > 0
  end

  scale = params[:scale] || images_json[0]['cm_per_pixel']
  user_id = params[:user_id] || images_json[0]['user_id']
  key = params[:key] || ''

  `mkdir public/warps`
  pid = fork do
    settings.running_server = nil
    MapKnitterExporter.run_export(
      user_id, # user_id, unused
      scale,
      export,
      export.export_id,
      images_json,
      key
    )
  end
  Process.detach(pid)
  "/id/#{export.export_id}/status.json"
end

class Export

  attr_accessor :status_url, :status, :tms, :geotiff, :zip, :jpg, :user_id, :size, :width, :height, :cm_per_pixel, :export_id, :start_time, :run_time, :gem_version

  def as_json(options={})
    {
      status_url: @status_url,
      status: @status,
      tms: @tms,
      geotiff: @geotiff,
      zip: @zip,
      jpg: @jpg,
      export_id: @export_id,
      user_id: @user_id,
      size: @size,
      width: @width,
      height: @height,
      start_time: @start_time,
      run_time: @run_time,
      gem_version: Gem.loaded_specs['mapknitter-exporter'].version.to_s,
      cm_per_pixel: @cm_per_pixel
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

  def initialize
    # create a connection
    connection = Fog::Storage.new( YAML.load(ERB.new(File.read('files.yml')).result) )
    @start_time = Time.now

    # First, a place to contain the glorious details
    @directory = connection.directories.get("mapknitter-exports-warps")
  end

  def run_time
    Time.now - @start_time
  end

  def save
    if @status == "complete"
      save_file(@jpg, 'jpg', @export_id)
    elsif @status == "generating jpg" # tiles have been zipped
      # save zip
      save_file(@zip, 'zip', @export_id)
    # elsif @status == "zipping tiles" # tiles have been generated
    #   # save tms
    elsif @status == "tiling" # images have been composited into single image
      # save geotiff
      save_file(@geotiff, 'tif', @export_id)
    # elsif @status == "compositing" # individual images have been distorted
    #   # save individual images? (optional)
    end

    # need to save status.json file with above properties as strings
    if @directory.files.head("#{@export_id}/status.json")
      sleep 2  # or we hit "Too many requests"
      stat = @directory.files.get("#{@export_id}/status.json")
      # record a static URL for status.json:
      @status_url = stat.public_url
      stat.destroy
    end

    @directory.files.create(
      :key    => "#{@export_id}/status.json",
      :body   => to_json,
      :public => true
    )
    STDERR.puts "saved status.json"
    return true
  end

  def save_file(path, extension, id)
    key = "#{id}/#{id}.#{extension}"
    file = @directory.files.create(
      :key    => key,
      :body   => File.open(path),
      :public => true
    )
    STDERR.puts "saved #{extension} at #{key}"
    file
  end

end
