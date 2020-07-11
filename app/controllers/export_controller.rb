require_relative "application_controller.rb"

get "/" do
  markdown :landing
end

# alt route to show files to follow mapknitter-exporter path conventions
get '/public/warps/:export_id/:filename' do
  connection = Fog::Storage.new(YAML.safe_load(ERB.new(File.read('files.yml')).result, [Symbol]))

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
  connection = Fog::Storage.new(YAML.safe_load(ERB.new(File.read('files.yml')).result, [Symbol]))

  directory = connection.directories.get("mapknitter-exports-warps")
  stat = directory.files.get("#{params[:export_id]}/#{params[:filename]}")

  redirect stat.public_url + '?' + request.query_string
end

get '/export' do
  @images_json = params[:collection] || open(params[:url]).read # rubocop:disable Security/Open
  @images_json = JSON.parse(@images_json)
  run_export(@images_json)
end

post '/export' do
  if params[:collection]
    @images_json = if params[:collection].class == String
                     JSON.parse(params[:collection])
                   else
                     params[:collection]
                   end
  else
    unless params[:metadata] &&
           (tmpfile = params[:metadata][:tempfile]) &&
           (name = params[:metadata][:filename])
      @error = "No file selected"
      return markdown :landing
    end
    warn "Uploading file, original name #{name.inspect}"
    @images_json = JSON.parse(tmpfile.read)
  end
  run_export(@images_json)
end

def run_export(images_json)
  export = Export.new
  export.export_id = Time.now.to_i

  images_json = images_json.keep_if do |w|
    w['nodes'] && !w['nodes'].empty? && w['cm_per_pixel'] && w['cm_per_pixel'].to_f.positive?
  end

  scale = params[:scale] || images_json[0]['cm_per_pixel']
  user_id = params[:user_id] || images_json[0]['user_id']
  key = params[:key] || ''

  `mkdir -p public/warps`
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
