import 'package:e_learning_app/core/model/language_model.dart';
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
  List<Language> selectedLanguages = [];
  List<Language> availableLanguages = [];

  @override
  void initState() {
    super.initState();
    _initializeLanguages();
  }

  Future<void> _initializeLanguages() async {
    final languageCubit = context.read<LanguageCubit>();

    final isAuthenticated = await languageCubit.checkAuthentication();

    if (!isAuthenticated) {
      if (mounted) {
        _showAuthenticationError();
      }
      return;
    }

    languageCubit.getAllLanguages();
  }

  void _showAuthenticationError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: const Text(
            'You need to be logged in to access languages. Please login and try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleLanguageSelection(Language language) {
    setState(() {
      final index =
          selectedLanguages.indexWhere((lang) => lang.id == language.id);
      if (index != -1) {
        selectedLanguages.removeAt(index);
      } else {
        selectedLanguages.add(language);
      }
    });
  }

  bool _isLanguageSelected(Language language) {
    return selectedLanguages.any((lang) => lang.id == language.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Choose languages you want to learn',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select multiple languages to get started',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                if (selectedLanguages.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4A90E2).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: const Color(0xFF4A90E2),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Selected Languages (${selectedLanguages.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4A90E2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedLanguages.map((language) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF4A90E2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    language.flag ??
                                        _getDefaultFlag(language.name),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    language.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                BlocConsumer<LanguageCubit, LanguageState>(
                  listener: (context, state) {
                    if (state is LanguageSuccess) {
                      availableLanguages = state.languages.cast<Language>();
                    }
                  },
                  builder: (context, state) {
                    if (state is LanguageLoading) {
                      return const Center(
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
                      return Container();
                    }
                  },
                ),
                const SizedBox(height: 100), // Space for floating button
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width - 48,
        height: 56,
        child: ElevatedButton(
          onPressed: selectedLanguages.isNotEmpty
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProficiencyPage(
                        selectedLanguages: selectedLanguages,
                      ),
                    ),
                  );
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A90E2),
            disabledBackgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            selectedLanguages.isEmpty
                ? 'Select at least one language'
                : 'Next (${selectedLanguages.length} selected)',
            style: const TextStyle(
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
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;

    if (screenWidth > 800) {
      crossAxisCount = 4;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 3;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: languages.length,
      itemBuilder: (context, index) {
        return _buildLanguageCard(languages[index]);
      },
    );
  }

  Widget _buildLanguageCard(Language language) {
    bool isSelected = _isLanguageSelected(language);

    return GestureDetector(
      onTap: () => _toggleLanguageSelection(language),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color:
                isSelected ? const Color(0xFF4A90E2) : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF4A90E2).withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: Offset(0, isSelected ? 4 : 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    language.flag ?? _getDefaultFlag(language.name),
                    style: const TextStyle(
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      language.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A90E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
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
          const SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final languageCubit = context.read<LanguageCubit>();

              final isAuthenticated = await languageCubit.checkAuthentication();

              if (!isAuthenticated) {
                _showAuthenticationError();
                return;
              }

              languageCubit.getAllLanguages();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

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
      case 'portuguese':
        return '🇵🇹';
      case 'hindi':
        return '🇮🇳';
      case 'turkish':
        return '🇹🇷';
      case 'dutch':
        return '🇳🇱';
      case 'swedish':
        return '🇸🇪';
      case 'norwegian':
        return '🇳🇴';
      case 'danish':
        return '🇩🇰';
      case 'finnish':
        return '🇫🇮';
      case 'polish':
        return '🇵🇱';
      case 'czech':
        return '🇨🇿';
      case 'hungarian':
        return '🇭🇺';
      case 'greek':
        return '🇬🇷';
      case 'hebrew':
        return '🇮🇱';
      case 'thai':
        return '🇹🇭';
      case 'vietnamese':
        return '🇻🇳';
      case 'indonesian':
        return '🇮🇩';
      case 'malay':
        return '🇲🇾';
      case 'swahili':
        return '🇰🇪';
      default:
        return '🌐';
    }
  }
}
