import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/transaction_store.dart';
import 'firebase_options.dart';
import 'repositories/firestore_finance_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'utils/app_scaffold_messenger.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PitieApp());
}

class PitieApp extends StatelessWidget {
  const PitieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: appScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Pitie',
      theme: AppTheme.lightTheme,
      home: const DashboardScreen(),
      builder: (context, child) =>
          AuthGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({required this.child, super.key});

  final Widget child;

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
        return _AuthenticatedHome(
          key: ValueKey(snapshot.data!.uid),
          uid: snapshot.data!.uid,
          child: widget.child,
        );
      },
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({required this.uid, required this.child, super.key});

  final String uid;
  final Widget child;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late final TransactionStore _store;

  @override
  void initState() {
    super.initState();
    _store = TransactionStore(
      repository: FirestoreFinanceRepository(
        FirebaseFirestore.instance,
        uid: widget.uid,
      ),
    );
    unawaited(_store.initialize());
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PitieScope(notifier: _store, child: widget.child);
}
