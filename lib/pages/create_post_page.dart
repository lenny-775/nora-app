import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'components.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  bool _isLoading = false;
  
  // Variables pour les nouveaux champs
  String? _selectedCity;
  String _selectedCategory = 'Général';
  XFile? _imageFile; // La photo sélectionnée

  // Listes d'options
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _categories = ['Général', '🏠 Logement', '💼 Emploi', '🍻 Sorties', '🆘 Entraide', '📢 Annonce'];

  // Fonction pour prendre une photo
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imageFile = image);
    }
  }

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

      // 1. Si y'a une image, on l'upload d'abord
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

      // 2. On crée le post avec toutes les infos
      await Supabase.instance.client.from('posts').insert({
        'user_id': user!.id,
        'content': content,
        'city': _selectedCity,
        'category': _selectedCategory,
        'image_url': imageUrl, // Peut être null, c'est pas grave
        'likes': 0,
      });

      if (mounted) {
        Navigator.pop(context, true); // On revient en arrière et on dit que c'est bon
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Nouveau Post", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: NoraButton(
              text: "Publier",
              isLoading: _isLoading,
              onPressed: _submitPost,
              width: 100,
              height: 40,
              fontSize: 14,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone de texte
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "Quoi de neuf ? (Cherche appart, job, potes...)",
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 18),
            ),
            
            const SizedBox(height: 20),
            
            // Prévisualisation de l'image si choisie
            if (_imageFile != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(_imageFile!.path, height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),
            const Divider(),
            
            // Options (Ville, Catégorie, Photo)
            ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFFFF6B00)),
              title: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCity,
                  hint: const Text("Choisir la ville"),
                  isExpanded: true,
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCity = v),
                ),
              ),
            ),
            
            ListTile(
              leading: const Icon(Icons.category, color: Color(0xFFFF6B00)),
              title: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFF6B00)),
              title: const Text("Ajouter une photo"),
              onTap: _pickImage,
            ),
          ],
        ),
      ),
    );
  }
}