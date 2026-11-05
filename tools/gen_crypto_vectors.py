"""Independent cryptography-library oracles, not a translation of the RTL."""
from pathlib import Path
from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes
from cryptography.hazmat.primitives.ciphers.aead import AESCCM
ROOT=Path(__file__).resolve().parents[1]
key=bytes(range(16));nonce=bytes(range(13));lengths=[0,1,15,16,17,31,260,2043]
def sm4ccm(plain):
    def block(x):return Cipher(algorithms.SM4(key),modes.ECB()).encryptor().update(x)
    def xor(a,b):return bytes(x^y for x,y in zip(a,b))
    mac=block(b'\x49'+nonce+len(plain).to_bytes(2,'big'))
    mac=block(xor(mac,b'\x00\x01'+b'\x00'*14))
    for i in range(0,len(plain),16):mac=block(xor(mac,plain[i:i+16].ljust(16,b'\x00')))
    tag=xor(mac,block(b'\x01'+nonce+b'\x00\x00'))[:4]
    cipher=b''.join(xor(plain[i:i+16],block(b'\x01'+nonce+(i//16+1).to_bytes(2,'big'))) for i in range(0,len(plain),16))
    return cipher+tag
out=[]
for alg in range(2):
    for n in lengths:
        plain=bytes((i*37+11)&255 for i in range(n))
        expected=AESCCM(key,tag_length=4).encrypt(nonce,plain,b'\x00') if alg==0 else sm4ccm(plain)
        out += [f'{int.from_bytes(expected[i:i+4].ljust(4,bytes(1)),"little"):08x}' for i in range(0,2048,4)]
(ROOT/'verification/aes_sm4_ccm.mem').write_text('\n'.join(out)+'\n',encoding='ascii')
print('16 AES/SM4 CCM library-reference vectors generated.')
nonce=bytes([1])+bytes(range(1,13))
plain=bytes((i*37+11)&255 for i in range(17))
out=[]
for alg in range(2):
    expected=AESCCM(key,tag_length=4).encrypt(nonce,plain,b'\x00') if alg==0 else sm4ccm(plain)
    out += [f'{int.from_bytes(expected[i:i+4].ljust(4,bytes(1)),"little"):08x}' for i in range(0,2048,4)]
(ROOT/'verification/secure_chain.mem').write_text('\n'.join(out)+'\n',encoding='ascii')
