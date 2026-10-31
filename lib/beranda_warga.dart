import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';

class BerandaWarga extends StatefulWidget {
  const BerandaWarga({super.key});

  @override
  State<BerandaWarga> createState() => _BerandaWargaState();
}

class _BerandaWargaState extends State<BerandaWarga> {
  String? _petugasSedangDiproses;
  final Set<String> _petugasBerhasilDipanggil = {};
  String _namaWarga = "Warga";
  bool _hasActiveCall = false;
  String? _base64ProfileImage;
  String _idAlat = "node_1";

  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://smart-trash-node-default-rtdb.asia-southeast1.firebasedatabase.app'
  );

  @override
  void initState() {
    super.initState();
    _ambilNamaWarga();
  }

  Future<void> _ambilNamaWarga() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await _database.ref('users/$uid').get();
    if (snapshot.exists) {
      if (mounted) {
        setState(() {
          var data = snapshot.value as Map<dynamic, dynamic>;
          _namaWarga = data['nama']?.toString() ?? "Warga";
          _base64ProfileImage = data['foto_profil']?.toString();
          if (data['id_alat'] != null) {
            _idAlat = data['id_alat'].toString();
          }
        });
        _cekPanggilanAktif();
      }
      
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _database.ref('users/$uid/fcm_token').set(token);
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
      
      await _database.ref('users/$uid/foto_profil').set(base64String);
      setState(() { _base64ProfileImage = base64String; });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto profil berhasil diperbarui!'),
            backgroundColor: const Color(0xFF059669),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  void _cekPanggilanAktif() {
    _database.ref('panggilan').onValue.listen((event) {
      if (!mounted) return;
      bool hasCall = false;
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> panggilanMap = event.snapshot.value as Map<dynamic, dynamic>;
        for (var call in panggilanMap.values) {
          if (call['pengirim'] == _namaWarga) {
            hasCall = true;
            break;
          }
        }
      }
      setState(() { _hasActiveCall = hasCall; });
    });
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  void _tampilkanDialogKonfirmasi(BuildContext context, String idPetugas, String namaPetugas) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Kirim Panggilan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Text(
          'Anda akan memanggil petugas bernama $namaPetugas.\n\nSistem akan otomatis membagikan koordinat GPS Anda agar petugas tiba dengan akurat.',
          style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey[700]),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
            ),
            onPressed: () {
              Navigator.pop(context);
              _kirimPanggilan(idPetugas, namaPetugas);
            },
            child: const Text('Kirim Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _kirimPanggilan(String idPetugas, String namaPetugas) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showSnackBar('Nyalakan GPS/Lokasi HP kamu dulu ya!', const Color(0xFFEF4444), Icons.location_off);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showSnackBar('Izin lokasi ditolak!', const Color(0xFFEF4444), Icons.error_outline);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showSnackBar('Izin lokasi ditolak permanen. Buka pengaturan HP.', const Color(0xFFEF4444), Icons.error_outline);
      return;
    }

    setState(() => _petugasSedangDiproses = idPetugas);

    try {
      Position posisi = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
      String lokasiWarga = "Titik GPS: ${posisi.latitude}, ${posisi.longitude}";
      String uidWarga = FirebaseAuth.instance.currentUser!.uid; 

      await _database.ref('panggilan').push().set({
        'id_warga': uidWarga,
        'pengirim': _namaWarga,
        'foto_pengirim': _base64ProfileImage,
        'id_petugas': idPetugas,
        'nama_petugas': namaPetugas,
        'id_alat': _idAlat,
        'lokasi': lokasiWarga,
        'lat': posisi.latitude,
        'lng': posisi.longitude,
        'pesan': "Tempat sampah sudah penuh, mohon segera diangkut.",
        'waktu': DateTime.now().toString(),
      });
      
      DataSnapshot snapshot = await _database.ref('data_petugas/$idPetugas/fcm_token').get();
      if (snapshot.exists) {
        String tokenPetugas = snapshot.value.toString();
        Uri urlAPI = Uri.parse('https://admin.dehans.web.id/api/send-notif');
        http.post(urlAPI, body: {
          'token': tokenPetugas,
          'title': 'Panggilan Penjemputan!',
          'body': 'Lokasi: $_namaWarga meminta penjemputan sampah.',
        });
      }

      if (mounted) {
        setState(() {
          _petugasSedangDiproses = null;
          _petugasBerhasilDipanggil.add(idPetugas);
        });
        _showSnackBar('Berhasil! $namaPetugas segera menuju ke lokasimu.', const Color(0xFF059669), Icons.check_circle_outline);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _petugasSedangDiproses = null);
        _showSnackBar('Gagal mengirim data / GPS lambat mencari titik.', const Color(0xFFEF4444), Icons.wifi_off);
      }
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 4),
      )
    );
  }

  void _logout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildPremiumHeader(),
        SliverToBoxAdapter(
          child: Stack(
            children: [
              Container(
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF047857)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrashStatusCard(), 
                    _buildActiveCallStatus(),
                    if (!_hasActiveCall) ...[
                      const SizedBox(height: 36),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Panggil Petugas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                              SizedBox(height: 4),
                              Text('Daftar pahlawan kebersihan area Anda', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.people_alt_rounded, color: Color(0xFF059669), size: 22),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!_hasActiveCall) _buildPetugasList(),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildPremiumHeader() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: false,
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
                              Text('Pantau & Panggil Petugas', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(_getGreeting(), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15)),
                              Text(_namaWarga, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
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

  Widget _buildTrashStatusCard() {
    return StreamBuilder(
      stream: _database.ref('sensor/$_idAlat/jarak').onValue,
      builder: (context, snapshot) {
        // Jika data belum ada, kita anggap tempat sampah kosong (60 cm)
        final jarakStr = snapshot.data?.snapshot.value?.toString() ?? '60'; 
        double jarakVal = double.tryParse(jarakStr) ?? 60.0;

        // --- KODE YANG DIPERBAIKI: Sesuaikan dengan hardware ---
        double maxTinggi = 60.0; // Nilai kedalaman maksimal tempat sampah kamu
        
        // Rumus: (Tinggi Maks - Jarak Terbaca) / Tinggi Maks
        // .clamp(0.0, 1.0) mencegah nilai menjadi minus jika sensor error membaca > 60 cm
        double persentase = ((maxTinggi - jarakVal) / maxTinggi).clamp(0.0, 1.0);
        
        Color statusColor;
        String statusText;
        IconData statusIcon;

        if (persentase >= 0.85) { 
          statusColor = const Color(0xFFEF4444);
          statusText = 'Kapasitas Penuh!';
          statusIcon = Icons.warning_rounded;
        } else if (persentase >= 0.40) { // Sedikit penyesuaian batas tengah
          statusColor = const Color(0xFFF59E0B);
          statusText = 'Terisi Sebagian';
          statusIcon = Icons.delete_outline_rounded;
        } else {
          statusColor = const Color(0xFF059669);
          statusText = 'Masih Kosong';
          statusIcon = Icons.check_circle_outline_rounded;
        }

        // ... (Kode UI ke bawahnya tetap SAMA persis, tidak perlu diubah)

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1), 
                            borderRadius: BorderRadius.circular(18)
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded( 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Status Sensor', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(statusText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: statusColor), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$jarakStr cm', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -1)),
                ],
              ),
              const SizedBox(height: 32),
              
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: persentase),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.fastOutSlowIn,
                builder: (context, value, _) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 12,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kosong', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                          Text('${(value * 100).toInt()}% Terisi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: statusColor)),
                        ],
                      )
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveCallStatus() {
    return StreamBuilder(
      stream: _database.ref('panggilan').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SizedBox.shrink(); 
        }
        
        Map<dynamic, dynamic> panggilanMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        var myCalls = panggilanMap.entries.where((e) => e.value['pengirim'] == _namaWarga).toList();
        
        if (myCalls.isEmpty) return const SizedBox.shrink(); 

        return Column(
          children: myCalls.map((entry) {
            var data = entry.value;
            bool isDiproses = data['status_pesanan'] == 'proses';
            
            Color cardThemeColor = isDiproses ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
            
            return Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: cardThemeColor.withOpacity(0.2), width: 1.5),
                boxShadow: [BoxShadow(color: cardThemeColor.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardThemeColor.withOpacity(0.1),
                          shape: BoxShape.circle
                        ),
                        child: Icon(isDiproses ? Icons.local_shipping_rounded : Icons.access_time_filled_rounded, 
                                    color: cardThemeColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isDiproses ? 'Sedang Menuju Lokasi' : 'Menunggu Respons', 
                                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cardThemeColor)),
                            const SizedBox(height: 4),
                            Text('Petugas: ${data['nama_petugas']}', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    ],
                  ),
                  if (isDiproses) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(color: cardThemeColor.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined, color: cardThemeColor, size: 20),
                          const SizedBox(width: 8),
                          Text(data['estimasi_menit'] != null 
                              ? 'Tiba dalam: ${data['estimasi_menit']} Menit (${(data['jarak_meter'] / 1000).toStringAsFixed(1)} km)' 
                              : 'Menghitung estimasi...', 
                            style: TextStyle(color: cardThemeColor, fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        backgroundColor: cardThemeColor.withOpacity(0.15),
                        color: cardThemeColor,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text('Siapkan sampah, petugas sedang di perjalanan!', 
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic))
                    ),
                  ]
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPetugasList() {
    return StreamBuilder(
      stream: _database.ref('data_petugas').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF059669)),
                  const SizedBox(height: 16),
                  Text('Mencari petugas...', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        }

        Map<dynamic, dynamic> petugasMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        List<dynamic> listPetugas = petugasMap.entries.toList();

        listPetugas.sort((a, b) {
          String statusA = (a.value['status'] ?? '').toString().toLowerCase();
          String statusB = (b.value['status'] ?? '').toString().toLowerCase();
          if (statusA == 'ready' && statusB != 'ready') return -1;
          if (statusA != 'ready' && statusB == 'ready') return 1;
          return 0;
        });

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var idPetugas = listPetugas[index].key;
                var data = listPetugas[index].value;
                String statusPetugas = (data['status'] ?? 'unknown').toString().toLowerCase();
                bool isReady = statusPetugas == 'ready';
                
                String textStatus;
                Color colorStatus;
                
                if (statusPetugas == 'ready') {
                  textStatus = 'Siap Bertugas'; colorStatus = const Color(0xFF059669); 
                } else if (statusPetugas == 'sibuk') {
                  textStatus = 'Sedang Menjemput'; colorStatus = const Color(0xFF3B82F6); 
                } else if (statusPetugas == 'sakit') {
                  textStatus = 'Sakit'; colorStatus = const Color(0xFFEF4444); 
                } else if (statusPetugas == 'izin') {
                  textStatus = 'Izin'; colorStatus = const Color(0xFF64748B); 
                } else {
                  textStatus = 'Tidak Diketahui'; colorStatus = Colors.grey;
                }

                bool isProcessing = _petugasSedangDiproses == idPetugas;
                bool isSuccess = _petugasBerhasilDipanggil.contains(idPetugas);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border(left: BorderSide(color: colorStatus, width: 6)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: isReady && !isProcessing && !isSuccess ? () => _tampilkanDialogKonfirmasi(context, idPetugas, data['nama']) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: colorStatus.withOpacity(0.1),
                              backgroundImage: data['foto_profil'] != null ? MemoryImage(base64Decode(data['foto_profil'].toString())) : null,
                              child: data['foto_profil'] == null ? Text(data['nama'] != null ? data['nama'].toString().substring(0, 1).toUpperCase() : 'P', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: colorStatus)) : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorStatus.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.circle, size: 8, color: colorStatus),
                                        const SizedBox(width: 6),
                                        Text(textStatus, style: TextStyle(color: colorStatus, fontWeight: FontWeight.bold, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildActionBtn(isSuccess, isProcessing, isReady, context, idPetugas, data['nama'])
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: listPetugas.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionBtn(bool isSuccess, bool isProcessing, bool isReady, BuildContext context, String idPetugas, String? nama) {
    if (isSuccess) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Color(0xFF059669), size: 24),
          ),
          const SizedBox(height: 4),
          const Text('Terkirim', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      );
    } else if (isProcessing) {
      return const SizedBox(
        width: 44, height: 44,
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: CircularProgressIndicator(color: Color(0xFF059669), strokeWidth: 3),
        ),
      );
    } else if (isReady) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _tampilkanDialogKonfirmasi(context, idPetugas, nama ?? 'Petugas'),
        child: const Text('Panggil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }
    return const SizedBox(width: 44);
  }
}