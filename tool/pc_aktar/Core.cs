using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

namespace DosyaAktar
{
    /// <summary>
    /// Telefondaki Dosya Okuyucu'nun "Yakındakiler" protokolü — kaynak:
    /// lib/services/fm/remote/peer_share.dart. Bir uç değişirse ikisi birlikte değişmeli.
    /// Bulma: UDP 8769'a "DOSYA-OKUYUCU-1" yayını, alıcı JSON kimliğiyle cevap verir.
    /// Aktarım: HTTP 8770 — /kim, /sor (onay), /durum (kaldığı yer), /al (gövde = dosya).
    /// </summary>
    public static class Proto
    {
        public const int DiscoveryPort = 8769;
        public const int TransferPort = 8770;
        public const string Magic = "DOSYA-OKUYUCU-1";
        public const string PartPrefix = ".dosya-aktarim-";

        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };

        public static string ToJson(object o) => Json.Serialize(o);

        public static Dictionary<string, object> FromJson(string s)
        {
            try { return Json.DeserializeObject(s) as Dictionary<string, object>; }
            catch { return null; }
        }

        public static string Str(Dictionary<string, object> d, string k) =>
            d != null && d.TryGetValue(k, out var v) && v != null ? v.ToString() : null;

        public static long Num(Dictionary<string, object> d, string k, long fallback)
        {
            if (d == null || !d.TryGetValue(k, out var v) || v == null) return fallback;
            try { return Convert.ToInt64(v); } catch { return fallback; }
        }

        static readonly HashSet<string> Reserved = new HashSet<string>(
            new[] { "CON", "PRN", "AUX", "NUL" }
                .Concat(Enumerable.Range(1, 9).Select(i => "COM" + i))
                .Concat(Enumerable.Range(1, 9).Select(i => "LPT" + i)));

        /// <summary>
        /// Yol değil yalnız AD: ayırıcılar ve Windows'un kabul etmediği karakterler '_' olur,
        /// ".." boşa düşer — gelen ad klasör dışına çıkamaz. Android adında ':' '?' olabilir.
        /// </summary>
        public static string SafeName(string name)
        {
            var sb = new StringBuilder();
            foreach (var c in (name ?? "").Trim())
                sb.Append(c < 32 || "/\\<>:\"|?*".IndexOf(c) >= 0 ? '_' : c);
            var s = sb.ToString().TrimEnd('.', ' ');
            if (s.Trim('.').Length == 0) return "";
            if (Reserved.Contains(s.Split('.')[0].ToUpperInvariant())) s = "_" + s;
            return s;
        }

        /// <summary>Var olanı EZMEZ: "rapor.pdf" → "rapor (1).pdf".</summary>
        public static string UniquePath(string path)
        {
            if (!File.Exists(path) && !Directory.Exists(path)) return path;
            var dir = Path.GetDirectoryName(path);
            var stem = Path.GetFileNameWithoutExtension(path);
            var ext = Path.GetExtension(path);
            for (var i = 1; i < 10000; i++)
            {
                var c = Path.Combine(dir, stem + " (" + i + ")" + ext);
                if (!File.Exists(c) && !Directory.Exists(c)) return c;
            }
            return Path.Combine(dir, stem + "-" + DateTime.Now.Ticks + ext);
        }

        /// <summary>Yerel IPv4 adresleri ve alt ağ yayın adresleri (geri döngü ve 169.254 hariç).</summary>
        public static List<(IPAddress ip, IPAddress broadcast)> LocalIPv4()
        {
            var list = new List<(IPAddress, IPAddress)>();
            try
            {
                foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (ni.OperationalStatus != OperationalStatus.Up ||
                        ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
                    foreach (var ua in ni.GetIPProperties().UnicastAddresses)
                    {
                        if (ua.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                        var b = ua.Address.GetAddressBytes();
                        if (b[0] == 169 && b[1] == 254) continue;
                        var m = ua.IPv4Mask?.GetAddressBytes();
                        if (m == null || m.Length != 4 || m.All(x => x == 0)) m = new byte[] { 255, 255, 255, 0 };
                        var bc = new byte[4];
                        for (var i = 0; i < 4; i++) bc[i] = (byte)(b[i] | ~m[i]);
                        list.Add((ua.Address, new IPAddress(bc)));
                    }
                }
            }
            catch { }
            return list;
        }

        /// <summary>
        /// Windows'ta karşıdan gelen ICMP "port kapalı" UDP soketinin bir sonraki Receive'ini
        /// hatayla düşürür (WSAECONNRESET) — bulma döngüsü sessizce ölmesin.
        /// </summary>
        public static void NoConnReset(Socket s)
        {
            try { s.IOControl(unchecked((int)0x9800000C), new byte[] { 0, 0, 0, 0 }, null); } catch { }
        }

        public static string Md5Hex(string s)
        {
            using (var md5 = MD5.Create())
                return string.Concat(md5.ComputeHash(Encoding.UTF8.GetBytes(s)).Select(x => x.ToString("x2")));
        }

        public static string Size(long bytes)
        {
            if (bytes < 1024) return bytes + " B";
            double v = bytes; var units = new[] { "KB", "MB", "GB", "TB" }; var u = -1;
            do { v /= 1024; u++; } while (v >= 1024 && u < units.Length - 1);
            return v.ToString(v < 10 ? "0.0" : "0") + " " + units[u];
        }
    }

