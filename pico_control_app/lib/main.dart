import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ble_controller.dart';
import 'dashboard_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock orientation to landscape
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Use light status bar on dark background
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0C0C0E),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const PicoControlApp());
}

class PicoControlApp extends StatefulWidget {
  const PicoControlApp({super.key});

  @override
  State<PicoControlApp> createState() => _PicoControlAppState();
}

class _PicoControlAppState extends State<PicoControlApp> {
  final BleController _bleController = BleController();

  @override
  void dispose() {
    _bleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'John Trucker Hawani Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0C0E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFFB300),
          surface: Color(0xFF1E1E24),
          error: Colors.redAccent,
        ),
      ),
      home: DashboardPage(controller: _bleController),
    );
  }
}
