# Smart Trash Node

<p align="center">
  <strong>Sistem Pemantauan & Pengelolaan Sampah Cerdas Berbasis IoT</strong><br />
  Menghubungkan warga dan petugas kebersihan secara real-time untuk meningkatkan efisiensi penjemputan sampah dan mencegah penumpukan.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Mobile%20App-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Language-Dart-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84?logo=android&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Project-Final%20Project-orange" alt="Final Project" />
</p>

## 📖 Tentang Proyek

**Smart Trash Node** merupakan aplikasi pemantauan dan pengelolaan sampah cerdas berbasis Internet of Things (IoT). Sistem ini dirancang untuk menghubungkan warga dengan petugas kebersihan melalui aplikasi mobile yang terintegrasi dengan perangkat sensor dan layanan berbasis cloud.

Warga dapat memantau kapasitas tempat sampah, mengajukan panggilan penjemputan, serta melihat informasi penjemputan. Di sisi lain, petugas dapat mengelola antrean tugas dan menavigasi lokasi penjemputan. Data aplikasi disinkronkan melalui Firebase agar informasi dapat diakses secara real-time.

Proyek ini dikembangkan sebagai **Final Project mata kuliah Mobile Programming**.

## ✨ Fitur Utama

### 👤 Autentikasi dan Hak Akses

- Login terpusat menggunakan Firebase Authentication.
- Pemisahan akses berdasarkan peran (**Warga** dan **Petugas**).
- Pengguna diarahkan ke dashboard sesuai peran yang dimilikinya.

### 🏠 Dashboard Warga

- Menampilkan informasi kapasitas tempat sampah.
- Indikator kapasitas menggunakan progress bar agar kondisi tempat sampah mudah dipahami.
- Pemantauan kapasitas dirancang terhubung dengan sensor ultrasonik pada perangkat IoT.

### 🚨 Panggilan Penjemputan Darurat

- Warga dapat mengirim permintaan penjemputan ketika tempat sampah perlu segera dikosongkan.
- Permintaan menyertakan koordinat GPS lokasi warga untuk membantu petugas menemukan titik penjemputan.

### 🧹 Dashboard Petugas

- Menampilkan daftar atau antrean tugas penjemputan yang masuk.
- Mendukung status tugas **Tugas Baru** dan **Sedang Dijemput**.
- Membantu petugas memantau perkembangan penjemputan.

### 🗺️ Peta dan Navigasi

- Integrasi Google Maps SDK untuk menampilkan lokasi penjemputan.
- Geolocator digunakan untuk memperoleh posisi perangkat.
- Flutter Polyline Points digunakan untuk membantu menggambarkan rute perjalanan petugas menuju titik jemput.

### 🕘 Riwayat Penjemputan

- Menyediakan riwayat tugas penjemputan yang telah selesai.
- Data riwayat tersimpan secara otomatis ke Firebase Realtime Database.
- Memudahkan pengguna dan petugas meninjau aktivitas penjemputan sebelumnya.

## 🧰 Teknologi yang Digunakan

| Bagian | Teknologi | Kegunaan |
|---|---|---|
| Frontend mobile | Flutter, Dart | Pengembangan aplikasi lintas platform. |
| Arsitektur aplikasi | Modular / pemisahan file per menu | Memisahkan bagian aplikasi agar lebih terstruktur dan mudah dikembangkan. |
| Autentikasi | Firebase Authentication | Mengelola proses autentikasi pengguna. |
| Database | Firebase Realtime Database | Menyimpan dan menyinkronkan data aplikasi secara real-time. |
| Peta | Google Maps Flutter | Menampilkan peta dan titik lokasi. |
| Lokasi | Geolocator | Mengakses koordinat GPS perangkat. |
| Rute | Flutter Polyline Points | Membantu menampilkan garis rute pada peta. |
| Mikrokontroler IoT | ESP8266 / ESP32 | Menghubungkan sensor dengan sistem. |
| Sensor | Ultrasonik HC-SR04 | Mengukur jarak untuk memperkirakan tingkat kepenuhan tempat sampah. |
| Perangkat keras | Custom PCB (EasyEDA / JLCPCB) | Papan rangkaian untuk integrasi komponen perangkat IoT. |

## 🏗️ Gambaran Sistem

Secara umum, Smart Trash Node menghubungkan tiga bagian utama:

1. **Perangkat IoT** membaca kondisi tempat sampah menggunakan sensor ultrasonik yang terhubung ke mikrokontroler ESP8266/ESP32.
2. **Firebase** menjadi layanan backend untuk autentikasi serta penyimpanan dan sinkronisasi data aplikasi.
3. **Aplikasi Flutter** menyediakan antarmuka bagi warga dan petugas sesuai hak akses masing-masing.

```text
+-----------------------+       +-----------------------+
|    Perangkat IoT      |       |    Aplikasi Flutter   |
|                       |       |                       |
|  HC-SR04 Ultrasonic   |       |  Dashboard Warga      |
|          |            |       |  Dashboard Petugas    |
|     ESP8266/ESP32     |       |  Peta & Riwayat       |
+-----------+-----------+       +-----------+-----------+
            |                               |
            |       Sinkronisasi data       |
            +---------------+---------------+
                            |
                  +---------v---------+
                  |      Firebase     |
                  |                   |
                  | Authentication    |
                  | Realtime Database |
                  +-------------------+
```

