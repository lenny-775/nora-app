import 'package:flutter/material.dart';

// --- 1. LE LOGO (Version Compatible Splash Screen) ---
class NoraPin3D extends StatelessWidget {
  final double size;
  final bool isAnimating; // Ajouté pour compatibilité

  const NoraPin3D({
    super.key, 
    this.size = 50,
    this.isAnimating = false, // On l'accepte mais on ne fait rien avec pour l'instant
  });

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_on, size: size, color: const Color(0xFFFF6B00));
  }
}

// --- 2. CHAMP DE TEXTE ---
class NoraTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isNumber;
  final bool obscureText;

  const NoraTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isNumber = false,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey.shade400),
          hintText: hintText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}

// --- 3. BOUTON (Version Flexible) ---
class NoraButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onPressed;
  
  final double? width;
  final double? height;
  final double? fontSize;

  const NoraButton({
    super.key,
    required this.text,
    this.isLoading = false, // Important : par défaut à false
    required this.onPressed,
    this.width,
    this.height,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 55,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B00),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          shadowColor: const Color(0xFFFF6B00).withOpacity(0.4),
        ),
        child: isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                text,
                style: TextStyle(fontSize: fontSize ?? 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }
}

// --- 4. CARTE DE POST (Version Compatible Détails) ---
class NoraPostCard extends StatelessWidget {
  final String userName;
  final String? avatarUrl;
  final String timeAgo;
  final String content;
  final int likes;
  final int comments;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback? onShare; // Devenu optionnel (?)

  const NoraPostCard({
    super.key,
    required this.userName,
    this.avatarUrl,
    required this.timeAgo,
    required this.content,
    required this.likes,
    required this.comments,
    required this.isLiked,
    required this.onLike,
    this.onShare, // Peut être null maintenant
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                backgroundColor: Colors.grey.shade200,
                child: avatarUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(timeAgo, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(content, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 15),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey),
                    onPressed: onLike,
                  ),
                  Text("$likes"),
                ],
              ),
              // On affiche le bouton partager seulement si onShare est fourni
              IconButton(
                icon: const Icon(Icons.send, color: Colors.grey), 
                onPressed: onShare ?? () {}, // Ne plante pas si null
              ),
            ],
          )
        ],
      ),
    );
  }
}