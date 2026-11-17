// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp_server.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$McpServerSettings {

 McpProtocolEra get protocolEra; int? get timeoutSeconds;
/// Create a copy of McpServerSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServerSettingsCopyWith<McpServerSettings> get copyWith => _$McpServerSettingsCopyWithImpl<McpServerSettings>(this as McpServerSettings, _$identity);

  /// Serializes this McpServerSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpServerSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerSettings&&(identical(other.protocolEra, _this.protocolEra) || other.protocolEra == _this.protocolEra)&&(identical(other.timeoutSeconds, _this.timeoutSeconds) || other.timeoutSeconds == _this.timeoutSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpServerSettings;
  return Object.hash(runtimeType,_this.protocolEra,_this.timeoutSeconds);
}

@override
String toString() {
  final _this = this as McpServerSettings;
  return 'McpServerSettings(protocolEra: ${_this.protocolEra}, timeoutSeconds: ${_this.timeoutSeconds})';
}


}

/// @nodoc
abstract mixin class $McpServerSettingsCopyWith<$Res>  {
  factory $McpServerSettingsCopyWith(McpServerSettings value, $Res Function(McpServerSettings) _then) = _$McpServerSettingsCopyWithImpl;
@useResult
$Res call({
 McpProtocolEra protocolEra, int? timeoutSeconds
});




}
/// @nodoc
class _$McpServerSettingsCopyWithImpl<$Res>
    implements $McpServerSettingsCopyWith<$Res> {
  _$McpServerSettingsCopyWithImpl(this._self, this._then);

  final McpServerSettings _self;
  final $Res Function(McpServerSettings) _then;

/// Create a copy of McpServerSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? protocolEra = null,Object? timeoutSeconds = freezed,}) {
  return _then(McpServerSettings(
protocolEra: null == protocolEra ? _self.protocolEra : protocolEra // ignore: cast_nullable_to_non_nullable
as McpProtocolEra,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [McpServerSettings].
extension McpServerSettingsPatterns on McpServerSettings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServerSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServerSettings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServerSettings value)  $default,){
final _that = this;
switch (_that) {
case _McpServerSettings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServerSettings value)?  $default,){
final _that = this;
switch (_that) {
case _McpServerSettings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( McpProtocolEra protocolEra,  int? timeoutSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServerSettings() when $default != null:
return $default(_that.protocolEra,_that.timeoutSeconds);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( McpProtocolEra protocolEra,  int? timeoutSeconds)  $default,) {final _that = this;
switch (_that) {
case _McpServerSettings():
return $default(_that.protocolEra,_that.timeoutSeconds);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( McpProtocolEra protocolEra,  int? timeoutSeconds)?  $default,) {final _that = this;
switch (_that) {
case _McpServerSettings() when $default != null:
return $default(_that.protocolEra,_that.timeoutSeconds);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _McpServerSettings implements McpServerSettings {
  const _McpServerSettings({this.protocolEra = McpProtocolEra.legacy, this.timeoutSeconds});
  factory _McpServerSettings.fromJson(Map<String, dynamic> json) => _$McpServerSettingsFromJson(json);

@override@JsonKey() final  McpProtocolEra protocolEra;
@override final  int? timeoutSeconds;

/// Create a copy of McpServerSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServerSettingsCopyWith<_McpServerSettings> get copyWith => __$McpServerSettingsCopyWithImpl<_McpServerSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServerSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServerSettings&&(identical(other.protocolEra, protocolEra) || other.protocolEra == protocolEra)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,protocolEra,timeoutSeconds);
}

@override
String toString() {
    return 'McpServerSettings(protocolEra: $protocolEra, timeoutSeconds: $timeoutSeconds)';
}


}

/// @nodoc
abstract mixin class _$McpServerSettingsCopyWith<$Res> implements $McpServerSettingsCopyWith<$Res> {
  factory _$McpServerSettingsCopyWith(_McpServerSettings value, $Res Function(_McpServerSettings) _then) = __$McpServerSettingsCopyWithImpl;
@override @useResult
$Res call({
 McpProtocolEra protocolEra, int? timeoutSeconds
});




}
/// @nodoc
class __$McpServerSettingsCopyWithImpl<$Res>
    implements _$McpServerSettingsCopyWith<$Res> {
  __$McpServerSettingsCopyWithImpl(this._self, this._then);

  final _McpServerSettings _self;
  final $Res Function(_McpServerSettings) _then;

/// Create a copy of McpServerSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? protocolEra = null,Object? timeoutSeconds = freezed,}) {
  return _then(_McpServerSettings(
protocolEra: null == protocolEra ? _self.protocolEra : protocolEra // ignore: cast_nullable_to_non_nullable
as McpProtocolEra,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$McpServerDraft {

 String get name; McpTransport get transport; String? get command; String? get url; List<String> get args; String? get cwd; Map<String, String> get env; Map<String, String> get headers; List<String> get secretKeys; McpServerSettings get settings;
/// Create a copy of McpServerDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServerDraftCopyWith<McpServerDraft> get copyWith => _$McpServerDraftCopyWithImpl<McpServerDraft>(this as McpServerDraft, _$identity);

  /// Serializes this McpServerDraft to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpServerDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerDraft&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.transport, _this.transport) || other.transport == _this.transport)&&(identical(other.command, _this.command) || other.command == _this.command)&&(identical(other.url, _this.url) || other.url == _this.url)&&const DeepCollectionEquality().equals(other.args, _this.args)&&(identical(other.cwd, _this.cwd) || other.cwd == _this.cwd)&&const DeepCollectionEquality().equals(other.env, _this.env)&&const DeepCollectionEquality().equals(other.headers, _this.headers)&&const DeepCollectionEquality().equals(other.secretKeys, _this.secretKeys)&&(identical(other.settings, _this.settings) || other.settings == _this.settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpServerDraft;
  return Object.hash(runtimeType,_this.name,_this.transport,_this.command,_this.url,const DeepCollectionEquality().hash(_this.args),_this.cwd,const DeepCollectionEquality().hash(_this.env),const DeepCollectionEquality().hash(_this.headers),const DeepCollectionEquality().hash(_this.secretKeys),_this.settings);
}

@override
String toString() {
  final _this = this as McpServerDraft;
  return 'McpServerDraft(name: ${_this.name}, transport: ${_this.transport}, command: ${_this.command}, url: ${_this.url}, args: ${_this.args}, cwd: ${_this.cwd}, env: ${_this.env}, headers: ${_this.headers}, secretKeys: ${_this.secretKeys}, settings: ${_this.settings})';
}


}

/// @nodoc
abstract mixin class $McpServerDraftCopyWith<$Res>  {
  factory $McpServerDraftCopyWith(McpServerDraft value, $Res Function(McpServerDraft) _then) = _$McpServerDraftCopyWithImpl;
@useResult
$Res call({
 String name, McpTransport transport, String? command, String? url, List<String> args, String? cwd, Map<String, String> env, Map<String, String> headers, List<String> secretKeys, McpServerSettings settings
});


$McpServerSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class _$McpServerDraftCopyWithImpl<$Res>
    implements $McpServerDraftCopyWith<$Res> {
  _$McpServerDraftCopyWithImpl(this._self, this._then);

  final McpServerDraft _self;
  final $Res Function(McpServerDraft) _then;

/// Create a copy of McpServerDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? transport = null,Object? command = freezed,Object? url = freezed,Object? args = null,Object? cwd = freezed,Object? env = null,Object? headers = null,Object? secretKeys = null,Object? settings = null,}) {
  return _then(McpServerDraft(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,transport: null == transport ? _self.transport : transport // ignore: cast_nullable_to_non_nullable
as McpTransport,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as List<String>,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,env: null == env ? _self.env : env // ignore: cast_nullable_to_non_nullable
as Map<String, String>,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,secretKeys: null == secretKeys ? _self.secretKeys : secretKeys // ignore: cast_nullable_to_non_nullable
as List<String>,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as McpServerSettings,
  ));
}
/// Create a copy of McpServerDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpServerSettingsCopyWith<$Res> get settings {
  
  return $McpServerSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [McpServerDraft].
extension McpServerDraftPatterns on McpServerDraft {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServerDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServerDraft() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServerDraft value)  $default,){
final _that = this;
switch (_that) {
case _McpServerDraft():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServerDraft value)?  $default,){
final _that = this;
switch (_that) {
case _McpServerDraft() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  McpTransport transport,  String? command,  String? url,  List<String> args,  String? cwd,  Map<String, String> env,  Map<String, String> headers,  List<String> secretKeys,  McpServerSettings settings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServerDraft() when $default != null:
return $default(_that.name,_that.transport,_that.command,_that.url,_that.args,_that.cwd,_that.env,_that.headers,_that.secretKeys,_that.settings);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  McpTransport transport,  String? command,  String? url,  List<String> args,  String? cwd,  Map<String, String> env,  Map<String, String> headers,  List<String> secretKeys,  McpServerSettings settings)  $default,) {final _that = this;
switch (_that) {
case _McpServerDraft():
return $default(_that.name,_that.transport,_that.command,_that.url,_that.args,_that.cwd,_that.env,_that.headers,_that.secretKeys,_that.settings);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  McpTransport transport,  String? command,  String? url,  List<String> args,  String? cwd,  Map<String, String> env,  Map<String, String> headers,  List<String> secretKeys,  McpServerSettings settings)?  $default,) {final _that = this;
switch (_that) {
case _McpServerDraft() when $default != null:
return $default(_that.name,_that.transport,_that.command,_that.url,_that.args,_that.cwd,_that.env,_that.headers,_that.secretKeys,_that.settings);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _McpServerDraft implements McpServerDraft {
  const _McpServerDraft({required this.name, required this.transport, this.command, this.url,  List<String> args = const [], this.cwd,  Map<String, String> env = const {},  Map<String, String> headers = const {},  List<String> secretKeys = const [], this.settings = const McpServerSettings()}): _args = args,_env = env,_headers = headers,_secretKeys = secretKeys;
  factory _McpServerDraft.fromJson(Map<String, dynamic> json) => _$McpServerDraftFromJson(json);

@override final  String name;
@override final  McpTransport transport;
@override final  String? command;
@override final  String? url;
 final  List<String> _args;
@override@JsonKey() List<String> get args {
  if (_args is EqualUnmodifiableListView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_args);
}

@override final  String? cwd;
 final  Map<String, String> _env;
@override@JsonKey() Map<String, String> get env {
  if (_env is EqualUnmodifiableMapView) return _env;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_env);
}

 final  Map<String, String> _headers;
@override@JsonKey() Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

 final  List<String> _secretKeys;
@override@JsonKey() List<String> get secretKeys {
  if (_secretKeys is EqualUnmodifiableListView) return _secretKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_secretKeys);
}

@override@JsonKey() final  McpServerSettings settings;

/// Create a copy of McpServerDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServerDraftCopyWith<_McpServerDraft> get copyWith => __$McpServerDraftCopyWithImpl<_McpServerDraft>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServerDraftToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServerDraft&&(identical(other.name, name) || other.name == name)&&(identical(other.transport, transport) || other.transport == transport)&&(identical(other.command, command) || other.command == command)&&(identical(other.url, url) || other.url == url)&&const DeepCollectionEquality().equals(other.args, _args)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&const DeepCollectionEquality().equals(other.env, _env)&&const DeepCollectionEquality().equals(other.headers, _headers)&&const DeepCollectionEquality().equals(other.secretKeys, _secretKeys)&&(identical(other.settings, settings) || other.settings == settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,transport,command,url,const DeepCollectionEquality().hash(_args),cwd,const DeepCollectionEquality().hash(_env),const DeepCollectionEquality().hash(_headers),const DeepCollectionEquality().hash(_secretKeys),settings);
}

@override
String toString() {
    return 'McpServerDraft(name: $name, transport: $transport, command: $command, url: $url, args: $args, cwd: $cwd, env: $env, headers: $headers, secretKeys: $secretKeys, settings: $settings)';
}


}

/// @nodoc
abstract mixin class _$McpServerDraftCopyWith<$Res> implements $McpServerDraftCopyWith<$Res> {
  factory _$McpServerDraftCopyWith(_McpServerDraft value, $Res Function(_McpServerDraft) _then) = __$McpServerDraftCopyWithImpl;
@override @useResult
$Res call({
 String name, McpTransport transport, String? command, String? url, List<String> args, String? cwd, Map<String, String> env, Map<String, String> headers, List<String> secretKeys, McpServerSettings settings
});


@override $McpServerSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class __$McpServerDraftCopyWithImpl<$Res>
    implements _$McpServerDraftCopyWith<$Res> {
  __$McpServerDraftCopyWithImpl(this._self, this._then);

  final _McpServerDraft _self;
  final $Res Function(_McpServerDraft) _then;

/// Create a copy of McpServerDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? transport = null,Object? command = freezed,Object? url = freezed,Object? args = null,Object? cwd = freezed,Object? env = null,Object? headers = null,Object? secretKeys = null,Object? settings = null,}) {
  return _then(_McpServerDraft(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,transport: null == transport ? _self.transport : transport // ignore: cast_nullable_to_non_nullable
as McpTransport,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as List<String>,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,env: null == env ? _self._env : env // ignore: cast_nullable_to_non_nullable
as Map<String, String>,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,secretKeys: null == secretKeys ? _self._secretKeys : secretKeys // ignore: cast_nullable_to_non_nullable
as List<String>,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as McpServerSettings,
  ));
}

/// Create a copy of McpServerDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpServerSettingsCopyWith<$Res> get settings {
  
  return $McpServerSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// @nodoc
mixin _$McpServer {

 String get id; String get workspaceId; McpServerDraft get draft; int? get position; Map<String, SecretValueState> get secretStates;
/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServerCopyWith<McpServer> get copyWith => _$McpServerCopyWithImpl<McpServer>(this as McpServer, _$identity);

  /// Serializes this McpServer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpServer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServer&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.workspaceId, _this.workspaceId) || other.workspaceId == _this.workspaceId)&&(identical(other.draft, _this.draft) || other.draft == _this.draft)&&(identical(other.position, _this.position) || other.position == _this.position)&&const DeepCollectionEquality().equals(other.secretStates, _this.secretStates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpServer;
  return Object.hash(runtimeType,_this.id,_this.workspaceId,_this.draft,_this.position,const DeepCollectionEquality().hash(_this.secretStates));
}

@override
String toString() {
  final _this = this as McpServer;
  return 'McpServer(id: ${_this.id}, workspaceId: ${_this.workspaceId}, draft: ${_this.draft}, position: ${_this.position}, secretStates: ${_this.secretStates})';
}


}

/// @nodoc
abstract mixin class $McpServerCopyWith<$Res>  {
  factory $McpServerCopyWith(McpServer value, $Res Function(McpServer) _then) = _$McpServerCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, McpServerDraft draft, int? position, Map<String, SecretValueState> secretStates
});


$McpServerDraftCopyWith<$Res> get draft;

}
/// @nodoc
class _$McpServerCopyWithImpl<$Res>
    implements $McpServerCopyWith<$Res> {
  _$McpServerCopyWithImpl(this._self, this._then);

  final McpServer _self;
  final $Res Function(McpServer) _then;

/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? draft = null,Object? position = freezed,Object? secretStates = null,}) {
  return _then(McpServer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as McpServerDraft,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,secretStates: null == secretStates ? _self.secretStates : secretStates // ignore: cast_nullable_to_non_nullable
as Map<String, SecretValueState>,
  ));
}
/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpServerDraftCopyWith<$Res> get draft {
  
  return $McpServerDraftCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}
}


/// Adds pattern-matching-related methods to [McpServer].
extension McpServerPatterns on McpServer {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServer() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServer value)  $default,){
final _that = this;
switch (_that) {
case _McpServer():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServer value)?  $default,){
final _that = this;
switch (_that) {
case _McpServer() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  McpServerDraft draft,  int? position,  Map<String, SecretValueState> secretStates)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServer() when $default != null:
return $default(_that.id,_that.workspaceId,_that.draft,_that.position,_that.secretStates);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  McpServerDraft draft,  int? position,  Map<String, SecretValueState> secretStates)  $default,) {final _that = this;
switch (_that) {
case _McpServer():
return $default(_that.id,_that.workspaceId,_that.draft,_that.position,_that.secretStates);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  McpServerDraft draft,  int? position,  Map<String, SecretValueState> secretStates)?  $default,) {final _that = this;
switch (_that) {
case _McpServer() when $default != null:
return $default(_that.id,_that.workspaceId,_that.draft,_that.position,_that.secretStates);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _McpServer implements McpServer {
  const _McpServer({required this.id, required this.workspaceId, required this.draft, this.position,  Map<String, SecretValueState> secretStates = const {}}): _secretStates = secretStates;
  factory _McpServer.fromJson(Map<String, dynamic> json) => _$McpServerFromJson(json);

@override final  String id;
@override final  String workspaceId;
@override final  McpServerDraft draft;
@override final  int? position;
 final  Map<String, SecretValueState> _secretStates;
@override@JsonKey() Map<String, SecretValueState> get secretStates {
  if (_secretStates is EqualUnmodifiableMapView) return _secretStates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_secretStates);
}


/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServerCopyWith<_McpServer> get copyWith => __$McpServerCopyWithImpl<_McpServer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServer&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.position, position) || other.position == position)&&const DeepCollectionEquality().equals(other.secretStates, _secretStates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,workspaceId,draft,position,const DeepCollectionEquality().hash(_secretStates));
}

@override
String toString() {
    return 'McpServer(id: $id, workspaceId: $workspaceId, draft: $draft, position: $position, secretStates: $secretStates)';
}


}

/// @nodoc
abstract mixin class _$McpServerCopyWith<$Res> implements $McpServerCopyWith<$Res> {
  factory _$McpServerCopyWith(_McpServer value, $Res Function(_McpServer) _then) = __$McpServerCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, McpServerDraft draft, int? position, Map<String, SecretValueState> secretStates
});


@override $McpServerDraftCopyWith<$Res> get draft;

}
/// @nodoc
class __$McpServerCopyWithImpl<$Res>
    implements _$McpServerCopyWith<$Res> {
  __$McpServerCopyWithImpl(this._self, this._then);

  final _McpServer _self;
  final $Res Function(_McpServer) _then;

/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? draft = null,Object? position = freezed,Object? secretStates = null,}) {
  return _then(_McpServer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as McpServerDraft,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,secretStates: null == secretStates ? _self._secretStates : secretStates // ignore: cast_nullable_to_non_nullable
as Map<String, SecretValueState>,
  ));
}

/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpServerDraftCopyWith<$Res> get draft {
  
  return $McpServerDraftCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}
}

// dart format on