> **Catatan:** Diagram di atas merupakan gambaran tingkat tinggi integrasi sistem. Detail komunikasi perangkat IoT ke Firebase dapat disesuaikan dengan implementasi pada firmware dan konfigurasi proyek.

## 🚀 Installation & Setup

Ikuti langkah-langkah berikut untuk menjalankan aplikasi di komputer lokal.

### Prasyarat

Pastikan perangkat pengembangan telah memiliki:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) yang sudah terpasang dan dikonfigurasi.
- [Dart SDK](https://dart.dev/get-dart) (umumnya sudah disertakan bersama Flutter).
- Android Studio atau Visual Studio Code.
- Android Emulator atau perangkat Android fisik dengan USB debugging aktif.
- Git.
- Proyek Firebase yang telah disiapkan untuk aplikasi.
- Google Maps API key yang telah diaktifkan sesuai kebutuhan platform.

Periksa instalasi Flutter dengan perintah:

```bash
flutter doctor
```

### 1. Clone Repository

Ganti `USERNAME` dan `REPOSITORY` dengan alamat repository GitHub proyek yang sebenarnya.

```bash
git clone https://github.com/USERNAME/REPOSITORY.git
cd REPOSITORY
```

### 2. Instal Dependencies

Jalankan perintah berikut dari direktori utama proyek (direktori yang berisi file `pubspec.yaml`):

```bash
flutter pub get
```

### 3. Konfigurasi Firebase

Pastikan aplikasi lokal telah terhubung ke proyek Firebase yang digunakan oleh tim.

- Siapkan konfigurasi Firebase untuk platform target.
- Untuk Android, pastikan file `google-services.json` tersedia pada lokasi konfigurasi aplikasi Android yang sesuai.
- Pastikan Firebase Authentication dan Firebase Realtime Database telah diaktifkan serta aturan akses database dikonfigurasi dengan aman.
- Jangan mengunggah kredensial privat, service account key, atau rahasia proyek ke repository publik.

Apabila proyek menggunakan FlutterFire CLI, konfigurasi dapat dibuat atau diperbarui dengan mengikuti [dokumentasi resmi FlutterFire](https://firebase.google.com/docs/flutter/setup).

### 4. Konfigurasi Google Maps

Tambahkan Google Maps API key sesuai konfigurasi platform yang digunakan. Untuk Android, API key umumnya diatur pada konfigurasi manifest aplikasi. Pastikan Maps SDK for Android telah diaktifkan pada Google Cloud project terkait.

Lihat [dokumentasi Google Maps untuk Flutter](https://pub.dev/packages/google_maps_flutter) untuk petunjuk konfigurasi lebih lanjut.

### 5. Jalankan Aplikasi

Hubungkan emulator atau perangkat fisik, lalu jalankan:

```bash
flutter run
```

Untuk melihat daftar perangkat yang terdeteksi:

```bash
flutter devices
```

## 📁 Struktur Proyek

Aplikasi dikembangkan dengan pendekatan modular atau pemisahan file berdasarkan menu/fitur. Struktur aktual dapat berbeda mengikuti implementasi pada repository.

Contoh gambaran struktur Flutter:

```text
smart_trash_node/
├── android/                 # Konfigurasi platform Android
├── ios/                     # Konfigurasi platform iOS (jika digunakan)
├── lib/
│   ├── main.dart            # Entry point aplikasi
│   ├── ...                  # Modul autentikasi, dashboard, peta, dan fitur lainnya
├── assets/                  # Gambar, ikon, dan aset aplikasi (jika tersedia)
├── test/                    # Pengujian aplikasi (jika tersedia)
├── pubspec.yaml             # Dependencies dan konfigurasi Flutter
└── README.md                # Dokumentasi proyek
```

## 👥 Anggota Tim

Proyek ini dikerjakan secara berkelompok oleh:

| Nama | NIM | Peran |
|---|---|---|
| **Abdul Hamid Dehana Friandana** | 240605110263 | Lead Developer & IoT Engineer |
| **Sultan Krishna Nugraha** | 240605110096 | UI/UX Designer & Documentator |
| **Erlangga Andi Saputra** | 240605110079 | Quality Assurance & Presenter |

## 🎓 Informasi Akademik

| Keterangan | Informasi |
|---|---|
| Nama proyek | Smart Trash Node |
| Jenis proyek | Final Project |
| Mata kuliah | Mobile Programming |
| Platform utama | Flutter (Dart) |

## 🔐 Keamanan dan Konfigurasi

Sebelum membagikan repository, pastikan:

- File konfigurasi yang berisi kredensial sensitif tidak ikut terunggah.
- Firebase Realtime Database Rules tidak menggunakan akses publik tanpa pembatasan untuk penggunaan sebenarnya.
- Google Maps API key dibatasi berdasarkan aplikasi dan kebutuhan API pada Google Cloud Console.
- Izin lokasi diminta dan digunakan secara transparan sesuai kebutuhan fitur penjemputan.

## 📄 Lisensi

Proyek ini dibuat untuk keperluan akademik sebagai Final Project mata kuliah Mobile Programming. Informasi lisensi penggunaan dan distribusi lebih lanjut dapat ditambahkan oleh tim apabila diperlukan.

---

<p align="center">
  <strong>Smart Trash Node</strong><br />
  <sub>Teknologi cerdas untuk pengelolaan sampah yang lebih efisien.</sub>
</p>
