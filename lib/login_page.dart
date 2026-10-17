import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'petugas_dashboard.dart';
import 'warga_dashboard.dart';
import 'package:firebase_core/firebase_core.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://smart-trash-node-default-rtdb.asia-southeast1.firebasedatabase.app'
  );

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // Ambil teks input dan pastikan format emailnya benar
      String inputText = _emailController.text.trim();
      String finalEmail = inputText.contains('@') ? inputText : '$inputText@gmail.com';

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
          email: finalEmail,
          password: _passwordController.text.trim());

      String uid = userCredential.user!.uid;
      final snapshot = await _database.ref('users/$uid/role').get();

      if (snapshot.exists) {
        String role = snapshot.value.toString();
        if (!mounted) return;
        if (role == 'petugas') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PetugasDashboard()));
        } else if (role == 'warga') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const WargaDashboard()));
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal Login: ${e.message}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.recycling, size: 80, color: Colors.green),
                  ),
                  const SizedBox(height: 24),
                  const Text('Smart Trash Node', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                  const Text('Login untuk melanjutkan', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person_outline),
                      suffixText: '@gmail.com', // Memberikan petunjuk visual di akhir kolom
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2),
                    onPressed: _login,
                    child: const Text('MASUK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}