import re

file_path = r"c:\Users\dell\AppData\Roaming\Code\User\workspaceStorage\dc7498fb08f4c68587044dd718d66bae\GitHub.copilot-chat\chat-session-resources\93d89770-427d-46dc-a6f9-45285538af53\call_MHxKMGhiSm1jaUdWRDdIR2szZFQ__vscode-1772281695287\content.txt"
pattern = r"(UI_\w+_[0-9A-F]{8}),([^,]+),(\S+)"

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    matches = re.findall(pattern, content)
    
    print(f"Total matches: {len(matches)}")
    print("First 5 matches:")
    for i, match in enumerate(matches[:5]):
        print(f"{i+1}: {match}")
        
except FileNotFoundError:
    print(f"Error: File not found at {file_path}")
except Exception as e:
    print(f"An error occurred: {e}")
