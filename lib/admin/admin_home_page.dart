import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_page.dart';

final supabase = Supabase.instance.client;

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  bool _loading = true;
  List<Map<String, dynamic>> _summary = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.from('vote_summary').select('*').order('constituency_name');
      _summary = List<Map<String, dynamic>>.from(res);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Home'),
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
          : ListView.builder(
              itemCount: _summary.length,
              itemBuilder: (ctx, i) {
                final c = _summary[i];
                return ListTile(
                  title: Text(c['constituency_name'] ?? ''),
                  subtitle: Text('C1 ${c['const_candidate1']}  C2 ${c['const_candidate2']}  C3 ${c['const_candidate3']}  Total ${c['const_total']}  Winner ${c['winner']}'),
                );
              },
            ),
    );
  }
}
