require "mapknitterExporter"

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
  
  MapKnitterExporter.run_export(
      params[:user_id],
      params[:resolution], # different from resolution?
      export,
      params[:id],
      params[:slug],
      params[:root], # this will be the URL eventually so maybe we can fill it from the Sinatra equiv of Rails.root?
      params[:scale],
      [image], # TODO: these images need a special format like https://github.com/publiclab/mapknitter-exporter/blob/bf375b6f2cb09070503f523d24ba803936144875/test/exporter_test.rb#L15-L39
      ''
    )
end


class Export

  attr_accessor :status, :tms, :geotiff, :zip, :jpg # these will be updated with i.e. export.tms = "/path"

  def save
    # need to save status.json file with above properties as strings
    puts "saved"
    return true
  end

end
