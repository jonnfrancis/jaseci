with entry {
    name: str = "John Francis";
    count: int = 1;
    age: int = 23;
    height: float = 5.12;
    is_student: bool = True;

    if is_student and age>=18 {
        print(f"{name} is {age} years old, {height} feet tall, not only is he a student but also an adult.");
    } else {
        print(f"{name} is {age} years old, {height} feet tall, he is a student but not an adult.");
    }

    while count <= 5 {
        print(f"Count is at: {count}");
        count = count + 1;
    }

    print("Done counting now let us loop!");

    fruits = ["Apples", "Oranges", "Artichokes"];

    for fruit in fruits {
        print(f"I like {fruit}");
    }
}