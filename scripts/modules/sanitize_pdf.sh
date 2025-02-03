#!/bin/bash
# PDF Data Sanitization Script for TinyLlama Training

# Set up error handling
set -e
set -o pipefail

# Configuration
MAX_CHUNK_SIZE=4096      # Maximum tokens per chunk
MIN_CHUNK_SIZE=10        # Minimum tokens per chunk
VALIDATION_SPLIT=0.2     # 20% for validation
OUTPUT_FORMAT="jsonl"    # jsonl or json
CLEAN_LEVEL="strict"     # basic, normal, or strict
PRESERVE_FORMATTING=true
HANDLE_TABLES=true
HANDLE_IMAGES=false  # Images require additional processing
SUPPORTED_FORMATS=("pdf" "docx" "txt" "rtf" "odt")
TRAINING_DIR="$HOME/training_output"  # Change this to your preferred location

# Check dependencies
check_dependencies() {
    local deps=(pdftotext python3 pip unrtf odt2txt)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "❌ Required dependency not found: $dep"
            case "$dep" in
                "pdftotext")
                    sudo apt-get update && sudo apt-get install -y poppler-utils
                    ;;
                "unrtf")
                    sudo apt-get update && sudo apt-get install -y unrtf
                    ;;
                "odt2txt")
                    sudo apt-get update && sudo apt-get install -y odt2txt
                    ;;
            esac
        fi
    done

    # Install Python dependencies
    pip install --quiet transformers nltk pandas tqdm scikit-learn \
        python-docx pillow pytesseract striprtf odfpy
}

# Create Python script for text processing
create_processor() {
cat > process_text.py << 'EOF'
import sys
import re
import nltk
import json
import random
from nltk.tokenize import sent_tokenize
from tqdm import tqdm
from sklearn.model_selection import train_test_split

# Download and verify NLTK data
def ensure_nltk_data():
    required_data = ['punkt', 'averaged_perceptron_tagger', 'punkt_tab']
    for data in required_data:
        try:
            nltk.data.find(f'tokenizers/{data}')
        except LookupError:
            print(f"Downloading {data}...")
            nltk.download(data)

# Initialize NLTK
ensure_nltk_data()

def split_into_chunks(text, max_length=2048):
    """Split text into chunks of maximum token length."""
    sentences = sent_tokenize(text)
    chunks = []
    current_chunk = []
    current_length = 0
    
    for sentence in sentences:
        sentence_length = len(sentence.split())
        if current_length + sentence_length > max_length:
            if current_chunk:
                chunks.append(' '.join(current_chunk))
            current_chunk = [sentence]
            current_length = sentence_length
        else:
            current_chunk.append(sentence)
            current_length += sentence_length
    
    if current_chunk:
        chunks.append(' '.join(current_chunk))
    
    return chunks

class TextCleaner:
    def __init__(self, clean_level='normal'):
        self.clean_level = clean_level
        
    def clean_text(self, text):
        if self.clean_level == 'basic':
            return self._basic_clean(text)
        elif self.clean_level == 'normal':
            return self._normal_clean(text)
        else:
            return self._strict_clean(text)
    
    def _basic_clean(self, text):
        # Basic cleaning
        text = re.sub(r'\s+', ' ', text)
        text = re.sub(r'\f', ' ', text)
        return text.strip()
    
    def _normal_clean(self, text):
        # Normal cleaning
        text = self._basic_clean(text)
        text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\xff]', '', text)
        text = re.sub(r'^\s*\d+\s*$', '', text, flags=re.MULTILINE)
        text = re.sub(r'(?<=[.!?])\s+(?=[A-Z])', '\n', text)
        return text.strip()
    
    def _strict_clean(self, text):
        # Strict cleaning
        text = self._normal_clean(text)
        text = re.sub(r'[^\w\s.!?,;:\-\'\"()]', '', text)
        text = re.sub(r'(\w+)([.!?])', r'\1 \2', text)
        text = re.sub(r'\s+([.!?,;:])', r'\1', text)
        return text.strip()

def create_training_examples(chunks):
    examples = []
    
    # Example templates
    templates = [
        {
            "instruction": "Summarize the following text:",
            "response_prefix": "Here's a summary:"
        },
        {
            "instruction": "Extract key points from this text:",
            "response_prefix": "Key points:"
        },
        {
            "instruction": "Explain the main concepts in this text:",
            "response_prefix": "The main concepts are:"
        }
    ]
    
    for chunk in chunks:
        for template in templates:
            example = {
                "instruction": template["instruction"],
                "input": chunk,
                "response": f"{template['response_prefix']}\n{chunk[:100]}...",
                "meta": {"source": "pdf_training", "template": template["instruction"]}
            }
            examples.append(example)
    
    return examples

