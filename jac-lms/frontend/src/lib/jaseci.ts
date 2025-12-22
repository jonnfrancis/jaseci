// src/lib/jaseci.ts

const JASECI_BASE_URL =
  import.meta.env.VITE_JASECI_URL || "http://localhost:8000";

/**
 * Frontend spawn abstraction.
 * Internally maps to POST /walker/<name>
 * 
 * RULE:
 * - All backend calls go through this function
 * - Components never call fetch directly
 */
export async function spawn<TResponse>(
  walker: string,
  payload: Record<string, unknown> = {},
  token?: string
): Promise<TResponse> {
  const res = await fetch(`${JASECI_BASE_URL}/walker/${walker}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(
      `Jaseci walker spawn failed [${walker}]: ${text}`
    );
  }

  return res.json() as Promise<TResponse>;
}
