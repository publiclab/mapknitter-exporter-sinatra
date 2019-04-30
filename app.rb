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
require "open-uri"

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
  @data = open(params[:url]).read
  @data = JSON.parse(@data)

  export = Export.new

  @data = @data.keep_if do |w|
    w['nodes'] && w['nodes'].length > 0 && w['cm_per_pixel'] && w['cm_per_pixel'].to_f > 0
  end

  scale = params[:scale] || @data[0]['cm_per_pixel']
  map_id = params[:map_id] || @data[0]['map_id']
  id = params[:id] || @data[0]['id']
  key = params[:key] || ''

  pid = fork do
    MapKnitterExporter.run_export(
      id, # sources from first image
      scale,
      export,
      map_id,
      ".",
      @data,
      key
    )
  end
  Process.detach(pid)
  "/pid/#{pid}/status.json"
end

post '/export' do
  unless params[:metadata] &&
       (tmpfile = params[:metadata][:tempfile]) &&
       (name = params[:metadata][:filename])
    @error = "No file selected"
    return markdown :landing
  end
  STDERR.puts "Uploading file, original name #{name.inspect}"
  @data = JSON.parse(tmpfile.read)
  String @data[0]['image_file_name']

  export = Export.new
  export.export_id = Time.now.to_i

  @data = @data.keep_if do |w|
    w['nodes'] && w['nodes'].length > 0 && w['cm_per_pixel'] && w['cm_per_pixel'].to_f > 0
  end

  scale = params[:scale] || @data[0]['cm_per_pixel']
  map_id = params[:map_id] || @data[0]['map_id']
  id = params[:id] || @data[0]['id']
  key = params[:key] || ''

  pid = fork do
    MapKnitterExporter.run_export(
      id, # sources from first image
      scale,
      export,
      map_id,
      ".",
      @data,
      key
    )
  end
  Process.detach(pid)
  "/#{export.export_id}/status.json"
end

class Export

  attr_accessor :status, :tms, :geotiff, :zip, :jpg, :user_id, :size, :width, :height, :cm_per_pixel, :export_id

  def as_json(options={})
    {
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

  def save
    # need to save status.json file with above properties as strings
    FileUtils.mkpath 'public/' + export_id.to_s
    File.write 'public/' + export_id.to_s + '/status.json', to_json({})
    return true
  end

end
