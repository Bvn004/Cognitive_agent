import os
import json
import uuid
from datetime import datetime
from glob import glob

import firebase_admin
from firebase_admin import credentials, firestore

from flask import Flask, request, jsonify, session
from dotenv import load_dotenv

from crewai import Agent, Task, Crew
from langchain_groq import ChatGroq



global_concept=''
# --- Firebase Setup ---
def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    # Ensure the path is correct and exists
    cred_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), 
        "cogbot-5f913-firebase-adminsdk-fbsvc-0d09449f5b.json"
    )
    
    # Check if the credentials file exists
    if not os.path.exists(cred_path):
        raise FileNotFoundError(f"Firebase credentials file not found at {cred_path}")
    
    # Initialize Firebase only if not already initialized
    if not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    
    return firebase_admin.firestore.client()

# --- Load Environment Variables ---
load_dotenv()

# --- Flask App Setup ---
app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "default_secret_key")

# --- Cognitive Profiles ---
COGNITIVE_PROFILES = {
    "Analytical Problem Solver": {
        "name": "The Analytical Problem Solver",
        "description": "You excel at breaking down complex problems through logical analysis and systematic reasoning.",
        "learning_recommendations": [
            "Tackle logic-based puzzles and case studies.",
            "Use flowcharts and diagrams to visualize concepts.",
            "Start with fundamental principles before applications.",
            "Engage with critical thinking material like debates and research."
        ]
    },
    "Strategic Planner": {
        "name": "The Strategic Planner",
        "description": "You excel at foresight and step-by-step execution, thriving in structured environments.",
        "learning_recommendations": [
            "Create learning roadmaps and goals.",
            "Use Kanban boards or Gantt charts.",
            "Practice with simulations and decision-making tasks.",
            "Tackle real-world scenarios requiring planning."
        ]
    },
    "Adaptive Learner": {
        "name": "The Adaptive Learner",
        "description": "You thrive on repetition, refinement, and attention to detail.",
        "learning_recommendations": [
            "Use Cornell or Zettelkasten note-taking.",
            "Practice debugging and proofreading.",
            "Regularly review and refine material.",
            "Work on precision-demanding projects."
        ]
    },
    "Experimental Explorer": {
        "name": "The Experimental Explorer",
        "description": "You learn best by experimenting and applying knowledge hands-on.",
        "learning_recommendations": [
            "Do real-world challenges and sandbox testing.",
            "Join hackathons or coding competitions.",
            "Collaborate on group projects.",
            "Experiment with tools and strategies."
        ]
    },
    "Methodical Thinker": {
        "name": "The Methodical Thinker",
        "description": "You prefer systematic, structured learning environments.",
        "learning_recommendations": [
            "Follow a structured curriculum.",
            "Use checklists and progress trackers.",
            "Take regular review breaks.",
            "Use visual aids and explore multiple resources."
        ]
    }
}

# --- Utility Functions ---
def get_latest_classification_file(directory="classifications"):
    """Find the most recently modified classification file"""
    try:
        json_files = glob(os.path.join(directory, "*.json"))
        return max(json_files, key=os.path.getmtime) if json_files else None
    except Exception as e:
        print(f"Error locating latest classification: {e}")
        return None

def load_profile_type(filepath):
    """Load profile type from a classification file"""
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
            return data.get("profile", None)
    except Exception as e:
        print(f"Error loading classification: {e}")
        return None

