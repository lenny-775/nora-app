import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'edit_profile_page.dart';
import 'post_details_page.dart';
import 'welcome_page.dart'; 

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  
  // Données Profil
  String _firstName = "";
  String _city = "";
  String _status = "";
  String? _avatarUrl;
  String _bio = "";
  List<String> _lookingFor = []; 
  List<Map<String, dynamic>> _myPosts = [];

  // COULEURS DESIGN SYSTEM
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _darkText = const Color(0xFF2D3436);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _softGrey = const Color(0xFFF4F6F8);

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

  // --- NAVIGATION VERS PARAMÈTRES ---
  void _goToSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
  }

  // --- CONSTRUCTEUR DES FAVORIS ---
  Widget _buildSavedPosts() {
    final myId = Supabase.instance.client.auth.currentUser!.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('saved_posts')
          .stream(primaryKey: ['id'])
          .eq('user_id', myId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
        final savedItems = snapshot.data!;

        if (savedItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border_rounded, size: 50, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text("Aucun favori pour l'instant.", style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        final List<int> postIds = savedItems.map((s) => s['post_id'] as int).toList();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client
              .from('posts')
              .select('*, profiles(first_name, avatar_url)')
              .inFilter('id', postIds), 
          builder: (context, postSnap) {
            if (!postSnap.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
            final posts = postSnap.data!;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return _buildProfilePostCard(posts[index]);
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
        backgroundColor: _backgroundColor,
        
        // PAS D'APPBAR ICI (On utilise SafeArea pour ne pas taper dans l'encoche)
        
        body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: _creamyOrange))
          : SafeArea( // Protège le contenu du haut de l'écran
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: _creamyOrange,
                    onRefresh: _fetchProfileData,
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            child: Column(
                              children: [
                                // --- BOUTON PARAMÈTRES FLOTTANT ---
                                Align(
                                  alignment: Alignment.topRight,
                                  child: GestureDetector(
                                    onTap: _goToSettings,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))]
                                      ),
                                      child: Icon(Icons.settings_rounded, color: _darkText, size: 24),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10), // Espace après le bouton

                                // --- PHOTO DE PROFIL AVEC EFFET "GLOW" ---
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4), // Bordure blanche
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
                                      ),
                                      child: CircleAvatar(
                                        radius: 60,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                                        child: _avatarUrl == null ? Icon(Icons.person_rounded, size: 60, color: Colors.grey.shade400) : null,
                                      ),
                                    ),
                                    // Badge Édition
                                    GestureDetector(
                                      onTap: _goToEditProfile,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _darkText, 
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 3)
                                        ),
                                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                                      ),
                                    )
                                  ],
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // --- NOM & INFOS ---
                                Text(_firstName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _darkText)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 16, color: _creamyOrange),
                                    const SizedBox(width: 4),
                                    Text("$_city  •  $_status", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                
                                const SizedBox(height: 24),

                                // --- BIO (CARTE ARRONDIE) ---
                                if (_bio.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5))]
                                    ),
                                    child: Text(_bio, style: TextStyle(fontSize: 15, height: 1.5, color: _darkText), textAlign: TextAlign.center),
                                  ),

                                const SizedBox(height: 20),

                                // --- INTENTIONS (TAGS PASTEL) ---
                                if (_lookingFor.isNotEmpty)
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: _lookingFor.map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _creamyOrange.withOpacity(0.1), // Fond Pastel
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(tag, style: TextStyle(color: _creamyOrange, fontWeight: FontWeight.w700, fontSize: 13)),
                                    )).toList(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        // --- TAB BAR STYLÉE ---
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverAppBarDelegate(
                            TabBar(
                              labelColor: _darkText,
                              unselectedLabelColor: Colors.grey.shade400,
                              indicatorColor: _creamyOrange,
                              indicatorWeight: 3,
                              indicatorSize: TabBarIndicatorSize.label,
                              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              tabs: const [
                                Tab(text: "Mes Posts"),
                                Tab(text: "Favoris"),
                              ],
                            ),
                          ),
                        ),
                      ],
                      body: TabBarView(
                        children: [
                          // Onglet 1 : Mes Publications
                          _myPosts.isEmpty 
                            ? Center(child: Text("Tu n'as rien posté encore.", style: TextStyle(color: Colors.grey.shade500)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: _myPosts.length,
                                itemBuilder: (context, index) => _buildProfilePostCard(_myPosts[index]),
                              ),
                          // Onglet 2 : Mes Favoris
                          _buildSavedPosts(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  // --- CARTE DE POST (VERSION PROFIL COMPACTE) ---
  Widget _buildProfilePostCard(Map<String, dynamic> post) {
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25), // Arrondi style Home
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image en haut si existe
            if (post['image_url'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    height: 150, // Moins haut que la home
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: Image.network(post['image_url'], fit: BoxFit.cover),
                  ),
                ),
              ),
              
            Text(post['content'], maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, height: 1.5, color: _darkText)),
            const SizedBox(height: 12),
            
            // Footer discret
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: _creamyOrange),
                const SizedBox(width: 6),
                Text(timeAgoString, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _softGrey, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: _darkText),
                )
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

// --- CLASSE POUR LE HEADER QUI COLLE (STICKY) ---
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFFFF8F5), // Même couleur que le fond pour l'intégration
      child: _tabBar,
    );
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

// --- NOUVELLE PAGE DE PARAMÈTRES (SETTINGS) ---
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text("Paramètres", style: TextStyle(color: Color(0xFF2D3436), fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        leading: const BackButton(color: Color(0xFF2D3436)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildSettingTile(Icons.person_outline_rounded, "Compte", "Gérer mes infos personnelles"),
            _buildSettingTile(Icons.notifications_outlined, "Notifications", "Gérer mes alertes"),
            _buildSettingTile(Icons.lock_outline_rounded, "Confidentialité", "Mot de passe et sécurité"),
            _buildSettingTile(Icons.help_outline_rounded, "Aide & Support", "FAQ, Contact"),
            const SizedBox(height: 40),
            
            // Bouton Déconnexion
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("Se déconnecter", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            Text("Version 1.0.0", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFFFF8F5), shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFFFF914D)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        onTap: () {}, // À implémenter plus tard
      ),
    );
  }
}