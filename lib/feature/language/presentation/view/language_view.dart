import 'package:e_learning_app/core/service/language_service.dart';
import 'package:e_learning_app/feature/language/data/language_cubit.dart';
import 'package:e_learning_app/feature/language/presentation/view/proficiency_view.dart';
import 'package:e_learning_app/feature/language/data/language_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  _LanguageSelectionPageState createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String? selectedLanguage;

  @override
  void initState() {
    super.initState();
    _initializeLanguages();
  }

  Future<void> _initializeLanguages() async {
    final languageCubit = context.read<LanguageCubit>();

    // Check authentication first
    final isAuthenticated = await languageCubit.checkAuthentication();

    if (!isAuthenticated) {
      if (mounted) {
        _showAuthenticationError();
      }
      return;
    }

    // Fetch languages when the page loads
    languageCubit.getAllLanguages();
  }

  void _showAuthenticationError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Authentication Required'),
        content: Text(
            'You need to be logged in to access languages. Please login and try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),

                Text(
                  'Choose the language you\nwant to learn',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 40),

                // Language options with BLoC
                BlocBuilder<LanguageCubit, LanguageState>(
                  builder: (context, state) {
                    if (state is LanguageLoading) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4A90E2),
                        ),
                      );
                    } else if (state is LanguageSuccess) {
                      return _buildLanguageGrid(
                          state.languages.cast<Language>());
                    } else if (state is LanguageError) {
                      return _buildErrorWidget(state.message);
                    } else {
                      return Container(); // Initial state
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width - 48, // 24 padding each side
        height: 56,
        child: ElevatedButton(
          onPressed: selectedLanguage != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ProficiencyPage(language: selectedLanguage!)),
                  );
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4A90E2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Next',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLanguageGrid(List<Language> languages) {
    // Group languages in pairs for rows
    List<Widget> rows = [];
    for (int i = 0; i < languages.length; i += 2) {
      Widget row;
      if (i + 1 < languages.length) {
        // Two languages in a row
        row = _buildLanguageRow(languages[i], languages[i + 1]);
      } else {
        // Single language in the last row
        row = Row(
          children: [
            Expanded(child: _buildLanguageCard(languages[i])),
            Expanded(child: SizedBox()), // Empty space
          ],
        );
      }
      rows.add(row);
      if (i + 2 < languages.length) {
        rows.add(SizedBox(height: 20));
      }
    }

    return Column(children: rows);
  }

  Widget _buildLanguageRow(Language lang1, Language lang2) {
    return Row(
      children: [
        Expanded(
          child: _buildLanguageCard(lang1),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildLanguageCard(lang2),
        ),
      ],
    );
  }

  Widget _buildLanguageCard(Language language) {
    bool isSelected = selectedLanguage == language.name;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLanguage = language.name;
        });
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? Color(0xFF4A90E2) : Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Use language.flag if available, otherwise use a default emoji
            Text(language.flag ?? _getDefaultFlag(language.name),
                style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text(
              language.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.red[400],
            ),
          ),
          SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final languageCubit = context.read<LanguageCubit>();

              // Check authentication before retrying
              final isAuthenticated = await languageCubit.checkAuthentication();

              if (!isAuthenticated) {
                _showAuthenticationError();
                return;
              }

              languageCubit.getAllLanguages();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4A90E2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to provide default flags for languages
  String _getDefaultFlag(String languageName) {
    switch (languageName.toLowerCase()) {
      case 'english':
        return '🇺🇸';
      case 'japanese':
        return '🇯🇵';
      case 'arabic':
        return '🇪🇬';
      case 'spanish':
        return '🇪🇸';
      case 'chinese':
        return '🇨🇳';
      case 'italian':
        return '🇮🇹';
      case 'russian':
        return '🇷🇺';
      case 'french':
        return '🇫🇷';
      case 'korean':
        return '🇰🇷';
      case 'german':
        return '🇩🇪';
      default:
        return '🌐';
    }
  }
}
