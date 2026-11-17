// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp_diagnostics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RpcFrame {

 RpcDirection get direction; DateTime get timestamp; RpcFrameKind get kind; Object? get id; String? get method; String get rawJson; int get size; Object? get pairedId; Map<String, dynamic> get meta; bool get redacted;
/// Create a copy of RpcFrame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RpcFrameCopyWith<RpcFrame> get copyWith => _$RpcFrameCopyWithImpl<RpcFrame>(this as RpcFrame, _$identity);

  /// Serializes this RpcFrame to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RpcFrame;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RpcFrame&&(identical(other.direction, _this.direction) || other.direction == _this.direction)&&(identical(other.timestamp, _this.timestamp) || other.timestamp == _this.timestamp)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&const DeepCollectionEquality().equals(other.id, _this.id)&&(identical(other.method, _this.method) || other.method == _this.method)&&(identical(other.rawJson, _this.rawJson) || other.rawJson == _this.rawJson)&&(identical(other.size, _this.size) || other.size == _this.size)&&const DeepCollectionEquality().equals(other.pairedId, _this.pairedId)&&const DeepCollectionEquality().equals(other.meta, _this.meta)&&(identical(other.redacted, _this.redacted) || other.redacted == _this.redacted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RpcFrame;
  return Object.hash(runtimeType,_this.direction,_this.timestamp,_this.kind,const DeepCollectionEquality().hash(_this.id),_this.method,_this.rawJson,_this.size,const DeepCollectionEquality().hash(_this.pairedId),const DeepCollectionEquality().hash(_this.meta),_this.redacted);
}

@override
String toString() {
  final _this = this as RpcFrame;
  return 'RpcFrame(direction: ${_this.direction}, timestamp: ${_this.timestamp}, kind: ${_this.kind}, id: ${_this.id}, method: ${_this.method}, rawJson: ${_this.rawJson}, size: ${_this.size}, pairedId: ${_this.pairedId}, meta: ${_this.meta}, redacted: ${_this.redacted})';
}


}

