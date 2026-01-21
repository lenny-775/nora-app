import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart'; // Pour enregistrer
import 'package:audioplayers/audioplayers.dart'; // Pour écouter
import 'package:path_provider/path_provider.dart'; // Pour les fichiers temporaires
import 'package:permission_handler/permission_handler.dart'; // Pour les permissions

class CommunityChatPage extends StatefulWidget {
  final int communityId;
  final String communityName;

  const CommunityChatPage({super.key, required this.communityId, required this.communityName});

  @override
  State<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _myId = Supabase.instance.client.auth.currentUser!.id;
  final ImagePicker _picker = ImagePicker();
  
  // Audio
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isUploading = false;

  // COULEURS V3
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _darkText = const Color(0xFF2D3436);

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- ENVOI GÉNÉRIQUE ---
  Future<void> _sendMessage({String? text, String? imageUrl, String? audioUrl}) async {
    if ((text == null || text.trim().isEmpty) && imageUrl == null && audioUrl == null) return;
    _messageController.clear();

    String type = 'text';
    if (imageUrl != null) type = 'image';
    if (audioUrl != null) type = 'audio';

    try {
      await Supabase.instance.client.from('messages').insert({
        'content': audioUrl ?? imageUrl ?? text,
        'sender_id': _myId,
        'group_id': widget.communityId,
        'type': type,
        'liked_by': [],
      });
      _scrollDown();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur envoi: $e")));
    }
  }

