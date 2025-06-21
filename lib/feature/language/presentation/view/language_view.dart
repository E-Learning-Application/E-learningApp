import 'package:flutter/material.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  _LanguageSelectionPageState createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String? selectedLanguage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             
              SizedBox(height: 40),
              
              Text(
                'Choose the language you\nwant to learn',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 40),
              
              // Language options
              Expanded(
                child: Column(
                  children: [
                    _buildLanguageRow('🇺🇸', 'English', '🇯🇵', 'Japanese'),
                    SizedBox(height: 20),
                    _buildLanguageRow('🇪🇬', 'Arabic', '🇪🇸', 'Spanish'),
                    SizedBox(height: 20),
                    _buildLanguageRow('🇨🇳', 'Chinese', '🇮🇹', 'Italian'),
                    SizedBox(height: 20),
                    _buildLanguageRow('🇷🇺', 'Russian', '🇫🇷', 'French'),
                    SizedBox(height: 20),
                    _buildLanguageRow('🇰🇷', 'Korean', '🇩🇪', 'German'),
                  ],
                ),
              ),
              
              Container(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedLanguage != null ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProficiencyPage(language: selectedLanguage!)),
                    );
                  } : null,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageRow(String flag1, String lang1, String flag2, String lang2) {
    return Row(
      children: [
        Expanded(
          child: _buildLanguageCard(flag1, lang1),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildLanguageCard(flag2, lang2),
        ),
      ],
    );
  }

  Widget _buildLanguageCard(String flag, String language) {
    bool isSelected = selectedLanguage == language;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLanguage = language;
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
            Text(flag, style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text(
              language,
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
}

class ProficiencyPage extends StatefulWidget {
  final String language;
  
  ProficiencyPage({required this.language});

  @override
  _ProficiencyPageState createState() => _ProficiencyPageState();
}

class _ProficiencyPageState extends State<ProficiencyPage> {
  String? selectedProficiency;
  List<String> selectedTopics = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status bar mock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('9:41', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Icon(Icons.signal_cellular_4_bar, size: 17),
                      SizedBox(width: 5),
                      Icon(Icons.wifi, size: 17),
                      SizedBox(width: 5),
                      Icon(Icons.battery_full, size: 24),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 40),
              
              // Title
              Text(
                'how good you are?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 30),
              
              // Proficiency levels
              Row(
                children: [
                  Expanded(
                    child: _buildProficiencyCard(
                      'Basic',
                      'Foundational skills for simple everyday tasks.',
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildProficiencyCard(
                      'Independent',
                      'Confident in everyday conversations.',
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
                      'Advanced understanding and oral expression.',
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildProficiencyCard(
                      'Native',
                      'Full fluency with cultural understanding.',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 40),
              
              // Topics section
              Text(
                'topics you interest in?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 20),
              
              // Topics grid
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildTopicChip('Programming'),
                        SizedBox(width: 12),
                        _buildTopicChip('Fashion'),
                        SizedBox(width: 12),
                        _buildTopicChip('Art'),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTopicChip('Gaming'),
                        SizedBox(width: 12),
                        _buildTopicChip('Politics'),
                        SizedBox(width: 12),
                        _buildTopicChip('Photography'),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTopicChip('Tourism'),
                        SizedBox(width: 12),
                        _buildTopicChip('Literature'),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Register button
              Container(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedProficiency != null && selectedTopics.isNotEmpty ? () {
                    // Handle registration
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Registration completed!')),
                    );
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4A90E2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  Widget _buildProficiencyCard(String level, String description) {
    bool isSelected = selectedProficiency == level;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedProficiency = level;
        });
      },
      child: Container(
        height: 100,
        padding: EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              level,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 12,
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

  Widget _buildTopicChip(String topic) {
    bool isSelected = selectedTopics.contains(topic);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedTopics.remove(topic);
          } else {
            selectedTopics.add(topic);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF4A90E2) : Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          topic,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}