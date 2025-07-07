from flask import Flask, request, jsonify
from datetime import datetime
import json
import os
import re
import traceback
import logging
import glob
from crewai import Agent, Task, Crew, LLM
from dotenv import load_dotenv
from textwrap import dedent
import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    cred = credentials.Certificate(r"D:\python-projects\Cognitive_final_repo\cognitive-agent\cogbot-5f913-firebase-adminsdk-fbsvc-0d09449f5b.json")
    firebase_admin.initialize_app(cred) 

db = firestore.client()




# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("api_debug.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Load API key and initialize LLM
load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    logger.error("GROQ_API_KEY not set in environment variables")
    raise ValueError("GROQ_API_KEY not set")

groq_llm = LLM(model="groq/gemma2-9b-it", temperature=0.7, api_key=GROQ_API_KEY)

assessment_prompt = """
You are a cognitive assessment expert specializing in dynamic questioning. Your goal is to evaluate a user's cognitive traits through an adaptive interview process.

For each interaction, analyze the user's previous responses carefully and generate a highly personalized follow-up question that builds upon their specific answers. Your questions should probe deeper into the following cognitive dimensions:

1. Working memory - How they process and retain information temporarily
2. Attention control - How they focus and filter distractions
3. Learning style - Whether they prefer visual, auditory, or kinesthetic learning
4. Planning orientation - How they approach tasks and organize their thinking
5. Decision-making style - Whether they rely more on intuition or analytical thinking

IMPORTANT RESPONSE FORMAT RULES:
- When asked to generate a question (before the 5th response), provide ONLY the text of your question with no preamble, JSON wrapping, or analysis.
- Do not include any cognitive trait assessments with your questions.
- Do not use a JSON format for questions, just provide plain text questions.
- Make sure each question directly references content from their previous answer.
- Generic follow-up questions are not acceptable.

After the 5th question, provide a comprehensive cognitive profile in this JSON format:
{
  "working_memory": {"score": <int 1-10>, "level": "<low/moderate/high>", "explanation": "<brief evidence-based rationale>"},
  "attention_control": {"score": <int 1-10>, "level": "<low/moderate/high>", "explanation": "<brief evidence-based rationale>"},
  "learning_style": {"type": "<visual/auditory/kinesthetic>", "explanation": "<brief evidence-based rationale>"},
  "planning_orientation": {"score": <int 1-10>, "level": "<low/moderate/high>", "explanation": "<brief evidence-based rationale>"},
  "decision_making": {"type": "<intuitive/analytical>", "explanation": "<brief evidence-based rationale>"}
}

Only provide the final JSON after all 5 questions have been answered. Do not provide partial assessments earlier.
"""

assessment_agent = Agent(
    role="Adaptive Cognitive Assessment Specialist",
    goal="Generate highly personalized questions based on previous responses to assess cognitive traits accurately",
    backstory="You are an expert in cognitive psychology with years of experience developing adaptive testing algorithms. Your specialty is creating assessment paths that dynamically adjust based on individual responses to maximize insight with minimal questions.",
    allow_delegation=False,
    verbose=True,
    llm=groq_llm,
    prompt=assessment_prompt
)

classifier_agent = Agent(
    role="Classifier Agent",
    goal="Analyze cognitive traits and assign a cognitive profile",
    backstory="An expert cognitive scientist who classifies learners into profiles based on traits like working memory, attention, learning style, and decision making.",
    verbose=True,
    llm=groq_llm
)

app = Flask(__name__)

# Improved conversation storage structure
# Format: {user_id: {"conversations": [{"question": "...", "response": "..."}, ...], "timestamp": datetime}}
conversation_history = {}

