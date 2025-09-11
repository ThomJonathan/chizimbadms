import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

final supabase = Supabase.instance.client;

class RecordVotesPage extends StatefulWidget {
  final Map<String, dynamic> station;
  final List<Map<String, dynamic>> candidates;
  final VoidCallback onResultsSubmitted;

  const RecordVotesPage({
    super.key,
    required this.station,
    required this.candidates,
    required this.onResultsSubmitted,
  });

  @override
  State<RecordVotesPage> createState() => _RecordVotesPageState();
}

class _RecordVotesPageState extends State<RecordVotesPage> {
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
    // Pre-populate the fields if data exists
    _candidate1Controller.text = widget.station['candidate1']?.toString() ?? '';
    _candidate2Controller.text = widget.station['candidate2']?.toString() ?? '';
    _candidate3Controller.text = widget.station['candidate3']?.toString() ?? '';
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
    // Validate inputs
    if (_candidate1Controller.text.isEmpty ||
        _candidate2Controller.text.isEmpty ||
        _candidate3Controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter votes for all candidates')),
      );
      return;
    }

    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a picture of the results')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Upload image first
      final String fileName = '${widget.station['station_name']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
          .eq('name', widget.station['station_name']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results submitted successfully!')),
      );

      widget.onResultsSubmitted();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Title
        const Text(
          'Record Votes',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 24),

        // Candidate Vote Cards
        if (widget.candidates.length >= 1)
          _buildCandidateCard(widget.candidates[0], _candidate1Controller),
        if (widget.candidates.length >= 2)
          _buildCandidateCard(widget.candidates[1], _candidate2Controller),
        if (widget.candidates.length >= 3)
          _buildCandidateCard(widget.candidates[2], _candidate3Controller),

        const SizedBox(height: 16),

        // Total Votes Card
        Card(
          elevation: 2,
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Votes:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _totalVotes.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Evidence Photo Section
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

        const SizedBox(height: 12),

        // Image Upload Button
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: Icon(_image == null ? Icons.camera_alt : Icons.check_circle),
          label: Text(_image == null ? 'Take Picture' : 'Picture Taken - Tap to Retake'),
          style: OutlinedButton.styleFrom(
            backgroundColor: _image == null ? null : Colors.green[50],
            foregroundColor: _image == null ? Colors.blue[600] : Colors.green[600],
            side: BorderSide(
              color: _image == null ? Colors.blue[600]! : Colors.green[600]!,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),

        // Image Preview (if image is taken)
        if (_image != null) ...[
          const SizedBox(height: 16),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green[300]!, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                _image!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Retake'),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _image = null;
                  });
                },
                icon: const Icon(Icons.delete),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),

        // Save Button - Make it more prominent
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: _submitting ? null : _submitResults,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Saving...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save, size: 24),
                SizedBox(width: 12),
                Text(
                  'SAVE RESULTS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Add some bottom padding to ensure button is visible
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> candidate, TextEditingController controller) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidate['fullname'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              candidate['party'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Enter number of votes',
                hintText: '0',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.how_to_vote),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => controller.clear(),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {}); // Update the total
              },
            ),
          ],
        ),
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