import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_page.dart';
import 'petugas_dashboard.dart';
import 'warga_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Trash Node',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)), 
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const AuthWrapper(),
    );
  }
}

// LOGIKA OTOMATIS PENGECEKAN LOGIN
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Widget _currentWidget = const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _currentWidget = const LoginPage());
      return;
    }

    try {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://smart-trash-node-default-rtdb.asia-southeast1.firebasedatabase.app'
      );
      final snapshot = await db.ref('users/${user.uid}/role').get();
      
      if (snapshot.exists) {
        String role = snapshot.value.toString();
        if (role == 'petugas') {
          setState(() => _currentWidget = const PetugasDashboard());
        } else if (role == 'warga') {
          setState(() => _currentWidget = const WargaDashboard());
        } else {
          setState(() => _currentWidget = const LoginPage());
        }
      } else {
        FirebaseAuth.instance.signOut();
        setState(() => _currentWidget = const LoginPage());
      }
    } catch (e) {
      setState(() => _currentWidget = const LoginPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _currentWidget;
  }
}