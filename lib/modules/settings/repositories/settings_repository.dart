import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/modules/settings/models/app_settings.dart';

abstract interface class SettingsRepository {
  /// Stored settings; anything missing or unreadable falls back to defaults.
  AppSettings load();

  Future<Result<void>> save(AppSettings settings);
}
