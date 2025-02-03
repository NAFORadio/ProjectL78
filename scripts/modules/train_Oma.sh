#!/bin/bash

# Ensure survival knowledge directory exists
DATA_DIR=~/survival_ai_data/
mkdir -p $DATA_DIR

# Create and activate a virtual environment
VENV_DIR=~/survival_ai_env
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

# Install required Python libraries
pip install --upgrade pip
pip install pdfminer.six langchain chromadb

# Recursively find and extract text from PDFs
echo "Extracting survival knowledge from PDFs in all subdirectories..."
find $DATA_DIR -type f -name "*.pdf" | while read pdf; do
    txt_file="${pdf%.pdf}.txt"
    python3 -m pdfminer.high_level "$pdf" > "$txt_file"
    echo "Processed: $pdf -> $txt_file"
done

# Build vector database using ChromaDB
echo "Building knowledge base..."
python3 - <<EOF
import os
import chromadb
from langchain.vectorstores import Chroma
from langchain.embeddings import HuggingFaceEmbeddings

DATA_DIR = os.path.expanduser("~/survival_ai_data/")
vectorstore = Chroma(persist_directory=DATA_DIR)

text_files = []
for root, _, files in os.walk(DATA_DIR):
    for file in files:
        if file.endswith(".txt"):
            text_files.append(os.path.join(root, file))

for file in text_files:
    with open(file, "r") as f:
        content = f.read()
        vectorstore.add_texts([content])
        print(f"Added {file} to knowledge base.")

print("Training complete! Knowledge base updated.")
EOF

# Deactivate virtual environment
deactivate