def get_next_question(conversation_history_list):
    try:
        logger.info(f"Generating next question based on history: {conversation_history_list}")
        
        # Count how many answers we already have
        answer_count = sum(1 for msg in conversation_history_list if msg.startswith("A"))
        logger.debug(f"Answer count: {answer_count}")
        
        # Determine if we need to generate a final assessment
        if answer_count >= 5:
            task_description = f"""
            Based on this conversation history:
            {conversation_history_list}
            
            The user has completed all 5 questions. Provide ONLY the final cognitive assessment in this JSON format:
            {{
              "working_memory": {{"score": <int 1-10>, "level": "<low/moderate/high>", "explanation": "<brief evidence-based rationale>"}},
              "attention_control": {{"score": <int 1-10>, "level": "<low/moderate/high>", "explanation": "<brief evidence-based rationale>"}},
              "learning_style": {{"type": "<visual/auditory/kinesthetic>", "explanation": "<brief evidence-based rationale>"}},
              "planning_orientation": {{"score": <int 1-10>, "level": "<low/moderate/high>", "explanation": "<brief evidence-based rationale>"}},
              "decision_making": {{"type": "<intuitive/analytical>", "explanation": "<brief evidence-based rationale>"}}
            }}
            """
        else:
            task_description = f"""
            Based on this conversation history:
            {conversation_history_list}
            
            Generate the next most relevant and personalized question (question #{answer_count + 1}).
            
            IMPORTANT: Your response must ONLY contain the text of your next question, with no JSON wrapping,
            no cognitive trait analysis, no explanations or commentary.
            
            The question should directly reference content from their previous answer.
            """

        assessment_task = Task(
            description=task_description,
            agent=assessment_agent,
            expected_output="Either a plain text question OR a JSON assessment"
        )
        
        assessment_crew = Crew(
            agents=[assessment_agent],
            tasks=[assessment_task],
            verbose=True
        )

        logger.info("Starting crew kickoff to generate next question")
        result = assessment_crew.kickoff()
        
        # Improved result handling
        if hasattr(result, 'output'):
            result_str = result.output
        elif isinstance(result, dict):
            result_str = json.dumps(result)
        else:
            result_str = str(result)
        
        logger.info(f"Raw result: {result_str[:200]}...")
        
        # Clean and return the result
        result_str = result_str.strip()
        if result_str.startswith('"') and result_str.endswith('"'):
            result_str = result_str[1:-1]
        
        return result_str
        
    except Exception as e:
        logger.error(f"Error in get_next_question: {str(e)}")
        logger.error(traceback.format_exc())
        return "Error generating question. Please try again."

def classify_assessment(assessment_data):
    """
    Improved classification function with robust parsing and error handling
    """
    try:
        logger.info(f"Classifying assessment data: {assessment_data}")
        
        # Parse input data (handle both dict and string)
        if isinstance(assessment_data, str):
            try:
                assessment_json = json.loads(assessment_data)
            except json.JSONDecodeError:
                assessment_json = assessment_data
        else:
            assessment_json = assessment_data
        
        # Prepare the classification task
        task_description = dedent(f"""
            You are given a cognitive assessment result in JSON format.
            Analyze the scores and descriptions for:
            - Working memory
            - Attention control
            - Learning style
            - Planning orientation
            - Decision making

            Then classify the user into ONE of the following cognitive profiles:
            - Methodical Thinker
            - Adaptive Learner
            - Strategic Planner
            - Analytical Problem Solver
            - Experimental Explorer

            Provide a classification label and a short rationale.

            INPUT:
            {json.dumps(assessment_json, indent=2)}

            OUTPUT FORMAT:
            Classification: <Profile Name>
            Rationale: <Why this profile fits based on traits>
        """)
        
        classifier_task = Task(
            description=task_description,
            agent=classifier_agent,
            expected_output="Classification: <Profile Name>\nRationale: <Why this profile fits based on traits>"
        )
        
        classifier_crew = Crew(
            agents=[classifier_agent],
            tasks=[classifier_task],
            verbose=True
        )
        
        logger.info("Starting classifier crew kickoff")
        result = classifier_crew.kickoff()
        
        # Handle different result formats
        if hasattr(result, 'output'):
            output_text = result.output
        else:
            output_text = str(result)
        
        logger.info(f"Raw classification result: {output_text[:200]}...")
        
        # Parse the classification result
        classification_result = {"profile": "Unknown", "rationale": ""}
        
        # Try to extract from both possible formats
        if "Classification:" in output_text and "Rationale:" in output_text:
            parts = output_text.split("Rationale:")
            classification_result["profile"] = parts[0].replace("Classification:", "").strip()
            classification_result["rationale"] = parts[1].strip()
        else:
            # Fallback to regex parsing
            classification_match = re.search(r"Classification:\s*(.+?)(?:\n|$)", output_text)
            rationale_match = re.search(r"Rationale:\s*(.+?)(?:\Z|$)", output_text, re.DOTALL)
            
            if classification_match:
                classification_result["profile"] = classification_match.group(1).strip()
            if rationale_match:
                classification_result["rationale"] = rationale_match.group(1).strip()
        
        logger.info(f"Final parsed classification: {classification_result}")
        return classification_result
        
    except Exception as e:
        logger.error(f"Error in classify_assessment: {str(e)}")
        logger.error(traceback.format_exc())
        return {"profile": "Error", "rationale": f"Classification failed: {str(e)}"}

