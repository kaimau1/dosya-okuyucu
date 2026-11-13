using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Security.Cryptography;
using System.Text;

namespace DosyaAktar
{
    /// <summary>
    /// Telefondaki Dosya Okuyucu'nun şifreli Aktar protokolü (Faz G5) — kaynak:
    /// lib/services/fm/remote/peer_crypto.dart; başvuru: tool/aktar_sifre_vektor.py.
    /// Biçim değişirse üçü birlikte değişir.
    ///
    /// .NET Framework 4.8'de ne X25519 ne AesGcm sınıfı var: X25519 BigInteger ile (RFC 7748
    /// Montgomery merdiveni, oturum başına üç işlem — hız önemsiz), AES-GCM ise Windows'un
    /// donanım hızlandırmalı AES'i (ECB ile sayaç akışı) + 4 bitlik tablolu GHASH.
    /// </summary>
    public static class Secure
    {
        public const string Info = "dosya-aktar v2";
        public const int ChunkSize = 1 << 20;
        public const int Overhead = 4 + 1 + 16;
        public const int MaxSealed = ChunkSize + 1 + 16;

        // ── X25519 (RFC 7748) ──────────────────────────────────────────────
        static readonly BigInteger P = BigInteger.Pow(2, 255) - 19;
        static readonly BigInteger A24 = 121665;

        static BigInteger Mod(BigInteger a) { var r = a % P; return r.Sign < 0 ? r + P : r; }

        static BigInteger FromLe(byte[] b)
        {
            var t = new byte[33];
            Array.Copy(b, t, 32);
            return new BigInteger(t); // son bayt 0 → pozitif
        }

        static byte[] ToLe(BigInteger v)
        {
            var raw = v.ToByteArray();
            var o = new byte[32];
            Array.Copy(raw, o, Math.Min(32, raw.Length));
            return o;
        }

        public static byte[] X25519(byte[] scalar, byte[] u)
        {
            var k = (byte[])scalar.Clone();
            k[0] &= 248; k[31] &= 127; k[31] |= 64;
            var uu = (byte[])u.Clone();
            uu[31] &= 127;
            var x1 = Mod(FromLe(uu));
            BigInteger x2 = 1, z2 = 0, x3 = x1, z3 = 1;
            var swap = 0;
            for (var t = 254; t >= 0; t--)
            {
                var kt = (k[t >> 3] >> (t & 7)) & 1;
                swap ^= kt;
                if (swap == 1) { var a0 = x2; x2 = x3; x3 = a0; a0 = z2; z2 = z3; z3 = a0; }
                swap = kt;
                var A = Mod(x2 + z2); var AA = Mod(A * A);
                var B = Mod(x2 - z2); var BB = Mod(B * B);
                var E = Mod(AA - BB);
                var C = Mod(x3 + z3); var D = Mod(x3 - z3);
                var DA = Mod(D * A); var CB = Mod(C * B);
                x3 = Mod(BigInteger.Pow(DA + CB, 2));
                z3 = Mod(x1 * BigInteger.Pow(DA - CB, 2));
                x2 = Mod(AA * BB);
                z2 = Mod(E * (AA + A24 * E));
            }
            if (swap == 1) { x2 = x3; z2 = z3; }
            return ToLe(Mod(x2 * BigInteger.ModPow(z2, P - 2, P)));
        }

        static readonly byte[] Base = Enumerable.Range(0, 32).Select(i => (byte)(i == 0 ? 9 : 0)).ToArray();

        public static byte[] PublicKey(byte[] seed) => X25519(seed, Base);

        public static byte[] RandomBytes(int n)
        {
            var b = new byte[n];
            using (var r = RandomNumberGenerator.Create()) r.GetBytes(b);
            return b;
        }

        static byte[] Dh(byte[] mine, byte[] theirs)
        {
            if (theirs == null || theirs.Length != 32) throw new CryptographicException("anahtar");
            var s = X25519(mine, theirs);
            if (s.All(x => x == 0)) throw new CryptographicException("anahtar");
            return s;
        }

