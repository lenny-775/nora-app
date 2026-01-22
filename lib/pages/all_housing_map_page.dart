import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_details_page.dart'; 

class AllHousingMapPage extends StatefulWidget {
  final String city; 
  const AllHousingMapPage({super.key, required this.city});

  @override
  State<AllHousingMapPage> createState() => _AllHousingMapPageState();
}

class _AllHousingMapPageState extends State<AllHousingMapPage> {
  final Color _creamyOrange = const Color(0xFFFF914D);
  List<Map<String, dynamic>> _housingPosts = [];
  bool _isLoading = true;

  // 📍 COORDONNÉES DES VILLES
  final Map<String, LatLng> _cityCoordinates = {
    'Montréal': const LatLng(45.5017, -73.5673),
    'Québec': const LatLng(46.8139, -71.2080),
    'Toronto': const LatLng(43.6532, -79.3832),
    'Vancouver': const LatLng(49.2827, -123.1207),
    'Ottawa': const LatLng(45.4215, -75.6972),
    'Calgary': const LatLng(51.0447, -114.0719),
    'Edmonton': const LatLng(53.5461, -113.4938),
    'Winnipeg': const LatLng(49.8951, -97.1384),
    'Halifax': const LatLng(44.6488, -63.5752),
    'Victoria': const LatLng(48.4284, -123.3656),
  };

  @override
  void initState() {
    super.initState();
    _fetchAllHousing();
  }

  Future<void> _fetchAllHousing() async {
    try {
      final data = await Supabase.instance.client
          .from('posts')
          .select('*, profiles(first_name, avatar_url)') 
          .eq('category', '🏠 Logement')
          .not('latitude', 'is', null); 

      if (mounted) {
        setState(() {
          _housingPosts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur carte globale: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Centre selon la ville
    final LatLng startCenter = _cityCoordinates[widget.city] ?? const LatLng(45.5017, -73.5673);

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _creamyOrange))
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: startCenter,
                    initialZoom: 12.0, 
                    minZoom: 3, 
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
                      markers: _housingPosts.map((post) {
                        return Marker(
                          point: LatLng(post['latitude'], post['longitude']),
                          width: 60, 
                          height: 60,
                          child: GestureDetector(
                            onTap: () => _showPreviewDialog(post),
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
                        );
                      }).toList(),
                    ),
                  ],
                ),

                Positioned(
                  top: 50, 
                  left: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                        ]
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 22),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showPreviewDialog(Map<String, dynamic> post) {
    final author = post['profiles'] ?? {};
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                 CircleAvatar(radius: 20, backgroundImage: NetworkImage(author['avatar_url'] ?? "")),
                 const SizedBox(width: 10),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(author['first_name'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold)),
                       Text(post['address'] ?? "Adresse inconnue", style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                     ],
                   ),
                 ),
              ],
            ),
            const SizedBox(height: 10),
            Text(post['content'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _creamyOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: author['first_name'] ?? "User", timeAgo: "Récemment")));
                },
                child: const Text("Voir l'annonce", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
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