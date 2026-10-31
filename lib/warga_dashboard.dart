import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import 3 Halaman Anak (Child Pages)
import 'beranda_warga.dart';
import 'peta_warga.dart';
import 'riwayat_warga.dart';

class WargaDashboard extends StatefulWidget {
  const WargaDashboard({super.key});

  @override
  State<WargaDashboard> createState() => _WargaDashboardState();
}

class _WargaDashboardState extends State<WargaDashboard> {
  DateTime? _lastPressedAt;
  
  // Variabel untuk melacak menu yang aktif
  int _selectedIndex = 0; 

  @override
  Widget build(BuildContext context) {
    // Membuat status bar transparan
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.light
    ));

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tekan kembali sekali lagi untuk keluar', textAlign: TextAlign.center),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              margin: const EdgeInsets.only(bottom: 20, left: 50, right: 50),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        
        // Memisahkan tampilan berdasarkan menu yang dipilih (Modular)
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            BerandaWarga(),   // Index 0: Memanggil dari beranda_warga.dart
            PetaWarga(),      // Index 1: Memanggil dari peta_warga.dart
            RiwayatWarga(),   // Index 2: Memanggil dari riwayat_warga.dart
          ],
        ),
        
        // Memanggil Bottom Navigation
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // --- DESAIN BOTTOM NAVIGATION BAR ---
  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (int index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFF059669).withOpacity(0.2), // Warna hover hijau transparan
      elevation: 10,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF059669)),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map_rounded, color: Color(0xFF059669)),
          label: 'Peta',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history_rounded, color: Color(0xFF059669)),
          label: 'Riwayat',
        ),
      ],
    );
  }
}