import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';
import 'community_chat_page.dart';
import 'search_page.dart'; // Pour choisir avec qui créer un chat privé

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final User? user = Supabase.instance.client.auth.currentUser;
  int _currentTabIndex = 0; // 0 = Privé, 1 = Groupes

  String _formatTime(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "${date.day}/${date.month}";
  }

  // --- LOGIQUE DE CRÉATION DE GROUPE ---
  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Créer une communauté"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(hintText: "Nom du groupe")),
            TextField(controller: descController, decoration: const InputDecoration(hintText: "Description")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await Supabase.instance.client.from('communities').insert({
                  'name': nameController.text,
                  'description': descController.text,
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Créer"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text('Mes Messages', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF6B00), size: 28),
            onPressed: () {
              if (_currentTabIndex == 0) {
                // Vers la recherche pour créer un chat privé
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage()));
              } else {
                _showCreateGroupDialog();
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          // CONTENU (Privé ou Groupes)
          _currentTabIndex == 0 ? _buildPrivateChats() : _buildCommunityChats(),

          // MENU LIQUID GLASS (En bas)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(left: 40, right: 40, bottom: 30),
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    children: [
                      _buildTabButton(0, "Privé", Icons.person_outline),
                      _buildTabButton(1, "Groupes", Icons.groups_outlined),
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

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFFF6B00) : Colors.grey),
              Text(label, style: TextStyle(color: isSelected ? const Color(0xFFFF6B00) : Colors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  // --- ONGLET 1 : PRIVÉ ---
  Widget _buildPrivateChats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('conversations').stream(primaryKey: ['id']).order('updated_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
        final myConversations = snapshot.data!.where((c) => c['user1_id'] == user!.id || c['user2_id'] == user!.id).toList();

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: myConversations.length,
          itemBuilder: (context, index) {
            final conversation = myConversations[index];
            final otherUserId = (conversation['user1_id'] == user!.id) ? conversation['user2_id'] : conversation['user1_id'];

            return FutureBuilder<List<dynamic>>(
              future: Future.wait([
                Supabase.instance.client.from('profiles').select().eq('id', otherUserId).single(),
                Supabase.instance.client.from('messages').select('id').eq('conversation_id', conversation['id']).eq('sender_id', otherUserId).filter('read_at', 'is', null)
              ]),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final profile = snap.data![0];
                final unread = (snap.data![1] as List).length;

                return _buildTile(
                  title: profile['first_name'] ?? 'Utilisateur',
                  subtitle: conversation['last_message'] ?? '...',
                  img: profile['avatar_url'],
                  time: _formatTime(conversation['updated_at']),
                  unread: unread,
                  isOnline: profile['last_seen'] != null && DateTime.now().difference(DateTime.parse(profile['last_seen'])).inMinutes < 5,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(conversationId: conversation['id'], receiverId: otherUserId, receiverName: profile['first_name']))),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- ONGLET 2 : GROUPES ---
  Widget _buildCommunityChats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('communities').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final community = snapshot.data![index];
            return _buildTile(
              title: community['name'],
              subtitle: community['description'] ?? "Discussion de groupe",
              isGroup: true,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CommunityChatPage(communityId: community['id'], communityName: community['name']))),
            );
          },
        );
      },
    );
  }

  Widget _buildTile({required String title, required String subtitle, String? img, String? time, int unread = 0, bool isOnline = false, bool isGroup = false, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: unread > 0 ? const Color(0xFFFF6B00).withOpacity(0.1) : Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(radius: 25, backgroundImage: img != null ? NetworkImage(img) : null, child: img == null ? Icon(isGroup ? Icons.groups : Icons.person) : null),
            if (isOnline) Positioned(right: 1, bottom: 1, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
          ],
        ),
        title: Text(title, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.bold)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? Colors.black87 : Colors.grey)),
        trailing: time != null ? Text(time, style: const TextStyle(fontSize: 11)) : null,
        onTap: onTap,
      ),
    );
  }
}