# Panduan Kerja Agent AI: Integrasi Firebase ke Aplikasi Pitie (Flutter)

Dokumen ini adalah instruksi kerja untuk agent AI (GitHub Copilot atau sejenisnya) yang mengerjakan integrasi Firebase pada aplikasi manajemen keuangan "Pitie". Baca seluruh dokumen sebelum menulis kode. Kerjakan fase secara berurutan.

## 1. Tujuan

Mengganti penyimpanan lokal (sqflite) dengan Firebase:

- Firebase Authentication: login per pengguna.
- Cloud Firestore: penyimpanan data per pengguna, dengan dukungan offline.
- Migrasi satu kali data SQLite lama ke Firestore.

Perilaku aplikasi dari sisi pengguna tidak boleh berubah, kecuali penambahan layar login dan tombol logout.

## 2. Aturan Umum (wajib)

1. Kerjakan satu fase per sesi. Jangan menggabungkan fase.
2. Sebelum mengubah file, baca file itu dan file yang bergantung padanya.
3. Jangan mengubah UI, tema, atau logika perhitungan (`balance`, `income`, `expenses`, laporan) kecuali fase tersebut secara eksplisit memintanya.
4. Setelah setiap fase jalankan `flutter analyze`. Hasilnya harus tanpa error dan tanpa warning baru.
5. Jangan menghapus `database_helper.dart` dan dependensi `sqflite` sebelum Fase 7.
6. Jangan menambahkan dependensi di luar daftar di bagian 5 tanpa izin pemilik project.
7. Untuk versi paket, pakai versi stabil terbaru dari pub.dev dan jangan menebak nomor versi. Satu set paket FlutterFire harus kompatibel satu sama lain.
8. Jangan menulis kunci rahasia, service account, atau file kredensial ke repository. `firebase_options.dart` dan `google-services.json` boleh, tetapi bukan kunci admin.
9. Jangan membuat perubahan besar di luar lingkup fase. Jika menemukan bug lain, catat saja di bagian "Catatan temuan" pada akhir jawaban.
10. Tulis kode dan komentar dalam gaya yang sudah ada di project (nama Inggris untuk identifier, teks UI tetap bahasa Indonesia).
11. Di akhir setiap fase, laporkan: file yang diubah, apa yang diubah, hasil `flutter analyze`, dan cara memverifikasi manual.

## 3. Arsitektur Saat Ini

Folder: `lib/`

```
main.dart                      # inisialisasi TransactionStore, PitieApp
database/database_helper.dart  # sqflite, DB versi 5, ID int autoincrement
data/transaction_store.dart    # ChangeNotifier + PitieScope (InheritedNotifier)
models/                        # transaction, debt, savings_goal, financial_activity, category
screens/                       # dashboard, transaction, transaction_detail, add_transaction,
                               # debt, savings, report
widgets/                       # transaction_item, weekly_expense_chart, balance_card
utils/app_theme.dart
```

Alur data: `Screen -> PitieScope.of(context) -> TransactionStore -> DatabaseHelper`.

Semua screen hanya berinteraksi dengan `TransactionStore`. Pertahankan prinsip ini.

Fakta penting tentang kode saat ini:

- ID semua entitas bertipe `int`. Transaksi menyimpan `debtId` dan `savingsGoalId` bertipe `int?`.
- `TransactionStore.refresh()` memuat ulang semua data lalu `notifyListeners()`.
- Saldo utama dihitung hanya dari transaksi dengan `account == TransactionAccount.main`. Transaksi `account == savings` tidak masuk saldo utama.
- Operasi majemuk yang harus tetap atomik:
  - `insertDebt`: debt + transaksi pembuka (hanya tipe `loan` = income "Pinjaman", dan `receivable` = expense "Piutang"; tipe `debt` tidak membuat transaksi).
  - `repayDebt`: update debt (`is_paid`, `paid_at`) + activity `debt_repayment` + transaksi pelunasan. Transaksi bertipe income jika `receivable`, selain itu expense. Kategori: "Pelunasan pinjaman" / "Pelunasan piutang" / "Pelunasan hutang".
  - `recordSavingsDeposit`: `saved_amount += amount` + activity `savings_deposit` + transaksi expense kategori "Tabungan", account `main`, deskripsi "Setoran tabungan: {nama}".
  - `recordSavingsUse`: `saved_amount -= amount` (tidak boleh negatif) + activity `savings_use` + transaksi expense, account `savings`, deskripsi "Pemakaian tabungan: {kategori}".
  - `clearDebts`: hapus transaksi dengan `debt_id` tidak null, activity `debt_repayment`, dan semua debt.

