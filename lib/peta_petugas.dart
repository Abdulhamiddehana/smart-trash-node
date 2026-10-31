import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class PetaPetugas extends StatefulWidget {
  const PetaPetugas({super.key});

  @override
  State<PetaPetugas> createState() => _PetaPetugasState();
}

class _PetaPetugasState extends State<PetaPetugas> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://smart-trash-node-default-rtdb.asia-southeast1.firebasedatabase.app'
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndMarkers();
  }

  Future<void> _getCurrentLocationAndMarkers() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // Ambil GPS Petugas
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    if (mounted) {
      setState(() {
        _currentPosition = position;
        _markers.add(
          Marker(
            markerId: const MarkerId('lokasi_saya'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(title: 'Posisi Anda Saat Ini'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      });
    }

    // Listen ke data Panggilan Warga secara Real-time
    _database.ref('panggilan').onValue.listen((event) {
      if (!mounted) return;
      
      Set<Marker> newMarkers = {};
      
      // Pertahankan marker posisi petugas
      if (_currentPosition != null) {
        newMarkers.add(
          Marker(
            markerId: const MarkerId('lokasi_saya'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Posisi Anda Saat Ini'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          )
        );
      }

      // Tambahkan marker untuk setiap panggilan warga
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          if (value['lat'] != null && value['lng'] != null) {
            bool isDiproses = value['status_pesanan'] == 'proses';
            newMarkers.add(
              Marker(
                markerId: MarkerId(key.toString()),
                position: LatLng(double.parse(value['lat'].toString()), double.parse(value['lng'].toString())),
                infoWindow: InfoWindow(
                  title: value['pengirim'],
                  snippet: isDiproses ? 'Sedang dijemput' : 'Menunggu jemputan',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  isDiproses ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueRed
                ),
              ),
            );
          }
        });
      }

      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    });

    setState(() => _isLoading = false);

    // Arahkan kamera peta ke lokasi petugas
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 14.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Peta Area Penjemputan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
          : _currentPosition == null
              ? const Center(child: Text('Gagal mendapatkan lokasi GPS.'))
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        zoom: 14.0,
                      ),
                      onMapCreated: (controller) => _mapController = controller,
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                    Positioned(
                      bottom: 24,
                      right: 16,
                      child: FloatingActionButton(
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.my_location_rounded, color: Color(0xFF059669)),
                        onPressed: () {
                          if (_currentPosition != null) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLng(LatLng(_currentPosition!.latitude, _currentPosition!.longitude))
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}