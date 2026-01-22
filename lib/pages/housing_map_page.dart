import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

class HousingMapPage extends StatelessWidget {
  final Map<String, dynamic> post;

  const HousingMapPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    // Coordonnées du logement (avec sécurité)
    final double lat = post['latitude'] ?? 45.5017;
    final double lng = post['longitude'] ?? -73.5673;
    final Color _creamyOrange = const Color(0xFFFF914D);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Emplacement", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
             urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
             additionalOptions: const {
               'accessToken': 'pk.eyJ1IjoibGVubnk3NzUiLCJhIjoiY21rcGs2dzd0MGYwbDNrczkycGd5N3kydyJ9.p5OApkqxbLW6ZP3JriBoGw',
             },
             userAgentPackageName: 'com.nora.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 60,
                height: 60,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _creamyOrange, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
                      ),
                      child: Icon(Icons.home_rounded, color: _creamyOrange, size: 24),
                    ),
                    ClipPath(
                      clipper: _TriangleClipper(),
                      child: Container(color: _creamyOrange, width: 10, height: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}