#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
set -e

# Parse arguments
tool="opencode"
max_iterations=10
yolo_mode=true
model="github-copilot/gpt-4o"

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-yolo)
      yolo_mode=false
      shift
      ;;
    --model)
      model="$2"
      shift 2
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        max_iterations="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$tool" != "copilot" && "$tool" != "opencode" ]]; then
  echo "Error: Invalid tool '$tool'. Must be 'copilot' or 'opencode'."
  exit 1
fi
# Determine project root
# First check if we're already in a directory with .scratch/ralph/prd.json
if [ -f "./.scratch/ralph/prd.json" ]; then
  project_root="$(pwd)"
  echo $project_root
else
  echo "No prd to run a ralph loop on"
  exit 1
fi
script_dir="$project_root/.scratch/ralph"
prd_file="$script_dir/prd.json"
progress_file="$script_dir/progress.txt"
archive_dir="$script_dir/archive"
last_branch_file="$script_dir/.last-branch"

# Track current branch
if [ -f "$prd_file" ]; then
  current_branch=$(jq -r '.branchName // empty' "$prd_file" 2>/dev/null || echo "")
  if [ -n "$current_branch" ]; then
    echo "$current_branch" > "$last_branch_file"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$progress_file" ]; then
  echo "# Ralph Progress Log" > "$progress_file"
  echo "Started: $(date)" >> "$progress_file"
  echo "---" >> "$progress_file"
fi

echo "Starting Ralph - Tool: $tool - Max iterations: $max_iterations - Model: $model"
echo "Project root: $project_root"
echo "PRD location: $prd_file"

# Change to project root so opencode runs in the right directory
cd "$project_root"

# Clear opencode environment variables to avoid conflicts when running nested opencode
unset OPENCODE
unset OPENCODE_SERVER_PASSWORD

# Set YOLO mode (allow all permissions) by default
if [ "$yolo_mode" = true ]; then
  export OPENCODE_PERMISSION='{"*":"allow"}'
  echo "YOLO mode enabled - all permissions allowed"
fi

for i in $(seq 1 $max_iterations); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $max_iterations ($tool)"
  echo "==============================================================="

   # Create a temp file for output
   OUTPUT_FILE=$(mktemp)
   opencode run -m "$model" 'use the "ralph implementer" skill to work on the current prd for one task only' 2>&1 | tee "$OUTPUT_FILE" || true
   OUTPUT=$(cat "$OUTPUT_FILE")
   rm -f "$OUTPUT_FILE"
  
  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $max_iterations"
    exit 0
  fi
  
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($max_iterations) without completing all tasks."
echo "Check $progress_file for status."
exit 1
