using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using System.Text;
using System.Threading.Tasks;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;

namespace DosyaAktar
{
    /// <summary>
    /// Telefonun Bluetooth LE yayınını görür (Yakındakiler ekranı açıkken ya da kişisel derlemede
    /// "arka planda görünür ol") ve GATT'a "push" daveti yazar. UUID'ler ve kimlik kodlaması:
    /// ci/NearbyBle.kt — ikisi birlikte değişmeli. Dosya BLE'den AKMAZ: telefon bildirimde
    /// "Kabul et" deyince Yakındakiler açılır, bu bilgisayar onu Wi-Fi'de bulup kendisi gönderir.
    /// </summary>
    public class BleLink
    {
        static readonly Guid Service = new Guid("7d3f1c2a-4b6e-4f0a-9c1d-5e8b2a6f0d41");
        static readonly Guid Invite = new Guid("7d3f1c2b-4b6e-4f0a-9c1d-5e8b2a6f0d41");
        const ushort Manufacturer = 0xFFFF;

        BluetoothLEAdvertisementWatcher watcher;
        volatile bool stopped;

        // 0xFFFF "deneme" üretici kimliği başka cihazlarda da olabilir: yalnız hizmet UUID'mizi
        // yayınlamış adreslerin tarama yanıtı okunur (Windows ikisini ayrı olay olarak verir).
        readonly HashSet<ulong> ours = new HashSet<ulong>();

        public Action<Peer> Found;

        public void Start()
        {
            try
            {
                watcher = new BluetoothLEAdvertisementWatcher { ScanningMode = BluetoothLEScanningMode.Active };
                watcher.Received += OnReceived;
                // Bluetooth kapatılınca izleyici durur: açılınca kendiliğinden dönsün.
                watcher.Stopped += (s, e) =>
                {
                    if (!stopped) Task.Delay(5000).ContinueWith(_ => { try { if (!stopped) watcher.Start(); } catch { } });
                };
                watcher.Start();
            }
            catch { } // Bluetooth yok: yalnız Wi-Fi ile çalışılır
        }

        public void Stop()
        {
            stopped = true;
            try { watcher?.Stop(); } catch { }
        }

        void OnReceived(BluetoothLEAdvertisementWatcher w, BluetoothLEAdvertisementReceivedEventArgs e)
        {
            try
            {
                var adv = e.Advertisement;
                bool known;
                lock (ours)
                {
                    if (adv.ServiceUuids.Contains(Service)) ours.Add(e.BluetoothAddress);
                    known = ours.Contains(e.BluetoothAddress);
                }
                if (!known) return;
                foreach (var m in adv.ManufacturerData)
                {
                    if (m.CompanyId != Manufacturer) continue;
                    var data = m.Data.ToArray();
                    if (data.Length < 4) continue;
                    Found?.Invoke(new Peer
                    {
                        Id = string.Concat(data.Take(4).Select(b => b.ToString("x2"))),
                        Name = Encoding.UTF8.GetString(data, 4, data.Length - 4),
                        BleAddress = e.BluetoothAddress,
                        BleRandom = e.BluetoothAddressType == BluetoothAddressType.Random,
                        Seen = DateTime.UtcNow,
                    });
                }
            }
            catch { }
        }

        /// <summary>Daveti yazar; telefona ulaştıysa true (onay ayrıca bildirimde sorulur).</summary>
        public static async Task<bool> SendInvite(Peer peer, string json)
        {
            var bytes = Encoding.UTF8.GetBytes(json);
            BluetoothLEDevice dev = null;
            try
            {
                try
                {
                    dev = await BluetoothLEDevice.FromBluetoothAddressAsync(peer.BleAddress,
                        peer.BleRandom ? BluetoothAddressType.Random : BluetoothAddressType.Public);
                }
                catch { dev = await BluetoothLEDevice.FromBluetoothAddressAsync(peer.BleAddress); } // eski Windows 10
                if (dev == null) return false;
                var sr = await dev.GetGattServicesForUuidAsync(Service, BluetoothCacheMode.Uncached);
                if (sr.Status != GattCommunicationStatus.Success || sr.Services.Count == 0) return false;
                var svc = sr.Services[0];
                try
                {
                    var cr = await svc.GetCharacteristicsForUuidAsync(Invite, BluetoothCacheMode.Uncached);
                    if (cr.Status != GattCommunicationStatus.Success || cr.Characteristics.Count == 0) return false;
                    var res = await cr.Characteristics[0].WriteValueWithResultAsync(bytes.AsBuffer(), GattWriteOption.WriteWithResponse);
                    return res.Status == GattCommunicationStatus.Success;
                }
                finally { svc.Dispose(); }
            }
            catch { return false; }
            finally { dev?.Dispose(); }
        }
    }
}
