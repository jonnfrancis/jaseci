# Codebase Genius

Codebase Genius is a powerful tool designed to analyze GitHub repositories and generate high-quality documentation. It provides insights into the structure, purpose, and functionality of a codebase, making it easier for developers to understand and work with unfamiliar projects.

## Features
- **GitHub Repository Analysis**: Submit a GitHub repository URL to analyze its structure and generate documentation.
- **Documentation Generation**: Automatically creates markdown documentation with an overview, code summary, and API details.
- **Manifest Display**: Presents a detailed manifest of the repository, including file structure and metadata.
- **Chat History**: Displays the interaction history with Codebase Genius in the sidebar for easy reference.

## How to Use
1. **Launch the Application**: Run the Streamlit app to start Codebase Genius.
2. **Enter GitHub URL**: Input the URL of the GitHub repository you want to analyze.
3. **Analyze Repository**: Click the "Analyze repository" button to start the analysis.
4. **View Results**: The generated documentation and manifest will be displayed directly in the app.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/jonnfrancis/jaseci.git
   ```
2. Navigate to the `FE` directory:
   ```bash
   cd jaseci/agentic_codebase_genius/FE
   ```
3. Install the required dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Run the Streamlit app:
   ```bash
   streamlit run app.py
   ```

## Example Output
### Documentation
```
# Repo analysis for `example-repo`
## Overview
This repository is a Python-based web application with a focus on modular design and scalability.

## Code Summary
The codebase consists of 12 Python files, including modules for authentication, database management, and API handling.

## API Summary
| File       | Type     | Name       | Line | Args       | Doc                       |
|------------|----------|------------|------|------------|--------------------------|
| auth.py    | function | login      | 10   | username   | Handles user login.      |
| auth.py    | function | logout     | 25   |            | Logs out the user.       |
| database.py| class    | Database   | 5    | connection | Manages database queries.|
```

### Manifest
```json
{
  "repo": "example-repo",
  "generated_at": "2025-11-17T12:00:00Z",
  "docs": "outputs/example-repo/docs.md",
  "files": {
    "auth.py": {},
    "database.py": {}
  }
}
```

## Contributing
Contributions are welcome! Feel free to open issues or submit pull requests to improve Codebase Genius.

## License
This project is licensed under the MIT License.
