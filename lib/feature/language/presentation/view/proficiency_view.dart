import 'package:e_learning_app/feature/app_container/app_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/feature/language/data/language_cubit.dart';
import 'package:e_learning_app/feature/language/data/language_state.dart';
import 'package:e_learning_app/core/model/language_model.dart';

class ProficiencyPage extends StatefulWidget {
  final List<Language> selectedLanguages;

  const ProficiencyPage({
    super.key,
    required this.selectedLanguages,
  });

  @override
  _ProficiencyPageState createState() => _ProficiencyPageState();
}

class _ProficiencyPageState extends State<ProficiencyPage> {
  Map<int, String> languageProficiencies = {};
  List<Interest> selectedInterests = [];
  List<Interest> availableInterests = [];
  bool isRegistering = false;
  bool isProcessingInterests = false;
  bool isLoadingInterests = false;
  int currentLanguageIndex = 0;
  PageController pageController = PageController();

  final Map<String, String> proficiencyMapping = {
    'Basic': 'Basic',
    'Independent': 'Conversational',
    'Proficient': 'Fluent',
    'Native': 'Native',
  };

  final Map<String, IconData> topicIcons = {
    'Programming': Icons.code,
    'Fashion': Icons.checkroom,
    'Art': Icons.palette,
    'Gaming': Icons.sports_esports,
    'Politics': Icons.how_to_vote,
    'Photography': Icons.camera_alt,
    'Tourism': Icons.travel_explore,
    'Literature': Icons.menu_book,
    'Music': Icons.music_note,
    'Sports': Icons.sports_soccer,
    'Business': Icons.business,
    'Science': Icons.science,
  };

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  void _loadInterests() {
    setState(() {
      isLoadingInterests = true;
    });
    context.read<LanguageCubit>().getAllInterests();
  }

  bool get isLastLanguage =>
      currentLanguageIndex == widget.selectedLanguages.length - 1;
  bool get isInterestsStep =>
      currentLanguageIndex == widget.selectedLanguages.length;
  bool get allLanguagesConfigured =>
      languageProficiencies.length == widget.selectedLanguages.length;

