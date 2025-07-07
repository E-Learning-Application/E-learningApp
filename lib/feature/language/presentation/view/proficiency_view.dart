import 'package:e_learning_app/feature/app_container/app_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/feature/language/data/language_cubit.dart';
import 'package:e_learning_app/feature/language/data/language_state.dart';

class ProficiencyPage extends StatefulWidget {
  final String language;
  final int? languageId;

  const ProficiencyPage({
    super.key,
    required this.language,
    this.languageId,
  });

  @override
  _ProficiencyPageState createState() => _ProficiencyPageState();
}

class _ProficiencyPageState extends State<ProficiencyPage> {
  String? selectedProficiency;
  List<Interest> selectedInterests = [];
  List<Interest> availableInterests = [];
  bool isRegistering = false;
  bool isProcessingInterests = false;
  bool isLoadingInterests = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.language,
          style: TextStyle(
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

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        },
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: 1.0,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                  ),
                  SizedBox(height: 30),
                  TweenAnimationBuilder(
                    duration: Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Text(
                            'How good are you at ${widget.language}?',
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
                  SizedBox(height: 8),
                  Text(
                    'Select your current proficiency level',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 30),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildProficiencyCard(
                              'Basic',
                              'Foundational skills for simple everyday tasks.',
                              Icons.looks_one_outlined,
                              Color(0xFF81C784),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildProficiencyCard(
                              'Independent',
                              'Confident in everyday conversations.',
                              Icons.looks_two_outlined,
                              Color(0xFF64B5F6),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildProficiencyCard(
                              'Proficient',
                              'Advanced understanding and expression.',
                              Icons.looks_3_outlined,
                              Color(0xFFFFB74D),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildProficiencyCard(
                              'Native',
                              'Full fluency with cultural understanding.',
                              Icons.looks_4_outlined,
                              Color(0xFFE57373),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 40),
                  Text(
                    'What topics interest you?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Choose topics you\'d like to learn about (optional)',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildInterestsSection(),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width - 48,
        height: 56,
        child: ElevatedButton(
          onPressed: selectedProficiency != null && !isRegistering
              ? _handleRegistration
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4A90E2),
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
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      isProcessingInterests
                          ? 'Adding interests...'
                          : 'Registering...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Complete Registration',
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

  Widget _buildInterestsSection() {
    if (isLoadingInterests) {
      return Center(
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
        padding: EdgeInsets.all(20),
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
            SizedBox(height: 8),
            Text(
              'No interests available at the moment',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: _loadInterests,
              child: Text(
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
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF4A90E2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Color(0xFF4A90E2) : Colors.transparent,
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
            SizedBox(width: 6),
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

  Widget _buildProficiencyCard(
      String level, String description, IconData icon, Color accentColor) {
    bool isSelected = selectedProficiency == level;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedProficiency = level;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        height: 130,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? Color(0xFF4A90E2) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Color(0xFF4A90E2).withOpacity(0.1)
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
                  padding: EdgeInsets.all(6),
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
                SizedBox(width: 8),
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              child: Text(
                description,
                style: TextStyle(
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
    if (selectedProficiency == null) return;

    setState(() {
      isRegistering = true;
    });

    try {
      final languageCubit = context.read<LanguageCubit>();
      final languageId = widget.languageId ?? 1;
      final apiProficiencyLevel = proficiencyMapping[selectedProficiency!]!;

      final preferences = [
        LanguagePreferenceUpdate(
          languageId: languageId,
          proficiencyLevel: apiProficiencyLevel,
          isLearning: true,
        ),
      ];

      // First update language preferences
      await languageCubit.updateUserLanguagePreferences(
        preferences: preferences,
      );
    } catch (e) {
      setState(() {
        isRegistering = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('An error occurred during registration. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        SnackBar(
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
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Registration completed successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    Future.delayed(Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AppContainer()),
      );
    });
  }
}
