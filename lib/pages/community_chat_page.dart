import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CommunityChatPage extends StatefulWidget {
  final int communityId;
  final String communityName;

  const CommunityChatPage({super.key, required this.communityId, required this.communityName});

  @override
  State<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage> {
  final _controller = TextEditingController();
  final _myId = Supabase.instance.client.auth.currentUser!.id;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    await Supabase.instance.client.from('community_messages').insert({
      'community_id': widget.communityId,
      'user_id': _myId,
      'content': text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(widget.communityName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(15),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['user_id'] == _myId;

                    return FutureBuilder<Map<String, dynamic>>(
                      future: Supabase.instance.client.from('profiles').select().eq('id', msg['user_id']).single(),
                      builder: (context, profileSnap) {
                        final name = profileSnap.data?['first_name'] ?? "...";
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe) Text("  $name", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFFFF6B00) : Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(msg['content'], style: TextStyle(color: isMe ? Colors.white : Colors.black)),
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
          // Barre de saisie (identique à ton ChatPage actuel)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Message groupe...",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFFFF6B00)), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}