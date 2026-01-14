import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';
import 'post_details_page.dart';
import 'conversations_page.dart';
import 'search_page.dart';
import 'other_profile_page.dart'; // NOUVEAU : Import nécessaire pour la navigation

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = Supabase.instance.client.auth.currentUser;
  
  int _selectedIndex = 0;
  String _currentViewCity = 'Montréal';

  final List<String> _cities = [
    'Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 
    'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'
  ];

  String _selectedFilter = 'Tout';
  final List<String> _filterOptions = ['Tout', 'Général', 'Job', 'Logement', 'Sortie', 'Aide'];

  final _postContentController = TextEditingController();
  String _selectedTag = 'Général';
  final List<String> _tagOptions = ['Général', 'Job', 'Logement', 'Sortie', 'Aide'];

  @override
  void initState() {
    super.initState();
    _currentViewCity = user?.userMetadata?['city'] ?? 'Montréal';
    if (!_cities.contains(_currentViewCity)) {
       _currentViewCity = 'Montréal';
    }
  }

  // --- LOGIQUE DES POSTS ---
  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final userId = user!.id;
    List<dynamic> likedBy = (post['liked_by'] as List<dynamic>?) ?? [];
    
    if (likedBy.contains(userId)) { 
      likedBy.remove(userId); 
    } else { 
      likedBy.add(userId); 
    }
    
    try { 
      await Supabase.instance.client.from('posts').update({'liked_by': likedBy}).eq('id', post['id']); 
    } catch (e) {
      // Erreur silencieuse
    }
  }

  Future<void> _deletePost(int postId) async {
    try { await Supabase.instance.client.from('posts').delete().eq('id', postId); } catch (e) {}
  }

  void _confirmDelete(int postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(onPressed: () { Navigator.pop(context); _deletePost(postId); }, child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _createPost() async {
    final content = _postContentController.text.trim();
    if (content.isEmpty) return;
    final authorName = user?.userMetadata?['first_name'] ?? user?.email?.split('@')[0] ?? 'Anonyme';
    try {
      await Supabase.instance.client.from('posts').insert({
        'content': content,
        'city': _currentViewCity,
        'tag': _selectedTag,
        'author': authorName,
        'user_id': user!.id,
        'liked_by': [],
      });
      if (mounted) { Navigator.pop(context); _postContentController.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post publié !'))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'envoi.'))); }
  }

  void _showAddPostDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Nouveau post à $_currentViewCity'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: _postContentController, decoration: const InputDecoration(hintText: 'Quoi de neuf ?', border: OutlineInputBorder()), maxLines: 3),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(value: _selectedTag, decoration: const InputDecoration(labelText: 'Catégorie'), items: _tagOptions.map((tag) => DropdownMenuItem(value: tag, child: Text(tag))).toList(), onChanged: (val) => setDialogState(() => _selectedTag = val!)),
                ],
              ),
              actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), ElevatedButton(onPressed: _createPost, child: const Text('Publier')) ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "Récemment";
    try {
      final date = DateTime.parse(dateString);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
      if (diff.inHours < 24) return "Il y a ${diff.inHours} h";
      return "${date.day}/${date.month}";
    } catch (e) { return "Récemment"; }
  }

  Color _getTagColor(String? tag) {
    if (tag == null) return Colors.blue.shade100;
    switch (tag.toLowerCase()) {
      case 'job': return Colors.green.shade100;
      case 'logement': return Colors.orange.shade100;
      case 'sortie': return Colors.purple.shade100;
      case 'aide': return Colors.red.shade100;
      default: return Colors.blue.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget feedScreen = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Fil d'actualité", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.blueAccent), const SizedBox(width: 4), Text(_currentViewCity, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12))]),
              )
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _filterOptions.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(padding: const EdgeInsets.only(right: 8.0), child: ChoiceChip(label: Text(filter), selected: isSelected, selectedColor: Colors.blueAccent, labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), backgroundColor: Colors.white, onSelected: (bool selected) { if (selected) setState(() => _selectedFilter = filter); }));
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('posts').stream(primaryKey: ['id']).eq('city', _currentViewCity).order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final allPosts = snapshot.data!;
              final filteredPosts = _selectedFilter == 'Tout' ? allPosts : allPosts.where((post) => post['tag'] == _selectedFilter).toList();
              
              if (filteredPosts.isEmpty) return const Center(child: Text("Aucun post pour le moment."));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredPosts.length,
                itemBuilder: (context, index) {
                  final post = filteredPosts[index];

                  // Données sécurisées
                  final String authorName = post['author'] as String? ?? 'Anonyme';
                  final String authorInitial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';
                  final String? createdAt = post['created_at'] as String?;
                  final String tag = post['tag'] as String? ?? 'Général';
                  final String content = post['content'] as String? ?? '';
                  final List<dynamic> likedBy = (post['liked_by'] as List<dynamic>?) ?? [];
                  final String? postUserId = post['user_id'] as String?;
                  
                  final bool isLiked = likedBy.contains(user!.id);
                  final int likeCount = likedBy.length;
                  final bool isMyPost = postUserId == user!.id;

                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post))),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // EN-TÊTE DU POST (AVATAR + NOM + DATE + POUBELLE)
                            Row(
                              children: [
                                // --- PARTIE CLIQUABLE (Avatar + Nom) ---
                                GestureDetector(
                                  onTap: () {
                                    // Navigation vers le profil de l'auteur
                                    if (postUserId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => OtherProfilePage(userId: postUserId),
                                        ),
                                      );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18, 
                                        backgroundColor: Colors.blueGrey.shade100, 
                                        child: Text(authorInitial, style: const TextStyle(color: Colors.black87))
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start, 
                                        children: [
                                          Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold)), 
                                          Text(_formatDate(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12))
                                        ]
                                      ),
                                    ],
                                  ),
                                ),
                                // ---------------------------------------

                                const Spacer(),
                                if (isMyPost) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20), onPressed: () => _confirmDelete(post['id'])),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _getTagColor(tag), borderRadius: BorderRadius.circular(20)), child: Text(tag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            const SizedBox(height: 12),
                            Text(content, style: const TextStyle(fontSize: 15, height: 1.4)),
                            const SizedBox(height: 16),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(children: [Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey), SizedBox(width: 6), Text("Commenter", style: TextStyle(color: Colors.grey, fontSize: 14))]),
                                GestureDetector(onTap: () => _toggleLike(post), child: Row(children: [Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 20, color: isLiked ? Colors.redAccent : Colors.grey), const SizedBox(width: 6), Text(likeCount > 0 ? "$likeCount" : "J'aime", style: TextStyle(color: isLiked ? Colors.redAccent : Colors.grey, fontSize: 14, fontWeight: isLiked ? FontWeight.bold : FontWeight.normal))])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    final List<Widget> pages = [
      feedScreen,             // Index 0
      const ConversationsPage(), // Index 1
      const ProfilePage(),    // Index 2
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        drawer: Drawer(
          child: Column(
            children: [
              DrawerHeader(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)])), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.public, color: Colors.white, size: 40), const SizedBox(height: 10), const Text("Villes Canadiennes", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Text("Actuellement : $_currentViewCity", style: const TextStyle(color: Colors.white70))]))),
              Expanded(child: ListView.builder(padding: EdgeInsets.zero, itemCount: _cities.length, itemBuilder: (context, index) { final city = _cities[index]; return ListTile(leading: Icon(Icons.location_city, color: city == _currentViewCity ? Colors.blueAccent : Colors.grey), title: Text(city, style: TextStyle(color: city == _currentViewCity ? Colors.blueAccent : Colors.black, fontWeight: FontWeight.bold)), onTap: () { setState(() { _currentViewCity = city; _selectedFilter = 'Tout'; }); Navigator.pop(context); }); })),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black), 
          centerTitle: false,
          title: const Text('NORA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage()));
              },
            ),
          ],
        ),
        
        body: pages[_selectedIndex],

        floatingActionButton: _selectedIndex == 0
            ? FloatingActionButton(onPressed: _showAddPostDialog, backgroundColor: Colors.blueAccent, child: const Icon(Icons.add))
            : null,
            
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Accueil'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Messages'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}