def parse_assessment_data(assessment_str):
    """Parse assessment data from string to dict"""
    try:
        logger.info(f"Parsing assessment data: {assessment_str[:100]}...")  # Log first 100 chars
        
        if isinstance(assessment_str, dict):
            return assessment_str
        
        # Try to parse as JSON
        try:
            return json.loads(assessment_str)
        except json.JSONDecodeError:
            logger.warning("Failed to parse assessment as JSON, trying alternative methods")
            pass
        
        # Try to extract JSON from text
        json_match = re.search(r"\{.*\}", assessment_str, re.DOTALL)
        if json_match:
            try:
                return json.loads(json_match.group(0))
            except json.JSONDecodeError:
                logger.warning("Failed to parse extracted JSON, trying field extraction")
                pass
        
        # Fallback: manual field extraction
        assessment_data = {}
        fields = ["working_memory", "attention_control", "learning_style", 
                 "planning_orientation", "decision_making"]
        
        for field in fields:
            pattern = f'"{field}"\\s*:\\s*(\\{{[^\\}}]*\\}}|"[^"]*")'
            match = re.search(pattern, assessment_str)
            if match:
                try:
                    assessment_data[field] = json.loads(match.group(1))
                except:
                    assessment_data[field] = match.group(1)
        
        return assessment_data if assessment_data else None
    
    except Exception as e:
        logger.error(f"Error parsing assessment data: {e}")
        logger.error(traceback.format_exc())
        return None

