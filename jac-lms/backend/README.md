# Jac LMS Backend

This repository contains the backend for an AI-driven Learning Management System (LMS) built with Jac, a graph-native, AI-first programming language designed for Object-Spatial Programming (OSP).

The backend models learning content as a knowledge graph of users, topics, lessons, quizzes, and mastery edges. It powers adaptive learning flows such as lesson unlocking, quiz generation, mastery tracking, and skill visualization.

## Key Capabilities
### Graph-Based Learning Model: 
    - Topics, lessons, and quizzes are represented as nodes
    - Learning dependencies are enforced using PREREQUISITE edges
    - User progress is tracked via MASTERY and COMPLETED edges
### Adaptive Learning: 
    - Lessons unlock dynamically based on mastery thresholds
    - Quiz difficulty adapts to learner mastery
    - Supports multi-topic progression paths
### AI-Powered Assessments: 
    - Quizzes are generated dynamically using byLLM
    - Learner code submissions are evaluated by an LLM
    - Conceptual understanding is scored (0.0 – 1.0) with feedback
### Progress Tracking & Skill Mapping: 
    - Progress Tracking & Skill Mapping
    - Generates a personalized skill map snapshot for frontend visualization


## Core Walkers
1. **initialize_learning_graph**: 
    - Creates core topics and lessons
    - Establishes prerequisite relationships
    - Initializes mastery edges for a given user
2. **generate_quiz**: 
    - Generates a quiz for a topic
    - Difficulty is derived from learner mastery
    - Uses byLLM to produce structured JSON output
3. **evaluate_answer**: 
    - Evaluates learner code submissions
    - Returns a conceptual score and actionable feedback
4. **progress_tracker**: 
    - Updates user mastery based on quiz performance
    - Tracks lesson completion
    - Maintains attempts and timestamps
5. **unlock_next_lesson**: 
    - Determines which lessons are unlocked for a user
    - Enforces prerequisite mastery thresholds
    - Returns only lessons the learner is eligible to access
4. **get_skill_map**: 
    - Returns a snapshot of all topics
    - Includes mastery score, prerequisites, and unlock status
    - Designed for frontend dashboards and progress UIs

## Learning Flow
    - Learner submits code
    - AI evaluates conceptual understanding
    - Mastery score is updated
    - New lessons unlock if thresholds are met
    - Fronend updates lesson and progress UI


## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/jonnfrancis/jaseci.git
   ```
2. Navigate to the backend directory:
   ```bash
   cd jaseci/jac-lms/backend
   ```
3. Install the required dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Start the Jac server:
   ```bash
   jac serve main.jac
   ```

## Example Usage
1. Start the backend server using the command above.
2. Use the Vite React frontend to interact with the backend:
   - Create an account.
   - Start learning.

## File Structure
- `server.jac`: The main Jac file containing the Learning logic.
- `requirements.txt`: python dependencies

## Contributing
Contributions are welcome! Feel free to open issues or submit pull requests to improve the backend functionality.

## License
This project is licensed under the MIT License.