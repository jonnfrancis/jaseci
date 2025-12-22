import { useState } from "react";
import Editor from "@monaco-editor/react";
import Button from "./Button";

interface Props {
  onRun: (code: string) => void;
  loading: boolean;
  starterCode?: string;
}

export default function CodeWorkspace({ onRun, loading, starterCode }: Props) {
  const [code, setCode] = useState<string>(starterCode || `walker hello_world {
  can run with entry {
    report "Hello from Jaseci!";
  }
}`);

  return (
    <main className="col-span-6 bg-surface rounded-xl p-4 flex flex-col">
      <div className="flex justify-between items-center mb-2">
        <h2 className="text-lg font-semibold">Editor</h2>

        <Button
          onClick={() => onRun(code)}
          disabled={loading}
          variant="secondary"
        >
          {loading ? "Running..." : "Run"}
        </Button>
      </div>

      <div className="flex-1 rounded-lg overflow-hidden">
        <Editor
          height="100%"
          theme="vs-dark"
          defaultLanguage="plaintext"
          value={code}
          onChange={(value) => setCode(value || "")}
          options={{
            fontSize: 14,
            minimap: { enabled: false },
            automaticLayout: true,
            wordWrap: "on",
          }}
        />
      </div>
    </main>
  );
}
