import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'other_profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  // Fonction de recherche
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Recherche 'ilike' (insensible à la casse) dans la colonne 'first_name'
      final results = await Supabase.instance.client
          .from('profiles')
          .select()
          .ilike('first_name', '%$query%') // Le % permet de chercher "partout" dans le nom
          .limit(20);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(results);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5), // Même fond que le reste
      body: Stack(
        children: [
          // 1. LES RÉSULTATS (En dessous de la barre)
          ListView.builder(
            padding: const EdgeInsets.only(top: 120, left: 20, right: 20), // On laisse de la place en haut
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(user['avatar_url'] ?? "https://i.pravatar.cc/300"),
                  ),
                  title: Text(
                    user['first_name'] ?? "Utilisateur", 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text("${user['status'] ?? 'Membre'} • ${user['city'] ?? 'Canada'}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    // Clic -> Profil de l'autre
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => OtherProfilePage(userId: user['id'])),
                    );
                  },
                ),
              );
            },
          ),

          // 2. LA BARRE DE RECHERCHE "LIQUID GLASS" (Flottante en haut)
          Positioned(
            top: 50, // Marge du haut (SafeArea)
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Flou
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6), // Semi-transparent
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true, // Ouvre le clavier direct
                          onChanged: _performSearch, // Recherche quand on tape
                          decoration: const InputDecoration(
                            hintText: "Rechercher un PVTiste...",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                             Navigator.pop(context); // Fermer la recherche
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}