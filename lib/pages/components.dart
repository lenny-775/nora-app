import 'package:flutter/material.dart';

// 1. LE CHAMP DE TEXTE (Style "Pilule" Blanche avec ombre)
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
        borderRadius: BorderRadius.circular(20), // Arrondi doux
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0E5E0).withOpacity(0.8), // Ombre légère colorée
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

// 2. LE BOUTON PRINCIPAL (Dégradé Pêche/Rouge)
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
          ? const LinearGradient(colors: [Colors.grey, Colors.grey]) // Gris si désactivé
          : const LinearGradient(
              colors: [Color(0xFFFFA07A), Color(0xFFFF5E62)], // Ton dégradé signature
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
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              text, 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
            ),
      ),
    );
  }
}

// 3. LA "TIP BOX" (L'ampoule avec le conseil)
class NoraInfoBox extends StatelessWidget {
  final String text;

  const NoraInfoBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F2), // Fond très clair
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
// ... (Laisse le reste du fichier comme avant)

// 4. LA CARTE DE POST (Style Facebook/Insta épuré)
class NoraPostCard extends StatelessWidget {
  final String userName;
  final String timeAgo;
  final String content;
  final String? avatarUrl;
  final int likes;
  final int comments;

  const NoraPostCard({
    super.key,
    required this.userName,
    required this.timeAgo,
    required this.content,
    this.avatarUrl,
    this.likes = 0,
    this.comments = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
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
          // En-tête (Avatar + Nom + Temps)
          Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(avatarUrl ?? "https://i.pravatar.cc/150"),
                radius: 20,
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
              Icon(Icons.more_horiz, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 15),
          // Contenu du post
          Text(content, style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF2D3436))),
          const SizedBox(height: 15),
          // Pied de carte (Likes / Coms)
          Row(
            children: [
              Icon(Icons.favorite_border, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text("$likes", style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(width: 20),
              Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text("$comments", style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}