import from dotenv { load_dotenv }
import from byllm.lib { Model }


glob llm = Model(model_name="gemini/gemini-2.5-flash", verbose=False);

node User {
    has user_id: str;
    has name: str;
}

node Topic {
    has topic_id: str;
    has title: str;
    has difficulty: int;
}

node Lesson {
    has lesson_id: str;
    has title: str;
    has content: str;
    has starter_code: str;
}

node Quiz {
    has quiz_id: str;
    has questions: list[str];
}

edge PREREQUISITE {
    has strength: float;
}

edge HAS_LESSON {}

edge HAS_QUIZ {}

edge MASTERY {
    has score: float;
    has attempts: int;
    has last_updated: str;
}

edge COMPLETED {
    has completed_at: str;
}

walker initialize_learning_graph {

    has user: User = None;

    can initialize with `root entry {
        if self.user != None {
            if not hasattr(self.user, "__jac__") {
                # Assume dict with user_id field
                user_nodes = [root --> (`?User)](?user_id == self.user["user_id"]);
                if len(user_nodes) > 0 {
                    self.user = user_nodes[0];
                } else {
                    self.user = root ++> User(user_id=self.user["user_id"], name=self.user.get("name", ""));
                }
            }
        }
        # Create topics, lessons, and link them
        if not [root --> (`?Topic)] {
            jac_basics = root ++> Topic(
                topic_id="t1",
                title="Jac Basics",
                difficulty=1
            );
            walkers = root ++> Topic(
                topic_id="t2",
                title="Understanding Walkers",
                difficulty=2
            );
            OSP_graphs = root ++> Topic(
                topic_id="t3",
                title="OSP Graphs",
                difficulty=3
            );
            byllm = root ++> Topic(
                topic_id="t4",
                title="byLLM & Agents",
                difficulty=4
            );
        } else {
            jac_basics = [root --> (`?Topic)](?title == "Jac Basics")[0];
            walkers = [root --> (`?Topic)](?title == "Understanding Walkers")[0];
            OSP_graphs = [root --> (`?Topic)](?title == "OSP Graphs")[0];
            byllm = [root --> (`?Topic)](?title == "byLLM & Agents")[0];
        }

        print("Topics set up.");

        #connect topics with prerequisites
        if not [walkers ->:PREREQUISITE:-> jac_basics] {
            walkers +>:PREREQUISITE(strength=0.9):+> jac_basics;
        }
        if not [OSP_graphs ->:PREREQUISITE:-> walkers] {
            OSP_graphs +>:PREREQUISITE(strength=0.9):+> walkers;
        }
        if not [byllm ->:PREREQUISITE:-> OSP_graphs] {
            byllm +>:PREREQUISITE(strength=0.9):+> OSP_graphs;
        }
        print("Prerequisite relationships established.");

        # create lessons
        lesson1 = root ++> Lesson(
            lesson_id="jac_intro",
            title="Intro to Jac Syntax",
            content="""Jac is an AI-first, graph-based programming language designed for Object-Spatial Programming (OSP).
It treats all data as nodes and edges in a graph, and behavior as walkers that traverse these graphs.

## Key Concepts:
- Nodes: Entities holding data and behavior.
- Edges: Directed connections between nodes, can hold data.
- Walkers: Programs that traverse nodes and edges to perform computations.

## Basic Syntax:
- Node declarations with properties using `has` keyword.
- Edge declarations to model relationships.
- Walkers to define traversal logic.
- Ability methods (`can`) on walkers and nodes.
- Use of `spawn` to start walkers.

## Example:

```jac
node Person {
    has name: str;
    has age: int;
}

edge Friend {}

walker Greeter {
    can greet with Person entry {
        print(f"Hello, {here.name}! You are {here.age} years old.");
    }
}

with entry {
    # Create a node
    alice = root ++> Person(name="Alice", age=30)[0];

    # Spawn the walker to greet
    Greeter() spawn alice;
}
```
""",
            starter_code="node Example { has str name; }"
        );
        lesson2 = root ++> Lesson(
            lesson_id="walker_intro",
            title="Your First Walker",
            content="""This lesson introduces the concept of Walkers in Jac, which are mobile
programs that traverse the graph of nodes and edges to perform computations.

Walkers are fundamental for interacting with and processing Jac graphs.
They carry their own state and can define abilities (methods) triggered
on visiting nodes or edges.

## Key Concepts:
- Walkers are declared with the `walker` keyword.
- Abilities are declared with `can <ability_name> with <context>`.
- The context often specifies node types or special entry points like `root entry`.
- Walkers can be spawned from nodes to start traversal.

### Example:
```jac
node Person {
    has name: str;
}

walker Greeter {
    # Ability to greet a Person node when walker enters it
    can greet with Person entry {
        print(f"Hello, {here.name}! Welcome to Jac Walkers.");
    }

    # Entry ability from root node to start greeting
    can start with `root entry {
        # Find all Person nodes connected to root and greet them
        for person_node in [root --> (`?Person)] {
            # Spawn this walker on each person node to greet
            Greeter() spawn person_node;
        }
    }
}