def validate_chunk(chunk):
    """Validate if a chunk is suitable for training."""
    # Minimum word count (more lenient)
    if len(chunk.split()) < 10:  # Changed from MIN_CHUNK_SIZE
        return False
    
    # Check for meaningful content (at least one sentence-ending punctuation)
    if not any(p in chunk for p in '.!?'):
        return False
    
    # Check for common Epicor terms to validate relevance
    epicor_terms = ['epicor', 'menu', 'screen', 'field', 'button', 'click', 'select', 'enter', 
                    'form', 'window', 'process', 'transaction', 'record', 'system', 'module']
    if not any(term in chunk.lower() for term in epicor_terms):
        return False
    
    # Remove strict quote/parentheses balance check
    # if chunk.count('"') % 2 != 0 or chunk.count('(') != chunk.count(')'):
    #     return False
    
    return True

def process_file(content, clean_level, min_chunk_size, output_format):
    cleaner = TextCleaner(clean_level)
    cleaned = cleaner.clean_text(content)
    
    # Split into chunks
    chunks = split_into_chunks(cleaned, int(sys.argv[1]))  # MAX_CHUNK_SIZE
    
    # Validate chunks
    valid_chunks = [c for c in chunks if validate_chunk(c)]
    
    if not valid_chunks:
        print("⚠️  Warning: No valid text chunks found in document", file=sys.stderr)
        return {
            'train': '',
            'val': ''
        }
    
    # Create training examples
    examples = create_training_examples(valid_chunks)
    
    if not examples:
        print("⚠️  Warning: No training examples created", file=sys.stderr)
        return {
            'train': '',
            'val': ''
        }
    
    # Split into train/validation sets
    train, val = train_test_split(examples, test_size=float(sys.argv[3]))  # VALIDATION_SPLIT
    
    # Format output
    if output_format == 'jsonl':
        return {
            'train': '\n'.join(json.dumps(ex) for ex in train),
            'val': '\n'.join(json.dumps(ex) for ex in val)
        }
    else:
        return {
            'train': train,
            'val': val
        }

if __name__ == "__main__":
    content = sys.stdin.read()
    result = process_file(content, sys.argv[4], int(sys.argv[2]), sys.argv[5])
    
    if sys.argv[5] == 'jsonl':
        print(result['train'])
        with open(sys.argv[6] + '.val.jsonl', 'w') as f:
            f.write(result['val'])
    else:
        json.dump(result, sys.stdout, indent=2)
EOF
}

# Create enhanced Python document processor
create_doc_processor() {
cat > doc_processor.py << 'EOF'
from docx import Document
from docx.table import Table
from PIL import Image
import pytesseract
import sys
import os
import json
from odf import text, teletype
from odf.opendocument import load

class DocumentProcessor:
    def __init__(self, preserve_formatting=True, handle_tables=True, handle_images=False):
        self.preserve_formatting = preserve_formatting
        self.handle_tables = handle_tables
        self.handle_images = handle_images

    def process_docx(self, path):
        doc = Document(path)
        content = []
        
        for element in doc.element.body:
            if element.tag.endswith('p'):
                # Paragraph processing
                para = doc.element.xpath('//w:p')[0]
                text = self._process_paragraph(para)
                if text.strip():
                    content.append({
                        'type': 'paragraph',
                        'text': text,
                        'formatting': self._extract_formatting(para) if self.preserve_formatting else {}
                    })
            elif element.tag.endswith('tbl') and self.handle_tables:
                # Table processing
                table = self._process_table(element)
                content.append({
                    'type': 'table',
                    'content': table
                })
            elif self.handle_images and element.tag.endswith('drawing'):
                # Image processing
                image_text = self._process_image(element)
                if image_text:
                    content.append({
                        'type': 'image',
                        'text': image_text
                    })
        
        return content

    def _process_paragraph(self, para):
        runs = para.findall('.//w:t')
        return ' '.join(r.text for r in runs)

    def _extract_formatting(self, para):
        formatting = {
            'style': para.style.name if para.style else 'Normal',
            'alignment': para.alignment,
            'indentation': {
                'left': para.paragraph_format.left_indent,
                'right': para.paragraph_format.right_indent,
                'first_line': para.paragraph_format.first_line_indent
            }
        }
        return formatting

    def _process_table(self, table_elem):
        table = []
        for row in table_elem.rows:
            row_data = []
            for cell in row.cells:
                cell_text = ' '.join(p.text for p in cell.paragraphs)
                row_data.append(cell_text)
            table.append(row_data)
        return table

    def _process_image(self, image_elem):
        try:
            image_path = image_elem.get('src')
            if image_path and os.path.exists(image_path):
                return pytesseract.image_to_string(Image.open(image_path))
        except Exception as e:
            print(f"Warning: Could not process image: {e}", file=sys.stderr)
        return None

    def process_rtf(self, path):
        with open(path, 'r', encoding='utf-8') as f:
            rtf_content = f.read()
        # Process RTF content
        # Implementation depends on the RTF library used

    def process_odt(self, path):
        textdoc = load(path)
        allparas = textdoc.getElementsByType(text.P)
        return '\n'.join(teletype.extractText(para) for para in allparas)

EOF
}

