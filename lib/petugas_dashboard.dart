import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PetugasDashboard extends StatefulWidget {
  const PetugasDashboard({super.key});

  @override
  State<PetugasDashboard> createState() => _PetugasDashboardState();
}

class _PetugasDashboardState extends State<PetugasDashboard> {
  String? _selectedPanggilanKey;
  Map<dynamic, dynamic>? _selectedPanggilanData;
  String _namaPetugas = "Petugas";
  String? _base64ProfileImage;
  DateTime? _lastPressedAt; // Menyimpan waktu terakhir pencet back

  double? _posisiPetugasLat;
  double? _posisiPetugasLng;

  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  GoogleMapController? _mapController;

  static const String googleApiKey = "AIzaSyBbQmtzHmMptNbZfyQMQLlzMbLoTfTV28k";
  final PolylinePoints polylinePoints = PolylinePoints(apiKey: googleApiKey);

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
          SnackBar(content: const Text('Foto profil diperbarui!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,)
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

  Future<void> _ambilRute(double startLat, double startLng, double destLat, double destLng) async {
    _polylineCoordinates.clear();

    // Trik Garis Lurus: Langsung masukkan titik awal dan akhir tanpa memanggil API Google
    _polylineCoordinates.add(LatLng(startLat, startLng));
    _polylineCoordinates.add(LatLng(destLat, destLng));

    if (mounted) {
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('rute_petugas_warga'),
            color: const Color(0xFF00897B), 
            points: _polylineCoordinates,
            width: 4, // Sedikit dipertipis agar lebih rapi
            geodesic: true, // Membuat garis mengikuti lengkungan bumi
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)], // Efek garis putus-putus
          ),
        );
      });
    }
  }

  void _konfirmasiSelesai(String key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline, color: Colors.green),
            ),
            const SizedBox(width: 12),
            const Text('Tugas Selesai?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: const Text(
          'Apakah sampah sudah berhasil diangkut? Laporan ini akan dihapus dari antrean dan status Anda akan kembali Siap Bertugas.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, 
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
            ),
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);

              _database.ref('panggilan/$key').remove().then((_) async {
                String? uidPetugas = FirebaseAuth.instance.currentUser?.uid;
                if (uidPetugas != null) {
                  await _database.ref('data_petugas/$uidPetugas/status').set('ready');
                }

                if (!mounted) return;
                setState(() {
                  _selectedPanggilanKey = null;
                  _selectedPanggilanData = null;
                  _posisiPetugasLat = null;
                  _posisiPetugasLng = null;
                  _polylines.clear();
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.thumb_up, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Mantap! Tugas berhasil diselesaikan.', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(20),
                  )
                );
              });
            },
            child: const Text('Ya, Selesai'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        // Khusus petugas: Jika lagi buka rute peta, back hanya mengecilkan peta (minimize)
        if (_selectedPanggilanData != null) {
          setState(() {
            _selectedPanggilanKey = null;
            _selectedPanggilanData = null;
            _polylines.clear();
          });
          return;
        }

        // Jika ada di beranda list, gunakan double tap to exit
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
        body: _selectedPanggilanData == null ? _buildDashboardList() : _buildMapView(),
      ), // <-- Koma untuk menutup Scaffold
    ); // <-- Kurung tutup untuk PopScope
  }

  // --- TAMPILAN 1: DASHBOARD & LIST PANGGILAN ---
  Widget _buildDashboardList() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                const Icon(Icons.list_alt_rounded, color: Color(0xFF1E293B)),
                const SizedBox(width: 8),
                const Text('Antrean Tugas Masuk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ),
        StreamBuilder(
          stream: _database.ref('panggilan').orderByChild('id_petugas').equalTo(FirebaseAuth.instance.currentUser?.uid).onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator(color: Colors.green))));
            }
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                      ),
                      const SizedBox(height: 24),
                      const Text('Area Bersih!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      const Text('Belum ada panggilan penjemputan masuk.\nWaktunya bersantai!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5)),
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
      backgroundColor: const Color(0xFF2E7D32),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF4CAF50)],
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
                              Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.lightGreenAccent, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text('Driver Aktif', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_getGreeting(), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15)),
                              Text(_namaPetugas, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
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
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.3), width: 1)),
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

  Widget _buildTugasCard(dynamic key, dynamic data) {
    bool isDiproses = data['status_pesanan'] == 'proses';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDiproses ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2), width: isDiproses ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card (Status Badge Dinamis)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDiproses ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18))
            ),
            child: Row(
              children: [
                Icon(isDiproses ? Icons.directions_car_rounded : Icons.local_fire_department_rounded, 
                     color: isDiproses ? Colors.blue : Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(isDiproses ? 'SEDANG DIJEMPUT' : 'TUGAS BARU', 
                     style: TextStyle(color: isDiproses ? Colors.blue : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                const Spacer(),
                Icon(Icons.more_horiz, color: (isDiproses ? Colors.blue : Colors.orange).withOpacity(0.5)),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Pelapor
                Row(
                  children: [
                    data['foto_pengirim'] != null
                      ? CircleAvatar(
                          radius: 24,
                          backgroundImage: MemoryImage(base64Decode(data['foto_pengirim'])),
                        )
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pelapor', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(data['pengirim'] ?? 'Warga', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(height: 1, thickness: 1)),
                
                // Info Lokasi
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Titik Jemput (GPS)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                          const SizedBox(height: 4),
                          Text('${data['lokasi']}', style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Tombol Aksi Dinamis
                if (!isDiproses)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                      ),
                      onPressed: () => _prosesTerimaTugas(key, data),
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
                            backgroundColor: Colors.blue, 
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                          ),
                          onPressed: () => _bukaPetaSaja(key, data),
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
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                              ),
                              onPressed: () => _batalkanTugas(key),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                              ),
                              onPressed: () => _konfirmasiSelesai(key),
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

  Future<void> _prosesTerimaTugas(dynamic key, dynamic data) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // Dialog Loading Premium
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(width: 20),
              const Expanded(child: Text('Menghubungkan GPS...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
        ),
      ),
    );

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'GPS mati.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Izin ditolak.';
      }

      Position posisi = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Menggunakan titik GPS asli dari device Petugas (bukan dummy)
      double realLat = posisi.latitude;
      double realLng = posisi.longitude;

      if (!mounted) {
        navigator.pop();
        return;
      }

      // HITUNG ESTIMASI WAKTU & JARAK (GRATIS TANPA API)
      double distanceInMeters = Geolocator.distanceBetween(realLat, realLng, data['lat'], data['lng']);
      int estimasiMenit = (distanceInMeters / 400).ceil(); // Asumsi kecepatan motor 400 meter/menit (24 km/jam)
      if (estimasiMenit < 1) estimasiMenit = 1;

      setState(() {
        _posisiPetugasLat = realLat;
        _posisiPetugasLng = realLng;
        _selectedPanggilanKey = key;
        
        // Buat salinan data dan tambahkan info jarak/waktu untuk ditampilkan di Peta Petugas
        Map<dynamic, dynamic> updatedData = Map.from(data);
        updatedData['estimasi_menit'] = estimasiMenit;
        updatedData['jarak_meter'] = distanceInMeters.round();
        _selectedPanggilanData = updatedData;
      });

      // UBAH STATUS PETUGAS MENJADI SIBUK
      String? uidPetugas = FirebaseAuth.instance.currentUser?.uid;
      if (uidPetugas != null) {
        await _database.ref('data_petugas/$uidPetugas/status').set('sibuk');
      }

      // TANDAI TUGAS SEBAGAI DIPROSES DAN SIMPAN ESTIMASI KE DATABASE
      await _database.ref('panggilan/$key').update({
        'status_pesanan': 'proses',
        'estimasi_menit': estimasiMenit,
        'jarak_meter': distanceInMeters.round(),
      });

      // Memanggil fungsi rute berdasarkan lokasi asli petugas dan lokasi warga
      await _ambilRute(realLat, realLng, data['lat'], data['lng']);

      navigator.pop(); // Tutup loading
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal akses GPS: $e', style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  // Fungsi untuk membatalkan tugas dari Halaman Utama
  Future<void> _batalkanTugas(String key) async {
    // Kembalikan status pesanan di database
    await _database.ref('panggilan/$key/status_pesanan').remove();
    
    // Kembalikan petugas menjadi ready
    String? uidPetugas = FirebaseAuth.instance.currentUser?.uid;
    if (uidPetugas != null) {
      await _database.ref('data_petugas/$uidPetugas/status').set('ready');
    }
    
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tugas dibatalkan. Anda kembali Siap Bertugas.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )
      );
    }
  }

  // Fungsi untuk membuka ulang peta tanpa mengubah database
  Future<void> _bukaPetaSaja(dynamic key, dynamic data) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.blue),
              const SizedBox(width: 20),
              const Expanded(child: Text('Melanjutkan Navigasi...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
        ),
      ),
    );

    try {
      Position posisi = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) {
        navigator.pop();
        return;
      }

      setState(() {
        _posisiPetugasLat = posisi.latitude;
        _posisiPetugasLng = posisi.longitude;
        _selectedPanggilanKey = key;
        _selectedPanggilanData = data;
      });

      await _ambilRute(posisi.latitude, posisi.longitude, data['lat'], data['lng']);

      navigator.pop();
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal akses GPS: $e'),
          backgroundColor: Colors.redAccent,
        )
      );
    }
  }

  // --- TAMPILAN 2: PETA NAVIGASI ---

  // --- TAMPILAN 2: PETA NAVIGASI ---
  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
            
            // Logika agar kamera otomatis menyesuaikan posisi Warga & Petugas
            LatLngBounds bounds;
            LatLng posPetugas = LatLng(_posisiPetugasLat!, _posisiPetugasLng!);
            LatLng posWarga = LatLng(_selectedPanggilanData!['lat'], _selectedPanggilanData!['lng']);
            
            if (posPetugas.latitude > posWarga.latitude && posPetugas.longitude > posWarga.longitude) {
              bounds = LatLngBounds(southwest: posWarga, northeast: posPetugas);
            } else if (posPetugas.longitude > posWarga.longitude) {
              bounds = LatLngBounds(
                  southwest: LatLng(posPetugas.latitude, posWarga.longitude),
                  northeast: LatLng(posWarga.latitude, posPetugas.longitude));
            } else if (posPetugas.latitude > posWarga.latitude) {
              bounds = LatLngBounds(
                  southwest: LatLng(posWarga.latitude, posPetugas.longitude),
                  northeast: LatLng(posPetugas.latitude, posWarga.longitude));
            } else {
              bounds = LatLngBounds(southwest: posPetugas, northeast: posWarga);
            }
            
            // Beri jeda sedikit lalu gerakkan kamera
            Future.delayed(const Duration(milliseconds: 600), () {
              _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60)); // 60 = padding layar
            });
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(
                (_posisiPetugasLat! + _selectedPanggilanData!['lat']) / 2,
                (_posisiPetugasLng! + _selectedPanggilanData!['lng']) / 2
            ),
            zoom: 15.0,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('lokasi_warga'),
              position: LatLng(_selectedPanggilanData!['lat'], _selectedPanggilanData!['lng']),
              infoWindow: InfoWindow(title: 'Lokasi Sampah Penuh', snippet: 'Pemanggil: ${_selectedPanggilanData!['pengirim']}'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
            Marker(
              markerId: const MarkerId('lokasi_petugas'),
              position: LatLng(_posisiPetugasLat!, _posisiPetugasLng!),
              infoWindow: const InfoWindow(title: 'Posisi Anda Saat Ini'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Ubah ke hijau agar lebih cocok dengan petugas
            ),
          },
          polylines: _polylines,
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
        
        // Tombol Kembali Floating Premium
        Positioned(
          top: 50, left: 20,
          child: Material(
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // HANYA MINIMIZE (KEMBALI KE LIST DEPAN), TIDAK MEMBATALKAN TUGAS
                setState(() {
                  _selectedPanggilanKey = null;
                  _selectedPanggilanData = null;
                  _polylines.clear();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
              ),
            ),
          ),
        ),

        // Panel Selesaikan Tugas (Bottom Card Premium)
        Positioned(
          bottom: 30, left: 20, right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 15))
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tujuan Penjemputan', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(_selectedPanggilanData!['pengirim'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.my_location_rounded, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_selectedPanggilanData!['lokasi'], style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4))),
                          ],
                        ),
                        if (_selectedPanggilanData!['estimasi_menit'] != null) ...[
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text('Estimasi Tiba: ${_selectedPanggilanData!['estimasi_menit']} Menit ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              Text('(${(_selectedPanggilanData!['jarak_meter'] / 1000).toStringAsFixed(1)} km)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),

                  // INFO SENSOR LIVE (MUNCUL JIKA ADA ID ALAT DARI WARGA)
                  if (_selectedPanggilanData!['id_alat'] != null) ...[
                    const SizedBox(height: 16),
                    StreamBuilder(
                      stream: _database.ref('sensor/${_selectedPanggilanData!['id_alat']}').onValue,
                      builder: (context, snapshot) {
                        String jarakInfo = "Membaca...";
                        String bateraiInfo = "Membaca...";
                        Color bateraiColor = Colors.grey;

                        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                          Map dataSensor = snapshot.data!.snapshot.value as Map;
                          jarakInfo = '${dataSensor['jarak'] ?? '?'} cm';
                          
                          int batLevel = int.tryParse(dataSensor['baterai']?.toString() ?? '0') ?? 0;
                          bateraiInfo = '$batLevel%';
                          if (batLevel > 50) bateraiColor = Colors.green;
                          else if (batLevel > 20) bateraiColor = Colors.orange;
                          else bateraiColor = Colors.red;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.withOpacity(0.2))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.delete_outline, color: Colors.teal, size: 20),
                                  const SizedBox(width: 6),
                                  Text('Jarak: $jarakInfo', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13)),
                                ],
                              ),
                              Container(width: 1, height: 20, color: Colors.teal.withOpacity(0.3)),
                              Row(
                                children: [
                                  Icon(Icons.battery_charging_full_rounded, color: bateraiColor, size: 20),
                                  const SizedBox(width: 6),
                                  Text('Baterai: $bateraiInfo', style: TextStyle(fontWeight: FontWeight.bold, color: bateraiColor, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32), 
                        foregroundColor: Colors.white, 
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      onPressed: () => _konfirmasiSelesai(_selectedPanggilanKey!),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 22),
                          SizedBox(width: 10),
                          Text('Selesaikan Tugas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}