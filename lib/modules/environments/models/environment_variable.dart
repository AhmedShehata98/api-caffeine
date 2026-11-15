import 'package:freezed_annotation/freezed_annotation.dart';

part 'environment_variable.freezed.dart';
part 'environment_variable.g.dart';

/// One row of an environment's variable table. Stored in the
/// `environments.variables` JSON column.
///
/// A secret row is synced with an empty `value` (the placeholder); the real
/// value is kept on the device only (see `EnvironmentService`).
@freezed
abstract class EnvironmentVariable with _$EnvironmentVariable {
  const factory EnvironmentVariable({
    @Default('') String key,
    @Default('') String value,
    @Default(false) bool secret,
    @Default(true) bool enabled,

    /// True for a secret row whose value is not stored on this device (for
    /// example it was set on another computer). Never synced.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool missingOnDevice,
  }) = _EnvironmentVariable;

  factory EnvironmentVariable.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentVariableFromJson(json);
}