  void _nextStep() {
    if (isInterestsStep) {
      _handleRegistration();
    } else if (isLastLanguage && allLanguagesConfigured) {
      // Move to interests step
      setState(() {
        currentLanguageIndex++;
      });
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Move to next language
      setState(() {
        currentLanguageIndex++;
      });
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (currentLanguageIndex > 0) {
      setState(() {
        currentLanguageIndex--;
      });
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceed() {
    if (isInterestsStep) {
      return selectedInterests.isNotEmpty; // Interests are required
    }
    return languageProficiencies
        .containsKey(widget.selectedLanguages[currentLanguageIndex].id);
  }

  String _getButtonText() {
    if (isInterestsStep) {
      return 'Complete Registration';
    } else if (isLastLanguage && allLanguagesConfigured) {
      return 'Continue to Interests';
    } else {
      return 'Next Language';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: currentLanguageIndex > 0
              ? _previousStep
              : () => Navigator.pop(context),
        ),
        title: Text(
          isInterestsStep
              ? 'Select Interests'
              : widget.selectedLanguages[currentLanguageIndex].name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocListener<LanguageCubit, LanguageState>(
        listener: (context, state) {
          if (state is InterestSuccess) {
            setState(() {
              availableInterests = state.interests;
              isLoadingInterests = false;
            });
          } else if (state is LanguageUpdateSuccess) {
            if (selectedInterests.isNotEmpty) {
              _addSelectedInterests();
            } else {
              _completeRegistration();
            }
          } else if (state is UserInterestAddSuccess) {
            if (isProcessingInterests) {
              return;
            }
            _completeRegistration();
          } else if (state is LanguageError) {
            setState(() {
              isRegistering = false;
              isProcessingInterests = false;
              isLoadingInterests = false;
            });
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: isInterestsStep
                          ? 1.0
                          : (currentLanguageIndex + 1) /
                              (widget.selectedLanguages.length + 1),
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4A90E2)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isInterestsStep
                          ? 'Final Step: Choose Your Interests'
                          : 'Step ${currentLanguageIndex + 1} of ${widget.selectedLanguages.length + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      widget.selectedLanguages.length + 1, // +1 for interests
                  itemBuilder: (context, index) {
                    if (index == widget.selectedLanguages.length) {
                      return _buildInterestsStep();
                    } else {
                      return _buildLanguageProficiencyStep(
                          widget.selectedLanguages[index]);
                    }
                  },
                ),
              ),

              // Bottom button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        _canProceed() && !isRegistering ? _nextStep : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isRegistering
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isProcessingInterests
                                    ? 'Adding interests...'
                                    : 'Registering...',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _getButtonText(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageProficiencyStep(Language language) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4A90E2).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    language.flag ?? _getDefaultFlag(language.name),
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select your proficiency level',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 600),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Text(
                      'How good are you at ${language.name}?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Select your current proficiency level',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),

            // Proficiency cards
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildProficiencyCard(
                        language.id,
                        'Basic',
                        'Foundational skills for simple everyday tasks.',
                        Icons.looks_one_outlined,
                        const Color(0xFF81C784),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildProficiencyCard(
                        language.id,
                        'Independent',
                        'Confident in everyday conversations.',
                        Icons.looks_two_outlined,
                        const Color(0xFF64B5F6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildProficiencyCard(
                        language.id,
                        'Proficient',
                        'Advanced understanding and expression.',
                        Icons.looks_3_outlined,
                        const Color(0xFFFFB74D),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildProficiencyCard(
                        language.id,
                        'Native',
                        'Full fluency with cultural understanding.',
                        Icons.looks_4_outlined,
                        const Color(0xFFE57373),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Progress summary
            if (languageProficiencies.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.checklist_rounded,
                          color: Color(0xFF4A90E2),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Progress Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...languageProficiencies.entries.map((entry) {
                      final lang = widget.selectedLanguages
                          .firstWhere((l) => l.id == entry.key);
                      final isCurrentLanguage = lang.id == language.id;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isCurrentLanguage
                              ? const Color(0xFF4A90E2).withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: isCurrentLanguage
                              ? Border.all(
                                  color:
                                      const Color(0xFF4A90E2).withOpacity(0.3))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Text(
                              lang.flag ?? _getDefaultFlag(lang.name),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${lang.name}: ${entry.value}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isCurrentLanguage
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isCurrentLanguage
                                      ? const Color(0xFF4A90E2)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (isCurrentLanguage)
                              const Icon(
                                Icons.edit,
                                size: 16,
                                color: Color(0xFF4A90E2),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 600),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: const Text(
                      'What topics interest you?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Choose at least one topic you\'d like to talk about',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Selected interests summary
            if (selectedInterests.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
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
                        const Icon(
                          Icons.favorite,
                          color: Color(0xFF4A90E2),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Interests (${selectedInterests.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedInterests.map((interest) {
                        IconData icon =
                            topicIcons[interest.name] ?? Icons.category;
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
                              Icon(
                                icon,
                                size: 14,
                                color: const Color(0xFF4A90E2),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                interest.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF4A90E2),
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

            // Languages summary
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.language,
                        color: Color(0xFF4A90E2),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Languages (${widget.selectedLanguages.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...widget.selectedLanguages.map((language) {
                    final proficiency =
                        languageProficiencies[language.id] ?? 'Not set';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Text(
                            language.flag ?? _getDefaultFlag(language.name),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${language.name}: $proficiency',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 8),
            _buildInterestsSection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsSection() {
    if (isLoadingInterests) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
        ),
      );
    }

    if (availableInterests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No interests available at the moment',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadInterests,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Color(0xFF4A90E2),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: availableInterests.map((interest) {
        return _buildInterestChip(interest);
      }).toList(),
    );
  }

  Widget _buildInterestChip(Interest interest) {
    bool isSelected =
        selectedInterests.any((selected) => selected.id == interest.id);
    IconData icon = topicIcons[interest.name] ?? Icons.category;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedInterests
                .removeWhere((selected) => selected.id == interest.id);
          } else {
            selectedInterests.add(interest);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              interest.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProficiencyCard(int languageId, String level, String description,
      IconData icon, Color accentColor) {
    bool isSelected = languageProficiencies[languageId] == level;

    return GestureDetector(
      onTap: () {
        setState(() {
          languageProficiencies[languageId] = level;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    level,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Color(0xFF4A90E2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleRegistration() async {
    if (languageProficiencies.isEmpty) return;

    setState(() {
      isRegistering = true;
    });

    try {
      final languageCubit = context.read<LanguageCubit>();

      // Prepare language preferences for all selected languages
      final preferences = languageProficiencies.entries.map((entry) {
        final apiProficiencyLevel = proficiencyMapping[entry.value]!;
        return LanguagePreferenceUpdate(
          languageId: entry.key,
          proficiencyLevel: apiProficiencyLevel,
          isLearning: true,
        );
      }).toList();

      // Update language preferences
      await languageCubit.updateUserLanguagePreferences(
        preferences: preferences,
      );
    } catch (e) {
      setState(() {
        isRegistering = false;
      });
    }
  }

  void _addSelectedInterests() async {
    if (selectedInterests.isEmpty) {
      _completeRegistration();
      return;
    }

    setState(() {
      isProcessingInterests = true;
    });

    try {
      final languageCubit = context.read<LanguageCubit>();

      // Add interests one by one
      for (Interest interest in selectedInterests) {
        await languageCubit.addUserInterest(interestId: interest.id);
      }

      setState(() {
        isProcessingInterests = false;
      });

      _completeRegistration();
    } catch (e) {
      setState(() {
        isProcessingInterests = false;
        isRegistering = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to add interests. Registration completed without interests.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _completeRegistration();
    }
  }

  void _completeRegistration() {
    setState(() {
      isRegistering = false;
      isProcessingInterests = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Registration completed successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppContainer()),
      );
    });
  }

  String _getDefaultFlag(String languageName) {
    switch (languageName.toLowerCase()) {
      case 'english':
        return '🇬🇧';
      case 'french':
        return '🇫🇷';
      case 'spanish':
        return '🇪🇸';
      case 'german':
        return '🇩🇪';
      case 'italian':
        return '🇮🇹';
      case 'arabic':
        return '🇸🇦';
      case 'chinese':
        return '🇨🇳';
      case 'japanese':
        return '🇯🇵';
      default:
        return '🏳️';
    }
  }
}
