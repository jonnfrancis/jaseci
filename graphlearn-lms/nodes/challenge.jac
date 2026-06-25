"""Challenge domain node."""

import from nodes.lesson { Difficulty }

node Challenge {
    has id: str;
    has title: str;
    has description: str;
    has skillId: str;
    has difficulty: Difficulty;
}
