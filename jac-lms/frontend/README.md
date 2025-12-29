# Jac LMS Frontend

This repository contains the frontend application for the Jac Learning Management System (LMS) — an interactive, AI-powered learning platform inspired by Scrimba-style learning experiences.

The frontend provides a modern learning workspace that combines lessons, live code editing, quizzes, and AI feedback, all powered by a Jac graph backend.

## Features
### Interactive Learning Workspace: 
    - Split-pane layout for lessons, code editor, and feedback
    - Smooth lesson transitions and state-driven UI updates
    - Responsive design for desktop and tablet screens
### Live Code Editing: 
    - Monaco Editor integration for real-time hands on coding
    - Syntax highlighting for Jac-style code
    - Starter code injected per lesson
### AI-Driven Feedback: 
    - Learner code is evaluated by an LLM
    - Immediate feedback with conceptual scoring
    - Progress updates unlock new lessons dynamically
### Adaptive Learning Flow: 
    - Lessons unlock based on mastery, not completion
    - Quiz difficulty adapts to learner performance
    - Skill progression visualized per topic

### Learning Flow (Frontend)
```jac
  Load Lesson
      ↓
  Generate Quiz
      ↓
  Learner Writes Code
      ↓
  evaluate_answer
      ↓
  progress_tracker
      ↓
  unlock_next_lesson
      ↓
  UI Updates
```

All backend interactions go through spawned Jac walkers.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/jonnfrancis/jaseci.git
   ```
2. Navigate to the backend directory:
   ```bash
   cd jaseci/jac-lms/frontend
   ```
3. Install the required dependencies:
   ```bash
   npm install
   ```
4. Start the Jac server:
   ```bash
   npm run dev
   ```

## Future Enhancements
- Animated lesson transitions
- Skill map visualization
- Multi-lesson navigation
- User authentication UI
- Progress persistence across sessions


## Contributing
Contributions are welcome! Feel free to open issues or submit pull requests to improve the backend functionality.

## License
This project is licensed under the MIT License.