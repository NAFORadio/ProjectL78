#!/bin/bash

echo "🔄 Starting training process..."

# Check if files exist
if [ ! -f "combined_training.jsonl" ]; then
    echo "❌ Error: combined_training.jsonl not found"
    exit 1
fi

if [ ! -f "Modelfile" ]; then
    echo "❌ Error: Modelfile not found"
    exit 1
fi

echo "📝 Converting training data format..."

# Convert JSONL to Ollama format
python3 -c '
import json
import sys

try:
    with open("combined_training.jsonl", "r") as f:
        data = []
        for line in f:
            try:
                item = json.loads(line.strip())
                data.append({
                    "prompt": f"Question: {item.get(\"instruction\", \"\")} {item.get(\"input\", \"\")}\nAnswer:",
                    "response": item.get("output", "")
                })
            except json.JSONDecodeError as e:
                print(f"Warning: Skipping invalid JSON line: {e}")
                continue

    print(f"Processed {len(data)} training examples")

    with open("training_formatted.jsonl", "w") as f:
        for item in data:
            json.dump(item, f)
            f.write("\n")

except Exception as e:
    print(f"Error: {str(e)}")
    sys.exit(1)
'

echo "🚀 Creating model..."
ollama create epicor-assistant -f Modelfile

echo "✨ Training complete!"
echo ""
echo "To test the model, run:"
echo "ollama run epicor-assistant \"Your question here\"" 