        // ── HKDF-SHA256 ────────────────────────────────────────────────────
        public static byte[] Hkdf(byte[] ikm, byte[] salt, byte[] info, int len)
        {
            byte[] prk;
            using (var h = new HMACSHA256(salt.Length == 0 ? new byte[32] : salt)) prk = h.ComputeHash(ikm);
            var o = new List<byte>();
            var t = new byte[0];
            byte i = 1;
            using (var h = new HMACSHA256(prk))
            {
                while (o.Count < len)
                {
                    t = h.ComputeHash(t.Concat(info).Concat(new[] { i++ }).ToArray());
                    o.AddRange(t);
                }
            }
            return o.Take(len).ToArray();
        }

        public static string Fingerprint(byte[] pub)
        {
            using (var s = SHA256.Create())
                return string.Concat(s.ComputeHash(pub).Take(16).Select(x => x.ToString("x2")));
        }

        public class Keys
        {
            public byte[] Send, Recv;
            public string VerifyCode, PeerFingerprint;
        }

        /// <summary>dh1 = DH(eI,eR), dh2 = DH(sI,eR), dh3 = DH(eI,sR); th = SHA256(info‖EI‖SI‖ER‖SR).</summary>
        public static Keys Derive(byte[] myStatic, byte[] myEph, byte[] theirStatic, byte[] theirEph, bool initiator, string code)
        {
            var myS = PublicKey(myStatic);
            var myE = PublicKey(myEph);
            var dh1 = Dh(myEph, theirEph);
            var dh2 = initiator ? Dh(myStatic, theirEph) : Dh(myEph, theirStatic);
            var dh3 = initiator ? Dh(myEph, theirStatic) : Dh(myStatic, theirEph);
            var eI = initiator ? myE : theirEph;
            var sI = initiator ? myS : theirStatic;
            var eR = initiator ? theirEph : myE;
            var sR = initiator ? theirStatic : myS;
            var info = Encoding.UTF8.GetBytes(Info);
            byte[] th;
            using (var s = SHA256.Create()) th = s.ComputeHash(info.Concat(eI).Concat(sI).Concat(eR).Concat(sR).ToArray());
            var okm = Hkdf(dh1.Concat(dh2).Concat(dh3).ToArray(), Encoding.UTF8.GetBytes(code ?? ""), info.Concat(th).ToArray(), 68);
            var i2r = okm.Take(32).ToArray();
            var r2i = okm.Skip(32).Take(32).ToArray();
            var v = ((uint)okm[64] << 24 | (uint)okm[65] << 16 | (uint)okm[66] << 8 | okm[67]) % 1000000;
            return new Keys
            {
                Send = initiator ? i2r : r2i,
                Recv = initiator ? r2i : i2r,
                VerifyCode = v.ToString("D6"),
                PeerFingerprint = Fingerprint(theirStatic),
            };
        }

        public static byte[] Nonce(uint stream, ulong counter)
        {
            var n = new byte[12];
            for (var i = 0; i < 4; i++) n[i] = (byte)(stream >> (24 - 8 * i));
            for (var i = 0; i < 8; i++) n[4 + i] = (byte)(counter >> (56 - 8 * i));
            return n;
        }
    }

    /// <summary>AES-256-GCM (96 bit nonce, 128 bit etiket sonda). Windows AES (ECB) + yazılım GHASH.</summary>
    public sealed class Gcm : IDisposable
    {
        readonly Aes aes;
        readonly ICryptoTransform enc;
        readonly ulong[] hl = new ulong[16], hh = new ulong[16];

        static readonly ulong[] Last4 =
        {
            0x0000, 0x1c20, 0x3840, 0x2460, 0x7080, 0x6ca0, 0x48c0, 0x54e0,
            0xe100, 0xfd20, 0xd940, 0xc560, 0x9180, 0x8da0, 0xa9c0, 0xb5e0,
        };