    public class Peer
    {
        public string Name = "?", Host, Id = "";
        public int Port = Proto.TransferPort;
        public DateTime Seen;
        public bool Manual;

        /// <summary>Yalnız Bluetooth'tan görülen telefon (Host yok): önce davet, sonra Wi-Fi.</summary>
        public ulong BleAddress;
        public bool BleRandom;
        public bool IsBle => Host == null;

        public string Key => IsBle ? "ble:" + BleAddress : Host + ":" + Port;
        public override string ToString() =>
            Name + "    " + (IsBle ? "Bluetooth" : Host) + (Manual ? "  (elle)" : "");
    }

    public class OfferItem
    {
        public string Name;
        public long Size;
        public long? Files; // klasörse içindeki dosya sayısı
    }

    public class Offer
    {
        public string From;
        public long Count, Total;
        public List<OfferItem> Items = new List<OfferItem>();
    }

    /// <summary>
    /// Alıcı: "kim var?" yayınına cevap verir, gelen dosyaları SaveDir'e yazar.
    /// Gelen baytlar önce gizli ".dosya-aktarim-&lt;tid&gt;" dosyasına yazılır; koparsa kalır,
    /// gönderen /durum ile sorup kaldığı yerden sürdürür. Paket (paket=1) klasöre açılır.
    /// </summary>
    public class Receiver
    {
        public string Name, Id;
        public volatile string SaveDir;
        public Func<Offer, bool> Ask;                 // engelleyici; null = onaysız
        public Action<string, string> Received;      // yol, gönderen
        public Action<string, long, long> Progress;  // ad, alınan, toplam
        public Action<string> Done;                  // ad
        public int Port { get; private set; }
        public int Active => active;

        TcpListener tcp;
        UdpClient udp;
        int active;
        volatile bool stopped;
        readonly object gate = new object();
        readonly Dictionary<string, DateTime> grants = new Dictionary<string, DateTime>();
        readonly HashSet<string> busy = new HashSet<string>();
        readonly SemaphoreSlim askLock = new SemaphoreSlim(1, 1);

        /// <summary>Port meşgulse işletim sisteminin verdiği porta düşer (gönderen portu yayın cevabından öğrenir).</summary>
        public void Start()
        {
            Directory.CreateDirectory(SaveDir);
            try { tcp = new TcpListener(IPAddress.Any, Proto.TransferPort) { ExclusiveAddressUse = true }; tcp.Start(); }
            catch (SocketException) { tcp = new TcpListener(IPAddress.Any, 0); tcp.Start(); }
            Port = ((IPEndPoint)tcp.LocalEndpoint).Port;
            new Thread(AcceptLoop) { IsBackground = true, Name = "al-tcp" }.Start();

            udp = new UdpClient();
            udp.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
            udp.Client.Bind(new IPEndPoint(IPAddress.Any, Proto.DiscoveryPort));
            udp.EnableBroadcast = true;
            Proto.NoConnReset(udp.Client);
            new Thread(UdpLoop) { IsBackground = true, Name = "al-udp" }.Start();

            ThreadPool.QueueUserWorkItem(_ => SweepParts());
        }

        public void Stop()
        {
            stopped = true;
            try { udp?.Close(); } catch { }
            try { tcp?.Stop(); } catch { }
        }

        Dictionary<string, object> Identity() => new Dictionary<string, object>
        {
            ["magic"] = Proto.Magic, ["name"] = Name, ["port"] = Port, ["id"] = Id,
            ["code"] = false, ["v"] = 2,
        };

        void UdpLoop()
        {
            while (!stopped)
            {
                try
                {
                    var ep = new IPEndPoint(IPAddress.Any, 0);
                    var data = udp.Receive(ref ep);
                    if (Encoding.UTF8.GetString(data) != Proto.Magic) continue;
                    var reply = Encoding.UTF8.GetBytes(Proto.ToJson(Identity()));
                    udp.Send(reply, reply.Length, ep); // cevap yalnız sorana
                }
                catch (ObjectDisposedException) { return; }
                catch { if (stopped) return; }
            }
        }

        void AcceptLoop()
        {
            while (!stopped)
            {
                TcpClient c;
                try { c = tcp.AcceptTcpClient(); }
                catch { if (stopped) return; continue; }
                ThreadPool.QueueUserWorkItem(_ => Handle(c));
            }
        }

        void SweepParts()
        {
            try
            {
                var limit = DateTime.Now.AddDays(-1);
                foreach (var e in new DirectoryInfo(SaveDir).EnumerateFileSystemInfos(Proto.PartPrefix + "*"))
                {
                    if (e.LastWriteTime >= limit) continue;
                    try { if (e is DirectoryInfo d) d.Delete(true); else e.Delete(); } catch { }
                }
            }
            catch { }
        }

