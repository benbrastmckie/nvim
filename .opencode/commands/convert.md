---
description: Convert documents between formats (PDF/DOCX to Markdown, Markdown to PDF)
---

# Command: /convert

**Purpose**: Convert documents between formats by delegating to document converter skill/agent chain  
**Layer**: 2 (Command File - Argument Parsing Agent)  
**Delegates To**: skill-document-converter

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Extract source_path from args[0]
    Extract output_path from args[1] (optional)
    
    If source_path missing: Return error "Usage: /convert SOURCE_PATH [OUTPUT_PATH]"
  </step_1>
  
  <step_2>
    Generate Session ID:
    session_id = sess_{timestamp}_{random}
  </step_2>
  
  <step_3>
    Validate source file:
    - Convert to absolute path if relative
    - Check file exists
    - Determine file extension
  </step_3>
  
  <step_4>
    Determine output path:
    If output_path not provided:
    - Infer from source extension
    - PDF/DOCX/XLSX/PPTX/HTML/Images -> .md
    - Markdown -> .pdf
    - Convert to absolute path
  </step_4>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Validate Input</action>
    <validation>
      - source_path exists
      - source format supported
      - output directory writable
    </validation>
    <on_failure>
      Return error with specific guidance
    </on_failure>
  </step_1>

  <step_2>
    <action>Delegate to Document Converter</action>
    <input>
      - skill: "skill-document-converter"
      - args: "source_path={source_path} output_path={output_path} session_id={session_id}"
    </input>
    <expected_return>
      {
        "status": "converted" | "partial" | "failed",
        "output_path": "...",
        "tool_used": "...",
        "output_size": "...",
        "error_message": "..."
      }
    </expected_return>
  </step_2>

  <step_3>
    <action>Validate Output</action>
    <validation>
      - Output file exists
      - Output file not empty
    </validation>
    <on_failure>
      Log warning, continue with partial result
    </on_failure>
  </step_3>

  <step_4>
    <action>Optional Git Commit</action>
    <process>
      Commit only if requested or part of task workflow
    </process>
  </step_4>

  <step_5>
    <action>Return Result</action>
    <output>
      Display conversion result:
      - Source and output paths
      - Tool used
      - File size
      - Status
      
      Return to orchestrator
    </output>
  </step_5>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - Source not found -> Return error with path
    - Unsupported format -> Return error with supported list
  </argument_errors>
  
  <execution_errors>
    - Skill failure -> Return error message
    - Tool not available -> Return installation guidance
    - Output creation failure -> Return error with troubleshooting
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    source_file (for validation)
  </reads>
  
  <writes>
    None (skill handles output file creation)
  </writes>
</state_management>