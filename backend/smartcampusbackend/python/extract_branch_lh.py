import re

with open(r'C:\Users\VINITHA\Desktop\smartcampusbackend\ocr_output.txt',
          'r',
          encoding='utf-8') as f:
    lines = f.readlines()

print('Branch -> LH Mapping')

for line in lines:
    if 'Branch' in line:
        line = line.strip()
        print('RAW:', line)

        # Extract branch name
        branch_match = re.search(r'Branch[:;]\\s*([A-Z0-9-]+)', line)

        # Extract LH numbers after L.H.N...
        lh_match = re.search(r'L\\.H\\.N\\w*[:.]?\\s*([0-9, ]+)', line)

        if branch_match:
            branch = branch_match.group(1)

            if lh_match:
                halls = [h.strip() for h in lh_match.group(1).split(',') if h.strip()]
            else:
                halls = []

            print(f'{branch} -> {halls}')