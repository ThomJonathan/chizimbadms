import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/login_page.dart';
import 'auth/sessionManager.dart';
import 'admin/admin_home_page.dart';
import 'Monitor/monitor_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://paswxeiypkzqwakxltez.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhc3d4ZWl5cGt6cXdha3hsdGV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk2NzU2MTcsImV4cCI6MjA2NTI1MTYxN30.9c31jJphxK_raGKW8OAx6zf8d3i8FsSZ8tUW3ddKAuo',
  );

  // Initialize SessionManager
  await SessionManager.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Election Monitoring System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
      // Add these routes to fix the error
      routes: {
        '/login': (context) => const LoginPage(),
        // Add other routes if needed
      },
      onGenerateRoute: (settings) {
        // You can add more complex route generation here if needed
        return null;
      },
      onUnknownRoute: (settings) {
        // Fallback for unknown routes
        return MaterialPageRoute(
          builder: (context) => const LoginPage(), // or a custom error page
        );
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final sessionManager = SessionManager.instance;
      final isLoggedIn = await sessionManager.isLoggedIn();

      if (isLoggedIn) {
        final userData = await sessionManager.getCurrentUser();
        if (userData != null && mounted) {
          _navigateToHome(userData);
          return;
        }
      }
    } catch (e) {
      // If there's an error checking session, go to login
      debugPrint('Error checking session: $e');
    }

    // If no valid session, go to login
    if (mounted) {
      _navigateToLogin();
    }
  }

  void _navigateToHome(Map<String, dynamic> user) {
    if (!mounted) return;

    Widget homePage;
    if (user['role'] == 'admin') {
      homePage = AdminHomePage(user: user);
    } else if (user['role'] == 'monitor') {
      homePage = MonitorHomePage(user: user);
    } else {
      // Invalid role, go to login
      _navigateToLogin();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => homePage),
    );
  }

  void _navigateToLogin() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_vote,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Election Monitoring System',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}