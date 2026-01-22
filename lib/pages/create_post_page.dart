import 'dart:io';
import 'dart:convert'; // Pour décoder la réponse de Mapbox
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // Pour appeler Mapbox
import 'package:flutter_typeahead/flutter_typeahead.dart'; // Pour la liste déroulante

class CreatePostPage extends StatefulWidget {
  final Map<String, dynamic>? postToEdit;

  const CreatePostPage({super.key, this.postToEdit});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  final _addressController = TextEditingController(); // Sert pour l'affichage
  final _postalCodeController = TextEditingController();
  
  bool _isLoading = false;
  
  String? _selectedCity;
  String _selectedCategory = 'Général';
  
  XFile? _newImageFile;
  String? _existingImageUrl;

  // ✅ VARIABLES POUR LE GPS (Directement issues de la sélection)
  double? _selectedLat;
  double? _selectedLng;

  // 🔑 TON TOKEN MAPBOX (C'est lui qui fait la magie)
  final String _mapboxAccessToken = 'pk.eyJ1IjoibGVubnk3NzUiLCJhIjoiY21rcGs2dzd0MGYwbDNrczkycGd5N3kydyJ9.p5OApkqxbLW6ZP3JriBoGw';

  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _categories = ['Général', '🏠 Logement', '💼 Emploi', '🍻 Sorties', '🆘 Entraide', '📢 Annonce'];

  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _darkText = const Color(0xFF2D3436);
  final Color _backgroundColor = const Color(0xFFFFF8F5);

