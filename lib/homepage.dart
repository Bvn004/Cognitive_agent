import 'package:cogbot/api.dart';
import 'package:cogbot/assessment_screen.dart';
import 'package:cogbot/learning.dart';
import 'package:flutter/material.dart';
import 'package:cogbot/login.dart'; // Assuming userId is from login.dart

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  /// Function to check if assessment is available and navigate if possible
  Future<void> checkAndNavigateToAssessment(BuildContext context) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to take the assessment')),
      );
      return;
    }

    // Check if user has NOT taken the assessment yet
    bool hasAlreadyTakenAssessment = await hasTakenAssessment(userId!);

    if (!hasAlreadyTakenAssessment) {
      // Only navigate to assessment if they haven't taken it
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => AssessmentScreen()));
    } else {
      // Show a message if they've already taken the assessment
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already completed the assessment'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Gradient
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple,
                    Colors.deepPurple.shade800,
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology, size: 24, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'CogBot',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                centerTitle: true,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Design Elements
                    Positioned(
                      right: -50,
                      top: -20,
                      child: Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -10,
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // Overlay for better text visibility
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.person, color: Colors.white),
                onPressed: () {
                  // Navigate to profile
                },
              ),
            ],
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to CogBot!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Enhance your cognitive abilities with personalized learning',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(),
                ),
                
                // Progress Summary
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade100, Colors.deepPurple.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.insights, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Text(
                            'Your Progress',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildProgressItem('Assessment', 'Pending', Icons.assignment),
                          Container(height: 40, width: 1, color: Colors.deepPurple.withOpacity(0.3)),
                          _buildProgressItem('Learning', '0%', Icons.school),
                          Container(height: 40, width: 1, color: Colors.deepPurple.withOpacity(0.3)),
                          _buildProgressItem('Practice', '0/7', Icons.repeat),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Section Header: Main Features
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade800,
                    ),
                  ),
                ),
                
                // Main Features: Assessment Button
                _buildFeatureButton(
                  context: context,
                  icon: Icons.assignment,
                  title: 'Cognitive Assessment',
                  description: 'Complete a quick assessment to personalize your learning',
                  color: Colors.blue.shade700,
                  onTap: () => checkAndNavigateToAssessment(context),
                ),
                
                // Main Features: Learning Button
                _buildFeatureButton(
                  context: context,
                  icon: Icons.school,
                  title: 'Start Learning',
                  description: 'Begin your personalized learning journey',
                  color: Colors.green.shade700,
                  onTap: () async {
                    if (userId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please log in to start learning')),
                      );
                      return;
                    }
                    
                    bool userHasTakenAssessment = await hasTakenAssessment(userId!);
                    
                    if (userHasTakenAssessment) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => Learning_Chat()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please complete the assessment first')),
                      );
                    }
                  },
                ),

                // Section Header: Tips
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Daily Tips',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade800,
                    ),
                  ),
                ),
                
                // Daily Tips
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildTipItem(
                        'Practice mindfulness for 10 minutes each day to improve focus.',
                        Colors.orange,
                      ),
                      Divider(height: 1),
                      _buildTipItem(
                        'Regular physical exercise boosts cognitive function.',
                        Colors.green,
                      ),
                      Divider(height: 1),
                      _buildTipItem(
                        'Sleep 7-8 hours for optimal brain performance.',
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 32),
                
                // Footer
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.psychology, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Text(
                            'CogBot',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Enhancing cognitive abilities through personalized learning',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '© 2025 CogBot. All rights reserved.',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.deepPurple.shade800),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.deepPurple.shade800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String tip, Color color) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}