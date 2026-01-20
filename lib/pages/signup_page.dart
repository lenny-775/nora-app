import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart'; 
import 'home_page.dart'; 

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _darkText = const Color(0xFF2D3436);

  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  
  String? _selectedCity;
  String? _selectedStatus;
  final List<String> _selectedGoals = []; 

  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _statusOptions = ['PVTiste', 'Expatrié', 'Étudiant', 'Touriste', 'Local'];
  final List<String> _goals = [
    '👋 Rencontrer du monde', '💼 Trouver un job', '🏠 Trouver un logement', 
    '🍻 Boire des verres', '📍 Découvrir la ville', '🎨 Juste curieux'
  ];

  // --- NOUVELLE FONCTION : POP-UP STYLÉE ---
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _creamyOrange.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.gpp_maybe_rounded, size: 36, color: _creamyOrange),
              ),
              const SizedBox(height: 20),
              
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 10),
              
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _creamyOrange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text(
                    "C'est noté !",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NAVIGATION (MODIFIÉE POUR VÉRIFIER LE MDP) ---
  void _nextPage() {
    FocusScope.of(context).unfocus();
    
    // ÉTAPE 1 : Identité
    if (_currentPage == 0) {
      if (_firstNameController.text.isEmpty || _ageController.text.isEmpty) { 
        _showSnack('Champs manquants'); return; 
      }
    } 
    // ÉTAPE 2 : Compte (VÉRIFICATION SÉCURITÉ)
    else if (_currentPage == 1) {
       // 1. Vérification si vide
       if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _phoneController.text.isEmpty) { 
         _showSnack('Tout est requis'); return; 
       }
       
       // 2. Vérification longueur mot de passe
       if (_passwordController.text.length < 8) {
         _showErrorDialog(
           "Mot de passe trop court", 
           "Pour ta sécurité, ton mot de passe doit contenir au moins 8 caractères."
         );
         return; // On bloque ici
       }
    } 
    // ÉTAPE 3 : Localisation
    else if (_currentPage == 2) {
      if (_selectedCity == null || _selectedStatus == null) { _showSnack('Dis-nous en plus !'); return; }
    } 
    // ÉTAPE 4 : Objectifs
    else if (_currentPage == 3) {
      if (_selectedGoals.isEmpty) { _showSnack('Choisis un objectif'); return; }
      _signUpAndNavigate(); return;
    }

    _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutQuart);
    setState(() => _currentPage++);
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage == 0) Navigator.pop(context);
    else {
      _pageController.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutQuart);
      setState(() => _currentPage--);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));

  Future<void> _signUpAndNavigate() async {
    setState(() => _isLoading = true);
    try {
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'first_name': _firstNameController.text.trim(), 'city': _selectedCity, 'phone': _phoneController.text.trim()},
      );
      if (res.user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': res.user!.id,
          'first_name': _firstNameController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 18,
          'city': _selectedCity,
          'status': _selectedStatus,
          'phone': _phoneController.text.trim(),
          'looking_for': _selectedGoals.join(', '),
          'avatar_url': "https://api.dicebear.com/9.x/initials/png?seed=${_firstNameController.text}&backgroundColor=FF914D&textColor=ffffff",
          'updated_at': DateTime.now().toIso8601String(),
        });
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GroupJoinPage(userCity: _selectedCity!)));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showSnack("Erreur: $e");
    }
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader() {
    double progress = (_currentPage + 1) / 4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            onPressed: _previousPage,
            color: _darkText,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: progress),
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: value, backgroundColor: Colors.grey.shade200, color: _creamyOrange, minHeight: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillField({required TextEditingController controller, required String hint, required IconData icon, bool isNumber = false, bool isPassword = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))]),
      child: TextField(
        controller: controller, obscureText: isPassword, keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(icon, color: Colors.grey.shade400, size: 22)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _creamyOrange, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildPillDropdown({required String? value, required String hint, required IconData icon, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), 
        boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
        isExpanded: true,
        style: TextStyle(color: _darkText, fontWeight: FontWeight.w600, fontSize: 16),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(20),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(icon, color: Colors.grey.shade400, size: 22)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _creamyOrange, width: 1.5)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // --- PAGES CENTRÉES ET REMPLIES ---

  Widget _buildStep1_Identity() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 180, child: Lottie.asset('assets/animations/hello.json', fit: BoxFit.contain)),
            const SizedBox(height: 20),
            Text("Enchanté !", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _darkText), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text("On commence par les présentations. Qui es-tu ?", style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4), textAlign: TextAlign.center)),
            const SizedBox(height: 40),
            _buildPillField(controller: _firstNameController, hint: "Ton prénom", icon: Icons.person_outline_rounded),
            _buildPillField(controller: _ageController, hint: "Ton âge", icon: Icons.cake_outlined, isNumber: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2_Account() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(height: 180, child: Lottie.asset('assets/animations/login.json', fit: BoxFit.contain)),
            const SizedBox(height: 20),
            Text("Sécurité", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _darkText), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text("Crée tes identifiants pour sécuriser ton compte.", style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4), textAlign: TextAlign.center)),
            const SizedBox(height: 40),
            _buildPillField(controller: _emailController, hint: "Ton email", icon: Icons.email_outlined),
            _buildPillField(controller: _phoneController, hint: "Ton téléphone", icon: Icons.phone_android_rounded, isNumber: true),
            _buildPillField(controller: _passwordController, hint: "Mot de passe", icon: Icons.lock_outline_rounded, isPassword: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3_Details() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(height: 180, child: Lottie.asset('assets/animations/paperplane.json', fit: BoxFit.contain)),
            const SizedBox(height: 20),
            Text("Localisation", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _darkText), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text("Où se passe ton aventure actuellement ?", style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4), textAlign: TextAlign.center)),
            const SizedBox(height: 40),
            _buildPillDropdown(value: _selectedCity, hint: "Quelle ville ?", icon: Icons.location_city_rounded, items: _cities, onChanged: (v) => setState(() => _selectedCity = v)),
            _buildPillDropdown(value: _selectedStatus, hint: "Ton statut", icon: Icons.badge_outlined, items: _statusOptions, onChanged: (v) => setState(() => _selectedStatus = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4_Goals() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20), 
            Text(
              "Tes Objectifs", 
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _darkText), 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                "Dis-nous ce qui t'amène ici.", 
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4), 
                textAlign: TextAlign.center
              ),
            ),
            const SizedBox(height: 40),
            ..._goals.map((goal) {
              final isSelected = _selectedGoals.contains(goal);
              return GestureDetector(
                onTap: () => setState(() => isSelected ? _selectedGoals.remove(goal) : _selectedGoals.add(goal)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: isSelected ? _creamyOrange : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 2))],
                    border: Border.all(color: isSelected ? _creamyOrange : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal, 
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : _darkText
                          )
                        )
                      ),
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined, 
                        color: isSelected ? Colors.white : Colors.grey.shade300
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextPage,
                  style: ElevatedButton.styleFrom(backgroundColor: _creamyOrange, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_currentPage == 3 ? "C'est parti ! 🚀" : "Continuer", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupJoinPage extends StatefulWidget {
  final String userCity;
  const GroupJoinPage({super.key, required this.userCity});
  @override
  State<GroupJoinPage> createState() => _GroupJoinPageState();
}

class _GroupJoinPageState extends State<GroupJoinPage> {
  bool _joining = false;
  final Color _creamyOrange = const Color(0xFFFF914D);
  Future<void> _joinCityGroup() async {
    setState(() => _joining = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomePage()), (route) => false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_rounded, size: 100, color: _creamyOrange),
            const SizedBox(height: 20),
            Text("Bienvenue à ${widget.userCity} !", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2D3436)), textAlign: TextAlign.center),
            const SizedBox(height: 15),
            Text("Rejoins le groupe de ta ville pour rencontrer les autres membres.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5)),
            const SizedBox(height: 50),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _joining ? null : _joinCityGroup, style: ElevatedButton.styleFrom(backgroundColor: _creamyOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _joining ? const CircularProgressIndicator(color: Colors.white) : const Text("Rejoindre le groupe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)))),
            const SizedBox(height: 20),
            TextButton(onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomePage()), (r) => false), child: Text("Passer pour le moment", style: TextStyle(color: Colors.grey.shade500)))
          ],
        ),
      ),
    );
  }
}