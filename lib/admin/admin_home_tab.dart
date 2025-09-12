import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _constSummary = [];
  List<Map<String, dynamic>> _pollingStations = [];
  int _recordedStations = 0;
  int _totalStations = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final constRes = await supabase.rpc('constituency_vote_summary');
      _constSummary = List<Map<String, dynamic>>.from(constRes ?? []);
      final pollingRes = await supabase.from('polling_station').select('*');
      _pollingStations = List<Map<String, dynamic>>.from(pollingRes);
      _totalStations = _pollingStations.length;
      _recordedStations = _pollingStations.where((s) => (s['candidate1'] ?? 0) > 0 || (s['candidate2'] ?? 0) > 0 || (s['candidate3'] ?? 0) > 0).length;
    } catch (e) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
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
          );
  }
}
