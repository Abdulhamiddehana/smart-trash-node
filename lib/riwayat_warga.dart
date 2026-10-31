import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

class RiwayatWarga extends StatefulWidget {
  const RiwayatWarga({super.key});

  @override
  State<RiwayatWarga> createState() => _RiwayatWargaState();
}

class _RiwayatWargaState extends State<RiwayatWarga> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://smart-trash-node-default-rtdb.asia-southeast1.firebasedatabase.app'
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Riwayat Penjemputan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // Membaca dari node 'panggilan' (nanti bisa diubah ke 'riwayat_panggilan' jika database sudah disesuaikan)
      body: StreamBuilder(
        stream: _database.ref('riwayat_panggilan').orderByChild('id_warga').equalTo(_uid).onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF059669)));
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _buildEmptyState();
          }

          Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List<MapEntry<dynamic, dynamic>> riwayatList = data.entries.toList();
          
          // Urutkan dari yang terbaru (berdasarkan waktu)
          riwayatList.sort((a, b) => b.value['waktu'].toString().compareTo(a.value['waktu'].toString()));

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: riwayatList.length,
            itemBuilder: (context, index) {
              var item = riwayatList[index].value;
              
              // Format tanggal
              DateTime waktu;
              try {
                waktu = DateTime.parse(item['waktu'].toString());
              } catch(e) {
                waktu = DateTime.now();
              }
              String tanggalBagus = DateFormat('dd MMM yyyy, HH:mm').format(waktu);
              bool isProses = item['status_pesanan'] == 'proses';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isProses ? const Color(0xFF3B82F6).withOpacity(0.1) : const Color(0xFF059669).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isProses ? Icons.local_shipping_rounded : Icons.check_circle_rounded,
                        color: isProses ? const Color(0xFF3B82F6) : const Color(0xFF059669),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tanggalBagus, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Petugas: ${item['nama_petugas']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text(isProses ? 'Sedang Diproses' : 'Selesai', 
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold,
                              color: isProses ? const Color(0xFF3B82F6) : const Color(0xFF059669)
                            )
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(Icons.history_rounded, size: 64, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 24),
          const Text('Belum Ada Riwayat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          const Text('Riwayat penjemputan sampah Anda\nakan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }
}