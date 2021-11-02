require_relative "../app/controllers/export_controller.rb"

class Export
  attr_accessor :status_url, :status, :tms, :geotiff, :zip, :jpg, :user_id, :size, :width, :height, :cm_per_pixel, :export_id, :start_time, :run_time, :gem_version

  def as_json(_options = {})
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
    connection = Fog::Storage.new(YAML.safe_load(ERB.new(File.read('files.yml')).result, [Symbol]))
    @start_time = Time.now

    # First, a place to contain the glorious details
    @directory = connection.directories.get("mapknitter-exports-warps")
  end

  def run_time # rubocop:disable Lint/DuplicateMethods
    Time.now - @start_time
  end

  def save_file(path, extension, id)
    key = "#{id}/#{id}.#{extension}"
    file = @directory.files.create(
      key: key,
      body: File.open(path),
      public: true
    )
    warn "saved #{extension} at #{key}"
    file
  end

  def check_status
    if @status == "complete"
      save_file(@jpg, 'jpg', @export_id)
    elsif @status == "generating jpg" # tiles have been zipped
      # save zip
      save_file(@zip, 'zip', @export_id)
    elsif @status == "zipping tiles" # tiles have been generated
      # save tms
      Dir.chdir('public/tms/#{@export_id}')
      Dir['**/*.{jpg,png,html,xml}'].each do |path|
        key = "#{@export_id}/tms/#{path}"
        file = @directory.files.create(
          key: key,
          body: File.open(path),
          public: true
        )
        Dir.chdir('../../../')
      end
    elsif @status == "tiling" # images have been composited into single image
      # save geotiff
      save_file(@geotiff, 'tif', @export_id)
        # elsif @status == "compositing" # individual images have been distorted
        #   # save individual images? (optional)
      end
  end

  def save
    check_status

    # need to save status.json file with above properties as strings
    if @directory.files.head("#{@export_id}/status.json")
      sleep 2 # or we hit "Too many requests"
      stat = @directory.files.get("#{@export_id}/status.json")
      # record a static URL for status.json:
      @status_url = stat.public_url
      stat.destroy
    end

    @directory.files.create(
      key: "#{@export_id}/status.json",
      body: to_json,
      public: true
    )
    warn "saved status.json"
    true
  end
end
