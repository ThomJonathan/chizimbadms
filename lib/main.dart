import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/login_page.dart';

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
      title: 'Election Results App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class ElectionHomeScreen extends StatefulWidget {
  const ElectionHomeScreen({super.key});

  @override
  State<ElectionHomeScreen> createState() => _ElectionHomeScreenState();
}

class _ElectionHomeScreenState extends State<ElectionHomeScreen> {
  List<Map<String, dynamic>> constituencies = [];
  List<Map<String, dynamic>> wards = [];
  List<Map<String, dynamic>> pollingStations = [];
  bool isLoading = false;
  String? selectedConstituency;
  String? selectedWard;

  @override
  void initState() {
    super.initState();
    _loadConstituencies();
  }

  // Load all constituencies
  Future<void> _loadConstituencies() async {
    setState(() => isLoading = true);

    try {
      final response = await supabase
          .from('constituency')
          .select('*')
          .order('name');

      setState(() {
        constituencies = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error loading constituencies: $e');
    }
  }

  // Load wards for selected constituency
  Future<void> _loadWards(String constituency) async {
    setState(() => isLoading = true);

    try {
      final response = await supabase
          .from('ward')
          .select('*')
          .eq('constituency', constituency)
          .order('name');

      setState(() {
        wards = List<Map<String, dynamic>>.from(response);
        pollingStations = []; // Clear polling stations
        selectedWard = null;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error loading wards: $e');
    }
  }

  // Load polling stations for selected ward
  Future<void> _loadPollingStations(String ward) async {
    setState(() => isLoading = true);

    try {
      final response = await supabase
          .from('polling_station')
          .select('*')
          .eq('ward', ward)
          .order('name');

      setState(() {
        pollingStations = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error loading polling stations: $e');
    }
  }

  // Test connection by inserting sample data
  Future<void> _testConnection() async {
    setState(() => isLoading = true);

    try {
      // Try to insert a test constituency (you can modify this)
      final testConstituency = 'Test Constituency ${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('constituency')
          .insert({
        'name': testConstituency,
        'district': 'Test District',
      });

      // Reload constituencies to show the new one
      await _loadConstituencies();

      _showSuccess('Connection successful! Test constituency added.');
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Connection failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Election Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConstituencies,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection test button
            ElevatedButton.icon(
              onPressed: _testConnection,
              icon: const Icon(Icons.wifi),
              label: const Text('Test Supabase Connection'),
            ),
            const SizedBox(height: 20),

            // Constituency dropdown
            const Text('Select Constituency:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedConstituency,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Choose a constituency'),
              items: constituencies.map((constituency) {
                return DropdownMenuItem<String>(
                  value: constituency['name'],
                  child: Text('${constituency['name']} (${constituency['district']})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedConstituency = value;
                  wards = [];
                  pollingStations = [];
                  selectedWard = null;
                });
                if (value != null) {
                  _loadWards(value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Ward dropdown (only show if constituency selected)
            if (selectedConstituency != null) ...[
              const Text('Select Ward:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedWard,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('Choose a ward'),
                items: wards.map((ward) {
                  return DropdownMenuItem<String>(
                    value: ward['name'],
                    child: Text(ward['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedWard = value;
                  });
                  if (value != null) {
                    _loadPollingStations(value);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            // Results section
            if (selectedConstituency != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Constituency: $selectedConstituency',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (constituencies.isNotEmpty) ...[
                        Builder(
                          builder: (context) {
                            final constituency = constituencies.firstWhere(
                                  (c) => c['name'] == selectedConstituency,
                              orElse: () => {},
                            );
                            if (constituency.isEmpty) return const SizedBox();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('District: ${constituency['district']}'),
                                Text('Candidate 1: ${constituency['candidate1']} votes'),
                                Text('Candidate 2: ${constituency['candidate2']} votes'),
                                Text('Candidate 3: ${constituency['candidate3']} votes'),
                                Text('Total: ${constituency['total']} votes',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Polling stations list
            if (pollingStations.isNotEmpty) ...[
              const Text('Polling Stations:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...pollingStations.map((station) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(station['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('C1: ${station['candidate1']}, C2: ${station['candidate2']}, C3: ${station['candidate3']}'),
                        Text('Total: ${station['total']} votes'),
                      ],
                    ),
                    trailing: station['total'] > 0
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.pending, color: Colors.orange),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}