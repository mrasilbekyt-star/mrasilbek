import 'package:flutter/material.dart';

import '../app.dart';
import '../core/geo.dart';
import '../map/hudud_map.dart';
import 'start_run.dart';

/// Pro: every route ever run, on one map.
class AllRoutesScreen extends StatefulWidget {
  const AllRoutesScreen({super.key});

  @override
  State<AllRoutesScreen> createState() => _AllRoutesScreenState();
}

class _AllRoutesScreenState extends State<AllRoutesScreen> {
  final _map = HududMapController();
  List<List<GeoPoint>>? _stretches;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = AppScope.read(context).store;
    final all = <List<GeoPoint>>[];
    for (final r in store.runs) {
      final route = await store.route(r.id);
      if (route != null) all.addAll(route.stretches);
    }
    if (mounted) setState(() => _stretches = all);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final stretches = _stretches;
    final points = [for (final st in stretches ?? const <List<GeoPoint>>[]) ...st];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(s.allRoutes), backgroundColor: Colors.transparent),
      body: stretches == null
          ? const Center(child: CircularProgressIndicator())
          : HududMap(
              theme: app.mapTheme,
              center: points.isEmpty ? fallbackCenter : points.first,
              zoom: 13,
              tilt: 0,
              controller: _map,
              territory: app.store.territory.shapes,
              territoryVersion: app.store.territory.length,
              color: app.skin,
              route: stretches,
              routeVersion: stretches.length,
              onReady: () => points.isEmpty ? null : _map.fit(points, padding: const EdgeInsets.all(60)),
            ),
    );
  }
}
