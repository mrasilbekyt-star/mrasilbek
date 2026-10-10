import 'dart:convert';
import 'dart:ui';

/// Colors of one map look.
class MapTheme {
  const MapTheme({
    required this.id,
    required this.pro,
    required this.dark,
    required this.background,
    required this.residential,
    required this.park,
    required this.wood,
    required this.water,
    required this.waterLine,
    required this.roadMajor,
    required this.roadMid,
    required this.roadMinor,
    required this.path,
    required this.rail,
    required this.building,
    required this.buildingTop,
    required this.placeLabel,
    required this.roadLabel,
    required this.waterLabel,
    required this.halo,
    required this.routeStart,
    required this.routeEnd,
  });

  final String id;

  /// Only Hudud Pro members can pick it.
  final bool pro;
  final bool dark;
  final Color background;
  final Color residential;
  final Color park;
  final Color wood;
  final Color water;
  final Color waterLine;
  final Color roadMajor;
  final Color roadMid;
  final Color roadMinor;
  final Color path;
  final Color rail;
  final Color building;
  final Color buildingTop;
  final Color placeLabel;
  final Color roadLabel;
  final Color waterLabel;
  final Color halo;

  /// The live route fades from [routeStart] (where you began) to [routeEnd].
  final Color routeStart;
  final Color routeEnd;

  static const night = MapTheme(
    id: 'night',
    pro: false,
    dark: true,
    background: Color(0xFF070B12),
    residential: Color(0xFF0B111B),
    park: Color(0xFF0B1D1A),
    wood: Color(0xFF0A1A16),
    water: Color(0xFF0A2135),
    waterLine: Color(0xFF0F2D45),
    roadMajor: Color(0xFF2B3A50),
    roadMid: Color(0xFF212D3E),
    roadMinor: Color(0xFF19222F),
    path: Color(0xFF34465C),
    rail: Color(0xFF1D2733),
    building: Color(0xFF111925),
    buildingTop: Color(0xFF1C2738),
    placeLabel: Color(0xFFAEBBCD),
    roadLabel: Color(0xFF64758C),
    waterLabel: Color(0xFF4C8DB5),
    halo: Color(0xFF070B12),
    routeStart: Color(0xFF7C5CFF),
    routeEnd: Color(0xFF3DFFA2),
  );

  static const aurora = MapTheme(
    id: 'aurora',
    pro: true,
    dark: true,
    background: Color(0xFF0B0718),
    residential: Color(0xFF110B22),
    park: Color(0xFF0E1B26),
    wood: Color(0xFF0C1822),
    water: Color(0xFF101A3D),
    waterLine: Color(0xFF16245A),
    roadMajor: Color(0xFF3B2F6B),
    roadMid: Color(0xFF2A2350),
    roadMinor: Color(0xFF1E1A3B),
    path: Color(0xFF4A3D82),
    rail: Color(0xFF241D44),
    building: Color(0xFF160F2C),
    buildingTop: Color(0xFF261C49),
    placeLabel: Color(0xFFC7B8FF),
    roadLabel: Color(0xFF7F72B8),
    waterLabel: Color(0xFF6E8CFF),
    halo: Color(0xFF0B0718),
    routeStart: Color(0xFFFF4FD8),
    routeEnd: Color(0xFF22E5FF),
  );

  static const dawn = MapTheme(
    id: 'dawn',
    pro: true,
    dark: false,
    background: Color(0xFFF3F1EC),
    residential: Color(0xFFEDEAE3),
    park: Color(0xFFDDEBD5),
    wood: Color(0xFFD2E4C9),
    water: Color(0xFFBFDCEB),
    waterLine: Color(0xFFA9CFE3),
    roadMajor: Color(0xFFFFFFFF),
    roadMid: Color(0xFFFFFFFF),
    roadMinor: Color(0xFFFBFAF7),
    path: Color(0xFFC9BFAF),
    rail: Color(0xFFD5D0C6),
    building: Color(0xFFE2DED6),
    buildingTop: Color(0xFFD6D1C7),
    placeLabel: Color(0xFF3B4250),
    roadLabel: Color(0xFF7D8491),
    waterLabel: Color(0xFF4C86A8),
    halo: Color(0xFFF3F1EC),
    routeStart: Color(0xFFFF6B3D),
    routeEnd: Color(0xFFE6007E),
  );

