import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cogbot/api.dart';
import 'package:flutter/material.dart';
import 'login.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final TextEditingController _answerController = TextEditingController();
  String _question = "Loading..."; // state variable to hold the question
  bool _isAssessmentComplete = false;
  String _profile = "";
  String _rationale = "";

  @override
  void initState() {
    super.initState();
    fetchQuestion(); // fetch the question on init
  }

  Future<void> fetchQuestion() async {
    String response = await getnextquestion();

    // Check if the response is an assessment result
    if (response.startsWith("Methodical Thinker") ||
        response.contains("profile")) {
      // Assessment is complete, parse the profile
      setState(() {
        _isAssessmentComplete = true;
        _profile = response;
        // Fetch the rationale from Firestore
        fetchRationale();
      });
    } else {
      // Just a regular question
      setState(() {
        _question = response;
      });
    }
  }

  Future<void> fetchRationale() async {
    try {
      // Access the user's document in Firestore
      final DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;

        if (userData != null &&
            userData.containsKey('cognitive_profile') &&
            userData['cognitive_profile'] != null &&
            userData['cognitive_profile'].containsKey('classification') &&
            userData['cognitive_profile']['classification'] != null &&
            userData['cognitive_profile']['classification'].containsKey(
              'rationale',
            )) {
          setState(() {
            _rationale =
                userData['cognitive_profile']['classification']['rationale'];
          });
        } else {
          setState(() {
            _rationale = "No rationale found in profile data.";
          });
        }
      } else {
        setState(() {
          _rationale = "User profile not found.";
        });
      }
    } catch (e) {
      setState(() {
        _rationale = "Error loading profile analysis: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cogbot'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            clearHistory(userId!);
            Navigator.of(context).pop();
          },
        ),
      ),
      body:
          _isAssessmentComplete
              ? _buildAssessmentResults()
              : _buildQuestionInterface(),
    );
  }

  Widget _buildAssessmentResults() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Your Cognitive Profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              _profile,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const Text(
              'Profile Analysis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _rationale,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                clearHistory(userId!);
                Navigator.of(context).pop();
              },
              child: const Text("Return to Home"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionInterface() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          textWidget(_question),
          const SizedBox(height: 20),
          optionsWidget(),
          ElevatedButton(
            onPressed: () async {
              final answer = _answerController.text.trim();
              if (answer.isEmpty) return;

              // Submit the answer
              final result = await SubmitAnswer(userId!, answer);

              if (result['success']) {
                // Clear the text field
                _answerController.clear();

                // Fetch and display the next question
                await fetchQuestion();
              } else {
                // Handle error (optional: show a snackbar)
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['error'] ?? 'Submission failed'),
                  ),
                );
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Widget textWidget(String question) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget optionsWidget() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _answerController,
        decoration: const InputDecoration(
          hintText: "Enter your answer",
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