with entry {
    # Create some Person nodes connected to root
    alice = root ++> Person(name="Alice")[0];
    bob = root ++> Person(name="Bob")[0];

    # Spawn the Greeter walker from root to start the greeting process
    Greeter() spawn root;
}
```
""",
            starter_code="walker hello { start { std.out('Hello Jaseci'); } }"
        );
        lesson3 = root ++> Lesson(
            lesson_id="osp_intro",
            title="Modeling with OSP",
            content="""This lesson introduces Object-Spatial Programming (OSP) in Jac, a core paradigm
that represents data and software as graphs of nodes and edges with traversal behavior.

OSP is a fundamental shift from traditional object-oriented programming, enabling
explicit modeling of relationships and dynamic computations over graph structures.

## Key Concepts:
- Nodes: Represent entities with data and behavior.
- Edges: Directed relationships connecting nodes, can have attributes.
- Walkers: Mobile programs that traverse nodes and edges, performing computations.

## Modeling with OSP:
- Define node and edge classes to capture entities and their relationships.
- Use walkers to navigate and compute over the object graph.
- Represent complex systems naturally as graphs.

### Example:
```jac
node A {
    has val: int = 0;
}

node B {
    has val: int = 0;
}

edge edge_ab {}

walker W {
    can create with `root entry {
        # Create nodes and connect them with edges
        a = here ++> A(val=5)[0];
        b = here ++> B(val=10)[0];
        a +>:edge_ab:+> b;
        print(f"Created node A with val {a.val} and node B with val {b.val}");
    }
}

with entry {
    # Spawn walker to build graph model
    root spawn W();
}
```
""",
            starter_code="node A {}; node B {}; A -[edge]-> B;"
        );
        lesson4 = root ++> Lesson(
            lesson_id="byllm_intro",
            title="Intro to byLLM",
            content="""This lesson introduces the byLLM integration in Jac, enabling AI-first programming by
leveraging large language models (LLMs) as first-class citizens within Jac walkers and nodes.

## Key Concepts:
- byLLM functions: Define methods that delegate computation or content generation to LLMs.
- Method annotations like `by llm(method="ReAct")` specify LLM usage with reasoning chains.
- Agents: Walkers or nodes enhanced with AI abilities for dynamic reasoning and generation.
- Integration allows generating content, quiz questions, evaluating answers, and more.

### Example:
```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gemini/gemini-2.5-flash", verbose=False);

node Lesson {
    has lesson_id: str;
    has title: str;
    has content: str;

    # LLM method to generate content given a topic
    def generate_content(topic: str) -> str by llm(method="ReAct");
}

walker byllm_demo {
    can run with `root entry {
        lesson = root ++> Lesson(lesson_id="byllm_intro", title="Intro to byLLM & Agents", content="")[0];
        lesson.content = lesson.generate_content(lesson.title);
        print("Generated content:");
        print(lesson.content);
    }
}

with entry {
    root spawn byllm_demo();
}
```
""",
            starter_code="@byllm(prompt='Explain walkers') func explain() {}"
        );
        
        print("Lessons created.");

        # link lessons to topics
        if not [jac_basics ->:HAS_LESSON:-> lesson1] {
            jac_basics +>:HAS_LESSON:+> lesson1;
        }
        if not [walkers ->:HAS_LESSON:-> lesson2] {
            walkers +>:HAS_LESSON:+> lesson2;
        }
        if not [OSP_graphs ->:HAS_LESSON:-> lesson3] {
            OSP_graphs +>:HAS_LESSON:+> lesson3;
        }
        if not [byllm ->:HAS_LESSON:-> lesson4] {
            byllm +>:HAS_LESSON:+> lesson4;
        }
        print("Lessons linked to topics.");

        print(type(self.user));

        print(f"Type of self.user after lookup: {type(self.user)}");

        if self.user != None {
            if hasattr(self.user, "__jac__") {
                for topic in [root --> (`?Topic)] {
                    if not [self.user ->:MASTERY:-> topic] {
                        self.user +>:MASTERY(score=0.0, attempts=0, last_updated="") :+> topic;
                    }
                }
            } else {
                print("Error: self.user is not a Jac node but a dict or other type.");
            }
        }

        report "Learning graph initialized.";
    }

    obj __specs__ {
        static has auth: bool = False;                # No authentication required
    }
}

