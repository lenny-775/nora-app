import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/nora_logo.dart'; // Import du logo
import 'edit_profile_page.dart'; // Assure-toi d'avoir cette page pour l'action "Modifier"
import 'welcome_page.dart';
import 'post_details_page.dart';
import 'search_page.dart'; // Import pour la loupe

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  late TabController _tabController;
  final String _myId = Supabase.instance.client.auth.currentUser!.id;

  // COULEURS V3
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _darkText = const Color(0xFF2D3436);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await Supabase.instance.client.from('profiles').select().eq('id', _myId).single();
      if (mounted) setState(() { _profileData = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomePage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFFFFF8F5), body: Center(child: CircularProgressIndicator(color: Color(0xFFFF914D))));
    if (_profileData == null) return const Scaffold(body: Center(child: Text("Erreur profil")));

    final String fullName = _profileData!['first_name'] ?? "Utilisateur";
    final String? bio = _profileData!['bio'];
    final String? avatarUrl = _profileData!['avatar_url'];
    final String city = _profileData!['city'] ?? "Monde";
    final String status = _profileData!['status'] ?? "Nouveau";
    List<String> goals = [];
    if (_profileData!['looking_for'] != null && _profileData!['looking_for'].isNotEmpty) {
      goals = (_profileData!['looking_for'] as String).split(', ');
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      
      // --- APP BAR V3 (LOUPE + LOGO) ---
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
        // 1. LOUPE À GAUCHE
        leading: IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.black, size: 28),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())),
        ),
        // 2. LOGO CENTRÉ (Taille adaptée)
        title: Hero(
          tag: 'nora-logo-hero',
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              height: 35, 
              width: 120, 
              child: FittedBox(
                fit: BoxFit.contain,
                child: const NoraLogo(size: 35),
              ),
            ),
          ),
        ),
        // 3. PARAMÈTRES À DROITE
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
               showModalBottomSheet(
                 context: context,
                 builder: (context) => Container(
                   padding: const EdgeInsets.all(20),
                   height: 150,
                   child: Column(
                     children: [
                       ListTile(
                         leading: const Icon(Icons.logout, color: Colors.red),
                         title: const Text("Se déconnecter", style: TextStyle(color: Colors.red)),
                         onTap: _signOut,
                       )
                     ],
                   ),
                 )
               );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),

      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // AVATAR
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _creamyOrange, width: 2)),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? Icon(Icons.person, size: 50, color: Colors.grey.shade400) : null,
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // NOM
                  Text(fullName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _darkText)),
                  const SizedBox(height: 5),
                  
                  // TAGS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTag(city, Icons.location_on, Colors.blue.shade100, Colors.blue.shade800),
                      const SizedBox(width: 8),
                      _buildTag(status, Icons.star, Colors.orange.shade100, Colors.orange.shade800),
                    ],
                  ),
                  
                  // BIO
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Text(bio, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, height: 1.4)),
                  ],

                  // GOALS
                  if (goals.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: goals.map((g) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                        child: Text(g, style: const TextStyle(fontSize: 11)),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),
                  
                  // BOUTON EDIT
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        // Navigation vers la page d'édition (que tu as nommée EditProfilePage ailleurs)
                        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                        if (result == true) _loadProfile();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _darkText),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 10)
                      ),
                      child: Text("Modifier le profil", style: TextStyle(color: _darkText, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // BARRE D'ONGLETS
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: _creamyOrange,
                labelColor: _creamyOrange,
                unselectedLabelColor: Colors.grey,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: const [
                  Tab(text: "Mes Posts"),
                  Tab(text: "Favoris"),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostGrid('user_id', _myId, "Tu n'as rien posté."),
            _buildSavedPostsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, IconData icon, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textCol),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  // GRILLE MES POSTS
  Widget _buildPostGrid(String column, String value, String emptyMsg) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('posts').stream(primaryKey: ['id']).eq(column, value).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
        final posts = snapshot.data!;
        if (posts.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.dashboard_outlined, size: 40, color: Colors.grey.shade300), const SizedBox(height: 10), Text(emptyMsg, style: TextStyle(color: Colors.grey.shade500))]));

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: _profileData!['first_name'], timeAgo: "Moi"))),
              child: Container(
                color: Colors.grey.shade100,
                child: post['image_url'] != null 
                  ? Image.network(post['image_url'], fit: BoxFit.cover)
                  : Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(post['content'] ?? "", maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)))),
              ),
            );
          },
        );
      },
    );
  }

  // GRILLE FAVORIS
  Widget _buildSavedPostsGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client.from('saved_posts').select('post_id, posts(*)').eq('user_id', _myId).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
        final savedItems = snapshot.data!;
        if (savedItems.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bookmark_border, size: 40, color: Colors.grey.shade300), const SizedBox(height: 10), Text("Aucun favori.", style: TextStyle(color: Colors.grey.shade500))]));

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: savedItems.length,
          itemBuilder: (context, index) {
            final post = savedItems[index]['posts'] as Map<String, dynamic>;
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: "Auteur", timeAgo: "..."))),
              child: Container(
                color: Colors.grey.shade100,
                child: post['image_url'] != null 
                  ? Image.network(post['image_url'], fit: BoxFit.cover)
                  : Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(post['content'] ?? "", maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)))),
              ),
            );
          },
        );
      },
    );
  }
}

// Classe utilitaire pour le Header Sticky
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: const Color(0xFFFFF8F5), child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}