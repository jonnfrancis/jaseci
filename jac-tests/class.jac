class Dog {
    has name: str  = "Unnamed";
    has age: int = 0;

    def bark {
        print(f"{self.name} says woof!");
    }
}

with entry {
    my_dog = Dog();
    my_dog.name = "Bosco";
    my_dog.age = 8;

    your_dog = Dog();
    your_dog.name = "Shadow";
    your_dog.age = 10;

    my_dog.bark();
    your_dog.bark();

    print(f"{my_dog.name} is {my_dog.age} years old");
}