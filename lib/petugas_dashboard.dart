import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

// --- IMPORT FILE ANAK ---
import 'beranda_petugas.dart';
import 'peta_petugas.dart';
import 'riwayat_petugas.dart';

class PetugasDashboard extends StatefulWidget {
  const PetugasDashboard({super.key});

  @override
  State<PetugasDashboard> createState() => _PetugasDashboardState();
}

class _PetugasDashboardState extends State<PetugasDashboard> {
  String? _selectedPanggilanKey;
  Map<dynamic, dynamic>? _selectedPanggilanData;
  DateTime? _lastPressedAt;
  
  // Mengambil nama petugas untuk notifikasi ke warga
  String _namaPetugas = "Petugas";

  int _selectedIndex = 0;
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
    _ambilNamaPetugasUntukNotif();
  }

  Future<void> _ambilNamaPetugasUntukNotif() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final snapshot = await _database.ref('data_petugas/$uid').get();
      if (snapshot.exists && mounted) {
        setState(() {
          var data = snapshot.value as Map<dynamic, dynamic>;
          _namaPetugas = data['nama']?.toString() ?? "Petugas";
        });
      }
    }
  }

  Future<void> _ambilRute(double startLat, double startLng, double destLat, double destLng) async {
    _polylineCoordinates.clear();
    _polylineCoordinates.add(LatLng(startLat, startLng));
    _polylineCoordinates.add(LatLng(destLat, destLng));

    if (mounted) {
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('rute_petugas_warga'),
            color: const Color(0xFF059669), 
            points: _polylineCoordinates,
            width: 4, 
            geodesic: true, 
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)], 
          ),
        );
      });
    }
  }

  Future<void> _prosesTerimaTugas(dynamic key, dynamic data) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF059669)),
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );

      double distanceInMeters = Geolocator.distanceBetween(posisi.latitude, posisi.longitude, data['lat'], data['lng']);
      int estimasiMenit = (distanceInMeters / 400).ceil(); 
      if (estimasiMenit < 1) estimasiMenit = 1;

      if (!mounted) {
        navigator.pop();
        return;
      }

      setState(() {
        _posisiPetugasLat = posisi.latitude;
        _posisiPetugasLng = posisi.longitude;
        _selectedPanggilanKey = key.toString();
        
        Map<dynamic, dynamic> updatedData = Map.from(data);
        updatedData['estimasi_menit'] = estimasiMenit;
        updatedData['jarak_meter'] = distanceInMeters.round();
        _selectedPanggilanData = updatedData;
      });

      String? uidPetugas = FirebaseAuth.instance.currentUser?.uid;
      if (uidPetugas != null) {
        await _database.ref('data_petugas/$uidPetugas/status').set('sibuk');
      }

      await _database.ref('panggilan/$key').update({
        'status_pesanan': 'proses',
        'estimasi_menit': estimasiMenit,
        'jarak_meter': distanceInMeters.round(),
      });

      if (data['id_warga'] != null) {
        DataSnapshot snap = await _database.ref('users/${data['id_warga']}/fcm_token').get();
        if (snap.exists) {
          String tokenWarga = snap.value.toString();
          Uri urlAPI = Uri.parse('https://admin.dehans.web.id/api/send-notif');
          http.post(urlAPI, body: {
            'token': tokenWarga,
            'title': 'Petugas OTW! 🚛',
            'body': '$_namaPetugas sedang menuju ke lokasimu.',
          });
        }
      }

      await _ambilRute(posisi.latitude, posisi.longitude, data['lat'], data['lng']);
      navigator.pop(); 
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Gagal akses GPS: $e', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  Future<void> _batalkanTugas(String key) async {
    await _database.ref('panggilan/$key/status_pesanan').remove();
    String? uidPetugas = FirebaseAuth.instance.currentUser?.uid;
    if (uidPetugas != null) {
      await _database.ref('data_petugas/$uidPetugas/status').set('ready');
    }
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Tugas dibatalkan. Anda kembali Siap Bertugas.'), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating)
      );
    }
  }

  Future<void> _bukaPetaSaja(dynamic key, dynamic data) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF3B82F6)),
              const SizedBox(width: 20),
              const Expanded(child: Text('Melanjutkan Navigasi...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
        ),
      ),
    );

    try {
      Position posisi = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
      if (!mounted) {
        navigator.pop();
        return;
      }
      setState(() {
        _posisiPetugasLat = posisi.latitude;
        _posisiPetugasLng = posisi.longitude;
        _selectedPanggilanKey = key.toString();
        _selectedPanggilanData = data;
      });
      await _ambilRute(posisi.latitude, posisi.longitude, data['lat'], data['lng']);
      navigator.pop();
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Gagal akses GPS: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  void _konfirmasiSelesai(String key) {
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
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 12),
            const Text('Tugas Selesai?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: const Text(
          'Apakah sampah sudah berhasil diangkut? Laporan ini akan dipindahkan ke Riwayat dan status Anda kembali Siap Bertugas.',
          style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);

              try {
                DataSnapshot snapshot = await _database.ref('panggilan/$key').get();
                if (snapshot.exists) {
                  Map<dynamic, dynamic> dataSelesai = snapshot.value as Map<dynamic, dynamic>;
                  dataSelesai['status_pesanan'] = 'selesai';
                  dataSelesai['waktu_selesai'] = DateTime.now().toString();

                  await _database.ref('riwayat_panggilan').push().set(dataSelesai);
                  await _database.ref('panggilan/$key').remove();

                  String? uidPetugas = FirebaseAuth.instance.currentUser?.uid;
                  if (uidPetugas != null) {
                    await _database.ref('data_petugas/$uidPetugas/status').set('ready');
                  }

                  if (dataSelesai['id_warga'] != null) {
                    DataSnapshot snapToken = await _database.ref('users/${dataSelesai['id_warga']}/fcm_token').get();
                    if (snapToken.exists) {
                      String tokenWarga = snapToken.value.toString();
                      Uri urlAPI = Uri.parse('https://admin.dehans.web.id/api/send-notif');
                      http.post(urlAPI, body: {
                        'token': tokenWarga,
                        'title': 'Tugas Selesai! ✅',
                        'body': 'Sampah kamu telah berhasil diangkut oleh $_namaPetugas.',
                      });
                    }
                  }

                  if (!mounted) return;
                  setState(() {
                    _selectedPanggilanKey = null;
                    _selectedPanggilanData = null;
                    _posisiPetugasLat = null;
                    _posisiPetugasLng = null;
                    _polylines.clear();
                  });
                  
                  messenger.showSnackBar(const SnackBar(content: Text('Tugas selesai & tersimpan di Riwayat!'), backgroundColor: Color(0xFF059669), behavior: SnackBarBehavior.floating));
                }
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Ya, Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_selectedPanggilanData != null) {
          setState(() {
            _selectedPanggilanKey = null;
            _selectedPanggilanData = null;
            _polylines.clear();
          });
          return;
        }
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Tekan kembali sekali lagi untuk keluar', textAlign: TextAlign.center), backgroundColor: const Color(0xFF0F172A), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), margin: const EdgeInsets.only(bottom: 20, left: 50, right: 50), duration: const Duration(seconds: 2)));
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        
        body: _selectedPanggilanData == null 
            ? IndexedStack(
                index: _selectedIndex,
                children: [
                  BerandaPetugas(
                    onTerimaTugas: _prosesTerimaTugas,
                    onBukaPeta: _bukaPetaSaja,
                    onBatalTugas: _batalkanTugas,
                    onSelesaiTugas: _konfirmasiSelesai,
                  ), 
                  const PetaPetugas(),
                  const RiwayatPetugas(), 
                ],
              )
            : _buildMapView(),
            
        bottomNavigationBar: _selectedPanggilanData == null ? _buildBottomNav() : null,
      ), 
    ); 
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (int index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFF059669).withOpacity(0.2),
      elevation: 10,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF059669)), label: 'Beranda'),
        NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded, color: Color(0xFF059669)), label: 'Peta'),
        NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded, color: Color(0xFF059669)), label: 'Riwayat'),
      ],
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
            LatLngBounds bounds;
            LatLng posPetugas = LatLng(_posisiPetugasLat!, _posisiPetugasLng!);
            LatLng posWarga = LatLng(_selectedPanggilanData!['lat'], _selectedPanggilanData!['lng']);
            
            if (posPetugas.latitude > posWarga.latitude && posPetugas.longitude > posWarga.longitude) {
              bounds = LatLngBounds(southwest: posWarga, northeast: posPetugas);
            } else if (posPetugas.longitude > posWarga.longitude) {
              bounds = LatLngBounds(southwest: LatLng(posPetugas.latitude, posWarga.longitude), northeast: LatLng(posWarga.latitude, posPetugas.longitude));
            } else if (posPetugas.latitude > posWarga.latitude) {
              bounds = LatLngBounds(southwest: LatLng(posWarga.latitude, posPetugas.longitude), northeast: LatLng(posPetugas.latitude, posWarga.longitude));
            } else {
              bounds = LatLngBounds(southwest: posPetugas, northeast: posWarga);
            }
            Future.delayed(const Duration(milliseconds: 600), () {
              _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80)); 
            });
          },
          initialCameraPosition: CameraPosition(target: LatLng((_posisiPetugasLat! + _selectedPanggilanData!['lat']) / 2, (_posisiPetugasLng! + _selectedPanggilanData!['lng']) / 2), zoom: 15.0),
          markers: {
            Marker(markerId: const MarkerId('lokasi_warga'), position: LatLng(_selectedPanggilanData!['lat'], _selectedPanggilanData!['lng']), infoWindow: InfoWindow(title: 'Lokasi Sampah', snippet: 'Pemanggil: ${_selectedPanggilanData!['pengirim']}'), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
            Marker(markerId: const MarkerId('lokasi_petugas'), position: LatLng(_posisiPetugasLat!, _posisiPetugasLng!), infoWindow: const InfoWindow(title: 'Posisi Anda'), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
          },
          polylines: _polylines,
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
        
        Positioned(
          top: 50, left: 20,
          child: Material(
            color: Colors.white, elevation: 8, shadowColor: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _selectedPanggilanKey = null;
                  _selectedPanggilanData = null;
                  _polylines.clear();
                });
              },
              child: Container(padding: const EdgeInsets.all(12), child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24)),
            ),
          ),
        ),

        Positioned(
          bottom: 24, left: 20, right: 20,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))]),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 24)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tujuan Penjemputan', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(_selectedPanggilanData!['pengirim'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A))),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.my_location_rounded, size: 18, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(_selectedPanggilanData!['lokasi'], style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, height: 1.5)))]),
                        if (_selectedPanggilanData!['estimasi_menit'] != null) ...[
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
                          Row(children: [const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF3B82F6)), const SizedBox(width: 8), Text('Estimasi Tiba: ${_selectedPanggilanData!['estimasi_menit']} Menit ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))), Text('(${(_selectedPanggilanData!['jarak_meter'] / 1000).toStringAsFixed(1)} km)', style: const TextStyle(color: Colors.grey, fontSize: 12))])
                        ]
                      ],
                    ),
                  ),
                  if (_selectedPanggilanData!['id_alat'] != null) ...[
                    const SizedBox(height: 16),
                    StreamBuilder(
                      stream: _database.ref('sensor/${_selectedPanggilanData!['id_alat']}').onValue,
                      builder: (context, snapshot) {
                        String jarakInfo = "Membaca..."; String bateraiInfo = "Membaca..."; Color bateraiColor = Colors.grey;
                        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                          Map dataSensor = snapshot.data!.snapshot.value as Map;
                          jarakInfo = '${dataSensor['jarak'] ?? '?'} cm';
                          int batLevel = int.tryParse(dataSensor['baterai']?.toString() ?? '0') ?? 0;
                          bateraiInfo = '$batLevel%';
                          if (batLevel > 50) bateraiColor = const Color(0xFF10B981); else if (batLevel > 20) bateraiColor = const Color(0xFFF59E0B); else bateraiColor = const Color(0xFFEF4444);
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(children: [const Icon(Icons.delete_outline_rounded, color: Color(0xFF059669), size: 20), const SizedBox(width: 8), Text('Jarak: $jarakInfo', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF059669), fontSize: 13))]),
                              Container(width: 1, height: 24, color: const Color(0xFF059669).withOpacity(0.2)),
                              Row(children: [Icon(Icons.battery_charging_full_rounded, color: bateraiColor, size: 20), const SizedBox(width: 8), Text('Baterai: $bateraiInfo', style: TextStyle(fontWeight: FontWeight.w700, color: bateraiColor, fontSize: 13))]),
                            ],
                          ),
                        );
                      }
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () => _konfirmasiSelesai(_selectedPanggilanKey!),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_rounded, size: 24), SizedBox(width: 10), Text('Selesaikan Tugas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5))]),
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