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

walker initialize_learning_graph {

    has user_id: string;
    has name: string = "Learner";

    # Helper to get or create a topic by title and id
    def get_or_create_topic(topic_id: str, title: str, difficulty: int) -> Topic {
        topics = [root --> (`?Topic)](?title == title);
        if len(topics) > 0 {
            return topics[0];
        }
        return root ++> Topic(topic_id=topic_id, title=title, difficulty=difficulty);
    }

    # Helper to get or create a lesson by lesson_id and title
    def get_or_create_lesson(lesson_id: str, title: str, content: str, starter_code: str) -> Lesson {
        lessons = [root --> (`?Lesson)](?lesson_id == lesson_id);
        if len(lessons) > 0 {
            return lessons[0];
        }
        return root ++> Lesson(
            lesson_id=lesson_id,
            title=title,
            content=content,
            starter_code=starter_code
        );
    }


    can initialize with `root entry {
        if self.user_id != None {
            user_nodes = [root --> (`?User)](?user_id == self.user_id);
            if len(user_nodes) > 0 {
                user = user_nodes[0];
            } else {
                user = root ++> User(user_id=self.user_id, name=self.name);
            }
        }
        print("User initialized.");

        # Create topics, lessons, and link them
        basics = self.get_or_create_topic("t1", "Jac Basics", 1);
        functions = self.get_or_create_topic("t2", "Functions and Control Flow", 2);
        objects = self.get_or_create_topic("t3", "Objects and Classes", 3);
        relationships = self.get_or_create_topic("t4", "Relationships and Graphs", 4);
        walkers = self.get_or_create_topic("t5", "Understanding Walkers", 5);
        abilities = self.get_or_create_topic("t6", "Abilities and Events", 6);
        pattern_matching = self.get_or_create_topic("t7", "Pattern Matching", 7);
        byllm = self.get_or_create_topic("t8", "byLLM & AI Integration", 8);
        advanced_osp = self.get_or_create_topic("t9", "Advanced OSP Concepts", 9);
        app_dev = self.get_or_create_topic("t10", "Building Apps and Programs", 10);

        print("Topics set up.");

        #connect topics with prerequisites
        prerequisites = [
            (functions, basics),
            (objects, functions),
            (relationships, objects),
            (walkers, relationships),
            (abilities, walkers),
            (pattern_matching, abilities),
            (byllm, pattern_matching),
            (advanced_osp, byllm),
            (app_dev, advanced_osp)
        ];

        for (src, dst) in prerequisites {
            if not [src ->:PREREQUISITE:-> dst] {
                src +>:PREREQUISITE(strength=0.9):+> dst;
            }
        }
        print("Prerequisite relationships established.");

        # create lessons
        lesson1 = self.get_or_create_lesson(
            "jac_intro",
            "Intro to Jac Syntax",
            """Jac is an AI-first, graph-based programming language designed for Object-Spatial Programming (OSP).
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
            "node Example { has str name; }"
        );
        
        lesson2 = self.get_or_create_lesson(
            "jac_functions_control_flow",
            "Functions and Control Flow in Jac",
            """This lesson covers how to organize your code using functions and control flow statements in Jac.

## Functions in Jac:
Functions allow you to group code into reusable blocks that you can call by name. This helps keep code clean and manageable.

### Defining Functions:
```jac
def greet(name: str) {
    print(f"Hello, {name}!");
}
```

### Calling Functions: 
```jac
with entry {
    greet("Alice");
}
```

## Control Flow Statements:
Control flow directs the execution path of your program. Jac supports conditionals and loops.

### If-Else Statements:
```jac
with entry {
    x: int = 10;

    if x < 5 {
        print("small");
    } elif x < 15 {
        print("medium");
    } else {
        print("large");
    }
}
```

### Pattern Matching:
Pattern matching lets you branch logic based on matching values or patterns.
```jac
with entry {
    value: int = 2;

    match value {
        case 1:
            print("one");
        case 2:
            print("two");
        case _:
            print("other");
    }
}

### For Loops:
For loops allow you to iterate over collections.
```jac
with entry {
    items: list[str] = ["a", "b", "c"];
    for item in items {
        print(item);
    }

    for i = 0 to i < 5 by i += 1 {
        print(i);
    }
}
```

### While Loops:
Jac supports while loops for repeated execution while a condition is true.
```jac
with entry {
    i: int = 0;
    while i < 3 {
        print(i);
        i += 1;
    }
}
```

""",
            """ def greet(name: str) { print(f"Hello, {name}!"); }
with entry { greet("Jac learner"); } """
        );
        lesson3 = self.get_or_create_lesson(
            "jac_objects_classes",
            "Objects and Classes in Jac",
            """This lesson introduces object-oriented programming concepts in Jac, focusing on nodes as classes and their properties and methods.

## Nodes as Classes:
In Jac, nodes represent classes or objects. You define a node type with properties using the `has` keyword.

### Defining Nodes (Classes):
```jac 
node Person {
    has name: str;
    has age: int;
}
``` 
This defines a `Person` node with two properties: `name` (a string) and `age` (an integer).

### Creating Node Instances:
You can create instances of nodes connected to another node (like `root`):
```jac
with entry {
    alice = root ++> Person(name="Alice", age=30)[0];
}
```

### Inheritance with `isa`:
Jac supports inheritance using the `isa` keyword, allowing nodes to inherit properties and methods from other nodes.
```jac
node Animal {
    has name: str;
}

node Dog isa Animal {
    can bark {
        print(f"Woof! My name is {self.name}");
    }
}
```
Here, `Dog` inherits the `name` property from `Animal` and adds the ability to `bark`.

### Using Methods and Abilities on Nodes:
You can define methods (called abilities) on nodes by declaring can blocks inside the node:
```jac
node Counter {
    has count: int = 0;

    can increment {
        self.count += 1;
        print(f"Count is now {self.count}");
    }
}
```

### Example: Using Objects and Abilities
```jac
walker test_objects {
    can run with `root entry {
        alice = root ++> Person(name="Alice", age=25)[0];
        dog = root ++> Dog(name="Fido")[0];
        dog.bark();
    }
}
```
""",
            """ node Person { has str name; has int age; }

node Animal { has str name; }

node Dog isa Animal { can bark { print(f"Woof! My name is {self.name}"); } }

with entry { alice = root ++> Person(name="Alice", age=30)[0]; dog = root ++> Dog(name="Fido")[0]; dog.bark(); }"""
        );
        lesson4 = self.get_or_create_lesson(
            "jac_relationships_graphs",
            "Relationships and Graphs in Jac",
            """This lesson introduces how to model relationships and graphs in Jac using nodes and edges.

## Nodes and Edges:

### Node Definition:
Nodes represent entities or objects in a graph.
```jac
node Person {
    has name: str;
    has age: int = 0;
}
```

### Edge Definition:
Edges represent directed relationships between nodes.
```jac
edge Friend {
    has since: int;
    has strength: float = 1.0;
}
```

### Modeling Relationships:
You connect nodes with edges to represent relationships, e.g., friendship.
```jac
walker RelationshipExplorer {
    can explore with Person entry {
        # Traverse outgoing Friend edges to connected persons
        friends = [->:Friend:->];
        for friend in friends {
            print(f"{here.name} is friends with {friend.name} since {here:Friend.since}");
        }
    }
}
```

### Graph Traversal:
Jac uses walkers to visit nodes and edges in a graph.
#### Basic Traversal:
```jac
with entry {
    # Start traversal at root nodes
    visit [->];
}
```

#### Filtering:
You can filter nodes or edges by attributes.
```jac
# Filter friends since 2020
recent_friends = [->:Friend:since > 2020:->];
```
This lesson helps you understand the core concepts of Object-Spatial Programming (OSP) in Jac by modeling and traversing graphs. """,
            """node Person { has name: str; has age: int = 0; }

edge Friend { has since: int; has strength: float = 1.0; }

walker RelationshipExplorer { can explore with Person entry { friends = [->:Friend:->]; for friend in friends { print(f"{here.name} is friends with {friend.name} since {here:Friend.since}"); } } }

with entry { visit [->]; } """
        );
        lesson5 = self.get_or_create_lesson(
            "jac_understanding_walkers",
            "Understanding Walkers in Jac",
            """This lesson introduces walkers, which are mobile computation agents that traverse the graph and execute logic at each node.

## What are Walkers?
Walkers are special objects designed to navigate nodes and edges in a Jac graph, performing computations or triggering behaviors as they go.

## Defining a Walker:
You define a walker similar to an object but with traversal abilities.

```jac
walker Greeter {
    can start with `root entry {
        visit [-->];  # Visit nodes connected to root
    }

    can greet with Person entry {
        print(f\"Hello, {here.name}!\");
        here.visited = True;
    }
}
```
- `can start with root entry`: Entry ability where the walker begins.
- `visit [-->];`: Traverses outgoing edges to connected nodes.
- `can greet with Person entry`: Ability triggered at nodes of type `Person`.

### Using Walkers:
You spawn walkers at nodes to start their traversal.
```jac
with entry {
    alice = Person(name="Alice");
    bob = Person(name="Bob");

    root ++> alice;
    alice ++> bob;

    root spawn Greeter();
}
```

### Key Points
- Walkers move through graphs visiting nodes and edges.
- They can have multiple abilities triggered at different node types.
- Use `visit` to control traversal.
- `report` continues execution after reporting a value; `return` stops.

This lesson helps you understand how to implement and use walkers for graph traversal and computation in Jac. """,
            """ node Person { has name: str; has visited: bool = False; }

walker Greeter { can start with `root entry { visit [-->]; }

can greet with Person entry {
    print(f"Hello, {here.name}!");
    here.visited = True;
}
}

with entry { alice = Person(name="Alice"); bob = Person(name="Bob");

root ++> alice;
alice ++> bob;

root spawn Greeter();
} """
        );
        lesson6 = self.get_or_create_lesson(
            "jac_abilities_events",
            "Abilities and Events in Jac",
            """This lesson introduces abilities, special methods on nodes and walkers that define behaviors triggered by events such as entering or exiting nodes.

## What are Abilities?
Abilities are special methods that define reactive behavior on nodes or walkers. They are triggered by events like entering or exiting a node or walker starting.

## Ability Syntax:
```jac
can ability_name with [Node_Type] [entry|exit] {
    // Ability logic here
}
```

- `can ability_name`: Defines an ability.
- `with [Node_Type] [entry|exit]`: Specifies trigger conditions. `Node_Type` is optional.
- `entry`: Triggers when walker enters a node.
- `exit`: Triggers when walker exits a node.

## Node Abilities:
Nodes can have callable abilities (methods) or visit-dependent abilities triggered by walkers.

```jac
node TestNode {
    has value: int;

    def callable {
        print(f"Callable on {self}");
    }

    can log_entry with entry {
        print(f"Some walker entered node {self}");
    }

    can log_specific_walker_entry with test_walker entry {
        print(f"{here} entered node {self}");
        here.callable();
    }
}
```

## Walker Abilities:
Walkers can define abilities that trigger on entry or exit of nodes they visit.
```jac
walker TestWalker {
    can on_entry with entry {
        print("Walker entry");
    }

    can on_root_entry with `root entry {
        print("Walker entered root");
        visit [-->];
    }

    can on_node_entry with Node entry {
        print(f"Node value: {here.value}");
    }

    can on_node_exit with Node exit {
        print(f"Exiting node {here.value}");
    }

    can on_exit with exit {
        print("Walker exit");
    }
}
```

## Common Ability Patterns
- Root entry abilities for setup and traversal start.
- Node-specific abilities triggered when walker visits specific node types.
- Abilities can report data or perform side effects.

Abilities enable reactive, event-driven programming in Jac, essential for graph traversal, AI agents, and event handling.

""",
            """ node TestNode { has value: int;

def callable {
    print(f"Callable on {self}");
}

can log_entry with entry {
    print(f"Some walker entered node {self}");
}

can log_specific_walker_entry with TestWalker entry {
    print(f"{here} entered node {self}");
    here.callable();
}
}

walker TestWalker { can on_entry with entry { print("Walker entry"); }

can on_root_entry with `root entry {
    print("Walker entered root");
    visit [-->];
}