        string Grant()
        {
            var token = Guid.NewGuid().ToString("N").Substring(0, 16);
            lock (gate)
            {
                var now = DateTime.UtcNow;
                foreach (var k in grants.Where(g => g.Value < now).Select(g => g.Key).ToList()) grants.Remove(k);
                grants[token] = now.AddMinutes(30);
            }
            return token;
        }

        bool Granted(string token)
        {
            if (token == null) return false;
            lock (gate) return grants.TryGetValue(token, out var until) && until > DateTime.UtcNow;
        }

        /// <summary>Sorular sırayla sorulur; iki gönderen aynı anda gelirse üst üste pencere açılmaz.</summary>
        bool AskUser(Offer o)
        {
            if (Ask == null) return true;
            if (!askLock.Wait(TimeSpan.FromSeconds(90))) return false;
            try { return Ask(o); }
            catch { return false; }
            finally { askLock.Release(); }
        }

        static string CleanTid(string raw)
        {
            if (raw == null) return null;
            var t = new string(raw.Where(c => c < 128 && char.IsLetterOrDigit(c)).ToArray());
            return t.Length == 0 || t.Length > 40 ? null : t;
        }

        static string ReadHead(Stream s)
        {
            var buf = new List<byte>(512);
            while (buf.Count < 16384)
            {
                var b = s.ReadByte();
                if (b < 0) return null;
                buf.Add((byte)b);
                var n = buf.Count;
                if (n >= 4 && buf[n - 4] == 13 && buf[n - 3] == 10 && buf[n - 2] == 13 && buf[n - 1] == 10)
                    return Encoding.UTF8.GetString(buf.ToArray(), 0, n - 4);
            }
            return null;
        }

        static void Reply(Stream s, int code, string body, bool json = true)
        {
            var data = Encoding.UTF8.GetBytes(body ?? "");
            var reason = code == 200 ? "OK" : code == 400 ? "Bad Request" : code == 403 ? "Forbidden"
                : code == 404 ? "Not Found" : code == 409 ? "Conflict" : "Error";
            var head = Encoding.ASCII.GetBytes("HTTP/1.1 " + code + " " + reason +
                "\r\nContent-Type: " + (json ? "application/json" : "text/plain") + "; charset=utf-8" +
                "\r\nContent-Length: " + data.Length + "\r\nConnection: close\r\n\r\n");
            s.Write(head, 0, head.Length);
            s.Write(data, 0, data.Length);
            s.Flush();
        }

        static void Json(Stream s, object body, int code = 200) => Reply(s, code, Proto.ToJson(body));

        void Handle(TcpClient c)
        {
            Interlocked.Increment(ref active);
            try
            {
                c.NoDelay = true;
                c.ReceiveTimeout = 30000;
                c.SendTimeout = 30000;
                var ns = c.GetStream();
                var input = new BufferedStream(ns, 1 << 16);
                try { Route(input, ns); }
                catch { try { Reply(ns, 500, "", false); } catch { } }
            }
            finally
            {
                try { c.Client.Shutdown(SocketShutdown.Send); } catch { }
                c.Close();
                Interlocked.Decrement(ref active);
            }
        }

