import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';

class CreatePostPage extends StatefulWidget {
  final VoidCallback? onPostSuccess;

  const CreatePostPage({super.key, this.onPostSuccess});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  String _selectedType = 'Message';
  String _selectedCity = 'Montréal';
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;

  final List<String> _cities = ['Montréal', 'Toronto', 'Vancouver', 'Calgary', 'Québec', 'Ottawa'];

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // --- ADAPTATION À TA BASE DE DONNÉES ---
        await Supabase.instance.client.from('posts').insert({
          'user_id': user.id,
          'content': content,
          'city': _selectedCity,
          'tag': _selectedType, // CORRECTION : On utilise 'tag' au lieu de 'type'
          // On n'envoie PAS 'likes' car la colonne n'existe pas.
          // On laisse 'liked_by' et 'author' prendre leurs valeurs par défaut (NULL ou vide).
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post publié ! 🚀"), backgroundColor: Colors.green));
          _contentController.clear();
          if (widget.onPostSuccess != null) widget.onPostSuccess!();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- WIDGETS DE DESIGN (Identique à avant) ---
  Widget _buildTypeCard(String label, IconData icon, Color mainColor, Color bgColor) {
    final bool isSelected = _selectedType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: isSelected ? mainColor : bgColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
            boxShadow: isSelected ? [BoxShadow(color: mainColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))] : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityChip(String city) {
    final bool isSelected = _selectedCity == city;
    return GestureDetector(
      onTap: () => setState(() => _selectedCity = city),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFDAB9) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? const Color(0xFFFF6B00) : Colors.transparent, width: 2),
          boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? Icons.location_on : Icons.location_on_outlined, size: 16, color: isSelected ? const Color(0xFFFF6B00) : Colors.grey),
            const SizedBox(width: 8),
            Text(city, style: TextStyle(color: isSelected ? const Color(0xFFFF6B00) : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Publier", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
              const Text("Partage avec la communauté", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 30),

              const Text("Type de publication", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),
              Row(
                children: [
                  _buildTypeCard("Message", Icons.chat_bubble_outline, const Color(0xFFFF9800), const Color(0xFFFFCC80)),
                  _buildTypeCard("Logement", Icons.home_filled, const Color(0xFFF06292), const Color(0xFFF8BBD0)),
                  _buildTypeCard("Emploi", Icons.work, const Color(0xFFFFAB91), const Color(0xFFFFCCBC)),
                ],
              ),

              const SizedBox(height: 30),

              const Text("Ville concernée", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _cities.map((city) => _buildCityChip(city)).toList(),
              ),

              const SizedBox(height: 30),

              const Text("Ton message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),
              Container(
                height: 180,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  maxLength: 500,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: "Écris ton message ici...",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    counterText: "",
                  ),
                ),
              ),
              
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ValueListenableBuilder(
                    valueListenable: _contentController,
                    builder: (context, value, child) => Text(
                      "${value.text.length} / 500",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              NoraButton(
                text: "Publier",
                isLoading: _isLoading,
                onPressed: _submitPost,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}