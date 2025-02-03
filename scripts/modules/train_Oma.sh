import os
import pdfminer.high_level
from langchain.vectorstores import Chroma
from langchain.embeddings import HuggingFaceEmbeddings

DATA_DIR = os.path.expanduser("~/survival_ai_data/")
vectorstore = Chroma(persist_directory=DATA_DIR)

def extract_text_from_pdfs():
    pdf_files = [f for f in os.listdir(DATA_DIR) if f.endswith(".pdf")]
    for pdf in pdf_files:
        text = pdfminer.high_level.extract_text(os.path.join(DATA_DIR, pdf))
        with open(os.path.join(DATA_DIR, f"{pdf}.txt"), "w") as f:
            f.write(text)
        print(f"Extracted text from {pdf}")

extract_text_from_pdfs()

