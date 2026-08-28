import 'dart:typed_data';

/// A decoded `audio_output` chunk: format read from the WAV header, plus the
/// raw PCM payload with that header stripped off.
class WavAudio {
  const WavAudio({
    required this.sampleRate,
    required this.channels,
    required this.pcm,
  });

  final int sampleRate;
  final int channels;
  final Uint8List pcm;
}

/// Parses a WAV/RIFF file's `fmt ` and `data` chunks.
///
/// Hume's `audio_output.data` is a base64-encoded **complete WAV file** per
/// chunk (see `app/api/voice.py`'s doc reference and the EVI audio guide) —
/// not headerless PCM. Feeding those bytes straight into a raw-PCM stream
/// player would insert ~44 bytes of header noise as an audible click before
/// every chunk, so this strips the header and reports the format it
/// described rather than assuming a fixed sample rate.
///
/// Returns null for anything that isn't a well-formed PCM WAV — the caller
/// drops the chunk rather than risk feeding garbage to the player.
WavAudio? parseWav(Uint8List bytes) {
  if (bytes.length < 12) return null;
  final data = ByteData.sublistView(bytes);

  if (_ascii(bytes, 0) != 'RIFF' || _ascii(bytes, 8) != 'WAVE') return null;

  int? sampleRate;
  int? channels;
  var offset = 12;

  while (offset + 8 <= bytes.length) {
    final chunkId = _ascii(bytes, offset);
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkStart = offset + 8;
    if (chunkStart + chunkSize > bytes.length) return null;

    if (chunkId == 'fmt ' && chunkSize >= 16) {
      channels = data.getUint16(chunkStart + 2, Endian.little);
      sampleRate = data.getUint32(chunkStart + 4, Endian.little);
    } else if (chunkId == 'data') {
      if (sampleRate == null || channels == null) return null;
      return WavAudio(
        sampleRate: sampleRate,
        channels: channels,
        pcm: bytes.sublist(chunkStart, chunkStart + chunkSize),
      );
    }

    // RIFF chunks are word-aligned — an odd-sized chunk has one pad byte
    // after it that isn't part of chunkSize.
    offset = chunkStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  return null;
}

String _ascii(Uint8List bytes, int start) =>
    String.fromCharCodes(bytes.sublist(start, start + 4));
