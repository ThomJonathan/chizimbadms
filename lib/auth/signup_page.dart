import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullname = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _stationSearchController = TextEditingController();
  String? _selectedConstituency;
  String? _selectedWard;
  String? _selectedStation;
  bool _loading = false;
  bool _showStationDropdown = false;
  List<Map<String, dynamic>> _constituencies = [];
  List<Map<String, dynamic>> _wards = [];
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _filteredStations = [];

  @override
  void initState() {
    super.initState();
    _loadConstituencies();
    _stationSearchController.addListener(_filterStations);
  }

  @override
  void dispose() {
    _fullname.dispose();
    _phone.dispose();
    _password.dispose();
    _stationSearchController.dispose();
    super.dispose();
  }

  void _filterStations() {
    final query = _stationSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStations = _stations;
        _showStationDropdown = false;
      } else {
        _filteredStations = _stations
            .where((station) =>
            station['name'].toString().toLowerCase().contains(query))
            .toList();
        _showStationDropdown = _filteredStations.isNotEmpty;
      }
    });
  }

  void _selectStation(Map<String, dynamic> station) {
    if (station['monitor'] != null) {
      _snack('This station is already assigned to another monitor', true);
      return;
    }

    setState(() {
      _selectedStation = station['name'];
      _stationSearchController.text = station['name'];
      _showStationDropdown = false;
    });
  }

  Future<void> _loadConstituencies() async {
    try {
      final res = await supabase
          .from('constituency')
          .select('name, district')
          .order('name');
      setState(() => _constituencies = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      _snack('Error loading constituencies: $e', true);
    }
  }

  Future<void> _loadWards(String constituency) async {
    try {
      final res = await supabase
          .from('ward')
          .select('name')
          .eq('constituency', constituency)
          .order('name');
      setState(() {
        _wards = List<Map<String, dynamic>>.from(res);
        _selectedWard = null;
        _stations = [];
        _filteredStations = [];
        _selectedStation = null;
        _stationSearchController.clear();
        _showStationDropdown = false;
      });
    } catch (e) {
      _snack('Error loading wards: $e', true);
    }
  }

  Future<void> _loadStations(String ward) async {
    try {
      final res = await supabase
          .from('polling_station')
          .select('name, monitor')
          .eq('ward', ward)
          .order('name');
      setState(() {
        _stations = List<Map<String, dynamic>>.from(res);
        _filteredStations = _stations;
        _selectedStation = null;
        _stationSearchController.clear();
        _showStationDropdown = false;
      });
    } catch (e) {
      _snack('Error loading stations: $e', true);
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStation == null) {
      _snack('Please select a polling station', true);
      return;
    }

    setState(() => _loading = true);

    try {
      // 1️⃣ Check if phone number already exists
      final existingUser = await supabase
          .from('users')
          .select('id')
          .eq('phone', _phone.text.trim())
          .maybeSingle();

      if (existingUser != null) {
        _snack('Phone number already registered', true);
        return;
      }

      // 2️⃣ Check if station is still available
      final stationCheck = await supabase
          .from('polling_station')
          .select('monitor')
          .eq('name', _selectedStation!)
          .single();

      if (stationCheck['monitor'] != null) {
        _snack('Station already assigned to another monitor. Please select a different station.', true);
        return;
      }

      // 3️⃣ Insert user directly into the database (plain text password)
      final userResult = await supabase.from('users').insert({
        'fullname': _fullname.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text.trim(), // Store password as plain text
        'role': 'monitor',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      final userId = userResult['id'];

      // 4️⃣ Assign monitor to polling station
      final updatedRows = await supabase
          .from('polling_station')
          .update({'monitor': userId})
          .eq('name', _selectedStation!)
          .filter('monitor', 'is', null)
          .select('name');

      if (updatedRows.isEmpty) {
        // 5️⃣ Rollback user if station assignment failed
        await supabase.from('users').delete().eq('id', userId);
        _snack('Station already assigned to another monitor. Please select a different station.', true);
        return;
      }

      _snack('Signup successful! You can now log in.');
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      print('Signup error details: $e'); // For debugging
      _snack('Signup error: ${e.toString()}', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, [bool error = false]) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                error ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: error ? 4 : 2),
        ),
      );
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter phone number';
    }
    // Remove any non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    // Optional: Add specific format validation for your region
    if (!RegExp(r'^[0-9+\-\s()]*$').hasMatch(value)) {
      return 'Invalid phone number format';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateStation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Select a polling station';
    }
    // Check if the entered station name exists in the stations list
    final stationExists = _stations.any((station) =>
    station['name'].toString().toLowerCase() == value.toLowerCase());
    if (!stationExists) {
      return 'Please select a valid station from the list';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor Signup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Register as Monitor',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _fullname,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: 'e.g., 0888099900',
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 24),

              const Text(
                'Select Your Monitoring Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedConstituency,
                decoration: const InputDecoration(
                  labelText: 'Constituency',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: _constituencies
                    .map((c) => DropdownMenuItem<String>(
                  value: c['name'],
                  child: Text('${c['name']} (${c['district']})'),
                ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedConstituency = v;
                    _selectedWard = null;
                    _selectedStation = null;
                    _wards = [];
                    _stations = [];
                    _filteredStations = [];
                    _stationSearchController.clear();
                    _showStationDropdown = false;
                  });
                  if (v != null) _loadWards(v);
                },
                validator: (v) => v == null ? 'Select a constituency' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedWard,
                decoration: const InputDecoration(
                  labelText: 'Ward',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: _wards
                    .map((w) => DropdownMenuItem<String>(
                  value: w['name'],
                  child: Text(w['name']),
                ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedWard = v;
                    _selectedStation = null;
                    _stations = [];
                    _filteredStations = [];
                    _stationSearchController.clear();
                    _showStationDropdown = false;
                  });
                  if (v != null) _loadStations(v);
                },
                validator: (v) => v == null ? 'Select a ward' : null,
              ),
              const SizedBox(height: 16),

              // Searchable Polling Station Field
              Column(
                children: [
                  TextFormField(
                    controller: _stationSearchController,
                    decoration: InputDecoration(
                      labelText: 'Polling Station',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.how_to_vote),
                      suffixIcon: _stationSearchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _stationSearchController.clear();
                            _selectedStation = null;
                            _showStationDropdown = false;
                            _filteredStations = _stations;
                          });
                        },
                      )
                          : const Icon(Icons.search),
                      hintText: _stations.isEmpty
                          ? 'Select ward first'
                          : 'Search for a polling station...',
                    ),
                    readOnly: _stations.isEmpty,
                    validator: _validateStation,
                    onTap: () {
                      if (_stations.isEmpty) {
                        _snack('Please select a ward first', true);
                        return;
                      }
                      setState(() {
                        if (_stationSearchController.text.isEmpty) {
                          _filteredStations = _stations;
                        }
                        _showStationDropdown = _filteredStations.isNotEmpty;
                      });
                    },
                    onChanged: (value) {
                      if (_stations.isEmpty) return;

                      // Reset selected station if user is typing a new value
                      if (_selectedStation != null && value != _selectedStation) {
                        setState(() {
                          _selectedStation = null;
                        });
                      }
                    },
                  ),

                  // Dropdown list for search results
                  if (_showStationDropdown && _filteredStations.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredStations.length,
                        itemBuilder: (context, index) {
                          final station = _filteredStations[index];
                          final isAssigned = station['monitor'] != null;

                          return ListTile(
                            title: Text(
                              station['name'],
                              style: TextStyle(
                                color: isAssigned ? Colors.grey : null,
                                fontSize: 14,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAssigned ? Colors.red.shade100 : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isAssigned ? 'Assigned' : 'Available',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isAssigned ? Colors.red.shade700 : Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            onTap: () => _selectStation(station),
                            enabled: !isAssigned,
                          );
                        },
                      ),
                    ),
                ],
              ),

              if (_selectedStation != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will be assigned to monitor: $_selectedStation',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Signing up...'),
                    ],
                  )
                      : const Text(
                    'Sign Up as Monitor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}