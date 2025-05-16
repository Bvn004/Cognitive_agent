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
      appBar: AppBar(title: const Text('CogBot')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => checkAndNavigateToAssessment(context),
              child: const Text("Take assessment"),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                bool hastakenAssessment = await hasTakenAssessment(userId!);

                if (hastakenAssessment) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => Learning_Chat()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please complete the assessment first'),
                    ),
                  );
                }
              },
              child: Text('Start Learning'),
            ),
          ],
        ),
      ),
    );
  }
}
