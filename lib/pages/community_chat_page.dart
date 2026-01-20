import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CommunityChatPage extends StatefulWidget {
  final int communityId;
  final String communityName;

  const CommunityChatPage({
    super.key, 
    required this.communityId, 
    required this.communityName
  });

  @override
  State<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage> {
  final _controller = TextEditingController();
  final _myId = Supabase.instance.client.auth.currentUser!.id;
  final ScrollController _scrollController = ScrollController();

  // Envoi de message dans le groupe
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    try {
      await Supabase.instance.client.from('community_messages').insert({
        'community_id': widget.communityId,
        'user_id': _myId,
        'content': text,
      });
      _scrollDown();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  void _scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFF6B00),
              child: Icon(Icons.groups, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.communityName, 
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.grey),
            onPressed: () {
              // Ici on pourrait afficher la liste des membres ou quitter le groupe
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('community_messages')
                  .stream(primaryKey: ['id'])
                  .eq('community_id', widget.communityId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return const Center(child: Text("Soyez le premier à écrire ! 👋"));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['user_id'] == _myId;

                    return FutureBuilder<Map<String, dynamic>>(
                      // On charge le profil de l'auteur du message pour afficher son nom/photo
                      future: Supabase.instance.client.from('profiles').select().eq('id', msg['user_id']).single(),
                      builder: (context, snap) {
                        final author = snap.data;
                        final String name = author?['first_name'] ?? "User";
                        final String? avatar = author?['avatar_url'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(radius: 16, backgroundImage: avatar != null ? NetworkImage(avatar) : null, child: avatar == null ? const Icon(Icons.person, size: 16) : null),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe) Padding(
                                      padding: const EdgeInsets.only(left: 12, bottom: 2),
                                      child: Text(name, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isMe ? const Color(0xFFFF6B00) : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                                          bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                                        ),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                                      ),
                                      child: Text(
                                        msg['content'] ?? "", 
                                        style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2, right: 5, left: 5),
                                      child: Text(_formatTime(msg['created_at']), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          
          // Zone de saisie
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFFFFF8F5), borderRadius: BorderRadius.circular(25)),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Envoyer un message...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFFFF6B00),
                      child: Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}