# Process a single PDF file
process_pdf() {
    local input_file="$1"
    local base_name="${input_file%.pdf}"
    local temp_txt="/tmp/pdf_text_$RANDOM.txt"

    echo "📄 Processing: $input_file"
    
    # Convert PDF to text
    pdftotext -layout "$input_file" "$temp_txt"
    
    # Process the text
    python3 process_text.py \
        "$MAX_CHUNK_SIZE" \
        "$MIN_CHUNK_SIZE" \
        "$VALIDATION_SPLIT" \
        "$CLEAN_LEVEL" \
        "$OUTPUT_FORMAT" \
        "$base_name" < "$temp_txt" > "${base_name}.${OUTPUT_FORMAT}"
    
    # Cleanup
    rm "$temp_txt"
    
    echo "✅ Created: ${base_name}.${OUTPUT_FORMAT}"
    if [ -f "${base_name}.val.${OUTPUT_FORMAT}" ]; then
        echo "✅ Created validation set: ${base_name}.val.${OUTPUT_FORMAT}"
    fi
}

# Add DOCX processing function
process_docx() {
    local input_file="$1"
    local base_name="${input_file%.docx}"
    local temp_txt="/tmp/docx_text_$RANDOM.txt"

    echo "📄 Processing DOCX: $input_file"
    
    # Create Python script for DOCX conversion
    cat > convert_docx.py << 'EOF'
from docx import Document
import sys

def extract_text_from_docx(docx_path):
    doc = Document(docx_path)
    full_text = []
    for para in doc.paragraphs:
        full_text.append(para.text)
    return '\n'.join(full_text)

if __name__ == "__main__":
    docx_path = sys.argv[1]
    text = extract_text_from_docx(docx_path)
    print(text)
EOF

    # Convert DOCX to text
    python3 convert_docx.py "$input_file" > "$temp_txt"
    
    # Process the text
    python3 process_text.py \
        "$MAX_CHUNK_SIZE" \
        "$MIN_CHUNK_SIZE" \
        "$VALIDATION_SPLIT" \
        "$CLEAN_LEVEL" \
        "$OUTPUT_FORMAT" \
        "$base_name" < "$temp_txt" > "${base_name}.${OUTPUT_FORMAT}"
    
    # Cleanup
    rm "$temp_txt" convert_docx.py
    
    echo "✅ Created: ${base_name}.${OUTPUT_FORMAT}"
    if [ -f "${base_name}.val.${OUTPUT_FORMAT}" ]; then
        echo "✅ Created validation set: ${base_name}.val.${OUTPUT_FORMAT}"
    fi
}

# Add new format processors
process_txt() {
    local input_file="$1"
    local base_name="${input_file%.txt}"
    
    echo "📄 Processing TXT: $input_file"
    python3 process_text.py \
        "$MAX_CHUNK_SIZE" \
        "$MIN_CHUNK_SIZE" \
        "$VALIDATION_SPLIT" \
        "$CLEAN_LEVEL" \
        "$OUTPUT_FORMAT" \
        "$base_name" < "$input_file" > "${base_name}.${OUTPUT_FORMAT}"
}

process_rtf() {
    local input_file="$1"
    local base_name="${input_file%.rtf}"
    local temp_txt="/tmp/rtf_text_$RANDOM.txt"
    
    echo "📄 Processing RTF: $input_file"
    unrtf --text "$input_file" | sed -e 's/### .*//' > "$temp_txt"
    
    python3 process_text.py \
        "$MAX_CHUNK_SIZE" \
        "$MIN_CHUNK_SIZE" \
        "$VALIDATION_SPLIT" \
        "$CLEAN_LEVEL" \
        "$OUTPUT_FORMAT" \
        "$base_name" < "$temp_txt" > "${base_name}.${OUTPUT_FORMAT}"
    
    rm "$temp_txt"
}

