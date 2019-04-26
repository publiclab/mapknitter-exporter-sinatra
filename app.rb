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

  export = run_export(@data)
  export.jpg
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

  export = run_export(@data)
  export.jpg
end

def run_export(data)
  export = Export.new
  data = data.keep_if do |w|
    w['nodes'] && w['nodes'].length > 0 && w['cm_per_pixel'] && w['cm_per_pixel'].to_f > 0
  end

  scale = params[:scale] || data[0]['cm_per_pixel']
  map_id = params[:map_id] || data[0]['map_id']
  id = params[:id] || data[0]['id']
  key = params[:key] || ''

  MapKnitterExporter.run_export(
    id, # sources from first image
    scale,
    export,
    map_id,
    ".",
    data,
    key
  )
end

class Export

  attr_accessor :status, :tms, :geotiff, :zip, :jpg, :user_id, :size, :width, :height, :cm_per_pixel

  def save
    # need to save status.json file with above properties as strings
    puts "saved"
    return true
  end

end
