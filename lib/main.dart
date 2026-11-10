import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/transaction_store.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final store = TransactionStore();
  try {
    await store.initialize();
  } catch (_) {
    // The screens remain usable and report operation errors through the UI.
  }
  runApp(PitieApp(store: store));
}

class PitieApp extends StatelessWidget {
  const PitieApp({required this.store, super.key});

  final TransactionStore store;

  @override
  Widget build(BuildContext context) {
    return PitieScope(
      notifier: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pitie',
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStateChanges = AuthService().authStateChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memeriksa status autentikasi: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (snapshot.data == null) return const LoginScreen();
        return const DashboardScreen();
      },
    );
  }
}
