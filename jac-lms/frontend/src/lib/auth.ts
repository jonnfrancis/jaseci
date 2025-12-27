const BASE_URL = import.meta.env.VITE_JASECI_URL || "http://localhost:8000";

export async function login(user_id: string, username: string, password: string) {
  const res = await fetch(`${BASE_URL}/user/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id, username, password }),
  });

  if (!res.ok) throw new Error("Login failed");
  return res.json(); // token, user info
}

export async function createUser(user_id: string, username: string, password: string) {
  const res = await fetch(`${BASE_URL}/user/create`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id, username, password }),
  });

  if (!res.ok) throw new Error("User creation failed");
  return res.json(); // token, user info
}
