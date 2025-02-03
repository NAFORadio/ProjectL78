#!/bin/bash

echo "🔍 Examining training data..."
head -n 1 combined_training.jsonl

echo -e "\n📝 Creating test conversion..."
python3 -c '
import json
import sys

# Read first line to determine format
with open("combined_training.jsonl", "r") as f:
    first_line = f.readline().strip()
    print("\nFirst line content:")
    print(first_line)
    
    try:
        data = json.loads(first_line)
        print("\nParsed JSON structure:")
        print(json.dumps(data, indent=2))
    except json.JSONDecodeError as e:
        print(f"\nError parsing JSON: {e}")
' 