## 4. Arsitektur Target

```
Screen -> PitieScope -> TransactionStore -> FinanceRepository (abstract)
                                              |- SqliteFinanceRepository     (sementara, membungkus DatabaseHelper)
                                              |- FirestoreFinanceRepository  (baru)
```

Struktur Firestore (semua di bawah dokumen pengguna):

```
users/{uid}/transactions/{id}
users/{uid}/debts/{id}
users/{uid}/savings_goals/{id}
users/{uid}/financial_activities/{id}
```

Pemetaan field (camelCase di Firestore):

| Koleksi | Field |
|---|---|
| transactions | type (`income`/`expense`), amount (number), category, description, date (Timestamp), createdAt (Timestamp), account (`main`/`savings`), debtId (string?), savingsGoalId (string?) |
| debts | amount, recipient, category, date (Timestamp), note, isPaid (bool), dueDate (Timestamp?), paidAt (Timestamp?), type (`loan`/`debt`/`receivable`) |
| savings_goals | name, targetAmount, savedAmount, createdAt (Timestamp) |
| financial_activities | kind (`debt_repayment`/`savings_deposit`/`savings_use`), amount, title, date (Timestamp) |

Aturan pemetaan:

- Tanggal disimpan sebagai `Timestamp`, bukan string ISO. Di model gunakan `DateTime`.
- ID dokumen adalah `String`. ID dibuat klien dengan `collection.doc().id` sebelum batch dibuat, supaya dokumen terkait (misalnya `debtId`) dapat direferensikan dalam satu batch.
- Store sebaiknya memakai snapshot listener (`snapshots()`) yang memanggil `notifyListeners()`, bukan `refresh()` manual.

## 5. Dependensi

Tambahkan di `pubspec.yaml` (versi: terbaru yang stabil):

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `google_sign_in` (opsional, hanya jika pemilik meminta login Google)
- `shared_preferences` (untuk penanda migrasi)

Dev dependency untuk pengujian:

- `fake_cloud_firestore` (atau gunakan Firebase Emulator)
- `firebase_auth_mocks` (opsional)

## 6. Fase Pengerjaan

### Fase 0: Setup Firebase

Tugas pemilik (manual, agent hanya memandu):

- Buat project di Firebase Console, aktifkan Authentication (Email/Password) dan Cloud Firestore (mode production).
- Jalankan `flutterfire configure` untuk menghasilkan `lib/firebase_options.dart`.
- Jika memakai Google Sign-In, daftarkan SHA-1 dan SHA-256 debug/release di console, lalu unduh ulang `google-services.json`.

Tugas agent:

