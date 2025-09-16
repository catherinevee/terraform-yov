import zipfile
import os

# Create lambda-placeholder.zip
with zipfile.ZipFile('lambda-placeholder.zip', 'w') as zf:
    zf.write('lambda-placeholder.js', arcname='index.js')

# Create lambda-layer.zip
with zipfile.ZipFile('lambda-layer.zip', 'w') as zf:
    zf.write('lambda-placeholder.js', arcname='nodejs/index.js')

print("Created lambda-placeholder.zip and lambda-layer.zip")