can on_node_entry with TestNode entry {
    print(f"Node value: {here.value}");
}

can on_node_exit with TestNode exit {
    print(f"Exiting node {here.value}");
}

can on_exit with exit {
    print("Walker exit");
}
}

with entry { test_node = TestNode(value=42); root ++> test_node;

root spawn TestWalker();
} """ 
        );
        lesson7 = self.get_or_create_lesson(
             "jac_pattern_matching",
            "Pattern Matching in Jac",
            """This lesson covers pattern matching in Jac, a powerful control flow construct that lets you branch logic based on matching values or complex patterns.

## What is Pattern Matching?
Pattern matching is a way to check a value against a series of patterns and execute code based on which pattern matches.

## Basic Syntax:
```jac
with entry {
    value: int = 2;

    match value {
        case 1:
            print("one");
        case 2:
            print("two");
        case _:
            print("other");
    }
}
```
- `match` keyword starts the pattern matching block.
- `case` specifies each pattern to match.
- `_` is the wildcard pattern matching anything else.

## Pattern Matching Features:
- Supports matching literals (e.g., numbers, strings).
- Supports attribute pattern matching (e.g., `case a.b.c`).
- Can destructure complex data structures.

### Example: Matching with Attributes
```jac
with entry {
    obj = SomeNode();

    match obj {
        case SomeNode.attribute:
            print("Matched SomeNode attribute pattern");
        case _:
            print("Default case");
    }
}
```