@app.route("/next-question", methods=["GET"])
def api_get_next_question():
    try:
        logger.info(f"Received next-question request: {request.args}")
        
        user_id = request.args.get("user_id")
        if not user_id:
            logger.warning("Missing user_id in request")
            return jsonify({"error": "Missing user_id"}), 400
        
        # Initialize user data if not exists
        if user_id not in conversation_history:
            logger.info(f"Initializing new conversation for user {user_id}")
            conversation_history[user_id] = {
                "conversations": [],
                "timestamp": datetime.now()
            }
        
        user_data = conversation_history[user_id]
        
        # Format conversation history for the AI prompt
        formatted_history = []
        for idx, conv in enumerate(user_data["conversations"]):
            if "question" in conv and conv["question"]:
                formatted_history.append(f"Q{idx+1}: {conv['question']}")
            if "response" in conv and conv["response"]:
                formatted_history.append(f"A{idx+1}: {conv['response']}")
        
        # For first question (no history), use a default starter question
        if not formatted_history:
            logger.info("No conversation history, using starter question")
            first_question = "How do you typically approach learning something completely new? Please describe your process and preferences."
            user_data["conversations"].append({
                "question": first_question,
                "response": None
            })
            return jsonify({"next_question": first_question})
        
        # Get next question or final assessment
        logger.info("Getting next question based on conversation history")
        result = get_next_question(formatted_history)
        logger.info(f"Got result: {result[:100]}...")  # Log first 100 chars
        
        # Check if this is the final assessment
        if result.strip().startswith("{") and any(term in result for term in ["working_memory", "attention_control", "learning_style"]):
            logger.info("Result appears to be final assessment")
            parsed = parse_assessment_data(result)
            if parsed:
                # Get classification for the assessment
                logger.info("Parsed assessment data, getting classification")
                classification = classify_assessment(parsed)
                
                # Store assessment and classification
                user_data["assessment"] = parsed
                user_data["classification"] = classification
                user_data["assessment_timestamp"] = datetime.now()
                
                response_data = {
                    "assessment": parsed,
                    "classification": classification,
                    "conversation_history": user_data["conversations"],
                    "is_final": True
                }
                logger.info(f"Returning final assessment: {json.dumps(response_data)[:100]}...")
                return jsonify(response_data)
            else:
                # Failed to parse, return raw result
                logger.warning("Failed to parse assessment data, returning raw result")
                user_data["assessment"] = result
                user_data["assessment_timestamp"] = datetime.now()
                return jsonify({
                    "assessment": result,
                    "conversation_history": user_data["conversations"],
                    "is_final": True
                })
        
        # Store the new question
        logger.info(f"Storing new question: {result}")
        user_data["conversations"].append({
            "question": result,
            "response": None
        })
        
        return jsonify({"next_question": result})
    
    except Exception as e:
        logger.error(f"Error in api_get_next_question: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/submit-response", methods=["POST"])
def submit_response():
    try:
        logger.info(f"Received submit-response request: {request.json}")
        
        data = request.json
        user_id = data.get("user_id")
        user_response = data.get("user_response")
        
        if not user_id or not user_response:
            logger.warning("Missing user_id or user_response in request")
            return jsonify({"error": "Missing 'user_id' or 'user_response'"}), 400
        
        if user_id not in conversation_history:
            logger.warning(f"No active session found for user_id: {user_id}")
            return jsonify({"error": "No active session for this user_id"}), 400
        
        user_data = conversation_history[user_id]
        
        # Find the last question without a response
        question_found = False
        for conversation in reversed(user_data["conversations"]):
            if conversation["response"] is None:
                conversation["response"] = user_response
                question_found = True
                break
        
        if not question_found:
            logger.warning(f"No pending question found for user {user_id}")
            return jsonify({
                "error": "No question awaiting response",
                "next_question_url": f"/next-question?user_id={user_id}"
            }), 400
        
        # Count completed Q&A pairs
        completed_qa_pairs = sum(
            1 for c in user_data["conversations"]
            if c.get("response") is not None and c["response"].strip() != ""
        )
        logger.info(f"User {user_id} has {completed_qa_pairs} completed Q&A pairs")
        
        return jsonify({
            "message": "Response submitted successfully",
            "completed_questions": completed_qa_pairs,
            "next_question_url": f"/next-question?user_id={user_id}"
        })
    
    except Exception as e:
        logger.error(f"Unexpected error in submit_response: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({
            "error": "Internal server error",
            "details": str(e),
            "support_url": "/health"
        }), 500

@app.route("/get-conversation-history", methods=["GET"])
def get_conversation_history():
    try:
        logger.info(f"Received get-conversation-history request: {request.args}")
        
        user_id = request.args.get("user_id")
        if not user_id:
            logger.warning("Missing user_id in request")
            return jsonify({"error": "Missing user_id"}), 400
        
        if user_id not in conversation_history:
            logger.warning(f"No history found for user_id: {user_id}")
            return jsonify({"error": "No history found for this user_id"}), 404
        
        user_data = conversation_history[user_id]
        
        response_data = {
            "user_id": user_id,
            "conversation_history": user_data["conversations"],
            "timestamp": user_data["timestamp"].isoformat(),
            "assessment": user_data.get("assessment"),
            "classification": user_data.get("classification"),
            "assessment_timestamp": user_data.get("assessment_timestamp", "").isoformat() if user_data.get("assessment_timestamp") else None
        }
        logger.info(f"Returning conversation history for user {user_id}")
        return jsonify(response_data)
    
    except Exception as e:
        logger.error(f"Error in get_conversation_history: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/profile", methods=["GET"])
