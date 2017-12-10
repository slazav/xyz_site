var map;
var layers = {};

function SetUp(mapid){

  // Setup the map
  map = L.map(mapid);

  // change URL on map move
  map.on('moveend', function(e){
    z = map.getZoom();
    x = map.getCenter().lat.toFixed(5);
    y = map.getCenter().lng.toFixed(5);
    hasher.setHash(z+"/"+x+"/"+y);
  });

  // setup hasher: listen for history changes and run crossroads.
  function parseHash(newHash, oldHash){ crossroads.parse(newHash); }
  hasher.prependHash = '';
  hasher.initialized.add(parseHash); //parse initial hash
  hasher.changed.add(parseHash); //parse hash changes
  hasher.init(); //start listening for history change

  // setup crossroads
  crossroads.addRoute('{z}/{x}/{y}', function(z,x,y) { map.setView([x, y], z); });

  //initial URL
  hasher.setHash("8/55.66674/37.50732");

  //default layer
  layer_toggle('OSM');
}

//function ViewModel() {
//  var self = this;
//};

function add_osm_layer() {
  return L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="http://osm.org/about/" target="_blank">OpenStreetMap</a> contributors'
  }).addTo(map);
}

function add_wpt_layer() {
  var myIcon1 = L.icon({
    iconUrl: 'img_geo/rod.png',
    iconSize:     [7, 12], // size of the icon
    iconAnchor:   [3,  3], // point of the icon which will correspond to marker's location
  });
  var myIcon2 = L.icon({
    iconUrl: 'img_geo/rod.png',
    iconSize:     [7, 12], // size of the icon
    iconAnchor:   [3,  3], // point of the icon which will correspond to marker's location
  });

  var get_marker_opts = function(type){
    if (type == 1)  return { icon: myIcon1 };
    return { icon: myIcon2 };
  }

  var get_popup = function(id){
    return id;
  }

  var rodn_geo = []
  for (var r in rodn_data){
    rodn_geo.push({
      "type": "Point",
      "t": 1,
      "txt": rodn_data[r].txt1 + "<p>" + rodn_data[r].txt2,
      "id": rodn_data[r].id,
      "coordinates": rodn_data[r].crd});
  }

  return L.geoJson(rodn_geo, {
    pointToLayer: function (feature, latlng) {
      return L.marker(latlng, get_marker_opts(feature.t));
    },
    onEachFeature: function(feature, layer) {
      layer.bindPopup(get_popup(feature.txt));
    }
  }).addTo(map);
}

function layer_toggle(name) {
  var sw = document.getElementById('toggle_' + name);

  if (name == 'OSM') {
    if (sw.checked) { layers.osm = add_osm_layer(); }
    else { map.removeLayer(layers.osm); }
    return;
  }

  if (name == 'rodn') {
    if (sw.checked) { layers.rodn = add_wpt_layer(); }
    else { map.removeLayer(layers.rodn); }
    return;
  }

}


//ko.applyBindings(new ViewModel());
