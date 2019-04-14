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

get '/export' do
  @data = open(params[:url]).read
  @data = JSON.parse(@data)

  export = Export.new
  
  MapKnitterExporter.run_export(
    @data[0]['id'], # sources from first image
    @data[0]['cm_per_pixel'],
    export,
    @data[0]['map_id'],
    ".",
    @data,
    ''
  )
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

  MapKnitterExporter.run_export(
    @data[0]['id'], # sources from first image
    @data[0]['cm_per_pixel'],
    export,
    @data[0]['map_id'],
    ".",
    @data,
    ''
  )

  # This will be the final version, once we reformat to give export.json top-level properties:
#   MapKnitterExporter.run_export(
#       @data['id'],
#       @data['cm_per_pixel'],
#       export,
#       @data['user_id'], # formerly map_id
#       ".", # root
#       @data['images'],
#       @data['google_api_key'] || '' # optional Google API key
#     )
end


class Export

  attr_accessor :status, :tms, :geotiff, :zip, :jpg, :user_id, :size, :width, :height, :cm_per_pixel

  def save
    # need to save status.json file with above properties as strings
    puts "saved"
    return true
  end

end
