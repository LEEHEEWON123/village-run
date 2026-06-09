// flutter/lib/core/constants.dart

class AppConstants {
  static const double pathBufferMeters = 5.0;
  static const double loopDetectionMeters = 20.0;
  static const double minMoveMeters = 3.0;
  static const int gpsIntervalMs = 1000;
  static const String shareBaseUrl = 'https://village-run-f512d.web.app/share';

  static String shareUserUrl(String userId) => '$shareBaseUrl/$userId';

  static String shareRunUrl(String userId, String runId) =>
      '$shareBaseUrl/$userId/$runId';
}
