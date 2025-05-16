import 'package:cogbot/assessment_screen.dart';
import 'package:cogbot/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cogbot/signup.dart';

String? userId; // Global variable to store UID

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    Future<void> loginUser() async {
      try {
        // Try to sign in the user
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: emailController.text,
              password: passwordController.text,
            );

        if (userCredential.user != null) {
          // Store UID in the variable after successful login
          userId = userCredential.user?.uid;
          print("Logged in successfully with UID: $userId");

          // Now, you can navigate to the next screen or perform any action
          // For example, navigate to the home screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (context) =>
                      Homepage(), // Replace with your home screen widget
            ),
          );
        }
      } catch (e) {
        print("Login failed: $e");
        // You can show an error message here if needed
      }
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Email",
                hintText: "Enter your email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: "Password",
                hintText: "Enter your password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () {
                loginUser();
              },
              child: Text("Login"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => SignupScreen()));
              },
              child: const Text("Don't have an account? Sign up"),
            ),
          ],
        ),
      ),
    );
  }
}