def get_profile():
    try:
        logger.info(f"Received profile request: {request.args}")
        
        user_id = request.args.get("user_id")
        if not user_id:
            logger.warning("Missing user_id in request")
            return jsonify({"error": "Missing user_id"}), 400
        
        if user_id not in conversation_history:
            logger.warning(f"No history found for user_id: {user_id}")
            return jsonify({"error": "No history found for this user_id"}), 404
        
        user_data = conversation_history[user_id]
        
        if "classification" not in user_data or not user_data["classification"] or \
           user_data["classification"].get("profile") == "Unknown":
            logger.info(f"No classification found for user {user_id}, checking for assessment")
            if "assessment" in user_data and user_data["assessment"]:
                logger.info(f"Generating classification for user {user_id}")
                # We have an assessment but no classification, generate it now
                classification = classify_assessment(user_data["assessment"])
                user_data["classification"] = classification
                logger.info(f"Generated classification: {classification}")
                
                return jsonify({
                    "user_id": user_id,
                    "profile": classification.get("profile", "Unknown"),
                    "rationale": classification.get("rationale", ""),
                    "assessment_timestamp": user_data.get("assessment_timestamp", "").isoformat() if user_data.get("assessment_timestamp") else None
                })
            else:
                logger.warning(f"No assessment available for user {user_id}")
                return jsonify({"error": "No assessment available for profile classification"}), 400
        
        # Return existing classification
        logger.info(f"Returning existing classification for user {user_id}")
        return jsonify({
            "user_id": user_id,
            "profile": user_data["classification"].get("profile", "Unknown"),
            "rationale": user_data["classification"].get("rationale", ""),
            "assessment_timestamp": user_data.get("assessment_timestamp", "").isoformat() if user_data.get("assessment_timestamp") else None
        })
    
    except Exception as e:
        logger.error(f"Error in get_profile: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/save-assessment", methods=["GET"])
def save_assessment():
    try:
        logger.info(f"Received save-assessment request: {request.args}")
        
        user_id = request.args.get("user_id")
        if not user_id:
            logger.warning("Missing user_id in request")
            return jsonify({"error": "Missing user_id"}), 400
        
        if user_id not in conversation_history:
            logger.warning(f"No history found for user_id: {user_id}")
            return jsonify({"error": "No history found for this user_id"}), 404
        
        user_data = conversation_history[user_id]
        
        if "assessment" not in user_data or not user_data["assessment"]:
            logger.warning(f"No assessment available to save for user {user_id}")
            return jsonify({"error": "No assessment available to save"}), 400
        
        try:
            # Create output directories if they don't exist
            os.makedirs("assessments", exist_ok=True)
            os.makedirs("classifications", exist_ok=True)
            logger.info("Created output directories (if they didn't exist)")
            
            # Generate filenames with timestamp
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            assessment_filename = f"assessments/cognitive_assessment_{user_id}_{timestamp}.json"
            classification_filename = f"classifications/classification_{user_id}_{timestamp}.json"
            
            # Prepare assessment data
            assessment_data = {
                "user_id": user_id,
                "timestamp": datetime.now().isoformat(),
                "conversation": [
                    {"question": conv["question"], "response": conv["response"]} 
                    for conv in user_data["conversations"] if conv["response"] is not None
                ],
                "assessment": user_data["assessment"],
                "classification": user_data.get("classification", {})
            }
            
            # Save assessment file
            with open(assessment_filename, "w") as f:
                json.dump(assessment_data, f, indent=2)
            
            # Prepare and save classification data if available
            if "classification" in user_data:
                classification_data = {
                    "user_id": user_id,
                    "timestamp": datetime.now().isoformat(),
                    "profile": user_data["classification"].get("profile", "Unknown"),
                    "rationale": user_data["classification"].get("rationale", ""),
                    "source_assessment": assessment_filename
                }
                
                with open(classification_filename, "w") as f:
                    json.dump(classification_data, f, indent=2)
            
            logger.info(f"Assessment saved to: {assessment_filename}")
            logger.info(f"Classification saved to: {classification_filename}")
            
            return jsonify({
                "message": "Assessment and classification saved",
                "assessment_file": assessment_filename,
                "classification_file": classification_filename
            })
        except Exception as e:
            logger.error(f"Error saving assessment to file: {str(e)}")
            logger.error(traceback.format_exc())
            return jsonify({"error": f"Error saving assessment: {str(e)}"}), 500
    
    except Exception as e:
        logger.error(f"Error in save_assessment: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/health", methods=["GET"])
