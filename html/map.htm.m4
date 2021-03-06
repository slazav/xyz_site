<html>
<head>
  <link rel="stylesheet" href="deps/leaflet.css" />
  <link rel="stylesheet" href="main.css" />
  <script src="deps/leaflet.js"></script>
  <script src="deps/knockout-3.2.0.js"></script>

  <!-- I use signals.js + crossroads.js + hasher.js
      to make client-side navigation. See:
      https://millermedeiros.github.io/crossroads.js/ -->
  <script src="deps/signals.min.js"></script>
  <script src="deps/crossroads.min.js"></script>
  <script src="deps/hasher.min.js"></script>

  <script src="rod/rodn201411.js" charset="UTF-8"></script>
  <script src="map.js"></script>
  <script src="main.js"></script>
  <script src="site.js"></script>

  <style>
    #mapid { height: 100%; }
  </style>
</head>
<body onload="SetUp('mapid')">

MAIN_PANEL_BEGIN

<table cellpadding=5 cellspacing=0 border=0 width=100% height=100%><tr>
<td valign=top width=20%>
<b>�������� ����:</b>
<br><input type=checkbox id=toggle_OSM checked onclick="layer_toggle('OSM')"><label>OSM</label>
<p><b>���������:</b>
<div><input type=checkbox id=toggle_rodn onclick="layer_toggle('rodn')"><label>�������
<br>(������� �������� ����������� ������ �������� � ������������)</label>
</div>
</td>
<td width=80%>
<div id="mapid"></div>
</td>

MAIN_PANEL_END

</body>
</html>
