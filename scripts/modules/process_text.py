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
