// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ml/model_loader.dart';
import 'services/notification_service.dart';
import 'services/websocket_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transaction_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/alerts_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Boot services
  await NotificationService().init();
  await ModelLoader().load();

  runApp(const FraudGuardApp());
}

class FraudGuardApp extends StatelessWidget {
  const FraudGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FraudGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/':            (_) => const SplashScreen(),
        '/login':       (_) => const LoginScreen(),
        '/dashboard':   (_) => const MainShell(),
        '/transactions':(_) => const TransactionScreen(),
        '/alerts':      (_) => const AlertsScreen(),
        '/settings':    (_) => const SettingsScreen(),
        '/analyze':     (_) => const TransactionScreen(),
      },
    );
  }
}

/// Bottom-nav shell wrapping the primary tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    TransactionScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];

  @override
  void dispose() {
    WebSocketService().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Transactions'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
