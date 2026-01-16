import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'transition_page.dart'; // ✅ On importe la page d'animation de fin

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

  // Listes d'options
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _statusOptions = ['PVTiste', 'Expatrié', 'Étudiant', 'Touriste', 'Local'];

  // --- LOGIQUE DE NAVIGATION ---
  void _nextPage() {
    FocusScope.of(context).unfocus(); // Ferme le clavier pour voir le bouton

    // Validation Etape 1 : Identité
    if (_currentPage == 0) {
      if (_firstNameController.text.isEmpty || _ageController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dis-nous comment tu t\'appelles !')));
        return;
      }
    } 
    // Validation Etape 2 : Compte
    else if (_currentPage == 1) { 
       if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email et mot de passe requis')));
        return;
      }
    } 
    // Validation Etape 3 : Détails (DERNIÈRE ÉTAPE)
    else if (_currentPage == 2) { 
      if (_selectedCity == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis ta ville !')));
        return;
      }
      // C'EST ICI QU'ON LANCE L'INSCRIPTION FINALE
      _signUpAndNavigate(); 
      return;
    }

    // Si on n'est pas à la fin, on avance
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

  // --- LOGIQUE D'INSCRIPTION ET REDIRECTION ---
  Future<void> _signUpAndNavigate() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Création du compte Auth (Email/MDP)
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'first_name': _firstNameController.text.trim(), 'city': _selectedCity},
      );
      
      if (res.user != null) {
        // 2. Création de la fiche Profil dans la base de données
        await Supabase.instance.client.from('profiles').upsert({
          'id': res.user!.id,
          'first_name': _firstNameController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 18,
          'city': _selectedCity,
          'status': _selectedStatus,
          // Avatar généré automatiquement avec les couleurs de l'appli
          'avatar_url': "https://api.dicebear.com/9.x/initials/png?seed=${_firstNameController.text}&backgroundColor=FF6B00&textColor=ffffff",
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        // 3. SUCCÈS : On redirige vers la TransitionPage ! 🚀
        if (mounted) {
           Navigator.pushReplacement( // On remplace pour ne pas pouvoir revenir en arrière
            context,
            MaterialPageRoute(
              builder: (context) => TransitionPage(
                userName: _firstNameController.text.trim()
              )
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

  // --- INTERFACE (DESIGN) ---

  Widget _buildHeader() {
    // On affiche "Étape X/3" maintenant (plus que 3 étapes)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: _previousPage),
              Text("Étape ${_currentPage + 1}/3", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              const SizedBox(width: 48), 
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / 3, // Sur 3 étapes
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFFFF6B00), // Orange Nora
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
        const Center(child: Text("NORA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3436)))),
        
        const SizedBox(height: 40),
        const Text("Comment tu t'appelles ?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        const SizedBox(height: 10),
        const Text("Choisis le prénom que la communauté verra.", style: TextStyle(fontSize: 16, color: Colors.grey)),
        
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
        const SizedBox(height: 10),
        const Text("Tes identifiants pour te connecter plus tard.", style: TextStyle(fontSize: 16, color: Colors.grey)),
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
        const Text("Dis-nous où tu es pour trouver du monde.", style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 30),

        DropdownButtonFormField(
          value: _selectedCity,
          decoration: InputDecoration(
            filled: true, 
            fillColor: Colors.white, 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
            prefixIcon: const Icon(Icons.location_city, color: Colors.grey)
          ),
          items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedCity = v as String?),
          hint: const Text("Quelle ville ?"),
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField(
          value: _selectedStatus,
          decoration: InputDecoration(
            filled: true, 
            fillColor: Colors.white, 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
            prefixIcon: const Icon(Icons.badge, color: Colors.grey)
          ),
          items: _statusOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedStatus = v as String?),
          hint: const Text("Ton statut (Ex: PVTiste)"),
        ),
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
            _buildHeader(), // Barre de progression
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Empêche de swiper manuellement
                children: [
                  _buildStep1_Identity(),
                  _buildStep2_Account(),
                  _buildStep3_Details(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: NoraButton(
                // Change le texte du bouton à la dernière étape
                text: _currentPage == 2 ? "Valider et Commencer 🚀" : "Continuer",
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