  @override
  void initState() {
    super.initState();
    if (widget.postToEdit != null) {
      final post = widget.postToEdit!;
      _contentController.text = post['content'] ?? '';
      _addressController.text = post['address'] ?? '';
      _postalCodeController.text = post['postal_code'] ?? '';
      
      if (_cities.contains(post['city'])) {
        _selectedCity = post['city'];
      }
      if (_categories.contains(post['category'])) {
        _selectedCategory = post['category'];
      }
      _existingImageUrl = post['image_url'];
      _selectedLat = post['latitude'];
      _selectedLng = post['longitude'];
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _newImageFile = image);
    }
  }

  // 🔥 FONCTION MAGIQUE : Elle interroge Mapbox quand tu tapes
  Future<List<Map<String, dynamic>>> _getAddressSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    // On limite la recherche au Canada (country=ca) pour éviter des résultats en France ou ailleurs
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$_mapboxAccessToken&country=ca&types=address,poi&limit=5'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // On transforme le JSON horrible en une liste propre
        return List<Map<String, dynamic>>.from(data['features']);
      }
    } catch (e) {
      debugPrint("Erreur Mapbox: $e");
    }
    return [];
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    final address = _addressController.text.trim();
    
    if (content.isEmpty && _newImageFile == null && _existingImageUrl == null) return;
    
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis une ville !')));
      return;
    }

    if (_selectedCategory == '🏠 Logement') {
      if (address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L\'adresse est requise pour un logement.')));
        return;
      }
      // On vérifie si on a bien le GPS (grâce à l'autocomplétion ou l'édition)
      if (_selectedLat == null || _selectedLng == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sélectionne une adresse dans la liste déroulante pour qu'on puisse la localiser !"), backgroundColor: Colors.orange));
         return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      String? finalImageUrl = _existingImageUrl;

      // 1. Upload Image
      if (_newImageFile != null) {
        final bytes = await _newImageFile!.readAsBytes();
        final fileExt = _newImageFile!.path.split('.').last;
        final fileName = '${user!.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await Supabase.instance.client.storage
            .from('posts')
            .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: _newImageFile!.mimeType));

        finalImageUrl = Supabase.instance.client.storage
            .from('posts')
            .getPublicUrl(fileName);
      }

      // 2. Sauvegarde (On a déjà le GPS, pas besoin de le calculer !)
      final dataToSave = {
        'content': content,
        'city': _selectedCity,
        'category': _selectedCategory,
        'image_url': finalImageUrl,
        'address': (_selectedCategory == '🏠 Logement') ? address : null,
        'postal_code': (_selectedCategory == '🏠 Logement') ? _postalCodeController.text : null,
        // ✅ On utilise directement les coordonnées récupérées par l'autocomplétion
        'latitude': (_selectedCategory == '🏠 Logement') ? _selectedLat : null,
        'longitude': (_selectedCategory == '🏠 Logement') ? _selectedLng : null,
      };

      if (widget.postToEdit != null) {
        await Supabase.instance.client.from('posts').update(dataToSave).eq('id', widget.postToEdit!['id']);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post modifié ! ✅")));
      } else {
        dataToSave['user_id'] = user!.id;
        dataToSave['liked_by'] = [];
        await Supabase.instance.client.from('posts').insert(dataToSave);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post publié ! 🚀")));
      }

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHousing = _selectedCategory == '🏠 Logement';
    final isEditing = widget.postToEdit != null;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: _darkText, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEditing ? "Modifier" : "Nouveau Post", style: TextStyle(color: _darkText, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20, top: 10, bottom: 10),
            child: SizedBox(
              width: 90,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _creamyOrange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: EdgeInsets.zero,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : Text(isEditing ? "Sauver" : "Publier", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          )
        ],
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 5))]),
              child: TextField(
                controller: _contentController,
                maxLines: 8,
                style: TextStyle(fontSize: 16, color: _darkText, height: 1.5),
                decoration: InputDecoration(
                  hintText: isHousing ? "Décris le logement..." : "Quoi de neuf ?",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                  border: InputBorder.none,
                ),
              ),
            ),
            
            const SizedBox(height: 25),

            if (_newImageFile != null) ...[
              _buildImagePreview(FileImage(File(_newImageFile!.path)), true)
            ] else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) ...[
              _buildImagePreview(NetworkImage(_existingImageUrl!), true)
            ],

            const Text("Détails", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 15),

            _buildPillDropdown(value: _selectedCity, hint: "Choisir la ville", icon: Icons.location_on_rounded, items: _cities, onChanged: (v) => setState(() => _selectedCity = v)),
            _buildPillDropdown(value: _selectedCategory, hint: "Catégorie", icon: Icons.category_rounded, items: _categories, onChanged: (v) => setState(() => _selectedCategory = v!)),

            if (isHousing) ...[
              const SizedBox(height: 5),
              
              // 🔥 LE CHAMP D'ADRESSE INTELLIGENT (TypeAhead)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(30), 
                  boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))], 
                  border: Border.all(color: _creamyOrange.withOpacity(0.3), width: 1)
                ),
                child: TypeAheadField<Map<String, dynamic>>(
                  controller: _addressController,
                  suggestionsCallback: _getAddressSuggestions, // Appelle Mapbox
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: TextStyle(color: _darkText, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: "Chercher l'adresse (ex: 1130 Yonge...)",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(Icons.search_rounded, color: _creamyOrange, size: 22)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20)
                      ),
                    );
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.grey),
                      title: Text(suggestion['place_name'] ?? "Adresse inconnue", style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                  onSelected: (suggestion) {
                    // ✅ C'est ici que la magie opère !
                    _addressController.text = suggestion['place_name']; // Remplit le texte
                    
                    // On extrait le GPS donné par Mapbox
                    List coords = suggestion['geometry']['coordinates']; // [long, lat]
                    setState(() {
                      _selectedLng = coords[0];
                      _selectedLat = coords[1];
                    });
                    
                    // Petit feedback visuel
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Adresse trouvée ! 📍"), 
                      duration: const Duration(milliseconds: 800),
                      backgroundColor: Colors.green
                    ));
                  },
                ),
              ),
              
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))], border: Border.all(color: _creamyOrange.withOpacity(0.3), width: 1)),
                child: TextField(
                  controller: _postalCodeController, 
                  style: TextStyle(color: _darkText, fontWeight: FontWeight.w600), 
                  decoration: InputDecoration(
                    hintText: "Complément (Appt, Code postal...)", 
                    hintStyle: TextStyle(color: Colors.grey.shade400), 
                    prefixIcon: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(Icons.markunread_mailbox_rounded, color: _creamyOrange, size: 22)), 
                    border: InputBorder.none, 
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20)
                  )
                ),
              ),
            ],

            const SizedBox(height: 10),

            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: _creamyOrange.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, color: _creamyOrange),
                    const SizedBox(width: 10),
                    Text(
                      (_newImageFile == null && _existingImageUrl == null) ? "Ajouter une photo" : "Changer la photo", 
                      style: TextStyle(color: _creamyOrange, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30), 
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(ImageProvider imageProvider, bool showDelete) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 25),
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 5))]
          ),
        ),
        if (showDelete)
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _newImageFile = null;
                  _existingImageUrl = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPillDropdown({required String? value, required String hint, required IconData icon, required List<String> items, required Function(String?) onChanged}) {
    return Container(margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))]), child: DropdownButtonFormField<String>(value: value, icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400), isExpanded: true, style: TextStyle(color: _darkText, fontWeight: FontWeight.w600, fontSize: 16), dropdownColor: Colors.white, borderRadius: BorderRadius.circular(20), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400), prefixIcon: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(icon, color: Colors.grey.shade400, size: 22)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _creamyOrange, width: 1.5))), items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: onChanged));
  }
}