import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DataEntryPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const DataEntryPage({super.key, required this.user});

  @override
  State<DataEntryPage> createState() => _DataEntryPageState();
}

class _DataEntryPageState extends State<DataEntryPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _totalVotesControllers = {};

  List<Map<String, dynamic>> _candidates = [];
  List<Map<String, dynamic>> _pollingStations = [];
  String? _selectedPollingStationName; // Changed to String instead of Map
  Map<String, dynamic>? _selectedPollingStation; // Keep this for the actual data
  bool _loading = false;
  bool _hasRecordedResults = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _loadData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _totalVotesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Add these variables to your state
  bool _candidatesLoaded = false;
  bool _stationsLoaded = false;

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      await _loadCandidates();
      await _loadPollingStations();
    } catch (e) {
      _showSnack('Error loading data: $e', true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadCandidates() async {
    final response = await supabase
        .from('candidate')
        .select('*')
        .order('id');

    setState(() {
      _candidates = List<Map<String, dynamic>>.from(response);
      _candidatesLoaded = true;

      // Initialize controllers
      for (var candidate in _candidates) {
        _totalVotesControllers[candidate['id'].toString()] =
            TextEditingController(text: '0');
      }
    });
  }

  Future<void> _loadPollingStations() async {
    final response = await supabase
        .from('polling_station')
        .select('*')
        .order('ward, name');

    setState(() {
      _pollingStations = List<Map<String, dynamic>>.from(response);
      _stationsLoaded = true;

      // Remove duplicates based on 'name' field to prevent dropdown errors
      final Map<String, Map<String, dynamic>> uniqueStations = {};
      for (var station in _pollingStations) {
        uniqueStations[station['name']] = station;
      }
      _pollingStations = uniqueStations.values.toList();

      // Sort by ward and name again after deduplication
      _pollingStations.sort((a, b) {
        int wardCompare = (a['ward'] ?? '').compareTo(b['ward'] ?? '');
        if (wardCompare != 0) return wardCompare;
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      });
    });
  }

  void _onPollingStationChanged(String? stationName) {
    if (stationName == null) {
      setState(() {
        _selectedPollingStationName = null;
        _selectedPollingStation = null;
        _hasRecordedResults = false;
      });
      return;
    }

    // Find the station data by name
    final station = _pollingStations.firstWhere(
          (s) => s['name'] == stationName,
      orElse: () => <String, dynamic>{},
    );

    if (station.isEmpty) {
      _showSnack('Selected polling station not found', true);
      return;
    }

    setState(() {
      _selectedPollingStationName = stationName;
      _selectedPollingStation = station;

      // Check if results have been recorded
      _hasRecordedResults = (station['candidate1'] ?? 0) > 0 ||
          (station['candidate2'] ?? 0) > 0 ||
          (station['candidate3'] ?? 0) > 0;

      if (_hasRecordedResults) {
        // Populate the form with existing data
        for (int i = 0; i < _candidates.length; i++) {
          final candidateKey = 'candidate${i + 1}';
          final candidateId = _candidates[i]['id'].toString();
          _totalVotesControllers[candidateId]?.text =
              station[candidateKey]?.toString() ?? '0';
        }
      } else {
        // Reset form for new entry
        for (var controller in _totalVotesControllers.values) {
          controller.text = '0';
        }
      }
    });
  }

  Future<void> _saveResults() async {
    if (_selectedPollingStation == null) {
      _showSnack('Please select a polling station first', true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Validate total votes limit
    final totalValidationError = _validateTotalVotesLimit();
    if (totalValidationError != null) {
      _showSnack(totalValidationError, true);
      return;
    }

    // Show confirmation dialog
    final bool? confirmed = await _showConfirmationDialog();
    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      // Calculate total from all candidates
      int grandTotal = 0;
      final Map<String, dynamic> resultsData = {};

      print('Saving results for polling station: ${_selectedPollingStation!['name']}');

      for (int i = 0; i < _candidates.length; i++) {
        final candidateKey = 'candidate${i + 1}';
        final candidateId = _candidates[i]['id'].toString();
        final totalVotes = int.tryParse(_totalVotesControllers[candidateId]?.text ?? '0') ?? 0;

        resultsData[candidateKey] = totalVotes;
        grandTotal += totalVotes;

        print('Candidate ${i+1} (${_candidates[i]['fullname']}): $totalVotes votes');
      }

      resultsData['total'] = grandTotal;
      resultsData['updated_at'] = DateTime.now().toIso8601String();
      resultsData['RecordedBy'] = 'admin'; // Set that admin recorded the results

      print('Total votes: $grandTotal');
      print('Recorded by: admin');

      // Update polling station with results
      final response = await supabase
          .from('polling_station')
          .update(resultsData)
          .eq('name', _selectedPollingStation!['name']);

      print('Update response: $response');

      _showSnack('Election results saved successfully!', false);

      // Refresh the selected polling station data
      await _refreshSelectedStation();

    } catch (e) {
      print('Error saving results: $e');
      _showSnack('Error saving results: ${e.toString()}', true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshSelectedStation() async {
    if (_selectedPollingStationName != null) {
      try {
        final response = await supabase
            .from('polling_station')
            .select('*')
            .eq('name', _selectedPollingStationName!)
            .single();

        // Update the selected station and refresh UI
        setState(() {
          _selectedPollingStation = response;

          // Update the polling stations list as well
          final index = _pollingStations.indexWhere((s) => s['name'] == _selectedPollingStationName);
          if (index != -1) {
            _pollingStations[index] = response;
          }
        });

        // Re-trigger the change to update the form
        _onPollingStationChanged(_selectedPollingStationName);

      } catch (e) {
        print('Error refreshing station data: $e');
        // Reload all polling stations if single station refresh fails
        await _loadPollingStations();
      }
    }
  }

  Future<bool?> _showConfirmationDialog() async {
    int totalAllCandidates = 0;
    for (int i = 0; i < _candidates.length; i++) {
      final candidateId = _candidates[i]['id'].toString();
      totalAllCandidates += int.tryParse(_totalVotesControllers[candidateId]?.text ?? '0') ?? 0;
    }

    // Check if total exceeds 1000
    if (totalAllCandidates > 1000) {
      _showSnack('Total votes cannot exceed 1000. Current total: $totalAllCandidates', true);
      return false;
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Confirm Results'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Polling Station: ${_selectedPollingStation!['name']}'),
              Text('Ward: ${_selectedPollingStation!['ward']}'),
              SizedBox(height: 16),
              Text('Please verify the total votes for each candidate:'),
              SizedBox(height: 16),
              for (int i = 0; i < _candidates.length; i++)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _candidates[i]['fullname'],
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_totalVotesControllers[_candidates[i]['id'].toString()]?.text ?? '0'} votes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 12),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL VOTES:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$totalAllCandidates',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _hasRecordedResults ? Colors.orange.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _hasRecordedResults ? Colors.orange.shade200 : Colors.red.shade200
                  ),
                ),
                child: Text(
                  _hasRecordedResults
                      ? '⚠️ Warning: This will update existing results. Previous data will be overwritten.'
                      : '⚠️ Warning: Once saved, these results will be recorded. Please ensure all numbers are accurate.',
                  style: TextStyle(
                    color: _hasRecordedResults ? Colors.orange.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(_hasRecordedResults ? 'Update Results' : 'Save Results'),
            ),
          ],
        );
      },
    );
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
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  String? _validateTotalVotes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter total votes';
    }
    final int? votes = int.tryParse(value.trim());
    if (votes == null || votes < 0) {
      return 'Please enter a valid number (0 or greater)';
    }
    return null;
  }

  // Method to calculate total votes from all candidates
  int _calculateTotalVotes() {
    int total = 0;
    for (var candidate in _candidates) {
      final candidateId = candidate['id'].toString();
      final votes = int.tryParse(_totalVotesControllers[candidateId]?.text ?? '0') ?? 0;
      total += votes;
    }
    return total;
  }

  // Method to validate if total votes exceed 1000
  String? _validateTotalVotesLimit() {
    final total = _calculateTotalVotes();
    if (total > 1000) {
      return 'Total votes cannot exceed 1000. Current total: $total';
    }
    return null;
  }

  Widget _buildPollingStationSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 8),
                Text(
                  'Select Polling Station',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                hintText: 'Choose a polling station',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              value: _selectedPollingStationName,
              items: _pollingStations.map((station) {
                final stationName = station['name'] as String;
                final hasData = (station['total'] ?? 0) > 0;
                final recordedBy = station['RecordedBy'] ?? '';

                return DropdownMenuItem<String>(
                  value: stationName,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stationName,
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (hasData) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: recordedBy == 'admin'
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                recordedBy == 'admin' ? 'Admin' : 'Monitor',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: recordedBy == 'admin'
                                      ? Colors.blue
                                      : Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Ward: ${station['ward']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      if (hasData)
                        Text(
                          'Total votes: ${station['total']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _onPollingStationChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsEntryForm() {
    if (_selectedPollingStation == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Select Polling Station',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Please select a polling station above to enter or modify election results.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.ballot, color: Theme.of(context).colorScheme.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasRecordedResults ? 'Update Election Results' : 'Record Election Results',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Station: ${_selectedPollingStation!['name']}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        if (_hasRecordedResults) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Previously recorded by: ${_selectedPollingStation!['RecordedBy'] ?? 'unknown'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Total votes inputs for each candidate
              for (int i = 0; i < _candidates.length; i++) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _candidates[i]['fullname'] ?? 'Unknown Candidate',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _candidates[i]['party'] ?? 'Unknown Party',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      TextFormField(
                        controller: _totalVotesControllers[_candidates[i]['id'].toString()],
                        keyboardType: TextInputType.number,
                        validator: _validateTotalVotes,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Total Votes',
                          hintText: 'Enter total votes for this candidate',
                          prefixIcon: Icon(Icons.how_to_reg),
                          suffixText: 'votes',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Total votes display and validation
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _validateTotalVotesLimit() != null
                        ? Colors.red.withOpacity(0.5)
                        : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL VOTES:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _validateTotalVotesLimit() != null
                                ? Colors.red
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_calculateTotalVotes()}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_validateTotalVotesLimit() != null) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validateTotalVotesLimit()!,
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 8),
                    Text(
                      'Maximum allowed: 1000 votes',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Save button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (_loading || _validateTotalVotesLimit() != null) ? null : _saveResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(_hasRecordedResults ? 'Updating Results...' : 'Saving Results...'),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_hasRecordedResults ? Icons.update : Icons.save, size: 24),
                      SizedBox(width: 8),
                      Text(
                        _hasRecordedResults ? 'Update Election Results' : 'Save Election Results',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Data Entry'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading && _candidates.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Data Entry',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Enter or update election results for any polling station',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Polling station selector
                _buildPollingStationSelector(),

                SizedBox(height: 20),

                // Results entry form
                _buildResultsEntryForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }
} // This closing brace was missing