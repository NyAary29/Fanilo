import 'dart:io';

import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/models.dart';

/// Enregistrement de la question vocale. Le fichier temporaire est effacé
/// dès que ses octets sont lus : l'audio ne reste jamais sur le téléphone.
abstract interface class VoiceRecorder {
  /// Demande l'autorisation du micro (dialogue système) ; `false` si refusée.
  Future<bool> requestPermission();
  Future<void> start();

  /// Arrête et renvoie l'audio (null si rien n'a été enregistré).
  Future<VoiceClip?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class RecordVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();
  String? _path;

  // AAC dans un conteneur MP4 (.m4a, `audio/mp4`) sur Android ; WAV ailleurs
  // (Linux : parecord, sans ffmpeg). Deux types acceptés par l'API.
  bool get _aac => Platform.isAndroid || Platform.isIOS;

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/fanilo_question.${_aac ? 'm4a' : 'wav'}';
    await _recorder.start(
      RecordConfig(
        encoder: _aac ? AudioEncoder.aacLc : AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: _path!,
    );
  }

  @override
  Future<VoiceClip?> stop() async {
    final path = await _recorder.stop() ?? _path;
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return VoiceClip(
        bytes: bytes,
        filename: _aac ? 'question.m4a' : 'question.wav',
        mimeType: _aac ? 'audio/mp4' : 'audio/wav',
      );
    } finally {
      await _delete(path);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    if (_path != null) await _delete(_path!);
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Lecture d'un `audio_url` publié.
abstract interface class AudioPlayback {
  Future<void> play(Uri url);
  Future<void> stop();
}

class JustAudioPlayback implements AudioPlayback {
  ja.AudioPlayer? _player;

  @override
  Future<void> play(Uri url) async {
    final p = _player ??= ja.AudioPlayer();
    await p.setUrl(url.toString());
    await p.play();
  }

  @override
  Future<void> stop() async => _player?.stop();
}
