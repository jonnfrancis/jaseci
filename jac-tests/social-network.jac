node User {
    has username: str;
    has age: int; 
    has interests: list;
}

edge Friendship {
    has since: int;
    has strength: int = 1;
}

walker FriendRecommender {
    has recommendations: list = [];

    can start with `root entry {
        visit [-->];
    }

    can find_recommendations with User entry {
        print(f"Finding recommendations for {here.username}...");

        #visit friends of friends excluding direct friends and self (2 hops)
        potential_friends = [here ->:Friendship:-> ->:Friendship:->];

        current_friends = [here ->:Friendship:->];

        for person in potential_friends {
            if person not in current_Friends and person != here {
                self.recommendations.append(person.username);
            }
        }
        disengage;
    }
}

walker InterestMatcher {
    has target_interest: str;
    has matches: list = [];

    can start with `root entry {
        visit [-->];
    }

    can find with User entry {
        if self.target_interest in here.interests {
            self.matches.append(here.username);
        }
        visit [-->];
    }
}

with entry {
    # Create users
    alice = User(
        username="alice",
        age=25,
        interests=["coding", "hiking", "photography"]
    );

    bob = User(
        username="bob",
        age=28,
        interests=["coding", "gaming"]
    );

    charlie = User(
        username="charlie",
        age=26,
        interests=["hiking", "reading"]
    );

    dana = User(
        username="dana",
        age=27,
        interests=["photography", "travel"]
    );

    # Build social graph
    root ++> alice;
    root ++> bob;
    root ++> charlie;
    root ++> dana;

    alice +>:Friendship(since=2020, strength=8):+> bob;
    bob +>:Friendship(since=2021, strength=6):+> charlie;
    alice +>:Friendship(since=2019, strength=9):+> dana;

    # Find friend recommendations for Bob
    recommender = FriendRecommender();
    bob spawn recommender;
    print(f"Recommendations: {recommender.recommendations}");

    # Find users interested in hiking
    matcher = InterestMatcher(target_interest="hiking");
    root spawn matcher;
    print(f"Users interested in hiking: {matcher.matches}");
}
