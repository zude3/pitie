# Ringkasan Proyek Pitie

Dokumen ini menjadi peta untuk memahami dan mengembangkan aplikasi Pitie. Isinya merangkum struktur dan perilaku yang ditemukan pada kode saat ini; periksa implementasi terkait sebelum mengubahnya karena kode tetap menjadi sumber kebenaran.
setiap ada perubahan/pengurangan/penambahan file, update file ini sesuai perubahan yang dilakukan

## Gambaran umum

Pitie adalah aplikasi Flutter untuk pencatatan keuangan pribadi. Fitur utamanya meliputi:

- autentikasi pengguna dengan Firebase Authentication;
- pencatatan pemasukan dan pengeluaran;
- pengelolaan hutang, pinjaman, dan piutang;
- target serta aktivitas tabungan;
- ringkasan saldo dan laporan.

Antarmuka menggunakan Material dan font Poppins serta Geist. Teks UI berbahasa Indonesia, sedangkan nama kelas, metode, dan identifier menggunakan bahasa Inggris.

## Teknologi dan penyimpanan

- Flutter dan Dart (batas SDK di `pubspec.yaml`: `^3.13.3`).
- Firebase Core, Firebase Authentication, dan Cloud Firestore.
- `shared_preferences` tersedia; `fake_cloud_firestore` digunakan dalam pengujian repository.
- SQLite melalui `sqflite` masih ada sebagai lapisan legacy.

Saat aplikasi berjalan, `main.dart` menginisialisasi Firebase, `AuthGate` memeriksa sesi login, lalu aplikasi membuat `TransactionStore` dengan `FirestoreFinanceRepository` untuk UID pengguna yang aktif. Lapisan SQLite (`DatabaseHelper` dan `SqliteFinanceRepository`) masih berada di proyek, tetapi bukan repository yang dipilih oleh alur utama saat ini. Jangan menganggap migrasi otomatis dari SQLite ke Firestore sudah berlangsung tanpa memeriksa implementasinya.

Data Firestore dipisahkan per pengguna:

```text
users/{uid}/transactions/{id}
users/{uid}/debts/{id}
users/{uid}/savings_goals/{id}
users/{uid}/financial_activities/{id}
```

Firestore menggunakan ID dokumen string dan timestamp Firestore untuk tanggal. Model mengubah timestamp menjadi `DateTime`. Repository Firestore mendengarkan perubahan melalui snapshot stream; perubahan diteruskan ke store dan UI.

## Struktur proyek

```text
pitie/
├── assets/
│   └── fonts/                 # Font Poppins dan Geist
├── docs/
│   ├── catatan.txt            # Catatan tindak lanjut dan checklist pengujian
│   └── ringkasan-proyek.md    # Peta proyek ini
├── lib/
│   ├── main.dart              # Inisialisasi Firebase, AuthGate, dan store per UID
│   ├── firebase_options.dart  # Konfigurasi Firebase per platform
│   ├── data/
│   │   └── transaction_store.dart # State aplikasi, logika operasi, dan PitieScope
│   ├── database/
│   │   └── database_helper.dart    # Implementasi SQLite legacy
│   ├── models/                # Model transaksi, utang, tabungan, aktivitas, kategori
│   ├── repositories/
│   │   ├── finance_repository.dart          # Kontrak repository
│   │   ├── firestore_finance_repository.dart # Implementasi Firestore aktif
│   │   └── sqlite_finance_repository.dart    # Implementasi SQLite legacy
│   ├── screens/
│   │   ├── auth/              # Layar login/registrasi
│   │   ├── dashboard_screen.dart
│   │   ├── transaction_screen.dart
│   │   ├── transaction_detail_screen.dart
│   │   ├── add_transaction_screen.dart
│   │   ├── debt_screen.dart
│   │   ├── savings_screen.dart
│   │   ├── savings_activity_form_screen.dart
│   │   └── report_screen.dart
│   ├── services/
│   │   └── auth_service.dart  # Pembungkus Firebase Authentication
│   ├── utils/                 # Tema, format Rupiah, dan utilitas UI
│   └── widgets/               # Kartu saldo, item transaksi, grafik
├── test/
│   ├── firestore_finance_repository_test.dart
│   └── widget_test.dart
├── android/, ios/, linux/, macos/, web/, windows/ # Dukungan platform Flutter
├── firebase.json
├── pubspec.yaml
└── README.md
```

## Pola arsitektur dan alur perubahan

```text
Screen / Widget
    ↓ PitieScope.of(context)
TransactionStore (ChangeNotifier)
    ↓ FinanceRepository
FirestoreFinanceRepository (aktif)
    └── Cloud Firestore per UID
```

`TransactionStore` menyimpan daftar transaksi, utang, target tabungan, dan aktivitas keuangan. Store berlangganan ke stream repository dan memanggil `notifyListeners()` saat data berubah. `PitieScope` menyediakan store kepada widget turunannya.