# --- Learn Route ---
@app.route('/learn', methods=['POST'])
def learn_concept():
    try:
        # Initialize Firebase
        db = initialize_firebase()

        # Parse input data
        data = request.json
        concept = data.get('concept')
        difficulty = data.get('difficulty', 'intermediate')
        format_pref = data.get('format', 'text')
        user_id = data.get('user_id')  # Expecting user_id from frontend

        if not concept or not user_id:
            return jsonify({"error": "Concept or user_id not provided"}), 400

        # Create chat session ID using Firestore auto-generated ID
        chat_ref = db.collection('users').document(user_id).collection('chats').document()
        chat_id = chat_ref.id  # Firestore-generated ID
        session['user_id'] = user_id
        session['chat_id'] = chat_id

        # Fetch cognitive profile from Firestore
        user_doc = db.collection("users").document(user_id).get()
        if not user_doc.exists:
            return jsonify({"error": f"No user profile found for user_id: {user_id}"}), 404

        profile_data = user_doc.to_dict().get("cognitive_profile", {}).get("classification", {})
        profile_type = profile_data.get("profile", "General Learner")
        rationale = profile_data.get("rationale", "No rationale provided.")
        global_concept = concept

        # LLM Setup
        groq_api_key = os.getenv("GROQ_API_KEY")
        if not groq_api_key:
            return jsonify({"error": "Groq API key not found"}), 500

        llm = ChatGroq(api_key=groq_api_key, model="groq/gemma2-9b-it")

        # Agent
        learning_agent = Agent(
            role="Cognitive Learning Expert",
            goal="Generate a personalized learning explanation based on cognitive traits",
            backstory=(f"The user has a cognitive profile of '{profile_type}'.\n"
                       f"Rationale: {rationale}\n"
                       "You must explain concepts in a way that aligns with this profile's learning preferences and cognitive strengths."),
            verbose=True,
            allow_delegation=False,
            llm=llm
        )

        # Format Guidance
        format_guidance = {
            "text": "Use clear, structured text with examples.",
            "visual": "Use diagrams, flowcharts, or visual metaphors (ASCII if needed).",
            "code example": "Include code snippets with explanation.",
            "step-by-step": "Break explanation into clear, numbered steps.",
            "real-world": "Include real-world use cases or examples."
        }
        format_instruction = format_guidance.get(format_pref.lower(), "Use clear and structured explanation.")

        # Task
        task = Task(
            description=(f"Explain the concept '{concept}' at a {difficulty} level for a user with the '{profile_type}' profile. "
                          f"The user prefers {format_pref} format. {format_instruction} "
                          f"Ensure the explanation aligns with the user's cognitive learning preferences."),
            expected_output="A personalized explanation suitable to the user's cognitive style, preferred format, and difficulty level.",
            agent=learning_agent
        )

        # Run Crew
        crew = Crew(agents=[learning_agent], tasks=[task], verbose=True)
        result = str(crew.kickoff())

        # Store in session
        session['context'] = result

        # Save to Firestore under chat history
        chat_ref.set({
            "messages": [
                {"role": "system", "content": f"Profile: {profile_type}"},
                {"role": "user", "content": f"Learn about: {concept}"},
                {"role": "ai", "content": result}
            ],
            "updated_at": datetime.utcnow(),
            "title": concept,
        })

        return jsonify({
            "chat_id": chat_id,  # Returning Firestore-generated chat ID
            "profile_type": profile_type,
            "rationale": rationale,
            "concept": concept,
            "difficulty": difficulty,
            "format": format_pref,
            "output": result
        })

    except Exception as e:
        print(f"Error in learn_concept: {str(e)}")
        return jsonify({"error": f"An unexpected error occurred: {str(e)}"}), 500



# --- Chat Route ---
@app.route('/chat', methods=['POST'])
def chat():
    try:
        # Initialize Firebase
        db = initialize_firebase()

        # Parse input data
        data = request.json
        user_message = data.get('message')
        user_id = data.get('user_id')
        chat_id = data.get('chat_id')

        if not user_message or not user_id or not chat_id:
            return jsonify({"error": "Missing message, user_id, or chat_id"}), 400

        # Retrieve chat history
        chat_ref = db.collection("users").document(user_id).collection("chats").document(chat_id)
        chat_doc = chat_ref.get()
        if not chat_doc.exists:
            return jsonify({"error": "Chat history not found"}), 404

        conversation_context = ""
        for msg in chat_doc.to_dict().get("messages", []):
            role = msg["role"].capitalize()
            conversation_context += f"\n{role}: {msg['content']}"
        conversation_context += f"\nUser: {user_message}\nAI:"

        # LLM Setup
        groq_api_key = os.getenv("GROQ_API_KEY")
        if not groq_api_key:
            return jsonify({"error": "Groq API key not found"}), 500

        llm = ChatGroq(api_key=groq_api_key, model="groq/gemma2-9b-it")
        chat_agent = Agent(
            role="Cognitive Learning Expert",
            goal="Answer follow-up questions based on previous context",
            backstory=conversation_context,
            verbose=True,
            allow_delegation=False,
            llm=llm
        )

        task = Task(
            description=conversation_context,
            expected_output="A relevant answer based on the user's previous query and profile context.",
            agent=chat_agent
        )

        crew = Crew(agents=[chat_agent], tasks=[task], verbose=True)
        result = str(crew.kickoff())

        # Update Firestore
        chat_ref.update({
            "messages": firestore.ArrayUnion([
                {"role": "user", "content": user_message},
                {"role": "ai", "content": result}
            ]),
            "updated_at": datetime.utcnow(),
            
        })

        return jsonify({"response": result})

    except Exception as e:
        print(f"Error in chat: {str(e)}")
        return jsonify({"error": f"An unexpected error occurred: {str(e)}"}), 500

# --- Run ---
if __name__ == '__main__':
    app.run(debug=True)