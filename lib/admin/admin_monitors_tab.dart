import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AdminMonitorsTab extends StatefulWidget {
  const AdminMonitorsTab({super.key});

  @override
  State<AdminMonitorsTab> createState() => _AdminMonitorsTabState();
}

class _AdminMonitorsTabState extends State<AdminMonitorsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _monitors = [];
  List<Map<String, dynamic>> _pollingStations = [];
  List<Map<String, dynamic>> _unassignedStations = [];
  List<Map<String, dynamic>> _assignedStations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final monitorRes = await supabase.from('users').select('*').eq('role', 'monitor');
      _monitors = List<Map<String, dynamic>>.from(monitorRes);
      final pollingRes = await supabase.from('polling_station').select('*');
      _pollingStations = List<Map<String, dynamic>>.from(pollingRes);
      
      // Separate assigned and unassigned stations
      _unassignedStations = _pollingStations.where((s) => s['monitor'] == null).toList();
      _assignedStations = _pollingStations.where((s) => s['monitor'] != null).toList();
    } catch (e) {
      _showSnack('Error loading data: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message, [bool isError = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _assignMonitor(String stationId, String monitorId) async {
    try {
      await supabase
          .from('polling_station')
          .update({'monitor': monitorId})
          .eq('id', stationId);
      
      _showSnack('Monitor assigned successfully!');
      _loadData();
    } catch (e) {
      _showSnack('Error assigning monitor: $e', true);
    }
  }

  Future<void> _unassignMonitor(String stationId) async {
    try {
      await supabase
          .from('polling_station')
          .update({'monitor': null})
          .eq('id', stationId);
      
      _showSnack('Monitor unassigned successfully!');
      _loadData();
    } catch (e) {
      _showSnack('Error unassigning monitor: $e', true);
    }
  }

  Future<void> _reassignMonitor(String stationId, String newMonitorId) async {
    try {
      await supabase
          .from('polling_station')
          .update({'monitor': newMonitorId})
          .eq('id', stationId);
      
      _showSnack('Monitor reassigned successfully!');
      _loadData();
    } catch (e) {
      _showSnack('Error reassigning monitor: $e', true);
    }
  }

  void _showAssignDialog(Map<String, dynamic> station) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Monitor to ${station['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a monitor to assign to this polling station:'),
            SizedBox(height: 16),
            ..._monitors.map((monitor) => ListTile(
              leading: CircleAvatar(
                child: Text((monitor['fullname'] ?? 'U')[0].toUpperCase()),
              ),
              title: Text(monitor['fullname'] ?? 'Unknown Monitor'),
              subtitle: Text(monitor['phone'] ?? 'No phone'),
              trailing: monitor['is_active'] == true
                ? Icon(Icons.check_circle, color: Colors.green)
                : Icon(Icons.cancel, color: Colors.red),
              onTap: () {
                Navigator.pop(context);
                _assignMonitor(station['id'], monitor['id']);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showReassignDialog(Map<String, dynamic> station) {
    final currentMonitor = _monitors.firstWhere(
      (m) => m['id'] == station['monitor'],
      orElse: () => {},
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reassign Monitor for ${station['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentMonitor.isNotEmpty) ...[
              Text('Current Monitor: ${currentMonitor['fullname']}'),
              SizedBox(height: 16),
            ],
            Text('Select a new monitor:'),
            SizedBox(height: 16),
            ..._monitors.map((monitor) => ListTile(
              leading: CircleAvatar(
                child: Text((monitor['fullname'] ?? 'U')[0].toUpperCase()),
              ),
              title: Text(monitor['fullname'] ?? 'Unknown Monitor'),
              subtitle: Text(monitor['phone'] ?? 'No phone'),
              trailing: monitor['is_active'] == true
                ? Icon(Icons.check_circle, color: Colors.green)
                : Icon(Icons.cancel, color: Colors.red),
              onTap: () {
                Navigator.pop(context);
                _reassignMonitor(station['id'], monitor['id']);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unassignMonitor(station['id']);
            },
            child: Text('Unassign'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.outline,
                  tabs: [
                    Tab(text: 'All Monitors', icon: Icon(Icons.people)),
                    Tab(text: 'Assigned Stations', icon: Icon(Icons.assignment_ind)),
                    Tab(text: 'Unassigned Stations', icon: Icon(Icons.location_off)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildAllMonitorsTab(theme),
                      _buildAssignedStationsTab(theme),
                      _buildUnassignedStationsTab(theme),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildAllMonitorsTab(ThemeData theme) {
    return ListView(
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
                Row(
                  children: [
                    Icon(Icons.people, color: theme.colorScheme.primary, size: 28),
                    SizedBox(width: 12),
                    Text('All Monitors', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
                    Spacer(),
                    Text('${_monitors.length} total', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                ..._monitors.map((m) {
                  final assignedStation = _pollingStations.firstWhere(
                    (s) => s['monitor'] == m['id'],
                    orElse: () => {'name': 'Unassigned'},
                  );
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: m['is_active'] ? theme.colorScheme.primary : theme.colorScheme.outline,
                        child: Text(
                          (m['fullname'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(m['fullname'] ?? '', style: theme.textTheme.bodyLarge),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Phone: ${m['phone']}'),
                          Text('Station: ${assignedStation['name']}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          m['is_active'] == true
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : Icon(Icons.cancel, color: Colors.red),
                          SizedBox(width: 8),
                          if (assignedStation['name'] != 'Unassigned')
                            Icon(Icons.assignment_ind, color: theme.colorScheme.primary)
                          else
                            Icon(Icons.location_off, color: theme.colorScheme.outline),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedStationsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.green.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_ind, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Text('Assigned Stations', style: theme.textTheme.titleLarge?.copyWith(color: Colors.green)),
                    Spacer(),
                    Text('${_assignedStations.length} assigned', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 16),
                ..._assignedStations.map((s) {
                  final monitor = _monitors.firstWhere(
                    (m) => m['id'] == s['monitor'],
                    orElse: () => {'fullname': 'Unknown Monitor'},
                  );
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.assignment_ind, color: Colors.white),
                      ),
                      title: Text(s['name'] ?? '', style: theme.textTheme.bodyLarge),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ward: ${s['ward']}'),
                          Text('Monitor: ${monitor['fullname']}'),
                          Text('Phone: ${monitor['phone']}'),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'reassign',
                            child: Row(
                              children: [
                                Icon(Icons.swap_horiz, color: theme.colorScheme.primary),
                                SizedBox(width: 8),
                                Text('Reassign'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'unassign',
                            child: Row(
                              children: [
                                Icon(Icons.remove_circle, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Unassign'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'reassign') {
                            _showReassignDialog(s);
                          } else if (value == 'unassign') {
                            _unassignMonitor(s['id']);
                          }
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnassignedStationsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.orange.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange, size: 28),
                    SizedBox(width: 12),
                    Text('Unassigned Stations', style: theme.textTheme.titleLarge?.copyWith(color: Colors.orange)),
                    Spacer(),
                    Text('${_unassignedStations.length} unassigned', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange)),
                  ],
                ),
                const SizedBox(height: 16),
                if (_unassignedStations.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 64),
                        SizedBox(height: 16),
                        Text('All stations are assigned!', style: theme.textTheme.titleMedium?.copyWith(color: Colors.green)),
                      ],
                    ),
                  )
                else
                  ..._unassignedStations.map((s) => Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.location_off, color: Colors.white),
                      ),
                      title: Text(s['name'] ?? '', style: theme.textTheme.bodyLarge),
                      subtitle: Text('Ward: ${s['ward']}'),
                      trailing: ElevatedButton.icon(
                        onPressed: () => _showAssignDialog(s),
                        icon: Icon(Icons.person_add, size: 16),
                        label: Text('Assign'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
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
