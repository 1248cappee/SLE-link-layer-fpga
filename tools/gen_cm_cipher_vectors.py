"""Block-engine oracle, independent of RTL, using cryptography/OpenSSL."""
from pathlib import Path
from random import Random
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
root=Path(__file__).resolve().parents[1]
rng=Random(0x534c45434d)
vectors=[]
for i in range(66):
    if i==0:
        key=bytes(range(16));plain=bytes.fromhex('00112233445566778899aabbccddeeff')
    elif i==1:
        key=plain=bytes.fromhex('0123456789abcdeffedcba9876543210')
    else:
        key=rng.randbytes(16);plain=rng.randbytes(16)
    algorithm=(algorithms.SM4 if i&1 else algorithms.AES)(key)
    enc=Cipher(algorithm,modes.ECB()).encryptor()
    result=enc.update(plain)+enc.finalize()
    vectors.append((key+plain+result).hex())
assert vectors[0][-32:]=='69c4e0d86a7b0430d8cdb78070b4c55a'
assert vectors[1][-32:]=='681edf34d206965e86b3e94f536e4246'
(root/'verification/cm_cipher.mem').write_text('\n'.join(vectors)+'\n',encoding='ascii')
print('Generated 66 independent AES/SM4 block vectors; seed 0x534c45434d')
