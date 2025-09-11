import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://paswxeiypkzqwakxltez.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhc3d4ZWl5cGt6cXdha3hsdGV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk2NzU2MTcsImV4cCI6MjA2NTI1MTYxN30.9c31jJphxK_raGKW8OAx6zf8d3i8FsSZ8tUW3ddKAuo',
  );
  runApp(MyApp());
}

// Get a reference to the Supabase client
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false, // This removes the debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool _isLoading = false;
  String _connectionStatus = "Not tested";

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  // Test Supabase connection
  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = "Testing...";
    });

    try {
      // Simple query to test connection
      final response = await supabase
          .from('constituency')
          .select('count')
          .count();

      setState(() {
        _isLoading = false;
        _connectionStatus = "✅ Connected! Found ${response.count} constituencies";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _connectionStatus = "❌ Connection failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test Supabase Connection'),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _connectionStatus,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}