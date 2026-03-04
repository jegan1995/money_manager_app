#!/bin/bash

OUTPUT_FILE="all_code_combined.txt"
> "$OUTPUT_FILE"

# Base directory
BASE_DIR="/workspaces/money_manager_app"

# Function to append file with header
append_file() {
    local filepath="$1"
    if [ -f "$filepath" ]; then
        echo "================================================================" >> "$OUTPUT_FILE"
        echo "FILE: $filepath" >> "$OUTPUT_FILE"
        echo "================================================================" >> "$OUTPUT_FILE"
        cat "$filepath" >> "$OUTPUT_FILE"
        echo -e "\n" >> "$OUTPUT_FILE"
    fi
}

# All lib files
find "$BASE_DIR/lib" -type f | sort | while read -r file; do
    append_file "$file"
done

# Root config files
append_file "$BASE_DIR/pubspec.yaml"
append_file "$BASE_DIR/codemagic.yaml"
append_file "$BASE_DIR/firestore.rules"

echo "Done! Output saved to $OUTPUT_FILE"
echo "Total size: $(wc -l < $OUTPUT_FILE) lines"