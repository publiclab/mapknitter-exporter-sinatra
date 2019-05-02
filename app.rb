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

# get files of form /warps/1/1.jpg
get '/jpg' do
  send_file "public/warps/#{params[:id]}/#{params[:id]}.jpg"
end

# Show current status
get '/pid/:pid/status.json' do |n|
  send_file "public/pid/#{params[:pid]}/status.json"
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
  map_id = params[:map_id] || images_json[0]['map_id']
  id = params[:id] || images_json[0]['id']
  key = params[:key] || ''

  pid = fork do
    MapKnitterExporter.run_export(
      id, # sources from first image
      scale,
      export,
      map_id,
      images_json,
      key,
      map_id # redundant, collection_id, see https://github.com/publiclab/mapknitter-exporter/issues/21
    )
  end
  Process.detach(pid)
  "/#{export.export_id}/status.json"
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
    @directory = connection.directories.create(
      :key    => Process.pid.to_s,
      :public => true
    )
  end


  def save
    # need to save status.json file with above properties as strings
    @directory.files.create(
      :key    => 'status.json',
      :body   => @status,
      :public => true
    )
    puts "saved"
    if @status == "complete"
      @directory.files.create(
        :key    => "output.jpg",
        :body   => "jpg content placeholder",
        :public => true
      )
    end
    return true
  end

end
