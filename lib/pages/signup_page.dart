import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'transition_page.dart'; 

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Variables du formulaire
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  
  String? _selectedCity;
  String? _selectedStatus;
  
  // MODIFICATION ICI : Une liste pour stocker plusieurs choix
  final List<String> _selectedGoals = []; 

  // Listes d'options
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _statusOptions = ['PVTiste', 'Expatrié', 'Étudiant', 'Touriste', 'Local'];
  
  final List<String> _goals = [
    '👋 Rencontrer du monde',
    '💼 Trouver un job',
    '🏠 Trouver un logement',
    '🍻 Boire des verres',
    '📍 Découvrir la ville',
    '🎨 Juste curieux'
  ];

  // --- LOGIQUE DE NAVIGATION ---
  void _nextPage() {
    FocusScope.of(context).unfocus();

    if (_currentPage == 0) { // Identité
      if (_firstNameController.text.isEmpty || _ageController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dis-nous comment tu t\'appelles !')));
        return;
      }
    } else if (_currentPage == 1) { // Compte
       if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email et mot de passe requis')));
        return;
      }
    } else if (_currentPage == 2) { // Ville & Statut
      if (_selectedCity == null || _selectedStatus == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tout les champs sont obligatoires !')));
        return;
      }
    } else if (_currentPage == 3) { // Goal (Dernière étape)
      // On vérifie que la liste n'est pas vide
      if (_selectedGoals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis au moins une motivation !')));
        return;
      }
      _signUpAndNavigate(); 
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

  // --- LOGIQUE D'INSCRIPTION ---
  Future<void> _signUpAndNavigate() async {
    setState(() => _isLoading = true);
    
    try {
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'first_name': _firstNameController.text.trim(), 'city': _selectedCity},
      );
      
      if (res.user != null) {
        // On transforme la liste ["Job", "Potes"] en une seule phrase "Job, Potes"
        final goalsString = _selectedGoals.join(', ');

        await Supabase.instance.client.from('profiles').upsert({
          'id': res.user!.id,
          'first_name': _firstNameController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 18,
          'city': _selectedCity,
          'status': _selectedStatus,
          'looking_for': goalsString, // <--- On sauvegarde la version texte combinée
          'avatar_url': "https://api.dicebear.com/9.x/initials/png?seed=${_firstNameController.text}&backgroundColor=FF6B00&textColor=ffffff",
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        if (mounted) {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TransitionPage(userName: _firstNameController.text.trim())
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Oups: $e")));
      }
    }
  }

  // --- INTERFACE ---

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
              const SizedBox(width: 48), 
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / 4,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFFFF6B00),
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
        const Center(child: Icon(Icons.location_on, size: 40, color: Color(0xFFFF6B00))),
        const SizedBox(height: 40),
        const Text("Comment tu t'appelles ?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        const SizedBox(height: 10),
        const Text("Ton identité sur NORA.", style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 40),
        NoraTextField(controller: _firstNameController, hintText: "Ton prénom", icon: Icons.person_outline),
        NoraTextField(controller: _ageController, hintText: "Ton âge", icon: Icons.cake_outlined, isNumber: true),
      ],
    );
  }

  Widget _buildStep2_Account() {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const Text("Sécurise ton compte", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        const SizedBox(height: 40),
        NoraTextField(controller: _emailController, hintText: "Ton adresse email", icon: Icons.email_outlined),
        NoraTextField(controller: _passwordController, hintText: "Mot de passe", icon: Icons.lock_outline, obscureText: true),
      ],
    );
  }

  Widget _buildStep3_Details() {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const Text("Ton Aventure", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        const SizedBox(height: 10),
        const Text("Dis-nous où tu es.", style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 30),

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

  // VERSION MULTI-SELECT
  Widget _buildStep4_Goals() {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const Text("Que recherches-tu ?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        const SizedBox(height: 10),
        const Text("Sélectionne tout ce qui t'intéresse (plusieurs choix possibles).", style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 30),

        ..._goals.map((goal) {
          // On regarde si c'est DANS la liste
          final isSelected = _selectedGoals.contains(goal);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedGoals.remove(goal); // On décoche
                } else {
                  _selectedGoals.add(goal); // On coche
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF6B00).withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF6B00) : Colors.transparent,
                  width: 2
                ),
                boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Expanded(child: Text(goal, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF2D3436)))),
                  
                  // On change l'icône : Rond vide ou Rond coché
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? const Color(0xFFFF6B00) : Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5), 
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1_Identity(),
                  _buildStep2_Account(),
                  _buildStep3_Details(),
                  _buildStep4_Goals(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: NoraButton(
                text: _currentPage == 3 ? "Valider et Commencer 🚀" : "Continuer",
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