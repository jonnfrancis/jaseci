node Person {
    has name: str;
    has age: int;

    can greet with Greeter entry {
        print(f"{self.name} says: Welcome, Visitor!");
    }
}

edge Friend {
    has since: int;
}

edge Coworker {
    has department: str;
}

walker Greeter {
    can start with `root entry {
        print("Walker starting journey!");
        visit [-->]; #visit all connected nodes
    }

    can greet with Person entry {
        print(f"Hello, {here.name}, age {here.age}!");
        report here.age;
        visit[-->]; #continue visiting connected nodes
    }

    can finish with exit {
        print("Walker has finished its journey.");
    }
}

with entry {
    #create node instances
    alice = Person(name="Alice", age=30);
    bob = Person(name="Bob", age=25);
    charlie = Person(name="Charlie", age=22);

    alice +>:Friend(since=2015):+> bob;
    alice +>:Friend(since=2019):+> charlie;
    alice +>:Coworker(department="HR"):+> charlie;
    

    #get all friends
    all_friends = [alice -->];
    print(f"Alice has {len(all_friends)} friends.");

    # Get specific type of connections
    friends = [alice ->:Friend:->];
    for friend in friends {
        print(f"Alice's friend: {friend.name}");
    }

    root ++> alice;
    root spawn Greeter();
}


# Operator	Direction	Example
# ++>	Forward	alice ++> bob; (alice → bob)
# <++	Backward	alice <++ bob; (bob → alice)
# <++>	Both ways	alice <++> bob; (alice ↔ bob)