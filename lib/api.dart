import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cogbot/login.dart';
import 'package:http/http.dart' as http;

Future<String> getnextquestion() async {
  final uri = Uri.parse('http://10.0.2.2:5002/next-question?user_id=$userId');

  try {
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data.containsKey('assessment')) {
        // Assessment received — save it
        await saveAssessmentToFirebase(userId!);

        return 'Assessment saved successfully';
      }

      print(response.body);
      print(data['next_question']);
      return data['next_question'] ?? 'No question found.';
    } else {
      return 'Error: ${response.statusCode}';
    }
  } catch (e) {
    return 'Exception: $e';
  }
}

Future<String> clearHistory(String userId) async {
  final uri = Uri.parse('http://10.0.2.2:5002/clear-history?user_id=$userId');

  try {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      print(response.body);
      return 'History cleared successfully';
    } else {
      print('Error: ${response.body}');
      return 'Error: ${response.body}';
    }
  } catch (e) {
    return 'Exception: $e';
  }
}

Future<dynamic> SubmitAnswer(String user_id, String answer) async {
  final uri = Uri.parse("http://10.0.2.2:5002/submit-response");

  try {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({"user_id": user_id, "user_response": answer}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': 'Error: ${response.statusCode}'};
    }
  } catch (e) {
    return {'success': false, 'error': 'Exception: $e'};
  }
}

Future<void> saveAssessmentToFirebase(String userId) async {
  final uri = Uri.parse(
    "http://10.0.2.2:5002/save-assessment-firebase?user_id=$userId",
  );

  try {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      print("Assessment saved successfully");
    } else {
      print("Error saving assessment: ${response.statusCode}");
    }
  } catch (e) {
    print("Exception saving assessment: $e");
  }
}

Future<bool> hasTakenAssessment(String userId) async {
  try {
    // Get reference to the user's document
    final DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    // Check if the document exists and has cognitive_profile with assessment data
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>?;

      if (userData != null &&
          userData.containsKey('cognitive_profile') &&
          userData['cognitive_profile'] != null &&
          userData['cognitive_profile'].containsKey('assessment')) {
        // User has assessment data
        return true;
      }
    }

    // No assessment data found
    return false;
  } catch (e) {
    print('Error checking assessment status: $e');
    // Return false on error to be safe
    return false;
  }
}

Future<Map<String, dynamic>> topicToLearn({
  required String userId,
  required String concept,
  String difficulty = 'intermediate',
  String format = 'text',
}) async {
  // API endpoint URL - replace with your actual API URL
  final String apiUrl = 'http://10.0.2.2:5000/learn';

  // Prepare request body
  final Map<String, dynamic> requestBody = {
    'user_id': userId,
    'concept': concept,
    'difficulty': difficulty,
    'format': format,
  };

  try {
    // Make the POST request
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    // Check if the request was successful
    if (response.statusCode == 200) {
      // Parse the response

      print(response.body);
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return responseData;
    } else {
      // Handle error responses
      final Map<String, dynamic> errorData = jsonDecode(response.body);
      throw Exception('Failed to learn topic: ${errorData['error']}');
    }
  } catch (e) {
    // Handle exceptions
    throw Exception('Error connecting to server: $e');
  }
}

Future<Map<String, dynamic>> sendFollowUpQuestion({
  required String userId,
  required String chatId,
  required String message,
}) async {
  // API endpoint URL - replace with your actual API URL
  final String apiUrl = 'http://10.0.2.2:5000/chat';

  // Prepare request body
  final Map<String, dynamic> requestBody = {
    'user_id': userId,
    'chat_id': chatId,
    'message': message,
  };

  try {
    // Make the POST request
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    // Check if the request was successful
    if (response.statusCode == 200) {
      // Parse the response
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return responseData;
    } else {
      // Handle error responses
      final Map<String, dynamic> errorData = jsonDecode(response.body);
      throw Exception(
        'Failed to send follow-up question: ${errorData['error']}',
      );
    }
  } catch (e) {
    // Handle exceptions
    throw Exception('Error connecting to server: $e');
  }
}