        void Route(Stream input, Stream output)
        {
            var head = ReadHead(input);
            if (head == null) return;
            var lines = head.Split(new[] { "\r\n" }, StringSplitOptions.None);
            var first = lines[0].Split(' ');
            if (first.Length < 2) return;
            var method = first[0];
            long contentLength = -1;
            foreach (var line in lines.Skip(1))
            {
                var i = line.IndexOf(':');
                if (i > 0 && line.Substring(0, i).Trim().Equals("Content-Length", StringComparison.OrdinalIgnoreCase))
                    long.TryParse(line.Substring(i + 1).Trim(), out contentLength);
            }
            var path = first[1];
            var q = new Dictionary<string, string>();
            var qi = path.IndexOf('?');
            if (qi >= 0)
            {
                foreach (var pair in path.Substring(qi + 1).Split('&'))
                {
                    var eq = pair.IndexOf('=');
                    var k = eq < 0 ? pair : pair.Substring(0, eq);
                    var v = eq < 0 ? "" : pair.Substring(eq + 1);
                    try { q[Uri.UnescapeDataString(k.Replace('+', ' '))] = Uri.UnescapeDataString(v.Replace('+', ' ')); } catch { }
                }
                path = path.Substring(0, qi);
            }
            string Q(string k) => q.TryGetValue(k, out var v) ? v : null;

            if (method == "GET" && path == "/kim") { Json(output, Identity()); return; }

            if (method == "POST" && path == "/sor")
            {
                var offer = new Offer
                {
                    From = Q("kim") ?? "?",
                    Count = long.TryParse(Q("adet"), out var n) ? n : 1,
                    Total = long.TryParse(Q("toplam"), out var t) ? t : 0,
                };
                // Önizleme gövdesi küçük olmalı; şişkin gövde kesilir.
                var body = ReadSmall(input, contentLength, 4 * 1024 * 1024);
                if (Proto.FromJson(body)?.TryGetValue("items", out var raw) == true && raw is object[] items)
                {
                    foreach (var it in items.Take(200).OfType<Dictionary<string, object>>())
                    {
                        var name = Proto.SafeName(Proto.Str(it, "n"));
                        if (name == "") continue;
                        offer.Items.Add(new OfferItem
                        {
                            Name = name,
                            Size = Proto.Num(it, "s", 0),
                            Files = it.ContainsKey("d") ? Proto.Num(it, "d", 0) : (long?)null,
                        });
                    }
                }
                if (offer.Items.Count == 0 && !string.IsNullOrEmpty(Q("ad")))
                    offer.Items.Add(new OfferItem { Name = Proto.SafeName(Q("ad")), Size = offer.Total });
                if (!AskUser(offer)) { Reply(output, 403, "red", false); return; }
                Json(output, new Dictionary<string, object> { ["ok"] = true, ["izin"] = Grant() });
                return;
            }

            if (method == "GET" && path == "/durum")
            {
                var tid = CleanTid(Q("tid"));
                long have = 0;
                if (tid != null && File.Exists(PartPath(tid))) have = new FileInfo(PartPath(tid)).Length;
                Json(output, new Dictionary<string, object> { ["have"] = have });
                return;
            }

            if (method != "POST" || path != "/al") { Reply(output, 404, "", false); return; }

            var safe = Proto.SafeName(Q("ad") ?? "dosya");
            if (safe == "") safe = "dosya";
            var from = Q("kim") ?? "?";
            var bundle = Q("paket") == "1";
            var tidAl = CleanTid(Q("tid"));
            long.TryParse(Q("ofs"), out var ofs);
            if (!long.TryParse(Q("boyut"), out var total)) total = contentLength >= 0 ? ofs + contentLength : -1;

            // İzin anahtarı yoksa (eski sürüm gönderen) dosya başına sorulur — reddedilen gövde okunmaz.
            if (Ask != null && !Granted(Q("izin")))
            {
                var o = new Offer { From = from, Count = 1, Total = total };
                o.Items.Add(new OfferItem { Name = safe, Size = total });
                if (!AskUser(o)) { Reply(output, 403, "red", false); return; }
            }

            if (tidAl == null) { ReceiveLegacy(input, output, safe, from, contentLength, total); return; }

            lock (gate)
            {
                if (!busy.Add(tidAl))
                {
                    Json(output, new Dictionary<string, object> { ["have"] = -1 }, 409);
                    return;
                }
            }
            try
            {
                var part = PartPath(tidAl);
                var have = File.Exists(part) ? new FileInfo(part).Length : 0;
                if (ofs != have && ofs != 0)
                {
                    // Gönderen yanlış yerden başlıyor: doğru yeri söyle, gövdeyi alma.
                    Json(output, new Dictionary<string, object> { ["have"] = have }, 409);
                    return;
                }
                long got;
                using (var fs = new FileStream(part, ofs == 0 ? FileMode.Create : FileMode.Append,
                           FileAccess.Write, FileShare.None, 1 << 20))
                {
                    try { File.SetAttributes(part, FileAttributes.Hidden); } catch { }
                    got = CopyBody(input, fs, contentLength, ofs, total, safe);
                }
                if (total > 0 && got < total)
                {
                    // Yarım: dosya KALIR, gönderen sürdürecek.
                    try { Json(output, new Dictionary<string, object> { ["have"] = got }, 400); } catch { }
                    return;
                }
                var landed = bundle ? Unpack(part) : new List<string> { Finalize(part, safe) };
                foreach (var p in landed) Received?.Invoke(p, from);
                Json(output, new Dictionary<string, object>
                {
                    ["ok"] = true,
                    ["name"] = landed.Count == 0 ? safe : Path.GetFileName(landed[0]),
                });
            }
            finally
            {
                lock (gate) busy.Remove(tidAl);
                Done?.Invoke(safe);
            }
        }

        /// <summary>Eski sürüm gönderen (tid yok): doğrudan hedefe yazılır, yarım kalırsa silinir.</summary>
        void ReceiveLegacy(Stream input, Stream output, string safe, string from, long contentLength, long total)
        {
            string target;
            lock (gate)
            {
                target = Proto.UniquePath(Path.Combine(SaveDir, safe));
                File.WriteAllBytes(target, new byte[0]); // adı ayır
            }
            long got;
            try
            {
                using (var fs = new FileStream(target, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20))
                    got = CopyBody(input, fs, contentLength, 0, total, safe);
            }
            finally { Done?.Invoke(safe); }
            if (total > 0 && got < total)
            {
                try { File.Delete(target); } catch { }
                try { Reply(output, 400, "", false); } catch { }
                return;
            }
            Received?.Invoke(target, from);
            Json(output, new Dictionary<string, object> { ["ok"] = true, ["name"] = Path.GetFileName(target) });
        }

        string PartPath(string tid) => Path.Combine(SaveDir, Proto.PartPrefix + tid);

