import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

enum RecordingInterruptionReason {
  phoneCall,
  permissionRevoked,
  lifecycleInterrupted,
  unknown,
}

class VoiceRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  StreamSubscription? _recordStateSubscription;

  bool get isRecording => _recordingStartTime != null;

  VoiceRecorderService() {
    _initInterruptionListener();
  }

  void _initInterruptionListener() {
    _recordStateSubscription = _audioRecorder.onStateChanged().listen((state) {
      if (state == RecordState.stop && _recordingStartTime != null) {
        debugPrint('[VoiceRecorder] Audio record state stopped externally (e.g. phone call or audio focus loss).');
        _cleanupIncompleteRecording();
      }
    });
  }

  /// Starts native audio recording to local AAC/M4A file
  Future<bool> startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[VoiceRecorder] Microphone permission denied.');
        return false;
      }

      final tempDir = Directory.systemTemp;
      final path = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _currentRecordingPath = path;
      _recordingStartTime = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('[VoiceRecorder] Error starting audio recording: $e');
      _cleanupIncompleteRecording();
      return false;
    }
  }

  /// Stops recording and returns the recorded file path and duration
  Future<Map<String, dynamic>?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null && _recordingStartTime != null) {
        final duration = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
        _recordingStartTime = null;

        final file = File(path);
        if (await file.exists() && await file.length() > 1024) {
          return {
            'filePath': path,
            'durationMs': duration,
            'file': file,
          };
        } else {
          debugPrint('[VoiceRecorder] Audio file too short or empty.');
          await _cleanupIncompleteRecording();
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[VoiceRecorder] Error stopping recording: $e');
      await _cleanupIncompleteRecording();
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.cancel();
    } catch (e) {
      // Ignored
    } finally {
      await _cleanupIncompleteRecording();
    }
  }

  Future<void> _cleanupIncompleteRecording() async {
    _recordingStartTime = null;
    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignored
      }
      _currentRecordingPath = null;
    }
  }

  void dispose() {
    _recordStateSubscription?.cancel();
    _cleanupIncompleteRecording();
    _audioRecorder.dispose();
  }
}
