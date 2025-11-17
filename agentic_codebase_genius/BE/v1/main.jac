import from byllm.llm { Model }
import from email.mime.text { MIMEText }
import from dotenv { load_dotenv }
import smtplib;
import os;
include utils;
import py_modules;

glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

node Memory {}

node Session {
    has history: list = [];
    has created_at: str = get_current_datetime();

    def add_history(entry: str) {
        self.history = self.history + [entry];
    }
    def get_history -> str {
        return "\n".join(self.history[-10:]);
    }
}

node RepoMapper {
    has outputs_dir: str = "./outputs";

    def clone_and_map(url: str) -> dict {
        return py_modules.vcs.clone_repo(url);
    }

    def build_tree(path: str) -> dict {
        return py_modules.vcs.build_file_tree(path);
    }

    def summarize_readme(path: str) -> str {
        try {
            import os;
            readme_variations = ["README.md", "readme.md", "ReadMe.md", "README.txt"];
            readme_path = os.path.join(path, "README.md");

            for filename in readme_variations {
                readme_path = os.path.join(path, filename);
                if os.path.exists(readme_path) {
                    with open(readme_path, "r", encoding="utf-8") as fh {
                        summary = fh.read();
                        print(f"README Summary: {summary}");
                        return self.summarize_content(summary);
                    }
            }
            
            }  
            print("README.md not found.");
            return "No README.md file found in the repository.";
            
        } except Exception as e {
            print(f"Error summarizing README: {e}");
            return "Error occurred while summarizing the README.";
        }
    }
    def summarize_content(content: str) -> str by llm(
        method="ReAct"
    );
}
sem RepoMapper.summarize_content = "Analyze and provide a concise summary of 2000 characters of the given README content, focusing on the main purpose and features of the repository.";

node CodeAnalyzer {
    def analyze_repo(path: str) -> dict {
        entries = py_modules.parser.find_candidate_entrypoints(path);
        analyses = [];
        for e in entries {
            parsed = py_modules.parser.parse_python_file(e);
            analyses = analyses + [parsed];
        }
        summary = self.summarize_analysis(entries, analyses);
        return {
            "entries": entries,
            "analyses": analyses,
            "summary": summary
        };
    }

    def query_relationships(function_name: str) -> dict {
        return py_modules.parser.query_function_relationships(function_name);
    }

    def summarize_analysis(entries: list, analyses: list) -> str by llm(
        method="ReAct"
    );
}

sem CodeAnalyzer.summarize_analysis = """
Summarize the given code analysis data into a human-readable format. Include:
1. A brief overview of the number of files and functions analyzed.
2. Key functions or classes identified, along with their purpose (if available).
3. Any notable patterns or relationships between functions or classes.
4. Avoid listing raw paths unless necessary; focus on the content and structure.
""";

node DocGenie {
    has outputs_dir: str = "./outputs";

    def generate_docs(repo_name: str, summary: str, file_tree: dict, analyses: list, code_summary: str) -> dict {
        # Use byllm to refine the code summary and API summary
        refined_code_summary = self.refine_code_summary(code_summary);
        refined_api_summary = self.refine_api_summary(analyses);
        return py_modules.docgen.generate_markdown(repo_name, summary, file_tree, analyses, self.outputs_dir, refined_code_summary, refined_api_summary);
    }

    def refine_code_summary(code_summary: str) -> str by llm(
        method="ReAct"
    );

    def refine_api_summary(analyses: list) -> str by llm(
        method="ReAct"
    );
}
sem DocGenie.refine_code_summary = """
Refine the given code summary to make it more human-readable and insightful. Focus on:
1. Highlighting the main purpose of the codebase.
2. Summarizing key functionalities and their significance.
3. Avoiding technical jargon unless necessary.
""";
sem DocGenie.refine_api_summary = """
Generate a human-readable API summary from the given analysis data. Include:
1. A brief overview of the analyzed files and their purpose.
2. Key functions and classes, their arguments, and their roles.
3. Relationships between functions and classes, if any.
4. Avoid listing raw paths unless necessary; focus on the content.
""";

walker code_genius {
    has github_url: str = "";
    has session_id: str = "";

    obj __specs__ {
        static has auth: bool = False;
    }

    can execute with `root entry {
        print("Starting code genius workflow...");
        if not self.github_url {
            print("Error: No GitHub URL provided.");
            report {"status": "error", "error": "No GitHub URL provided"};
            disengage;
        }

        # Step 1: Delegate to Repo Mapper
        print("Cloning and mapping repository...");
        repo_mapper = RepoMapper();
        cloned = repo_mapper.clone_and_map(self.github_url);
        if not cloned["ok"] {
            report {"status": "error", "error": cloned["error"]};
            disengage;
        }
        print("Repository cloned successfully.");

        path = cloned["path"];
        print("Building file tree and summarizing README...");
        file_tree = repo_mapper.build_tree(path);
        readme_summary = repo_mapper.summarize_readme(path);
        print("File tree built and README summarized.");

        # Step 2: Delegate to Code Analyzer
        print("Analyzing codebase...");
        code_analyzer = CodeAnalyzer();
        analysis = code_analyzer.analyze_repo(path);
        print("Codebase analysis completed.");

        # Step 3: Delegate to DocGenie
        print("Generating documentation with DocGenie...");
        doc_genie = DocGenie();
        docs = doc_genie.generate_docs(
            repo_name=self.github_url.split("/")[-1].replace(".git", ""),
            summary=readme_summary,
            file_tree=file_tree,
            code_summary=analysis["summary"],
            analyses=analysis["analyses"]
        );
        print("Documentation generation completed.");

        # Step 4: Cleanup and Report
        print("Cleaning up temporary files...");
        py_modules.vcs.cleanup_path(path);
        print("Cleanup completed.");

        report {
            "status": "ok",
            "docs_content": docs["docs_content"],
            "manifest_content": docs["manifest_content"]
        };
        print("Code genius workflow completed successfully.");
    }
}

with entry {
    load_dotenv();
}