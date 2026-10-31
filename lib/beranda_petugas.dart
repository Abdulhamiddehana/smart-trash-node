import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';

class BerandaPetugas extends StatefulWidget {
  // --- KODE BARU: Callbacks untuk menyambungkan UI dengan Logika Utama ---
  final Function(dynamic key, dynamic data) onTerimaTugas;
  final Function(dynamic key, dynamic data) onBukaPeta;
  final Function(String key) onBatalTugas;
  final Function(String key) onSelesaiTugas;

  const BerandaPetugas({
    super.key,
    required this.onTerimaTugas,
    required this.onBukaPeta,
    required this.onBatalTugas,
    required this.onSelesaiTugas,
  });

  @override
  State<BerandaPetugas> createState() => _BerandaPetugasState();
}

class _BerandaPetugasState extends State<BerandaPetugas> {
  String _namaPetugas = "Petugas";
  String? _base64ProfileImage;

  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://smart-trash-node-default-rtdb.asia-southeast1.firebasedatabase.app'
  );

  @override
  void initState() {
    super.initState();
    _ambilNamaPetugas();
  }

  Future<void> _ambilNamaPetugas() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final snapshot = await _database.ref('data_petugas/$uid').get();
      if (snapshot.exists && mounted) {
        setState(() {
          var data = snapshot.value as Map<dynamic, dynamic>;
          _namaPetugas = data['nama']?.toString() ?? "Petugas";
          _base64ProfileImage = data['foto_profil']?.toString();
        });
      }
      
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _database.ref('data_petugas/$uid/fcm_token').set(token);
      }
    }
  }

  Future<void> _gantiFotoProfil() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: 200, maxHeight: 200, imageQuality: 50,
    );
    if (image != null) {
      File file = File(image.path);
      List<int> imageBytes = await file.readAsBytes();
      String base64String = base64Encode(imageBytes);
      String uid = FirebaseAuth.instance.currentUser!.uid;
      
      await _database.ref('data_petugas/$uid/foto_profil').set(base64String);
      setState(() { _base64ProfileImage = base64String; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto profil diperbarui!'), 
            backgroundColor: const Color(0xFF059669), 
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      }
    }
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  void _logout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            child: Row(
              children: [
                const Icon(Icons.list_alt_rounded, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                const Text('Antrean Tugas Masuk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
              ],
            ),
          ),
        ),
        StreamBuilder(
          stream: _database.ref('panggilan').orderByChild('id_petugas').equalTo(FirebaseAuth.instance.currentUser?.uid).onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator(color: Color(0xFF059669)))));
            }
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFF059669)),
                      ),
                      const SizedBox(height: 24),
                      const Text('Area Bersih!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                      const SizedBox(height: 8),
                      const Text('Belum ada panggilan penjemputan masuk.\nWaktunya bersantai!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.6)),
                    ],
                  ),
                ),
              );
            }

            Map<dynamic, dynamic> panggilanMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            List<MapEntry<dynamic, dynamic>> listPanggilan = panggilanMap.entries.toList();

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    var key = listPanggilan[index].key;
                    var data = listPanggilan[index].value;
                    return _buildTugasCard(key, data);
                  },
                  childCount: listPanggilan.length,
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF10B981),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF047857), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _gantiFotoProfil,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white.withOpacity(0.15),
                              backgroundImage: _base64ProfileImage != null ? MemoryImage(base64Decode(_base64ProfileImage!)) : null,
                              child: _base64ProfileImage == null ? const Icon(Icons.person_rounded, color: Colors.white, size: 34) : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF6EE7B7), shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text('Driver Aktif', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_getGreeting(), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15)),
                              Text(_namaPetugas, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15), 
                        borderRadius: BorderRadius.circular(16), 
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTugasCard(dynamic key, dynamic data) {
    bool isDiproses = data['status_pesanan'] == 'proses';
    Color badgeColor = isDiproses ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    Color badgeBgColor = isDiproses ? const Color(0xFF3B82F6).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDiproses ? badgeColor.withOpacity(0.3) : Colors.grey.withOpacity(0.15), width: isDiproses ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22))
            ),
            child: Row(
              children: [
                Icon(isDiproses ? Icons.local_shipping_rounded : Icons.local_fire_department_rounded, color: badgeColor, size: 20),
                const SizedBox(width: 8),
                Text(isDiproses ? 'SEDANG DIJEMPUT' : 'TUGAS BARU', style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                const Spacer(),
                Icon(Icons.more_horiz_rounded, color: badgeColor.withOpacity(0.5)),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    data['foto_pengirim'] != null
                      ? CircleAvatar(
                          radius: 26,
                          backgroundImage: MemoryImage(base64Decode(data['foto_pengirim'])),
                        )
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF0F172A).withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.person_rounded, color: Colors.grey, size: 28),
                        ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pelapor', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(data['pengirim'] ?? 'Warga', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9))),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Titik Jemput (GPS)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text('${data['lokasi']}', style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                if (!isDiproses)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      // --- KODE BARU: Melempar tugas ini ke file Dashboard Utama ---
                      onPressed: () => widget.onTerimaTugas(key, data),
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Terima & Buka Peta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                          // --- KODE BARU: Melempar ke Dashboard Utama ---
                          onPressed: () => widget.onBukaPeta(key, data),
                          icon: const Icon(Icons.navigation_rounded),
                          label: const Text('Buka Peta Navigasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                              ),
                              // --- KODE BARU: Melempar ke Dashboard Utama ---
                              onPressed: () => widget.onBatalTugas(key.toString()),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                              ),
                              // --- KODE BARU: Melempar ke Dashboard Utama ---
                              onPressed: () => widget.onSelesaiTugas(key.toString()),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}