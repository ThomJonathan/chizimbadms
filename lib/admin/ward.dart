import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// Main function to call from your AdminHomePage
Widget buildWardsPage() {
  return const _WardPageWidget();
}

class _WardPageWidget extends StatefulWidget {
  const _WardPageWidget();

  @override
  State<_WardPageWidget> createState() => _WardPageWidgetState();
}

class _WardPageWidgetState extends State<_WardPageWidget> {
  List<Map<String, dynamic>> wardPollingStations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWardData();
  }

  Future<void> _loadWardData() async {
    setState(() => _loading = true);

    try {
      // Load wards with their polling stations and monitor details
      final wardsResponse = await supabase
          .from('ward')
          .select('name, constituency')
          .order('name', ascending: true);

      List<Map<String, dynamic>> wardPollingStationsData = [];

      for (var ward in wardsResponse) {
        final wardName = ward['name'] as String;

        // Load polling stations for this ward with monitor information
        final pollingStationsResponse = await supabase
            .from('polling_station')
            .select('''
              name, 
              monitor, 
              candidate1, 
              candidate2, 
              candidate3, 
              total,
              users!fk_polling_station_monitor(
                fullname
              )
            ''')
            .eq('ward', wardName)
            .order('name', ascending: true);

        // Process polling stations to include monitor names
        List<Map<String, dynamic>> processedStations = [];
        for (var station in pollingStationsResponse) {
          Map<String, dynamic> processedStation = {
            'name': station['name'],
            'monitor': station['monitor'],
            'candidate1': station['candidate1'],
            'candidate2': station['candidate2'],
            'candidate3': station['candidate3'],
            'total': station['total'],
          };

          // Add monitor name if available
          if (station['users'] != null) {
            processedStation['monitor_name'] = station['users']['fullname'];
          }

          processedStations.add(processedStation);
        }

        wardPollingStationsData.add({
          'name': wardName,
          'constituency': ward['constituency'],
          'polling_stations': processedStations,
        });
      }

      setState(() {
        wardPollingStations = wardPollingStationsData;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Error loading ward data: ${e.toString()}', true);
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

  Widget _buildWardsSummaryStats() {
    final theme = Theme.of(context);

    // Calculate summary statistics
    int totalWards = wardPollingStations.length;
    int totalPollingStations = 0;
    int recordedPollingStations = 0;

    for (var wardData in wardPollingStations) {
      final stations = wardData['polling_stations'] as List<Map<String, dynamic>>;
      totalPollingStations += stations.length;
      recordedPollingStations += stations.where((station) =>
      (station['total'] as int? ?? 0) > 0).length;
    }

    int pendingPollingStations = totalPollingStations - recordedPollingStations;
    double completionPercentage = totalPollingStations > 0
        ? (recordedPollingStations / totalPollingStations) * 100
        : 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary Overview',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryStatCard(
                    'Total Wards',
                    '$totalWards',
                    Icons.location_city,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryStatCard(
                    'Total Stations',
                    '$totalPollingStations',
                    Icons.how_to_vote,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryStatCard(
                    'Recorded',
                    '$recordedPollingStations',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryStatCard(
                    'Pending',
                    '$pendingPollingStations',
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Completion',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: completionPercentage / 100,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completionPercentage >= 80
                              ? Colors.green
                              : completionPercentage >= 50
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${completionPercentage.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWardPollingStationCard(Map<String, dynamic> wardData) {
    final theme = Theme.of(context);
    final wardName = wardData['name'] as String;
    final constituency = wardData['constituency'] as String? ?? 'Unknown';
    final pollingStations = wardData['polling_stations'] as List<Map<String, dynamic>>;

    // Calculate ward statistics
    final totalStations = pollingStations.length;
    final recordedStations = pollingStations.where((station) =>
    (station['total'] as int? ?? 0) > 0).length;
    final pendingStations = totalStations - recordedStations;
    final completionRate = totalStations > 0 ? (recordedStations / totalStations) * 100 : 0.0;

    // Calculate total votes in this ward
    int wardTotalVotes = 0;
    for (var station in pollingStations) {
      wardTotalVotes += (station['total'] as int? ?? 0);
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.location_on,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wardName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                constituency,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildStatusChip('$totalStations Total', Colors.blue),
                _buildStatusChip('$recordedStations Done', Colors.green),
                _buildStatusChip('$pendingStations Pending', Colors.orange),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${completionRate.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: completionRate >= 80
                      ? Colors.green
                      : completionRate >= 50
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
              Text(
                '$wardTotalVotes votes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Completion Progress Bar
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completion Progress',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: completionRate / 100,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              completionRate >= 80
                                  ? Colors.green
                                  : completionRate >= 50
                                  ? Colors.orange
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Polling Stations List
                Text(
                  'Polling Stations',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                ...pollingStations.map((station) => _buildPollingStationRow(station)).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPollingStationRow(Map<String, dynamic> station) {
    final theme = Theme.of(context);
    final stationName = station['name'] as String;
    final totalVotes = station['total'] as int? ?? 0;
    final monitorId = station['monitor'] as String?;
    final monitorName = station['monitor_name'] as String? ??
        (monitorId != null ? 'Monitor Assigned' : 'No Monitor');
    final isRecorded = totalVotes > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRecorded
            ? Colors.green.withOpacity(0.05)
            : Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRecorded
              ? Colors.green.withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status Icon
          Icon(
            isRecorded ? Icons.check_circle : Icons.pending,
            color: isRecorded ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),

          // Station Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stationName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      monitorId != null ? Icons.person : Icons.person_outline,
                      size: 14,
                      color: monitorId != null ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        monitorName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: monitorId != null
                              ? Colors.blue
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vote Count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$totalVotes',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isRecorded ? Colors.green : Colors.orange,
                ),
              ),
              Text(
                'votes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.secondary,
                      Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_city,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ward Monitoring Dashboard',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time polling station tracking',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Summary Stats
            _buildWardsSummaryStats(),

            const SizedBox(height: 24),

            // Ward Details Section
            Text(
              'Ward Details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Ward Cards with Polling Station Details
            if (wardPollingStations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No wards found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...wardPollingStations.map((wardData) => _buildWardPollingStationCard(wardData)).toList(),
          ],
        ),
      ),
    );
  }
}