
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_page.dart';
import 'admin_monitors_tab.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildHomeTab(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Constituency Summary', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 12),
                  ..._constSummary.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${c['constituency_name']}: C1 ${c['candidate1']}  C2 ${c['candidate2']}  C3 ${c['candidate3']}  Total ${c['total']}',
                          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
                        ),
                      )),
                  const SizedBox(height: 16),
                  Divider(),
                  Text('Polling Station Progress', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text('Reported: $_recordedStations / $_totalStations', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface)),
                  Text('Remaining: ${_totalStations - _recordedStations}', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _totalStations == 0 ? 0 : _recordedStations / _totalStations,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Divider(),
                  Text('Recent Submissions', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                  ..._pollingStations.where((s) => (s['candidate1'] ?? 0) > 0 || (s['candidate2'] ?? 0) > 0 || (s['candidate3'] ?? 0) > 0).take(5).map((s) => ListTile(
                        title: Text(s['name'] ?? '', style: theme.textTheme.bodyMedium),
                        subtitle: Text('C1: ${s['candidate1']}  C2: ${s['candidate2']}  C3: ${s['candidate3']}'),
                        leading: Icon(Icons.how_to_vote, color: theme.colorScheme.primary),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardTab(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ward Summary', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 12),
                  ..._wardSummary.map((w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${w['ward_name']}:', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface)),
                            Text('C1: ${w['candidate1']}  C2: ${w['candidate2']}  C3: ${w['candidate3']}  Total: ${w['total']}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.8))),
                            Divider(),
                            Text('Polling Stations:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                            ..._pollingStations.where((s) => s['ward'] == w['ward_name']).map((s) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        (s['candidate1'] ?? 0) > 0 || (s['candidate2'] ?? 0) > 0 || (s['candidate3'] ?? 0) > 0
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: (s['candidate1'] ?? 0) > 0 || (s['candidate2'] ?? 0) > 0 || (s['candidate3'] ?? 0) > 0
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outline,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(s['name'] ?? '', style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false),
            child: const Text('Logout'),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onPrimary),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedTab,
              children: [
                _buildHomeTab(context),
                _buildWardTab(context),
                AdminMonitorsTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.outline,
        backgroundColor: theme.colorScheme.surface,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Ward Summary',
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
