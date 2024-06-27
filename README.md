
# flutter_ntp

[![pub package](https://img.shields.io/pub/v/flutter_ntp.svg)](https://pub.dartlang.org/packages/flutter_ntp)

A Flutter package for obtaining accurate time using Network Time Protocol (NTP).

## Overview

`flutter_ntp` is a Dart package designed to fetch accurate time information using NTP servers. It supports querying various NTP servers and caching responses to improve performance and reliability.

## Features

- **NTP Querying**: Fetch accurate time from NTP servers.
- **Server Flexibility**: Supports querying from a wide range of NTP servers.
- **Caching**: Optionally caches NTP responses to reduce network calls and improve performance.
- **Timeout Handling**: Configurable timeout for NTP queries.
- **Easy Integration**: Simple API for fetching NTP time in your Flutter applications.

## Installation

Add `flutter_ntp` to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ntp: ^version
```

Install packages from the command line:

```bash
flutter pub get
```

## Usage

Import the package where needed:

```dart
import 'package:flutter_ntp/flutter_ntp.dart';
```

### Fetching NTP Time

```dart
 DateTime currentTime = await FlutterNTP.now();
 print('Current NTP time: $currentTime');
```

### Parameters

- `lookUpAddress`: Optional. The NTP server address to query. Default is `google`, you can access `NtpServer` and change the address.
- `port`: Optional. The port number for NTP query. Default is `123`, which uses default port for `google` server.
- `timeout`: Optional. Timeout duration for NTP query. Default is `null`.
- `cacheDuration`: Optional. Duration to cache NTP responses. Default is 1 hour.

### Example

```dart
DateTime currentTime = await NTP.now(
  lookUpAddress: NtpServer.google.url,
  port: 123,
  timeout: Duration(seconds: 5),
  cacheDuration: Duration(minutes: 30),
);
```

## Support

If you find this plugin helpful, consider supporting me:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-1.svg)](https://buymeacoffee.com/is10vmust)
