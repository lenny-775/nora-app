import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/nora_logo.dart'; 
// import 'edit_profile_page.dart'; // Plus nécessaire ici, déplacé dans settings
import 'welcome_page.dart';
import 'post_details_page.dart';
import 'search_page.dart'; 
import 'other_profile_page.dart';
import 'notifications_page.dart'; 
import 'settings_page.dart';      

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

  // --- LOGIQUE NOTIFICATIONS (POPUP) ---
  void _showNotificationsPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75, 
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Notifications", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _darkText)),
                  IconButton(
                    icon: Icon(Icons.done_all_rounded, color: _creamyOrange),
                    tooltip: "Tout marquer comme lu",
                    onPressed: () async {
                      await Supabase.instance.client.from('notifications').update({'is_read': true}).eq('user_id', _myId);
                    },
                  )
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client.from('notifications').stream(primaryKey: ['id']).eq('user_id', _myId).order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
                  final notifs = snapshot.data!;
                  
                  if (notifs.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.notifications_off_outlined, size: 50, color: Colors.grey.shade300), const SizedBox(height: 10), Text("Aucune notification", style: TextStyle(color: Colors.grey.shade500))]));
                  }

                  return ListView.builder(
                    itemCount: notifs.length,
                    padding: const EdgeInsets.all(0),
                    itemBuilder: (context, index) {
                      final notif = notifs[index];
                      final bool isRead = notif['is_read'] ?? false;
                      final String type = notif['type'];

                      return FutureBuilder(
                        future: Future.wait([
                          Supabase.instance.client.from('profiles').select().eq('id', notif['actor_id']).single(),
                          Supabase.instance.client.from('posts').select().eq('id', notif['post_id']).maybeSingle(),
                        ]),
                        builder: (context, snap) {
                          if (!snap.hasData) return const SizedBox();
                          final actor = snap.data![0] as Map<String, dynamic>;
                          final post = snap.data![1] as Map<String, dynamic>?;

                          if (post == null) return const SizedBox(); 

                          return Container(
                            color: isRead ? Colors.white : _creamyOrange.withOpacity(0.08),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: actor['id']))),
                                child: CircleAvatar(backgroundImage: NetworkImage(actor['avatar_url'] ?? "https://i.pravatar.cc/150"), radius: 22),
                              ),
                              title: RichText(
                                text: TextSpan(style: TextStyle(color: _darkText, fontSize: 14), children: [
                                    TextSpan(text: actor['first_name'] ?? "Quelqu'un", style: const TextStyle(fontWeight: FontWeight.w800)),
                                    TextSpan(text: type == 'like' ? " a aimé ton post." : " a commenté : "),
                                    if (type == 'comment') TextSpan(text: "\"Post...\"", style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                                ]),
                              ),
                              subtitle: Text(_formatTime(notif['created_at']), style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
                              trailing: post['image_url'] != null 
                                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(post['image_url'], width: 40, height: 40, fit: BoxFit.cover)) 
                                : Icon(Icons.article_rounded, color: Colors.grey.shade300),
                              onTap: () {
                                Supabase.instance.client.from('notifications').update({'is_read': true}).eq('id', notif['id']);
                                Navigator.pop(context); 
                                Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: "Moi", timeAgo: "")));
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    final diff = DateTime.now().difference(DateTime.parse(dateStr).toLocal());
    if (diff.inMinutes < 60) return "${diff.inMinutes} min";
    if (diff.inHours < 24) return "${diff.inHours} h";
    return "${diff.inDays} j";
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
      
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
        
        // 1. CLOCHE NOTIFICATION
        leading: Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_rounded, color: Colors.black, size: 28),
              onPressed: _showNotificationsPopup, 
            ),
            Positioned(
              right: 12, top: 12,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client.from('notifications').stream(primaryKey: ['id']).eq('user_id', _myId),
                builder: (context, snapshot) {
                  bool hasUnread = false;
                  if (snapshot.hasData) hasUnread = snapshot.data!.any((n) => n['is_read'] == false);
                  if (hasUnread) return Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle));
                  return const SizedBox();
                },
              ),
            )
          ],
        ),

        title: Hero(
          tag: 'nora-logo-hero',
          child: Material(
            color: Colors.transparent,
            child: SizedBox(height: 35, width: 120, child: FittedBox(fit: BoxFit.contain, child: const NoraLogo(size: 35))),
          ),
        ),
        
        // 3. PARAMÈTRES
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
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
                  Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _creamyOrange, width: 2)), child: CircleAvatar(radius: 50, backgroundColor: Colors.grey.shade200, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? Icon(Icons.person, size: 50, color: Colors.grey.shade400) : null)),
                  const SizedBox(height: 15),
                  Text(fullName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _darkText)),
                  const SizedBox(height: 5),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildTag(city, Icons.location_on, Colors.blue.shade100, Colors.blue.shade800), const SizedBox(width: 8), _buildTag(status, Icons.star, Colors.orange.shade100, Colors.orange.shade800)]),
                  if (bio != null && bio.isNotEmpty) ...[const SizedBox(height: 15), Text(bio, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, height: 1.4))],
                  if (goals.isNotEmpty) ...[const SizedBox(height: 15), Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: goals.map((g) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), child: Text(g, style: const TextStyle(fontSize: 11)))).toList())],
                  const SizedBox(height: 20),
                  // 🔥 BOUTON SUPPRIMÉ ICI 🔥
                ],
              ),
            ),
          ),
          SliverPersistentHeader(pinned: true, delegate: _SliverAppBarDelegate(TabBar(controller: _tabController, indicatorColor: _creamyOrange, labelColor: _creamyOrange, unselectedLabelColor: Colors.grey, indicatorWeight: 3, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), tabs: const [Tab(text: "Mes Posts"), Tab(text: "Favoris")]))),
        ],
        body: TabBarView(controller: _tabController, children: [_buildPostGrid('user_id', _myId, "Tu n'as rien posté."), _buildSavedPostsGrid()]),
      ),
    );
  }

  Widget _buildTag(String text, IconData icon, Color bg, Color textCol) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: textCol), const SizedBox(width: 4), Text(text, style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 11))]));
  }

  Widget _buildPostGrid(String column, String value, String emptyMsg) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('posts').stream(primaryKey: ['id']).eq(column, value).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
        final posts = snapshot.data!;
        if (posts.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.dashboard_outlined, size: 40, color: Colors.grey.shade300), const SizedBox(height: 10), Text(emptyMsg, style: TextStyle(color: Colors.grey.shade500))]));
        return GridView.builder(padding: const EdgeInsets.all(2), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: posts.length, itemBuilder: (context, index) { final post = posts[index]; return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: _profileData!['first_name'], timeAgo: "Moi"))), child: Container(color: Colors.grey.shade100, child: post['image_url'] != null ? Image.network(post['image_url'], fit: BoxFit.cover) : Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(post['content'] ?? "", maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)))))); });
      },
    );
  }

  Widget _buildSavedPostsGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client.from('saved_posts').select('post_id, posts(*)').eq('user_id', _myId).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
        final savedItems = snapshot.data!;
        if (savedItems.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bookmark_border, size: 40, color: Colors.grey.shade300), const SizedBox(height: 10), Text("Aucun favori.", style: TextStyle(color: Colors.grey.shade500))]));
        return GridView.builder(padding: const EdgeInsets.all(2), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: savedItems.length, itemBuilder: (context, index) { final post = savedItems[index]['posts'] as Map<String, dynamic>; return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: "Auteur", timeAgo: "..."))), child: Container(color: Colors.grey.shade100, child: post['image_url'] != null ? Image.network(post['image_url'], fit: BoxFit.cover) : Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(post['content'] ?? "", maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)))))); });
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: const Color(0xFFFFF8F5), child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}