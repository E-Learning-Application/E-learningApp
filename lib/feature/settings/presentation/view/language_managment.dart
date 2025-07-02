import 'package:e_learning_app/core/model/language_model.dart';
import 'package:e_learning_app/core/model/language_request_model.dart';
import 'package:e_learning_app/feature/settings/data/language_mangment_cubit.dart';
import 'package:e_learning_app/feature/settings/data/language_mangment_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/core/service/language_service.dart';

class LanguageManagementScreen extends StatelessWidget {
  final LanguageService? languageService;
  final AuthService? authService;

  const LanguageManagementScreen({
    super.key,
    this.languageService,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LanguageManagementCubit(
        languageService: languageService ?? context.read<LanguageService>(),
        authService: authService ?? context.read<AuthService>(),
      )..loadLanguages(),
      child: const LanguageManagementView(),
    );
  }
}

class LanguageManagementScreenWithBuilder extends StatelessWidget {
  const LanguageManagementScreenWithBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = context.read<LanguageService>();
    final authService = context.read<AuthService>();
    return BlocProvider(
      create: (context) => LanguageManagementCubit(
        languageService: languageService,
        authService: authService,
      )..loadLanguages(),
      child: const LanguageManagementView(),
    );
  }
}

class LanguageManagementScreenSelfContained extends StatelessWidget {
  const LanguageManagementScreenSelfContained({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        try {
          final languageService = context.read<LanguageService>();
          final authService = context.read<AuthService>();

          return LanguageManagementCubit(
            languageService: languageService,
            authService: authService,
          )..loadLanguages();
        } catch (e) {
          throw Exception(
              'LanguageService and AuthService must be provided in the widget tree');
        }
      },
      child: const LanguageManagementView(),
    );
  }
}

class LanguageManagementView extends StatelessWidget {
  const LanguageManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LanguageManagementCubit, LanguageManagementState>(
      listener: (context, state) {
        if (state is LanguageManagementSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state is LanguageManagementError) {
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
            'Language Management',
            style: TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.blue[50],
          foregroundColor: Colors.blue[800],
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<LanguageManagementCubit>().loadLanguages();
              },
            ),
          ],
        ),
        body: BlocBuilder<LanguageManagementCubit, LanguageManagementState>(
          builder: (context, state) {
            if (state is LanguageManagementLoading) {
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
                          onPressed: () => _showAddLanguageDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Language'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildLanguagesList(context, state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanguagesList(
      BuildContext context, LanguageManagementState state) {
    final cubit = context.read<LanguageManagementCubit>();
    final languages = cubit.languages;

    if (languages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.language,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No languages found',
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
      itemCount: languages.length,
      itemBuilder: (context, index) {
        final language = languages[index];
        cubit.selectedLanguageIds.contains(language.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            title: Text(
              language.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              'Code: ${language.code}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
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
                  _showEditLanguageDialog(context, language);
                } else if (value == 'delete') {
                  _showDeleteLanguageDialog(context, language);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showAddLanguageDialog(BuildContext context) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Language Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Language Code (en, fr)',
                border: OutlineInputBorder(),
              ),
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
              if (nameController.text.trim().isNotEmpty &&
                  codeController.text.trim().isNotEmpty) {
                context.read<LanguageManagementCubit>().addLanguages([
                  AddLanguageRequest(
                    name: nameController.text.trim(),
                    code: codeController.text.trim(),
                  ),
                ]);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditLanguageDialog(BuildContext context, Language language) {
    final nameController = TextEditingController(text: language.name);
    final codeController = TextEditingController(text: language.code);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Language Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Language Code',
                border: OutlineInputBorder(),
              ),
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
              if (nameController.text.trim().isNotEmpty &&
                  codeController.text.trim().isNotEmpty) {
                context.read<LanguageManagementCubit>().updateLanguages([
                  UpdateLanguageRequest(
                    id: language.id,
                    name: nameController.text.trim(),
                    code: codeController.text.trim(),
                  ),
                ]);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteLanguageDialog(BuildContext context, Language language) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Language'),
        content: Text('Are you sure you want to delete "${language.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context
                  .read<LanguageManagementCubit>()
                  .removeLanguages([language.id]);
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