Untuk perubahan fitur:

1. Ikuti alur dari layar yang terkait ke `TransactionStore`, lalu ke `FinanceRepository`.
2. Letakkan akses penyimpanan dan operasi majemuk di repository; jangan menaruh query Firestore langsung di layar.
3. Pertahankan kontrak repository agar implementasi SQLite legacy tetap konsisten bila masih digunakan.
4. Jika mengubah skema, periksa model, konversi Firestore/legacy, repository, dan tes terkait.
5. Pertahankan cakupan data berdasarkan UID dan pastikan operasi majemuk tidak meninggalkan data parsial.

## Perilaku domain yang perlu dijaga

- Saldo, pemasukan, dan pengeluaran utama dihitung hanya dari transaksi dengan akun `main`. Transaksi dengan akun `savings` tidak masuk saldo utama.
- Menambahkan pinjaman (`loan`) membuat transaksi pembuka pemasukan kategori `Pinjaman`.
- Menambahkan piutang (`receivable`) membuat transaksi pembuka pengeluaran kategori `Piutang`.
- Menambahkan hutang (`debt`) tidak membuat transaksi pembuka.
- Pelunasan menandai utang lunas, mencatat aktivitas pelunasan, dan membuat transaksi pelunasan. Piutang menjadi pemasukan; pinjaman dan hutang menjadi pengeluaran.
- Setoran tabungan menambah `savedAmount`, mencatat aktivitas setoran, dan membuat transaksi pengeluaran kategori `Tabungan` pada akun `main`.
- Pemakaian tabungan mengurangi `savedAmount`, mencatat aktivitas pemakaian, dan membuat transaksi pengeluaran pada akun `savings`. Jumlah pemakaian tidak boleh melebihi saldo tabungan.
- Penghapusan semua utang juga membersihkan transaksi yang terhubung ke utang dan aktivitas pelunasan; aktivitas tabungan dan transaksi biasa harus tetap ada.
- Catatan pinjaman, hutang, dan piutang dapat diedit/dihapus. Transaksi pembuka dan transaksi/aktivitas pelunasan yang terkait diperbarui bersama agar saldo akun mengikuti perubahan.
- Validasi transaksi di repository menolak jumlah tidak valid atau kategori kosong. Operasi setoran/pemakaian juga memerlukan jumlah positif.
- Riwayat setoran/pemakaian tabungan terhubung ke transaksi dan aktivitas keuangan. Pengubahan/penghapusan riwayat memperbarui `savedAmount`; setoran tidak dapat dihapus jika menyebabkan saldo target negatif.
- Menghapus target dengan saldo tersisa membuat transaksi pemasukan pengembalian ke akun utama; riwayat transaksi sebelumnya tetap dipertahankan.
- Tampilan nominal memakai formatter bersama di `lib/utils/currency_formatter.dart` dengan format Rupiah Indonesia.
- Commit Firestore menunggu hingga sekitar 15 detik; operasi offline dapat menampilkan timeout meskipun perubahan mungkin tersinkron setelah koneksi pulih.

## Panduan pengembangan dan verifikasi

Perintah umum dari root proyek:

```powershell
flutter pub get
flutter analyze
flutter test
```

Untuk perubahan repository Firestore, jalankan tes terarah:

```powershell
flutter test test/firestore_finance_repository_test.dart
```

Checklist manual yang relevan tersimpan di [catatan.txt](./catatan.txt). Antara lain: verifikasi login dan pemisahan data per UID, operasi tambah/ubah/hapus transaksi, pembuatan dan pelunasan utang, aktivitas tabungan, pembaruan listener, serta sinkronisasi setelah koneksi pulih.

## Catatan tindak lanjut dari `catatan.txt`

Catatan yang sudah ada mengusulkan:

- memastikan pengeditan/penghapusan pinjaman berdampak benar pada saldo;
- memastikan penghapusan target tabungan yang memiliki saldo menangani saldo tersebut dengan benar;
- konsistensi format nominal Rupiah;
- pengeditan/penghapusan catatan utang serta aktivitas tabungan menjaga transaksi dan saldo terkait;
- menjalankan checklist fase 4 untuk autentikasi, transaksi, utang, tabungan, listener, dan sinkronisasi.

Perlakukan butir tersebut sebagai catatan kebutuhan/verifikasi, bukan bukti bahwa perilaku tersebut belum atau sudah sepenuhnya diimplementasikan. Periksa alur terkait dan konfirmasikan perilaku yang diinginkan sebelum mengubah aturan saldo, khususnya saat mengedit atau menghapus data yang menghasilkan transaksi.

## Dokumentasi terkait

- [README.md](../README.md): README bawaan Flutter yang saat ini masih berisi petunjuk proyek awal.
- [firebase_agent_guide.md](../firebase_agent_guide.md): panduan fase dan aturan kerja integrasi Firebase.
- [catatan.txt](./catatan.txt): catatan perubahan serta checklist pengujian manual.