        static string ReadSmall(Stream s, long contentLength, int max)
        {
            if (contentLength <= 0) return "";
            var buf = new byte[Math.Min(contentLength, max)];
            var got = 0;
            while (got < buf.Length)
            {
                var n = s.Read(buf, got, buf.Length - got);
                if (n <= 0) break;
                got += n;
            }
            try { return Encoding.UTF8.GetString(buf, 0, got); } catch { return ""; }
        }

        long CopyBody(Stream src, Stream dst, long contentLength, long got, long total, string name)
        {
            var buf = new byte[256 * 1024];
            var left = contentLength < 0 ? long.MaxValue : contentLength;
            var tick = Environment.TickCount;
            while (left > 0)
            {
                int n;
                try { n = src.Read(buf, 0, (int)Math.Min(buf.Length, left)); }
                catch (IOException) { break; }
                catch (ObjectDisposedException) { break; }
                if (n <= 0) break;
                dst.Write(buf, 0, n);
                got += n;
                left -= n;
                if (Environment.TickCount - tick > 250)
                {
                    tick = Environment.TickCount;
                    Progress?.Invoke(name, got, total);
                }
            }
            Progress?.Invoke(name, got, total);
            return got;
        }

        string Finalize(string part, string safe)
        {
            lock (gate)
            {
                var target = Proto.UniquePath(Path.Combine(SaveDir, safe));
                File.Move(part, target);
                try { File.SetAttributes(target, FileAttributes.Normal); } catch { }
                return target;
            }
        }

        /// <summary>
        /// Paketi açar: her yol parçası SafeName'den geçer (".." düşer, Windows'a uymayan karakter '_'),
        /// üst düzeydeki her öğe SaveDir'e taşınır, ad çakışırsa "(1)" eklenir.
        /// </summary>
        List<string> Unpack(string part)
        {
            var tmp = part + "-x";
            var output = new List<string>();
            try
            {
                if (Directory.Exists(tmp)) Directory.Delete(tmp, true);
                Directory.CreateDirectory(tmp);
                using (var zip = ZipFile.OpenRead(part))
                {
                    foreach (var e in zip.Entries)
                    {
                        var segs = e.FullName.Replace('\\', '/').Split('/').Select(Proto.SafeName).Where(x => x != "").ToArray();
                        if (segs.Length == 0) continue;
                        var dest = Path.Combine(new[] { tmp }.Concat(segs).ToArray());
                        if (e.FullName.EndsWith("/") || e.FullName.EndsWith("\\")) { Directory.CreateDirectory(dest); continue; }
                        Directory.CreateDirectory(Path.GetDirectoryName(dest));
                        e.ExtractToFile(dest, true);
                        try { File.SetLastWriteTime(dest, e.LastWriteTime.DateTime); } catch { }
                    }
                }
                foreach (var e in new DirectoryInfo(tmp).GetFileSystemInfos())
                {
                    lock (gate)
                    {
                        var target = Proto.UniquePath(Path.Combine(SaveDir, e.Name));
                        if (e is DirectoryInfo d) d.MoveTo(target); else ((FileInfo)e).MoveTo(target);
                        output.Add(target);
                    }
                }
            }
            finally
            {
                try { File.Delete(part); } catch { }
                try { if (Directory.Exists(tmp)) Directory.Delete(tmp, true); } catch { }
            }
            return output;
        }
    }

    /// <summary>Ağdaki alıcıları sürekli arar: 1,5 sn'de bir yayın; 7 sn sesi çıkmayan listeden düşer.</summary>
    public class Scanner
    {
        public string OwnId;
        readonly Dictionary<string, Peer> peers = new Dictionary<string, Peer>();

        public void Start() => new Thread(Loop) { IsBackground = true, Name = "tara" }.Start();

        public void AddManual(Peer p)
        {
            p.Manual = true;
            lock (peers) peers[p.Key] = p;
        }

        public void AddBle(Peer p)
        {
            lock (peers) peers[p.Key] = p;
        }

        public List<Peer> Snapshot()
        {
            var now = DateTime.UtcNow;
            lock (peers)
            {
                return peers.Values
                    // Arka plandaki telefon ~1 sn'de bir, seyrek yayınlar: Bluetooth'a daha uzun süre tanınır.
                    .Where(p => p.Manual || now - p.Seen < TimeSpan.FromSeconds(p.IsBle ? 15 : 7))
                    // Aynı cihaz iki arayüzden (Wi-Fi + hotspot, Wi-Fi + Bluetooth) görünebilir; Wi-Fi öncelikli.
                    .GroupBy(p => p.Id != "" ? p.Id : p.Key)
                    .Select(g => g.OrderBy(p => p.IsBle).ThenByDescending(p => p.Seen).First())
                    .OrderBy(p => p.Name, StringComparer.CurrentCultureIgnoreCase)
                    .ToList();
            }
        }