walker progress_tracker {

    has user: User;
    has lesson: Lesson = None;
    has quiz: Quiz = None;
    has score: float = 0.0;
    has completed_at: str = "";

    can submit with `root entry { 
        if self.user == None {
            report {"error": "User not specified"};
            disengage;
        }
        # Defensive type check for self.user
        print(f"Type of self.user: {type(self.user)}");
        if not hasattr(self.user, "__jac__") {
            print("Error: self.user is not a Jac node but a dict or other type. Attempting conversion...");
            # Attempt to convert dict to Jac node by querying existing nodes matching user_id if available
            if "user_id" in self.user {
                user_nodes = [root --> (`?User)](?user_id == self.user["user_id"]);
                if len(user_nodes) > 0 {
                    self.user = user_nodes[0];
                    print("Conversion successful: self.user set to existing Jac node.");
                } else {
                    # Spawn a new User node with the dict values if possible
                    print("No existing User node found with user_id. Creating new User node.");
                    self.user = root ++> User(
                        user_id = self.user.get("user_id", ""),
                        name = self.user.get("name", ""),
                    );
                    print("New User node created.");
                }
            } else {
                print("Cannot convert: 'user_id' not found in dict.");
                report {"error": "Invalid user object"};
                disengage;
            }
        }
        print("Tracking progress for user:", self.user.user_id);

        # Determine the topic related either by Lesson or Quiz
        topic = None;
        if self.lesson != None {
            if not hasattr(self.lesson, "__jac__") {
                print("Error: self.lesson is not a Jac node but a dict or other type. Attempting conversion...");
                # Attempt to convert dict to Jac node by querying existing nodes matching lesson_id if available
                if "lesson_id" in self.lesson {
                    lesson_nodes = [root --> (`?Lesson)](?lesson_id == self.lesson["lesson_id"]);
                    if len(lesson_nodes) > 0 {
                        self.lesson = lesson_nodes[0];
                        print("Conversion successful: self.lesson set to existing Jac node.");
                    } else {
                        # Spawn a new Lesson node with the dict values if possible
                        print("No existing Lesson node found with lesson_id. Creating new Lesson node.");
                        self.lesson = root ++> Lesson(
                            lesson_id = self.lesson.get("lesson_id", ""),
                            title = self.lesson.get("title", ""),
                            content = self.lesson.get("content", ""),
                            starter_code = self.lesson.get("starter_code", "")
                        );
                        print("New Lesson node created.");
                    }
                } else {
                    print("Cannot convert: 'lesson_id' not found in dict.");
                    report {"error": "Invalid lesson object"};
                    disengage;
                }
            }
            print("Looking for topics related to lesson:", self.lesson.title);
            lessons = [root --> (`?Lesson)](?lesson_id == self.lesson.lesson_id);
            if len(lessons) == 0 {
                report {"error": "Lesson not found in graph"};
                disengage;
            }
            lesson_node = lessons[0];
            topics = [lesson_node <-:HAS_LESSON:<- (`?Topic)];
            print("Found topics for lesson:", len(topics));
            
            if len(topics) > 0 {
                topic = topics[0];
            } else {
                print("No related Topic found for Lesson:", self.lesson.title);
                report {"error": "No related Topic found for Lesson"};
                disengage;
            }
        } elif self.quiz != None {
            print("Looking for topics related to quiz:", self.quiz.quiz_id);
            quizes = [root --> (`?Quiz)](?quiz_id == self.quiz.quiz_id);
            if len(quizes) == 0 {
                report {"error": "Quiz not found in graph"};
                disengage;
            }
            quiz_node = quizes[0];
            topics = [quiz_node <-:HAS_QUIZ:<- (`?Topic)];
            if len(topics) > 0 {
                topic = topics[0];
            } else {
                report {"error": "No related Topic found for Quiz"};
                disengage;
            }
        }

        if topic == None {
            report {"error": "Related Topic not found for submission"};
            disengage;
        }
        print("Related topic identified:", topic.title);

        

        # Find or create the MASTERY edge from User to Topic
        mastery_edges = [edge self.user ->:MASTERY:-> topic];
        print(mastery_edges);
        mastery = None;
        if len(mastery_edges) == 0 {
            mastery = self.user +>:MASTERY(score=0.0, attempts=0, last_updated="" ):+> topic;
            edges = [edge self.user ->:MASTERY:-> topic];
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
        if self.lesson != None {
            completed_edges = [self.user ->:COMPLETED:-> self.lesson];
            if len(completed_edges) == 0 {
                self.user +>:COMPLETED(completed_at=self.completed_at):+> self.lesson;
            }
        }
        print("Lesson completion recorded.");

        # Prepare structured feedback dictionary
        feedback = {
            "user_id": self.user.user_id,
            "topic_id": topic.topic_id,
            "topic_title": topic.title,
            "new_mastery_score": new_score,
            "total_attempts": new_attempts,
            "completed_lesson_id": self.lesson.lesson_id if self.lesson != None else None,
            "completed_quiz_id": self.quiz.quiz_id if self.quiz != None else None,
            "completion_time": self.completed_at,
        };

        report feedback;
    }

    obj __specs__ {
        static has auth: bool = False;                # No authentication required
    }
}

walker unlock_next_lesson {
    has user: User;
    has threshold: float = 0.6;

    can get_unlocked_lessons with `root entry {
        unlocked_lessons = [];

        print(f"Type of self.user: {type(self.user)}");
        
        if self.user == None {
            print("Error: user is None, cannot proceed.");
            report {"error": "User not specified"};
            disengage;
        }

        if not hasattr(self.user, "__jac__") {
            print("Error: self.user is not a Jac node but a dict or other type. Attempting conversion...");
            # Attempt to convert dict to Jac node by querying existing nodes matching user_id if available
            if "user_id" in self.user {
                user_nodes = [root --> (`?User)](?user_id == self.user["user_id"]);
                if len(user_nodes) > 0 {
                    self.user = user_nodes[0];
                    print("Conversion successful: self.user set to existing Jac node.");
                } else {
                    # Spawn a new User node with the dict values if possible
                    print("No existing User node found with user_id. Creating new User node.");
                    self.user = root ++> User(
                        user_id = self.user.get("user_id", ""),
                        name = self.user.get("name", ""),
                    );
                    print("New User node created.");
                }
            } else {
                print("Cannot convert: 'user_id' not found in dict.");
                report {"error": "Invalid user object"};
                disengage;
            }
        }

        for topic in [root --> (`?Topic)] {
            prereqs = [topic ->:PREREQUISITE:->];

            # Check if user mastery score for all prerequisites is above or equal to threshold
            can_unlock = True;
            for prereq in prereqs {
                mastery_edges = [edge self.user ->:MASTERY:-> prereq];
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
        static has auth: bool = False;                # No authentication required
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
    has user: User; 
    has threshold: float = 0.6;  

    # The main ability to generate the skill map snapshot
    can snapshot with `root entry {
        topics_list = [];

        print(f"Type of self.user: {type(self.user)}");
        if self.user == None {
            print("Error: user is None, cannot proceed.");
            report {"error": "User not specified"};
            disengage;
        }
        if not hasattr(self.user, "__jac__") {
            print("Error: self.user is not a Jac node but a dict or other type. Attempting conversion...");
            # Attempt to convert dict to Jac node by querying existing nodes matching user_id if available
            if "user_id" in self.user {
                user_nodes = [root --> (`?User)](?user_id == self.user["user_id"]);
                if len(user_nodes) > 0 {
                    self.user = user_nodes[0];
                    print("Conversion successful: self.user set to existing Jac node.");
                } else {
                    # Spawn a new User node with the dict values if possible
                    print("No existing User node found with user_id. Creating new User node.");
                    self.user = root ++> User(
                        user_id = self.user.get("user_id", ""),
                        name = self.user.get("name", ""),
                    );
                    print("New User node created.");
                }
            } else {
                print("Cannot convert: 'user_id' not found in dict.");
                report {"error": "Invalid user object"};
                disengage;
            }
        }


        # Iterate over all topics in the root graph
        for topic in [root --> (`?Topic)] {
            # Collect prerequisite topics connected by PREREQUISITE edges
            prereqs = [topic ->:PREREQUISITE:->];
            prereq_ids = [p.topic_id for p in prereqs];

            # Get the user's mastery edge to this topic, if it exists
            mastery_edges = [edge self.user ->:MASTERY:-> topic];
            mastery_score = 0.0;
            if len(mastery_edges) > 0 {
                mastery_score = mastery_edges[0].score;
            }

            # Determine if topic is unlocked: all prerequisites mastery >= threshold
            unlocked = True;
            for prereq in prereqs {
                prereq_mastery_edges = [edge self.user ->:MASTERY:-> prereq];
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
        static has auth: bool = False;  # No authentication required
    }
}

with entry {
    load_dotenv();
}



