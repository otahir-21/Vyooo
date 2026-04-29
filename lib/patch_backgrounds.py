import os
import glob
import re

directories = [
    './screens/account',
    './screens/settings',
    './features/subscription',
]

def patch_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # If it already uses premiumDark, skip
    if 'GradientType.premiumDark' in content or 'premiumDarkGradient' in content:
        return

    # Case 1: AppGradientBackground without type (defaults to auth/main)
    # AppGradientBackground(\n      child: 
    if re.search(r'AppGradientBackground\(\s*child:', content):
        content = re.sub(r'AppGradientBackground\(\s*child:', 'AppGradientBackground(\n        type: GradientType.premiumDark,\n        child:', content)
    
    # Case 2: Scaffold with body: Container(decoration: BoxDecoration(gradient: AppGradients.authGradient))
    elif 'decoration: BoxDecoration(gradient: AppGradients.authGradient),' in content:
        # replace the Container wrapper with AppGradientBackground
        # import AppGradientBackground if missing
        if 'app_gradient_background.dart' not in content:
            # add import after the last import
            imports_end = content.rfind("import '")
            end_of_line = content.find('\n', imports_end)
            content = content[:end_of_line+1] + "import 'package:vyooo/core/widgets/app_gradient_background.dart';\n" + content[end_of_line+1:]
        
        # replace body: Container(decoration: ...) with body: AppGradientBackground(type: GradientType.premiumDark,
        content = re.sub(r'body:\s*Container\(\s*decoration:\s*BoxDecoration\(gradient:\s*AppGradients\.authGradient\),', 
                         r'body: AppGradientBackground(\n        type: GradientType.premiumDark,', content)
                         
    # Case 3: Scaffold with body: AppGradientBackground(type: GradientType.auth
    elif re.search(r'AppGradientBackground\(\s*type:\s*GradientType\.auth,', content):
        content = re.sub(r'AppGradientBackground\(\s*type:\s*GradientType\.auth,', 'AppGradientBackground(\n        type: GradientType.premiumDark,', content)
        
    with open(filepath, 'w') as f:
        f.write(content)

for d in directories:
    for root, dirs, files in os.walk(d):
        for file in files:
            if file.endswith('.dart'):
                patch_file(os.path.join(root, file))

print("Patching complete")
