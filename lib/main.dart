import 'package:addiction_tracker/sourceCode/Loading.dart';
import 'package:flutter/material.dart';

import 'sourceCode/NotificationService.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize NUVEXA notification service.
  await NotificationService.instance.initialize();

  // Restore/synchronize notifications from saved settings.
  await NotificationService.instance.syncNotifications();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NUVEXA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const Loading(),
    );
  }
}
