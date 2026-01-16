import 'dart:ui'; // Nécessaire pour le flou (Glass)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'profile_page.dart';
import 'create_post_page.dart';
import 'conversations_page.dart'; 
import 'other_profile_page.dart'; 
import 'post_details_page.dart';
import 'search_page.dart';
import 'chat_page.dart'; // Pour la redirection

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

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    List<dynamic> likedBy = List.from(post['liked_by'] ?? []);
    
    if (likedBy.contains(user.id)) {
      likedBy.remove(user.id);
    } else {
      likedBy.add(user.id);
    }

    await Supabase.instance.client
        .from('posts')
        .update({'liked_by': likedBy})
        .eq('id', post['id']);
  }

  // --- 1. FONCTION DE PARTAGE (Ouvre la liste des gens) ---
  void _sharePost(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Partager à...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: Supabase.instance.client.from('profiles').select().neq('id', Supabase.instance.client.auth.currentUser!.id).limit(20),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final users = snapshot.data!;
                    
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ListTile(
                          leading: CircleAvatar(backgroundImage: NetworkImage(user['avatar_url'] ?? "https://i.pravatar.cc/300")),
                          title: Text(user['first_name'] ?? "Utilisateur"),
                          trailing: const Icon(Icons.send, color: Color(0xFFFF6B00)),
                          onTap: () => _sendPostToUser(post, user),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 2. FONCTION INTELLIGENTE (Trouve la discussion existante) ---
  Future<void> _sendPostToUser(Map<String, dynamic> post, Map<String, dynamic> receiver) async {
    Navigator.pop(context); // On ferme la liste
    final myId = Supabase.instance.client.auth.currentUser!.id;

    try {
      // ÉTAPE CLÉ : On cherche l'ID de la conversation EXISTANTE via la fonction SQL
      final existingConvId = await Supabase.instance.client.rpc('get_conversation_id', params: {
        'user1': myId, 
        'user2': receiver['id']
      });
      
      int conversationId;

      if (existingConvId != null) {
        // CAS A : La discussion existe déjà -> On la réutilise !
        conversationId = existingConvId;
      } else {
        // CAS B : C'est la première fois -> On crée une nouvelle
        final newConv = await Supabase.instance.client.from('conversations').insert({}).select().single();
        conversationId = newConv['id'];
        await Supabase.instance.client.from('conversation_participants').insert([
          {'conversation_id': conversationId, 'user_id': myId},
          {'conversation_id': conversationId, 'user_id': receiver['id']}
        ]);
      }

      // ÉTAPE FINALE : On va dans le Chat SANS envoyer le message tout de suite.
      // On passe le 'post' en paramètre pour qu'il s'affiche en prévisualisation.
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(
            conversationId: conversationId,
            receiverId: receiver['id'],
            receiverName: receiver['first_name'] ?? "Utilisateur",
            pendingPost: post, // <--- C'est ici que la magie opère
          )),
        );
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
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

  Widget _buildFeed() {
    final myId = Supabase.instance.client.auth.currentUser?.id;

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
          padding: const EdgeInsets.only(top: 10, bottom: 100), 
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            
            final createdAt = DateTime.tryParse(post['created_at'].toString()) ?? DateTime.now();
            final difference = DateTime.now().difference(createdAt);
            String timeAgo = "À l'instant";
            if (difference.inMinutes > 0) timeAgo = "${difference.inMinutes} min";
            if (difference.inHours > 0) timeAgo = "${difference.inHours} h";
            if (difference.inDays > 0) timeAgo = "${difference.inDays} j";

            List<dynamic> likedBy = post['liked_by'] ?? [];
            int likesCount = likedBy.length;
            bool isLikedByMe = likedBy.contains(myId);

            return FutureBuilder<Map<String, dynamic>>(
              future: Supabase.instance.client
                  .from('profiles')
                  .select('first_name, avatar_url') 
                  .eq('id', post['user_id'])
                  .single(),
              builder: (context, profileSnapshot) {
                String name = "Chargement...";
                String? avatarUrl;

                if (profileSnapshot.hasData) {
                  name = profileSnapshot.data?['first_name'] ?? "Voyageur";
                  avatarUrl = profileSnapshot.data?['avatar_url'];
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailsPage(
                          post: post,
                          userName: name,
                          avatarUrl: avatarUrl,
                          timeAgo: timeAgo,
                        ),
                      ),
                    );
                  },
                  child: NoraPostCard(
                    userName: name,
                    avatarUrl: avatarUrl,
                    timeAgo: timeAgo,
                    content: post['content'] ?? "",
                    likes: likesCount,
                    comments: 0,
                    isLiked: isLikedByMe,
                    onLike: () => _toggleLike(post),
                    onShare: () => _sharePost(post), // C'est ici !
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

  PreferredSizeWidget _buildAppBar() {
    if (_selectedIndex != 0) return AppBar(backgroundColor: const Color(0xFFFFF8F5), elevation: 0);

    return AppBar(
      backgroundColor: const Color(0xFFFFF8F5),
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 10, 
      title: Row(
        children: [
          GestureDetector(
            onTap: _showCityPicker,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: const Icon(Icons.map_outlined, color: Color(0xFFFF6B00), size: 24),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 15),
                    Icon(Icons.search, color: Colors.grey.shade400, size: 22),
                    const SizedBox(width: 10),
                    Text("Chercher un pvtiste...", style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.black54),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ConversationsPage()));
          },
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildFeed(),         
      _buildPostCreation(), 
      const ProfilePage(), 
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      extendBody: true, 
      appBar: _buildAppBar(),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 30), 
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85), 
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
          border: Border.all(color: Colors.white, width: 2), 
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAnimatedNavItem(0, Icons.home_outlined, Icons.home_filled),
                _buildAnimatedNavItem(1, Icons.add_circle_outline, Icons.add_circle),
                _buildAnimatedNavItem(2, Icons.person_outline, Icons.person),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedNavItem(int index, IconData iconOff, IconData iconOn) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint, 
        padding: isSelected ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12) : const EdgeInsets.all(12), 
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B00) : Colors.transparent, 
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(isSelected ? iconOn : iconOff, color: isSelected ? Colors.white : Colors.grey.shade400, size: 26),
      ),
    );
  }
}