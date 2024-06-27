import 'dart:math';

class NTPMessage {
  final double timeToUtc = 2208988800.0;

  int _leapIndicator = 0;
  int _version = 3;
  int _mode = 0;
  int _stratum = 0;
  int _pollInterval = 0;
  int _precision = 0;
  int _rootDelay = 0;
  int _rootDispersion = 0;
  final List<int> _referenceIdentifier = <int>[0, 0, 0, 0];
  double _referenceTimestamp = 0.0;
  double originateTimestamp = 0.0;
  double receiveTimestamp = 0.0;
  double transmitTimestamp = 0.0;

  NTPMessage([List<int>? array]) {
    if (array != null && array.length >= 48) {
      _leapIndicator = array[0] >> 6 & 0x3;
      _version = array[0] >> 3 & 0x7;
      _mode = array[0] & 0x7;
      _stratum = unsignedByteToShort(array[1]);
      _pollInterval = array[2];
      _precision = array[3];

      _rootDelay = ((array[4] * 256) +
              unsignedByteToShort(array[5]) +
              (unsignedByteToShort(array[6]) / 256) +
              (unsignedByteToShort(array[7]) / 65536))
          .toInt();

      _rootDispersion = ((unsignedByteToShort(array[8]) * 256) +
              unsignedByteToShort(array[9]) +
              (unsignedByteToShort(array[10]) / 256) +
              (unsignedByteToShort(array[11]) / 65536))
          .toInt();

      _referenceIdentifier[0] = array[12];
      _referenceIdentifier[1] = array[13];
      _referenceIdentifier[2] = array[14];
      _referenceIdentifier[3] = array[15];

      _referenceTimestamp = decodeTimestamp(array, 16);
      originateTimestamp = decodeTimestamp(array, 24);
      receiveTimestamp = decodeTimestamp(array, 32);
      transmitTimestamp = decodeTimestamp(array, 40);
    } else {
      final DateTime time = DateTime.now().toLocal();
      _mode = 3;
      transmitTimestamp = (time.millisecondsSinceEpoch / 1000.0) + timeToUtc;
    }
  }

  int unsignedByteToShort(int i) {
    if ((i & 0x80) == 0x80) {
      return 128 + (i & 0x7f);
    } else {
      return i;
    }
  }

  double decodeTimestamp(List<int> array, int pointer) {
    double r = 0.0;
    for (int i = 0; i < 8; i++) {
      r += unsignedByteToShort(array[pointer + i]) * pow(2.0, (3 - i) * 8);
    }
    return r;
  }

  void encodeTimestamp(List<int> array, int pointer, double timestamp) {
    for (int i = 0; i < 8; i++) {
      final num base = pow(2.0, (3 - i) * 8);
      array[pointer + i] = timestamp ~/ base;
      timestamp -= unsignedByteToShort(array[pointer + i]) * base;
    }
    array[7] = Random().nextInt(255);
  }

  List<int> toByteArray() {
    final List<int> rawNtp = List.filled(48, 0);

    rawNtp[0] = _leapIndicator << 6 | _version << 3 | _mode;
    rawNtp[1] = _stratum;
    rawNtp[2] = _pollInterval;
    rawNtp[3] = _precision;

    final int l = _rootDelay * 65536;
    rawNtp[4] = l >> 24 & 0xFF;
    rawNtp[5] = l >> 16 & 0xFF;
    rawNtp[6] = l >> 8 & 0xFF;
    rawNtp[7] = l & 0xFF;

    final int ul = _rootDispersion * 65536;
    rawNtp[8] = ul >> 24 & 0xFF;
    rawNtp[9] = ul >> 16 & 0xFF;
    rawNtp[10] = ul >> 8 & 0xFF;
    rawNtp[11] = ul & 0xFF;

    rawNtp[12] = _referenceIdentifier[0];
    rawNtp[13] = _referenceIdentifier[1];
    rawNtp[14] = _referenceIdentifier[2];
    rawNtp[15] = _referenceIdentifier[3];

    encodeTimestamp(rawNtp, 16, _referenceTimestamp);
    encodeTimestamp(rawNtp, 24, originateTimestamp);
    encodeTimestamp(rawNtp, 32, receiveTimestamp);
    encodeTimestamp(rawNtp, 40, transmitTimestamp);

    return rawNtp;
  }

  @override
  String toString() {
    return 'Leap indicator: $_leapIndicator\n'
        'Version: $_version \n'
        'Mode: $_mode\n'
        'Stratum: $_stratum\n'
        'Poll: $_pollInterval\n'
        'Precision: $_precision\n'
        'Root delay: ${_rootDelay * 1000.0} ms\n'
        'Root dispersion: ${_rootDispersion * 1000.0}ms\n'
        'Reference identifier: ${referenceIdentifierToString(_referenceIdentifier, _stratum, _version)}\n'
        'Reference timestamp: ${timestampToString(_referenceTimestamp)}\n'
        'Originate timestamp: ${timestampToString(originateTimestamp)}\n'
        'Receive timestamp:   ${timestampToString(receiveTimestamp)}\n'
        'Transmit timestamp:  ${timestampToString(transmitTimestamp)}';
  }

  String timestampToString(double timestamp) {
    if (timestamp == 0) {
      return '0';
    }

    final double utc = timestamp - timeToUtc;
    final double ms = utc * 1000.0;

    return DateTime.fromMillisecondsSinceEpoch(ms.toInt()).toString();
  }

  String referenceIdentifierToString(List<int> ref, int stratum, int version) {
    if (stratum == 0 || stratum == 1) {
      return ref.toString();
    } else if (version == 3) {
      return '${unsignedByteToShort(ref[0])}.${unsignedByteToShort(ref[1])}.'
          '${unsignedByteToShort(ref[2])}.${unsignedByteToShort(ref[3])}';
    } else if (version == 4) {
      return '${unsignedByteToShort(ref[0]) / 256.0 + unsignedByteToShort(ref[1]) / 65536.0 + unsignedByteToShort(ref[2]) / 16777216.0 + unsignedByteToShort(ref[3]) / 4294967296.0}';
    }
    return '';
  }
}
