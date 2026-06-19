import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:centinel8/providers/auth_provider.dart';
import 'package:centinel8/screens/splash_screen.dart';
import 'package:centinel8/screens/login_screen.dart';
import 'package:centinel8/screens/forgot_password_screen.dart';
import 'package:centinel8/screens/admin_users_screen.dart';
import 'package:centinel8/screens/register_screen.dart';
import 'package:centinel8/screens/home_screen.dart';
import 'package:centinel8/screens/incident_report_screen.dart';
import 'package:centinel8/screens/panic_button_screen.dart';
import 'package:centinel8/screens/map_screen.dart';
import 'package:centinel8/screens/history_screen.dart';
import 'package:centinel8/screens/profile_screen.dart';
import 'package:centinel8/screens/admin_dashboard_screen.dart';
import 'package:centinel8/screens/admin_reports_screen.dart';
import 'package:centinel8/screens/reset_password_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const Centinel8App(),
    ),
  );
}

class Centinel8App extends StatelessWidget {
  const Centinel8App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Centinel8',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          brightness: Brightness.light,
          primary: const Color(0xFF0D47A1),
          secondary: const Color(0xFFFFA000),
          error: const Color(0xFFD32F2F),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          brightness: Brightness.dark,
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFFFFB300),
          error: const Color(0xFFE53935),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.black,
            elevation: 4,
          ),
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/admin/users': (context) => const AdminUsersScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/report': (context) => const IncidentReportScreen(),
        '/panic': (context) => const PanicButtonScreen(),
        '/map': (context) => const MapScreen(),
        '/history': (context) => const HistoryScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/dashboard': (context) => const AdminDashboardScreen(),
        '/reports': (context) => const AdminReportsScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
      },
    );
  }
}
