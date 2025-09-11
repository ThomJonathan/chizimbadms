import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_page.dart';

final supabase = Supabase.instance.client;

class MonitorHomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const MonitorHomePage({super.key, required this.user});

  @override
  State<MonitorHomePage> createState() => _MonitorHomePageState();
}

class _MonitorHomePageState extends State<MonitorHomePage> {
  Map<String, dynamic>? _station;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyStation();
  }

  Future<void> _loadMyStation() async {
    setState(() => _loading = true);
    try {
      final phone = widget.user['phone'] as String;
      final rows = await supabase.rpc('get_monitor_station', params: {
        'monitor_phone': phone,
      });
      if (rows is List && rows.isNotEmpty) {
        _station = Map<String, dynamic>.from(rows.first);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor Home'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false),
            child: const Text('Logout'),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _station == null
              ? const Center(child: Text('No station assigned'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Station: ${_station!['station_name']}'),
                      Text('Ward: ${_station!['ward_name']}'),
                      const SizedBox(height: 12),
                      Text('C1: ${_station!['candidate1']}'),
                      Text('C2: ${_station!['candidate2']}'),
                      Text('C3: ${_station!['candidate3']}'),
                      Text('Total: ${_station!['total']}'),
                    ],
                  ),
                ),
    );
  }
}
