import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'other_profile_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Variables
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _dateController = TextEditingController();
  
  String? _selectedCity;
  String? _selectedStatus;
  String? _selectedGoal;
  DateTime? _arrivalDate;

  // Listes d'options
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _statusOptions = ['PVTiste', 'Expatrié', 'Étudiant', 'Touriste', 'Local'];
  final List<String> _goals = ['Rencontrer du monde', 'Trouver un job', 'Trouver un logement', 'Boire des verres', 'Découvrir la ville'];
  List<Map<String, dynamic>> _similarProfiles = [];

  // --- LOGIQUE (Reste inchangée) ---
  void _nextPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage == 0) {
      if (_firstNameController.text.isEmpty || _ageController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dis-nous comment tu t\'appelles !')));
        return;
      }
    } else if (_currentPage == 1) { // Email & MDP
       if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email et mot de passe requis')));
        return;
      }
    } else if (_currentPage == 2) { // Info Canada
      if (_selectedCity == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis ta ville !')));
        return;
      }
      _signUpAndFetchProfiles();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentPage++);
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage == 0) {
      Navigator.pop(context);
    } else {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentPage--);
    }
  }

  Future<void> _signUpAndFetchProfiles() async {
    setState(() => _isLoading = true);
    try {
      // Inscription Supabase
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'first_name': _firstNameController.text.trim(), 'city': _selectedCity},
      );
      
      if (res.user != null) {
        // Création profil
        await Supabase.instance.client.from('profiles').upsert({
          'id': res.user!.id,
          'first_name': _firstNameController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 18,
          'city': _selectedCity,
          'status': _selectedStatus,
          'goal': _selectedGoal,
          'avatar_url': "https://api.dicebear.com/9.x/initials/png?seed=${_firstNameController.text}&backgroundColor=FF6B00&textColor=ffffff",
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        // Récupération profils similaires
        final profiles = await Supabase.instance.client.from('profiles').select().eq('city', _selectedCity!).neq('id', res.user!.id).limit(10);
        setState(() {
          _similarProfiles = List<Map<String, dynamic>>.from(profiles);
          _isLoading = false;
        });
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        setState(() => _currentPage = 3);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  // --- DESIGN (C'est ici que la magie opère) ---

  // Header personnalisé avec barre de progression
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: _previousPage),
              Text("Étape ${_currentPage + 1}/4", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              const SizedBox(width: 48), // Pour équilibrer l'icône retour
            ],
          ),
          const SizedBox(height: 10),
          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / 4,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFFFF5E62), // Rouge/Rose
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1_Identity() {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 20),
        // Petit logo centré
        Center(child: Icon(Icons.location_on, size: 40, color: Color(0xFFFF5E62))),
        Center(child: Text("NORA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3436)))),
        
        const SizedBox(height: 40),
        const Text("Comment tu t'appelles ?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        const SizedBox(height: 10),
        const Text("Choisis le prénom que la communauté verra.", style: TextStyle(fontSize: 16, color: Colors.grey)),
        
        const SizedBox(height: 40),
        NoraTextField(controller: _firstNameController, hintText: "Ton prénom", icon: Icons.person_outline),
        NoraTextField(controller: _ageController, hintText: "Ton âge", icon: Icons.cake_outlined, isNumber: true),
        
        const SizedBox(height: 20),
        const NoraInfoBox(text: "Utilise ton vrai prénom pour créer une vraie connexion avec la communauté."),
      ],
    );
  }

  Widget _buildStep2_Account() {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const Text("Sécurise ton compte", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        const SizedBox(height: 10),
        const Text("Tes identifiants pour te connecter plus tard.", style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 40),
        
        NoraTextField(controller: _emailController, hintText: "Ton adresse email", icon: Icons.email_outlined),
        NoraTextField(controller: _passwordController, hintText: "Mot de passe", icon: Icons.lock_outline, obscureText: true),
        
        const SizedBox(height: 20),
        const NoraInfoBox(text: "On ne t'enverra jamais de spam, promis !"),
      ],
    );
  }

  Widget _buildStep3_Details() {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const Text("Ton Aventure", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        const SizedBox(height: 10),
        const Text("Dis-nous où tu es pour trouver du monde.", style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 30),

        // Dropdowns simplifiés visuellement
        DropdownButtonFormField(
          value: _selectedCity,
          decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.location_city, color: Colors.grey)),
          items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedCity = v as String?),
          hint: const Text("Quelle ville ?"),
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField(
          value: _selectedStatus,
          decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.badge, color: Colors.grey)),
          items: _statusOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedStatus = v as String?),
          hint: const Text("Ton statut (Ex: PVTiste)"),
        ),
      ],
    );
  }

  Widget _buildStep4_Suggestions() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text("C'est tout bon !", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("Voici des gens à $_selectedCity :", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          
          if (_similarProfiles.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _similarProfiles.length,
                itemBuilder: (context, index) {
                   final p = _similarProfiles[index];
                   return GestureDetector(
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: p['id']))),
                     child: Container(
                       margin: const EdgeInsets.only(right: 15),
                       child: Column(children: [
                         CircleAvatar(radius: 30, backgroundImage: NetworkImage(p['avatar_url'] ?? '')),
                         const SizedBox(height: 5),
                         Text(p['first_name'], style: const TextStyle(fontWeight: FontWeight.bold))
                       ]),
                     ),
                   );
                },
              ),
            ),
          const Spacer(),
          NoraButton(text: "Commencer l'aventure", onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Le fond crème très léger de ton image
      backgroundColor: const Color(0xFFFFF8F5), 
      body: SafeArea(
        child: Column(
          children: [
            if (_currentPage < 3) _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1_Identity(),
                  _buildStep2_Account(),
                  _buildStep3_Details(),
                  _buildStep4_Suggestions(),
                ],
              ),
            ),
            if (_currentPage < 3)
              Padding(
                padding: const EdgeInsets.all(30),
                child: NoraButton(
                  text: "Continuer",
                  isLoading: _isLoading,
                  onPressed: _nextPage,
                ),
              ),
          ],
        ),
      ),
    );
  }
}