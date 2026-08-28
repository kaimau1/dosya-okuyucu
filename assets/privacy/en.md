# Privacy Policy — Dosya Okuyucu

**Last updated:** 28 August 2026 · **Version:** 0.1.0

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
| **Firebase sign-in & sync** | Google | Only if configured and signed in: your e-mail address and the settings you sync. If it is not configured the app runs in **local mode**. |
| **Network storage** (FTP/SFTP/SMB/WebDAV) | **Your own** server | Connection details and the files you transfer. These connections do not pass through us. |
| **Download manager** | The address you enter | The download request |
| **Translation** (ML Kit) | Google | Only while the language model is downloaded **for the first time**. Translation itself runs offline, on the device. |
| **Share / Print** | The app you choose | The file you share |

**Text recognition (OCR), document scanning and translation run on the
device** — your document contents are not uploaded for these features.

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
