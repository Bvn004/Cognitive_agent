import 'package:cogbot/api.dart';
import 'package:cogbot/db_collection.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'dart:async';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _answerController = TextEditingController();
  String _question = "Loading...";
  String? _classifiedCategory;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _assessmentCompleted = false;
  int _questionCount = 0;

  late final AnimationController _animationController;
  late final Animation<double> _fadeInAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    fetchQuestion();
  }

  Future<void> fetchQuestion() async {
    setState(() => _isLoading = true);
    try {
      String nextQ = await getnextquestion();

      if (nextQ.isEmpty || nextQ == "No more questions") {
        setState(() {
          _assessmentCompleted = true;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _question = nextQ;
        _isLoading = false;
        _questionCount++;
      });

      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _question = "Error loading question. Please try again.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> handleSubmit() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your answer')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isLoading = true;
    });

    try {
      final result = await SubmitAnswer(userId!, answer);
      _answerController.clear();

      if (result['success']) {
        if (result['category'] != null) {
          setState(() {
            _classifiedCategory = result['category'];
            _assessmentCompleted = true;
            _isSubmitting = false;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assessment saved successfully!'),
              backgroundColor: Colors.deepPurple,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          setState(() {
            _isSubmitting = false;
          });
          await fetchQuestion();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Submission failed')),
        );
        setState(() {
          _isSubmitting = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _getProgressIndicator() {
    if (_questionCount == 0) return "Getting started";
    if (_questionCount < 3) return "Initial assessment";
    if (_questionCount < 5) return "Mid assessment";
    if (_questionCount < 7) return "Detailed analysis";
    return "Final questions";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1), // Light background color
      appBar: AppBar(
        backgroundColor: Colors.white, // Light app bar background
        elevation: 1,
        title: const Text(
          'Cognitive Assessment',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Exit Assessment?', style: TextStyle(color: Colors.black)),
                content: const Text(
                  'Your progress will be cleared. Are you sure you want to exit?',
                  style: TextStyle(color: Colors.black54),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: () {
                      clearHistory(userId!);
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Exit'),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          if (!_assessmentCompleted && _questionCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade800.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Q$_questionCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && _questionCount == 0 
        ? _buildLoadingView() 
        : _buildMainContent(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
          const SizedBox(height: 24),
          Text(
            'Preparing your assessment...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _assessmentCompleted ? _buildCompletionView() : _buildQuestionView(),
    );
  }

  Widget _buildCompletionView() {
    return Container(
      key: const ValueKey('completion'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFffffff),
            Colors.deepPurple.shade800.withOpacity(0.4),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 24),
              const Text(
                'Assessment Completed',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Thank you for completing the cognitive assessment.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (_classifiedCategory != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade800.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.deepPurple.shade800.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Text('Your Classification:', style: TextStyle(fontSize: 18, color: Colors.black)),
                      const SizedBox(height: 12),
                      Text(
                        _classifiedCategory!,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home),
                label: const Text("Return to Home", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionView() {
    return Container(
      key: const ValueKey('questions'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF1F1F1), Color(0xFFffffff)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading && _questionCount > 0
            ? _buildLoadingView()
            : AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(opacity: _fadeInAnimation.value, child: child),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade800.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_getProgressIndicator(), style: TextStyle(color: Colors.deepPurple.shade800, fontSize: 12)),
                        ),
                        const Spacer(),
                        Text('Question $_questionCount', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.psychology, color: Colors.deepPurple, size: 32),
                            const SizedBox(height: 16),
                            Text(
                              _question,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _answerController,
                      style: const TextStyle(color: Colors.black),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Enter your answer...",
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : handleSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.deepPurple.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Submit Answer", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
