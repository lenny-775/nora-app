import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'profile_page.dart';
import 'create_post_page.dart';
import 'conversations_page.dart'; 
import 'other_profile_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; 
  String _userCity = "Chargement...";
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('city')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _userCity = data['city'] ?? "Canada";
        });
      }
    }
  }

  Future<void> _updateCity(String newCity) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() => _userCity = newCity);
      await Supabase.instance.client
          .from('profiles')
          .update({'city': newCity})
          .eq('id', user.id);
    }
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cities.length,
            itemBuilder: (context, index) {
              final city = _cities[index];
              return ListTile(
                leading: const Icon(Icons.location_city, color: Color(0xFFFF6B00)),
                title: Text(city),
                trailing: city == _userCity ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  _updateCity(city);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  // --- LE FEED AVEC LES VRAIS PROFILS ET LE CLIC ---
  Widget _buildFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('posts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
        }

        final allPosts = snapshot.data!;
        // Filtre par ville
        final posts = allPosts.where((p) => p['city'] == _userCity).toList();

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 20),
                Text("Aucune publication à $_userCity", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            
            // Calcul du temps
            final createdAt = DateTime.tryParse(post['created_at'].toString()) ?? DateTime.now();
            final difference = DateTime.now().difference(createdAt);
            String timeAgo = "À l'instant";
            if (difference.inMinutes > 0) timeAgo = "${difference.inMinutes} min";
            if (difference.inHours > 0) timeAgo = "${difference.inHours} h";
            if (difference.inDays > 0) timeAgo = "${difference.inDays} j";

            // Likes
            int likesCount = 0;
            if (post['liked_by'] != null && post['liked_by'] is List) {
               likesCount = (post['liked_by'] as List).length;
            }

            // --- ICI : ON CHARGE LE PROFIL DE L'AUTEUR ---
            return FutureBuilder<Map<String, dynamic>>(
              // On va chercher dans 'profiles' la ligne qui correspond au user_id du post
              future: Supabase.instance.client
                  .from('profiles')
                  .select('first_name, avatar_url') 
                  .eq('id', post['user_id'])
                  .single(),
              builder: (context, profileSnapshot) {
                // Valeurs par défaut
                String name = "Chargement...";
                String? avatarUrl;

                if (profileSnapshot.hasData) {
                  name = profileSnapshot.data?['first_name'] ?? "Voyageur";
                  avatarUrl = profileSnapshot.data?['avatar_url'];
                }

                // --- MODIFICATION : RENDRE LE POST CLIQUABLE ---
                return GestureDetector(
                  onTap: () {
                    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
                    
                    // Si c'est MON post -> Je vais sur mon onglet Profil
                    if (post['user_id'] == currentUserId) {
                      setState(() {
                        _selectedIndex = 2; // Index de la page Profil
                      });
                    } 
                    // Si c'est le post d'un AUTRE -> Je vais sur sa page
                    else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OtherProfilePage(userId: post['user_id']),
                        ),
                      );
                    }
                  },
                  child: NoraPostCard(
                    userName: name,
                    avatarUrl: avatarUrl,
                    timeAgo: timeAgo,
                    content: post['content'] ?? "",
                    likes: likesCount,
                    comments: 0,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPostCreation() {
    return CreatePostPage(
      onPostSuccess: () => setState(() => _selectedIndex = 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Liste des pages
    final List<Widget> pages = [
      _buildFeed(),         
      _buildPostCreation(), 
      const ProfilePage(), // J'ai enlevé le 'const' ici pour éviter les erreurs si la classe change
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: _selectedIndex == 0 ? AppBar(
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: _showCityPicker,
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Color(0xFFFF6B00)),
              const SizedBox(width: 8),
              Text(_userCity, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
              const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
            ],
          ),
        ),
        // BOUTON CHAT
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConversationsPage()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ) : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFFF6B00),
          unselectedItemColor: Colors.grey.shade400,
          showUnselectedLabels: false,
          showSelectedLabels: false,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 28), activeIcon: Icon(Icons.home_filled, size: 28), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline, size: 32), activeIcon: Icon(Icons.add_circle, size: 32), label: "Post"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 28), activeIcon: Icon(Icons.person, size: 28), label: "Profil"),
          ],
        ),
      ),
    );
  }
}