import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'post_details_page.dart';
import 'other_profile_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _myId = Supabase.instance.client.auth.currentUser?.id;
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _backgroundColor = const Color(0xFFFFF8F5);

  Future<void> _markAsRead(int notificationId) async {
    await Supabase.instance.client.from('notifications').update({'is_read': true}).eq('id', notificationId);
    setState(() {});
  }

  Future<void> _markAllAsRead() async {
    await Supabase.instance.client.from('notifications').update({'is_read': true}).eq('user_id', _myId!);
    setState(() {});
  }

  String _formatTime(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Il y a ${diff.inHours} h";
    return DateFormat('dd/MM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_myId == null) return const Scaffold(body: Center(child: Text("Non connecté")));

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all_rounded, color: _creamyOrange),
            tooltip: "Tout marquer comme lu",
            onPressed: _markAllAsRead,
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', _myId!)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
          
          final notifs = snapshot.data!;
          if (notifs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text("Aucune notification", style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifs.length,
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

                  if (post == null) return const SizedBox(); // Post supprimé

                  return Container(
                    color: isRead ? _backgroundColor : _creamyOrange.withOpacity(0.1), // Surlignage si non lu
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: actor['id']))),
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(actor['avatar_url'] ?? "https://i.pravatar.cc/150"),
                          radius: 24,
                        ),
                      ),
                      title: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black, fontSize: 14),
                          children: [
                            TextSpan(text: actor['first_name'] ?? "Quelqu'un", style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: type == 'like' ? " a aimé ton post." : " a commenté ton post."),
                          ],
                        ),
                      ),
                      subtitle: Text(_formatTime(notif['created_at']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      trailing: post['image_url'] != null 
                          ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(post['image_url'], width: 40, height: 40, fit: BoxFit.cover))
                          : const Icon(Icons.article_outlined, color: Colors.grey),
                      onTap: () {
                        _markAsRead(notif['id']);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: "Moi", timeAgo: ""))); // Adapter timeAgo si besoin
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}