        public Gcm(byte[] key)
        {
            aes = Aes.Create();
            aes.Mode = CipherMode.ECB;
            aes.Padding = PaddingMode.None;
            aes.Key = key;
            enc = aes.CreateEncryptor();
            var h = new byte[16];
            enc.TransformBlock(new byte[16], 0, 16, h, 0);
            ulong vh = Be(h, 0), vl = Be(h, 8);
            hl[8] = vl; hh[8] = vh;
            for (var i = 4; i > 0; i >>= 1)
            {
                var t = (vl & 1) * 0xe1000000UL;
                vl = (vh << 63) | (vl >> 1);
                vh = (vh >> 1) ^ (t << 32);
                hl[i] = vl; hh[i] = vh;
            }
            for (var i = 2; i <= 8; i *= 2)
            {
                vh = hh[i]; vl = hl[i];
                for (var j = 1; j < i; j++) { hh[i + j] = vh ^ hh[j]; hl[i + j] = vl ^ hl[j]; }
            }
        }

        static ulong Be(byte[] b, int o)
        {
            ulong v = 0;
            for (var i = 0; i < 8; i++) v = (v << 8) | b[o + i];
            return v;
        }

        static void PutBe(byte[] b, int o, ulong v)
        {
            for (var i = 7; i >= 0; i--) { b[o + i] = (byte)v; v >>= 8; }
        }

        void Mult(byte[] x)
        {
            int lo = x[15] & 0xf;
            ulong zh = hh[lo], zl = hl[lo];
            for (var i = 15; i >= 0; i--)
            {
                lo = x[i] & 0xf;
                var hi = (x[i] >> 4) & 0xf;
                int rem;
                if (i != 15)
                {
                    rem = (int)(zl & 0xf);
                    zl = (zh << 60) | (zl >> 4);
                    zh >>= 4;
                    zh ^= Last4[rem] << 48;
                    zh ^= hh[lo]; zl ^= hl[lo];
                }
                rem = (int)(zl & 0xf);
                zl = (zh << 60) | (zl >> 4);
                zh >>= 4;
                zh ^= Last4[rem] << 48;
                zh ^= hh[hi]; zl ^= hl[hi];
            }
            PutBe(x, 0, zh);
            PutBe(x, 8, zl);
        }

        void Absorb(byte[] y, byte[] data, int off, int len)
        {
            for (var p = 0; p < len; p += 16)
            {
                var n = Math.Min(16, len - p);
                for (var i = 0; i < n; i++) y[i] ^= data[off + p + i];
                Mult(y);
            }
        }

        byte[] Tag(byte[] nonce, byte[] aad, byte[] ct, int off, int len)
        {
            var y = new byte[16];
            Absorb(y, aad, 0, aad.Length);
            Absorb(y, ct, off, len);
            var l = new byte[16];
            PutBe(l, 0, (ulong)aad.Length * 8);
            PutBe(l, 8, (ulong)len * 8);
            for (var i = 0; i < 16; i++) y[i] ^= l[i];
            Mult(y);
            var j0 = new byte[16];
            Array.Copy(nonce, j0, 12);
            j0[15] = 1;
            var ek = new byte[16];
            enc.TransformBlock(j0, 0, 16, ek, 0);
            for (var i = 0; i < 16; i++) y[i] ^= ek[i];
            return y;
        }

        void Ctr(byte[] nonce, byte[] src, int off, int len, byte[] dst, int dOff)
        {
            var blocks = (len + 15) / 16;
            var ctr = new byte[blocks * 16];
            for (var b = 0; b < blocks; b++)
            {
                Array.Copy(nonce, 0, ctr, b * 16, 12);
                var c = (uint)(b + 2);
                ctr[b * 16 + 12] = (byte)(c >> 24); ctr[b * 16 + 13] = (byte)(c >> 16);
                ctr[b * 16 + 14] = (byte)(c >> 8); ctr[b * 16 + 15] = (byte)c;
            }
            var ks = new byte[ctr.Length];
            if (ctr.Length > 0) enc.TransformBlock(ctr, 0, ctr.Length, ks, 0);
            for (var i = 0; i < len; i++) dst[dOff + i] = (byte)(src[off + i] ^ ks[i]);
        }

