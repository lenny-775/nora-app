import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// AJOUT ICI : Import pour les langues
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rguwsummytxcysrksgaf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJndXdzdW1teXR4Y3lzcmtzZ2FmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzNzY3MzIsImV4cCI6MjA4Mzk1MjczMn0.7ljOdyyyPdd8THHL1DxwLKD3UDFlv-ksnnCCGuIxpmM',
  );

  runApp(const NoraApp());
}

class NoraApp extends StatelessWidget {
  const NoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NORA',
      debugShowCheckedModeBanner: false,
      
      // --- DÉBUT CONFIGURATION LANGUE ---
      // On autorise le Français et l'Anglais
      supportedLocales: const [
        Locale('fr', 'FR'), 
        Locale('en', 'US'),
      ],
      // On charge les outils de traduction de Flutter
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // --- FIN CONFIGURATION LANGUE ---

      home: const AuthGate(),
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) return HomePage();
    return WelcomePage();
  }
}