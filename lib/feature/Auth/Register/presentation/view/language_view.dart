import 'package:e_learning_app/feature/Auth/Register/presentation/view/proficiency_view.dart';
import 'package:flutter/material.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
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
          child: SingleChildScrollView(
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
                Column(
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
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width - 48, // 24 padding each side
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              // ignore: deprecated_member_use
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

