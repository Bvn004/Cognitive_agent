import 'package:cogbot/api.dart';
import 'package:cogbot/db_collection.dart';
import 'package:flutter/material.dart';
import 'login.dart';

class AssessmentScreen extends StatefulWidget {
  AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  TextEditingController _answercontroller = TextEditingController();
  String _question = "Loading..."; // state variable to hold the question

  @override
  void initState() {
    super.initState();
    fetchQuestion(); // fetch the question on init
  }

  Future<void> fetchQuestion() async {
    String nextQ = await getnextquestion();
    setState(() {
      _question = nextQ;
    });
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            textwidget(_question),
            const SizedBox(height: 20),
            options(),
            ElevatedButton(
              onPressed: () async {
                final answer = _answercontroller.text.trim();
                if (answer.isEmpty) return;

                // Submit the answer
                final result = await SubmitAnswer(userId!, answer);

                if (result['success']) {
                  // Clear the text field
                  _answercontroller.clear();

                  // Fetch and display the next question
                  await fetchQuestion();
                } else {
                  // Handle error (optional: show a snackbar)
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
      ),
    );
  }

  Widget textwidget(String question) {
    return Text(
      question,
      style: const TextStyle(fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }

  Widget options() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _answercontroller,
        decoration: const InputDecoration(
          hintText: "Enter your answer",
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
