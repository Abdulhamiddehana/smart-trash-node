import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

class RiwayatPetugas extends StatefulWidget {
  const RiwayatPetugas({super.key});

  @override
  State<RiwayatPetugas> createState() => _RiwayatPetugasState();
}

class _RiwayatPetugasState extends State<RiwayatPetugas> {
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
        title: const Text('Riwayat Tugas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // Membaca dari node riwayat_panggilan khusus untuk petugas ini
      body: StreamBuilder(
        stream: _database.ref('riwayat_panggilan').orderByChild('id_petugas').equalTo(_uid).onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF059669)));
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _buildEmptyState();
          }

          Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List<MapEntry<dynamic, dynamic>> riwayatList = data.entries.toList();
          
          // Urutkan dari yang terbaru (berdasarkan waktu_selesai)
          riwayatList.sort((a, b) => b.value['waktu_selesai'].toString().compareTo(a.value['waktu_selesai'].toString()));

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: riwayatList.length,
            itemBuilder: (context, index) {
              var item = riwayatList[index].value;
              
              // Format tanggal
              DateTime waktu;
              try {
                waktu = DateTime.parse(item['waktu_selesai'].toString());
              } catch(e) {
                waktu = DateTime.now();
              }
              String tanggalBagus = DateFormat('dd MMM yyyy, HH:mm').format(waktu);

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
                        color: const Color(0xFF059669).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tanggalBagus, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Warga: ${item['pengirim'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text(item['lokasi'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
          const Text('Tugas yang sudah Anda selesaikan\nakan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }
}