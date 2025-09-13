import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MonitorsPage extends StatefulWidget {
  const MonitorsPage({super.key});

  @override
  State<MonitorsPage> createState() => _MonitorsPageState();
}

class _MonitorsPageState extends State<MonitorsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> monitors = [];
  List<Map<String, dynamic>> pollingStations = [];
  List<Map<String, dynamic>> candidates = [];
  bool _loading = true;
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();

    // Set up real-time subscription for polling stations
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    supabase
        .channel('polling_station_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'polling_station',
      callback: (payload) {
        _loadData(); // Refresh data when changes occur
      },
    )
        .subscribe();

    // Also listen to user changes
    supabase
        .channel('users_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'users',
      callback: (payload) {
        _loadData(); // Refresh data when changes occur
      },
    )
        .subscribe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    supabase.removeAllChannels();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('Loading monitors data...'); // Debug log

      // Load candidates
      final candidatesResponse = await supabase
          .from('candidate')
          .select('*')
          .order('id', ascending: true);

      // Load monitors with their roles
      final monitorsResponse = await supabase
          .from('users')
          .select('*')
          .eq('role', 'monitor')
          .order('created_at', ascending: false);

      print('Monitors response: $monitorsResponse'); // Debug log

      // Load polling stations with monitor info
      final stationsResponse = await supabase
          .from('polling_station')
          .select('''
            *,
            users!fk_polling_station_monitor(id, fullname, phone)
          ''')
          .order('name', ascending: true);

      print('Stations response: $stationsResponse'); // Debug log

      setState(() {
        candidates = List<Map<String, dynamic>>.from(candidatesResponse);
        monitors = List<Map<String, dynamic>>.from(monitorsResponse);
        pollingStations = List<Map<String, dynamic>>.from(stationsResponse);
        _loading = false;
      });

      print('Loaded ${candidates.length} candidates, ${monitors.length} monitors and ${pollingStations.length} stations'); // Debug log
    } catch (e) {
      print('Error loading data: $e'); // Debug log
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      _showSnack('Error loading data: ${e.toString()}', true);
    }
  }

  void _showSnack(String message, [bool isError = false]) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _deleteMonitor(String monitorId, String monitorName) async {
    // First, check if this monitor is assigned to any polling station
    final assignedStations = pollingStations.where((station) =>
    station['monitor'] == monitorId).toList();

    bool clearData = false;

    if (assignedStations.isNotEmpty) {
      // Show dialog asking if user wants to clear data
      final result = await showDialog<Map<String, bool>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Monitor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete monitor "$monitorName"?'),
              const SizedBox(height: 16),
              if (assignedStations.isNotEmpty) ...[
                Text(
                  'This monitor is assigned to ${assignedStations.length} polling station(s):',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...assignedStations.map((station) => Text(
                  '• ${station['name']} (Ward: ${station['ward']})',
                  style: const TextStyle(fontSize: 13),
                )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'What should happen to the voting data?',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StatefulBuilder(
                        builder: (context, setDialogState) => Column(
                          children: [
                            RadioListTile<bool>(
                              title: const Text('Keep voting data (recommended)'),
                              subtitle: const Text('Data remains but monitor will be unassigned'),
                              value: false,
                              groupValue: clearData,
                              onChanged: (value) => setDialogState(() => clearData = value ?? false),
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<bool>(
                              title: Text(
                                'Clear all voting data',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                              subtitle: Text(
                                'Reset all votes to 0 (cannot be undone)',
                                style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                              ),
                              value: true,
                              groupValue: clearData,
                              onChanged: (value) => setDialogState(() => clearData = value ?? false),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop({'delete': true, 'clearData': clearData}),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Monitor'),
            ),
          ],
        ),
      );

      if (result == null) return; // User cancelled
      clearData = result['clearData'] ?? false;
    } else {
      // Simple confirmation for monitors with no assigned stations
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Monitor'),
          content: Text('Are you sure you want to delete monitor "$monitorName"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      // Start a transaction-like process
      if (clearData && assignedStations.isNotEmpty) {
        // Clear voting data from assigned stations
        for (final station in assignedStations) {
          await supabase
              .from('polling_station')
              .update({
            'candidate1': 0,
            'candidate2': 0,
            'candidate3': 0,
            'total': 0,
            'monitor': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
              .eq('name', station['name']);
        }
        _showSnack('Voting data cleared for ${assignedStations.length} station(s)');
      } else {
        // Just remove monitor from stations (keep voting data)
        await supabase
            .from('polling_station')
            .update({'monitor': null})
            .eq('monitor', monitorId);
      }

      // Delete the monitor user
      await supabase
          .from('users')
          .delete()
          .eq('id', monitorId);

      _showSnack('Monitor "$monitorName" deleted successfully');
      _loadData();
    } catch (e) {
      _showSnack('Error deleting monitor: ${e.toString()}', true);
    }
  }

  Future<void> _editMonitor(Map<String, dynamic> monitor) async {
    final nameController = TextEditingController(text: monitor['fullname']);
    final phoneController = TextEditingController(text: monitor['phone']);
    bool isActive = monitor['is_active'] ?? true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Monitor'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active Status'),
                subtitle: Text(isActive ? 'Monitor is active' : 'Monitor is inactive'),
                value: isActive,
                onChanged: (value) => setDialogState(() => isActive = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }
              Navigator.of(context).pop({
                'fullname': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'is_active': isActive,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await supabase
            .from('users')
            .update({
          'fullname': result['fullname'],
          'phone': result['phone'],
          'is_active': result['is_active'],
          'updated_at': DateTime.now().toIso8601String(),
        })
            .eq('id', monitor['id']);

        _showSnack('Monitor updated successfully');
        _loadData();
      } catch (e) {
        _showSnack('Error updating monitor: ${e.toString()}', true);
      }
    }
  }

  Future<void> _deleteMonitorData(String stationName, String monitorName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Station Data'),
        content: Text('Are you sure you want to clear all voting data for "$stationName" entered by monitor "$monitorName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase
            .from('polling_station')
            .update({
          'candidate1': 0,
          'candidate2': 0,
          'candidate3': 0,
          'total': 0,
          'updated_at': DateTime.now().toIso8601String(),
        })
            .eq('name', stationName);

        _showSnack('Station data cleared successfully');
        _loadData();
      } catch (e) {
        _showSnack('Error clearing data: ${e.toString()}', true);
      }
    }
  }

  Future<void> _assignMonitorToStation(String stationName) async {
    final availableMonitors = monitors.where((monitor) {
      // Check if this monitor is already assigned to any station and is active
      final isAssigned = pollingStations.any((station) =>
      station['monitor'] == monitor['id']);
      final isActive = monitor['is_active'] ?? true;
      return !isAssigned && isActive;
    }).toList();

    if (availableMonitors.isEmpty) {
      _showSnack('No available active monitors to assign', true);
      return;
    }

    final selectedMonitor = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Monitor to $stationName'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableMonitors.length,
            itemBuilder: (context, index) {
              final monitor = availableMonitors[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(monitor['fullname'][0].toString().toUpperCase()),
                ),
                title: Text(monitor['fullname']),
                subtitle: Text(monitor['phone']),
                onTap: () => Navigator.of(context).pop(monitor),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedMonitor != null) {
      try {
        await supabase
            .from('polling_station')
            .update({'monitor': selectedMonitor['id']})
            .eq('name', stationName);

        _showSnack('Monitor assigned successfully');
        _loadData();
      } catch (e) {
        _showSnack('Error assigning monitor: ${e.toString()}', true);
      }
    }
  }

  Widget _buildActiveMonitorsTab() {
    final activeMonitors = pollingStations.where((station) =>
    station['monitor'] != null).toList();

    if (activeMonitors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Active Monitors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'No monitors are currently assigned to stations',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activeMonitors.length,
        itemBuilder: (context, index) {
          final station = activeMonitors[index];
          final monitor = station['users'];
          final hasData = (station['candidate1'] ?? 0) > 0 ||
              (station['candidate2'] ?? 0) > 0 ||
              (station['candidate3'] ?? 0) > 0;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: hasData ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                child: Icon(
                  hasData ? Icons.check_circle : Icons.pending,
                  color: hasData ? Colors.green : Colors.orange,
                ),
              ),
              title: Text(
                station['name'],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(monitor['fullname'] ?? 'Unknown'),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(monitor['phone'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Ward: ${station['ward']}'),
                    ],
                  ),
                  if (hasData) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total Votes: ${station['total'] ?? 0}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: const Row(
                      children: [
                        Icon(Icons.visibility, size: 20),
                        SizedBox(width: 8),
                        Text('View Details'),
                      ],
                    ),
                  ),
                  if (hasData)
                    PopupMenuItem(
                      value: 'clear_data',
                      child: const Row(
                        children: [
                          Icon(Icons.clear, size: 20, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Clear Data'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'remove_monitor',
                    child: const Row(
                      children: [
                        Icon(Icons.person_remove, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remove Monitor'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      _showStationDetails(station);
                      break;
                    case 'clear_data':
                      _deleteMonitorData(station['name'], monitor['fullname']);
                      break;
                    case 'remove_monitor':
                      _removeMonitorFromStation(station['name']);
                      break;
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnassignedStationsTab() {
    final unassignedStations = pollingStations.where((station) =>
    station['monitor'] == null).toList();

    if (unassignedStations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'All Stations Assigned',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'All polling stations have monitors assigned',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: unassignedStations.length,
        itemBuilder: (context, index) {
          final station = unassignedStations[index];

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: Colors.red.withOpacity(0.2),
                child: const Icon(
                  Icons.warning,
                  color: Colors.red,
                ),
              ),
              title: Text(
                station['name'],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Ward: ${station['ward']}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No Monitor Assigned',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: ElevatedButton.icon(
                onPressed: () => _assignMonitorToStation(station['name']),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Assign'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAllMonitorsTab() {
    final filteredMonitors = monitors.where((monitor) {
      final name = monitor['fullname'].toString().toLowerCase();
      final phone = monitor['phone'].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          phone.contains(_searchQuery.toLowerCase());
    }).toList();

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (monitors.isEmpty && !_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Monitors Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'No monitors have been registered in the system yet',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search monitors by name or phone...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.withOpacity(0.1),
            ),
          ),
        ),

        // Monitors List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredMonitors.length,
              itemBuilder: (context, index) {
                final monitor = filteredMonitors[index];
                final assignedStation = pollingStations.firstWhere(
                      (station) => station['monitor'] == monitor['id'],
                  orElse: () => {},
                );
                final isAssigned = assignedStation.isNotEmpty;
                final isActive = monitor['is_active'] ?? true;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? (isAssigned ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2))
                          : Colors.red.withOpacity(0.2),
                      child: Text(
                        monitor['fullname'][0].toString().toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? (isAssigned ? Colors.green : Colors.grey.shade600)
                              : Colors.red,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            monitor['fullname'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isActive ? null : Colors.grey,
                            ),
                          ),
                        ),
                        if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'INACTIVE',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(monitor['phone']),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAssigned ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAssigned ? 'Assigned: ${assignedStation['name']}' : 'Not Assigned',
                            style: TextStyle(
                              color: isAssigned ? Colors.green.shade700 : Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: const Row(
                            children: [
                              Icon(Icons.visibility, size: 20),
                              SizedBox(width: 8),
                              Text('View Profile'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: const Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit Monitor'),
                            ],
                          ),
                        ),
                        if (isAssigned)
                          PopupMenuItem(
                            value: 'unassign',
                            child: const Row(
                              children: [
                                Icon(Icons.person_remove, size: 20, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Unassign'),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: const Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Monitor'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'view':
                            _showMonitorProfile(monitor);
                            break;
                          case 'edit':
                            _editMonitor(monitor);
                            break;
                          case 'unassign':
                            _removeMonitorFromStation(assignedStation['name']);
                            break;
                          case 'delete':
                            _deleteMonitor(monitor['id'], monitor['fullname']);
                            break;
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showStationDetails(Map<String, dynamic> station) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(station['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Ward', station['ward']),
            _buildDetailRow('Monitor', station['users']['fullname']),
            _buildDetailRow('Monitor Phone', station['users']['phone']),
            const SizedBox(height: 16),
            const Text('Vote Counts:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Display actual candidate names
            if (candidates.isNotEmpty) ...[
              _buildDetailRow(
                  candidates[0]['fullname'] ?? 'Candidate 1',
                  '${station['candidate1'] ?? 0}'
              ),
            ],
            if (candidates.length > 1) ...[
              _buildDetailRow(
                  candidates[1]['fullname'] ?? 'Candidate 2',
                  '${station['candidate2'] ?? 0}'
              ),
            ],
            if (candidates.length > 2) ...[
              _buildDetailRow(
                  candidates[2]['fullname'] ?? 'Candidate 3',
                  '${station['candidate3'] ?? 0}'
              ),
            ],
            // Fallback to generic names if no candidates loaded
            if (candidates.isEmpty) ...[
              _buildDetailRow('Candidate 1', '${station['candidate1'] ?? 0}'),
              _buildDetailRow('Candidate 2', '${station['candidate2'] ?? 0}'),
              _buildDetailRow('Candidate 3', '${station['candidate3'] ?? 0}'),
            ],
            _buildDetailRow('Total Votes', '${station['total'] ?? 0}'),
            const SizedBox(height: 8),
            _buildDetailRow('Last Updated', _formatDateTime(station['updated_at'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMonitorProfile(Map<String, dynamic> monitor) {
    final assignedStation = pollingStations.firstWhere(
          (station) => station['monitor'] == monitor['id'],
      orElse: () => {},
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(monitor['fullname']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Phone', monitor['phone']),
            _buildDetailRow('Role', monitor['role']),
            _buildDetailRow('Status', monitor['is_active'] ? 'Active' : 'Inactive'),
            _buildDetailRow('Created', _formatDateTime(monitor['created_at'])),
            _buildDetailRow('Last Updated', _formatDateTime(monitor['updated_at'])),
            if (assignedStation.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Assignment:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _buildDetailRow('Station', assignedStation['name']),
              _buildDetailRow('Ward', assignedStation['ward']),
            ] else
              _buildDetailRow('Assignment', 'Not assigned to any station'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMonitorFromStation(String stationName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Monitor'),
        content: Text('Are you sure you want to remove the monitor from "$stationName"? The voting data will be preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase
            .from('polling_station')
            .update({'monitor': null})
            .eq('name', stationName);

        _showSnack('Monitor removed from station');
        _loadData();
      } catch (e) {
        _showSnack('Error removing monitor: ${e.toString()}', true);
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.people),
              text: 'Active (${pollingStations.where((s) => s['monitor'] != null).length})',
            ),
            Tab(
              icon: const Icon(Icons.warning),
              text: 'Unassigned (${pollingStations.where((s) => s['monitor'] == null).length})',
            ),
            Tab(
              icon: const Icon(Icons.group),
              text: 'All Monitors (${monitors.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveMonitorsTab(),
          _buildUnassignedStationsTab(),
          _buildAllMonitorsTab(),
        ],
      ),
    );
  }
}