import streamlit as st
import requests
import time
from streamlit.components.v1 import html as components_html

# --- PAGE CONFIG ---
st.set_page_config(
    page_title="Codebase Genius",
    layout="wide",
)

# --- CSS STYLING ---
st.markdown("""
    <style>
        /* Make the chat container wider and centered */
        .main > div {
            max-width: 1000px;
            padding-left: 50px;
            padding-right: 50px;
        }

        /* Full height layout */
        .block-container {
            display: flex;
            flex-direction: column;
            height: 100vh;
            padding-top: 1rem;
            padding-bottom: 0;
        }

        /* Ensure tabs stay at top */
        .stTabs {
            position: sticky;
            top: 0;
            z-index: 100;
            background-color: white;
            padding-bottom: 1rem;
        }

        /* Chat wrapper with proper flex layout */
        .chat-wrapper {
            display: flex;
            flex-direction: column;
            height: calc(100vh - 200px);
            overflow: hidden;
        }

        /* Scrollable chat messages area */
        .chat-scroll {
            flex: 1;
            overflow-y: auto;
            padding: 1rem 0;
            margin-bottom: 1rem;
            max-height: calc(100vh - 300px);
        }

        .chat-input {
            position: absolute;
            bottom: 0;
            left: 0;
            width: 100%;
            background-color: white;
            padding: 1rem 0;
            border-top: 1px solid #e0e0e0;
            z-index: 50;
        }

        /* Style adjustments for better spacing */
        .stChatInput {
            margin: 0 !important;
        }

        /* Custom scrollbar for chat area */
        .chat-scroll::-webkit-scrollbar {
            width: 8px;
        }

        .chat-scroll::-webkit-scrollbar-track {
            background: #f1f1f1;
            border-radius: 4px;
        }

        .chat-scroll::-webkit-scrollbar-thumb {
            background: #888;
            border-radius: 4px;
        }

        .chat-scroll::-webkit-scrollbar-thumb:hover {
            background: #555;
        }

        /* Ensure message spacing */
        .stChatMessage {
            margin-bottom: 1rem;
        }
    </style>
""", unsafe_allow_html=True)

# --- CONSTANTS ---
BASE_URL = "http://localhost:8000"

# --- SESSION STATE INIT ---
if 'session_id' not in st.session_state:
    st.session_state.session_id = ""
if 'chat_history' not in st.session_state:
    st.session_state.chat_history = []

with st.sidebar:
    st.title("Session Management")
    if st.button("Start New Session"):
        # Just reset the virtual session and chat history
        st.session_state.session_id = ""
        st.session_state.chat_history = []
        st.success("Virtual session reset!")

# --- TITLE ---
st.title("Codebase Genius")

# --- CODEBASE GENIUS TAB ---
st.header("Codebase Genius — Repo Analyzer")
github_url = st.text_input("GitHub repo URL (https://github.com/owner/repo):")
if st.button("Analyze repository"):
    if not github_url:
        st.error("Enter a GitHub URL first.")
    else:
        with st.spinner("Submitting repo for analysis..."):
            st.session_state.chat_history.append({"role": "user", "content": github_url})
            # If no session_id, create session with first message
            if not st.session_state.session_id:
                payload = {"github_url": github_url, "session_id": ""}
            else:
                payload = {"github_url": github_url, "session_id": st.session_state.session_id}
            res = requests.post(f"{BASE_URL}/walker/code_genius", json=payload)
            if res.status_code == 200:
                data = res.json()
                # We expect { "reports": [ { "status":"ok", "docs_content":"...", "manifest_content":"..." } ] } format
                reports = data.get("reports", [])
                if reports:
                    r0 = reports[0]
                    if r0.get("status") == "ok":
                        st.session_state.docs_content = r0.get("docs_content")
                        st.session_state.manifest_content = r0.get("manifest_content")
                        st.success("Documentation and manifest generated successfully!")

                        # Automatically display the content
                        docs_content = st.session_state.docs_content
                        manifest_content = st.session_state.manifest_content

                        try:
                            # Render documentation with markdown styling
                            st.subheader("Documentation")
                            st.markdown(docs_content, unsafe_allow_html=True)

                            # Render manifest as formatted JSON
                            st.subheader("Manifest")
                            st.json(manifest_content)

                        except Exception as e:
                            st.error(f"An error occurred while displaying the content: {e}")
                    else:
                        st.error(f"Analysis failed: {r0.get('error')}")
                else:
                    st.error("No response from server.")
            else:
                st.error(f"Error posting to server: {res.status_code}")

