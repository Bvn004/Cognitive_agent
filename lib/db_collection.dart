
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> storeCognitiveProfile(String userId) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final cognitiveProfile = {
    "assessment": {
      "attention_control": {
        "explanation":
            "While the user prioritizes time-sensitive subtasks, they also express awareness of potential negative impacts on overall quality, indicating moderate attentional control.",
        "level": "moderate",
        "score": 6
      },
      "decision_making": {
        "explanation":
            "The user's approach to problem-solving involves a step-by-step analysis and consideration of constraints, suggesting an analytical decision-making style.",
        "type": "analytical"
      },
      "learning_style": {
        "explanation":
            "The user's preference for breaking down tasks and focusing on concrete steps suggests a kinesthetic learning style.",
        "type": "kinesthetic"
      },
      "planning_orientation": {
        "explanation":
            "The user's explicit emphasis on planning, scheduling, and prioritizing subtasks indicates a strong planning orientation.",
        "level": "high",
        "score": 8
      },
      "working_memory": {
        "explanation":
            "The user demonstrates an ability to break down complex tasks and maintain a focus on multiple subtasks, suggesting moderate working memory capacity.",
        "level": "moderate",
        "score": 7
      }
    },
    "conversation_history": [
      {
        "question":
            "How do you typically approach learning something completely new? Please describe your process and preferences.",
        "response": "i break it down to smaller tasks"
      },
      {
        "question":
            "Can you give an example of a time when breaking down a complex task into smaller ones helped you succeed, and what specific challenges did you encounter along the way?",
        "response":
            "I applied my knowledge of data structures to optimize a coding problem, using a step-by-step approach to choose the most efficient algorithm based on the problem's constraints"
      },
      {
        "question":
            "In breaking down complex tasks, do you find yourself prioritizing certain aspects or criteria, and if so, what are they?",
        "response": "i proritize time to complete a certain sub task"
      },
      {
        "question":
            "Can you describe a situation where prioritizing a specific subtask's timeframe led to a positive or negative outcome, and what factors influenced your decision?",
        "response":
            "i finish the task that reuires more time first so it has a positive impact"
      },
      {
        "question":
            "What strategies do you use to ensure that completing a time-sensitive subtask doesn't negatively impact the overall quality or effectiveness of the final project?",
        "response":
            "i try to plan ahead and schedule my task so it doesnot affect me negatively"
      }
    ],
    "is_final": true
  };

  try {
    await firestore
        .collection("users")
        .doc(userId)
        .set({"cognitive_profile": cognitiveProfile}, SetOptions(merge: true));

    print("✅ Cognitive profile stored for user $userId");
  } catch (e) {
    print("❌ Error storing cognitive profile: $e");
  }
}