        void Loop()
        {
            UdpClient udp = null;
            var magic = Encoding.UTF8.GetBytes(Proto.Magic);
            var lastAsk = Environment.TickCount - 10000;
            while (true)
            {
                try
                {
                    if (udp == null)
                    {
                        udp = new UdpClient(new IPEndPoint(IPAddress.Any, 0)) { EnableBroadcast = true };
                        udp.Client.ReceiveTimeout = 500;
                        Proto.NoConnReset(udp.Client);
                    }
                    if (Environment.TickCount - lastAsk > 1500)
                    {
                        lastAsk = Environment.TickCount;
                        // Hem genel hem alt ağ yayını: bazı yönlendiriciler/Android sürümleri birini yutuyor.
                        var targets = new HashSet<string> { "255.255.255.255" };
                        foreach (var a in Proto.LocalIPv4()) targets.Add(a.broadcast.ToString());
                        foreach (var t in targets)
                        {
                            try { udp.Send(magic, magic.Length, new IPEndPoint(IPAddress.Parse(t), Proto.DiscoveryPort)); } catch { }
                        }
                    }
                    var ep = new IPEndPoint(IPAddress.Any, 0);
                    byte[] data;
                    try { data = udp.Receive(ref ep); }
                    catch (SocketException e) when (e.SocketErrorCode == SocketError.TimedOut) { continue; }
                    var d = Proto.FromJson(Encoding.UTF8.GetString(data));
                    if (Proto.Str(d, "magic") != Proto.Magic) continue;
                    var id = Proto.Str(d, "id") ?? "";
                    if (id != "" && id == OwnId) continue; // kendi alıcımız
                    var p = new Peer
                    {
                        Name = Proto.Str(d, "name") ?? "?",
                        Host = ep.Address.ToString(),
                        Port = (int)Proto.Num(d, "port", Proto.TransferPort),
                        Id = id,
                        Seen = DateTime.UtcNow,
                    };
                    lock (peers)
                    {
                        if (peers.TryGetValue(p.Key, out var old) && old.Manual) p.Manual = true;
                        peers[p.Key] = p;
                    }
                }
                catch
                {
                    try { udp?.Close(); } catch { }
                    udp = null;
                    Thread.Sleep(1000);
                }
            }
        }
    }

    public class SendResult
    {
        public int Sent;
        public List<string> Errors = new List<string>();
        public bool Cancelled, Declined, WrongCode;
    }

    /// <summary>Gönderen: önce /sor ile onay, sonra her parça için /durum + /al; koparsa 2 dk kaldığı yerden dener.</summary>
    public class Sender
    {
        public string Name, Id;
        public Action<string> Status;
        public Action<string, long, long> Progress; // ad, giden (toplam üzerinden), toplam
        public Action<bool> Waiting;
        public Func<bool> IsCancelled = () => false;

        enum Outcome { Ok, Declined, WrongCode, Network, Cancelled, Fatal }

        class Item
        {
            public string Path, Name, Tid;
            public long Size;
            public long Files = 1;
            public bool Bundle;
        }

        public static Peer Probe(string host, int port = Proto.TransferPort)
        {
            try
            {
                var r = Req("http://" + host + ":" + port + "/kim", "GET", 3000);
                if (Call(r, out var body) != 200) return null;
                var d = Proto.FromJson(body);
                if (Proto.Str(d, "magic") != Proto.Magic) return null;
                return new Peer
                {
                    Name = Proto.Str(d, "name") ?? host, Host = host,
                    Port = (int)Proto.Num(d, "port", port), Id = Proto.Str(d, "id") ?? "",
                    Seen = DateTime.UtcNow,
                };
            }
            catch { return null; }
        }

