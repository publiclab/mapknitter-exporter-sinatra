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
require "json"
require "yaml"
require "erb"
require "open-uri"
require "fog/google.rb"
require "fog/local.rb"

get "/" do
  markdown :landing
end

# get files of form /warps/1/1.jpg (for tests)
get '/jpg' do
  send_file "public/warps/#{params[:id]}/#{params[:id]}.jpg"
end

# Show files
get '/id/:export_id/:filename' do
  connection = Fog::Storage.new(YAML.load(ERB.new(File.read('files.yml')).result))

  directory = connection.directories.get("mapknitter-exports-warps")
  stat = directory.files.get("#{params[:export_id]}/#{params[:filename]}")

  redirect stat.public_url
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
    @images_json = JSON.parse(params[:collection])
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

  attr_accessor :status_url, :status, :tms, :geotiff, :zip, :jpg, :user_id, :size, :width, :height, :cm_per_pixel, :export_id

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
      cm_per_pixel: @cm_per_pixel
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

  def initialize
    # create a connection
    connection = Fog::Storage.new( YAML.load(ERB.new(File.read('files.yml')).result) )

    # First, a place to contain the glorious details
    @directory = connection.directories.get("mapknitter-exports-warps")
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

  # TODO: save the static path instead of the sinatra-redirected path, into status.json 
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
