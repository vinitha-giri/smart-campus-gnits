import sys
from pdf2image import convert_from_path
import pytesseract

# Tesseract path
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

# Correct Poppler path
POPPLER_PATH = r'C:\poppler-26.02.0\Library\bin'

pdf_path = sys.argv[1]

pages = convert_from_path(pdf_path, poppler_path=POPPLER_PATH)

text = ''

for page in pages:
    text += pytesseract.image_to_string(page)

with open('ocr_output.txt', 'w', encoding='utf-8') as f:
    f.write(text)

print('OCR text saved to ocr_output.txt')