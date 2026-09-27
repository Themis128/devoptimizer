import os
import shutil

src1 = '/mnt/d/DevOptimizer/scripts/.clineignore'
dst1 = '/home/tbaltzakis/ComfyUI-Docker/cu130-slim/.clineignore'
src2 = '/mnt/d/DevOptimizer/scripts/.cline-instructions.md'
dst2 = '/home/tbaltzakis/ComfyUI-Docker/cu130-slim/.cline-instructions.md'

print('Source1 exists:', os.path.exists(src1))
print('Source2 exists:', os.path.exists(src2))
print('Dest dir exists:', os.path.exists(os.path.dirname(dst1)))
print('Dest dir writable:', os.access(os.path.dirname(dst1), os.W_OK))

shutil.copy2(src1, dst1)
shutil.copy2(src2, dst2)
print('Copied successfully')

print('Dest1 exists:', os.path.exists(dst1))
print('Dest2 exists:', os.path.exists(dst2))
print('Dest1 size:', os.path.getsize(dst1))
print('Dest2 size:', os.path.getsize(dst2))