## Why Use Pattern Matching?

- Cleaner and clearer branching logic compared to multiple if-else.
- More expressive matching on complex data structures.

This lesson helps you understand how to use Jac's match/case syntax for effective control flow based on patterns. """,
            """ with entry { value: int = 2;

match value {
    case 1:
        print("one");
    case 2:
        print("two");
    case _:
        print("other");
}
} """
        );
        lesson8 = self.get_or_create_lesson(
             "jac_byllm_ai_integration",
            "byLLM & AI Integration in Jac",
            """This lesson introduces the byLLM feature in Jac that allows native integration of Large Language Models (LLMs) in your programs.

## What is byLLM?

- `by llm()` is a method modifier indicating the implementation of a method is done by a Large Language Model.
- It enables seamless AI integration for functions, methods, and walkers.
- Jac generates the necessary prompts and handles interactions with LLMs automatically.

## Syntax:

```jac
def method_name(params) -> return_type by llm();
```

## Example: LLM-powered method in a node
```jac
node AIResponder {
    def generate_response(prompt: str) -> str by llm();
}
```

## Example: Walker using LLM-powered methods
```jac
walker ChatAgent {
    has prompt: str;
    has response: str = "";

    can start with `root entry {
        self.response = here.generate_response(self.prompt);
        print(f"AI Response: {self.response}");
    }
}
```

### Benefits of byLLM

- Simplifies calling AI models from Jac code.
- Enables building AI-native applications with minimal boilerplate.
- Supports complex AI behaviors as native Jac methods.

This lesson helps you understand how to leverage Jac's AI integration features to build intelligent applications with LLMs. """,
            """ node AIResponder { def generate_response(prompt: str) -> str by llm(); }

walker ChatAgent { has prompt: str; has response: str = "";

can start with `root entry {
    self.response = here.generate_response(self.prompt);
    print(f"AI Response: {self.response}");
}
}

with entry { root spawn ChatAgent(prompt="Hello, Jac with AI!"); } """ 
        );
        lesson9 = self.get_or_create_lesson(
            "jac_advanced_osp_concepts",
            "Advanced Object-Spatial Programming Concepts",
            """This lesson dives into advanced Object-Spatial Programming (OSP) concepts in Jac, focusing on the powerful graph-based programming model.

## What is Object-Spatial Programming (OSP)?
OSP is Jac's unique programming paradigm where data and computation coexist in a graph.

- Objects (nodes) represent entities.
- Relationships (edges) connect nodes.
- Walkers are mobile computations that traverse and act on the graph.

## Node-Walker Architecture
Jac programs are organized with nodes (data) and walkers (actions).

### Nodes
Nodes hold attributes and define behaviors.

### Walkers
Walkers traverse nodes and edges, executing abilities triggered by events.

## Graph-Based Programming
OSP leverages explicit relationships to enable spatial computation.

- Computation moves to data instead of fetching data to computation.
- Enables distributed, asynchronous, and reactive programming.

## Advanced Usage

- Use typed edges to model complex relationships.
- Design walkers with multiple abilities for flexible traversals.
- Combine abilities and AI integrations (by llm) for intelligent agents.

## Benefits

- Clear separation of data and behavior.
- Scalable and modular program design.
- Natural fit for AI, simulations, and distributed systems.

This lesson helps you master Jac's advanced graph-based programming techniques for building sophisticated AI-native applications.
""",
    """
node Entity {
    has name: str;
    has description: str = "";
}

edge Relation {
    has relation_type: str;
    has strength: float = 1.0;
}

walker AdvancedWalker {
    can start with `root entry {
        print("Starting advanced traversal...");
        visit [-->];
    }

    can act with Entity entry {
        print(f"Visiting entity: {here.name} - {here.description}");
    }
}

with entry {
    e1 = Entity(name="Node1", description="First node");
    e2 = Entity(name="Node2", description="Second node");

    root ++> e1;
    e1 ++> e2;

    root spawn AdvancedWalker();
}
"""
);
        lesson10 = self.get_or_create_lesson(
                "jac_building_apps_programs",
                "Building Apps and Programs in Jac",
                """This lesson guides you through building applications and programs using Jac's unique Object-Spatial Programming (OSP) model.

## Getting Started with Jac Projects
- Organize your Jac code into nodes (data), walkers (behavior), and abilities (events).
- Use modules and imports to structure large projects.
- Define clear entry points using walkers with `root entry` abilities.

## Combining Nodes and Walkers
- Nodes hold your data and state.
- Walkers traverse nodes and edges, executing logic and updating state.
- Abilities on nodes and walkers enable event-driven programming.

## Example: Simple To-Do App
```jac
node Task {
    has description: str;
    has done: bool = False;

    can mark_done with entry {
        self.done = True;
        print(f"Task done: {self.description}");
    }
}

walker TaskManager {
    can start with `root entry {
        tasks = [-->(`?Task)];
        for task in tasks {
            if not task.done {
                print(f"Pending: {task.description}");
                task.mark_done();
            }
        }
    }
}
```

## Deployment and Integration

- Jac programs can be deployed on backend servers or compiled to frontend.
- Integrate with AI models using by llm() for intelligent behavior.
- Use Jac's full-stack capabilities to build seamless AI-native applications.

This lesson prepares you to build complete, interactive Jac programs leveraging its powerful graph-based and AI-integrated features. """,
            """ node Task { has description: str; has done: bool = False;

can mark_done with entry {
    self.done = True;
    print(f"Task done: {self.description}");
}
}

walker TaskManager { can start with root entry { tasks = [-->(?Task)]; for task in tasks { if not task.done { print(f"Pending: {task.description}"); task.mark_done(); } } } }

with entry { t1 = Task(description="Write Jac LMS content"); t2 = Task(description="Test Jac lessons");

root ++> t1;
root ++> t2;

root spawn TaskManager();
} """
        );
        
        print("Lessons created.");

        # link lessons to topics
        topic_lesson_pairs = [
            (basics, lesson1),
            (functions, lesson2),
            (objects, lesson3),
            (relationships, lesson4),
            (walkers, lesson5),
            (abilities, lesson6),
            (pattern_matching, lesson7),
            (byllm, lesson8),
            (advanced_osp, lesson9),
            (app_dev, lesson10)
        ];
        for (topic, lesson) in topic_lesson_pairs {
            if not [topic ->:HAS_LESSON:-> lesson] {
                topic +>:HAS_LESSON:+> lesson;
            }
        }
        print("Lessons linked to topics.");



        if self.user_id != None {
            if hasattr(user, "__jac__") {
                for topic in [root --> (`?Topic)] {
                    if not [user ->:MASTERY:-> topic] {
                        user +>:MASTERY(score=0.0, attempts=0, last_updated="") :+> topic;
                    }
                }
            } else {
                print("Error: user is not a Jac node but a dict or other type.");
            }
        }

        report "Learning graph initialized.";
    }

    obj __specs__ {
        static has auth: bool = True;                # No authentication required
    }
}

with entry {
    load_dotenv();
}