        public SendResult Send(Peer peer, IList<string> paths)
        {
            var result = new SendResult();
            var temps = new List<string>();
            try
            {
                Status?.Invoke("Hazırlanıyor…");
                var plan = new List<Item>();
                foreach (var path in paths)
                {
                    if (IsCancelled()) { result.Cancelled = true; return result; }
                    try { plan.Add(Directory.Exists(path) ? Bundle(path, temps) : Plain(path)); }
                    catch (OperationCanceledException) { result.Cancelled = true; return result; }
                    catch (Exception e) { result.Errors.Add(Path.GetFileName(path) + ": " + e.Message); }
                }
                if (plan.Count == 0) return result;
                var totalBytes = plan.Sum(i => i.Size);
                var fileCount = plan.Sum(i => i.Files);

                // Ön soru: alıcı "Kabul et" diyene kadar bekler (telefon 90 sn'de vazgeçer).
                Status?.Invoke(peer.Name + " onayı bekleniyor…");
                var grant = "";
                try
                {
                    var items = plan.Take(200).Select(i =>
                    {
                        var m = new Dictionary<string, object> { ["n"] = i.Bundle ? i.Name.Substring(0, i.Name.Length - 4) : i.Name, ["s"] = i.Size };
                        if (i.Bundle) m["d"] = i.Files;
                        return m;
                    }).ToList();
                    var body = Encoding.UTF8.GetBytes(Proto.ToJson(new Dictionary<string, object> { ["items"] = items }));
                    var r = Req(Url(peer, "/sor", new Dictionary<string, string>
                    {
                        ["kim"] = Name, ["ad"] = plan[0].Name, ["adet"] = fileCount.ToString(), ["toplam"] = totalBytes.ToString(),
                    }), "POST", 95000);
                    r.ContentType = "application/json";
                    r.ContentLength = body.Length;
                    using (var s = r.GetRequestStream()) s.Write(body, 0, body.Length);
                    var code = Call(r, out var reply);
                    if (code == 403)
                    {
                        if (reply.Trim() == "red") result.Declined = true; else result.WrongCode = true;
                        return result;
                    }
                    if (code == 200) grant = Proto.Str(Proto.FromJson(reply), "izin") ?? "";
                }
                catch (WebException e) when (e.Status == WebExceptionStatus.Timeout)
                {
                    result.Declined = true; // cevap yok = kabul edilmedi
                    return result;
                }
                catch { /* ön soru başarısız (eski alıcı/ağ): gönderim yine denenir */ }

                long doneBytes = 0;
                foreach (var item in plan)
                {
                    if (IsCancelled()) { result.Cancelled = true; return result; }
                    var deadline = DateTime.UtcNow.AddMinutes(2);
                    var waiting = false;
                    Outcome outcome;
                    while (true)
                    {
                        if (IsCancelled()) { result.Cancelled = true; return result; }
                        outcome = SendOne(peer, item, grant, n =>
                        {
                            if (waiting) { waiting = false; Waiting?.Invoke(false); }
                            Progress?.Invoke(item.Name, doneBytes + n, totalBytes);
                        });
                        if (outcome == Outcome.Ok || outcome == Outcome.Fatal || outcome == Outcome.Declined ||
                            outcome == Outcome.WrongCode || outcome == Outcome.Cancelled) break;
                        if (DateTime.UtcNow > deadline) break;
                        // Bağlantı koptu: bekle, yeniden dene — baytlar alıcıda duruyor.
                        if (!waiting) { waiting = true; Waiting?.Invoke(true); }
                        Thread.Sleep(2000);
                    }
                    if (waiting) Waiting?.Invoke(false);
                    switch (outcome)
                    {
                        case Outcome.Ok: result.Sent += (int)item.Files; doneBytes += item.Size; break;
                        case Outcome.Declined: result.Declined = true; return result;
                        case Outcome.WrongCode: result.WrongCode = true; return result;
                        case Outcome.Cancelled: result.Cancelled = true; return result;
                        default: result.Errors.Add(item.Name + ": " + (outcome == Outcome.Network ? "bağlantı koptu" : "alıcı hata verdi")); break;
                    }
                }
                return result;
            }
            finally
            {
                foreach (var t in temps) { try { File.Delete(t); } catch { } }
            }
        }

        Item Plain(string path)
        {
            var fi = new FileInfo(path);
            var name = Proto.SafeName(fi.Name);
            return new Item
            {
                Path = path, Name = name == "" ? "dosya" : name, Size = fi.Length,
                // Aynı gönderen + aynı içerik → aynı kimlik: yeniden denemede kaldığı yerden sürer.
                Tid = Proto.Md5Hex(Id + "/" + fi.Name + "/" + fi.Length + "/" + fi.LastWriteTimeUtc.Ticks).Substring(0, 24),
            };
        }

        /// <summary>
        /// Klasör geçici bir ZIP'e (sıkıştırmasız) paketlenir, alıcıda klasör olarak açılır.
        /// ponytail: klasör diske bir kez daha yazılıyor; çok büyük klasörde akış ZIP'e geçilir (telefondaki ZipStream gibi).
        /// </summary>
        Item Bundle(string folder, List<string> temps)
        {
            var root = new DirectoryInfo(folder);
            var top = Proto.SafeName(root.Name);
            if (top == "") top = "klasor";
            var dir = Path.Combine(Path.GetTempPath(), "DosyaAktar");
            Directory.CreateDirectory(dir);
            var zipPath = Path.Combine(dir, Proto.Md5Hex(root.FullName).Substring(0, 16) + ".zip");
            temps.Add(zipPath);
            Status?.Invoke(top + " paketleniyor…");
            long count = 0;
            var sig = new StringBuilder(Id + "/" + root.FullName);
            using (var fs = new FileStream(zipPath, FileMode.Create, FileAccess.ReadWrite, FileShare.None, 1 << 20))
            using (var zip = new ZipArchive(fs, ZipArchiveMode.Create))
            {
                void Walk(DirectoryInfo d, string rel)
                {
                    zip.CreateEntry(rel + "/");
                    FileInfo[] files;
                    DirectoryInfo[] dirs;
                    try { files = d.GetFiles(); dirs = d.GetDirectories(); }
                    catch (UnauthorizedAccessException) { return; }
                    catch (IOException) { return; }
                    foreach (var f in files)
                    {
                        if (IsCancelled()) throw new OperationCanceledException();
                        FileStream src;
                        try { src = f.OpenRead(); } catch { continue; } // kilitli/izinsiz dosya atlanır
                        using (src)
                        {
                            var name = Proto.SafeName(f.Name);
                            if (name == "") continue;
                            var e = zip.CreateEntry(rel + "/" + name, CompressionLevel.NoCompression);
                            try { e.LastWriteTime = f.LastWriteTime; } catch { }
                            using (var es = e.Open()) src.CopyTo(es, 1 << 20);
                        }
                        count++;
                        sig.Append('/').Append(f.Name).Append('|').Append(f.Length).Append('|').Append(f.LastWriteTimeUtc.Ticks);
                    }
                    foreach (var sub in dirs)
                    {
                        if ((sub.Attributes & FileAttributes.ReparsePoint) != 0) continue; // kısayol döngüsü yok
                        var name = Proto.SafeName(sub.Name);
                        if (name != "") Walk(sub, rel + "/" + name);
                    }
                }
                Walk(root, top);
            }
            var size = new FileInfo(zipPath).Length;
            return new Item
            {
                Path = zipPath, Name = top + ".zip", Size = size, Files = count, Bundle = true,
                Tid = Proto.Md5Hex(sig + "/" + size).Substring(0, 24),
            };
        }

