using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace DosyaAktar
{
    /// <summary>
    /// Gelenler klasörünün küçük resimli ızgarası (en yeni üstte). Önizleme Windows'un kendi
    /// küçük resim motorundan (Gezgin'deki foto/video karesi/PDF sayfası). Seçilenler dışarı
    /// sürüklenebilir (WhatsApp, Claude, Gezgin) ya da tek tuşla dosya olarak panoya kopyalanır.
    /// </summary>
    class Gallery : ListView
    {
        // ponytail: son 300 öğe; daha fazlası "Klasörü aç" ile Gezgin'de.
        const int MaxItems = 300;

        readonly ImageList thumbs = new ImageList { ColorDepth = ColorDepth.Depth32Bit };
        readonly FileSystemWatcher watcher = new FileSystemWatcher { IncludeSubdirectories = false };
        readonly System.Windows.Forms.Timer debounce = new System.Windows.Forms.Timer { Interval = 400 };
        readonly BlockingCollection<string> queue = new BlockingCollection<string>();
        readonly HashSet<string> requested = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        readonly int side;
        string folder;

        public event Action SelectionChangedDebounced;

        public Gallery(int thumbSide)
        {
            side = thumbSide;
            View = View.LargeIcon;
            MultiSelect = true;
            HideSelection = false;
            ShowItemToolTips = true;
            BorderStyle = BorderStyle.None;
            thumbs.ImageSize = new Size(side, side);
            LargeImageList = thumbs;
            DoubleBuffered = true;

            watcher.SynchronizingObject = this;
            watcher.Created += (s, e) => Poke();
            watcher.Deleted += (s, e) => Poke();
            watcher.Renamed += (s, e) => Poke();
            debounce.Tick += (s, e) => { debounce.Stop(); Reload(); };

            ItemDrag += (s, e) =>
            {
                var paths = SelectedPaths();
                if (paths.Length > 0) DoDragDrop(new DataObject(DataFormats.FileDrop, paths), DragDropEffects.Copy);
            };
            DoubleClick += (s, e) => { var p = SelectedPaths(); if (p.Length == 1) Open(p[0]); };
            KeyDown += (s, e) =>
            {
                if (e.Control && e.KeyCode == Keys.C) { CopySelected(); e.Handled = true; }
                else if (e.Control && e.KeyCode == Keys.A) { SelectAll(); e.Handled = true; }
                else if (e.KeyCode == Keys.Enter) { foreach (var p in SelectedPaths().Take(10)) Open(p); e.Handled = true; }
            };
            ItemSelectionChanged += (s, e) => SelectionChangedDebounced?.Invoke();

            var menu = new ContextMenuStrip();
            menu.Items.Add("Aç", null, (s, e) => { foreach (var p in SelectedPaths().Take(10)) Open(p); });
            menu.Items.Add("Kopyala  (Ctrl+C)", null, (s, e) => CopySelected());
            menu.Items.Add("Klasörde göster", null, (s, e) => { var p = SelectedPaths(); if (p.Length > 0) Reveal(p[0]); });
            ContextMenuStrip = menu;
        }

        bool loaderStarted;

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            if (loaderStarted) return;
            loaderStarted = true;
            var t = new Thread(ThumbLoop) { IsBackground = true, Name = "onizleme" };
            t.SetApartmentState(ApartmentState.STA); // kabuk COM nesneleri STA ister
            t.Start();
        }

        public void SetFolder(string dir)
        {
            folder = dir;
            try
            {
                Directory.CreateDirectory(dir);
                watcher.EnableRaisingEvents = false;
                watcher.Path = dir;
                watcher.EnableRaisingEvents = true;
            }
            catch { }
            Reload();
        }

        /// <summary>Klasör değişti: kısa beklemeyle yeniden okunur (bir paket onlarca olay üretir).</summary>
        public void Poke() { debounce.Stop(); debounce.Start(); }

        public void Reload()
        {
            if (folder == null) return;
            List<FileSystemInfo> entries;
            try
            {
                entries = new DirectoryInfo(folder).GetFileSystemInfos()
                    .Where(e => !e.Name.StartsWith(Proto.PartPrefix) && (e.Attributes & FileAttributes.Hidden) == 0)
                    // Taşınan dosya eski tarihini korur: yeni gelen, oluşturma zamanıyla üste çıkar.
                    .OrderByDescending(e => e.CreationTime > e.LastWriteTime ? e.CreationTime : e.LastWriteTime)
                    .Take(MaxItems)
                    .ToList();
            }
            catch { entries = new List<FileSystemInfo>(); }

            var selected = new HashSet<string>(SelectedPaths(), StringComparer.OrdinalIgnoreCase);
            BeginUpdate();
            Items.Clear();
            foreach (var e in entries)
            {
                var item = new ListViewItem(e.Name)
                {
                    Tag = e.FullName,
                    ToolTipText = e.Name + "\n" + (e is FileInfo f ? Proto.Size(f.Length) + "   ·   " : "klasör   ·   ") +
                                  e.LastWriteTime.ToString("dd.MM.yyyy HH:mm"),
                };
                var key = ThumbKey(e);
                if (thumbs.Images.ContainsKey(key)) item.ImageKey = key;
                else lock (requested) if (requested.Add(key)) queue.Add(key);
                item.Name = key;
                Items.Add(item);
                if (selected.Contains(e.FullName)) item.Selected = true;
            }
            EndUpdate();
            SelectionChangedDebounced?.Invoke();
        }

        static string ThumbKey(FileSystemInfo e) => e.FullName + "|" + e.LastWriteTimeUtc.Ticks;

        public string[] SelectedPaths() => SelectedItems.Cast<ListViewItem>().Select(i => (string)i.Tag).ToArray();

        public void SelectAll()
        {
            BeginUpdate();
            foreach (ListViewItem i in Items) i.Selected = true;
            EndUpdate();
        }

        /// <summary>Dosya olarak panoya: WhatsApp / Claude / Gezgin'de Ctrl+V.</summary>
        public int CopySelected()
        {
            var paths = SelectedPaths().Where(p => File.Exists(p) || Directory.Exists(p)).ToArray();
            if (paths.Length == 0) return 0;
            var list = new StringCollection();
            list.AddRange(paths);
            try { Clipboard.SetFileDropList(list); } catch { return 0; } // pano başka uygulamada kilitli
            return paths.Length;
        }

        static void Open(string path)
        {
            try { Process.Start(new ProcessStartInfo(path) { UseShellExecute = true }); } catch { }
        }

        public static void Reveal(string path)
        {
            try { Process.Start("explorer.exe", "/select,\"" + path + "\""); } catch { }
        }

        void ThumbLoop()
        {
            foreach (var key in queue.GetConsumingEnumerable())
            {
                var path = key.Substring(0, key.LastIndexOf('|'));
                var bmp = Thumbnail(path, side);
                if (bmp == null) continue;
                try
                {
                    BeginInvoke((Action)(() =>
                    {
                        if (!thumbs.Images.ContainsKey(key)) thumbs.Images.Add(key, bmp);
                        var item = Items[key];
                        if (item != null) item.ImageKey = key;
                    }));
                }
                catch { return; } // pencere kapandı
            }
        }

        // ── Windows küçük resmi (IShellItemImageFactory) ───────────────────────────

        [ComImport, Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IShellItemImageFactory
        {
            [PreserveSig] int GetImage(NativeSize size, int flags, out IntPtr phbm);
        }

        [StructLayout(LayoutKind.Sequential)]
        struct NativeSize { public int cx, cy; }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
        static extern void SHCreateItemFromParsingName(string path, IntPtr pbc,
            [MarshalAs(UnmanagedType.LPStruct)] Guid riid, out IShellItemImageFactory ppv);

        [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr h);

        /// <summary>Kareye sığdırılmış önizleme (ImageList kareyi gerer; en-boy oranı burada korunur).</summary>
        static Bitmap Thumbnail(string path, int side)
        {
            IntPtr h = IntPtr.Zero;
            try
            {
                SHCreateItemFromParsingName(path, IntPtr.Zero, typeof(IShellItemImageFactory).GUID, out var f);
                try
                {
                    if (f.GetImage(new NativeSize { cx = side, cy = side }, 0, out h) != 0 || h == IntPtr.Zero) return null;
                }
                finally { Marshal.ReleaseComObject(f); }
                using (var src = FromHBitmap(h))
                {
                    var square = new Bitmap(side, side, PixelFormat.Format32bppArgb);
                    using (var g = Graphics.FromImage(square))
                    {
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        var k = Math.Min((float)side / src.Width, (float)side / src.Height);
                        var w = (int)(src.Width * k);
                        var hh = (int)(src.Height * k);
                        g.DrawImage(src, (side - w) / 2, (side - hh) / 2, w, hh);
                    }
                    return square;
                }
            }
            catch { return null; }
            finally { if (h != IntPtr.Zero) DeleteObject(h); }
        }

        /// <summary>
        /// FromHbitmap saydamlığı atar (simgeler siyah zeminli çıkar): baytlar ARGB olarak yeniden okunur.
        /// Fotoğraf küçük resminde alfa hep 0 gelebilir — o durumda düz RGB kullanılır.
        /// </summary>
        static Bitmap FromHBitmap(IntPtr h)
        {
            var bmp = Image.FromHbitmap(h);
            if (Image.GetPixelFormatSize(bmp.PixelFormat) < 32) return bmp;
            var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, bmp.PixelFormat);
            var argb = new Bitmap(bmp.Width, bmp.Height, PixelFormat.Format32bppArgb);
            var dst = argb.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var anyAlpha = false;
            try
            {
                // Satır satır: kabuk DIB'i alttan-üste (negatif adım) verebiliyor.
                var row = new byte[bmp.Width * 4];
                for (var y = 0; y < bmp.Height; y++)
                {
                    Marshal.Copy(data.Scan0 + y * data.Stride, row, 0, row.Length);
                    if (!anyAlpha) for (var i = 3; i < row.Length; i += 4) if (row[i] != 0) { anyAlpha = true; break; }
                    Marshal.Copy(row, 0, dst.Scan0 + y * dst.Stride, row.Length);
                }
            }
            finally
            {
                argb.UnlockBits(dst);
                bmp.UnlockBits(data);
            }
            if (anyAlpha) { bmp.Dispose(); return argb; }
            argb.Dispose();
            var opaque = new Bitmap(bmp);
            bmp.Dispose();
            return opaque;
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                queue.CompleteAdding();
                watcher.Dispose();
                debounce.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
