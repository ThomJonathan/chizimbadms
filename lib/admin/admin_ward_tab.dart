import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AdminWardTab extends StatefulWidget {
  const AdminWardTab({super.key});

  @override
  State<AdminWardTab> createState() => _AdminWardTabState();
}

class _AdminWardTabState extends State<AdminWardTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _wardSummary = [];
  List<Map<String, dynamic>> _pollingStations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final wardRes = await supabase.rpc('ward_vote_summary');
      _wardSummary = List<Map<String, dynamic>>.from(wardRes ?? []);
      final pollingRes = await supabase.from('polling_station').select('*');
      _pollingStations = List<Map<String, dynamic>>.from(pollingRes);
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
          );
  }
}