        Outcome SendOne(Peer peer, Item item, string grant, Action<long> onBytes)
        {
            try
            {
                // Kaç bayt zaten orada? Eski alıcı /durum bilmez (404) → baştan.
                long have = 0;
                var st = Req(Url(peer, "/durum", new Dictionary<string, string> { ["tid"] = item.Tid }), "GET", 10000);
                if (Call(st, out var stBody) == 200) have = Proto.Num(Proto.FromJson(stBody), "have", 0);
                if (have > item.Size || have < 0) have = 0;
                onBytes(have);

                var q = new Dictionary<string, string>
                {
                    ["ad"] = item.Name, ["kim"] = Name, ["tid"] = item.Tid,
                    ["ofs"] = have.ToString(), ["boyut"] = item.Size.ToString(),
                };
                if (item.Bundle) q["paket"] = "1";
                if (grant != "") q["izin"] = grant;
                // Paket alıcıda açılırken cevap gecikebilir: uzun zaman aşımı.
                var r = Req(Url(peer, "/al", q), "POST", 10 * 60 * 1000);
                r.ReadWriteTimeout = 60000;
                r.AllowWriteStreamBuffering = false;
                r.SendChunked = false;
                r.ContentLength = item.Size - have;
                r.ContentType = "application/octet-stream";
                using (var fs = new FileStream(item.Path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 1 << 20))
                using (var rs = r.GetRequestStream())
                {
                    fs.Seek(have, SeekOrigin.Begin);
                    var buf = new byte[256 * 1024];
                    var n = have;
                    var tick = Environment.TickCount;
                    var left = item.Size - have;
                    while (left > 0)
                    {
                        if (IsCancelled()) { r.Abort(); return Outcome.Cancelled; }
                        var k = fs.Read(buf, 0, (int)Math.Min(buf.Length, left));
                        if (k <= 0) return Outcome.Fatal; // dosya gönderilirken küçüldü
                        rs.Write(buf, 0, k);
                        n += k;
                        left -= k;
                        if (Environment.TickCount - tick > 200) { tick = Environment.TickCount; onBytes(n); }
                    }
                    onBytes(n);
                }
                var code = Call(r, out var reply);
                switch (code)
                {
                    case 200: return Outcome.Ok;
                    case 403: return reply.Trim() == "red" ? Outcome.Declined : Outcome.WrongCode;
                    case 400:
                    case 409: return Outcome.Network; // yeniden sor, doğru yerden sürdür
                    default: return Outcome.Fatal;
                }
            }
            catch (WebException) { return IsCancelled() ? Outcome.Cancelled : Outcome.Network; }
            catch (IOException) { return Outcome.Network; }
            catch { return Outcome.Fatal; }
        }

        static string Url(Peer p, string path, Dictionary<string, string> q) =>
            "http://" + p.Host + ":" + p.Port + path + "?" +
            string.Join("&", q.Select(kv => Uri.EscapeDataString(kv.Key) + "=" + Uri.EscapeDataString(kv.Value ?? "")));

        static HttpWebRequest Req(string url, string method, int timeoutMs)
        {
            var r = (HttpWebRequest)WebRequest.Create(url);
            r.Method = method;
            r.Proxy = null;          // sistem vekil sunucusu yerel ağı kaçırmasın
            r.KeepAlive = false;
            r.Timeout = timeoutMs;
            r.ReadWriteTimeout = timeoutMs;
            r.ServicePoint.Expect100Continue = false;
            return r;
        }

        /// <summary>Durum kodu + gövde; 4xx/5xx istisna değil. Ağ hatası WebException olarak çıkar.</summary>
        static int Call(HttpWebRequest r, out string body)
        {
            try
            {
                using (var resp = (HttpWebResponse)r.GetResponse())
                using (var sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8))
                {
                    body = sr.ReadToEnd();
                    return (int)resp.StatusCode;
                }
            }
            catch (WebException e) when (e.Response is HttpWebResponse hr)
            {
                using (hr)
                using (var sr = new StreamReader(hr.GetResponseStream(), Encoding.UTF8))
                {
                    body = sr.ReadToEnd();
                    return (int)hr.StatusCode;
                }
            }
        }
    }
}
