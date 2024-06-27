part of '../flutter_ntp.dart';

enum NtpServer {
  google('time.google.com'),
  cloudflare('time.cloudflare.com'),
  facebook('time.facebook.com'),
  microsoft('time.windows.com'),
  apple('time.apple.com'),
  nist('time.nist.gov'),
  pool('pool.ntp.org'),
  usno('tick.usno.navy.mil'),
  isc('ntp.isc.org'),
  timeNl('ntp.time.nl'),
  chrony('chrony.eu'),
  hetzner('ntp1.hetzner.de'),
  hetzner2('ntp2.hetzner.de'),
  ntpSe('gbg1.ntp.se'),
  qiX('ntp.qix.ca'),
  mskIx('ntp.ix.ru'),
  ripe('ntp.ripe.net'),
  timeDns('clock.isc.org'),
  internetSystems('ntp1.usno.navy.mil'),
  natMorris('ntp.nat.ms'),
  ntpPool('pool.ntp.org'),
  milUsno('tick.usno.navy.mil'),
  eduUtcnist('utcnist.colorado.edu'),
  comNtpstm('ntpstm.netbone-digital.com'),
  netGps('gps.layer42.net'),
  orgPtb('ptbtime1.ptb.de'),
  plNtp('ntp.fizyka.umk.pl'),
  dePtb('time.fu-berlin.de'),
  nlChime1('chime1.surfnet.nl'),
  atAsynchronos('asynchronos.iiss.at'),
  czNtp('ntp.nic.cz'),
  roNtp('ntp1.usv.ro'),
  seTimehost('timehost.lysator.liu.se'),
  caTime('time.nrc.ca'),
  mxCronos('cronos.cenam.mx'),
  esHora('hora.roa.es'),
  itInrim('ntp1.inrim.it'),
  beOma('ntp1.oma.be'),
  huAtomki('ntp.atomki.mta.hu'),
  eusI2t('ntp.i2t.ehu.eus'),
  chNeel('ntp.neel.ch'),
  cnNeu('ntp.neu.edu.cn'),
  jpNict('ntp.nict.jp'),
  brUfrj('ntps1.pads.ufrj.br'),
  clShoa('ntp.shoa.cl'),
  intEsa('time.esa.int');

  final String url;
  const NtpServer(this.url);
}

const _defaultLookup = NtpServer.google;

class FlutterNTP {
  static final Map<String, int> _cache = {};

  /// Return NTP delay in microseconds
  static Future<int> _getNtpOffset({
    String? lookUpAddress,
    int? port,
    DateTime? localTime,
    Duration? timeout,
    Duration cacheDuration = const Duration(hours: 1),
  }) async {
    try {
      lookUpAddress ??= _defaultLookup.url;
      port ??= 123;

      final cacheKey = '$lookUpAddress:$port';

      if (_cache.containsKey(cacheKey)) {
        final cachedOffset = _cache[cacheKey]!;
        final cachedTime = DateTime.fromMicrosecondsSinceEpoch(cachedOffset);
        final now = DateTime.now();
        if (now.difference(cachedTime) < cacheDuration) {
          return cachedOffset;
        }
      }
      final addresses = await InternetAddress.lookup(lookUpAddress);

      if (addresses.isEmpty) {
        throw 'Could not resolve address for $lookUpAddress.';
      }

      final serverAddress = addresses.first;
      final clientAddress = serverAddress.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : InternetAddress.anyIPv4;

      final datagramSocket = await RawDatagramSocket.bind(clientAddress, 0);

      final ntpMessage = _NTPMessage();
      final buffer = ntpMessage.toByteArray();
      final time = localTime ?? DateTime.now();
      ntpMessage.encodeTimestamp(
        buffer,
        40,
        (time.microsecondsSinceEpoch / 1000000.0) + ntpMessage.timeToUtc,
      );

      datagramSocket.send(buffer, serverAddress, port);

      Datagram? packet;

      receivePacket(RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          packet = datagramSocket.receive();
        }
        return packet != null;
      }

      try {
        if (timeout != null) {
          await datagramSocket.timeout(timeout).firstWhere(receivePacket);
        } else {
          await datagramSocket.firstWhere(receivePacket);
        }
      } catch (e) {
        rethrow;
      } finally {
        datagramSocket.close();
      }

      if (packet == null) {
        throw 'Received empty response.';
      }

      final offset = _parseData(packet!.data, DateTime.now());

      // Check if the offset is within a reasonable range
      // 12 years in micoseconds
      const maxOffset = 12 * 365 * 24 * 60 * 60 * 1000000;

      if (offset.abs() > maxOffset) {
        // Handle the case where the offset is too large, potentially reset local time or handle gracefully
        dev.log('NTP offset exceeds maximum allowable range: $offset');
        throw Exception('NTP offset exceeds maximum allowable range');
      }
      _cache[cacheKey] = offset;

      return offset;
    } catch (e, stackTrace) {
      dev.log('Error in getNtpOffset: $e \n $stackTrace');
      rethrow;
    }
  }

  /// Get current NTP time
  static Future<DateTime> now({
    String? lookUpAddress,
    int? port,
    Duration? timeout,
    Duration cacheDuration = const Duration(hours: 1),
  }) async {
    try {
      final localTime = DateTime.now();

      final offset = await _getNtpOffset(
        lookUpAddress: lookUpAddress,
        port: port,
        localTime: localTime,
        timeout: timeout,
        cacheDuration: cacheDuration,
      );

      return localTime.add(Duration(microseconds: offset));
    } catch (e, stackTrace) {
      dev.log('Error in NTP now: $e \n $stackTrace');
      rethrow;
    }
  }

  /// Parse data from datagram socket.
  static int _parseData(List<int> data, DateTime time) {
    final ntpMessage = _NTPMessage(data);

    // Calculate destination timestamp in seconds since NTP epoch
    final destinationTimestamp =
        (time.microsecondsSinceEpoch / 1000000.0) + ntpMessage.timeToUtc;

    // Calculate local clock offset in seconds
    final localClockOffset =
        ((ntpMessage._receiveTimestamp - ntpMessage._originateTimestamp) +
                (ntpMessage._transmitTimestamp - destinationTimestamp)) /
            2;

    // Convert offset to microseconds and return as an integer
    return (localClockOffset * 1000000).toInt();
  }
}

class _NTPMessage {
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
  double _originateTimestamp = 0.0;
  double _receiveTimestamp = 0.0;
  double _transmitTimestamp = 0.0;

  _NTPMessage([List<int>? array]) {
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
      _originateTimestamp = decodeTimestamp(array, 24);
      _receiveTimestamp = decodeTimestamp(array, 32);
      _transmitTimestamp = decodeTimestamp(array, 40);
    } else {
      final DateTime time = DateTime.now().toLocal();
      _mode = 3;
      _transmitTimestamp = (time.millisecondsSinceEpoch / 1000.0) + timeToUtc;
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
    encodeTimestamp(rawNtp, 24, _originateTimestamp);
    encodeTimestamp(rawNtp, 32, _receiveTimestamp);
    encodeTimestamp(rawNtp, 40, _transmitTimestamp);

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
        'Originate timestamp: ${timestampToString(_originateTimestamp)}\n'
        'Receive timestamp:   ${timestampToString(_receiveTimestamp)}\n'
        'Transmit timestamp:  ${timestampToString(_transmitTimestamp)}';
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