/// @nodoc
abstract mixin class $RpcFrameCopyWith<$Res>  {
  factory $RpcFrameCopyWith(RpcFrame value, $Res Function(RpcFrame) _then) = _$RpcFrameCopyWithImpl;
@useResult
$Res call({
 RpcDirection direction, DateTime timestamp, RpcFrameKind kind, Object? id, String? method, String rawJson, int size, Object? pairedId, Map<String, dynamic> meta, bool redacted
});




}
/// @nodoc
class _$RpcFrameCopyWithImpl<$Res>
    implements $RpcFrameCopyWith<$Res> {
  _$RpcFrameCopyWithImpl(this._self, this._then);

  final RpcFrame _self;
  final $Res Function(RpcFrame) _then;

/// Create a copy of RpcFrame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? direction = null,Object? timestamp = null,Object? kind = null,Object? id = freezed,Object? method = freezed,Object? rawJson = null,Object? size = null,Object? pairedId = freezed,Object? meta = null,Object? redacted = null,}) {
  return _then(RpcFrame(
direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as RpcDirection,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RpcFrameKind,id: freezed == id ? _self.id : id ,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,rawJson: null == rawJson ? _self.rawJson : rawJson // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,pairedId: freezed == pairedId ? _self.pairedId : pairedId ,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,redacted: null == redacted ? _self.redacted : redacted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RpcFrame].
extension RpcFramePatterns on RpcFrame {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RpcFrame value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RpcFrame() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RpcFrame value)  $default,){
final _that = this;
switch (_that) {
case _RpcFrame():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RpcFrame value)?  $default,){
final _that = this;
switch (_that) {
case _RpcFrame() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RpcDirection direction,  DateTime timestamp,  RpcFrameKind kind,  Object? id,  String? method,  String rawJson,  int size,  Object? pairedId,  Map<String, dynamic> meta,  bool redacted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RpcFrame() when $default != null:
return $default(_that.direction,_that.timestamp,_that.kind,_that.id,_that.method,_that.rawJson,_that.size,_that.pairedId,_that.meta,_that.redacted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RpcDirection direction,  DateTime timestamp,  RpcFrameKind kind,  Object? id,  String? method,  String rawJson,  int size,  Object? pairedId,  Map<String, dynamic> meta,  bool redacted)  $default,) {final _that = this;
switch (_that) {
case _RpcFrame():
return $default(_that.direction,_that.timestamp,_that.kind,_that.id,_that.method,_that.rawJson,_that.size,_that.pairedId,_that.meta,_that.redacted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RpcDirection direction,  DateTime timestamp,  RpcFrameKind kind,  Object? id,  String? method,  String rawJson,  int size,  Object? pairedId,  Map<String, dynamic> meta,  bool redacted)?  $default,) {final _that = this;
switch (_that) {
case _RpcFrame() when $default != null:
return $default(_that.direction,_that.timestamp,_that.kind,_that.id,_that.method,_that.rawJson,_that.size,_that.pairedId,_that.meta,_that.redacted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RpcFrame implements RpcFrame {
  const _RpcFrame({required this.direction, required this.timestamp, required this.kind, this.id, this.method, required this.rawJson, required this.size, this.pairedId,  Map<String, dynamic> meta = const {}, this.redacted = false}): _meta = meta;
  factory _RpcFrame.fromJson(Map<String, dynamic> json) => _$RpcFrameFromJson(json);

@override final  RpcDirection direction;
@override final  DateTime timestamp;
@override final  RpcFrameKind kind;
@override final  Object? id;
@override final  String? method;
@override final  String rawJson;
@override final  int size;
@override final  Object? pairedId;
 final  Map<String, dynamic> _meta;
@override@JsonKey() Map<String, dynamic> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}

@override@JsonKey() final  bool redacted;

/// Create a copy of RpcFrame
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RpcFrameCopyWith<_RpcFrame> get copyWith => __$RpcFrameCopyWithImpl<_RpcFrame>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RpcFrameToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RpcFrame&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other.id, id)&&(identical(other.method, method) || other.method == method)&&(identical(other.rawJson, rawJson) || other.rawJson == rawJson)&&(identical(other.size, size) || other.size == size)&&const DeepCollectionEquality().equals(other.pairedId, pairedId)&&const DeepCollectionEquality().equals(other.meta, _meta)&&(identical(other.redacted, redacted) || other.redacted == redacted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,direction,timestamp,kind,const DeepCollectionEquality().hash(id),method,rawJson,size,const DeepCollectionEquality().hash(pairedId),const DeepCollectionEquality().hash(_meta),redacted);
}

@override
String toString() {
    return 'RpcFrame(direction: $direction, timestamp: $timestamp, kind: $kind, id: $id, method: $method, rawJson: $rawJson, size: $size, pairedId: $pairedId, meta: $meta, redacted: $redacted)';
}


}

/// @nodoc
abstract mixin class _$RpcFrameCopyWith<$Res> implements $RpcFrameCopyWith<$Res> {
  factory _$RpcFrameCopyWith(_RpcFrame value, $Res Function(_RpcFrame) _then) = __$RpcFrameCopyWithImpl;
@override @useResult
$Res call({
 RpcDirection direction, DateTime timestamp, RpcFrameKind kind, Object? id, String? method, String rawJson, int size, Object? pairedId, Map<String, dynamic> meta, bool redacted
});




}
/// @nodoc
class __$RpcFrameCopyWithImpl<$Res>
    implements _$RpcFrameCopyWith<$Res> {
  __$RpcFrameCopyWithImpl(this._self, this._then);

  final _RpcFrame _self;
  final $Res Function(_RpcFrame) _then;

/// Create a copy of RpcFrame
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? direction = null,Object? timestamp = null,Object? kind = null,Object? id = freezed,Object? method = freezed,Object? rawJson = null,Object? size = null,Object? pairedId = freezed,Object? meta = null,Object? redacted = null,}) {
  return _then(_RpcFrame(
direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as RpcDirection,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RpcFrameKind,id: freezed == id ? _self.id : id ,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,rawJson: null == rawJson ? _self.rawJson : rawJson // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,pairedId: freezed == pairedId ? _self.pairedId : pairedId ,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,redacted: null == redacted ? _self.redacted : redacted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$NetworkEntry {

 String get method; String get url; int? get status; Map<String, List<String>> get requestHeaders; Map<String, List<String>> get responseHeaders; String? get body; bool get truncated; Duration get duration;
/// Create a copy of NetworkEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NetworkEntryCopyWith<NetworkEntry> get copyWith => _$NetworkEntryCopyWithImpl<NetworkEntry>(this as NetworkEntry, _$identity);

  /// Serializes this NetworkEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as NetworkEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NetworkEntry&&(identical(other.method, _this.method) || other.method == _this.method)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.requestHeaders, _this.requestHeaders)&&const DeepCollectionEquality().equals(other.responseHeaders, _this.responseHeaders)&&(identical(other.body, _this.body) || other.body == _this.body)&&(identical(other.truncated, _this.truncated) || other.truncated == _this.truncated)&&(identical(other.duration, _this.duration) || other.duration == _this.duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as NetworkEntry;
  return Object.hash(runtimeType,_this.method,_this.url,_this.status,const DeepCollectionEquality().hash(_this.requestHeaders),const DeepCollectionEquality().hash(_this.responseHeaders),_this.body,_this.truncated,_this.duration);
}

@override
String toString() {
  final _this = this as NetworkEntry;
  return 'NetworkEntry(method: ${_this.method}, url: ${_this.url}, status: ${_this.status}, requestHeaders: ${_this.requestHeaders}, responseHeaders: ${_this.responseHeaders}, body: ${_this.body}, truncated: ${_this.truncated}, duration: ${_this.duration})';
}


}

/// @nodoc
abstract mixin class $NetworkEntryCopyWith<$Res>  {
  factory $NetworkEntryCopyWith(NetworkEntry value, $Res Function(NetworkEntry) _then) = _$NetworkEntryCopyWithImpl;
@useResult
$Res call({
 String method, String url, int? status, Map<String, List<String>> requestHeaders, Map<String, List<String>> responseHeaders, String? body, bool truncated, Duration duration
});




}
/// @nodoc
class _$NetworkEntryCopyWithImpl<$Res>
    implements $NetworkEntryCopyWith<$Res> {
  _$NetworkEntryCopyWithImpl(this._self, this._then);

  final NetworkEntry _self;
  final $Res Function(NetworkEntry) _then;

/// Create a copy of NetworkEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? method = null,Object? url = null,Object? status = freezed,Object? requestHeaders = null,Object? responseHeaders = null,Object? body = freezed,Object? truncated = null,Object? duration = null,}) {
  return _then(NetworkEntry(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,requestHeaders: null == requestHeaders ? _self.requestHeaders : requestHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,responseHeaders: null == responseHeaders ? _self.responseHeaders : responseHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [NetworkEntry].
extension NetworkEntryPatterns on NetworkEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NetworkEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NetworkEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NetworkEntry value)  $default,){
final _that = this;
switch (_that) {
case _NetworkEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NetworkEntry value)?  $default,){
final _that = this;
switch (_that) {
case _NetworkEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String method,  String url,  int? status,  Map<String, List<String>> requestHeaders,  Map<String, List<String>> responseHeaders,  String? body,  bool truncated,  Duration duration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NetworkEntry() when $default != null:
return $default(_that.method,_that.url,_that.status,_that.requestHeaders,_that.responseHeaders,_that.body,_that.truncated,_that.duration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String method,  String url,  int? status,  Map<String, List<String>> requestHeaders,  Map<String, List<String>> responseHeaders,  String? body,  bool truncated,  Duration duration)  $default,) {final _that = this;
switch (_that) {
case _NetworkEntry():
return $default(_that.method,_that.url,_that.status,_that.requestHeaders,_that.responseHeaders,_that.body,_that.truncated,_that.duration);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String method,  String url,  int? status,  Map<String, List<String>> requestHeaders,  Map<String, List<String>> responseHeaders,  String? body,  bool truncated,  Duration duration)?  $default,) {final _that = this;
switch (_that) {
case _NetworkEntry() when $default != null:
return $default(_that.method,_that.url,_that.status,_that.requestHeaders,_that.responseHeaders,_that.body,_that.truncated,_that.duration);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NetworkEntry implements NetworkEntry {
  const _NetworkEntry({required this.method, required this.url, this.status,  Map<String, List<String>> requestHeaders = const {},  Map<String, List<String>> responseHeaders = const {}, this.body, this.truncated = false, required this.duration}): _requestHeaders = requestHeaders,_responseHeaders = responseHeaders;
  factory _NetworkEntry.fromJson(Map<String, dynamic> json) => _$NetworkEntryFromJson(json);

@override final  String method;
@override final  String url;
@override final  int? status;
 final  Map<String, List<String>> _requestHeaders;
@override@JsonKey() Map<String, List<String>> get requestHeaders {
  if (_requestHeaders is EqualUnmodifiableMapView) return _requestHeaders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_requestHeaders);
}

 final  Map<String, List<String>> _responseHeaders;
@override@JsonKey() Map<String, List<String>> get responseHeaders {
  if (_responseHeaders is EqualUnmodifiableMapView) return _responseHeaders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_responseHeaders);
}

@override final  String? body;
@override@JsonKey() final  bool truncated;
@override final  Duration duration;

/// Create a copy of NetworkEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NetworkEntryCopyWith<_NetworkEntry> get copyWith => __$NetworkEntryCopyWithImpl<_NetworkEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NetworkEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NetworkEntry&&(identical(other.method, method) || other.method == method)&&(identical(other.url, url) || other.url == url)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.requestHeaders, _requestHeaders)&&const DeepCollectionEquality().equals(other.responseHeaders, _responseHeaders)&&(identical(other.body, body) || other.body == body)&&(identical(other.truncated, truncated) || other.truncated == truncated)&&(identical(other.duration, duration) || other.duration == duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,method,url,status,const DeepCollectionEquality().hash(_requestHeaders),const DeepCollectionEquality().hash(_responseHeaders),body,truncated,duration);
}

@override
String toString() {
    return 'NetworkEntry(method: $method, url: $url, status: $status, requestHeaders: $requestHeaders, responseHeaders: $responseHeaders, body: $body, truncated: $truncated, duration: $duration)';
}


}

/// @nodoc
abstract mixin class _$NetworkEntryCopyWith<$Res> implements $NetworkEntryCopyWith<$Res> {
  factory _$NetworkEntryCopyWith(_NetworkEntry value, $Res Function(_NetworkEntry) _then) = __$NetworkEntryCopyWithImpl;
@override @useResult
$Res call({
 String method, String url, int? status, Map<String, List<String>> requestHeaders, Map<String, List<String>> responseHeaders, String? body, bool truncated, Duration duration
});




}
/// @nodoc
class __$NetworkEntryCopyWithImpl<$Res>
    implements _$NetworkEntryCopyWith<$Res> {
  __$NetworkEntryCopyWithImpl(this._self, this._then);

  final _NetworkEntry _self;
  final $Res Function(_NetworkEntry) _then;

/// Create a copy of NetworkEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? url = null,Object? status = freezed,Object? requestHeaders = null,Object? responseHeaders = null,Object? body = freezed,Object? truncated = null,Object? duration = null,}) {
  return _then(_NetworkEntry(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,requestHeaders: null == requestHeaders ? _self._requestHeaders : requestHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,responseHeaders: null == responseHeaders ? _self._responseHeaders : responseHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}


/// @nodoc
mixin _$ConsoleLine {

 DateTime get timestamp; String get text;
/// Create a copy of ConsoleLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConsoleLineCopyWith<ConsoleLine> get copyWith => _$ConsoleLineCopyWithImpl<ConsoleLine>(this as ConsoleLine, _$identity);

  /// Serializes this ConsoleLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ConsoleLine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsoleLine&&(identical(other.timestamp, _this.timestamp) || other.timestamp == _this.timestamp)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ConsoleLine;
  return Object.hash(runtimeType,_this.timestamp,_this.text);
}

@override
String toString() {
  final _this = this as ConsoleLine;
  return 'ConsoleLine(timestamp: ${_this.timestamp}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $ConsoleLineCopyWith<$Res>  {
  factory $ConsoleLineCopyWith(ConsoleLine value, $Res Function(ConsoleLine) _then) = _$ConsoleLineCopyWithImpl;
@useResult
$Res call({
 DateTime timestamp, String text
});




}
/// @nodoc
class _$ConsoleLineCopyWithImpl<$Res>
    implements $ConsoleLineCopyWith<$Res> {
  _$ConsoleLineCopyWithImpl(this._self, this._then);

  final ConsoleLine _self;
  final $Res Function(ConsoleLine) _then;

/// Create a copy of ConsoleLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = null,Object? text = null,}) {
  return _then(ConsoleLine(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ConsoleLine].
extension ConsoleLinePatterns on ConsoleLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConsoleLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConsoleLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConsoleLine value)  $default,){
final _that = this;
switch (_that) {
case _ConsoleLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConsoleLine value)?  $default,){
final _that = this;
switch (_that) {
case _ConsoleLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime timestamp,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConsoleLine() when $default != null:
return $default(_that.timestamp,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime timestamp,  String text)  $default,) {final _that = this;
switch (_that) {
case _ConsoleLine():
return $default(_that.timestamp,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime timestamp,  String text)?  $default,) {final _that = this;
switch (_that) {
case _ConsoleLine() when $default != null:
return $default(_that.timestamp,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConsoleLine implements ConsoleLine {
  const _ConsoleLine({required this.timestamp, required this.text});
  factory _ConsoleLine.fromJson(Map<String, dynamic> json) => _$ConsoleLineFromJson(json);

@override final  DateTime timestamp;
@override final  String text;

/// Create a copy of ConsoleLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConsoleLineCopyWith<_ConsoleLine> get copyWith => __$ConsoleLineCopyWithImpl<_ConsoleLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConsoleLineToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConsoleLine&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,timestamp,text);
}

@override
String toString() {
    return 'ConsoleLine(timestamp: $timestamp, text: $text)';
}


}

/// @nodoc
abstract mixin class _$ConsoleLineCopyWith<$Res> implements $ConsoleLineCopyWith<$Res> {
  factory _$ConsoleLineCopyWith(_ConsoleLine value, $Res Function(_ConsoleLine) _then) = __$ConsoleLineCopyWithImpl;
@override @useResult
$Res call({
 DateTime timestamp, String text
});




}
/// @nodoc
class __$ConsoleLineCopyWithImpl<$Res>
    implements _$ConsoleLineCopyWith<$Res> {
  __$ConsoleLineCopyWithImpl(this._self, this._then);

  final _ConsoleLine _self;
  final $Res Function(_ConsoleLine) _then;

/// Create a copy of ConsoleLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = null,Object? text = null,}) {
  return _then(_ConsoleLine(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ConnectionStatus {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConnectionStatus()';
}


}

/// @nodoc
class $ConnectionStatusCopyWith<$Res>  {
$ConnectionStatusCopyWith(ConnectionStatus _, $Res Function(ConnectionStatus) __);
}


/// Adds pattern-matching-related methods to [ConnectionStatus].
extension ConnectionStatusPatterns on ConnectionStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ConnectionIdle value)?  idle,TResult Function( ConnectionConnecting value)?  connecting,TResult Function( ConnectionConnected value)?  connected,TResult Function( ConnectionDisconnected value)?  disconnected,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ConnectionIdle() when idle != null:
return idle(_that);case ConnectionConnecting() when connecting != null:
return connecting(_that);case ConnectionConnected() when connected != null:
return connected(_that);case ConnectionDisconnected() when disconnected != null:
return disconnected(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ConnectionIdle value)  idle,required TResult Function( ConnectionConnecting value)  connecting,required TResult Function( ConnectionConnected value)  connected,required TResult Function( ConnectionDisconnected value)  disconnected,}){
final _that = this;
switch (_that) {
case ConnectionIdle():
return idle(_that);case ConnectionConnecting():
return connecting(_that);case ConnectionConnected():
return connected(_that);case ConnectionDisconnected():
return disconnected(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ConnectionIdle value)?  idle,TResult? Function( ConnectionConnecting value)?  connecting,TResult? Function( ConnectionConnected value)?  connected,TResult? Function( ConnectionDisconnected value)?  disconnected,}){
final _that = this;
switch (_that) {
case ConnectionIdle() when idle != null:
return idle(_that);case ConnectionConnecting() when connecting != null:
return connecting(_that);case ConnectionConnected() when connected != null:
return connected(_that);case ConnectionDisconnected() when disconnected != null:
return disconnected(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  connecting,TResult Function( NegotiatedEra era,  Map<String, dynamic> serverInfo)?  connected,TResult Function( McpCoded? failure)?  disconnected,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ConnectionIdle() when idle != null:
return idle();case ConnectionConnecting() when connecting != null:
return connecting();case ConnectionConnected() when connected != null:
return connected(_that.era,_that.serverInfo);case ConnectionDisconnected() when disconnected != null:
return disconnected(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  connecting,required TResult Function( NegotiatedEra era,  Map<String, dynamic> serverInfo)  connected,required TResult Function( McpCoded? failure)  disconnected,}) {final _that = this;
switch (_that) {
case ConnectionIdle():
return idle();case ConnectionConnecting():
return connecting();case ConnectionConnected():
return connected(_that.era,_that.serverInfo);case ConnectionDisconnected():
return disconnected(_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  connecting,TResult? Function( NegotiatedEra era,  Map<String, dynamic> serverInfo)?  connected,TResult? Function( McpCoded? failure)?  disconnected,}) {final _that = this;
switch (_that) {
case ConnectionIdle() when idle != null:
return idle();case ConnectionConnecting() when connecting != null:
return connecting();case ConnectionConnected() when connected != null:
return connected(_that.era,_that.serverInfo);case ConnectionDisconnected() when disconnected != null:
return disconnected(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class ConnectionIdle implements ConnectionStatus {
  const ConnectionIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConnectionStatus.idle()';
}


}




/// @nodoc


class ConnectionConnecting implements ConnectionStatus {
  const ConnectionConnecting();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionConnecting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConnectionStatus.connecting()';
}


}




/// @nodoc


class ConnectionConnected implements ConnectionStatus {
  const ConnectionConnected({required this.era, required  Map<String, dynamic> serverInfo}): _serverInfo = serverInfo;
  

 final  NegotiatedEra era;
 final  Map<String, dynamic> _serverInfo;
 Map<String, dynamic> get serverInfo {
  if (_serverInfo is EqualUnmodifiableMapView) return _serverInfo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_serverInfo);
}


/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionConnectedCopyWith<ConnectionConnected> get copyWith => _$ConnectionConnectedCopyWithImpl<ConnectionConnected>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionConnected&&(identical(other.era, era) || other.era == era)&&const DeepCollectionEquality().equals(other.serverInfo, _serverInfo));
}


@override
int get hashCode {
    return Object.hash(runtimeType,era,const DeepCollectionEquality().hash(_serverInfo));
}

@override
String toString() {
    return 'ConnectionStatus.connected(era: $era, serverInfo: $serverInfo)';
}


}

/// @nodoc
abstract mixin class $ConnectionConnectedCopyWith<$Res> implements $ConnectionStatusCopyWith<$Res> {
  factory $ConnectionConnectedCopyWith(ConnectionConnected value, $Res Function(ConnectionConnected) _then) = _$ConnectionConnectedCopyWithImpl;
@useResult
$Res call({
 NegotiatedEra era, Map<String, dynamic> serverInfo
});




}
/// @nodoc
class _$ConnectionConnectedCopyWithImpl<$Res>
    implements $ConnectionConnectedCopyWith<$Res> {
  _$ConnectionConnectedCopyWithImpl(this._self, this._then);

  final ConnectionConnected _self;
  final $Res Function(ConnectionConnected) _then;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? era = null,Object? serverInfo = null,}) {
  return _then(ConnectionConnected(
era: null == era ? _self.era : era // ignore: cast_nullable_to_non_nullable
as NegotiatedEra,serverInfo: null == serverInfo ? _self._serverInfo : serverInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

/// @nodoc


class ConnectionDisconnected implements ConnectionStatus {
  const ConnectionDisconnected({this.failure});
  

 final  McpCoded? failure;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionDisconnectedCopyWith<ConnectionDisconnected> get copyWith => _$ConnectionDisconnectedCopyWithImpl<ConnectionDisconnected>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionDisconnected&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure);
}

@override
String toString() {
    return 'ConnectionStatus.disconnected(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $ConnectionDisconnectedCopyWith<$Res> implements $ConnectionStatusCopyWith<$Res> {
  factory $ConnectionDisconnectedCopyWith(ConnectionDisconnected value, $Res Function(ConnectionDisconnected) _then) = _$ConnectionDisconnectedCopyWithImpl;
@useResult
$Res call({
 McpCoded? failure
});




}
/// @nodoc
class _$ConnectionDisconnectedCopyWithImpl<$Res>
    implements $ConnectionDisconnectedCopyWith<$Res> {
  _$ConnectionDisconnectedCopyWithImpl(this._self, this._then);

  final ConnectionDisconnected _self;
  final $Res Function(ConnectionDisconnected) _then;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = freezed,}) {
  return _then(ConnectionDisconnected(
failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as McpCoded?,
  ));
}


}

// dart format on
