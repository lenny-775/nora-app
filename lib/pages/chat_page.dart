import 'dart:async';
import 'dart:io'; // Attention : File ne marche pas sur le Web
import 'package:flutter/foundation.dart'; // Pour kIsWeb
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:permission_handler/permission_handler.dart';

class ChatPage extends StatefulWidget {
  final int conversationId;
  final String receiverId;
  final String receiverName;
  final Map<String, dynamic>? pendingPost;

  const ChatPage({
    super.key, 
    required this.conversationId, 
    required this.receiverId,
    required this.receiverName,
    this.pendingPost, 
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _myId = Supabase.instance.client.auth.currentUser!.id;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isUploading = false;
  
  Map<String, dynamic>? _attachedPost;
  String? _receiverAvatarUrl; 

  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _darkText = const Color(0xFF2D3436);

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    if (widget.pendingPost != null) _attachedPost = widget.pendingPost;
    _fetchReceiverProfile();
    _updateMyLastSeen();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _fetchReceiverProfile() async {
    try {
      final data = await Supabase.instance.client.from('profiles').select('avatar_url').eq('id', widget.receiverId).single();
      if (mounted) setState(() => _receiverAvatarUrl = data['avatar_url']);
    } catch (_) {}
  }

  Future<void> _updateMyLastSeen() async {
    try { await Supabase.instance.client.from('profiles').update({'last_seen': DateTime.now().toIso8601String()}).eq('id', _myId); } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    try { await Supabase.instance.client.from('messages').update({'read_at': DateTime.now().toIso8601String()}).eq('conversation_id', widget.conversationId).neq('sender_id', _myId).filter('read_at', 'is', null); } catch (_) {}
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

  // --- ENVOI GÉNÉRIQUE ---
  Future<void> _sendMessage({String? text, String? imageUrl, String? audioUrl}) async {
    if ((text == null || text.trim().isEmpty) && imageUrl == null && audioUrl == null && _attachedPost == null) return;
    
    _controller.clear();
    final postToSend = _attachedPost;
    setState(() => _attachedPost = null);

    String type = 'text';
    if (postToSend != null) type = 'post_share';
    else if (imageUrl != null) type = 'image';
    else if (audioUrl != null) type = 'audio';

    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': _myId,
        'content': audioUrl ?? imageUrl ?? text,
        'post_data': postToSend,
        'type': type,
        'liked_by': [],
      });

      String lastMsgPreview = "Message";
      if (type == 'text') lastMsgPreview = text!;
      if (type == 'image') lastMsgPreview = "📷 Photo";
      if (type == 'audio') lastMsgPreview = "🎤 Vocal";
      if (type == 'post_share') lastMsgPreview = "🔗 Post";

      await Supabase.instance.client.from('conversations').update({'last_message': lastMsgPreview, 'updated_at': DateTime.now().toIso8601String()}).eq('id', widget.conversationId);
      
      _updateMyLastSeen();
      _scrollDown();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  // --- UPLOAD IMAGE (CORRIGÉ) ---
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 1024);
      if (image == null) return;
      setState(() => _isUploading = true);
      
      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$_myId.$fileExt';
      
      // CORRECTION : On enlève le dossier 'chat_images/' car on est déjà dedans via .from()
      final path = fileName;

      await Supabase.instance.client.storage.from('chat_images').uploadBinary(
        path, 
        bytes, 
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true)
      );
      final imageUrl = Supabase.instance.client.storage.from('chat_images').getPublicUrl(path);

      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur upload image")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- AUDIO (SÉCURISÉ POUR LE WEB + CORRIGÉ) ---
  Future<void> _toggleRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Les vocaux sont disponibles sur l'application mobile 📱")));
      return;
    }

    try {
      if (_isRecording) {
        // STOP
        final String? path = await _audioRecorder.stop();
        setState(() => _isRecording = false);

        if (path != null) {
          setState(() => _isUploading = true);
          final File audioFile = File(path);
          final bytes = await audioFile.readAsBytes();
          final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}_$_myId.m4a';
          
          // CORRECTION : On enlève le dossier 'chat_images/' ici aussi
          final storagePath = fileName;

          await Supabase.instance.client.storage.from('chat_images').uploadBinary(
            storagePath, 
            bytes, 
            fileOptions: const FileOptions(contentType: 'audio/m4a', upsert: true)
          );
          final audioUrl = Supabase.instance.client.storage.from('chat_images').getPublicUrl(storagePath);
          await _sendMessage(audioUrl: audioUrl);
        }
      } else {
        // START
        if (await _audioRecorder.hasPermission()) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String path = '${appDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: path);
          setState(() => _isRecording = true);
        } else {
          await Permission.microphone.request();
        }
      }
    } catch (e) { 
      debugPrint("Erreur audio: $e"); 
    } finally { 
      if (mounted) setState(() => _isUploading = false); 
    }
  }

  void _scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.minScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  String _formatTime(String createdAt) {
    final date = DateTime.parse(createdAt).toLocal();
    return DateFormat('HH:mm').format(date);
  }

  String _formatLastSeen(String? lastSeenStr) {
    if (lastSeenStr == null) return "Hors ligne";
    final lastSeen = DateTime.parse(lastSeenStr).toLocal();
    final difference = DateTime.now().difference(lastSeen);
    if (difference.inMinutes < 5) return "En ligne";
    if (difference.inDays == 0) return "Vu à ${DateFormat('HH:mm').format(lastSeen)}";
    return "Vu le ${DateFormat('dd/MM').format(lastSeen)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor, 
      appBar: AppBar(
        backgroundColor: _backgroundColor, elevation: 0, centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: _darkText), onPressed: () => Navigator.pop(context)),
        title: Column(children: [Text(widget.receiverName, style: TextStyle(color: _darkText, fontWeight: FontWeight.w900, fontSize: 18)), StreamBuilder<List<Map<String, dynamic>>>(stream: Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).eq('id', widget.receiverId), builder: (context, snapshot) { if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink(); return Text(_formatLastSeen(snapshot.data!.first['last_seen']), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)); })]),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('messages').stream(primaryKey: ['id']).eq('conversation_id', widget.conversationId).order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
                final messages = snapshot.data!;
                if (messages.isNotEmpty) { final lastMsg = messages.first; if (lastMsg['sender_id'] != _myId && lastMsg['read_at'] == null) Future.delayed(Duration.zero, () => _markMessagesAsRead()); }
                if (messages.isEmpty) return const Center(child: Text("Dites bonjour ! 👋", style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  controller: _scrollController, reverse: true, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myId;
                    final String type = msg['type'] ?? 'text';
                    final String content = msg['content'] ?? '';
                    final Map<String, dynamic>? postData = msg['post_data']; 
                    final String? readAt = msg['read_at'];
                    final String time = _formatTime(msg['created_at']);
                    
                    final List<dynamic> likes = msg['liked_by'] ?? [];
                    final bool isLiked = likes.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade300, backgroundImage: _receiverAvatarUrl != null ? NetworkImage(_receiverAvatarUrl!) : null, child: _receiverAvatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.grey) : null),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onDoubleTap: () => _toggleLike(msg),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        padding: (type == 'image' || type == 'audio' || postData != null) ? const EdgeInsets.all(5) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isMe ? _creamyOrange : Colors.white,
                                          borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(5), bottomRight: isMe ? const Radius.circular(5) : const Radius.circular(20)),
                                          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // IMAGE
                                            if (type == 'image') 
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(15), 
                                                child: Image.network(
                                                  content, width: 200, fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => const SizedBox(height: 50, width: 50, child: Icon(Icons.broken_image)),
                                                )
                                              ),
                                            
                                            // POST
                                            if (postData != null) Container(width: 220, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.share_rounded, size: 14, color: _creamyOrange), const SizedBox(width: 5), const Expanded(child: Text("Post partagé", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)))]), const SizedBox(height: 5), Text(postData['content'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontSize: 13))])),
                                            
                                            // AUDIO
                                            if (type == 'audio') _AudioPlayerBubble(url: content, isMe: isMe),

                                            // TEXTE
                                            if (type == 'text' && content.isNotEmpty) Text(content, style: TextStyle(color: isMe ? Colors.white : _darkText, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                      if (isLiked) Positioned(bottom: -8, right: isMe ? null : -5, left: isMe ? -5 : null, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)]), child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 14)))
                                    ],
                                  ),
                                ),
                                Padding(padding: const EdgeInsets.only(top: 4, left: 2, right: 2), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)), if (isMe) ...[const SizedBox(width: 4), if (readAt != null) Text("Vu", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _creamyOrange)) else const Icon(Icons.check, size: 12, color: Colors.grey)]])),
                              ],
                            ),
                          ),
                        ],
                      ),
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
              child: Column(
                children: [
                  if (_attachedPost != null) Container(margin: const EdgeInsets.fromLTRB(16, 16, 16, 0), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _creamyOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.share_rounded, color: _creamyOrange), const SizedBox(width: 12), Expanded(child: Text(_attachedPost!['content'] ?? "Post", maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () => setState(() => _attachedPost = null))])),
                  Row(children: [
                     // MICRO
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
                    IconButton(icon: Icon(Icons.photo_camera_rounded, color: Colors.grey.shade400), onPressed: _isUploading || _isRecording ? null : _pickAndUploadImage),
                    Expanded(child: TextField(controller: _controller, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: _isRecording ? "Enregistrement..." : "Message...", hintStyle: TextStyle(color: _isRecording ? Colors.redAccent : Colors.grey.shade400), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14)), onTap: () { _updateMyLastSeen(); _markMessagesAsRead(); })),
                    Padding(padding: const EdgeInsets.only(right: 8.0), child: IconButton(icon: Icon(Icons.send_rounded, color: _creamyOrange), onPressed: () => _sendMessage(text: _controller.text.trim()))),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// WIDGET AUDIO
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
  void dispose() { _player.dispose(); super.dispose(); }
  Future<void> _togglePlay() async { if (_isPlaying) { await _player.pause(); } else { await _player.play(UrlSource(widget.url)); } }
  @override
  void initState() { super.initState(); _player.onPlayerStateChanged.listen((state) { if(mounted) setState(() => _isPlaying = state == PlayerState.playing); }); }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          IconButton(icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: widget.isMe ? Colors.white : const Color(0xFFFF914D), size: 35), onPressed: _togglePlay),
          Expanded(child: Container(height: 4, decoration: BoxDecoration(color: widget.isMe ? Colors.white54 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(width: 10),
          Text("Audio", style: TextStyle(color: widget.isMe ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}