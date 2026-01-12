import 'package:flutter/material.dart';
import 'package:alpr/data/database_helper.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    final logs = await _dbHelper.getAllLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Records?'),
        content: const Text('This will delete all entry logs permanently. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CLEAR ALL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.clearAllLogs();
      await _fetchLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New set started! All records cleared.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear All',
            onPressed: _logs.isEmpty ? null : _clearLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Text(
                    'No records found.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final plate = log['plate_number'] as String;
                    final timestamp = log['timestamp'] as String;
                    final status = log['status'] as String;
                    final isWhitelisted = status == 'whitelisted';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey[850], // Dark theme card
                      child: ListTile(
                        leading: Icon(
                          isWhitelisted ? Icons.check_circle : Icons.warning,
                          color: isWhitelisted ? Colors.greenAccent : Colors.redAccent,
                          size: 32,
                        ),
                        title: Text(
                          plate,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'Time: ${timestamp.split('T').join(' ').split('.').first}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: isWhitelisted ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
