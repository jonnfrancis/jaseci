import { useState } from "react";
import Button from "../components/Button";
import { v4 as uuidv4 } from 'uuid';
import { useNavigate } from "react-router-dom";
import { createUser, login } from "../lib/auth";
import { spawn } from "../lib/jaseci";

function UserAuth() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [token, setToken] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  // Create user by calling backend /user/create
  async function createNewUser() {
    const userId = uuidv4();
    const data = await createUser(userId, username, password);

    if (userId) {
        localStorage.setItem("userId", userId);
        setMessage("User created successfully! User ID stored.");
    }

    if (data?.token) {
        localStorage.setItem("token", data.token);
        setToken(data.token);
        setMessage("User created successfully! Token stored.");
    }

    if (data?.username) {
        localStorage.setItem("username", data.username);
        setUsername(data.username);
        setMessage((prev) => prev + " Username stored.");
    }

    try {
        spawn("initialize_learning_graph", { user: { user_id: userId, name: username } });
        setMessage((prev) => prev + " Learning graph initialized.");
    } finally {
        // redirect to learn page or other actions can be added here
        navigate("/learn");

    }
  }

  // Login user by calling backend /user/login and store auth token
  async function loginExistingUser() {
    const data = await login(localStorage.getItem("userId") || "", username, password);

    if (data?.token) {
        localStorage.setItem("token", data.token);
        setToken(data.token);
        setMessage("Login successful! Token stored.");
    }
    if (data?.username) {
        localStorage.setItem("username", data.username);
        setUsername(data.username);
        setMessage((prev) => prev + " Username stored.");
    }

    // redirect to learn page or other actions can be added here
    navigate("/learn");

  }

  return (
    <div className="h-dvh w-full flex flex-col items-center justify-center">
      <h2>User Registration & Login</h2>

      <input
        type="text"
        placeholder="Username"
        value={username}
        onChange={(e) => setUsername(e.target.value)}
      />
      <input
        type="password"
        placeholder="Password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />

      <Button className="m-2" onClick={createNewUser}>Create User</Button>
      <Button className="m-2" onClick={loginExistingUser}>Login</Button>

      {message && <p>{message}</p>}
      {token && <p>Your auth token: {token}</p>}
    </div>
  );
}

export default UserAuth;
