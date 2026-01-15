import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'edit_profile_page.dart'; 

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    }
  }

  void _goToEditPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    ).then((updated) {
      if (updated == true) {
        _fetchProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(_profileData?['avatar_url'] ?? "https://i.pravatar.cc/300"),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, color: Color(0xFFFF6B00), size: 20),
                      ),
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              Text(
                _profileData?['first_name'] ?? "Voyageur",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
              ),
              Text(
                "${_profileData?['status'] ?? 'PVTiste'} à ${_profileData?['city'] ?? 'Canada'}",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: 200, 
                child: OutlinedButton.icon(
                  onPressed: _goToEditPage,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("Modifier mes infos"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D3436),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              
              const Spacer(),
              
              TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text("Se déconnecter", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}