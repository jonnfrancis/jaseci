### Here are the previous walkers implemented for a similar LMS.

walker progress_tracker {

    has user_id: string;
    has lesson_id: string;
    has quiz_id: string = "";
    has score: float = 0.0;
    has completed_at: str = "";

    can submit with `root entry { 
        if self.user_id == None {
            report {"error": "User not specified"};
            disengage;
        }
        user = [root --> (`?User)](?user_id == self.user_id)[0];

        # Determine the topic related either by Lesson or Quiz
        topic = None;
        if self.lesson_id != None {
            lesson_nodes = [root --> (`?Lesson)](?lesson_id == self.lesson_id);
            lesson_node = lesson_nodes[0];
            topics = [lesson_node <-:HAS_LESSON:<- (`?Topic)];
            print("Found topics for lesson:", len(topics));
            
            if len(topics) > 0 {
                topic = topics[0];
            } else {
                print("No related Topic found for Lesson:", lesson_node.title);
                report {"error": "No related Topic found for Lesson"};
                disengage;
            }
        }

        if topic == None {
            report {"error": "Related Topic not found for submission"};
            disengage;
        }
        print("Related topic identified:", topic.title);

        

        # Find or create the MASTERY edge from User to Topic
        mastery_edges = [edge user ->:MASTERY:-> topic];
        print(mastery_edges);
        mastery = None;
        if len(mastery_edges) == 0 {
            mastery = user +>:MASTERY(score=0.0, attempts=0, last_updated="" ):+> topic;
            edges = [edge user ->:MASTERY:-> topic];
            print("User mastery edges with score 0.0:", type(edges));
        } else {
            mastery = mastery_edges[0];
        }
        print("Mastery edge found/created.", mastery);

        # Update mastery score based on performance - simple weighted average
        # Ensure proper type handling for score and attempts
        old_score = float(mastery.score);
        old_attempts = int(mastery.attempts);
        new_attempts = old_attempts + 1;
        new_score = (old_score * old_attempts + float(self.score)) / new_attempts;
        print("Mastery score updated from", old_score, "to", new_score);

        # Update the mastery edge properties
        mastery.score = new_score;
        mastery.attempts = new_attempts;
        mastery.last_updated = self.completed_at;
        print("Mastery edge properties updated.");

        # Mark the lesson as completed by adding COMPLETED edge from User to Lesson if lesson submitted
        if self.lesson_id != None {
            completed_edges = [user ->:COMPLETED:-> lesson_node];
            if len(completed_edges) == 0 {
                user +>:COMPLETED(completed_at=self.completed_at):+> lesson_node;
            }
        }
        print("Lesson completion recorded.");

        # Prepare structured feedback dictionary
        feedback = {
            "user_id": user.user_id,
            "topic_id": topic.topic_id,
            "topic_title": topic.title,
            "new_mastery_score": new_score,
            "total_attempts": new_attempts,
            "completed_lesson_id": lesson_node.lesson_id if self.lesson_id != None else None,
            "completion_time": self.completed_at,
        };

        report feedback;
    }

    obj __specs__ {
        static has auth: bool = True;                # No authentication required
    }
}

