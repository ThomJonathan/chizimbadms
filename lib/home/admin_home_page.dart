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
  int _selectedTab = 0;
  List<Map<String, dynamic>> _wardSummary = [];
  List<Map<String, dynamic>> _constSummary = [];
  List<Map<String, dynamic>> _pollingStations = [];
  List<Map<String, dynamic>> _monitors = [];
  int _recordedStations = 0;
  int _totalStations = 0;
  int _stationsWithoutMonitor = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final wardRes = await supabase.rpc('ward_vote_summary');
      _wardSummary = List<Map<String, dynamic>>.from(wardRes ?? []);

      final constRes = await supabase.rpc('constituency_vote_summary');
      _constSummary = List<Map<String, dynamic>>.from(constRes ?? []);

      final pollingRes = await supabase.from('polling_station').select('*');
      _pollingStations = List<Map<String, dynamic>>.from(pollingRes);
      _totalStations = _pollingStations.length;
      _recordedStations = _pollingStations.where((s) => (s['candidate1'] ?? 0) > 0 || (s['candidate2'] ?? 0) > 0 || (s['candidate3'] ?? 0) > 0).length;

      final monitorRes = await supabase.from('users').select('*').eq('role', 'monitor');
      _monitors = List<Map<String, dynamic>>.from(monitorRes);
      _stationsWithoutMonitor = _pollingStations.where((s) => s['monitor'] == null).length;
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildPollingTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Polling Station Status', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Recorded: $_recordedStations / $_totalStations', style: theme.textTheme.bodyLarge),
                Text('Remaining: ${_totalStations - _recordedStations}', style: theme.textTheme.bodyLarge),
                Text('Stations without Monitor: $_stationsWithoutMonitor', style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recorded Stations:', style: theme.textTheme.bodyLarge),
                ..._pollingStations.where((s) => (s['candidate1'] ?? 0) > 0 || (s['candidate2'] ?? 0) > 0 || (s['candidate3'] ?? 0) > 0).map((s) => Text(s['name'] ?? '', style: theme.textTheme.bodyMedium)),
                const SizedBox(height: 8),
                Text('Remaining Stations:', style: theme.textTheme.bodyLarge),
                ..._pollingStations.where((s) => (s['candidate1'] ?? 0) == 0 && (s['candidate2'] ?? 0) == 0 && (s['candidate3'] ?? 0) == 0).map((s) => Text(s['name'] ?? '', style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWardTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ward Vote Summary', style: theme.textTheme.titleLarge),
                ..._wardSummary.map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${w['ward_name']}: C1 ${w['candidate1']}  C2 ${w['candidate2']}  C3 ${w['candidate3']}  Total ${w['total']}',
                    style: theme.textTheme.bodyMedium,
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConstituencyTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Constituency Vote Summary', style: theme.textTheme.titleLarge),
                ..._constSummary.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${c['constituency_name']}: C1 ${c['candidate1']}  C2 ${c['candidate2']}  C3 ${c['candidate3']}  Total ${c['total']}',
                    style: theme.textTheme.bodyMedium,
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonitorTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monitor Status', style: theme.textTheme.titleLarge),
                ..._monitors.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Monitor: ${m['fullname']} | Phone: ${m['phone']} | Active: ${m['is_active'] ? 'Yes' : 'No'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
          : IndexedStack(
        index: _selectedTab,
        children: [
          _buildPollingTab(context),
          _buildWardTab(context),
          _buildConstituencyTab(context),
          _buildMonitorTab(context),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_vote),
            label: 'Polling Stations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Ward Summary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Constituency Summary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Monitors',
          ),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}