  static const desert = MapTheme(
    id: 'desert',
    pro: true,
    dark: true,
    background: Color(0xFF15100A),
    residential: Color(0xFF1C150D),
    park: Color(0xFF1B1D10),
    wood: Color(0xFF17190E),
    water: Color(0xFF0E2430),
    waterLine: Color(0xFF14313F),
    roadMajor: Color(0xFF4A3820),
    roadMid: Color(0xFF382A18),
    roadMinor: Color(0xFF281E12),
    path: Color(0xFF5C4628),
    rail: Color(0xFF30251A),
    building: Color(0xFF211810),
    buildingTop: Color(0xFF34261A),
    placeLabel: Color(0xFFE8CFA6),
    roadLabel: Color(0xFFA58A61),
    waterLabel: Color(0xFF5FA3BF),
    halo: Color(0xFF15100A),
    routeStart: Color(0xFFFFB020),
    routeEnd: Color(0xFFFF4D6D),
  );

  static const all = [night, aurora, dawn, desert];

  static MapTheme byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => night);
}

/// Where the base map comes from. OpenFreeMap serves OpenStreetMap vector
/// tiles in the OpenMapTiles schema, free and without a key.
abstract final class MapSource {
  static const tiles = 'https://tiles.openfreemap.org/planet';
  static const glyphs = 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';
  static const regular = ['Noto Sans Regular'];
  static const bold = ['Noto Sans Bold'];
  static const italic = ['Noto Sans Italic'];
}

/// Ids of the GeoJSON sources the app fills in at run time.
abstract final class HududSources {
  static const territory = 'hudud-territory';
  static const runCells = 'hudud-run-cells';
  static const route = 'hudud-route';
  static const hint = 'hudud-hint';
  static const me = 'hudud-me';
  static const all = [territory, runCells, route, hint, me];
}

