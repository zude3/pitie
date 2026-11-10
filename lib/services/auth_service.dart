import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForCode(error.code));
    }
  }

  Future<UserCredential> register(String email, String password) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForCode(error.code));
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForCode(error.code));
    }
  }

  static String _messageForCode(String code) => switch (code) {
    'user-not-found' => 'Akun dengan alamat email tersebut tidak ditemukan.',
    'wrong-password' => 'Kata sandi yang dimasukkan salah.',
    'invalid-credential' => 'Email atau kata sandi tidak valid.',
    'email-already-in-use' => 'Alamat email sudah digunakan.',
    'weak-password' => 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.',
    'invalid-email' => 'Format alamat email tidak valid.',
    'network-request-failed' =>
      'Koneksi jaringan bermasalah. Periksa koneksi internet Anda.',
    'too-many-requests' => 'Terlalu banyak percobaan. Silakan coba lagi nanti.',
    _ => 'Terjadi kesalahan autentikasi. Silakan coba lagi.',
  };
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
