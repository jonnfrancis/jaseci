import from byllm.llm { Model }
glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

node Room {
    has description: str;
    has has_key: bool = False;
    has has_door: bool = False;
}

node Key {
    has picked_up: bool = False;
}

node Door {
    has is_open: bool = False;
}

edge connected_to {}

def generate_room_description(room: str) -> str by llm();

walker Explorer {
    has has_key: bool = False;
    can explore with `root entry;
}

impl Explorer.explore {
    current = [root --> (`?Room)][0];
    description = generate_room_description(current.description);
    print(f"Starting in room: {current.description} - {description}");

    while True {
        print("Available directions:");
        for next_room in [current ->:connected_to:-> (`?Room)] {
            desc = generate_room_description(next_room.description);
            print(f" - {next_room.description} - {desc}");
        }

        # Check for door in current room
        if current.has_door {
            doors = [root --> (`?Door)](?is_open == False);
            if len(doors) > 0 {
                print("There is a closed door here.");
                if self.has_key {
                    user_input = input("You have the key! Type 'open' to open the door or 'continue' to explore: ");
                    if user_input == "open" {
                        doors[0].is_open = True;
                        print("You opened the door! You finished the game.");
                        break;
                    }
                } else {
                    print("You need a key to open the door.");
                }
            }
        }

        if current.has_key and not self.has_key {
            keys_here = [root --> (`?Key)](?picked_up == False);
            if len(keys_here) > 0 {
                print("You found a key in this room!");
                user_input = input("Pick up the key? (yes/no): ");
                if user_input == "yes" {
                    keys_here[0].picked_up = True;
                    self.has_key = True;
                    print("You picked up the key!");
                }
            }
        }

        user_input = input("Where do you want to go? (type 'exit' to quit): ");
        if user_input == "exit" {
            print("Exiting the explorer. Goodbye!");
            break;
        }

        next_rooms = [r for r in [current ->:connected_to:-> (`?Room)] if r.description == user_input];
        if len(next_rooms) > 0 {
            current = next_rooms[0];
            print(f"You moved to: {current.description}");
        } else {
            print(f"Can't go to '{user_input}'. Try again.");
        }
    }
}

with entry {
    room1 = Room(description="Entrance Hall", has_key=False);
    room2 = Room(description="Kitchen");
    room3 = Room(description="Library", has_key=True);
    room4 = Room(description="Garden");
    room5 = Room(description="Gate", has_door=True);


    key1 = Key();
    door1 = Door();

    room1 +>:connected_to:+> room2;
    room2 +>:connected_to:+> room3;
    room3 +>:connected_to:+> room4;
    room4 +>:connected_to:+> room5;
    room5 +>:connected_to:+> room1;

    root ++> room1;
    root ++> room2;
    root ++> room3;
    root ++> room4;
    root ++> room5;
    root ++> key1;
    root ++> door1;

    root spawn Explorer();
}
