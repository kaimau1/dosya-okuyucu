# Privacy Policy — Dosya Okuyucu

**Last updated:** 2 November 2026 · **Version:** 0.2.0

## Summary

Dosya Okuyucu is a file manager and document reader/editor that runs **on your
device**. We do **not** operate a server that collects your files, tracks you or
sells data. The app contains **no ads** and **no usage analytics**.

Your data leaves the device only through an action **you** start; every such
action is listed below.

## 1. Data that stays on your device

Kept in the app's private folder and never sent anywhere:

- Your settings (theme, language, layout, start folder)
- Recent files, open history, tags, favourites
- Search index and thumbnail cache
- Files in the recycle bin
- Folder-lock PIN and the list of locked folders
- AI long-term memory notes (if you saved any)
- **Crash reports** — see below

Uninstalling the app deletes all of it.

## 2. Data that leaves the device — only on actions you start

| Action | Goes to | What is sent |
|---|---|---|
| **Gemini AI** (chat, summary, analysis) | Google — `generativelanguage.googleapis.com` | Your question and the text of the file you opened for the AI. Sent with **your own API key**, which you enter, is stored on the device and never passes through a server of ours. |
| **Google Drive** | Google | Only if you connect it: the files you upload/download and the file listing |
| **Network storage** (FTP/SFTP/SMB/WebDAV) | **Your own** server | Connection details and the files you transfer. These connections do not pass through us. |
| **Download manager** | The address you enter | The download request |
| **Translation** (ML Kit) | Google | Only while the language model is downloaded **for the first time**. Translation itself runs offline, on the device. |
| **Share / Print** | The app you choose | The file you share |
| **AI meaning search** | Google — `generativelanguage.googleapis.com` | **Only the search query you type** (with your own key). File names and contents are not sent; matching happens on the device. |
| **AI tagging / sorting into categories** | Google — `generativelanguage.googleapis.com` | For the files you select: **name, extension, the NAME of the folder they are in** (not the full path), size and month (for a category analysis also a count/size summary). File contents are not sent; the camera folder and locked folders are never sent. Suggestions are not written until you approve them. |
| **AI voices** (Antalia-2 Mini, EMA Lightning) | Hugging Face — `huggingface.co` | Only while **you download** a voice: the request for the model files. Your text is never sent — speech is generated on the device, offline. |

**Text recognition (OCR), smart cleanup analysis, audiobook creation,
document scanning and translation run on the
device** — your document contents are not uploaded for these features.

**Showing text as a QR code** uses no network: the text is inside the QR
code that the other person's camera reads and is not uploaded anywhere.

**Nearby** (sending files to a nearby device or browser) **uses no
third-party server**; files go directly between the two devices over the
local network:

- **Bluetooth LE only for discovery and invitations:** while the Nearby
  screen is open, your phone advertises its display name and a random ID
  unique to this installation. Files never travel over Bluetooth.
- **Local network:** devices on the same Wi-Fi find each other by local
  broadcast; without a shared Wi-Fi the phone creates a temporary network
  with no internet (hotspot).
- **Receiving in a browser:** while sending, the phone opens a web page that
  is reachable only on the local network (port 8080); the page is protected
  by a 6-letter code and closes when the transfer ends.
- The location permission (Android 12 and earlier only) is requested because
  the system requires it for these network operations; **your location is
  never read or stored.**

The **assistant bridge** exists only in the developer's **personal build**
(not in the store or GitHub releases): an assistant app signed with the same
key can have a file read aloud or open its summary. Other apps cannot use
this bridge; no data leaves the device.

## 3. Crash reports

When the app hits an unexpected error, a technical summary (error message,
stack trace, time, Android version) is written to a file **on your device**.
These reports:

- Are **never sent anywhere automatically.**
- Can be read in full under Settings → About → **Crash reports**.
- Leave the device only if you press **Share**, and only to where you choose.
- Can be deleted at any time with **Clear**.
- Are limited to the last 20 entries.

An error message may contain the name or path of the file that caused it.
That is why the full text is shown on screen before sharing — you decide with
the content in front of you.

## 4. Permissions and why

| Permission | Why |
|---|---|
| All files access (`MANAGE_EXTERNAL_STORAGE`) | So a file manager can browse the folders on your phone. If you decline, the app still works; only media folders are visible. |
| Media (images/video/audio) | Gallery, players and thumbnails |
| Camera | Document scanner only. The app works fully on devices without a camera. |
| Notifications | Progress of long jobs (copy, compress, download) |
| Usage access (`PACKAGE_USAGE_STATS`) | The **last-opened date** on the "Apps" screen. If you decline, the list still works. |
| Install unknown apps | To open the system installer when you tap an `.apk` file |
| Bluetooth, nearby devices, Wi-Fi state | Nearby: finding a nearby phone, invitations and the temporary network (above). If you refuse, QR and same-Wi-Fi transfer still work. |
| Location (Android 12 and earlier only) | Older Android versions tie Bluetooth scanning and the temporary network to the location permission. Location is never read. |
| Seeing installed apps | The "Apps" screen: list, size, the system's uninstall dialog. The list never leaves the device. |
| Running after reboot | If you turned it on, so that the periodic job of SD-card unified storage survives a restart. |
| Internet | The actions in section 2 |

## 5. Children

The app is not directed at children and does not knowingly collect data from
them (it does not collect data from anyone).

## 6. Changes

When this text changes, the date above is updated. The current version is
always inside the app (Settings → Privacy → Privacy policy) and in the
repository.

## 7. Contact

Questions and reports:
<https://github.com/kaimau1/dosya-okuyucu/issues>