def health_check():
    """Simple health check endpoint to verify the API is working"""
    return jsonify({
        "status": "ok",
        "timestamp": datetime.now().isoformat(),
        "active_users": len(conversation_history)
    })
@app.route("/save-assessment-firebase", methods=["GET"])
def save_assessment_firebase():
    try:
        logger.info(f"Received save-assessment request: {request.args}")

        user_id = request.args.get("user_id")
        if not user_id:
            logger.warning("Missing user_id in request")
            return jsonify({"error": "Missing user_id"}), 400

        if user_id not in conversation_history:
            logger.warning(f"No history found for user_id: {user_id}")
            return jsonify({"error": "No history found for this user_id"}), 404

        user_data = conversation_history[user_id]

        if "assessment" not in user_data or not user_data["assessment"]:
            logger.warning(f"No assessment available to save for user {user_id}")
            return jsonify({"error": "No assessment available to save"}), 400

        timestamp = datetime.now().isoformat()

        # Build conversation list
        conversation_list = [
            {"question": c["question"], "response": c["response"]}
            for c in user_data["conversations"]
            if c.get("response") is not None
        ]

        # Get classification if present
        classification = user_data.get("classification", {})

        # Construct cognitive_profile to match Dart structure
        cognitive_profile = {
            "assessment": user_data["assessment"],
            "conversation_history": conversation_list,
            "classification": classification,
            "is_final": True
        }

        try:
            # Write cognitive_profile to Firestore under users/{user_id}
            user_ref = db.collection("users").document(user_id)
            user_ref.set({"cognitive_profile": cognitive_profile}, merge=True)

            logger.info(f"✅ Cognitive profile and classification stored for user {user_id}")
            return jsonify({"message": "Cognitive profile and classification saved to Firebase"}), 200

        except Exception as e:
            logger.error(f"❌ Firebase save error: {str(e)}")
            logger.error(traceback.format_exc())
            return jsonify({"error": f"Firebase error: {str(e)}"}), 500

    except Exception as e:
        logger.error(f"❌ Server error in save_assessment: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({"error": f"Server error: {str(e)}"}), 500
    
    
    
@app.route("/clear-history",methods=["GET"])
def clear_history():
    try:
        logger.info(f"Received next-question request: {request.args}")
        
        user_id = request.args.get("user_id")
        if not user_id:
            logger.warning("Missing user_id in request")
            return jsonify({"error": "Missing user_id"}), 400
        
        if user_id not in conversation_history:
            logger.warning(f"No history found for user_id: {user_id}")
            return jsonify({"error": "No history found for this user_id"}), 404
        else:
            # Clear the conversation history for the user
            del conversation_history[user_id]
            logger.info(f"Cleared conversation history for user {user_id}")
            return jsonify({"message": "Conversation history cleared successfully"}), 200
    except Exception as e:
        logger.error(f"Error in clear_history: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({"error": f"Server error: {str(e)}"}), 500
        

if __name__ == "__main__":
    # This will make the server accessible from any network interface
    logger.info("Starting Flask server on 0.0.0.0:5002")
    app.run(host="0.0.0.0", port=5002, debug=True)