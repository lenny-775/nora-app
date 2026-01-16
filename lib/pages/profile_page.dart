import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'edit_profile_page.dart';
import 'post_details_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  
  String _firstName = "";
  String _city = "";
  String _status = "";
  String? _avatarUrl;
  String _bio = "";
  List<String> _lookingFor = []; 

  List<Map<String, dynamic>> _myPosts = [];

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      final postsData = await Supabase.instance.client
          .from('posts')
          .select('*, profiles(first_name, avatar_url)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _firstName = data['first_name'] ?? "Voyageur";
          _city = data['city'] ?? "Inconnu";
          _status = data['status'] ?? "PVTiste";
          _avatarUrl = data['avatar_url'];
          _bio = data['bio'] ?? "";

          if (data['looking_for'] != null && (data['looking_for'] as String).isNotEmpty) {
            _lookingFor = (data['looking_for'] as String).split(', ');
          } else {
            _lookingFor = [];
          }

          _myPosts = List<Map<String, dynamic>>.from(postsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      setState(() => _isLoading = false);
    }
  }

  void _goToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
    if (result == true) {
      setState(() => _isLoading = true);
      _fetchProfileData();
    }
  }

  // --- BUILDER DES FAVORIS CORRIGÉ ---
  Widget _buildSavedPosts() {
    final myId = Supabase.instance.client.auth.currentUser!.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('saved_posts')
          .stream(primaryKey: ['id'])
          .eq('user_id', myId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final savedItems = snapshot.data!;

        if (savedItems.isEmpty) {
          return const Center(child: Text("Aucun post enregistré.", style: TextStyle(color: Colors.grey)));
        }

        final List<int> postIds = savedItems.map((s) => s['post_id'] as int).toList();

        return FutureBuilder<List<Map<String, dynamic>>>(
          // ✅ CORRECTION ICI : Utilisation de .inFilter au lieu de .in_
          future: Supabase.instance.client
              .from('posts')
              .select('*, profiles(first_name, avatar_url)')
              .inFilter('id', postIds), 
          builder: (context, postSnap) {
            if (!postSnap.hasData) return const Center(child: CircularProgressIndicator());
            final posts = postSnap.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return _buildMiniPostCard(posts[index]);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F5),
        appBar: AppBar(
          title: const Text("Mon Profil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
              },
            )
          ],
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : RefreshIndicator(
              onRefresh: _fetchProfileData,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // --- EN-TÊTE ---
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                                child: _avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _goToEditProfile,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Color(0xFFFF6B00), shape: BoxShape.circle),
                                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(_firstName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("📍 $_city  •  $_status", style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 20),

                          // --- BIO ---
                          if (_bio.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                              child: Text(_bio, style: const TextStyle(fontSize: 15, height: 1.4)),
                            ),

                          const SizedBox(height: 15),

                          // --- INTENTIONS ---
                          if (_lookingFor.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: _lookingFor.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B00).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3)),
                                ),
                                child: Text(tag, style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600, fontSize: 12)),
                              )).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: TabBar(
                      labelColor: Color(0xFFFF6B00),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFFFF6B00),
                      tabs: [
                        Tab(text: "Mes Posts"),
                        Tab(text: "Favoris 🔖"),
                      ],
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    // Onglet 1 : Mes Publications
                    ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: _myPosts.length,
                      itemBuilder: (context, index) => _buildMiniPostCard(_myPosts[index]),
                    ),
                    // Onglet 2 : Mes Favoris
                    _buildSavedPosts(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildMiniPostCard(Map<String, dynamic> post) {
    final String timeAgoString = _formatDate(post['created_at']);
    final String postName = post['profiles']?['first_name'] ?? _firstName;

    return GestureDetector(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => PostDetailsPage(
          post: post, 
          userName: postName,
          timeAgo: timeAgoString
        ))
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post['content'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 5),
                Text(timeAgoString, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              ],
            )
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes} min";
    if (diff.inHours < 24) return "${diff.inHours} h";
    return "${date.day}/${date.month}";
  }
}