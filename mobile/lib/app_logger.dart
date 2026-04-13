import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 全局日志（Release 下 level 为 off，不输出）。
final Logger appLogger = Logger(
  level: kReleaseMode ? Level.off : Level.debug,
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    lineLength: 110,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
