# mapknitter-exporter-sinatra

A minimal Sinatra app to run MapKnitter exports in the cloud, using the `mapknitter-exporter` gem.

* Gem: https://github.com/publiclab/mapknitter-exporter
* Rails app: https://github.com/publiclab/mapknitter

## Usage

(note NOT https for now:) http://export.mapknitter.org/export?url=https://mapknitter.org/maps/ceres--2/warpables.json&scale=30

You can also run it as a POST or GET with a parameter called `collection` containing the JSON string.

```js
var json = {[
  {
  "cm_per_pixel": 4.99408,
  "nodes": [ 
    {"lat":"-37.7664063648","lon":"144.9828654528"}, // id is also optional here
    {"lat":"-37.7650239004","lon":"144.9831980467"},
    {"lat":"-37.7652020107","lon":"144.9844533205"},
    {"lat":"-37.7665844718","lon":"144.9841207266"}
  ],
  "src":"https://s3.amazonaws.com/grassrootsmapping/warpables/306187/DJI_1207.JPG",
  },
  { ... } // add as many images to the list as we want
]}

$.post("http://export.mapknitter.org/export", {
    scale: 30,
    collection: JSON.stringify(json) } )
  .success(function(response) {
    // response is the URL of a status.json file that will be continuously updated with the status of the export
  });
```

## status.json format

```js
{
  "status_url":"https://mapknitter-exports-warps.storage.googleapis.com/1557156175/status.json",
  "status":"complete",
  "tms":"public/tms/1557156175/",
  "geotiff":"public/warps/1557156175/1557156175.tif",
  "zip":"public/tms/1557156175.zip",
  "jpg":"public/warps/1557156175/1557156175.jpg",
  "export_id":1557156175,
  "user_id":null,
  "size":"3.85456MB",
  "width":"1272",
  "height":"744",
  "cm_per_pixel":30.0
}
```

The URLs can then be used like:

* GeoTiff: http://export.mapknitter.org/public/warps/1557156175/1557156175.tif
* JPG: http://export.mapknitter.org/public/warps/1557156175/1557156175.jpg
* Zip: http://export.mapknitter.org/public/warps/1557156175/1557156175.zip
