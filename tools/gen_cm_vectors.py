"""Independent library CCM oracle for the SLE slot/day profile (slot=100,day=1)."""
from pathlib import Path
from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes
from cryptography.hazmat.primitives.ciphers.aead import AESCCM
ROOT=Path(__file__).resolve().parents[1]
key=bytes(range(16));nonce=((1<<30)|100).to_bytes(5,'little')+bytes(range(5,13))
plain=bytes((i*37+11)&255 for i in range(17))
def xor(a,b):return bytes(x^y for x,y in zip(a,b))
def sm4_ccm():
 def block(x):return Cipher(algorithms.SM4(key),modes.ECB()).encryptor().update(x)
 mac=block(b'\x49'+nonce+len(plain).to_bytes(2,'big'))
 mac=block(xor(mac,b'\x00\x01'+bytes(14)))
 for off in range(0,len(plain),16):mac=block(xor(mac,plain[off:off+16].ljust(16,b'\0')))
 tag=xor(mac,block(b'\x01'+nonce+bytes(2)))[:4]
 return b''.join(xor(plain[off:off+16],block(b'\x01'+nonce+(off//16+1).to_bytes(2,'big'))) for off in range(0,len(plain),16))+tag
out=[]
for cipher in [AESCCM(key,tag_length=4).encrypt(nonce,plain,b'\0'),sm4_ccm()]:
 out += [f'{int.from_bytes(cipher[i:i+4].ljust(4,bytes(1)),"little"):08x}' for i in range(0,2048,4)]
(ROOT/'verification/cm_slot_nonce.mem').write_text('\n'.join(out)+'\n',encoding='ascii')
print('Generated independent slot/day AES/SM4 vectors',nonce.hex())
