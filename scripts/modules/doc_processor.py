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

