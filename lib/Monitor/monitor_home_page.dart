import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../auth/login_page.dart';

final supabase = Supabase.instance.client;

class MonitorHomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const MonitorHomePage({super.key, required this.user});

  @override
  State<MonitorHomePage> createState() => _MonitorHomePageState();
}

class _MonitorHomePageState extends State<MonitorHomePage> {
  Map<String, dynamic>? _station;
  bool _loading = true;
  bool _submitted = false;
  bool _submitting = false;
  File? _image;
  final ImagePicker _picker = ImagePicker();

  // Controllers for vote inputs
  final TextEditingController _candidate1Controller = TextEditingController();
  final TextEditingController _candidate2Controller = TextEditingController();
  final TextEditingController _candidate3Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMyStation();
  }

  Future<void> _loadMyStation() async {
    setState(() => _loading = true);
    try {
      final phone = widget.user['phone'] as String;
      final rows = await supabase.rpc('get_monitor_station', params: {
        'monitor_phone': phone,
      });
      if (rows is List && rows.isNotEmpty) {
        _station = Map<String, dynamic>.from(rows.first);

        // Check if results have already been submitted
        if (_station!['total'] != null && _station!['total'] > 0) {
          _submitted = true;
        }

        // Pre-populate the fields if data exists
        _candidate1Controller.text = _station!['candidate1']?.toString() ?? '0';
        _candidate2Controller.text = _station!['candidate2']?.toString() ?? '0';
        _candidate3Controller.text = _station!['candidate3']?.toString() ?? '0';
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _image = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }

  Future<void> _submitResults() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a picture of the results')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Upload image first
      final String fileName = '${_station!['station_name']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage
          .from('results-pictures')
          .upload(fileName, _image!);

      // Get the public URL
      final String imageUrl = supabase.storage
          .from('results-pictures')
          .getPublicUrl(fileName);

      // Update the polling station with results
      await supabase
          .from('polling_station')
          .update({
        'candidate1': int.parse(_candidate1Controller.text),
        'candidate2': int.parse(_candidate2Controller.text),
        'candidate3': int.parse(_candidate3Controller.text),
        'Pictureurl': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('name', _station!['station_name']);

      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results submitted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting results: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  int get _totalVotes {
    try {
      return (int.tryParse(_candidate1Controller.text) ?? 0) +
          (int.tryParse(_candidate2Controller.text) ?? 0) +
          (int.tryParse(_candidate3Controller.text) ?? 0);
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Polling Station Monitor'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (r) => false
            ),
            tooltip: 'Logout',
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _station == null
          ? const Center(child: Text('No station assigned to you.'))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Station Information Card
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _station!['station_name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ward: ${_station!['ward_name']}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Results Section
              const Text(
                'Record Votes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Candidate Inputs
              _buildCandidateInput(1, _candidate1Controller),
              _buildCandidateInput(2, _candidate2Controller),
              _buildCandidateInput(3, _candidate3Controller),

              const SizedBox(height: 16),

              // Total Votes
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Votes:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _totalVotes.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Picture Section
              const Text(
                'Evidence Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Take a clear picture of the physical vote count sheet',
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 16),

              // Image Preview and Capture Button
              _image == null
                  ? Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.photo_camera,
                  size: 50,
                  color: Colors.grey[400],
                ),
              )
                  : Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(_image!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: ElevatedButton.icon(
                  onPressed: _submitted ? null : _pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Picture'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: _submitted
                    ? ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      SizedBox(width: 8),
                      Text('Results Submitted Successfully'),
                    ],
                  ),
                )
                    : ElevatedButton(
                  onPressed: _submitting ? null : _submitResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _submitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Submit Results'),
                ),
              ),

              if (_submitted) ...[
                const SizedBox(height: 16),
                const Text(
                  'Note: Results cannot be modified after submission.',
                  style: TextStyle(
                    color: Colors.red,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateInput(int candidateNumber, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !_submitted,
        decoration: InputDecoration(
          labelText: 'Candidate $candidateNumber Votes',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _submitted ? null : () => controller.clear(),
          ),
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          setState(() {}); // Update the total
        },
      ),
    );
  }

  @override
  void dispose() {
    _candidate1Controller.dispose();
    _candidate2Controller.dispose();
    _candidate3Controller.dispose();
    super.dispose();
  }
}