import 'package:e_learning_app/feature/settings/data/settings_cubit.dart';
import 'package:e_learning_app/feature/settings/data/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match History'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is SettingsHistoryLoaded) {
            return _buildHistoryList(state.matchHistory);
          } else if (state is SettingsError) {
            return _buildErrorView(context, state.message);
          } else {
            return _buildEmptyView();
          }
        },
      ),
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> matchHistory) {
    if (matchHistory.isEmpty) {
      return _buildEmptyHistoryView();
    }

    return RefreshIndicator(
      onRefresh: () async {
        // You can add refresh functionality here
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: matchHistory.length,
        itemBuilder: (context, index) {
          final match = matchHistory[index];
          return _buildHistoryCard(match);
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(match['status']),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _getStatusIcon(match['status']),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match['partnerName'] ?? 'Unknown Partner',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatStatus(match['status']),
                        style: TextStyle(
                          fontSize: 14,
                          color: _getStatusColor(match['status']),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(match['startTime']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (match['duration'] != null)
                      Text(
                        _formatDuration(match['duration']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (match['language'] != null || match['interests'] != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              if (match['language'] != null)
                _buildInfoRow(
                  icon: Icons.language,
                  label: 'Language',
                  value: match['language'],
                ),
              if (match['interests'] != null)
                _buildInfoRow(
                  icon: Icons.interests,
                  label: 'Interests',
                  value: (match['interests'] as List).join(', '),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No Match History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start matching to see your history here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error Loading History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<SettingsCubit>().navigateToHistory();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Text(
        'Something went wrong',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'active':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'active':
        return Icons.radio_button_checked;
      default:
        return Icons.help_outline;
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return 'Unknown';
    return status.substring(0, 1).toUpperCase() +
        status.substring(1).toLowerCase();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '';
    try {
      if (duration is int) {
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        return '${minutes}m ${seconds}s';
      } else if (duration is String) {
        final parts = duration.split(':');
        if (parts.length >= 2) {
          final hours = int.parse(parts[0]);
          final minutes = int.parse(parts[1]);
          if (hours > 0) {
            return '${hours}h ${minutes}m';
          } else {
            return '${minutes}m';
          }
        }
      }
    } catch (e) {
      return '';
    }
    return '';
  }
}
