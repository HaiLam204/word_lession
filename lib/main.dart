import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDp64EGR6nMbfMonQ7PFQMmFOQk8wC14XY",
        authDomain: "wordlession.firebaseapp.com",
        databaseURL: "https://wordlession-default-rtdb.asia-southeast1.firebasedatabase.app",
        projectId: "wordlession",
        storageBucket: "wordlession.firebasestorage.app",
        messagingSenderId: "414162632829",
        appId: "1:414162632829:web:b8ff721bc13b4dec13b114",
        measurementId: "G-RWF3WSSB2T",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const WordLessionApp());
}

class WordLessionApp extends StatelessWidget {
  const WordLessionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WordLession',
      theme: ThemeData(
        primaryColor: const Color(0xFF27CEAF),
        scaffoldBackgroundColor: const Color(0xFFF6F7F8),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}