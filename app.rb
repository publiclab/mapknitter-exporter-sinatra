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

get "/" do
  markdown :landing
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

  # each image will be:
  # {
  #   "cm_per_pixel":4.99408,
  #   "id":306187, // some unique id
  #   "nodes":[ 
  #     {"id":2593754,"lat":"-37.7664063648","lon":"144.9828654528"},
  #     {"id":2593755,"lat":"-37.7650239004","lon":"144.9831980467"},
  #     {"id":2593756,"lat":"-37.7652020107","lon":"144.9844533205"},
  #     {"id":2593757,"lat":"-37.7665844718","lon":"144.9841207266"}
  #   ],
  #   "src":"https://s3.amazonaws.com/grassrootsmapping/warpables/306187/DJI_1207.JPG",
  # }

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
