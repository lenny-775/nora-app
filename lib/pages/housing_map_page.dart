import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Le moteur de carte
import 'package:latlong2/latlong.dart'; // Pour gérer les coordonnées GPS

class HousingMapPage extends StatefulWidget {
  final Map<String, dynamic> post; // On reçoit tout le post (avec lat/lng/adresse)

  const HousingMapPage({super.key, required this.post});

  @override
  State<HousingMapPage> createState() => _HousingMapPageState();
}

class _HousingMapPageState extends State<HousingMapPage> {
  // COULEURS V3
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _darkText = const Color(0xFF2D3436);

  @override
  Widget build(BuildContext context) {
    // 1. Récupération sécurisée des coordonnées
    final double lat = widget.post['latitude'] ?? 0.0;
    final double lng = widget.post['longitude'] ?? 0.0;
    final String address = widget.post['address'] ?? "Adresse inconnue";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Localisation", style: TextStyle(color: _darkText, fontWeight: FontWeight.w900)),
      ),
      body: Stack(
        children: [
          // LA CARTE OPENSTREETMAP
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng), // Centre sur le logement
              initialZoom: 15.0, // Zoom assez proche
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app', // Laisse comme ça ou mets ton package id
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Icon(Icons.location_on_rounded, color: _creamyOrange, size: 45),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // UNE PETITE CARTE D'INFO EN BAS
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _creamyOrange.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.home_rounded, color: _creamyOrange),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Logement situé à :", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(address, style: TextStyle(color: _darkText, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}