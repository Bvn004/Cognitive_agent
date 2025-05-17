import 'package:flutter/material.dart';
import 'landing_page.dart'; // Add this new file

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller and the rotation animation
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(); // Repeating the animation indefinitely

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * 3.14159).animate(_controller); // Rotate 360 degrees

    // Navigate to LandingPage after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LandingPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Clean up the controller when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo with rotation effect
            RotationTransition(
              turns: _rotationAnimation,
              child: const Icon(
                Icons.psychology_rounded,
                size: 100,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            // Text with gradient and animation
            GradientText(
              'CogBot',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.purpleAccent],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your AI Learning Companion',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

// Gradient text widget (add this class)
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    required this.gradient,
    this.style,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}