- Tambahkan dependensi pada bagian 5.
- Pastikan konfigurasi Gradle Android sesuai petunjuk FlutterFire (plugin `com.google.gms.google-services`, `minSdk` yang dibutuhkan).
- Di `main()`: `WidgetsFlutterBinding.ensureInitialized()` lalu `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

Selesai jika: aplikasi berjalan di emulator/perangkat tanpa error inisialisasi, dan perilaku lain tidak berubah.

### Fase 1: Autentikasi

File baru:

- `lib/services/auth_service.dart`: pembungkus `FirebaseAuth` (`signIn`, `register`, `signOut`, `authStateChanges`, terjemahan pesan error ke bahasa Indonesia).
- `lib/screens/auth/login_screen.dart` (login dan daftar; boleh satu layar dengan tab).

File diubah:

- `lib/main.dart`: tambahkan `AuthGate` (StreamBuilder pada `authStateChanges`). Belum login -> `LoginScreen`. Sudah login -> `PitieScope` + `DashboardScreen`.
- `lib/screens/dashboard_screen.dart`: tambahkan aksi logout (menu kecil di AppBar atau area header). Ikuti gaya UI yang ada.

Catatan:

- Pada fase ini `TransactionStore` masih memakai SQLite. Pembuatan store per uid dilakukan penuh di Fase 4.
- Tampilkan loading saat status auth belum diketahui.
- Validasi form: email valid, password minimal 6 karakter.

Selesai jika: daftar, login, logout berfungsi; sesi bertahan setelah aplikasi ditutup; pesan error tampil dalam bahasa Indonesia.

### Fase 2: Ekstrak `FinanceRepository`

File baru:

- `lib/repositories/finance_repository.dart`: abstract class dengan semua metode publik yang dipakai store saat ini. Disarankan:
  - `Stream<List<TransactionModel>> watchTransactions()` dan stream serupa untuk debts, savings goals, financial activities.
  - `Future<void> addTransaction(...)`, `updateTransaction(...)`, `deleteTransaction(id)`.
  - `Future<void> addDebt(DebtModel debt, {TransactionModel? openingTransaction})`.
  - `Future<bool> repayDebt(String id, DateTime paidAt)`.
  - `Future<void> addSavingsGoal(...)`, `recordSavingsDeposit(...)`, `recordSavingsUse(...)`.
  - `Future<void> clearDebts()`.
- `lib/repositories/sqlite_finance_repository.dart`: membungkus `DatabaseHelper`. Karena SQLite tidak punya stream, boleh memakai `StreamController` yang di-emit ulang setelah setiap penulisan.

File diubah:

- `lib/data/transaction_store.dart`: bergantung pada `FinanceRepository` (injeksi lewat konstruktor), bukan `DatabaseHelper`.

Aturan:

- Tidak ada perubahan perilaku. Semua validasi yang sudah ada di store (jumlah > 0, saldo tabungan cukup, kategori tidak kosong) tetap ada.
- Pada fase ini ID masih `int`. Jika interface harus menyebut tipe ID, gunakan tipe generik atau `String` dengan konversi sementara. Pilih yang paling sederhana dan jelaskan pilihannya di laporan.

Selesai jika: seluruh fitur berjalan identik dengan sebelum fase ini.

### Fase 3: Migrasi Model ke ID `String` dan Firestore

File diubah: semua file di `lib/models/` (kecuali `category_model.dart`).

- `id`, `debtId`, `savingsGoalId` menjadi `String?`.
- Ganti `fromMap/toMap` dengan `fromFirestore(DocumentSnapshot)` dan `toFirestore()`. Tanggal memakai `Timestamp`.
- Pertahankan konstruktor, getter (`isOverdue`, `status`, `icon`), dan enum yang ada.
- Pertahankan `fromMap/toMap` lama jika masih dibutuhkan oleh `SqliteFinanceRepository` atau migrator Fase 6 (boleh dipindah menjadi factory bernama `fromLegacyMap`).

Screen yang harus disesuaikan karena tipe ID berubah:

- `lib/screens/debt_screen.dart`: perbandingan `transaction.debtId == debt.id`.
- `lib/screens/savings_screen.dart`: `_goalId` dan `DropdownButton<int>` menjadi `String`; perbandingan `item.id == goal.id`; `savingsGoalId == current.id`.
- `lib/screens/transaction_detail_screen.dart`: `remove(transaction.id!)` dan perbandingan ID.
- `lib/screens/add_transaction_screen.dart`: `id: widget.transaction?.id`.
- `lib/data/transaction_store.dart` dan repository: tipe parameter ID.

Selesai jika: `flutter analyze` bersih. Selama Fase 3, `SqliteFinanceRepository` boleh mengonversi `int <-> String` dengan `toString()`/`int.parse` agar aplikasi tetap berjalan.

### Fase 4: `FirestoreFinanceRepository`

File baru: `lib/repositories/firestore_finance_repository.dart`, menerima `FirebaseFirestore` dan `uid`.

Referensi koleksi: `firestore.collection('users').doc(uid).collection('transactions')`, dan seterusnya.

Operasi:

- Stream: `snapshots()` dengan urutan yang sama seperti query SQLite lama (transaksi: `date` desc lalu `createdAt` desc; debts: `date` desc; savings goals: `createdAt` desc; activities: `date` desc).
- CRUD transaksi: `set`, `update`, `delete`. Validasi `_validateTransaction` dipindah ke store atau repository supaya tetap berlaku.
- `addDebt`: satu `WriteBatch`. Buat ID debt dengan `doc().id` lebih dulu. Jika ada transaksi pembuka, set dengan `debtId` tersebut.
- `repayDebt`: satu `WriteBatch`: update debt (`isPaid: true`, `paidAt`) + tambah activity + tambah transaksi pelunasan (aturan tipe/kategori di bagian 3). Cek "sudah lunas" memakai data lokal dari store sebelum memanggil repository (mengembalikan `false` jika sudah lunas).
- `recordSavingsDeposit` / `recordSavingsUse`: satu `WriteBatch` dengan `FieldValue.increment(amount)` atau `FieldValue.increment(-amount)` pada `savedAmount`, plus activity dan transaksi sesuai aturan bagian 3. Pengecekan saldo cukup dilakukan di store dengan data lokal, dan diperkuat oleh security rules.
- `clearDebts`: query transaksi dengan `debtId != null`, activity `kind == 'debt_repayment'`, dan semua debts. Hapus dalam batch maksimal 500 operasi per batch.

File diubah:

- `lib/main.dart` / `AuthGate`: setelah login, buat `TransactionStore(FirestoreFinanceRepository(uid))` dan sediakan lewat `PitieScope`. Saat logout, batalkan semua subscription dan buang store.
- `TransactionStore`: berlangganan stream, simpan hasilnya ke `transactions`, `debts`, `savingsGoals`, `financialActivities`, lalu `notifyListeners()`. Tambahkan `dispose()` yang membatalkan subscription. Hapus panggilan `refresh()` setelah penulisan.

Aturan penting:

- Jangan memakai `runTransaction` untuk operasi di atas. `runTransaction` membutuhkan koneksi, sedangkan `WriteBatch` bekerja offline.
- `await batch.commit()` pada mode offline baru selesai setelah server mengonfirmasi. Di UI, jangan memblokir layar menunggu commit tanpa batas. Tutup form setelah operasi dikirim, dan biarkan listener memperbarui daftar. Jika memakai `await`, tambahkan timeout atau tangani kasus offline secara eksplisit.
- Jangan menyimpan field turunan (misalnya saldo total). Saldo tetap dihitung di store.

Selesai jika: semua alur utama berjalan dengan Firestore (transaksi, utang, tabungan), termasuk saat perangkat offline lalu online kembali.

### Fase 5: Security Rules dan Indeks

File baru di root project: `firestore.rules` (dan `firestore.indexes.json` jika Firestore meminta indeks komposit).

Kerangka rules (sesuaikan dan perketat per koleksi):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

Perketat dengan validasi:

- `transactions`: `amount > 0`, `type in ['income','expense']`, `category` string tidak kosong, `account in ['main','savings']`.
- `savings_goals`: `savedAmount >= 0`, `targetAmount > 0`.
- `debts`: `amount > 0`, `type in ['loan','debt','receivable']`.
- `financial_activities`: `kind` valid, `amount > 0`.

Selesai jika: pengguna A tidak dapat membaca atau menulis data pengguna B (uji lewat emulator), dan semua alur aplikasi tetap berjalan.

### Fase 6: Migrasi Data Lokal ke Cloud

File baru: `lib/services/local_data_migrator.dart`.

Langkah:

1. Setelah login pertama, cek penanda migrasi (kunci per uid di `SharedPreferences`, atau field di dokumen `users/{uid}`). Jika sudah ada, lewati.
2. Jika file database lokal tidak ada atau kosong, tandai selesai dan lewati.
3. Baca semua baris dari SQLite (`DatabaseHelper`): transactions, debts, savings_goals, financial_activities.
4. Unggah dengan ID dokumen deterministik, misalnya `t_{idLama}`, `d_{idLama}`, `g_{idLama}`, `a_{idLama}`. Petakan `debt_id` ke `d_{debt_id}` dan `savings_goal_id` ke `g_{savings_goal_id}`. Dengan begitu migrasi aman diulang tanpa menggandakan data.
5. Tulis dalam batch maksimal 500 operasi.
6. Setelah semua batch berhasil, set penanda migrasi.
7. Jangan hapus `pitie.db` pada fase ini.

Catatan: kolom `type` pada tabel `debts` lama bisa berisi nilai `'debt'`, `'loan'`, `'receivable'`, dan pada jalur migrasi lama pernah ada default `'hutang'`. Petakan nilai tak dikenal ke `debt`.

Selesai jika: pengguna lama login pertama kali dan seluruh data lamanya muncul di aplikasi; menjalankan migrasi dua kali tidak menggandakan data.

### Fase 7: Pengujian dan Pembersihan

- Tulis unit test untuk `TransactionStore` memakai `fake_cloud_firestore` atau repository palsu: saldo, saldo tabungan, pelunasan (3 tipe), setor/pakai tabungan, `clearDebts`.
- Uji manual (checklist):
  - Tambah, ubah, hapus transaksi.
  - Pinjaman, hutang, piutang: buat, lunasi, hapus semua.
  - Target tabungan: buat, setor, pakai, pakai melebihi saldo (harus ditolak).
  - Mode pesawat: buat data, nyalakan jaringan, data tersinkron.
  - Ganti akun: data akun sebelumnya tidak terlihat.
  - Laporan mingguan dan grafik tetap benar.
- Pembersihan (hanya jika pemilik menyetujui): hapus `SqliteFinanceRepository` dan `DatabaseHelper`, hapus `sqflite` dan `path` dari `pubspec.yaml`, hapus kode migrator setelah semua pengguna termigrasi.

## 7. Definisi Selesai (setiap fase)

- `flutter analyze` tanpa error dan tanpa warning baru.
- Aplikasi dapat dijalankan (`flutter run`) dan alur yang relevan diuji manual.
- Tidak ada perubahan di luar lingkup fase.
- Laporan fase ditulis sesuai aturan nomor 11.

## 8. Larangan

- Jangan mengganti state management (tetap `ChangeNotifier` + `InheritedNotifier`).
- Jangan menambahkan Provider, Riverpod, Bloc, atau GetX.
- Jangan mengubah tampilan atau teks UI yang sudah ada tanpa diminta.
- Jangan mengubah aturan perhitungan saldo atau laporan.
- Jangan commit kunci rahasia atau kredensial admin.
- Jangan mengerjakan fase berikutnya sebelum pemilik mengonfirmasi fase saat ini selesai.

## 9. Template Prompt per Fase

Gunakan format ini saat memberi tugas ke agent:

```
Konteks: baca AGENTS.md / FIREBASE_AGENT_GUIDE.md.
Tugas: kerjakan Fase N saja.
File yang relevan: <daftar file>.
Jangan mengerjakan fase lain. Di akhir, laporkan sesuai aturan nomor 11.
```