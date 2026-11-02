using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Media;
using System.Net;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace DosyaAktar
{
    static class Program
    {
        [DllImport("user32.dll")] static extern bool SetProcessDPIAware();

        [STAThread]
        static void Main()
        {
            // İki örnek aynı portları kapışmasın.
            using (new Mutex(true, "DosyaOkuyucu-DosyaAktar", out var first))
            {
                if (!first) { MessageBox.Show("Dosya Aktar zaten açık.", "Dosya Aktar"); return; }
                try { SetProcessDPIAware(); } catch { }
                ServicePointManager.Expect100Continue = false;
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new MainForm());
            }
        }
    }

    /// <summary>%APPDATA%\DosyaAktar\ayar.txt — "anahtar=değer" satırları.</summary>
    static class Settings
    {
        static readonly string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DosyaAktar");
        static readonly string FilePath = Path.Combine(Dir, "ayar.txt");

        public static Dictionary<string, string> Load()
        {
            var d = new Dictionary<string, string>();
            try
            {
                foreach (var line in File.ReadAllLines(FilePath))
                {
                    var i = line.IndexOf('=');
                    if (i > 0) d[line.Substring(0, i)] = line.Substring(i + 1);
                }
            }
            catch { }
            return d;
        }

        public static void Save(Dictionary<string, string> d)
        {
            try
            {
                Directory.CreateDirectory(Dir);
                File.WriteAllLines(FilePath, d.Select(kv => kv.Key + "=" + kv.Value));
            }
            catch { }
        }
    }

    class LogEntry
    {
        public string Text, Path;
        public override string ToString() => Text;
    }

    class MainForm : Form
    {
        readonly Dictionary<string, string> settings = Settings.Load();
        readonly string deviceName, deviceId;
        readonly Receiver receiver;
        readonly Scanner scanner;
        volatile bool sending, cancel;

        readonly ListBox devices = new ListBox();
        readonly TextBox ipBox = new TextBox();
        readonly Label drop = new Label();
        readonly Button pickFiles = new Button(), pickFolder = new Button(), cancelBtn = new Button();
        readonly ProgressBar bar = new ProgressBar();
        readonly Label status = new Label(), recvStatus = new Label(), info = new Label();
        readonly ListBox log = new ListBox();
        readonly System.Windows.Forms.Timer refresh = new System.Windows.Forms.Timer { Interval = 1000 };

        float scale = 1f;
        int S(int px) => (int)(px * scale);

        public MainForm()
        {
            using (var g = CreateGraphics()) scale = g.DpiX / 96f;

            if (!settings.TryGetValue("id", out deviceId) || deviceId.Length != 8)
            {
                deviceId = Guid.NewGuid().ToString("N").Substring(0, 8);
                settings["id"] = deviceId;
                Settings.Save(settings);
            }
            deviceName = settings.TryGetValue("ad", out var n) && n.Trim() != "" ? n.Trim() : Environment.UserName + " (PC)";
            if (!settings.TryGetValue("klasor", out var saveDir) || saveDir.Trim() == "")
                saveDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads", "Dosya Okuyucu");

            receiver = new Receiver
            {
                Name = deviceName, Id = deviceId, SaveDir = saveDir,
                Ask = AskUser,
                Received = (path, from) => Ui(() => AddLog("⬇  " + System.IO.Path.GetFileName(path) + "   ←  " + from, path)),
                Progress = (name, got, total) => Ui(() => recvStatus.Text = "Alınıyor: " + name + "  " +
                    (total > 0 ? (got * 100 / total) + "%  (" + Proto.Size(got) + " / " + Proto.Size(total) + ")" : Proto.Size(got))),
                Done = name => Ui(() => { if (receiver.Active <= 1) recvStatus.Text = ""; }),
            };
            scanner = new Scanner { OwnId = deviceId };

            BuildUi();
            Load += (s, e) => StartServices();
            FormClosing += OnClosing;
        }

        void BuildUi()
        {
            Text = "Dosya Aktar — Dosya Okuyucu";
            Font = new Font("Segoe UI", 10f);
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(S(900), S(620));
            MinimumSize = new Size(S(680), S(520));
            BackColor = Color.FromArgb(0xFA, 0xF8, 0xF2);

            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3, Padding = new Padding(S(12)) };
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, S(200)));
            Controls.Add(root);

            // Başlık
            var head = new TableLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, ColumnCount = 1, Margin = new Padding(0, 0, 0, S(8)) };
            head.Controls.Add(new Label { Text = "Bu bilgisayar: " + deviceName, AutoSize = true, Font = new Font("Segoe UI Semibold", 14f) });
            info.AutoSize = true;
            info.ForeColor = Color.FromArgb(0x55, 0x55, 0x55);
            head.Controls.Add(info);
            root.Controls.Add(head, 0, 0);

            var main = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1 };
            main.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 40));
            main.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 60));
            root.Controls.Add(main, 0, 1);

            // Sol: cihazlar
            var left = new GroupBox { Text = "Yakındaki cihazlar", Dock = DockStyle.Fill, Padding = new Padding(S(8)) };
            var leftGrid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2 };
            leftGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            leftGrid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            devices.Dock = DockStyle.Fill;
            devices.Font = new Font("Segoe UI", 11.5f);
            devices.IntegralHeight = false;
            devices.BorderStyle = BorderStyle.None;
            leftGrid.Controls.Add(devices, 0, 0);
            var manual = new TableLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, ColumnCount = 2 };
            manual.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            manual.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            ipBox.Dock = DockStyle.Fill;
            SetCue(ipBox, "Görünmüyorsa IP yazın (ör. 192.168.1.5)");
            var add = new Button { Text = "Ekle", AutoSize = true };
            add.Click += (s, e) => AddManual();
            ipBox.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; AddManual(); } };
            manual.Controls.Add(ipBox, 0, 0);
            manual.Controls.Add(add, 1, 0);
            leftGrid.Controls.Add(manual, 0, 1);
            left.Controls.Add(leftGrid);
            main.Controls.Add(left, 0, 0);

            // Sağ: gönder
            var right = new GroupBox { Text = "Gönder", Dock = DockStyle.Fill, Padding = new Padding(S(8)) };
            var rightGrid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 4 };
            rightGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            rightGrid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            rightGrid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            rightGrid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            drop.Dock = DockStyle.Fill;
            drop.TextAlign = ContentAlignment.MiddleCenter;
            drop.BackColor = Color.White;
            drop.BorderStyle = BorderStyle.FixedSingle;
            drop.Font = new Font("Segoe UI", 12f);
            drop.AllowDrop = true;
            drop.Cursor = Cursors.Hand;
            drop.DragEnter += (s, e) =>
            {
                var ok = e.Data.GetDataPresent(DataFormats.FileDrop) && !sending;
                e.Effect = ok ? DragDropEffects.Copy : DragDropEffects.None;
                if (ok) drop.BackColor = Color.FromArgb(0xE6, 0xF0, 0xFF);
            };
            drop.DragLeave += (s, e) => drop.BackColor = Color.White;
            drop.DragDrop += (s, e) =>
            {
                drop.BackColor = Color.White;
                if (e.Data.GetData(DataFormats.FileDrop) is string[] paths) StartSend(paths);
            };
            drop.Click += (s, e) => PickFiles();
            rightGrid.Controls.Add(drop, 0, 0);

            var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, Margin = new Padding(0, S(6), 0, 0) };
            pickFiles.Text = "Dosya seç…";
            pickFolder.Text = "Klasör seç…";
            cancelBtn.Text = "İptal";
            foreach (var b in new[] { pickFiles, pickFolder, cancelBtn }) { b.AutoSize = true; b.Padding = new Padding(S(6), S(2), S(6), S(2)); buttons.Controls.Add(b); }
            cancelBtn.Enabled = false;
            pickFiles.Click += (s, e) => PickFiles();
            pickFolder.Click += (s, e) =>
            {
                using (var d = new FolderBrowserDialog { Description = "Gönderilecek klasör" })
                    if (d.ShowDialog(this) == DialogResult.OK) StartSend(new[] { d.SelectedPath });
            };
            cancelBtn.Click += (s, e) => { cancel = true; status.Text = "İptal ediliyor…"; };
            rightGrid.Controls.Add(buttons, 0, 1);
            bar.Dock = DockStyle.Fill;
            bar.Height = S(18);
            bar.Maximum = 1000;
            rightGrid.Controls.Add(bar, 0, 2);
            status.AutoSize = true;
            status.Margin = new Padding(0, S(4), 0, 0);
            rightGrid.Controls.Add(status, 0, 3);
            right.Controls.Add(rightGrid);
            main.Controls.Add(right, 1, 0);

            // Alt: gelenler ve geçmiş
            var bottom = new GroupBox { Text = "Gelenler ve geçmiş  (çift tıkla: klasörde göster)", Dock = DockStyle.Fill, Padding = new Padding(S(8)) };
            var bottomGrid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2 };
            bottomGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            bottomGrid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            log.Dock = DockStyle.Fill;
            log.IntegralHeight = false;
            log.BorderStyle = BorderStyle.None;
            log.DoubleClick += (s, e) => { if (log.SelectedItem is LogEntry le && le.Path != null) Reveal(le.Path); };
            bottomGrid.Controls.Add(log, 0, 0);
            var bb = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true };
            var open = new Button { Text = "Gelenler klasörünü aç", AutoSize = true };
            open.Click += (s, e) => { Directory.CreateDirectory(receiver.SaveDir); Process.Start("explorer.exe", "\"" + receiver.SaveDir + "\""); };
            var change = new Button { Text = "Klasörü değiştir…", AutoSize = true };
            change.Click += (s, e) => ChangeFolder();
            recvStatus.AutoSize = true;
            recvStatus.Margin = new Padding(S(10), S(8), 0, 0);
            recvStatus.ForeColor = Color.FromArgb(0x1A, 0x5F, 0xB4);
            bb.Controls.Add(open);
            bb.Controls.Add(change);
            bb.Controls.Add(recvStatus);
            bottomGrid.Controls.Add(bb, 0, 1);
            bottom.Controls.Add(bottomGrid);
            root.Controls.Add(bottom, 0, 2);

            refresh.Tick += (s, e) => RefreshDevices();
            UpdateInfo();
            RefreshDevices();
        }

        void StartServices()
        {
            try { receiver.Start(); }
            catch (Exception e)
            {
                MessageBox.Show(this, "Alıcı başlatılamadı — telefondan bu bilgisayara gönderim çalışmaz.\n\n" + e.Message,
                    "Dosya Aktar", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            scanner.Start();
            refresh.Start();
            UpdateInfo();
        }

        void UpdateInfo()
        {
            var ips = string.Join(", ", Proto.LocalIPv4().Select(a => a.ip.ToString()));
            info.Text = "Telefonda Dosya Okuyucu › Yakındakiler ekranını açın; bu bilgisayar orada görünür.\n" +
                        "IP: " + (ips == "" ? "ağ yok" : ips) + "   ·   Gelenler: " + receiver.SaveDir;
        }

        void RefreshDevices()
        {
            var snap = scanner.Snapshot();
            var now = devices.Items.Cast<Peer>().Select(p => p.Key + p.Name);
            if (!now.SequenceEqual(snap.Select(p => p.Key + p.Name)))
            {
                var sel = (devices.SelectedItem as Peer)?.Key;
                devices.BeginUpdate();
                devices.Items.Clear();
                foreach (var p in snap) devices.Items.Add(p);
                var i = snap.FindIndex(p => p.Key == sel);
                if (i >= 0) devices.SelectedIndex = i;
                else if (snap.Count == 1) devices.SelectedIndex = 0;
                devices.EndUpdate();
            }
            if (!sending)
                drop.Text = snap.Count == 0
                    ? "Henüz cihaz yok.\n\nTelefon aynı Wi-Fi'de (ya da bilgisayar telefonun\nhotspot'unda) olmalı ve Yakındakiler ekranı açık olmalı."
                    : "Göndermek için dosya ya da klasörü buraya sürükleyin\n\nya da tıklayıp seçin";
        }

        void AddManual()
        {
            var text = ipBox.Text.Trim();
            if (text == "") return;
            var host = text;
            var port = Proto.TransferPort;
            var c = text.LastIndexOf(':');
            if (c > 0 && int.TryParse(text.Substring(c + 1), out var pp)) { host = text.Substring(0, c); port = pp; }
            if (!IPAddress.TryParse(host, out _)) { MessageBox.Show(this, "Geçerli bir IP adresi yazın (ör. 192.168.1.5).", "Dosya Aktar"); return; }
            ipBox.Enabled = false;
            Task.Run(() => Sender.Probe(host, port)).ContinueWith(t => Ui(() =>
            {
                ipBox.Enabled = true;
                if (t.Result == null)
                {
                    MessageBox.Show(this, host + " adresinde açık bir Dosya Okuyucu bulunamadı.\nTelefonda Yakındakiler ekranı açık mı?", "Dosya Aktar");
                    return;
                }
                scanner.AddManual(t.Result);
                ipBox.Text = "";
                RefreshDevices();
            }));
        }

        void PickFiles()
        {
            if (sending) return;
            using (var d = new OpenFileDialog { Multiselect = true, Title = "Gönderilecek dosyalar" })
                if (d.ShowDialog(this) == DialogResult.OK) StartSend(d.FileNames);
        }

        void StartSend(string[] paths)
        {
            if (sending || paths == null || paths.Length == 0) return;
            var peer = devices.SelectedItem as Peer ?? (devices.Items.Count == 1 ? devices.Items[0] as Peer : null);
            if (peer == null)
            {
                MessageBox.Show(this, devices.Items.Count == 0
                    ? "Yakında cihaz yok. Telefonda Yakındakiler ekranını açın."
                    : "Önce soldan göndereceğiniz cihazı seçin.", "Dosya Aktar");
                return;
            }
            sending = true;
            cancel = false;
            SetSending(true);
            bar.Value = 0;
            var sender = new Sender
            {
                Name = deviceName, Id = deviceId,
                IsCancelled = () => cancel,
                Status = text => Ui(() => status.Text = text),
                Waiting = w => Ui(() => { if (w) status.Text = "Bağlantı koptu, yeniden deneniyor…"; }),
                Progress = (name, done, total) => Ui(() =>
                {
                    bar.Value = total > 0 ? (int)Math.Min(1000, done * 1000 / total) : 0;
                    status.Text = "Gönderiliyor: " + name + "   " + Proto.Size(done) + " / " + Proto.Size(total);
                }),
            };
            Task.Run(() =>
            {
                SendResult r;
                try { r = sender.Send(peer, paths); }
                catch (Exception e) { r = new SendResult(); r.Errors.Add(e.Message); }
                Ui(() => Finish(peer, r));
            });
        }

        void Finish(Peer peer, SendResult r)
        {
            sending = false;
            SetSending(false);
            string text;
            if (r.Declined) text = "✗  " + peer.Name + " gönderimi kabul etmedi.";
            else if (r.WrongCode) text = "✗  " + peer.Name + " eşleştirme kodu istiyor (bu sürüm desteklemiyor).";
            else if (r.Cancelled) text = "İptal edildi (" + r.Sent + " dosya gitti).";
            else if (r.Errors.Count > 0) text = "⚠  " + r.Sent + " dosya gitti, " + r.Errors.Count + " gitmedi: " + string.Join("; ", r.Errors);
            else text = "✓  " + r.Sent + " dosya gönderildi  →  " + peer.Name;
            if (!r.Declined && !r.Cancelled && r.Errors.Count == 0) bar.Value = bar.Maximum;
            status.Text = text;
            AddLog("⬆  " + text, null);
            RefreshDevices();
        }

        void SetSending(bool on)
        {
            cancelBtn.Enabled = on;
            pickFiles.Enabled = pickFolder.Enabled = !on;
            drop.Cursor = on ? Cursors.Default : Cursors.Hand;
            if (on) drop.Text = "Gönderiliyor…";
        }

        void AddLog(string text, string path)
        {
            log.Items.Insert(0, new LogEntry { Text = DateTime.Now.ToString("HH:mm") + "   " + text, Path = path });
            while (log.Items.Count > 500) log.Items.RemoveAt(log.Items.Count - 1);
        }

        static void Reveal(string path)
        {
            try { Process.Start("explorer.exe", "/select,\"" + path + "\""); } catch { }
        }

        void ChangeFolder()
        {
            using (var d = new FolderBrowserDialog { Description = "Gelen dosyalar nereye kaydedilsin?", SelectedPath = receiver.SaveDir })
            {
                if (d.ShowDialog(this) != DialogResult.OK) return;
                receiver.SaveDir = d.SelectedPath;
                settings["klasor"] = d.SelectedPath;
                Settings.Save(settings);
                UpdateInfo();
            }
        }

        /// <summary>Alıcı iş parçacığından çağrılır; pencere açılana ve cevaplanana kadar bekler.</summary>
        bool AskUser(Offer offer)
        {
            var ok = false;
            try
            {
                Invoke((Action)(() =>
                {
                    if (WindowState == FormWindowState.Minimized) WindowState = FormWindowState.Normal;
                    Activate();
                    SystemSounds.Asterisk.Play();
                    using (var f = new AskForm(offer, S)) ok = f.ShowDialog(this) == DialogResult.Yes;
                }));
            }
            catch { return false; } // pencere kapanıyor
            return ok;
        }

        void Ui(Action a)
        {
            try { if (!IsDisposed && IsHandleCreated) BeginInvoke(a); } catch { }
        }

        void OnClosing(object s, FormClosingEventArgs e)
        {
            if ((sending || receiver.Active > 0) &&
                MessageBox.Show(this, "Aktarım sürüyor. Kapatılırsa yarıda kalır (sonra kaldığı yerden sürdürülebilir). Kapatılsın mı?",
                    "Dosya Aktar", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
            {
                e.Cancel = true;
                return;
            }
            cancel = true;
            refresh.Stop();
            receiver.Stop();
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);

        static void SetCue(TextBox box, string cue) =>
            box.HandleCreated += (s, e) => SendMessage(box.Handle, 0x1501, (IntPtr)1, cue); // EM_SETCUEBANNER
    }

    /// <summary>Gelen dosya onayı. 85 sn içinde cevap yoksa reddeder (telefon 90 sn'de vazgeçiyor).</summary>
    class AskForm : Form
    {
        int left = 85;

        public AskForm(Offer o, Func<int, int> S)
        {
            Text = "Gelen dosya";
            Font = new Font("Segoe UI", 10f);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            TopMost = true;
            ClientSize = new Size(S(460), S(340));

            var grid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3, Padding = new Padding(S(12)) };
            grid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            grid.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            grid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            grid.Controls.Add(new Label
            {
                AutoSize = true,
                Font = new Font("Segoe UI Semibold", 11.5f),
                Text = o.From + " size " + o.Count + " dosya göndermek istiyor" + (o.Total > 0 ? " (" + Proto.Size(o.Total) + ")" : "") + ".",
                MaximumSize = new Size(S(430), 0),
                Margin = new Padding(0, 0, 0, S(8)),
            }, 0, 0);
            var list = new ListBox { Dock = DockStyle.Fill, IntegralHeight = false };
            foreach (var it in o.Items)
                list.Items.Add(it.Name + (it.Files != null ? "   (klasör, " + it.Files + " dosya)" : "") + "   —   " + Proto.Size(it.Size));
            grid.Controls.Add(list, 0, 1);
            var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, FlowDirection = FlowDirection.RightToLeft, Margin = new Padding(0, S(8), 0, 0) };
            var yes = new Button { Text = "Kabul et", AutoSize = true, DialogResult = DialogResult.Yes, Padding = new Padding(S(10), S(2), S(10), S(2)) };
            var no = new Button { Text = "Reddet (85)", AutoSize = true, DialogResult = DialogResult.No, Padding = new Padding(S(10), S(2), S(10), S(2)) };
            buttons.Controls.Add(yes);
            buttons.Controls.Add(no);
            grid.Controls.Add(buttons, 0, 2);
            Controls.Add(grid);
            AcceptButton = yes;
            CancelButton = no;

            var timer = new System.Windows.Forms.Timer { Interval = 1000 };
            timer.Tick += (s, e) =>
            {
                left--;
                no.Text = "Reddet (" + left + ")";
                if (left <= 0) { timer.Stop(); DialogResult = DialogResult.No; }
            };
            Shown += (s, e) => { Activate(); timer.Start(); };
            FormClosed += (s, e) => timer.Dispose();
        }
    }
}
