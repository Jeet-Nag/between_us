import 'dart:async';
import 'package:just_audio/just_audio.dart';

class NativeAudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration? get duration => _player.duration;
  bool get isPlaying => _player.playing;

  Future<void> loadAudio(String url) async {
    try {
      if (url.startsWith('http')) {
        await _player.setUrl(url);
      } else if (url.startsWith('asset://')) {
        await _player.setAsset(url.replaceFirst('asset://', ''));
      } else {
        await _player.setFilePath(url);
      }
    } catch (e) {
      // Ignored in simulator
    }
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  void dispose() {
    _player.dispose();
  }
}
