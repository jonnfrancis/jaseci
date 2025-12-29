# Jac LMS – AI-Driven Learning Platform

Jac LMS is an AI-first, graph-native learning management system built with Jac on the backend and a modern React + Vite frontend.
It delivers an adaptive, code-centric learning experience inspired by platforms like Scrimba, where learners progress based on mastery, not time.

The system models learning as a knowledge graph and uses LLMs as first-class primitives to generate quizzes, evaluate learner code, and unlock content dynamically.

<img src="https://res.cloudinary.com/dxvygt0ay/image/upload/v1767031372/bandicam_2025-12-29_21-02-06-270_gwj5qu.jpg" align="center" style="width: 100%" />

```bash
jac-lms/
├── backend/
│   ├── server.jac            # Jac graph schema + walkers
│   ├── requirements.txt
│   └── README.md             # Backend documentation
│
├── frontend/
│   ├── src/
│   ├── public/
│   ├── README.md             # Frontend documentation
│   └── package.json
│
└── README.md  
```

<img src="https://res.cloudinary.com/dxvygt0ay/image/upload/v1767031372/bandicam_2025-12-29_14-27-05-081_tapfph.jpg" align="center" style="width: 100%" />

## Core Concepts
### Graph-Native Learning
    - Topics, lessons, quizzes, and users are nodes
    - Prerequisites, mastery, and completion are edges
    - Learning state lives in the graph, not tables

### AI-First Execution
    - Quizzes are generated dynamically using LLMs
    - Learner code is evaluated conceptually by AI
    - Feedback is immediate and personalized

### Mastery-Based Progression
    - Lessons unlock based on mastery thresholds
    - No fixed lesson order or linear progression
    - Learners advance when they understand concepts





<img src="https://res.cloudinary.com/dxvygt0ay/image/upload/v1767031370/bandicam_2025-12-29_14-27-13-568_fyi6gw.jpg" align="center" style="width: 100%" />