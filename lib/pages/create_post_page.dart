import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  bool _isLoading = false;
  
  // Variables
  String? _selectedCity;
  String _selectedCategory = 'Général';
  XFile? _imageFile; 

  // Listes
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _categories = ['Général', '🏠 Logement', '💼 Emploi', '🍻 Sorties', '🆘 Entraide', '📢 Annonce'];

  // COULEURS DESIGN SYSTEM
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _darkText = const Color(0xFF2D3436);
  final Color _backgroundColor = const Color(0xFFFFF8F5);

  // Fonction Photo
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imageFile = image);
    }
  }

  // Fonction Submit
  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis une ville !')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      String? imageUrl;

      // 1. Upload Image
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${user!.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await Supabase.instance.client.storage
            .from('posts')
            .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: _imageFile!.mimeType));

        imageUrl = Supabase.instance.client.storage
            .from('posts')
            .getPublicUrl(fileName);
      }

      // 2. Insert Post (CORRECTION ICI)
      await Supabase.instance.client.from('posts').insert({
        'user_id': user!.id,
        'content': content,
        'city': _selectedCity,
        'category': _selectedCategory,
        'image_url': imageUrl,
        'liked_by': [], // <--- C'EST LA LIGNE QUI CHANGE TOUT !
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post publié ! 🚀")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor, // Fond Crème
      
      // --- APP BAR CLEAN ---
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: _darkText, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Nouveau Post", style: TextStyle(color: _darkText, fontWeight: FontWeight.w900, fontSize: 20)),
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
                  : const Text("Publier", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
            
            // 1. ZONE DE TEXTE (STYLE PAPIER)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200.withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: TextField(
                controller: _contentController,
                maxLines: 8,
                style: TextStyle(fontSize: 16, color: _darkText, height: 1.5),
                decoration: InputDecoration(
                  hintText: "Quoi de neuf ?\n(Cherche appart, job, potes...)",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                  border: InputBorder.none,
                ),
              ),
            ),
            
            const SizedBox(height: 25),

            // 2. PRÉVISUALISATION IMAGE
            if (_imageFile != null)
              Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 25),
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      image: DecorationImage(
                        image: FileImage(File(_imageFile!.path)),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 5))]
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),

            // 3. SELECTION VILLE & CATÉGORIE
            const Text("Détails", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 15),

            _buildPillDropdown(
              value: _selectedCity, 
              hint: "Choisir la ville", 
              icon: Icons.location_on_rounded, 
              items: _cities, 
              onChanged: (v) => setState(() => _selectedCity = v)
            ),
            
            _buildPillDropdown(
              value: _selectedCategory, 
              hint: "Catégorie", 
              icon: Icons.category_rounded, 
              items: _categories, 
              onChanged: (v) => setState(() => _selectedCategory = v!)
            ),

            const SizedBox(height: 10),

            // 4. BOUTON AJOUTER PHOTO
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _creamyOrange.withOpacity(0.5), width: 1.5), // Bordure orange légère
                  boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, color: _creamyOrange),
                    const SizedBox(width: 10),
                    Text(
                      _imageFile == null ? "Ajouter une photo" : "Changer la photo", 
                      style: TextStyle(color: _creamyOrange, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30), // Espace pour le bas
          ],
        ),
      ),
    );
  }

  // --- WIDGET DROPDOWN (RÉUTILISÉ DU SIGNUP) ---
  Widget _buildPillDropdown({required String? value, required String hint, required IconData icon, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), 
        boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
        isExpanded: true,
        style: TextStyle(color: _darkText, fontWeight: FontWeight.w600, fontSize: 16),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(20),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(icon, color: Colors.grey.shade400, size: 22)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          // Effet focus orange
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _creamyOrange, width: 1.5)),
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}