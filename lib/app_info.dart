import 'package:package_info_plus/package_info_plus.dart';

/// Date of the commit the app was built from (YYYY-MM-DD), passed in by CI
/// with --dart-define. Empty in local builds.
const releaseDate = String.fromEnvironment('RELEASE_DATE');

/// The pubspec version the build stamped into the app, e.g. "0.5.0".
Future<String> appVersion() async => (await PackageInfo.fromPlatform()).version;
