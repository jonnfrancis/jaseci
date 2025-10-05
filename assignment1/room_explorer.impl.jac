
impl Room.enter {
    # describe the room
    print(f"You are in the {here.name}. {here.description}");

    # if there is a key in this room, offer to pick it up
    if here.has_key_here {
        ans = input("You see a small key on the floor. Take it? (y/n) ");
        if ans.startswith("y") {
            visitor.picked_key = True;
            here.has_key_here = False;
            print("You picked up the key.");
        }
    }

    # special behavior for the gate (final room)
    if here.name == "Gate" {
        if visitor.picked_key {
            print("You use the key. The gate opens — you win!");
            disengage;
        } else {
            print("The gate is locked. You need a key to open it.");
            disengage;
        }
    }

    # otherwise, move to next connected room
    visit [-->];
}

impl Explorer.start {
    visit [-->];
}