walker unlock_next_lesson {
    has user_id: string;
    has threshold: float = 0.6;

    can get_unlocked_lessons with `root entry {
        unlocked_lessons = [];

        if self.user_id == None {
            print("Error: user is None, cannot proceed.");
            report {"error": "User not specified"};
            disengage;
        }

        user = [root --> (`?User)](?user_id == self.user_id)[0];

        for topic in [root --> (`?Topic)] {
            prereqs = [topic ->:PREREQUISITE:->];

            # Check if user mastery score for all prerequisites is above or equal to threshold
            can_unlock = True;
            for prereq in prereqs {
                mastery_edges = [edge user ->:MASTERY:-> prereq];
                if len(mastery_edges) == 0 {
                    can_unlock = False;
                    break;
                }
                mastery = mastery_edges[0];
                if mastery.score < self.threshold {
                    can_unlock = False;
                    break;
                }
            }

            if can_unlock {
                lessons = [topic ->:HAS_LESSON:->];
                unique_lessons = {};
                for lesson in lessons {
                    # Use lesson_id as unique key
                    if lesson.lesson_id not in unique_lessons {
                        unique_lessons[lesson.lesson_id] = {
                            "topic": topic.title,
                            "lesson_id": lesson.lesson_id,
                            "lesson_title": lesson.title,
                            "lesson_content": lesson.content,
                            "starter_code": lesson.starter_code,
                            "topic_difficulty": topic.difficulty
                        };
                    }
                }
                for lesson_id in unique_lessons {
                    unlocked_lessons.append(unique_lessons[lesson_id]);
                }

            }   
        }
        # Report the unlocked lessons for the frontend
        report {"unlocked_lessons": unlocked_lessons};
    }

    obj __specs__ {
        static has auth: bool = True;                # No authentication required
    }
}

walker generate_quiz {
    has topic: string;
    has mastery_score: float;

    can create_quiz with `root entry {
        # Defensive type check to ensure self.topic is a Jac node
        print(f"Type of self.topic: {type(self.topic)}");
        if self.topic == None {
            print("Error: topic is None, cannot proceed.");
            report {"error": "Topic not specified"};
            disengage;
        }
        # if not hasattr(self.topic, "__jac__") {
        #     print("Error: self.topic is not a Jac node but a dict or other type. Attempting conversion...");
        #     # Attempt to convert dict to Jac node by querying existing nodes matching topic_id if available
        #     if "topic_id" in self.topic {
        #         topic_nodes = [root --> (`?Topic)](?topic_id == self.topic["topic_id"]);
        #         if len(topic_nodes) > 0 {
        #             self.topic = topic_nodes[0];
        #             print("Conversion successful: self.topic set to existing Jac node.");
        #         } else {
        #             # Spawn a new Topic node with the dict values if possible
        #             print("No existing Topic node found with topic_id. Creating new Topic node.");
        #             self.topic = root ++> Topic(
        #                 topic_id = self.topic.get("topic_id", ""),
        #                 title = self.topic.get("title", ""),
        #                 difficulty = self.topic.get("difficulty", 0)
        #             );
        #             print("New Topic node created.");
        #         }
        #     } else {
        #         print("Cannot convert: 'topic_id' not found in dict.");
        #         report {"error": "Invalid topic object"};
        #         disengage;
        #     }
        # }

        # Determine difficulty level based on mastery_score
        difficulty = "";
        if self.mastery_score < 0.5 {
            difficulty = "easy";
        } elif self.mastery_score <= 0.8 {
            difficulty = "medium";
        } else {
            difficulty = "hard";
        }

        # Compose prompt for LLM to generate structured quiz questions
        prompt = f"""
        You are an expert programming instructor generating a short quiz for an interactive code editor environment.

        Context:
        - Learners are using a code editor (similar to Monaco Editor).
        - They will write code snippets related to the topic.
        - The quiz should prepare them to reason about code, not just definitions.

        Topic:
        - Title: "{self.topic}"
        - Difficulty level: "{difficulty}"

        Instructions:
        - Generate 2 to 3 concise questions.
        - Each question should assess understanding of how the concept applies in code (structure, intent, behavior).
        - Questions may reference code patterns or short pseudo-code examples.
        - Avoid asking purely theoretical or memorization-based questions.

        Output format:
        - Return a valid JSON object only.
        - Do NOT include explanations or markdown.
        - Use the following structure exactly:

        {{
        "difficulty": "{difficulty}",
        "questions": [
            "question 1",
            "question 2"
        ]
        }}
        """;


        # Call LLM function to generate quiz questions in structured JSON format
        quiz_json = self.generate_quiz_questions(prompt);

        # Report the quiz JSON result for frontend consumption
        report {"quiz": quiz_json};
    }

    # LLM function to generate quiz questions from prompt
    def generate_quiz_questions(prompt: str) -> dict[str, str | list[str]] by llm();

    obj __specs__ {
        static has auth: bool = False;                # No authentication required
    }
}

walker evaluate_answer {
    has topic: string;
    has questions: list[str];
    has learner_answer: string;

    can evaluate with `root entry {
        print(f"Type of self.topic: {type(self.topic)}");
        if self.topic == None {
            print("Error: topic is None, cannot proceed.");
            report {"error": "Topic not specified"};
            disengage;
        }

        # Compose prompt for LLM to evaluate learner's free-text answer
        prompt = f"""
        You are an expert programming instructor evaluating a learner's code submission.

        Context:
        - The learner submitted code written in an interactive editor (similar to Monaco Editor).
        - The code is NOT executed.
        - Evaluation should focus on conceptual correctness, structure, and intent.

        Topic:
        - "{self.topic}"

        Quiz Questions:
        {self.questions}

        Learner Code Submission:
        \"\"\"
        {self.learner_answer}
        \"\"\"

        Evaluation Guidelines:
        - Assess whether the code demonstrates understanding of the topic.
        - Consider:
        - Correct use of relevant constructs (e.g. walkers, entry abilities, traversal logic)
        - Logical structure and intent
        - Common misconceptions or missing elements
        - Ignore minor syntax errors unless they indicate conceptual misunderstanding.
        - Do NOT penalize formatting or style.

        Scoring:
        - Provide a score between 0.0 and 1.0.
        - A score near 1.0 indicates strong conceptual understanding.
        - A score below 0.5 indicates significant misunderstandings.

        Feedback:
        - Provide constructive, specific feedback.
        - Reference parts of the learner's code where relevant.
        - Suggest 1–2 concrete improvements or next steps.

        Output format:
        - Return a valid JSON object only.
        - Do NOT include markdown or explanations outside JSON.
        - Use the following structure exactly:

        {{
        "score": 0.0,
        "feedback": "string",
        "correct": "boolean"
        }}
        """;


        # Call LLM function to evaluate answer and generate score + feedback
        evaluation = self.evaluate_answer_response(prompt);

        # Report the evaluation result for downstream processing
        report evaluation;
    }

    # LLM function to evaluate answer from prompt
    def evaluate_answer_response(prompt: str) -> dict[str, str | list[str]] by llm();

    obj __specs__ {
        static has auth: bool = False;                # No authentication required
    }
}

walker get_skill_map {
    has user_id: string; 
    has threshold: float = 0.6;  

    # The main ability to generate the skill map snapshot
    can snapshot with `root entry {
        topics_list = [];

        if self.user_id == None {
            print("Error: user is None, cannot proceed.");
            report {"error": "User not specified"};
            disengage;
        }
        
        user = [root --> (`?User)](?user_id == self.user_id)[0];


        # Iterate over all topics in the root graph
        for topic in [root --> (`?Topic)] {
            # Collect prerequisite topics connected by PREREQUISITE edges
            prereqs = [topic ->:PREREQUISITE:->];
            prereq_ids = [p.topic_id for p in prereqs];

            # Get the user's mastery edge to this topic, if it exists
            mastery_edges = [edge user ->:MASTERY:-> topic];
            mastery_score = 0.0;
            if len(mastery_edges) > 0 {
                mastery_score = mastery_edges[0].score;
            }

            # Determine if topic is unlocked: all prerequisites mastery >= threshold
            unlocked = True;
            for prereq in prereqs {
                prereq_mastery_edges = [edge user ->:MASTERY:-> prereq];
                if len(prereq_mastery_edges) == 0 or prereq_mastery_edges[0].score < self.threshold {
                    unlocked = False;
                    break;
                }
            }

            # Compose the topic snapshot dict for frontend
            topic_snapshot = {
                "topic_id": topic.topic_id,
                "title": topic.title,
                "difficulty": topic.difficulty,
                "mastery": mastery_score,
                "prerequisites": prereq_ids,
                "unlocked": unlocked
            };

            topics_list.append(topic_snapshot);
        }

        # Report the snapshot as a JSON-like dictionary
        report {"topics": topics_list};
    }

    obj __specs__ {
        static has auth: bool = True;  # No authentication required
    }
}