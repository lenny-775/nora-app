import 'package:flutter/material.dart';

// 1. LE CHAMP DE TEXTE
class NoraTextField extends StatelessWidget {
  final String hintText;
  final IconData icon;
  final TextEditingController controller;
  final bool isNumber;
  final bool obscureText;
  final VoidCallback? onTap;
  final bool readOnly;

  const NoraTextField({
    super.key,
    required this.hintText,
    required this.icon,
    required this.controller,
    this.isNumber = false,
    this.obscureText = false,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0E5E0).withOpacity(0.8),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(color: Color(0xFF2D3436), fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        ),
      ),
    );
  }
}

// 2. LE BOUTON PRINCIPAL
class NoraButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const NoraButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: onPressed == null 
          ? const LinearGradient(colors: [Colors.grey, Colors.grey]) 
          : const LinearGradient(
              colors: [Color(0xFFFFA07A), Color(0xFFFF5E62)], 
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: const Color(0xFFFF5E62).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: isLoading 
          ? const SizedBox(
              height: 24, 
              width: 24, 
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            )
          : Text(
              text, 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
            ),
      ),
    );
  }
}

// 3. LA "TIP BOX"
class NoraInfoBox extends StatelessWidget {
  final String text;

  const NoraInfoBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 20, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// 4. LA CARTE DE POST (VERSION MISE À JOUR AVEC SHARE)
class NoraPostCard extends StatelessWidget {
  final String userName;
  final String timeAgo;
  final String content;
  final String? avatarUrl;
  final int likes;
  final int comments;
  final VoidCallback? onLike;
  final bool isLiked;
  final VoidCallback? onShare; // <--- C'est ici que ça manquait !

  const NoraPostCard({
    super.key,
    required this.userName,
    required this.timeAgo,
    required this.content,
    this.avatarUrl,
    this.likes = 0,
    this.comments = 0,
    this.onLike,
    this.isLiked = false,
    this.onShare, // <--- Et ici !
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null 
                    ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : "?", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)) 
                    : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(timeAgo, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.more_horiz, color: Colors.grey),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(content, style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF2D3436))),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onLike, 
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border, 
                        size: 24, 
                        color: isLiked ? Colors.red : Colors.grey.shade600
                      ),
                      const SizedBox(width: 5),
                      Text("$likes", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                
                const SizedBox(width: 20),
                
                Icon(Icons.chat_bubble_outline, size: 22, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text("$comments", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                
                const Spacer(),
                
                // --- BOUTON PARTAGER (AVION EN PAPIER) ---
                GestureDetector(
                  onTap: onShare, // Connexion avec la fonction
                  child: Icon(Icons.send_rounded, size: 22, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 15),
                Icon(Icons.bookmark_border, size: 20, color: Colors.grey.shade600),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 5. LE PIN 3D
class NoraPin3D extends StatefulWidget {
  final double size;
  final bool isAnimating;

  const NoraPin3D({
    super.key, 
    required this.size, 
    this.isAnimating = true
  });

  @override
  State<NoraPin3D> createState() => _NoraPin3DState();
}

class _NoraPin3DState extends State<NoraPin3D> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 3), vsync: this);
    
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(NoraPin3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = widget.isAnimating ? _controller.value * 2 * 3.14159 : 0.0;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle), 
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size, 
                height: widget.size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF0055), Color(0xFFFF6B00)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
                ),
                child: Icon(Icons.location_on, size: widget.size * 0.6, color: Colors.white),
              ),
              Positioned(
                top: widget.size * 0.2,
                child: Icon(Icons.eco, size: widget.size * 0.25, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}