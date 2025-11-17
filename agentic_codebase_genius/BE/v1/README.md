# Codebase Genius Backend

The backend for Codebase Genius is built using Jac, a high-level language for creating AI-driven workflows. This backend is responsible for analyzing GitHub repositories, generating documentation, and managing the workflow for Codebase Genius.

## Features
- **Repository Cloning and Mapping**: Clones GitHub repositories and generates a structured file tree.
- **Code Analysis**: Analyzes Python and Jac files to extract key functions, classes, and relationships.
- **Documentation Generation**: Produces high-quality markdown documentation, including an overview, code summary, and API details.
- **Integration with Frontend**: Communicates with the Streamlit frontend to display results in real-time.

## Workflow
1. **Repo Mapper**:
   - Clones the repository.
   - Builds a file tree representation.
   - Summarizes the README file (if available).
2. **Code Analyzer**:
   - Parses source files to extract functions, classes, and their relationships.
   - Generates a code context graph for deeper insights.
3. **DocGenie**:
   - Synthesizes the analysis into a well-structured markdown document.
   - Includes sections for project overview, installation, usage, and API reference.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/jonnfrancis/jaseci.git
   ```
2. Navigate to the backend directory:
   ```bash
   cd jaseci/agentic_codebase_genius/BE/v1
   ```
3. Install the required dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Start the Jac server:
   ```bash
   jac serve main.jac
   ```

## Example Usage
1. Start the backend server using the command above.
2. Use the Streamlit frontend to interact with the backend:
   - Enter a GitHub repository URL.
   - Analyze the repository.
   - View the generated documentation and manifest.

## File Structure
- `main.jac`: The main Jac file containing the workflow logic.
- `py_modules/`: Python modules for repository cloning, code analysis, and documentation generation.
- `outputs/`: Directory where generated documentation and manifests are stored.

## Contributing
Contributions are welcome! Feel free to open issues or submit pull requests to improve the backend functionality.

## License
This project is licensed under the MIT License.
