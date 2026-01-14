import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'other_profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Recherche insensible à la casse (ilike) sur le prénom
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .ilike('first_name', '%$query%') // Le % permet de chercher "Len" dans "Lenny"
          .limit(20);

      setState(() {
        _results = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      // Gérer l'erreur silencieusement ou afficher un snackbar
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: TextField(
          controller: _searchController,
          autofocus: true, // Le clavier s'ouvre direct
          decoration: const InputDecoration(
            hintText: 'Rechercher un prénom...',
            border: InputBorder.none,
          ),
          onChanged: _searchUsers, // Recherche à chaque lettre tapée
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final user = _results[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                    child: user['avatar_url'] == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(user['first_name'] ?? 'Inconnu'),
                  subtitle: Text("${user['status'] ?? ''} • ${user['city'] ?? ''}"),
                  onTap: () {
                    // Clic sur un résultat -> Voir son profil
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OtherProfilePage(userId: user['id']),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}