        public byte[] Seal(byte[] nonce, byte[] plain, int off, int len, byte[] aad)
        {
            var o = new byte[len + 16];
            Ctr(nonce, plain, off, len, o, 0);
            Array.Copy(Tag(nonce, aad, o, 0, len), 0, o, len, 16);
            return o;
        }

        public byte[] Open(byte[] nonce, byte[] sealedData, byte[] aad)
        {
            if (sealedData.Length < 16) throw new CryptographicException("kisa");
            var len = sealedData.Length - 16;
            var tag = Tag(nonce, aad, sealedData, 0, len);
            var diff = 0;
            for (var i = 0; i < 16; i++) diff |= tag[i] ^ sealedData[len + i];
            if (diff != 0) throw new CryptographicException("etiket");
            var o = new byte[len];
            Ctr(nonce, sealedData, 0, len, o, 0);
            return o;
        }

        public void Dispose() { enc.Dispose(); aes.Dispose(); }
    }

    /// <summary>Bir akışın kayıtları: u32be(uzunluk) ‖ GCM(nonce = akış ‖ sayaç, bayrak ‖ yük, aad).</summary>
    public sealed class Records : IDisposable
    {
        readonly Gcm gcm;
        readonly uint stream;
        readonly byte[] aad;
        ulong counter;
        public bool Done { get; private set; }

        public Records(byte[] key, uint stream, string aad)
        {
            gcm = new Gcm(key);
            this.stream = stream;
            this.aad = Encoding.UTF8.GetBytes(aad);
        }

        public static long SealedLength(long len) =>
            Math.Max(0, len) + (len <= 0 ? 1 : (len + Secure.ChunkSize - 1) / Secure.ChunkSize) * Secure.Overhead;

        public byte[] Seal(byte[] payload, int off, int len, bool last)
        {
            if (Done) throw new InvalidOperationException("akış kapandı");
            var plain = new byte[len + 1];
            plain[0] = (byte)(last ? 1 : 0);
            Array.Copy(payload, off, plain, 1, len);
            var s = gcm.Seal(Secure.Nonce(stream, counter++), plain, 0, plain.Length, aad);
            if (last) Done = true;
            var o = new byte[4 + s.Length];
            o[0] = (byte)(s.Length >> 24); o[1] = (byte)(s.Length >> 16); o[2] = (byte)(s.Length >> 8); o[3] = (byte)s.Length;
            Array.Copy(s, 0, o, 4, s.Length);
            return o;
        }

        static bool ReadFull(Stream s, byte[] b, int len)
        {
            var got = 0;
            while (got < len)
            {
                var n = s.Read(b, got, len - got);
                if (n <= 0) return false;
                got += n;
            }
            return true;
        }

        /// <summary>Sıradaki kaydı okuyup açar; akış kayıt ortasında biterse "kesik".</summary>
        public byte[] OpenNext(Stream s, out bool last)
        {
            if (Done) throw new CryptographicException("fazla");
            var h = new byte[4];
            if (!ReadFull(s, h, 4)) throw new CryptographicException("kesik");
            var len = h[0] << 24 | h[1] << 16 | h[2] << 8 | h[3];
            if (len < 17 || len > Secure.MaxSealed) throw new CryptographicException("boy");
            var b = new byte[len];
            if (!ReadFull(s, b, len)) throw new CryptographicException("kesik");
            var plain = gcm.Open(Secure.Nonce(stream, counter++), b, aad);
            if (plain.Length == 0 || plain[0] > 1) throw new CryptographicException("bicim");
            last = plain[0] == 1;
            if (last) Done = true;
            var o = new byte[plain.Length - 1];
            Array.Copy(plain, 1, o, 0, o.Length);
            return o;
        }

        public void Dispose() => gcm.Dispose();
    }
}