  // --- UPLOAD IMAGE ---
  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 1024);
      if (image == null) return;
      setState(() => _isUploading = true);

      final fileExt = image.name.split('.').last; 
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$_myId.$fileExt';
      final filePath = 'group_${widget.communityId}/$fileName';
      final bytes = await image.readAsBytes();

      await Supabase.instance.client.storage.from('chat_images').uploadBinary(
        filePath, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final imageUrl = Supabase.instance.client.storage.from('chat_images').getPublicUrl(filePath);
      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      debugPrint("Erreur upload: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- LOGIQUE AUDIO : START / STOP & SEND ---
  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        // STOP & ENVOI
        final String? path = await _audioRecorder.stop();
        setState(() => _isRecording = false);

        if (path != null) {
          setState(() => _isUploading = true);
          final File audioFile = File(path);
          final bytes = await audioFile.readAsBytes();
          final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}_$_myId.m4a';
          final filePath = 'group_${widget.communityId}/$fileName';

          // On utilise le même bucket 'chat_images' pour simplifier (c'est juste du stockage)
          await Supabase.instance.client.storage.from('chat_images').uploadBinary(
            filePath, bytes, fileOptions: const FileOptions(contentType: 'audio/m4a', upsert: true),
          );
          final audioUrl = Supabase.instance.client.storage.from('chat_images').getPublicUrl(filePath);
          await _sendMessage(audioUrl: audioUrl);
        }
      } else {
        // START
        if (await _audioRecorder.hasPermission()) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String path = '${appDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
          
          await _audioRecorder.start(const RecordConfig(), path: path);
          setState(() => _isRecording = true);
        } else {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission micro refusée")));
        }
      }
    } catch (e) {
      debugPrint("Erreur audio: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- LIKE ---
  Future<void> _toggleLike(Map<String, dynamic> msg) async {
    try {
      final messageId = msg['id'];
      List<dynamic> currentLikes = List.from(msg['liked_by'] ?? []);
      if (currentLikes.contains(_myId)) currentLikes.remove(_myId); else currentLikes.add(_myId);
      await Supabase.instance.client.from('messages').update({'liked_by': currentLikes}).eq('id', messageId);
    } catch (e) { debugPrint("Erreur like: $e"); }
  }

  // --- QUITTER ---
  Future<void> _leaveGroup() async {
    try {
      await Supabase.instance.client.from('group_members').delete().eq('group_id', widget.communityId).eq('user_id', _myId);
      if (mounted) { Navigator.pop(context); Navigator.pop(context); }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  void _scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.minScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  String _formatTime(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
    return DateFormat('HH:mm').format(date);
  }

  // --- SETTINGS ---
  void _showGroupSettings() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text("Membres", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _darkText)),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: Supabase.instance.client.from('group_members').select('user_id, profiles(first_name, avatar_url)').eq('group_id', widget.communityId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
                    final members = snapshot.data!;
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), itemCount: members.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final p = members[index]['profiles'] as Map<String, dynamic>;
                        return ListTile(leading: CircleAvatar(backgroundImage: NetworkImage(p['avatar_url'] ?? "https://i.pravatar.cc/150")), title: Text(p['first_name'] ?? "Membre", style: TextStyle(fontWeight: FontWeight.bold, color: _darkText)));
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Quitter ?"), content: const Text("Tu ne recevras plus les messages."), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Annuler")), TextButton(onPressed: (){Navigator.pop(ctx); _leaveGroup();}, child: const Text("Quitter", style: TextStyle(color: Colors.red)))])); },
                      icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white), label: const Text("Quitter le groupe", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor, elevation: 0, centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: _darkText), onPressed: () => Navigator.pop(context)),
        title: Column(children: [Text(widget.communityName, style: TextStyle(color: _darkText, fontWeight: FontWeight.w900, fontSize: 18)), const Text("Groupe", style: TextStyle(color: Colors.grey, fontSize: 12))]),
        actions: [IconButton(icon: Icon(Icons.settings_outlined, color: _darkText), onPressed: _showGroupSettings), const SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('messages').stream(primaryKey: ['id']).eq('group_id', widget.communityId).order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
                final messages = snapshot.data!;
                if (messages.isEmpty) return const Center(child: Text("Dites bonjour ! 👋", style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  controller: _scrollController, reverse: true, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myId;
                    final String type = msg['type'] ?? 'text';
                    final content = msg['content'] ?? '';
                    final time = _formatTime(msg['created_at']);
                    
                    final List<dynamic> likes = msg['liked_by'] ?? [];
                    final bool isLiked = likes.isNotEmpty;

                    return FutureBuilder<Map<String, dynamic>>(
                      future: Supabase.instance.client.from('profiles').select().eq('id', msg['sender_id']).single(),
                      builder: (context, snapProfile) {
                        final authorName = snapProfile.hasData ? snapProfile.data!['first_name'] : '...';
                        final authorAvatar = snapProfile.hasData ? snapProfile.data!['avatar_url'] : null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade300, backgroundImage: authorAvatar != null ? NetworkImage(authorAvatar) : null, child: authorAvatar == null ? const Icon(Icons.person, size: 16, color: Colors.grey) : null),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe) Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Text(authorName, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
                                    
                                    // GESTURE (Double Tap Like)
                                    GestureDetector(
                                      onDoubleTap: () => _toggleLike(msg),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            padding: (type == 'image' || type == 'audio') ? const EdgeInsets.all(5) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isMe ? _creamyOrange : Colors.white,
                                              borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(5), bottomRight: isMe ? const Radius.circular(5) : const Radius.circular(20)),
                                              boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))],
                                            ),
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              // CONTENU SELON TYPE
                                              if (type == 'image') ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(content, width: 200, fit: BoxFit.cover, loadingBuilder: (ctx, child, p) => p == null ? child : Container(height: 150, width: 200, color: Colors.grey.shade200, child: const Center(child: Icon(Icons.image, color: Colors.white)))))
                                              else if (type == 'audio') 
                                                // LECTEUR AUDIO CUSTOM
                                                _AudioPlayerBubble(url: content, isMe: isMe)
                                              else Text(content, style: TextStyle(color: isMe ? Colors.white : _darkText, fontSize: 16)),
                                            ]),
                                          ),
                                          if (isLiked) Positioned(bottom: -8, right: isMe ? null : -5, left: isMe ? -5 : null, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)]), child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 14)))
                                        ],
                                      ),
                                    ),
                                    Padding(padding: const EdgeInsets.only(top: 4, left: 2, right: 2), child: Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)))
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
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(35), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))]),
              child: Row(children: [
                // BOUTON MICRO (Switch)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _isRecording ? Colors.redAccent : _creamyOrange.withOpacity(0.1), shape: BoxShape.circle),
                    child: _isUploading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                      : Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: _isRecording ? Colors.white : _creamyOrange, size: 24),
                  ),
                  onPressed: _isUploading ? null : _toggleRecording,
                ),
                
                // BOUTON PHOTO
                IconButton(icon: Icon(Icons.photo_camera_rounded, color: Colors.grey.shade400), onPressed: _isUploading || _isRecording ? null : _pickAndSendImage),

                Expanded(child: TextField(controller: _messageController, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: _isRecording ? "Enregistrement..." : "Message...", hintStyle: TextStyle(color: _isRecording ? Colors.redAccent : Colors.grey.shade400), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14)))),
                Padding(padding: const EdgeInsets.only(right: 8.0), child: IconButton(icon: Icon(Icons.send_rounded, color: _creamyOrange), onPressed: () => _sendMessage(text: _messageController.text.trim()))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET LECTEUR AUDIO ---
class _AudioPlayerBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  const _AudioPlayerBubble({required this.url, required this.isMe});

  @override
  State<_AudioPlayerBubble> createState() => _AudioPlayerBubbleState();
}

class _AudioPlayerBubbleState extends State<_AudioPlayerBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if(mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: widget.isMe ? Colors.white : const Color(0xFFFF914D), size: 35),
            onPressed: _togglePlay,
          ),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(color: widget.isMe ? Colors.white54 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(width: 10),
          Text("Audio", style: TextStyle(color: widget.isMe ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}