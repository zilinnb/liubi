import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class LivePhotoUtil {
  static final Map<String, bool> _motionCache = {};

  static Future<bool> isMotionPhoto(String filePath) async {
    if (_motionCache.containsKey(filePath)) return _motionCache[filePath]!;

    final lower = filePath.toLowerCase();
    if (!lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg') &&
        !lower.endsWith('.heic')) {
      _motionCache[filePath] = false;
      return false;
    }
    try {
      final file = File(filePath);
      final length = await file.length();
      if (length < 2048) {
        _motionCache[filePath] = false;
        return false;
      }

      final raf = await file.open();
      try {
        final readLen = length > 65536 ? 65536 : length;
        final headerBytes = await raf.read(readLen);
        final header = String.fromCharCodes(headerBytes);

        if (_checkXmpMotionPhoto(header)) {
          _motionCache[filePath] = true;
          return true;
        }

        if (length > readLen) {
          final tailLen = length > 131072 ? 131072 : length;
          await raf.setPosition(length - tailLen);
          final tailBytes = await raf.read(tailLen);
          if (_hasEmbeddedMp4(tailBytes)) {
            _motionCache[filePath] = true;
            return true;
          }
        }

        _motionCache[filePath] = false;
        return false;
      } finally {
        await raf.close();
      }
    } catch (_) {
      _motionCache[filePath] = false;
      return false;
    }
  }

  static Future<bool> isMotionPhotoByAsset(AssetEntity asset) async {
    if (_motionCache.containsKey(asset.id)) return _motionCache[asset.id]!;

    final title = asset.title ?? '';
    if (title.toUpperCase().startsWith('MVIMG')) {
      _motionCache[asset.id] = true;
      return true;
    }

    try {
      String? filePath;
      final relativePath = asset.relativePath ?? '';
      if (relativePath.isNotEmpty && title.isNotEmpty) {
        for (final prefix
            in ['/storage/emulated/0/', '/sdcard/', '/mnt/sdcard/']) {
          final p = '$prefix$relativePath$title';
          if (await File(p).exists()) {
            filePath = p;
            break;
          }
        }
      }

      if (filePath == null) {
        final file = await asset.originFile;
        if (file == null) {
          _motionCache[asset.id] = false;
          return false;
        }
        filePath = file.path;
      }

      final result = await isMotionPhoto(filePath);
      _motionCache[asset.id] = result;
      return result;
    } catch (_) {
      _motionCache[asset.id] = false;
      return false;
    }
  }

  static bool isCachedMotionPhoto(String assetId) {
    return _motionCache[assetId] == true;
  }

  static void clearCache() {
    _motionCache.clear();
  }

  static bool _checkXmpMotionPhoto(String header) {
    if (header.contains('MotionPhoto')) return true;
    if (header.contains('MicroVideo')) return true;
    if (header.contains('GCamera:MotionPhoto')) return true;
    if (header.contains('Camera:MotionPhoto')) return true;
    if (header.contains('XmpGCamera:MotionPhoto')) return true;
    if (header.contains('EmbeddedVideoType')) return true;
    if (header.contains('MotionPhotoVersion')) return true;

    final xmpStart = header.indexOf('<x:xmpmeta');
    if (xmpStart != -1) {
      final xmpEnd = header.indexOf('</x:xmpmeta>', xmpStart);
      if (xmpEnd != -1) {
        final xmp = header.substring(xmpStart, xmpEnd + 12);
        if (xmp.contains('MotionPhoto')) return true;
        if (xmp.contains('MicroVideo')) return true;
        if (xmp.contains('Container:Item') && xmp.contains('video/')) {
          return true;
        }
        if (xmp.contains('Container:Directory')) return true;
        if (xmp.contains('EmbeddedVideoType')) return true;
        if (xmp.contains('XmpGCamera')) return true;
      }
    }

    return false;
  }

  static bool _hasEmbeddedMp4(List<int> bytes) {
    for (int i = 0; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x00 &&
          bytes[i + 1] == 0x00 &&
          bytes[i + 2] == 0x00 &&
          bytes[i + 4] == 0x66 &&
          bytes[i + 5] == 0x74 &&
          bytes[i + 6] == 0x79 &&
          bytes[i + 7] == 0x70) {
        final boxSize = (bytes[i] << 24) |
            (bytes[i + 1] << 16) |
            (bytes[i + 2] << 8) |
            bytes[i + 3];
        if (boxSize > 8 && boxSize < 0x7FFFFFFF) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<String?> extractVideo(String filePath) async {
    try {
      final file = File(filePath);
      final length = await file.length();
      final raf = await file.open();
      try {
        final headerLen = length > 524288 ? 524288 : length;
        final headerBytes = await raf.read(headerLen);
        final header = String.fromCharCodes(headerBytes);

        int? videoOffset;
        int? videoLength;

        final xmpStart = header.indexOf('<x:xmpmeta');
        if (xmpStart != -1) {
          final xmpEnd = header.indexOf('</x:xmpmeta>', xmpStart);
          if (xmpEnd != -1) {
            final xmp = header.substring(xmpStart, xmpEnd + 12);

            final containerItemRegex =
                RegExp(r'<Container:Item[^>]*Mime="video/[^"]*"[^>]*/?\s*>');
            final containerMatch = containerItemRegex.firstMatch(xmp);
            if (containerMatch != null) {
              final itemStr = containerMatch.group(0)!;
              final lengthMatch =
                  RegExp(r'Length="(\d+)"').firstMatch(itemStr);
              final paddingMatch =
                  RegExp(r'Padding="(\d+)"').firstMatch(itemStr);
              if (lengthMatch != null) {
                videoLength = int.parse(lengthMatch.group(1)!);
                if (paddingMatch != null) {
                  final dirItemRegex =
                      RegExp(r'<Container:Item[^>]*Mime="image/[^"]*"[^>]*/?\s*>');
                  final dirMatch = dirItemRegex.firstMatch(xmp);
                  if (dirMatch != null) {
                    final dirLengthMatch = RegExp(r'Length="(\d+)"')
                        .firstMatch(dirMatch.group(0)!);
                    final dirPaddingMatch = RegExp(r'Padding="(\d+)"')
                        .firstMatch(dirMatch.group(0)!);
                    if (dirLengthMatch != null) {
                      int dirLen = int.parse(dirLengthMatch.group(1)!);
                      int dirPad = dirPaddingMatch != null
                          ? int.parse(dirPaddingMatch.group(1)!)
                          : 0;
                      videoOffset = dirLen + dirPad;
                    }
                  }
                }
              }
            }

            if (videoLength == null) {
              final microVideoOffset =
                  RegExp(r'MicroVideoOffset="(\d+)"').firstMatch(xmp);
              final microVideoLength =
                  RegExp(r'MicroVideoLength="(\d+)"').firstMatch(xmp);
              if (microVideoOffset != null && microVideoLength != null) {
                videoOffset = int.parse(microVideoOffset.group(1)!);
                videoLength = int.parse(microVideoLength.group(1)!);
              }
            }

            if (videoLength == null) {
              final embeddedOffset =
                  RegExp(r'EmbeddedVideoOffset="(\d+)"').firstMatch(xmp);
              final embeddedLength =
                  RegExp(r'EmbeddedVideoLength="(\d+)"').firstMatch(xmp);
              if (embeddedOffset != null && embeddedLength != null) {
                videoOffset = int.parse(embeddedOffset.group(1)!);
                videoLength = int.parse(embeddedLength.group(1)!);
              }
            }

            if (videoLength == null) {
              final motionPhotoOffset =
                  RegExp(r'MotionPhotoOffset="(\d+)"').firstMatch(xmp);
              final motionPhotoLength =
                  RegExp(r'MotionPhotoLength="(\d+)"').firstMatch(xmp);
              if (motionPhotoOffset != null && motionPhotoLength != null) {
                videoOffset = int.parse(motionPhotoOffset.group(1)!);
                videoLength = int.parse(motionPhotoLength.group(1)!);
              }
            }
          }
        }

        if (videoLength != null && videoLength > 0) {
          final allBytes = await _readFullFile(file, length);
          if (allBytes == null) return null;

          if (videoOffset != null &&
              videoOffset > 0 &&
              videoOffset + videoLength <= allBytes.length) {
            return await _saveVideoBytes(
                allBytes.sublist(videoOffset, videoOffset + videoLength));
          } else {
            final totalLen = allBytes.length;
            if (videoLength < totalLen) {
              return await _saveVideoBytes(
                  allBytes.sublist(totalLen - videoLength, totalLen));
            }
          }
        }

        final allBytes = await _readFullFile(file, length);
        if (allBytes == null) return null;

        final ftypIdx = _findMp4Start(allBytes);
        if (ftypIdx != null && ftypIdx > 0) {
          final videoBytes = allBytes.sublist(ftypIdx);
          if (videoBytes.length > 2048) {
            return await _saveVideoBytes(videoBytes);
          }
        }

        return null;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _readFullFile(File file, int length) async {
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static int? _findMp4Start(Uint8List bytes) {
    for (int i = bytes.length - 8; i >= 0; i--) {
      if (i + 8 <= bytes.length &&
          bytes[i] == 0x00 &&
          bytes[i + 1] == 0x00 &&
          bytes[i + 2] == 0x00 &&
          bytes[i + 3] >= 0x08 &&
          bytes[i + 4] == 0x66 &&
          bytes[i + 5] == 0x74 &&
          bytes[i + 6] == 0x79 &&
          bytes[i + 7] == 0x70) {
        final boxSize = (bytes[i] << 24) |
            (bytes[i + 1] << 16) |
            (bytes[i + 2] << 8) |
            bytes[i + 3];
        if (boxSize > 8 && boxSize < bytes.length - i) {
          return i;
        }
      }
    }
    return null;
  }

  static Future<String> _saveVideoBytes(List<int> videoBytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/live_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(path).writeAsBytes(videoBytes);
    return path;
  }
}
