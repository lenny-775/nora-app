import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'profile_page.dart';
import 'create_post_page.dart';
import 'conversations_page.dart'; 
import 'post_details_page.dart';
import 'search_page.dart';
import 'chat_page.dart';
import 'welcome_page.dart';
import 'other_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; 
  String _userCity = "Montréal"; 
  
  String _selectedFilter = 'Tout';
  final List<String> _filters = ['Tout', '🏠 Logement', '💼 Emploi', '🍻 Sorties', '🆘 Entraide', '📢 Annonce'];
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadProfile();
  }

  Future<void> _checkAuthAndLoadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
         Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()), 
          (route) => false,
        );
      }
      return;
    }
    try {
      final data = await Supabase.instance.client.from('profiles').select('city').eq('id', user.id).maybeSingle();
      if (mounted && data != null && data['city'] != null) {
        setState(() => _userCity = data['city']);
      }
    } catch (e) {
      debugPrint("Erreur profil: $e");
    }
  }

  Future<void> _updateCity(String newCity) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() => _userCity = newCity);
      await Supabase.instance.client.from('profiles').update({'city': newCity}).eq('id', user.id);
    }
  }

  // --- LOGIQUE NOTIFICATIONS CORRIGÉE (FILTRAGE MANUEL) ---
  Widget _buildNotificationBadge() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Icon(Icons.chat_bubble_outline, color: Colors.black87);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('messages')
          .stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        int unreadTotal = 0;
        if (snapshot.hasData) {
          // On filtre manuellement pour éviter les erreurs de paramètres Null en SQL
          unreadTotal = snapshot.data!.where((m) => 
            m['read_at'] == null && m['sender_id'] != user.id
          ).length;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.chat_bubble_outline, color: Colors.black87, size: 26),
            if (unreadTotal > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    unreadTotal > 9 ? '9+' : '$unreadTotal',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    List<dynamic> likedBy = List.from(post['liked_by'] ?? []);
    setState(() {
      if (likedBy.contains(user.id)) {
        likedBy.remove(user.id);
      } else {
        likedBy.add(user.id);
      }
    });

    await Supabase.instance.client.from('posts').update({'liked_by': likedBy}).eq('id', post['id']);
  }

  Future<void> _toggleSavePost(int postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final existing = await Supabase.instance.client
          .from('saved_posts')
          .select()
          .eq('user_id', user.id)
          .eq('post_id', postId)
          .maybeSingle();

      if (existing == null) {
        await Supabase.instance.client.from('saved_posts').insert({
          'user_id': user.id,
          'post_id': postId,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post enregistré ! 🔖")));
      } else {
        await Supabase.instance.client
            .from('saved_posts')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', postId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Supprimé des favoris.")));
      }
    } catch (e) {
      debugPrint("Erreur favoris: $e");
    }
  }

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

  Future<void> _sendPostToUser(Map<String, dynamic> post, Map<String, dynamic> receiver) async {
    Navigator.pop(context); 
    final myId = Supabase.instance.client.auth.currentUser!.id;
    try {
      final existingConvId = await Supabase.instance.client.rpc('get_conversation_id', params: {'user1': myId, 'user2': receiver['id']});
      int conversationId;
      if (existingConvId != null) {
        conversationId = existingConvId;
      } else {
        final newConv = await Supabase.instance.client.from('conversations').insert({}).select().single();
        conversationId = newConv['id'];
        await Supabase.instance.client.from('conversation_participants').insert([{'conversation_id': conversationId, 'user_id': myId}, {'conversation_id': conversationId, 'user_id': receiver['id']}]);
      }
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(conversationId: conversationId, receiverId: receiver['id'], receiverName: receiver['first_name'] ?? "Utilisateur", pendingPost: post)));
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 2))]),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFFF6B00)),
                isExpanded: true, 
                style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                borderRadius: BorderRadius.circular(20),
                onChanged: (String? newValue) => setState(() => _selectedFilter = newValue!),
                items: _filters.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        if (value == 'Tout') const Icon(Icons.filter_list, size: 18, color: Colors.grey),
                        if (value == 'Tout') const SizedBox(width: 8),
                        Text(value),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('posts').stream(primaryKey: ['id']).order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
              final allPosts = snapshot.data!;
              var posts = allPosts.where((p) => p['city'] == _userCity).toList();
              if (_selectedFilter != 'Tout') posts = posts.where((p) => p['category'] == _selectedFilter).toList();

              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_none, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      Text("Aucun post trouvé", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 5, bottom: 100), 
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final createdAt = DateTime.tryParse(post['created_at'].toString()) ?? DateTime.now();
                  final difference = DateTime.now().difference(createdAt);
                  String timeAgo = difference.inMinutes < 60 ? "${difference.inMinutes} min" : difference.inHours < 24 ? "${difference.inHours} h" : "${difference.inDays} j";
                  List<dynamic> likedBy = post['liked_by'] ?? [];
                  
                  return FutureBuilder<Map<String, dynamic>>(
                    future: Supabase.instance.client.from('profiles').select('first_name, avatar_url').eq('id', post['user_id']).single(),
                    builder: (context, profileSnapshot) {
                      String name = profileSnapshot.data?['first_name'] ?? "Voyageur";
                      String? avatarUrl = profileSnapshot.data?['avatar_url'];
                      return _buildCustomPostCard(
                        post: post, name: name, avatarUrl: avatarUrl, timeAgo: timeAgo,
                        isLiked: likedBy.contains(myId), likesCount: likedBy.length, myId: myId ?? '',
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomPostCard({
    required Map<String, dynamic> post, required String name, required String? avatarUrl, required String timeAgo,
    required bool isLiked, required int likesCount, required String myId,
  }) {
    bool isMyPost = post['user_id'] == myId;
    String category = post['category'] ?? 'Général';
    String? postImage = post['image_url'];
    int commentsCount = 0; 

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: name, timeAgo: timeAgo)));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (isMyPost) {
                  setState(() => _selectedIndex = 2);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: post['user_id'])));
                }
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            Text(timeAgo, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.circle, size: 4, color: Colors.grey.shade300)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFFF6B00).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text(category, style: const TextStyle(fontSize: 10, color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isMyPost)
                    IconButton(icon: const Icon(Icons.more_horiz, color: Colors.grey), onPressed: () {})
                  else
                    IconButton(
                      icon: const Icon(Icons.bookmark_border, color: Colors.grey), 
                      onPressed: () => _toggleSavePost(post['id']),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            Text(post['content'] ?? "", style: const TextStyle(fontSize: 15, height: 1.4)),
            if (postImage != null && postImage.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 12), child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(postImage, fit: BoxFit.cover, width: double.infinity))),
            
            const SizedBox(height: 15),
            const Divider(height: 1, color: Color(0xFFEEEEEE)), 
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLike(post),
                      child: Row(
                        children: [
                          Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey, size: 22),
                          const SizedBox(width: 5),
                          if (likesCount > 0) Text("$likesCount", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
                        const SizedBox(width: 5),
                        Text("$commentsCount", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  constraints: const BoxConstraints(), 
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.send_outlined, color: Colors.grey), 
                  onPressed: () => _sharePost(post)
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: name, timeAgo: timeAgo)));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F8), 
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Text(
                      "Ajouter un commentaire...",
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_selectedIndex == 2) return AppBar(backgroundColor: Colors.transparent, elevation: 0);
    return AppBar(
      backgroundColor: const Color(0xFFFFF8F5), elevation: 0, automaticallyImplyLeading: false, titleSpacing: 10, 
      title: Row(
        children: [
          GestureDetector(
            onTap: _showCityPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Row(children: [const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 18), const SizedBox(width: 5), Text(_userCity, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold))]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())), child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white), boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.05), blurRadius: 10)]), child: Row(children: [Icon(Icons.search, color: Colors.grey.shade400, size: 20), const SizedBox(width: 10), Text("Chercher un pvtiste...", style: TextStyle(color: Colors.grey.shade400, fontSize: 14))])))),
        ],
      ),
      actions: [
        IconButton(
          icon: _buildNotificationBadge(),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConversationsPage())),
        ), 
        const SizedBox(width: 10)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5), extendBody: true, appBar: _buildAppBar(),
      body: [ _buildFeed(), const SizedBox(), const ProfilePage()][_selectedIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 30), height: 70,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(35), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))], border: Border.all(color: Colors.white, width: 1)),
        child: ClipRRect(borderRadius: BorderRadius.circular(35), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _buildAnimatedNavItem(0, Icons.home_outlined, Icons.home_filled),
          GestureDetector(
            onTap: () async {
              if (await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage())) == true) setState(() {});
            },
            child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFF6B00), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]), child: const Icon(Icons.add, color: Colors.white, size: 28)),
          ),
          _buildAnimatedNavItem(2, Icons.person_outline, Icons.person),
        ]))),
      ),
    );
  }

  Widget _buildAnimatedNavItem(int index, IconData iconOff, IconData iconOn) {
    return GestureDetector(onTap: () => setState(() => _selectedIndex = index), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(10), child: Icon(_selectedIndex == index ? iconOn : iconOff, color: _selectedIndex == index ? const Color(0xFFFF6B00) : Colors.grey.shade400, size: 28)));
  }
}