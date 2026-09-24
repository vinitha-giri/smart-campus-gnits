import re

# Read the OCR output file from the project root
with open(r'C:\Users\VINITHA\Desktop\smartcampusbackend\ocr_output.txt',
          'r',
          encoding='utf-8') as f:
    text = f.read()

# Find room numbers like A-201, B-305, F-413, A002, D202
pattern = r'\b[A-F]-?\d{3}[A-Z]?\b|\b[A-F]\d{3}\b'

rooms = sorted(set(re.findall(pattern, text)))

print('Detected rooms:')
for room in rooms:
    print(room)