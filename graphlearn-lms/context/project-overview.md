# GraphLearn LMS

## Overview

GRAPHLEARN LMS is an AI-powered adaptive learning platform built with JacLang and Jaseci.

The platform enables learners to master programming languages through personalized learning paths, dynamically generated lessons, hands-on coding challenges, graph-based mastery tracking, and AI-driven tutoring.

Unlike traditional learning management systems that provide fixed course structures, JAC LMS continuously adapts to each learner's knowledge level. Every learner receives a personalized roadmap generated from an initial mastery assessment, and future lessons, challenges, and recommendations are generated dynamically based on performance and mastery progression.

The platform uses Object Spatial Programming (OSP) graphs to model learner knowledge, topic dependencies, prerequisite relationships, mastery scores, and learning recommendations. byLLM agents generate educational content, evaluate coding submissions, provide feedback, and determine optimal learning progression.

The goal is to create a production-ready self-paced learning environment capable of guiding learners from beginner to mastery across multiple programming languages.

---

## Goals

1. Provide personalized learning journeys for every learner.
2. Support multiple programming languages and technology tracks.
3. Generate adaptive roadmaps based on learner assessments.
4. Dynamically generate lessons and coding challenges.
5. Evaluate learner submissions using AI.
6. Track mastery using OSP graph relationships.
7. Visualize learner progress through skill maps.
8. Unlock content through demonstrated mastery rather than course completion.
9. Deliver AI-powered tutoring and learning recommendations.
10. Create a scalable platform capable of supporting thousands of learners.

---

## Core User Flow

### 1. Landing Experience

* User visits the platform.
* User learns about available learning paths.
* User signs up or logs in.

### 2. Learning Path Selection

* User selects a programming language track.
* Examples:

  * Jaseci
  * Python
  * JavaScript
  * TypeScript
  * Java

### 3. Initial Mastery Assessment

* User completes an interactive assessment.
* Assessment measures:

  * Experience level
  * Existing knowledge
  * Confidence levels
  * Practical coding ability

### 4. Personalized Roadmap Generation

* AI analyzes assessment results.
* OSP graph initializes learner knowledge state.
* Personalized roadmap is generated.
* Roadmap is organized into:

  * Weeks
  * Topics
  * Lessons
  * Mastery milestones

### 5. Dashboard

The dashboard displays:

* Current learning path
* Current week
* Next lesson
* Mastery percentage
* Skill graph
* Learning streak
* Completed lessons
* Recommended actions

### 6. Dynamic Lesson Generation

When a learner opens a lesson:

* AI generates lesson content on demand.
* AI generates coding exercises.
* AI generates mastery criteria.
* Generated content is stored in the database.

### 7. Interactive Learning Workspace

The workspace consists of:

#### Lesson Panel

* Lesson content
* Examples
* Explanations

#### Coding Workspace

* Monaco Editor
* Execution environment
* Starter templates

#### Challenge Panel

* Coding challenge
* AI feedback
* Mastery score

### 8. Mastery Evaluation

After submission:

* AI evaluates the solution.
* Mastery score is calculated.
* Feedback is generated.
* Weak concepts are identified.

### 9. Adaptive Progression

If mastery threshold is reached:

* Lesson marked complete.
* Topic mastery updated.
* Next lesson unlocked.

If mastery threshold is not reached:

* New challenge generated.
* Additional practice recommended.
* Remediation content suggested.

### 10. Completion

After all roadmap milestones are completed:

* Learning path marked complete.
* Mastery report generated.
* Learner returns to dashboard.
* Future certifications can be added.

---

## Major Features

### AI Roadmap Generation

Generate personalized learning plans based on learner assessments.

### Dynamic Lesson Generation

Generate lessons only when needed to reduce generation cost and latency.

### Dynamic Coding Challenges

Generate practical coding exercises aligned with learner mastery.

### AI Evaluation

Evaluate coding submissions and provide detailed feedback.

### Adaptive Difficulty

Continuously adjust challenge complexity based on performance.

### Knowledge Graph

Track mastery through an OSP graph rather than static completion states.

### Skill Map

Visual graph visualization of strengths and weaknesses.

### Learning Analytics

Track:

* Progress
* Streaks
* Mastery trends
* Weak concepts
* Time spent

### AI Tutor

Provide:

* Explanations
* Hints
* Learning recommendations
* Revision suggestions

---
### Out Of Scope

- Billing and subscription systems
- Enterprise permission tiers beyond owner and collaborator
- Versioned spec history and review workflows
- Production object storage migration
- Mobile-native applications

## Success Criteria

1. Users can generate personalized learning paths.
2. Lessons are generated dynamically and stored.
3. Coding challenges are generated dynamically.
4. AI can evaluate submissions and provide feedback.
5. OSP graphs accurately track learner mastery.
6. Roadmaps adapt based on learner performance.
7. Skill maps visualize progression clearly.
8. Learners can progress from beginner to mastery without instructor intervention.
9. Platform supports multiple programming language tracks.
10. All learner progress persists across sessions.