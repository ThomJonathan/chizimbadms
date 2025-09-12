import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dotted_border/dotted_border.dart';
import '../auth/login_page.dart';
import '../auth/sessionManager.dart'; // Import SessionManager

final supabase = Supabase.instance.client;

class MonitorHomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const MonitorHomePage({super.key, required this.user});

  @override
  State<MonitorHomePage> createState() => _MonitorHomePageState();
}

class _MonitorHomePageState extends State<MonitorHomePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _totalVotesControllers = {};

  List<Map<String, dynamic>> _candidates = [];
  Map<String, dynamic>? _pollingStation;
  bool _loading = false;
  bool _hasRecordedResults = false;
  bool _loggingOut = false; // Add loading state for logout

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

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      // Load candidates
      final candidatesResponse = await supabase
          .from('candidate')
          .select('*')
          .order('id'); // Make sure this sorts consistently

      _candidates = List<Map<String, dynamic>>.from(candidatesResponse);

      // Initialize controllers for each candidate
      for (var candidate in _candidates) {
        _totalVotesControllers[candidate['id'].toString()] = TextEditingController(text: '0');
      }

      // Load polling station assigned to this monitor
      final pollingResponse = await supabase
          .from('polling_station')
          .select('*')
          .eq('monitor', widget.user['id'])
          .maybeSingle();

      if (pollingResponse != null) {
        _pollingStation = pollingResponse;

        // Check if results have been recorded (any candidate has votes > 0)
        _hasRecordedResults = (_pollingStation!['candidate1'] ?? 0) > 0 ||
            (_pollingStation!['candidate2'] ?? 0) > 0 ||
            (_pollingStation!['candidate3'] ?? 0) > 0;

        if (_hasRecordedResults) {
          // Populate the form with existing data
          for (int i = 0; i < _candidates.length; i++) {
            final candidateKey = 'candidate${i + 1}';
            final candidateId = _candidates[i]['id'].toString();
            _totalVotesControllers[candidateId]?.text =
                _pollingStation![candidateKey]?.toString() ?? '0';
          }
        }
      }

    } catch (e) {
      _showSnack('Error loading data: ${e.toString()}', true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveResults() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog
    final bool? confirmed = await _showConfirmationDialog();
    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      // Calculate total from all candidates
      int grandTotal = 0;
      final Map<String, dynamic> resultsData = {};

      // Debug output
      print('Saving results for polling station: ${_pollingStation!['name']}');

      for (int i = 0; i < _candidates.length; i++) {
        final candidateKey = 'candidate${i + 1}';
        final candidateId = _candidates[i]['id'].toString();
        final totalVotes = int.tryParse(_totalVotesControllers[candidateId]?.text ?? '0') ?? 0;

        resultsData[candidateKey] = totalVotes;
        grandTotal += totalVotes;

        // Debug output
        print('Candidate ${i+1} (${_candidates[i]['fullname']}): $totalVotes votes');
      }

      resultsData['total'] = grandTotal;
      resultsData['updated_at'] = DateTime.now().toIso8601String();

      print('Total votes: $grandTotal');

      // Update polling station with results
      final response = await supabase
          .from('polling_station')
          .update(resultsData)
          .eq('monitor', widget.user['id']);

      print('Update response: $response');

      _showSnack('Election results saved successfully!', false);
      _loadData(); // Reload data to show saved results

    } catch (e) {
      print('Error saving results: $e');
      _showSnack('Error saving results: ${e.toString()}', true);
    } finally {
      setState(() => _loading = false);
    }
  }
  // Updated logout method to use SessionManager
  Future<void> _handleLogout() async {
    setState(() => _loggingOut = true);

    try {
      final sessionManager = SessionManager.instance;
      await sessionManager.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error logging out: ${e.toString()}', true);
      }
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  // Updated logout confirmation dialog
  Future<void> _showLogoutDialog() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Confirm Logout'),
            ],
          ),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _handleLogout();
    }
  }

  Future<bool?> _showConfirmationDialog() async {
    int totalAllCandidates = 0;
    for (int i = 0; i < _candidates.length; i++) {
      final candidateId = _candidates[i]['id'].toString();
      totalAllCandidates += int.tryParse(_totalVotesControllers[candidateId]?.text ?? '0') ?? 0;
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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  '⚠️ Warning: Once saved, these results cannot be modified. Please ensure all numbers are accurate.',
                  style: TextStyle(
                    color: Colors.red.shade700,
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
              child: Text('Save Results'),
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

  Widget _buildResultsEntryForm() {
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
                          'Record Election Results',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Enter the total votes each candidate received',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
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

              // Save button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveResults,
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
                      Text('Saving Results...'),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, size: 24),
                      SizedBox(width: 8),
                      Text(
                          'Save Election Results',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
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

  Widget _buildSavedResultsView() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Results Recorded',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Election results have been saved successfully',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '✅ The election results have been recorded and locked. No further changes are allowed.',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            SizedBox(height: 24),

            Text(
              'Final Results Summary:',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Display results for each candidate
            for (int i = 0; i < _candidates.length; i++) ...[
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
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
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_pollingStation!['candidate${i + 1}'] ?? 0}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 16),

            // Total votes
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL VOTES CAST:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      '${_pollingStation!['total'] ?? 0}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Election Monitor Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _loggingOut
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _loggingOut ? null : _showLogoutDialog,
          ),
        ],
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
                // Welcome header
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Icon(Icons.person, color: Colors.white, size: 32),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monitor: ${widget.user['fullname'] ?? 'Unknown User'}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _pollingStation != null
                                    ? 'Assigned to: ${_pollingStation!['name'] ?? 'Unknown Station'}'
                                    : 'No polling station assigned',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              if (_pollingStation != null) ...[
                                SizedBox(height: 4),
                                Text(
                                  'Ward: ${_pollingStation!['ward'] ?? 'Unknown Ward'}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Main content
                if (_pollingStation == null)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.info_outline, size: 64, color: Colors.orange),
                          SizedBox(height: 16),
                          Text(
                            'No Polling Station Assigned',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please contact the administrator to assign you to a polling station before you can record election results.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_hasRecordedResults)
                  _buildSavedResultsView()
                else
                  _buildResultsEntryForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}