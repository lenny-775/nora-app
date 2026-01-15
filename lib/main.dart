import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';
import 'pages/splash_screen.dart'; // AJOUT : Import du Splash Screen

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
      
      // --- CONFIGURATION LANGUE ---
      supportedLocales: const [
        Locale('fr', 'FR'), 
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // --- CHANGEMENT ICI : On démarre sur le Splash Screen ---
      home: const SplashScreen(),

      // --- ROUTES ---
      // Le Splash Screen utilise ces noms pour naviguer
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(), // J'ai ajouté const pour optimiser
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}