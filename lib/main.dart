import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import 'login_page.dart';
import 'petugas_dashboard.dart';
import 'warga_dashboard.dart';

// --- KODE BARU ---
// Fungsi wajib untuk menangkap notifikasi saat aplikasi ditutup total (Background)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Daftarkan fungsi background dan inisialisasi notifikasi
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService().initNotification();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Trash Node',
      debugShowCheckedModeBanner: false,
      // --- KUNCI TEMA GLOBAL DI SINI ---
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Warna background seluruh app
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669), // Emerald Green
          primary: const Color(0xFF059669),
          surface: Colors.white,
        ),
        // Mengubah seluruh font aplikasi menjadi Poppins secara otomatis
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: const Color(0xFF0F172A),
          displayColor: const Color(0xFF0F172A),
        ),
        // Mengunci gaya tombol utama (ElevatedButton) untuk seluruh halaman
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        // Mengunci gaya kartu (Card)
        // Mengunci gaya kartu (Card)
        // Mengunci gaya kartu (Card)
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
        ),
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