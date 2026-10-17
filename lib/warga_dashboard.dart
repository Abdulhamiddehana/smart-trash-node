import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class WargaDashboard extends StatefulWidget {
  const WargaDashboard({super.key});

  @override
  State<WargaDashboard> createState() => _WargaDashboardState();
}

class _WargaDashboardState extends State<WargaDashboard> {
  String? _petugasSedangDiproses;
  final Set<String> _petugasBerhasilDipanggil = {};
String _namaWarga = "Warga";
  bool _hasActiveCall = false;
  String? _base64ProfileImage;
  DateTime? _lastPressedAt; // Menyimpan waktu terakhir pencet back
  String _idAlat = "node_1"; // Default awal

  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://smart-trash-node-default-rtdb.asia-southeast1.firebasedatabase.app'
  );

  @override
  void initState() {
    super.initState();
    _ambilNamaWarga();
  }

  // Mengambil nama warga untuk ditampilkan di Header (Murni UI)
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
    }
  }

  Future<void> _gantiFotoProfil() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 200, // Ukuran ditekan sekecil mungkin agar DB tidak berat
      maxHeight: 200,
      imageQuality: 50,
    );

    if (image != null) {
      File file = File(image.path);
      List<int> imageBytes = await file.readAsBytes();
      String base64String = base64Encode(imageBytes);

      String uid = FirebaseAuth.instance.currentUser!.uid;
      // Simpan ke Realtime Database
      await _database.ref('users/$uid/foto_profil').set(base64String);

      setState(() {
        _base64ProfileImage = base64String;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto profil berhasil diperbarui!'),
            backgroundColor: Colors.teal,
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
      setState(() {
        _hasActiveCall = hasCall;
      });
    });
  }

  // --- LOGIKA SAPAAN UI Bawaan Dart (Tanpa Package Tambahan) ---
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.teal),
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
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              elevation: 0,
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
      if (mounted) _showSnackBar('Nyalakan GPS/Lokasi HP kamu dulu ya!', Colors.redAccent, Icons.location_off);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showSnackBar('Izin lokasi ditolak!', Colors.redAccent, Icons.error_outline);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showSnackBar('Izin lokasi ditolak permanen. Buka pengaturan HP.', Colors.redAccent, Icons.error_outline);
      return;
    }

    setState(() => _petugasSedangDiproses = idPetugas);

    try {
      Position posisi = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      String lokasiWarga = "Titik GPS: ${posisi.latitude}, ${posisi.longitude}";
      String pesanOtomatis = "Tempat sampah sudah penuh, mohon segera diangkut.";

      await _database.ref('panggilan').push().set({
        'pengirim': _namaWarga,
        'foto_pengirim': _base64ProfileImage,
        'id_petugas': idPetugas,
        'nama_petugas': namaPetugas,
        'id_alat': _idAlat, // <-- Mengirimkan ID alat milik warga ini ke petugas
        'lokasi': lokasiWarga,
        'lat': posisi.latitude,
        'lng': posisi.longitude,
        'pesan': pesanOtomatis,
        'waktu': DateTime.now().toString(),
      });

      if (mounted) {
        setState(() {
          _petugasSedangDiproses = null;
          _petugasBerhasilDipanggil.add(idPetugas);
        });
        _showSnackBar('Berhasil! $namaPetugas segera menuju ke lokasimu.', Colors.teal, Icons.check_circle_outline);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _petugasSedangDiproses = null);
        _showSnackBar('Gagal mengirim data / GPS lambat mencari titik.', Colors.redAccent, Icons.wifi_off);
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));

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
              backgroundColor: Colors.black87,
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
      backgroundColor: const Color(0xFFF4F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildPremiumHeader(),
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Background hijau yang meneruskan header untuk efek tumpuk (overlap)
                Container(
                  height: 60,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF26A69A), Color(0xFF00897B)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTrashStatusCard(), // CARD SENSOR YANG SUDAH DIPERBAIKI (TIDAK OVERFLOW)
                      
                      // Memanggil widget status penjemputan warga (Live Tracking)
                      _buildActiveCallStatus(),
                      
                      if (!_hasActiveCall) ...[
                        const SizedBox(height: 36),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Panggil Petugas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: -0.5)),
                                SizedBox(height: 4),
                                Text('Daftar kebersihan area Anda', style: TextStyle(fontSize: 14, color: Colors.grey)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.people_alt_outlined, color: Colors.teal),
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
      ), // Penutup slivers / CustomScrollView
    ), // <-- Koma penutup Scaffold
    ); // <-- Kurung tutup PopScope
  }

  Widget _buildPremiumHeader() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: false,
      elevation: 0,
      backgroundColor: const Color(0xFF26A69A),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00796B), Color(0xFF26A69A)],
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
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            backgroundImage: _base64ProfileImage != null 
                                ? MemoryImage(base64Decode(_base64ProfileImage!)) 
                                : null,
                            child: _base64ProfileImage == null 
                                ? const Icon(Icons.person, color: Colors.white, size: 36) 
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pantau & Panggil Petugas', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(_getGreeting(), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
                              Text(_namaWarga, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
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
        final jarakStr = snapshot.data?.snapshot.value?.toString() ?? '100';
        double jarakVal = double.tryParse(jarakStr) ?? 100.0;

        double maxTinggi = 100.0;
        double persentase = ((maxTinggi - jarakVal) / maxTinggi).clamp(0.0, 1.0);
        
        Color statusColor;
        String statusText;
        IconData statusIcon;

        if (persentase >= 0.85) { // Jarak <= 15cm
          statusColor = const Color(0xFFE53935); // Merah kuat
          statusText = 'Kapasitas Penuh!';
          statusIcon = Icons.warning_rounded;
        } else if (persentase >= 0.50) { // Jarak <= 50cm
          statusColor = const Color(0xFFF57C00); // Oranye solid
          statusText = 'Terisi Sebagian';
          statusIcon = Icons.delete_outline;
        } else {
          statusColor = const Color(0xFF00897B); // Hijau Teal
          statusText = 'Masih Kosong';
          statusIcon = Icons.check_circle_outline;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: statusColor.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 12))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PERBAIKAN OVERFLOW DI SINI
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
                          child: Icon(statusIcon, color: statusColor, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded( // Memastikan teks panjang terpotong rapi (ellipsis)
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Status Sensor', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(statusText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$jarakStr cm', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -1)),
                ],
              ),
              const SizedBox(height: 30),
              
              // ANIMASI PROGRESS BAR
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: persentase),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.fastOutSlowIn,
                builder: (context, value, _) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 14,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kosong', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                          Text('${(value * 100).toInt()}% Terisi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
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

  // --- WIDGET BARU: STATUS PENJEMPUTAN AKTIF (LIVE TRACKING) ---
  Widget _buildActiveCallStatus() {
    return StreamBuilder(
      stream: _database.ref('panggilan').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SizedBox.shrink(); // Sembunyikan jika tidak ada panggilan
        }
        
        Map<dynamic, dynamic> panggilanMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        
        // Cari panggilan milik warga ini berdasarkan nama
        var myCalls = panggilanMap.entries.where((e) => e.value['pengirim'] == _namaWarga).toList();
        
        if (myCalls.isEmpty) return const SizedBox.shrink(); // Sembunyikan jika tidak ada panggilannya

        return Column(
          children: myCalls.map((entry) {
            var data = entry.value;
            bool isDiproses = data['status_pesanan'] == 'proses';
            
            return Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDiproses ? Colors.blue.withOpacity(0.3) : Colors.orange.withOpacity(0.3), width: 2),
                boxShadow: [BoxShadow(color: (isDiproses ? Colors.blue : Colors.orange).withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDiproses ? Colors.blue : Colors.orange).withOpacity(0.1),
                          shape: BoxShape.circle
                        ),
                        child: Icon(isDiproses ? Icons.local_shipping_rounded : Icons.access_time_filled_rounded, 
                                    color: isDiproses ? Colors.blue : Colors.orange),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isDiproses ? 'Petugas Sedang Menuju Lokasi' : 'Menunggu Respons Petugas', 
                                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDiproses ? Colors.blue[800] : Colors.orange[800])),
                            const SizedBox(height: 4),
                            Text('Petugas: ${data['nama_petugas']}', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    ],
                  ),
                  
                  // Tampilkan animasi progress jika sedang dijemput
                  if (isDiproses) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(data['estimasi_menit'] != null 
                              ? 'Estimasi Tiba: ${data['estimasi_menit']} Menit (${(data['jarak_meter'] / 1000).toStringAsFixed(1)} km)' 
                              : 'Menghitung estimasi...', 
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        backgroundColor: Color(0xFFE3F2FD), // Light blue
                        color: Colors.blue,
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
                  CircularProgressIndicator(color: Colors.teal.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('Mencari petugas...', style: TextStyle(color: Colors.grey)),
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
                  textStatus = 'Siap Bertugas'; colorStatus = const Color(0xFF00897B);
                } else if (statusPetugas == 'sibuk') {
                  textStatus = 'Sedang Menjemput'; colorStatus = Colors.blue; // Diubah senada dengan UI "Sedang Diproses"
                } else if (statusPetugas == 'sakit') {
                  textStatus = 'Sakit'; colorStatus = const Color(0xFFE53935);
                } else if (statusPetugas == 'izin') {
                  textStatus = 'Izin'; colorStatus = const Color(0xFF8D6E63);
                } else {
                  textStatus = 'Tidak Diketahui'; colorStatus = Colors.grey;
                }

                bool isProcessing = _petugasSedangDiproses == idPetugas;
                bool isSuccess = _petugasBerhasilDipanggil.contains(idPetugas);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border(left: BorderSide(color: colorStatus, width: 5)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: isReady && !isProcessing && !isSuccess ? () => _tampilkanDialogKonfirmasi(context, idPetugas, data['nama']) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: colorStatus.withOpacity(0.12),
                              backgroundImage: data['foto_profil'] != null 
                                  ? MemoryImage(base64Decode(data['foto_profil'].toString())) 
                                  : null,
                              child: data['foto_profil'] == null 
                                  ? Text(
                                      data['nama'] != null ? data['nama'].toString().substring(0, 1).toUpperCase() : 'P',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: colorStatus),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1E293B))),
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
                                        Text(textStatus, style: TextStyle(color: colorStatus, fontWeight: FontWeight.w700, fontSize: 11)),
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
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.teal, size: 24),
          ),
          const SizedBox(height: 4),
          const Text('Terkirim', style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      );
    } else if (isProcessing) {
      return const SizedBox(
        width: 44, height: 44,
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: CircularProgressIndicator(color: Colors.teal, strokeWidth: 3),
        ),
      );
    } else if (isReady) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        onPressed: () => _tampilkanDialogKonfirmasi(context, idPetugas, nama ?? 'Petugas'),
        child: const Text('Panggil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      );
    }
    return const SizedBox(width: 44);
  }
}