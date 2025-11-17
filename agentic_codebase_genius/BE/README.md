# Codebase Genius - byLLM Project

This is the **byLLM (Multi-Tool Prompting)** implementation of the Codebase Genius. It demonstrates how to build an agentic application using a toolbox + tool-based approach within JacLang.

---

## Setup Instructions

Follow the steps below to set up and run the Codebase Genius using byLLM.

### 1. Clone the Repository

```bash
git clone https://github.com/jonnfrancis/jaseci.git
cd agentic_codebase_genius
```

### 2. Clone the Repository

```bash
cd BE/v1
```

### 3. Create a Virtual Environment and Activate It

```bash
python3 -m venv venv
source venv/bin/activate     # On Windows: venv\Scripts\activate
```

### 4. Create a Virtual Environment and Activate It

Create a .env file in the byllm directory and set the required variables there.
At minimum, you’ll need to provide your LLM provider key (for example, OpenAI):

```bash
export GEMINI_API_KEY=sk-xxxxx
```

### 5. Install Required Packages

You can either install directly:

```bash
pip install byllm jac-cloud
```

Or use the provided requirements file:

```bash
pip install -r requirements.txt
```

### 7. Run the Application

```bash
jac serve main.jac
```

This will start a local server with the defined walkers.

## Using the Application

### Codebase Genius Agent Walker

Start a new session by sending a request to:

```http
POST /walker/code_genius
```

Sample JSON Payload

```json
{
  "url": "github.com/...",
  "session_id": ""
}
```

- For the first message, set "session_id": "".
- The system will return a new session ID.
- Use that session ID for all subsequent messages to continue the conversation.

### Get All Sessions

List all session IDs by calling:

```http
POST /walker/get_all_sessions
````
