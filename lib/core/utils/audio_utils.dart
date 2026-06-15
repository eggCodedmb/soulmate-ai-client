import 'dart:typed_data';
import 'dart:math' as math;

class AudioUtils {
  /// 将 [samples] (范围通常为 -1.0 到 1.0) 转换为 16-bit PCM WAV 文件的字节数组
  /// [sampleRate] 默认为 16000，这是 VAD 包输出的标准采样率
  static Uint8List createWavHeader(int dataLength, int sampleRate) {
    final int totalLength = dataLength + 36;
    final int byteRate = sampleRate * 2; // 16-bit = 2 bytes per sample, mono

    final ByteData header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, totalLength, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    header.setUint16(22, 1, Endian.little); // NumChannels (1 for mono)
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little); // BlockAlign (NumChannels * BitsPerSample/8)
    header.setUint16(34, 16, Endian.little); // BitsPerSample

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataLength, Endian.little);

    return header.buffer.asUint8List();
  }

  static Uint8List samplesToWav(List<double> samples, int sampleRate) {
    final int dataLength = samples.length * 2;
    final Uint8List header = createWavHeader(dataLength, sampleRate);
    final Int16List pcmData = Int16List(samples.length);

    for (int i = 0; i < samples.length; i++) {
      // 限制范围并转换为 16-bit 整数
      final double sample = samples[i].clamp(-1.0, 1.0);
      pcmData[i] = (sample * 32767).toInt();
    }

    final Uint8List result = Uint8List(44 + dataLength);
    result.setAll(0, header);
    result.setAll(44, pcmData.buffer.asUint8List());

    return result;
  }
  
  /// 计算一组 PCM 样本的平均振幅 (dBFS)
  static double calculateDb(List<double> samples) {
    if (samples.isEmpty) return -160.0;
    
    double sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    
    final double rms = math.sqrt(sumSquares / samples.length);
    if (rms == 0) return -160.0;
    
    final double db = 20 * math.log(rms) / math.ln10;
    return db.clamp(-160.0, 0.0);
  }
}
