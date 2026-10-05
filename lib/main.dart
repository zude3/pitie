import 'package:flutter/material.dart';

import 'data/transaction_store.dart';
import 'screens/dashboard_screen.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        home: const DashboardScreen(),
      ),
    );
  }
}
