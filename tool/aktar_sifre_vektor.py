#!/usr/bin/env python3
"""Aktar şifreli protokolünün (Faz G5) BAĞIMSIZ başvuru uygulaması.

Dart (`lib/services/fm/remote/peer_crypto.dart`) ve Windows "Dosya Aktar"
(`tool/pc_aktar/Secure.cs`) bu betiğin ürettiği sabit vektörlerle sınanır
(`test/peer_crypto_test.dart`). Biçim değişirse üçü birlikte değişir.

Kullanım:  python3 tool/aktar_sifre_vektor.py   (Python `cryptography` paketi)

Tasarım (docs/GUVENLIK_PLANI.md G5):
* X25519: e = geçici, s = kalıcı. Başlatan (I) ve yanıtlayan (R).
  dh1 = DH(eI, eR), dh2 = DH(sI, eR), dh3 = DH(eI, sR)
* th  = SHA256("dosya-aktar v2" || EI || SI || ER || SR)
* okm = HKDF-SHA256(ikm = dh1||dh2||dh3, salt = eşleştirme kodu (boşsa 32 sıfır),
                    info = "dosya-aktar v2" || th, L = 68)
  kI2R = okm[0:32], kR2I = okm[32:64], doğrulama = u32be(okm[64:68]) % 10^6
* Parmak izi = hex(SHA256(kalıcı açık anahtar))[:32]
* Kayıt: u32be(len) || AES-256-GCM(k, nonce = u32be(akış) || u64be(sayaç),
         düz = bayrak(1: 1 = son) || yük, aad)
"""
import hashlib
import hmac
import struct

from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives import serialization

INFO = b"dosya-aktar v2"


def pub(seed: bytes) -> bytes:
    return X25519PrivateKey.from_private_bytes(seed).public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def dh(seed: bytes, other: bytes) -> bytes:
    return X25519PrivateKey.from_private_bytes(seed).exchange(X25519PublicKey.from_public_bytes(other))


def hkdf(ikm: bytes, salt: bytes, info: bytes, n: int) -> bytes:
    prk = hmac.new(salt or bytes(32), ikm, hashlib.sha256).digest()
    out, t, i = b"", b"", 1
    while len(out) < n:
        t = hmac.new(prk, t + info + bytes([i]), hashlib.sha256).digest()
        out += t
        i += 1
    return out[:n]


def derive(sI, eI, sR, eR, code=""):
    SI, EI, SR, ER = pub(sI), pub(eI), pub(sR), pub(eR)
    ikm = dh(eI, ER) + dh(sI, ER) + dh(eI, SR)
    th = hashlib.sha256(INFO + EI + SI + ER + SR).digest()
    okm = hkdf(ikm, code.encode(), INFO + th, 68)
    verify = "%06d" % (struct.unpack(">I", okm[64:68])[0] % 1000000)
    return okm[:32], okm[32:64], verify


def record(key, prefix, counter, payload, last, aad):
    nonce = struct.pack(">IQ", prefix, counter)
    ct = AESGCM(key).encrypt(nonce, bytes([1 if last else 0]) + payload, aad)
    return struct.pack(">I", len(ct)) + ct


def fp(p: bytes) -> str:
    return hashlib.sha256(p).hexdigest()[:32]


if __name__ == "__main__":
    sI, eI = bytes(range(1, 33)), bytes(range(33, 65))
    sR, eR = bytes(range(65, 97)), bytes(range(97, 129))
    for code in ("", "123456"):
        k1, k2, v = derive(sI, eI, sR, eR, code)
        print(f"kod={code!r} kI2R={k1.hex()} kR2I={k2.hex()} dogrulama={v}")
    print("SI", pub(sI).hex(), "fpI", fp(pub(sI)))
    print("SR", pub(sR).hex(), "fpR", fp(pub(sR)))
    k1, _, _ = derive(sI, eI, sR, eR, "")
    print("kayit", record(k1, 7, 0, b"merhaba", True, b"/al").hex())
