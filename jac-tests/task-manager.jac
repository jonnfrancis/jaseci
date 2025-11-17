node Task {
    has title: str;
    has status: str = "pending";
    has priority: int = 1;
}

edge DependsOn {}

walker CheckReady {
    has ready_tasks: list = [];

    can start with `root entry {
        visit[-->];
    }

    can check with Task entry {
        if here.status != "pending" {
            return;
        }

        dependencies = [here ->:DependsOn:->];
        all_done = True;
        
        for dep in dependencies {
            if dep.status != "complete" {
                all_done = False;
                break;
            }
        }

        if all_done {
            self.ready_tasks.append(here.title);
        }
    }
}

walker MarkComplete {
    has task_title: str;

    can start with `root entry {
        visit [-->];
    }

    can mark with Task entry {
        if here.title == self.task_title {
            here.status = "complete";
            print(f"Completed task: {here.title}");
            disengage;
        }
        visit [-->];
    }
}

with entry {
    # Create tasks
    task1 = Task(title="Design database schema", priority=3);
    task2 = Task(title="Implement API", priority=3);
    task3 = Task(title="Create frontend", priority=2);
    task4 = Task(title="Write tests", priority=2);
    task5 = Task(title="Deploy to production", priority=3);

    # Define dependencies
    task2 +>:DependsOn:+> task1;  # API needs schema first
    task3 +>:DependsOn:+> task2;  # Frontend needs API
    task4 +>:DependsOn:+> task2;  # Tests need API
    task5 +>:DependsOn:+> task3;  # Deploy needs frontend
    task5 +>:DependsOn:+> task4;  # Deploy needs tests

    # Connect to root
    root ++> task1;
    root ++> task2;
    root ++> task3;
    root ++> task4;
    root ++> task5;

    # Check what's ready
    checker = CheckReady();
    root spawn checker;
    print(f"Ready to work on: {checker.ready_tasks}");

    # Complete a task
    root spawn MarkComplete(task_title="Design database schema");

    # Check again
    checker2 = CheckReady();
    root spawn checker2;
    print(f"Now ready: {checker2.ready_tasks}");

    # Complete a task
    root spawn MarkComplete(task_title="Implement API");

    # Check again
    checker3 = CheckReady();
    root spawn checker3;
    print(f"Now ready: {checker3.ready_tasks}");
}