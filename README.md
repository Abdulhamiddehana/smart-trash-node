# Smart Trash Node & Penjemputan

Aplikasi ini adalah bagian dari Proyek Semester Mobile Programming. Smart Trash Node adalah aplikasi Android native terintegrasi dengan hardware IoT (berbasis ESP32-WROOM-32E) dan Google Maps SDK untuk mendeteksi kapasitas tempat sampah dan memfasilitasi panggilan penjemputan sampah oleh warga.

## 1. Tujuan Proyek
Mengatasi inefisiensi pengecekan tempat sampah secara manual dan memperbaiki alur komunikasi antara warga dan petugas kebersihan. Aplikasi memberikan visualisasi lokasi (menggunakan peta/map) bagi petugas untuk menjemput sampah, baik dari pemicu otomatis (sensor penuh) maupun pemicu manual (warga yang memanggil).

## 2. Kebutuhan Sistem
- **Perangkat Keras Node:** Custom PCB dengan mikrokontroler ESP32-WROOM-32E (semua desain tata letak board dikonfigurasi menggunakan pengukuran mm).
- **Perangkat Bergerak:** Smartphone Android dengan OS minimal 8.0 (API Level 26) atau lebih baru.
- **Sensor & Izin:** Membutuhkan akses Internet, izin Lokasi (GPS), dan Notifikasi.
- **Teknologi Utama:** Kotlin, Jetpack Compose, Firebase Realtime Database, Google Maps SDK.

## 3. Cara Menjalankan Aplikasi
1. *Clone* repositori ini ke komputer lokal menggunakan perintah: `git clone [masukkan_link_repo_kamu_di_sini]`
2. Buka proyek menggunakan **Android Studio**.
3. Tunggu hingga proses *sync Gradle* selesai.
4. **Perhatian Keamanan:** API Key Google Maps dan file `google-services.json` (Firebase) tidak disertakan di repositori ini demi keamanan data sensitif. Untuk menjalankan secara penuh, Anda harus memasukkan API Key secara mandiri di `local.properties`.
5. Hubungkan perangkat fisik via *USB Debugging* atau gunakan Emulator, lalu tekan tombol **Run (Shift + F10)**.

## 4. Pembagian Kontribusi
- **Abdul Hamid:** Setup Firebase Realtime Database, integrasi perangkat keras IoT, dan konfigurasi awal Google Maps API.
- **Sultan:** Pengembangan UI/UX Jetpack Compose untuk peran/role Warga dan fitur pemanggilan (Request Location).
- **Erlangga (Angga):** Pengembangan UI/UX Jetpack Compose untuk peran/role Petugas, manajemen notifikasi, dan *local persistence* (Room).

## 5. Dokumentasi Penggunaan AI (Sesuai Ketentuan)
- **Tujuan:** Membantu menyusun struktur proposal awal, merumuskan ide integrasi peta (Google Maps), dan membuat templat Markdown README.
- **Sumber verifikasi:** Modul Praktikum Pertemuan 1 dan Dokumentasi Resmi Google Maps SDK for Android.
- **Bagian yang diadaptasi:** Matriks seleksi masalah dan kerangka dokumen `README.md`.
