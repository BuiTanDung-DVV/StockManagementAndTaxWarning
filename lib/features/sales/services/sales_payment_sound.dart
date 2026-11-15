import 'package:audioplayers/audioplayers.dart';

enum SalesPaymentSound {
  cashReceived('cash_received.wav'),
  debtRecorded('debt_recorded.wav'),
  transferReceived('transfer_received.wav');

  const SalesPaymentSound(this._fileName);

  final String _fileName;
  static AudioPlayer? _player;

  Future<void> play() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource('audio/$_fileName'));
    } catch (_) {
      // Audio is optional feedback after the transaction succeeds.
    }
  }
}