String hex(Color c) {
  final argb = c.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

const _emptyCollection = {'type': 'FeatureCollection', 'features': <Object>[]};

Map<String, Object?> _geojsonSource({bool lineMetrics = false}) => {
      'type': 'geojson',
      'data': _emptyCollection,
      if (lineMetrics) 'lineMetrics': true,
    };

/// Label text: the Uzbek name when OpenStreetMap has one, else the Latin
/// spelling, else the local name.
const _name = ['coalesce', ['get', 'name:uz'], ['get', 'name:latin'], ['get', 'name']];

List<Object> _zoomRamp(List<num> stops) => ['interpolate', ['exponential', 1.5], ['zoom'], ...stops];

/// The complete MapLibre style: the base map in [theme] with the Hudud
/// layers (territory, the live run, the loop hint and the runner) on top.
Map<String, Object?> buildStyle(MapTheme theme) {
  final t = theme;
  return {
    'version': 8,
    'name': 'Hudud ${t.id}',
    'glyphs': MapSource.glyphs,
    'sources': {
      'openmaptiles': {'type': 'vector', 'url': MapSource.tiles},
      HududSources.territory: _geojsonSource(),
      HududSources.runCells: _geojsonSource(),
      HududSources.route: _geojsonSource(lineMetrics: true),
      HududSources.hint: _geojsonSource(),
      HududSources.me: _geojsonSource(),
    },
    'layers': [
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': hex(t.background)},
      },
      {
        'id': 'landuse-residential',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'landuse',
        'filter': ['in', ['get', 'class'], ['literal', ['residential', 'suburb', 'neighbourhood']]],
        'paint': {'fill-color': hex(t.residential)},
      },
      {
        'id': 'park',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'park',
        'paint': {'fill-color': hex(t.park)},
      },
      {
        'id': 'landcover-green',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'landcover',
        'filter': ['in', ['get', 'class'], ['literal', ['grass', 'wood', 'farmland', 'wetland']]],
        'paint': {
          'fill-color': ['match', ['get', 'class'], 'wood', hex(t.wood), hex(t.park)],
          'fill-opacity': 0.9,
        },
      },
      {
        'id': 'landuse-sport',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'landuse',
        'filter': ['in', ['get', 'class'], ['literal', ['pitch', 'stadium', 'playground', 'park']]],
        'paint': {'fill-color': hex(t.park)},
      },
      {
        'id': 'water',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'water',
        'paint': {'fill-color': hex(t.water)},
      },
      {
        'id': 'waterway',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'waterway',
        'paint': {
          'line-color': hex(t.waterLine),
          'line-width': _zoomRamp([10, 0.6, 18, 4]),
        },
      },
      {
        'id': 'road-path',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'transportation',
        'minzoom': 14,
        'filter': ['==', ['get', 'class'], 'path'],
        'layout': {'line-cap': 'round'},
        'paint': {
          'line-color': hex(t.path),
          'line-width': _zoomRamp([14, 0.6, 18, 2.2]),
          'line-dasharray': [1.5, 1.5],
        },
      },
      {
        'id': 'road-minor',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'transportation',
        'filter': ['in', ['get', 'class'], ['literal', ['minor', 'service', 'track']]],
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': hex(t.roadMinor),
          'line-width': _zoomRamp([12, 0.5, 18, 9]),
        },
      },
      {
        'id': 'road-mid',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'transportation',
        'filter': ['in', ['get', 'class'], ['literal', ['secondary', 'tertiary']]],
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': hex(t.roadMid),
          'line-width': _zoomRamp([8, 0.5, 18, 14]),
        },
      },
      {
        'id': 'road-major',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'transportation',
        'filter': ['in', ['get', 'class'], ['literal', ['motorway', 'trunk', 'primary']]],
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': hex(t.roadMajor),
          'line-width': _zoomRamp([5, 0.6, 18, 20]),
        },
      },
      {
        'id': 'rail',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'transportation',
        'filter': ['in', ['get', 'class'], ['literal', ['rail', 'transit']]],
        'paint': {
          'line-color': hex(t.rail),
          'line-width': _zoomRamp([10, 0.6, 18, 3]),
          'line-dasharray': [3, 2],
        },
      },
      {
        'id': 'building-flat',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'building',
        'minzoom': 13,
        'maxzoom': 15,
        'paint': {'fill-color': hex(t.building)},
      },
      {
        'id': 'building-3d',
        'type': 'fill-extrusion',
        'source': 'openmaptiles',
        'source-layer': 'building',
        'minzoom': 15,
        'filter': ['!=', ['get', 'hide_3d'], true],
        'paint': {
          'fill-extrusion-color': [
            'interpolate', ['linear'], ['coalesce', ['get', 'render_height'], 6],
            0, hex(t.building),
            40, hex(t.buildingTop),
          ],
          'fill-extrusion-height': ['coalesce', ['get', 'render_height'], 6],
          'fill-extrusion-base': ['coalesce', ['get', 'render_min_height'], 0],
          'fill-extrusion-opacity': 0.9,
          'fill-extrusion-vertical-gradient': true,
        },
      },
      ..._hududLayers(t),
      {
        'id': 'label-road',
        'type': 'symbol',
        'source': 'openmaptiles',
        'source-layer': 'transportation_name',
        'minzoom': 14,
        'layout': {
          'symbol-placement': 'line',
          'text-field': _name,
          'text-font': MapSource.regular,
          'text-size': _zoomRamp([14, 10, 18, 13]),
          'text-letter-spacing': 0.04,
        },
        'paint': {
          'text-color': hex(t.roadLabel),
          'text-halo-color': hex(t.halo),
          'text-halo-width': 1.4,
        },
      },
      {
        'id': 'label-water',
        'type': 'symbol',
        'source': 'openmaptiles',
        'source-layer': 'water_name',
        'layout': {
          'text-field': _name,
          'text-font': MapSource.italic,
          'text-size': 12,
        },
        'paint': {
          'text-color': hex(t.waterLabel),
          'text-halo-color': hex(t.halo),
          'text-halo-width': 1.2,
        },
      },
      {
        'id': 'label-neighbourhood',
        'type': 'symbol',
        'source': 'openmaptiles',
        'source-layer': 'place',
        'minzoom': 12,
        'filter': ['in', ['get', 'class'], ['literal', ['suburb', 'neighbourhood', 'quarter', 'village', 'hamlet']]],
        'layout': {
          'text-field': _name,
          'text-font': MapSource.bold,
          'text-size': _zoomRamp([12, 10, 16, 14]),
          'text-transform': 'uppercase',
          'text-letter-spacing': 0.12,
          'text-max-width': 8,
        },
        'paint': {
          'text-color': hex(t.placeLabel),
          'text-opacity': 0.75,
          'text-halo-color': hex(t.halo),
          'text-halo-width': 1.6,
        },
      },
      {
        'id': 'label-city',
        'type': 'symbol',
        'source': 'openmaptiles',
        'source-layer': 'place',
        'maxzoom': 14,
        'filter': ['in', ['get', 'class'], ['literal', ['city', 'town']]],
        'layout': {
          'text-field': _name,
          'text-font': MapSource.bold,
          'text-size': _zoomRamp([5, 11, 12, 20]),
        },
        'paint': {
          'text-color': hex(t.placeLabel),
          'text-halo-color': hex(t.halo),
          'text-halo-width': 2,
        },
      },
      ..._runnerLayers(t),
    ],
  };
}

