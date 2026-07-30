/// **Mesajlaşma dosyalarının tür kırılımı** (WhatsApp / Telegram …).
///
/// Kullanıcı isteği (2026-07-29): *"WhatsApp telegram gibi yerlerden gelen
/// resim görüntü belge video vs grubuna kişiye göre filtreleme"*.
///
/// ## DÜRÜST SINIR — kişi/grup dosya sisteminden okunamaz
/// WhatsApp gelen dosyayı `IMG-20260729-WA0012.jpg` diye kaydeder; ne adında
/// ne klasöründe **gönderen ya da grup** bilgisi vardır. O eşleşme yalnız
/// WhatsApp'ın kendi şifreli `msgstore` veritabanında durur ve root olmadan
/// okunamaz (Telegram da aynı). Bu yüzden:
/// - klasör düzeninden **kesin** okunabilen şey burada modellenir:
///   hangi uygulama, hangi tür (görüntü/video/belge/ses/sesli not/çıkartma/
///   animasyon) ve **gönderilen mi** (WhatsApp `Sent` klasörü);
/// - kişi/grup ise kullanıcının kendi verdiği **etiketlerle** çözülür
///   (`services/fm/file_tags.dart`). Tahmin edip "Ayşe'den geldi" yazmak
///   uydurma olurdu.
///
/// Saf Dart: kurallar birim testiyle sabitlensin diye (klasör adları
/// Android sürümüne göre değişiyor, testte kilitli tutulmalı).
library;

import 'fs_entry.dart';

/// Mesajlaşma medyasının türü.
enum ChatMediaKind {
  image,
  video,
  document,
  audio,
  voice,
  sticker,
  gif,
  other,
}

extension ChatMediaKindLabel on ChatMediaKind {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        ChatMediaKind.image => 'enum.chat_image',
        ChatMediaKind.video => 'enum.chat_video',
        ChatMediaKind.document => 'enum.chat_document',
        ChatMediaKind.audio => 'enum.chat_audio',
        ChatMediaKind.voice => 'enum.chat_voice',
        ChatMediaKind.sticker => 'enum.chat_sticker',
        ChatMediaKind.gif => 'enum.chat_gif',
        ChatMediaKind.other => 'enum.chat_other',
      };

  String get label => switch (this) {
        ChatMediaKind.image => 'Görüntü',
        ChatMediaKind.video => 'Video',
        ChatMediaKind.document => 'Belge',
        ChatMediaKind.audio => 'Ses',
        ChatMediaKind.voice => 'Sesli not',
        ChatMediaKind.sticker => 'Çıkartma',
        ChatMediaKind.gif => 'Animasyon (GIF)',
        ChatMediaKind.other => 'Diğer',
      };
}

/// Gelen / gönderilen ayrımı.
enum ChatDirection { any, received, sent }

extension ChatDirectionLabel on ChatDirection {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        ChatDirection.any => 'enum.chat_dir_any',
        ChatDirection.received => 'enum.chat_dir_received',
        ChatDirection.sent => 'enum.chat_dir_sent',
      };

  String get label => switch (this) {
        ChatDirection.any => 'Hepsi',
        ChatDirection.received => 'Bana gelenler',
        ChatDirection.sent => 'Gönderdiklerim',
      };
}

/// Yoldan tür çıkarır; mesajlaşma klasörü tanınmazsa null.
///
/// **Sıra önemli:** "WhatsApp Video Notes" hem "video" hem "notes" içerir,
/// "WhatsApp Animated Gifs" hem "gif" hem (bazı sürümlerde) "images" yolunun
/// altındadır. Daha özel olan önce sınanır, yoksa yanlış kovaya düşer.
ChatMediaKind? chatKindForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.contains('voice note') || lower.contains('voice_note')) {
    return ChatMediaKind.voice;
  }
  // Telegram sesli notu ayrı klasöre yazmıyor; WhatsApp'ın "Video Notes"u
  // (yuvarlak video) ses değil video sayılır.
  if (lower.contains('sticker')) return ChatMediaKind.sticker;
  if (lower.contains('animated gif') || lower.contains('animated_gif')) {
    return ChatMediaKind.gif;
  }
  if (lower.contains('video note') || lower.contains('video_note')) {
    return ChatMediaKind.video;
  }
  if (lower.contains('whatsapp video') ||
      lower.contains('telegram video') ||
      lower.contains('/video/')) {
    return ChatMediaKind.video;
  }
  if (lower.contains('whatsapp image') ||
      lower.contains('telegram image') ||
      lower.contains('profile photo')) {
    return ChatMediaKind.image;
  }
  if (lower.contains('whatsapp document') ||
      lower.contains('telegram document')) {
    return ChatMediaKind.document;
  }
  if (lower.contains('whatsapp audio') || lower.contains('telegram audio')) {
    return ChatMediaKind.audio;
  }
  return null;
}

/// Girdinin mesajlaşma türü. Klasör tanınmazsa dosyanın **kendi** türüne
/// düşülür: WhatsApp bazı sürümlerde dosyayı beklenmedik bir klasöre yazıyor,
/// o zaman "görüntü" süzgeci bir fotoğrafı yine de bulmalı.
ChatMediaKind chatKindForEntry(FsEntry entry) {
  final byPath = chatKindForPath(entry.path);
  if (byPath != null) return byPath;
  return switch (entry.category) {
    FmCategory.image => ChatMediaKind.image,
    FmCategory.video => ChatMediaKind.video,
    FmCategory.audio => ChatMediaKind.audio,
    FmCategory.document => ChatMediaKind.document,
    _ => ChatMediaKind.other,
  };
}

/// Dosya **kullanıcının gönderdiği** bir dosya mı?
///
/// WhatsApp gönderilenleri tür klasörünün altındaki `Sent` klasörüne yazar
/// (`WhatsApp Images/Sent/...`). Telegram böyle bir ayrım yapmıyor → orada
/// her şey "gelen" sayılır; süzgeç metninde bu açıkça yazılı.
bool isSentByMe(String path) {
  final lower = path.toLowerCase().replaceAll('\\', '/');
  return lower.contains('/sent/');
}

/// Bir liste için tür sayıları (süzgeç çiplerindeki rozetler).
Map<ChatMediaKind, int> chatKindCounts(Iterable<FsEntry> entries) {
  final counts = <ChatMediaKind, int>{};
  for (final e in entries) {
    final kind = chatKindForEntry(e);
    counts[kind] = (counts[kind] ?? 0) + 1;
  }
  return counts;
}
