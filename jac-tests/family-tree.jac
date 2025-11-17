node Person {
    has name: str;
    has birth_year: int;
}

edge Parent {}

walker FindAncestors {
    has generations: int = 0;
    has max_generations: int = 3;

    can start with `root entry {
        visit [-->];
    }

    can explore with Person entry {
        print(f"{'  ' * self.generations}{here.name} (born {here.birth_year})");
        if self.generations < self.max_generations {
            #visit parents
            parents = [here <-:Parent:<-];
            if parents {
                self.generations += 1;
                visit parents;
                self.generations -= 1;
            }
        }
    }
}

with entry {
    # Create family
    alice = Person(name="Alice", birth_year=2000);
    bob = Person(name="Bob", birth_year=1975);
    carol = Person(name="Carol", birth_year=1978);
    dave = Person(name="Dave", birth_year=1950);
    eve = Person(name="Eve", birth_year=1952);

    # Build family tree (children point to parents)
    alice +>:Parent:+> bob;
    alice +>:Parent:+> carol;
    bob +>:Parent:+> dave;
    bob +>:Parent:+> eve;

    # Find ancestors
    root ++> eve;
    print("Family tree:");
    root spawn FindAncestors(max_generations=3);
}