/// Territory and the live run sit above the base map and below the labels.
/// Colors come from each feature's `color`, so a new skin needs no restyle.
List<Map<String, Object?>> _hududLayers(MapTheme t) => [
      {
        'id': 'territory-fill',
        'type': 'fill',
        'source': HududSources.territory,
        'paint': {
          'fill-color': ['get', 'color'],
          'fill-opacity': t.dark ? 0.22 : 0.3,
        },
      },
      {
        'id': 'territory-3d',
        'type': 'fill-extrusion',
        'source': HududSources.territory,
        'minzoom': 14,
        'paint': {
          'fill-extrusion-color': ['get', 'color'],
          'fill-extrusion-height': 4,
          'fill-extrusion-opacity': 0.35,
        },
      },
      {
        'id': 'territory-glow',
        'type': 'line',
        'source': HududSources.territory,
        'layout': {'line-join': 'round'},
        'paint': {
          'line-color': ['get', 'color'],
          'line-width': _zoomRamp([12, 4, 18, 14]),
          'line-blur': _zoomRamp([12, 3, 18, 10]),
          'line-opacity': 0.4,
        },
      },
      {
        'id': 'territory-line',
        'type': 'line',
        'source': HududSources.territory,
        'layout': {'line-join': 'round'},
        'paint': {
          'line-color': ['get', 'color'],
          'line-width': _zoomRamp([12, 1, 18, 2.6]),
        },
      },
      {
        'id': 'run-cells-fill',
        'type': 'fill',
        'source': HududSources.runCells,
        'paint': {
          'fill-color': ['get', 'color'],
          'fill-opacity': 0.45,
        },
      },
      {
        'id': 'run-cells-line',
        'type': 'line',
        'source': HududSources.runCells,
        'paint': {
          'line-color': '#ffffff',
          'line-opacity': 0.7,
          'line-width': _zoomRamp([12, 0.6, 18, 1.8]),
        },
      },
    ];

/// The route, the loop hint and the runner's dot, drawn above everything.
List<Map<String, Object?>> _runnerLayers(MapTheme t) => [
      {
        'id': 'route-glow',
        'type': 'line',
        'source': HududSources.route,
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': hex(t.routeEnd),
          'line-width': _zoomRamp([12, 8, 18, 22]),
          'line-blur': _zoomRamp([12, 6, 18, 14]),
          'line-opacity': 0.3,
        },
      },
      {
        'id': 'route-line',
        'type': 'line',
        'source': HududSources.route,
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-width': _zoomRamp([12, 3, 18, 7]),
          'line-gradient': [
            'interpolate', ['linear'], ['line-progress'],
            0, hex(t.routeStart),
            1, hex(t.routeEnd),
          ],
        },
      },
      {
        'id': 'hint-line',
        'type': 'line',
        'source': HududSources.hint,
        'layout': {'line-cap': 'round'},
        'paint': {
          'line-color': t.dark ? '#ffffff' : '#1b2230',
          'line-opacity': 0.8,
          'line-width': 2.5,
          'line-dasharray': [0.5, 2],
        },
      },
      {
        'id': 'hint-target',
        'type': 'circle',
        'source': HududSources.hint,
        'filter': ['==', ['geometry-type'], 'Point'],
        'paint': {
          'circle-radius': 9,
          'circle-color': 'rgba(0,0,0,0)',
          'circle-stroke-color': hex(t.routeEnd),
          'circle-stroke-width': 3,
        },
      },
      {
        'id': 'me-accuracy',
        'type': 'circle',
        'source': HududSources.me,
        'paint': {
          // `acc22` is the accuracy radius in pixels at zoom 22; halving it
          // per zoom level keeps the circle the right size in meters.
          'circle-radius': ['interpolate', ['exponential', 2], ['zoom'],
            0, ['/', ['get', 'acc22'], 4194304],
            22, ['get', 'acc22']],
          'circle-color': hex(t.routeEnd),
          'circle-opacity': 0.12,
          'circle-pitch-alignment': 'map',
        },
      },
      {
        'id': 'me-halo',
        'type': 'circle',
        'source': HududSources.me,
        'paint': {
          'circle-radius': 14,
          'circle-color': hex(t.routeEnd),
          'circle-opacity': 0.25,
          'circle-blur': 0.6,
        },
      },
      {
        'id': 'me-dot',
        'type': 'circle',
        'source': HududSources.me,
        'paint': {
          'circle-radius': 7,
          'circle-color': hex(t.routeEnd),
          'circle-stroke-color': '#ffffff',
          'circle-stroke-width': 3,
        },
      },
    ];

String styleJson(MapTheme theme) => jsonEncode(buildStyle(theme));
