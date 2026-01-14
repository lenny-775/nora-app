import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'other_profile_page.dart'; // NOUVEAU : On importe la page de profil

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // --- VARIABLES FORMULAIRE ---
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();

  String? _selectedCity;
  String? _selectedStatus;
  String? _selectedGoal;
  DateTime? _arrivalDate;
  final _dateController = TextEditingController();

  final List<String> _cities = [
    'Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 
    'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'
  ];
  final List<String> _statusOptions = ['PVTiste', 'Expatrié', 'Étudiant', 'Touriste', 'Local'];
  final List<String> _goals = ['Rencontrer du monde', 'Trouver un job', 'Trouver un logement', 'Boire des verres', 'Découvrir la ville'];

  List<Map<String, dynamic>> _similarProfiles = [];

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // --- LOGIQUE NAVIGATION ---
  void _nextPage() {
    if (_currentPage == 0) {
      if (_firstNameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _ageController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tout remplir svp !')));
        return;
      }
    } else if (_currentPage == 1) {
      if (_selectedCity == null || _selectedStatus == null || _selectedGoal == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tout remplir svp !')));
        return;
      }
      _signUpAndFetchProfiles();
      return; 
    }

    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentPage++);
  }

  void _previousPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentPage--);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _arrivalDate = picked;
        _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // --- FONCTION INSCRIPTION ---
  Future<void> _signUpAndFetchProfiles() async {
    setState(() => _isLoading = true);

    try {
      final firstName = _firstNameController.text.trim();
      final email = _emailController.text.trim();
      final age = int.tryParse(_ageController.text.trim()) ?? 18;
      final newAvatarUrl = "https://api.dicebear.com/9.x/initials/png?seed=$firstName&backgroundColor=FF6B00&textColor=ffffff";

      // 1. Inscription Auth
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text.trim(),
        data: {'first_name': firstName, 'city': _selectedCity},
      );

      final User? user = res.user;

      if (user != null) {
        // 2. Sauvegarde Profil
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'first_name': firstName,
          'email': email,
          'age': age,
          'city': _selectedCity,
          'status': _selectedStatus,
          'goal': _selectedGoal,
          'avatar_url': newAvatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });

        // 3. Récupérer des profils similaires
        final profiles = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('city', _selectedCity!)
            .neq('id', user.id)
            .limit(10); // J'ai monté la limite à 10 pour avoir du choix

        setState(() {
          _similarProfiles = List<Map<String, dynamic>>.from(profiles);
          _isLoading = false;
        });

        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        setState(() => _currentPage = 2);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  // --- DESIGN ---
  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFFF6B00)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Qui es-tu ?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
          const SizedBox(height: 10),
          const Text("Dis-nous en un peu plus sur toi", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          TextField(controller: _firstNameController, decoration: _inputDecor("Ton Prénom", Icons.person)),
          const SizedBox(height: 16),
          TextField(controller: _ageController, keyboardType: TextInputType.number, decoration: _inputDecor("Ton Âge", Icons.cake)),
          const SizedBox(height: 16),
          TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecor("Email", Icons.email)),
          const SizedBox(height: 16),
          TextField(controller: _passwordController, obscureText: true, decoration: _inputDecor("Mot de passe", Icons.lock)),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Ton Aventure", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
          const SizedBox(height: 10),
          const Text("Où en es-tu au Canada ?", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          DropdownButtonFormField<String>(value: _selectedCity, decoration: _inputDecor("Ta ville actuelle", Icons.location_city), items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _selectedCity = v)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: _selectedStatus, decoration: _inputDecor("Ton statut", Icons.badge), items: _statusOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _selectedStatus = v)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: _selectedGoal, decoration: _inputDecor("Je cherche surtout à...", Icons.search), items: _goals.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _selectedGoal = v)),
          const SizedBox(height: 16),
          TextField(controller: _dateController, readOnly: true, onTap: _selectDate, decoration: _inputDecor("Date d'arrivée", Icons.calendar_today)),
        ],
      ),
    );
  }

  // --- PAGE 3 : SUGGESTIONS (MODIFIÉE) ---
  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text("Compte créé !", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("Voici des PVTistes à $_selectedCity qui pourraient t'intéresser :", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          if (_similarProfiles.isEmpty)
            const Text("Tu es le premier ici ! 🎉")
          else
            SizedBox(
              height: 150, // Un peu plus haut pour le confort
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _similarProfiles.length,
                itemBuilder: (context, index) {
                  final p = _similarProfiles[index];
                  // --- C'EST ICI QU'ON REND CLIQUABLE ---
                  return GestureDetector(
                    onTap: () {
                      // Ouvre la page du profil
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OtherProfilePage(userId: p['id']),
                        ),
                      );
                    },
                    child: Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 15),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                        border: Border.all(color: Colors.grey.shade200)
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30, 
                            backgroundImage: NetworkImage(p['avatar_url'] ?? ''),
                          ),
                          const SizedBox(height: 8),
                          Text(p['first_name'], style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          Text(p['status'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          const Icon(Icons.arrow_forward, size: 14, color: Color(0xFFFF6B00)) // Petit indicateur visuel
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("Commencer l'aventure", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentPage > 0 
          ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: _previousPage)
          : IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 10, height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _currentPage == index ? const Color(0xFFFF6B00) : Colors.grey.shade300),
          )),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            if (_currentPage < 2)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  width: double.infinity, height: 55,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF0055)]), borderRadius: BorderRadius.circular(16)),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _nextPage,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_currentPage == 0 ? "Suivant" : "Valider mon profil", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}