process_odt() {
    local input_file="$1"
    local base_name="${input_file%.odt}"
    local temp_txt="/tmp/odt_text_$RANDOM.txt"
    
    echo "📄 Processing ODT: $input_file"
    odt2txt "$input_file" > "$temp_txt"
    
    python3 process_text.py \
        "$MAX_CHUNK_SIZE" \
        "$MIN_CHUNK_SIZE" \
        "$VALIDATION_SPLIT" \
        "$CLEAN_LEVEL" \
        "$OUTPUT_FORMAT" \
        "$base_name" < "$temp_txt" > "${base_name}.${OUTPUT_FORMAT}"
    
    rm "$temp_txt"
}

# Create Modelfile
create_modelfile() {
    local training_data="$1"
    cat > "$TRAINING_DIR/Modelfile" << EOF
FROM tinyllama
WORKDIR /data
COPY ${training_data} /data/training.jsonl

# System prompt
SYSTEM "You are a helpful assistant trained on Epicor documentation. You aim to provide accurate and relevant information about Epicor processes and procedures."

# Training parameters
PARAMETER stop "[INST]"
PARAMETER stop "[/INST]"
PARAMETER temperature 0.7
PARAMETER top_p 0.9

# Train on the data
TRAIN /data/training.jsonl
EOF

    echo "✅ Created: $TRAINING_DIR/Modelfile"
    echo ""
    echo "To train the model:"
    echo "cd $TRAINING_DIR"
    echo "ollama create epicor-assistant -f Modelfile"
    echo ""
    echo "To test the model:"
    echo "ollama run epicor-assistant"
}

# Main function
main() {
    local input_dir="$1"
    
    if [ -z "$input_dir" ]; then
        echo "❌ Usage: $0 <directory_with_documents> [options]"
        echo "Options:"
        echo "  --clean-level    basic|normal|strict (default: strict)"
        echo "  --chunk-size     maximum tokens per chunk (default: 2048)"
        echo "  --min-size       minimum tokens per chunk (default: 50)"
        echo "  --format         json|jsonl (default: jsonl)"
        echo "  --val-split      validation split ratio (default: 0.2)"
        echo "  --preserve-formatting"
        echo "  --handle-tables"
        echo "  --handle-images"
        exit 1
    fi
    
    echo "🔄 Setting up environment..."
    check_dependencies
    create_processor
    create_doc_processor
    
    mkdir -p "$TRAINING_DIR"
    
    echo "🔍 Processing documents..."
    
    for format in "${SUPPORTED_FORMATS[@]}"; do
        find "$input_dir" -type f -name "*.$format" | while read -r doc; do
            case "$format" in
                "pdf")  process_pdf "$doc" ;;
                "docx") process_docx "$doc" ;;
                "txt")  process_txt "$doc" ;;
                "rtf")  process_rtf "$doc" ;;
                "odt")  process_odt "$doc" ;;
            esac
        done
    done
    
    # Combine all training files
    if [ "$OUTPUT_FORMAT" = "jsonl" ]; then
        echo "Combining training files..."
        find "$input_dir" -type f -name "*.jsonl" ! -name "*.val.jsonl" -exec cat {} + > "$TRAINING_DIR/combined_training.jsonl"
        create_modelfile "$TRAINING_DIR/combined_training.jsonl"
        echo "✅ Created: $TRAINING_DIR/combined_training.jsonl"
    else
        echo "Combining training files..."
        echo "[" > "$TRAINING_DIR/combined_training.json"
        find "$input_dir" -type f -name "*.json" ! -name "*.val.json" -exec cat {} + | sed '$s/,$//' >> "$TRAINING_DIR/combined_training.json"
        echo "]" >> "$TRAINING_DIR/combined_training.json"
        create_modelfile "$TRAINING_DIR/combined_training.json"
        echo "✅ Created: $TRAINING_DIR/combined_training.json"
    fi
    
    echo "✅ Processing complete!"
    echo "📝 Training files prepared"
    echo ""
    echo "To train TinyLlama with this data:"
    echo "ollama create custom-model -f ./Modelfile"
    echo ""
    echo "To test the model:"
    echo "ollama run custom-model"
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean-level)
            CLEAN_LEVEL="$2"
            shift 2
            ;;
        --chunk-size)
            MAX_CHUNK_SIZE="$2"
            shift 2
            ;;
        --min-size)
            MIN_CHUNK_SIZE="$2"
            shift 2
            ;;
        --format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --val-split)
            VALIDATION_SPLIT="$2"
            shift 2
            ;;
        --preserve-formatting)
            PRESERVE_FORMATTING="$2"
            shift 2
            ;;
        --handle-tables)
            HANDLE_TABLES="$2"
            shift 2
            ;;
        --handle-images)
            HANDLE_IMAGES="$2"
            shift 2
            ;;
        *)
            INPUT_DIR="$1"
            shift
            ;;
    esac
done

# Run the script
main "$INPUT_DIR" 