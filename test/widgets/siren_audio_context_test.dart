import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/widgets/siren_dialog.dart';

void main() {
  test('siren audio context is valid on every platform', () {
    expect(buildSirenAudioContext, returnsNormally);
  });

  test('regression control: playback plus defaultToSpeaker is rejected', () {
    expect(
      () => AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.defaultToSpeaker},
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
