import 'package:e_learning_app/feature/language/data/language_state.dart';
import 'package:e_learning_app/feature/settings/data/interest_mangment_cubit.dart';
import 'package:e_learning_app/feature/settings/data/interest_mangment_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/core/service/interest_service.dart';
import 'package:e_learning_app/core/model/interest_update_request.dart';

class InterestManagementScreen extends StatelessWidget {
  final InterestService? interestService;
  final AuthService? authService;

  const InterestManagementScreen({
    super.key,
    this.interestService,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InterestManagementCubit(
        interestService: interestService ?? context.read<InterestService>(),
        authService: authService ?? context.read<AuthService>(),
      )..loadInterests(),
      child: const InterestManagementView(),
    );
  }
}

class InterestManagementScreenWithBuilder extends StatelessWidget {
  const InterestManagementScreenWithBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    final interestService = context.read<InterestService>();
    final authService = context.read<AuthService>();
    return BlocProvider(
      create: (context) => InterestManagementCubit(
        interestService: interestService,
        authService: authService,
      )..loadInterests(),
      child: const InterestManagementView(),
    );
  }
}

class InterestManagementScreenSelfContained extends StatelessWidget {
  const InterestManagementScreenSelfContained({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        try {
          final interestService = context.read<InterestService>();
          final authService = context.read<AuthService>();

          return InterestManagementCubit(
            interestService: interestService,
            authService: authService,
          )..loadInterests();
        } catch (e) {
          throw Exception(
              'InterestService and AuthService must be provided in the widget tree');
        }
      },
      child: const InterestManagementView(),
    );
  }
}

class InterestManagementView extends StatelessWidget {
  const InterestManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<InterestManagementCubit, InterestManagementState>(
      listener: (context, state) {
        if (state is InterestManagementSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state is InterestManagementError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Interest Management',
            style: TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.purple[50],
          foregroundColor: Colors.purple[800],
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<InterestManagementCubit>().loadInterests();
              },
            ),
          ],
        ),
        body: BlocBuilder<InterestManagementCubit, InterestManagementState>(
          builder: (context, state) {
            if (state is InterestManagementLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddInterestDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Interest'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildInterestsList(context, state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInterestsList(
      BuildContext context, InterestManagementState state) {
    final cubit = context.read<InterestManagementCubit>();
    final interests = cubit.interests;

    if (interests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.interests,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No interests found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: interests.length,
      itemBuilder: (context, index) {
        final interest = interests[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple[100],
              child: Icon(
                Icons.interests,
                color: Colors.purple[700],
              ),
            ),
            title: Text(
              interest.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: interest.description != null
                ? Text(
                    interest.description!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: const Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: const Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditInterestDialog(context, interest);
                } else if (value == 'delete') {
                  _showDeleteInterestDialog(context, interest);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showAddInterestDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Interest'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Interest Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                context.read<InterestManagementCubit>().addInterest(
                      InterestAddRequest(
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                      ),
                    );
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditInterestDialog(BuildContext context, Interest interest) {
    final nameController = TextEditingController(text: interest.name);
    final descriptionController =
        TextEditingController(text: interest.description ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Interest'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Interest Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeleteInterestDialog(BuildContext context, Interest interest) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Interest'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${interest.name}"?'),
            if (interest.description != null) ...[
              const SizedBox(height: 8),
              Text(
                'Description: ${interest.description}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
