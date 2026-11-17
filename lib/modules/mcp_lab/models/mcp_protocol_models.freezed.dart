// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp_protocol_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ToolAnnotations {

 String? get title; bool? get readOnlyHint; bool? get destructiveHint; bool? get idempotentHint; bool? get openWorldHint;
/// Create a copy of ToolAnnotations
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolAnnotationsCopyWith<ToolAnnotations> get copyWith => _$ToolAnnotationsCopyWithImpl<ToolAnnotations>(this as ToolAnnotations, _$identity);

  /// Serializes this ToolAnnotations to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ToolAnnotations;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolAnnotations&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.readOnlyHint, _this.readOnlyHint) || other.readOnlyHint == _this.readOnlyHint)&&(identical(other.destructiveHint, _this.destructiveHint) || other.destructiveHint == _this.destructiveHint)&&(identical(other.idempotentHint, _this.idempotentHint) || other.idempotentHint == _this.idempotentHint)&&(identical(other.openWorldHint, _this.openWorldHint) || other.openWorldHint == _this.openWorldHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ToolAnnotations;
  return Object.hash(runtimeType,_this.title,_this.readOnlyHint,_this.destructiveHint,_this.idempotentHint,_this.openWorldHint);
}

@override
String toString() {
  final _this = this as ToolAnnotations;
  return 'ToolAnnotations(title: ${_this.title}, readOnlyHint: ${_this.readOnlyHint}, destructiveHint: ${_this.destructiveHint}, idempotentHint: ${_this.idempotentHint}, openWorldHint: ${_this.openWorldHint})';
}


}

/// @nodoc
abstract mixin class $ToolAnnotationsCopyWith<$Res>  {
  factory $ToolAnnotationsCopyWith(ToolAnnotations value, $Res Function(ToolAnnotations) _then) = _$ToolAnnotationsCopyWithImpl;
@useResult
$Res call({
 String? title, bool? readOnlyHint, bool? destructiveHint, bool? idempotentHint, bool? openWorldHint
});




}
/// @nodoc
class _$ToolAnnotationsCopyWithImpl<$Res>
    implements $ToolAnnotationsCopyWith<$Res> {
  _$ToolAnnotationsCopyWithImpl(this._self, this._then);

  final ToolAnnotations _self;
  final $Res Function(ToolAnnotations) _then;

/// Create a copy of ToolAnnotations
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = freezed,Object? readOnlyHint = freezed,Object? destructiveHint = freezed,Object? idempotentHint = freezed,Object? openWorldHint = freezed,}) {
  return _then(ToolAnnotations(
title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,readOnlyHint: freezed == readOnlyHint ? _self.readOnlyHint : readOnlyHint // ignore: cast_nullable_to_non_nullable
as bool?,destructiveHint: freezed == destructiveHint ? _self.destructiveHint : destructiveHint // ignore: cast_nullable_to_non_nullable
as bool?,idempotentHint: freezed == idempotentHint ? _self.idempotentHint : idempotentHint // ignore: cast_nullable_to_non_nullable
as bool?,openWorldHint: freezed == openWorldHint ? _self.openWorldHint : openWorldHint // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolAnnotations].
extension ToolAnnotationsPatterns on ToolAnnotations {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolAnnotations value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolAnnotations() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolAnnotations value)  $default,){
final _that = this;
switch (_that) {
case _ToolAnnotations():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolAnnotations value)?  $default,){
final _that = this;
switch (_that) {
case _ToolAnnotations() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? title,  bool? readOnlyHint,  bool? destructiveHint,  bool? idempotentHint,  bool? openWorldHint)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolAnnotations() when $default != null:
return $default(_that.title,_that.readOnlyHint,_that.destructiveHint,_that.idempotentHint,_that.openWorldHint);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? title,  bool? readOnlyHint,  bool? destructiveHint,  bool? idempotentHint,  bool? openWorldHint)  $default,) {final _that = this;
switch (_that) {
case _ToolAnnotations():
return $default(_that.title,_that.readOnlyHint,_that.destructiveHint,_that.idempotentHint,_that.openWorldHint);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? title,  bool? readOnlyHint,  bool? destructiveHint,  bool? idempotentHint,  bool? openWorldHint)?  $default,) {final _that = this;
switch (_that) {
case _ToolAnnotations() when $default != null:
return $default(_that.title,_that.readOnlyHint,_that.destructiveHint,_that.idempotentHint,_that.openWorldHint);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _ToolAnnotations implements ToolAnnotations {
  const _ToolAnnotations({this.title, this.readOnlyHint, this.destructiveHint, this.idempotentHint, this.openWorldHint});
  factory _ToolAnnotations.fromJson(Map<String, dynamic> json) => _$ToolAnnotationsFromJson(json);

@override final  String? title;
@override final  bool? readOnlyHint;
@override final  bool? destructiveHint;
@override final  bool? idempotentHint;
@override final  bool? openWorldHint;

/// Create a copy of ToolAnnotations
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolAnnotationsCopyWith<_ToolAnnotations> get copyWith => __$ToolAnnotationsCopyWithImpl<_ToolAnnotations>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolAnnotationsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolAnnotations&&(identical(other.title, title) || other.title == title)&&(identical(other.readOnlyHint, readOnlyHint) || other.readOnlyHint == readOnlyHint)&&(identical(other.destructiveHint, destructiveHint) || other.destructiveHint == destructiveHint)&&(identical(other.idempotentHint, idempotentHint) || other.idempotentHint == idempotentHint)&&(identical(other.openWorldHint, openWorldHint) || other.openWorldHint == openWorldHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,title,readOnlyHint,destructiveHint,idempotentHint,openWorldHint);
}

@override
String toString() {
    return 'ToolAnnotations(title: $title, readOnlyHint: $readOnlyHint, destructiveHint: $destructiveHint, idempotentHint: $idempotentHint, openWorldHint: $openWorldHint)';
}


}

/// @nodoc
abstract mixin class _$ToolAnnotationsCopyWith<$Res> implements $ToolAnnotationsCopyWith<$Res> {
  factory _$ToolAnnotationsCopyWith(_ToolAnnotations value, $Res Function(_ToolAnnotations) _then) = __$ToolAnnotationsCopyWithImpl;
@override @useResult
$Res call({
 String? title, bool? readOnlyHint, bool? destructiveHint, bool? idempotentHint, bool? openWorldHint
});




}
/// @nodoc
class __$ToolAnnotationsCopyWithImpl<$Res>
    implements _$ToolAnnotationsCopyWith<$Res> {
  __$ToolAnnotationsCopyWithImpl(this._self, this._then);

  final _ToolAnnotations _self;
  final $Res Function(_ToolAnnotations) _then;

/// Create a copy of ToolAnnotations
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = freezed,Object? readOnlyHint = freezed,Object? destructiveHint = freezed,Object? idempotentHint = freezed,Object? openWorldHint = freezed,}) {
  return _then(_ToolAnnotations(
title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,readOnlyHint: freezed == readOnlyHint ? _self.readOnlyHint : readOnlyHint // ignore: cast_nullable_to_non_nullable
as bool?,destructiveHint: freezed == destructiveHint ? _self.destructiveHint : destructiveHint // ignore: cast_nullable_to_non_nullable
as bool?,idempotentHint: freezed == idempotentHint ? _self.idempotentHint : idempotentHint // ignore: cast_nullable_to_non_nullable
as bool?,openWorldHint: freezed == openWorldHint ? _self.openWorldHint : openWorldHint // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$McpTool {

 String get name; String? get title; String? get description; Map<String, dynamic> get inputSchema; Map<String, dynamic>? get outputSchema; ToolAnnotations? get annotations;
/// Create a copy of McpTool
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpToolCopyWith<McpTool> get copyWith => _$McpToolCopyWithImpl<McpTool>(this as McpTool, _$identity);

  /// Serializes this McpTool to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpTool;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpTool&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.inputSchema, _this.inputSchema)&&const DeepCollectionEquality().equals(other.outputSchema, _this.outputSchema)&&(identical(other.annotations, _this.annotations) || other.annotations == _this.annotations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpTool;
  return Object.hash(runtimeType,_this.name,_this.title,_this.description,const DeepCollectionEquality().hash(_this.inputSchema),const DeepCollectionEquality().hash(_this.outputSchema),_this.annotations);
}

@override
String toString() {
  final _this = this as McpTool;
  return 'McpTool(name: ${_this.name}, title: ${_this.title}, description: ${_this.description}, inputSchema: ${_this.inputSchema}, outputSchema: ${_this.outputSchema}, annotations: ${_this.annotations})';
}


}

/// @nodoc
abstract mixin class $McpToolCopyWith<$Res>  {
  factory $McpToolCopyWith(McpTool value, $Res Function(McpTool) _then) = _$McpToolCopyWithImpl;
@useResult
$Res call({
 String name, String? title, String? description, Map<String, dynamic> inputSchema, Map<String, dynamic>? outputSchema, ToolAnnotations? annotations
});


$ToolAnnotationsCopyWith<$Res>? get annotations;

}
/// @nodoc
class _$McpToolCopyWithImpl<$Res>
    implements $McpToolCopyWith<$Res> {
  _$McpToolCopyWithImpl(this._self, this._then);

  final McpTool _self;
  final $Res Function(McpTool) _then;

/// Create a copy of McpTool
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? title = freezed,Object? description = freezed,Object? inputSchema = null,Object? outputSchema = freezed,Object? annotations = freezed,}) {
  return _then(McpTool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,inputSchema: null == inputSchema ? _self.inputSchema : inputSchema // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,outputSchema: freezed == outputSchema ? _self.outputSchema : outputSchema // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,annotations: freezed == annotations ? _self.annotations : annotations // ignore: cast_nullable_to_non_nullable
as ToolAnnotations?,
  ));
}
/// Create a copy of McpTool
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolAnnotationsCopyWith<$Res>? get annotations {
    if (_self.annotations == null) {
    return null;
  }

  return $ToolAnnotationsCopyWith<$Res>(_self.annotations!, (value) {
    return _then(_self.copyWith(annotations: value));
  });
}
}


/// Adds pattern-matching-related methods to [McpTool].
extension McpToolPatterns on McpTool {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpTool value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpTool() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpTool value)  $default,){
final _that = this;
switch (_that) {
case _McpTool():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpTool value)?  $default,){
final _that = this;
switch (_that) {
case _McpTool() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? title,  String? description,  Map<String, dynamic> inputSchema,  Map<String, dynamic>? outputSchema,  ToolAnnotations? annotations)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpTool() when $default != null:
return $default(_that.name,_that.title,_that.description,_that.inputSchema,_that.outputSchema,_that.annotations);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? title,  String? description,  Map<String, dynamic> inputSchema,  Map<String, dynamic>? outputSchema,  ToolAnnotations? annotations)  $default,) {final _that = this;
switch (_that) {
case _McpTool():
return $default(_that.name,_that.title,_that.description,_that.inputSchema,_that.outputSchema,_that.annotations);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? title,  String? description,  Map<String, dynamic> inputSchema,  Map<String, dynamic>? outputSchema,  ToolAnnotations? annotations)?  $default,) {final _that = this;
switch (_that) {
case _McpTool() when $default != null:
return $default(_that.name,_that.title,_that.description,_that.inputSchema,_that.outputSchema,_that.annotations);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _McpTool implements McpTool {
  const _McpTool({required this.name, this.title, this.description, required  Map<String, dynamic> inputSchema,  Map<String, dynamic>? outputSchema, this.annotations}): _inputSchema = inputSchema,_outputSchema = outputSchema;
  factory _McpTool.fromJson(Map<String, dynamic> json) => _$McpToolFromJson(json);

@override final  String name;
@override final  String? title;
@override final  String? description;
 final  Map<String, dynamic> _inputSchema;
@override Map<String, dynamic> get inputSchema {
  if (_inputSchema is EqualUnmodifiableMapView) return _inputSchema;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_inputSchema);
}

 final  Map<String, dynamic>? _outputSchema;
@override Map<String, dynamic>? get outputSchema {
  final value = _outputSchema;
  if (value == null) return null;
  if (_outputSchema is EqualUnmodifiableMapView) return _outputSchema;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  ToolAnnotations? annotations;

/// Create a copy of McpTool
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpToolCopyWith<_McpTool> get copyWith => __$McpToolCopyWithImpl<_McpTool>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpToolToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpTool&&(identical(other.name, name) || other.name == name)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.inputSchema, _inputSchema)&&const DeepCollectionEquality().equals(other.outputSchema, _outputSchema)&&(identical(other.annotations, annotations) || other.annotations == annotations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,title,description,const DeepCollectionEquality().hash(_inputSchema),const DeepCollectionEquality().hash(_outputSchema),annotations);
}

@override
String toString() {
    return 'McpTool(name: $name, title: $title, description: $description, inputSchema: $inputSchema, outputSchema: $outputSchema, annotations: $annotations)';
}


}

/// @nodoc
abstract mixin class _$McpToolCopyWith<$Res> implements $McpToolCopyWith<$Res> {
  factory _$McpToolCopyWith(_McpTool value, $Res Function(_McpTool) _then) = __$McpToolCopyWithImpl;
@override @useResult
$Res call({
 String name, String? title, String? description, Map<String, dynamic> inputSchema, Map<String, dynamic>? outputSchema, ToolAnnotations? annotations
});


@override $ToolAnnotationsCopyWith<$Res>? get annotations;

}
/// @nodoc
class __$McpToolCopyWithImpl<$Res>
    implements _$McpToolCopyWith<$Res> {
  __$McpToolCopyWithImpl(this._self, this._then);

  final _McpTool _self;
  final $Res Function(_McpTool) _then;

/// Create a copy of McpTool
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? title = freezed,Object? description = freezed,Object? inputSchema = null,Object? outputSchema = freezed,Object? annotations = freezed,}) {
  return _then(_McpTool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,inputSchema: null == inputSchema ? _self._inputSchema : inputSchema // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,outputSchema: freezed == outputSchema ? _self._outputSchema : outputSchema // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,annotations: freezed == annotations ? _self.annotations : annotations // ignore: cast_nullable_to_non_nullable
as ToolAnnotations?,
  ));
}

/// Create a copy of McpTool
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolAnnotationsCopyWith<$Res>? get annotations {
    if (_self.annotations == null) {
    return null;
  }

  return $ToolAnnotationsCopyWith<$Res>(_self.annotations!, (value) {
    return _then(_self.copyWith(annotations: value));
  });
}
}


/// @nodoc
mixin _$McpResource {

 String get uri; String get name; String? get title; String? get description; String? get mimeType; int? get size;
/// Create a copy of McpResource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpResourceCopyWith<McpResource> get copyWith => _$McpResourceCopyWithImpl<McpResource>(this as McpResource, _$identity);

  /// Serializes this McpResource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpResource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpResource&&(identical(other.uri, _this.uri) || other.uri == _this.uri)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType)&&(identical(other.size, _this.size) || other.size == _this.size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpResource;
  return Object.hash(runtimeType,_this.uri,_this.name,_this.title,_this.description,_this.mimeType,_this.size);
}

@override
String toString() {
  final _this = this as McpResource;
  return 'McpResource(uri: ${_this.uri}, name: ${_this.name}, title: ${_this.title}, description: ${_this.description}, mimeType: ${_this.mimeType}, size: ${_this.size})';
}


}

/// @nodoc
abstract mixin class $McpResourceCopyWith<$Res>  {
  factory $McpResourceCopyWith(McpResource value, $Res Function(McpResource) _then) = _$McpResourceCopyWithImpl;
@useResult
$Res call({
 String uri, String name, String? title, String? description, String? mimeType, int? size
});




}
/// @nodoc
class _$McpResourceCopyWithImpl<$Res>
    implements $McpResourceCopyWith<$Res> {
  _$McpResourceCopyWithImpl(this._self, this._then);

  final McpResource _self;
  final $Res Function(McpResource) _then;

/// Create a copy of McpResource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uri = null,Object? name = null,Object? title = freezed,Object? description = freezed,Object? mimeType = freezed,Object? size = freezed,}) {
  return _then(McpResource(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [McpResource].
extension McpResourcePatterns on McpResource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpResource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpResource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpResource value)  $default,){
final _that = this;
switch (_that) {
case _McpResource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpResource value)?  $default,){
final _that = this;
switch (_that) {
case _McpResource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uri,  String name,  String? title,  String? description,  String? mimeType,  int? size)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpResource() when $default != null:
return $default(_that.uri,_that.name,_that.title,_that.description,_that.mimeType,_that.size);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uri,  String name,  String? title,  String? description,  String? mimeType,  int? size)  $default,) {final _that = this;
switch (_that) {
case _McpResource():
return $default(_that.uri,_that.name,_that.title,_that.description,_that.mimeType,_that.size);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uri,  String name,  String? title,  String? description,  String? mimeType,  int? size)?  $default,) {final _that = this;
switch (_that) {
case _McpResource() when $default != null:
return $default(_that.uri,_that.name,_that.title,_that.description,_that.mimeType,_that.size);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _McpResource implements McpResource {
  const _McpResource({required this.uri, required this.name, this.title, this.description, this.mimeType, this.size});
  factory _McpResource.fromJson(Map<String, dynamic> json) => _$McpResourceFromJson(json);

@override final  String uri;
@override final  String name;
@override final  String? title;
@override final  String? description;
@override final  String? mimeType;
@override final  int? size;

/// Create a copy of McpResource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpResourceCopyWith<_McpResource> get copyWith => __$McpResourceCopyWithImpl<_McpResource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpResourceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpResource&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.name, name) || other.name == name)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,uri,name,title,description,mimeType,size);
}

@override
String toString() {
    return 'McpResource(uri: $uri, name: $name, title: $title, description: $description, mimeType: $mimeType, size: $size)';
}


}

/// @nodoc
abstract mixin class _$McpResourceCopyWith<$Res> implements $McpResourceCopyWith<$Res> {
  factory _$McpResourceCopyWith(_McpResource value, $Res Function(_McpResource) _then) = __$McpResourceCopyWithImpl;
@override @useResult
$Res call({
 String uri, String name, String? title, String? description, String? mimeType, int? size
});




}
/// @nodoc
class __$McpResourceCopyWithImpl<$Res>
    implements _$McpResourceCopyWith<$Res> {
  __$McpResourceCopyWithImpl(this._self, this._then);

  final _McpResource _self;
  final $Res Function(_McpResource) _then;

/// Create a copy of McpResource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uri = null,Object? name = null,Object? title = freezed,Object? description = freezed,Object? mimeType = freezed,Object? size = freezed,}) {
  return _then(_McpResource(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$McpResourceTemplate {

 String get uriTemplate; String get name; String? get title; String? get description; String? get mimeType;
/// Create a copy of McpResourceTemplate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpResourceTemplateCopyWith<McpResourceTemplate> get copyWith => _$McpResourceTemplateCopyWithImpl<McpResourceTemplate>(this as McpResourceTemplate, _$identity);

  /// Serializes this McpResourceTemplate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpResourceTemplate;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpResourceTemplate&&(identical(other.uriTemplate, _this.uriTemplate) || other.uriTemplate == _this.uriTemplate)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpResourceTemplate;
  return Object.hash(runtimeType,_this.uriTemplate,_this.name,_this.title,_this.description,_this.mimeType);
}

@override
String toString() {
  final _this = this as McpResourceTemplate;
  return 'McpResourceTemplate(uriTemplate: ${_this.uriTemplate}, name: ${_this.name}, title: ${_this.title}, description: ${_this.description}, mimeType: ${_this.mimeType})';
}


}

/// @nodoc
abstract mixin class $McpResourceTemplateCopyWith<$Res>  {
  factory $McpResourceTemplateCopyWith(McpResourceTemplate value, $Res Function(McpResourceTemplate) _then) = _$McpResourceTemplateCopyWithImpl;
@useResult
$Res call({
 String uriTemplate, String name, String? title, String? description, String? mimeType
});




}
/// @nodoc
class _$McpResourceTemplateCopyWithImpl<$Res>
    implements $McpResourceTemplateCopyWith<$Res> {
  _$McpResourceTemplateCopyWithImpl(this._self, this._then);

  final McpResourceTemplate _self;
  final $Res Function(McpResourceTemplate) _then;

/// Create a copy of McpResourceTemplate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uriTemplate = null,Object? name = null,Object? title = freezed,Object? description = freezed,Object? mimeType = freezed,}) {
  return _then(McpResourceTemplate(
uriTemplate: null == uriTemplate ? _self.uriTemplate : uriTemplate // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [McpResourceTemplate].
extension McpResourceTemplatePatterns on McpResourceTemplate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpResourceTemplate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpResourceTemplate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpResourceTemplate value)  $default,){
final _that = this;
switch (_that) {
case _McpResourceTemplate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpResourceTemplate value)?  $default,){
final _that = this;
switch (_that) {
case _McpResourceTemplate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uriTemplate,  String name,  String? title,  String? description,  String? mimeType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpResourceTemplate() when $default != null:
return $default(_that.uriTemplate,_that.name,_that.title,_that.description,_that.mimeType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uriTemplate,  String name,  String? title,  String? description,  String? mimeType)  $default,) {final _that = this;
switch (_that) {
case _McpResourceTemplate():
return $default(_that.uriTemplate,_that.name,_that.title,_that.description,_that.mimeType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uriTemplate,  String name,  String? title,  String? description,  String? mimeType)?  $default,) {final _that = this;
switch (_that) {
case _McpResourceTemplate() when $default != null:
return $default(_that.uriTemplate,_that.name,_that.title,_that.description,_that.mimeType);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _McpResourceTemplate implements McpResourceTemplate {
  const _McpResourceTemplate({required this.uriTemplate, required this.name, this.title, this.description, this.mimeType});
  factory _McpResourceTemplate.fromJson(Map<String, dynamic> json) => _$McpResourceTemplateFromJson(json);

@override final  String uriTemplate;
@override final  String name;
@override final  String? title;
@override final  String? description;
@override final  String? mimeType;

/// Create a copy of McpResourceTemplate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpResourceTemplateCopyWith<_McpResourceTemplate> get copyWith => __$McpResourceTemplateCopyWithImpl<_McpResourceTemplate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpResourceTemplateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpResourceTemplate&&(identical(other.uriTemplate, uriTemplate) || other.uriTemplate == uriTemplate)&&(identical(other.name, name) || other.name == name)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,uriTemplate,name,title,description,mimeType);
}

@override
String toString() {
    return 'McpResourceTemplate(uriTemplate: $uriTemplate, name: $name, title: $title, description: $description, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class _$McpResourceTemplateCopyWith<$Res> implements $McpResourceTemplateCopyWith<$Res> {
  factory _$McpResourceTemplateCopyWith(_McpResourceTemplate value, $Res Function(_McpResourceTemplate) _then) = __$McpResourceTemplateCopyWithImpl;
@override @useResult
$Res call({
 String uriTemplate, String name, String? title, String? description, String? mimeType
});




}
/// @nodoc
class __$McpResourceTemplateCopyWithImpl<$Res>
    implements _$McpResourceTemplateCopyWith<$Res> {
  __$McpResourceTemplateCopyWithImpl(this._self, this._then);

  final _McpResourceTemplate _self;
  final $Res Function(_McpResourceTemplate) _then;

/// Create a copy of McpResourceTemplate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uriTemplate = null,Object? name = null,Object? title = freezed,Object? description = freezed,Object? mimeType = freezed,}) {
  return _then(_McpResourceTemplate(
uriTemplate: null == uriTemplate ? _self.uriTemplate : uriTemplate // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ResourceContents {

 String get uri; String? get mimeType; String? get text; String? get blob;
/// Create a copy of ResourceContents
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResourceContentsCopyWith<ResourceContents> get copyWith => _$ResourceContentsCopyWithImpl<ResourceContents>(this as ResourceContents, _$identity);

  /// Serializes this ResourceContents to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ResourceContents;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResourceContents&&(identical(other.uri, _this.uri) || other.uri == _this.uri)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.blob, _this.blob) || other.blob == _this.blob));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ResourceContents;
  return Object.hash(runtimeType,_this.uri,_this.mimeType,_this.text,_this.blob);
}

@override
String toString() {
  final _this = this as ResourceContents;
  return 'ResourceContents(uri: ${_this.uri}, mimeType: ${_this.mimeType}, text: ${_this.text}, blob: ${_this.blob})';
}


}

/// @nodoc
abstract mixin class $ResourceContentsCopyWith<$Res>  {
  factory $ResourceContentsCopyWith(ResourceContents value, $Res Function(ResourceContents) _then) = _$ResourceContentsCopyWithImpl;
@useResult
$Res call({
 String uri, String? mimeType, String? text, String? blob
});




}
/// @nodoc
class _$ResourceContentsCopyWithImpl<$Res>
    implements $ResourceContentsCopyWith<$Res> {
  _$ResourceContentsCopyWithImpl(this._self, this._then);

  final ResourceContents _self;
  final $Res Function(ResourceContents) _then;

/// Create a copy of ResourceContents
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uri = null,Object? mimeType = freezed,Object? text = freezed,Object? blob = freezed,}) {
  return _then(ResourceContents(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,blob: freezed == blob ? _self.blob : blob // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ResourceContents].
extension ResourceContentsPatterns on ResourceContents {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResourceContents value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResourceContents() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResourceContents value)  $default,){
final _that = this;
switch (_that) {
case _ResourceContents():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResourceContents value)?  $default,){
final _that = this;
switch (_that) {
case _ResourceContents() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uri,  String? mimeType,  String? text,  String? blob)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResourceContents() when $default != null:
return $default(_that.uri,_that.mimeType,_that.text,_that.blob);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uri,  String? mimeType,  String? text,  String? blob)  $default,) {final _that = this;
switch (_that) {
case _ResourceContents():
return $default(_that.uri,_that.mimeType,_that.text,_that.blob);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uri,  String? mimeType,  String? text,  String? blob)?  $default,) {final _that = this;
switch (_that) {
case _ResourceContents() when $default != null:
return $default(_that.uri,_that.mimeType,_that.text,_that.blob);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _ResourceContents implements ResourceContents {
  const _ResourceContents({required this.uri, this.mimeType, this.text, this.blob});
  factory _ResourceContents.fromJson(Map<String, dynamic> json) => _$ResourceContentsFromJson(json);

@override final  String uri;
@override final  String? mimeType;
@override final  String? text;
@override final  String? blob;

/// Create a copy of ResourceContents
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResourceContentsCopyWith<_ResourceContents> get copyWith => __$ResourceContentsCopyWithImpl<_ResourceContents>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResourceContentsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResourceContents&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.text, text) || other.text == text)&&(identical(other.blob, blob) || other.blob == blob));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,uri,mimeType,text,blob);
}

@override
String toString() {
    return 'ResourceContents(uri: $uri, mimeType: $mimeType, text: $text, blob: $blob)';
}


}

/// @nodoc
abstract mixin class _$ResourceContentsCopyWith<$Res> implements $ResourceContentsCopyWith<$Res> {
  factory _$ResourceContentsCopyWith(_ResourceContents value, $Res Function(_ResourceContents) _then) = __$ResourceContentsCopyWithImpl;
@override @useResult
$Res call({
 String uri, String? mimeType, String? text, String? blob
});




}
/// @nodoc
class __$ResourceContentsCopyWithImpl<$Res>
    implements _$ResourceContentsCopyWith<$Res> {
  __$ResourceContentsCopyWithImpl(this._self, this._then);

  final _ResourceContents _self;
  final $Res Function(_ResourceContents) _then;

/// Create a copy of ResourceContents
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uri = null,Object? mimeType = freezed,Object? text = freezed,Object? blob = freezed,}) {
  return _then(_ResourceContents(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,blob: freezed == blob ? _self.blob : blob // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

ContentBlock _$ContentBlockFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return TextBlock.fromJson(
            json
          );
                case 'image':
          return ImageBlock.fromJson(
            json
          );
                case 'audio':
          return AudioBlock.fromJson(
            json
          );
                case 'resource':
          return EmbeddedResourceBlock.fromJson(
            json
          );
                case 'resource_link':
          return ResourceLinkBlock.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'ContentBlock',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$ContentBlock {



  /// Serializes this ContentBlock to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ContentBlock);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ContentBlock()';
}


}

/// @nodoc
class $ContentBlockCopyWith<$Res>  {
$ContentBlockCopyWith(ContentBlock _, $Res Function(ContentBlock) __);
}


/// Adds pattern-matching-related methods to [ContentBlock].
extension ContentBlockPatterns on ContentBlock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TextBlock value)?  text,TResult Function( ImageBlock value)?  image,TResult Function( AudioBlock value)?  audio,TResult Function( EmbeddedResourceBlock value)?  resource,TResult Function( ResourceLinkBlock value)?  resourceLink,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that);case ImageBlock() when image != null:
return image(_that);case AudioBlock() when audio != null:
return audio(_that);case EmbeddedResourceBlock() when resource != null:
return resource(_that);case ResourceLinkBlock() when resourceLink != null:
return resourceLink(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TextBlock value)  text,required TResult Function( ImageBlock value)  image,required TResult Function( AudioBlock value)  audio,required TResult Function( EmbeddedResourceBlock value)  resource,required TResult Function( ResourceLinkBlock value)  resourceLink,}){
final _that = this;
switch (_that) {
case TextBlock():
return text(_that);case ImageBlock():
return image(_that);case AudioBlock():
return audio(_that);case EmbeddedResourceBlock():
return resource(_that);case ResourceLinkBlock():
return resourceLink(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TextBlock value)?  text,TResult? Function( ImageBlock value)?  image,TResult? Function( AudioBlock value)?  audio,TResult? Function( EmbeddedResourceBlock value)?  resource,TResult? Function( ResourceLinkBlock value)?  resourceLink,}){
final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that);case ImageBlock() when image != null:
return image(_that);case AudioBlock() when audio != null:
return audio(_that);case EmbeddedResourceBlock() when resource != null:
return resource(_that);case ResourceLinkBlock() when resourceLink != null:
return resourceLink(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text)?  text,TResult Function( String data,  String mimeType)?  image,TResult Function( String data,  String mimeType)?  audio,TResult Function( ResourceContents resource)?  resource,TResult Function( String uri,  String name,  String? title,  String? description,  String? mimeType,  int? size)?  resourceLink,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that.text);case ImageBlock() when image != null:
return image(_that.data,_that.mimeType);case AudioBlock() when audio != null:
return audio(_that.data,_that.mimeType);case EmbeddedResourceBlock() when resource != null:
return resource(_that.resource);case ResourceLinkBlock() when resourceLink != null:
return resourceLink(_that.uri,_that.name,_that.title,_that.description,_that.mimeType,_that.size);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text)  text,required TResult Function( String data,  String mimeType)  image,required TResult Function( String data,  String mimeType)  audio,required TResult Function( ResourceContents resource)  resource,required TResult Function( String uri,  String name,  String? title,  String? description,  String? mimeType,  int? size)  resourceLink,}) {final _that = this;
switch (_that) {
case TextBlock():
return text(_that.text);case ImageBlock():
return image(_that.data,_that.mimeType);case AudioBlock():
return audio(_that.data,_that.mimeType);case EmbeddedResourceBlock():
return resource(_that.resource);case ResourceLinkBlock():
return resourceLink(_that.uri,_that.name,_that.title,_that.description,_that.mimeType,_that.size);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text)?  text,TResult? Function( String data,  String mimeType)?  image,TResult? Function( String data,  String mimeType)?  audio,TResult? Function( ResourceContents resource)?  resource,TResult? Function( String uri,  String name,  String? title,  String? description,  String? mimeType,  int? size)?  resourceLink,}) {final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that.text);case ImageBlock() when image != null:
return image(_that.data,_that.mimeType);case AudioBlock() when audio != null:
return audio(_that.data,_that.mimeType);case EmbeddedResourceBlock() when resource != null:
return resource(_that.resource);case ResourceLinkBlock() when resourceLink != null:
return resourceLink(_that.uri,_that.name,_that.title,_that.description,_that.mimeType,_that.size);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class TextBlock implements ContentBlock {
  const TextBlock({required this.text,  String? $type}): $type = $type ?? 'text';
  factory TextBlock.fromJson(Map<String, dynamic> json) => _$TextBlockFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextBlockCopyWith<TextBlock> get copyWith => _$TextBlockCopyWithImpl<TextBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextBlockToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TextBlock&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text);
}

@override
String toString() {
    return 'ContentBlock.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $TextBlockCopyWith<$Res> implements $ContentBlockCopyWith<$Res> {
  factory $TextBlockCopyWith(TextBlock value, $Res Function(TextBlock) _then) = _$TextBlockCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$TextBlockCopyWithImpl<$Res>
    implements $TextBlockCopyWith<$Res> {
  _$TextBlockCopyWithImpl(this._self, this._then);

  final TextBlock _self;
  final $Res Function(TextBlock) _then;

/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(TextBlock(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class ImageBlock implements ContentBlock {
  const ImageBlock({required this.data, required this.mimeType,  String? $type}): $type = $type ?? 'image';
  factory ImageBlock.fromJson(Map<String, dynamic> json) => _$ImageBlockFromJson(json);

 final  String data;
 final  String mimeType;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageBlockCopyWith<ImageBlock> get copyWith => _$ImageBlockCopyWithImpl<ImageBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImageBlockToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageBlock&&(identical(other.data, data) || other.data == data)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,data,mimeType);
}

@override
String toString() {
    return 'ContentBlock.image(data: $data, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class $ImageBlockCopyWith<$Res> implements $ContentBlockCopyWith<$Res> {
  factory $ImageBlockCopyWith(ImageBlock value, $Res Function(ImageBlock) _then) = _$ImageBlockCopyWithImpl;
@useResult
$Res call({
 String data, String mimeType
});




}
/// @nodoc
class _$ImageBlockCopyWithImpl<$Res>
    implements $ImageBlockCopyWith<$Res> {
  _$ImageBlockCopyWithImpl(this._self, this._then);

  final ImageBlock _self;
  final $Res Function(ImageBlock) _then;

/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,Object? mimeType = null,}) {
  return _then(ImageBlock(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class AudioBlock implements ContentBlock {
  const AudioBlock({required this.data, required this.mimeType,  String? $type}): $type = $type ?? 'audio';
  factory AudioBlock.fromJson(Map<String, dynamic> json) => _$AudioBlockFromJson(json);

 final  String data;
 final  String mimeType;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioBlockCopyWith<AudioBlock> get copyWith => _$AudioBlockCopyWithImpl<AudioBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioBlockToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioBlock&&(identical(other.data, data) || other.data == data)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,data,mimeType);
}

@override
String toString() {
    return 'ContentBlock.audio(data: $data, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class $AudioBlockCopyWith<$Res> implements $ContentBlockCopyWith<$Res> {
  factory $AudioBlockCopyWith(AudioBlock value, $Res Function(AudioBlock) _then) = _$AudioBlockCopyWithImpl;
@useResult
$Res call({
 String data, String mimeType
});




}
/// @nodoc
class _$AudioBlockCopyWithImpl<$Res>
    implements $AudioBlockCopyWith<$Res> {
  _$AudioBlockCopyWithImpl(this._self, this._then);

  final AudioBlock _self;
  final $Res Function(AudioBlock) _then;

/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,Object? mimeType = null,}) {
  return _then(AudioBlock(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class EmbeddedResourceBlock implements ContentBlock {
  const EmbeddedResourceBlock({required this.resource,  String? $type}): $type = $type ?? 'resource';
  factory EmbeddedResourceBlock.fromJson(Map<String, dynamic> json) => _$EmbeddedResourceBlockFromJson(json);

 final  ResourceContents resource;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmbeddedResourceBlockCopyWith<EmbeddedResourceBlock> get copyWith => _$EmbeddedResourceBlockCopyWithImpl<EmbeddedResourceBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EmbeddedResourceBlockToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EmbeddedResourceBlock&&(identical(other.resource, resource) || other.resource == resource));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,resource);
}

@override
String toString() {
    return 'ContentBlock.resource(resource: $resource)';
}


}

/// @nodoc
abstract mixin class $EmbeddedResourceBlockCopyWith<$Res> implements $ContentBlockCopyWith<$Res> {
  factory $EmbeddedResourceBlockCopyWith(EmbeddedResourceBlock value, $Res Function(EmbeddedResourceBlock) _then) = _$EmbeddedResourceBlockCopyWithImpl;
@useResult
$Res call({
 ResourceContents resource
});


$ResourceContentsCopyWith<$Res> get resource;

}
/// @nodoc
class _$EmbeddedResourceBlockCopyWithImpl<$Res>
    implements $EmbeddedResourceBlockCopyWith<$Res> {
  _$EmbeddedResourceBlockCopyWithImpl(this._self, this._then);

  final EmbeddedResourceBlock _self;
  final $Res Function(EmbeddedResourceBlock) _then;

/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? resource = null,}) {
  return _then(EmbeddedResourceBlock(
resource: null == resource ? _self.resource : resource // ignore: cast_nullable_to_non_nullable
as ResourceContents,
  ));
}

/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResourceContentsCopyWith<$Res> get resource {
  
  return $ResourceContentsCopyWith<$Res>(_self.resource, (value) {
    return _then(_self.copyWith(resource: value));
  });
}
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class ResourceLinkBlock implements ContentBlock {
  const ResourceLinkBlock({required this.uri, required this.name, this.title, this.description, this.mimeType, this.size,  String? $type}): $type = $type ?? 'resource_link';
  factory ResourceLinkBlock.fromJson(Map<String, dynamic> json) => _$ResourceLinkBlockFromJson(json);

 final  String uri;
 final  String name;
 final  String? title;
 final  String? description;
 final  String? mimeType;
 final  int? size;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResourceLinkBlockCopyWith<ResourceLinkBlock> get copyWith => _$ResourceLinkBlockCopyWithImpl<ResourceLinkBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResourceLinkBlockToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ResourceLinkBlock&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.name, name) || other.name == name)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,uri,name,title,description,mimeType,size);
}

@override
String toString() {
    return 'ContentBlock.resourceLink(uri: $uri, name: $name, title: $title, description: $description, mimeType: $mimeType, size: $size)';
}


}

/// @nodoc
abstract mixin class $ResourceLinkBlockCopyWith<$Res> implements $ContentBlockCopyWith<$Res> {
  factory $ResourceLinkBlockCopyWith(ResourceLinkBlock value, $Res Function(ResourceLinkBlock) _then) = _$ResourceLinkBlockCopyWithImpl;
@useResult
$Res call({
 String uri, String name, String? title, String? description, String? mimeType, int? size
});




}
/// @nodoc
class _$ResourceLinkBlockCopyWithImpl<$Res>
    implements $ResourceLinkBlockCopyWith<$Res> {
  _$ResourceLinkBlockCopyWithImpl(this._self, this._then);

  final ResourceLinkBlock _self;
  final $Res Function(ResourceLinkBlock) _then;

/// Create a copy of ContentBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? uri = null,Object? name = null,Object? title = freezed,Object? description = freezed,Object? mimeType = freezed,Object? size = freezed,}) {
  return _then(ResourceLinkBlock(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$ToolCallResult {

 ToolResultType get resultType; List<ContentBlock> get content; Object? get structuredContent; bool get isError;
/// Create a copy of ToolCallResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallResultCopyWith<ToolCallResult> get copyWith => _$ToolCallResultCopyWithImpl<ToolCallResult>(this as ToolCallResult, _$identity);

  /// Serializes this ToolCallResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ToolCallResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallResult&&(identical(other.resultType, _this.resultType) || other.resultType == _this.resultType)&&const DeepCollectionEquality().equals(other.content, _this.content)&&const DeepCollectionEquality().equals(other.structuredContent, _this.structuredContent)&&(identical(other.isError, _this.isError) || other.isError == _this.isError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ToolCallResult;
  return Object.hash(runtimeType,_this.resultType,const DeepCollectionEquality().hash(_this.content),const DeepCollectionEquality().hash(_this.structuredContent),_this.isError);
}

@override
String toString() {
  final _this = this as ToolCallResult;
  return 'ToolCallResult(resultType: ${_this.resultType}, content: ${_this.content}, structuredContent: ${_this.structuredContent}, isError: ${_this.isError})';
}


}

/// @nodoc
abstract mixin class $ToolCallResultCopyWith<$Res>  {
  factory $ToolCallResultCopyWith(ToolCallResult value, $Res Function(ToolCallResult) _then) = _$ToolCallResultCopyWithImpl;
@useResult
$Res call({
 ToolResultType resultType, List<ContentBlock> content, Object? structuredContent, bool isError
});




}
/// @nodoc
class _$ToolCallResultCopyWithImpl<$Res>
    implements $ToolCallResultCopyWith<$Res> {
  _$ToolCallResultCopyWithImpl(this._self, this._then);

  final ToolCallResult _self;
  final $Res Function(ToolCallResult) _then;

/// Create a copy of ToolCallResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? resultType = null,Object? content = null,Object? structuredContent = freezed,Object? isError = null,}) {
  return _then(ToolCallResult(
resultType: null == resultType ? _self.resultType : resultType // ignore: cast_nullable_to_non_nullable
as ToolResultType,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as List<ContentBlock>,structuredContent: freezed == structuredContent ? _self.structuredContent : structuredContent ,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolCallResult].
extension ToolCallResultPatterns on ToolCallResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCallResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCallResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCallResult value)  $default,){
final _that = this;
switch (_that) {
case _ToolCallResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCallResult value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCallResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ToolResultType resultType,  List<ContentBlock> content,  Object? structuredContent,  bool isError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCallResult() when $default != null:
return $default(_that.resultType,_that.content,_that.structuredContent,_that.isError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ToolResultType resultType,  List<ContentBlock> content,  Object? structuredContent,  bool isError)  $default,) {final _that = this;
switch (_that) {
case _ToolCallResult():
return $default(_that.resultType,_that.content,_that.structuredContent,_that.isError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ToolResultType resultType,  List<ContentBlock> content,  Object? structuredContent,  bool isError)?  $default,) {final _that = this;
switch (_that) {
case _ToolCallResult() when $default != null:
return $default(_that.resultType,_that.content,_that.structuredContent,_that.isError);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _ToolCallResult extends ToolCallResult {
  const _ToolCallResult({this.resultType = ToolResultType.complete,  List<ContentBlock> content = const [], this.structuredContent, this.isError = false}): _content = content,super._();
  factory _ToolCallResult.fromJson(Map<String, dynamic> json) => _$ToolCallResultFromJson(json);

@override@JsonKey() final  ToolResultType resultType;
 final  List<ContentBlock> _content;
@override@JsonKey() List<ContentBlock> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

@override final  Object? structuredContent;
@override@JsonKey() final  bool isError;

/// Create a copy of ToolCallResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallResultCopyWith<_ToolCallResult> get copyWith => __$ToolCallResultCopyWithImpl<_ToolCallResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolCallResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCallResult&&(identical(other.resultType, resultType) || other.resultType == resultType)&&const DeepCollectionEquality().equals(other.content, _content)&&const DeepCollectionEquality().equals(other.structuredContent, structuredContent)&&(identical(other.isError, isError) || other.isError == isError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,resultType,const DeepCollectionEquality().hash(_content),const DeepCollectionEquality().hash(structuredContent),isError);
}

@override
String toString() {
    return 'ToolCallResult(resultType: $resultType, content: $content, structuredContent: $structuredContent, isError: $isError)';
}


}

/// @nodoc
abstract mixin class _$ToolCallResultCopyWith<$Res> implements $ToolCallResultCopyWith<$Res> {
  factory _$ToolCallResultCopyWith(_ToolCallResult value, $Res Function(_ToolCallResult) _then) = __$ToolCallResultCopyWithImpl;
@override @useResult
$Res call({
 ToolResultType resultType, List<ContentBlock> content, Object? structuredContent, bool isError
});




}
/// @nodoc
class __$ToolCallResultCopyWithImpl<$Res>
    implements _$ToolCallResultCopyWith<$Res> {
  __$ToolCallResultCopyWithImpl(this._self, this._then);

  final _ToolCallResult _self;
  final $Res Function(_ToolCallResult) _then;

/// Create a copy of ToolCallResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? resultType = null,Object? content = null,Object? structuredContent = freezed,Object? isError = null,}) {
  return _then(_ToolCallResult(
resultType: null == resultType ? _self.resultType : resultType // ignore: cast_nullable_to_non_nullable
as ToolResultType,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<ContentBlock>,structuredContent: freezed == structuredContent ? _self.structuredContent : structuredContent ,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$PromptArgument {

 String get name; String? get title; String? get description; bool get required;
/// Create a copy of PromptArgument
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptArgumentCopyWith<PromptArgument> get copyWith => _$PromptArgumentCopyWithImpl<PromptArgument>(this as PromptArgument, _$identity);

  /// Serializes this PromptArgument to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PromptArgument;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptArgument&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.required, _this.required) || other.required == _this.required));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PromptArgument;
  return Object.hash(runtimeType,_this.name,_this.title,_this.description,_this.required);
}

@override
String toString() {
  final _this = this as PromptArgument;
  return 'PromptArgument(name: ${_this.name}, title: ${_this.title}, description: ${_this.description}, required: ${_this.required})';
}


}

/// @nodoc
abstract mixin class $PromptArgumentCopyWith<$Res>  {
  factory $PromptArgumentCopyWith(PromptArgument value, $Res Function(PromptArgument) _then) = _$PromptArgumentCopyWithImpl;
@useResult
$Res call({
 String name, String? title, String? description, bool required
});




}
/// @nodoc
class _$PromptArgumentCopyWithImpl<$Res>
    implements $PromptArgumentCopyWith<$Res> {
  _$PromptArgumentCopyWithImpl(this._self, this._then);

  final PromptArgument _self;
  final $Res Function(PromptArgument) _then;

/// Create a copy of PromptArgument
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? title = freezed,Object? description = freezed,Object? required = null,}) {
  return _then(PromptArgument(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PromptArgument].
extension PromptArgumentPatterns on PromptArgument {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PromptArgument value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PromptArgument() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PromptArgument value)  $default,){
final _that = this;
switch (_that) {
case _PromptArgument():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PromptArgument value)?  $default,){
final _that = this;
switch (_that) {
case _PromptArgument() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? title,  String? description,  bool required)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PromptArgument() when $default != null:
return $default(_that.name,_that.title,_that.description,_that.required);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? title,  String? description,  bool required)  $default,) {final _that = this;
switch (_that) {
case _PromptArgument():
return $default(_that.name,_that.title,_that.description,_that.required);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? title,  String? description,  bool required)?  $default,) {final _that = this;
switch (_that) {
case _PromptArgument() when $default != null:
return $default(_that.name,_that.title,_that.description,_that.required);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _PromptArgument implements PromptArgument {
  const _PromptArgument({required this.name, this.title, this.description, this.required = false});
  factory _PromptArgument.fromJson(Map<String, dynamic> json) => _$PromptArgumentFromJson(json);

@override final  String name;
@override final  String? title;
@override final  String? description;
@override@JsonKey() final  bool required;

/// Create a copy of PromptArgument
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PromptArgumentCopyWith<_PromptArgument> get copyWith => __$PromptArgumentCopyWithImpl<_PromptArgument>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromptArgumentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PromptArgument&&(identical(other.name, name) || other.name == name)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.required, required) || other.required == required));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,title,description,required);
}

@override
String toString() {
    return 'PromptArgument(name: $name, title: $title, description: $description, required: $required)';
}


}

/// @nodoc
abstract mixin class _$PromptArgumentCopyWith<$Res> implements $PromptArgumentCopyWith<$Res> {
  factory _$PromptArgumentCopyWith(_PromptArgument value, $Res Function(_PromptArgument) _then) = __$PromptArgumentCopyWithImpl;
@override @useResult
$Res call({
 String name, String? title, String? description, bool required
});




}
/// @nodoc
class __$PromptArgumentCopyWithImpl<$Res>
    implements _$PromptArgumentCopyWith<$Res> {
  __$PromptArgumentCopyWithImpl(this._self, this._then);

  final _PromptArgument _self;
  final $Res Function(_PromptArgument) _then;

/// Create a copy of PromptArgument
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? title = freezed,Object? description = freezed,Object? required = null,}) {
  return _then(_PromptArgument(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$McpPrompt {

 String get name; String? get title; String? get description; List<PromptArgument> get arguments;
/// Create a copy of McpPrompt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpPromptCopyWith<McpPrompt> get copyWith => _$McpPromptCopyWithImpl<McpPrompt>(this as McpPrompt, _$identity);

  /// Serializes this McpPrompt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpPrompt;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpPrompt&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.arguments, _this.arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpPrompt;
  return Object.hash(runtimeType,_this.name,_this.title,_this.description,const DeepCollectionEquality().hash(_this.arguments));
}

@override
String toString() {
  final _this = this as McpPrompt;
  return 'McpPrompt(name: ${_this.name}, title: ${_this.title}, description: ${_this.description}, arguments: ${_this.arguments})';
}


}

/// @nodoc
abstract mixin class $McpPromptCopyWith<$Res>  {
  factory $McpPromptCopyWith(McpPrompt value, $Res Function(McpPrompt) _then) = _$McpPromptCopyWithImpl;
@useResult
$Res call({
 String name, String? title, String? description, List<PromptArgument> arguments
});




}
/// @nodoc
class _$McpPromptCopyWithImpl<$Res>
    implements $McpPromptCopyWith<$Res> {
  _$McpPromptCopyWithImpl(this._self, this._then);

  final McpPrompt _self;
  final $Res Function(McpPrompt) _then;

/// Create a copy of McpPrompt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? title = freezed,Object? description = freezed,Object? arguments = null,}) {
  return _then(McpPrompt(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,arguments: null == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as List<PromptArgument>,
  ));
}

}


/// Adds pattern-matching-related methods to [McpPrompt].
extension McpPromptPatterns on McpPrompt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpPrompt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpPrompt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpPrompt value)  $default,){
final _that = this;
switch (_that) {
case _McpPrompt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpPrompt value)?  $default,){
final _that = this;
switch (_that) {
case _McpPrompt() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? title,  String? description,  List<PromptArgument> arguments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpPrompt() when $default != null:
return $default(_that.name,_that.title,_that.description,_that.arguments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? title,  String? description,  List<PromptArgument> arguments)  $default,) {final _that = this;
switch (_that) {
case _McpPrompt():
return $default(_that.name,_that.title,_that.description,_that.arguments);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? title,  String? description,  List<PromptArgument> arguments)?  $default,) {final _that = this;
switch (_that) {
case _McpPrompt() when $default != null:
return $default(_that.name,_that.title,_that.description,_that.arguments);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _McpPrompt implements McpPrompt {
  const _McpPrompt({required this.name, this.title, this.description,  List<PromptArgument> arguments = const []}): _arguments = arguments;
  factory _McpPrompt.fromJson(Map<String, dynamic> json) => _$McpPromptFromJson(json);

@override final  String name;
@override final  String? title;
@override final  String? description;
 final  List<PromptArgument> _arguments;
@override@JsonKey() List<PromptArgument> get arguments {
  if (_arguments is EqualUnmodifiableListView) return _arguments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_arguments);
}


/// Create a copy of McpPrompt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpPromptCopyWith<_McpPrompt> get copyWith => __$McpPromptCopyWithImpl<_McpPrompt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpPromptToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpPrompt&&(identical(other.name, name) || other.name == name)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.arguments, _arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,title,description,const DeepCollectionEquality().hash(_arguments));
}

@override
String toString() {
    return 'McpPrompt(name: $name, title: $title, description: $description, arguments: $arguments)';
}


}

/// @nodoc
abstract mixin class _$McpPromptCopyWith<$Res> implements $McpPromptCopyWith<$Res> {
  factory _$McpPromptCopyWith(_McpPrompt value, $Res Function(_McpPrompt) _then) = __$McpPromptCopyWithImpl;
@override @useResult
$Res call({
 String name, String? title, String? description, List<PromptArgument> arguments
});




}
/// @nodoc
class __$McpPromptCopyWithImpl<$Res>
    implements _$McpPromptCopyWith<$Res> {
  __$McpPromptCopyWithImpl(this._self, this._then);

  final _McpPrompt _self;
  final $Res Function(_McpPrompt) _then;

/// Create a copy of McpPrompt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? title = freezed,Object? description = freezed,Object? arguments = null,}) {
  return _then(_McpPrompt(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,arguments: null == arguments ? _self._arguments : arguments // ignore: cast_nullable_to_non_nullable
as List<PromptArgument>,
  ));
}


}


/// @nodoc
mixin _$PromptMessage {

 PromptRole get role; ContentBlock get content;
/// Create a copy of PromptMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptMessageCopyWith<PromptMessage> get copyWith => _$PromptMessageCopyWithImpl<PromptMessage>(this as PromptMessage, _$identity);

  /// Serializes this PromptMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PromptMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptMessage&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.content, _this.content) || other.content == _this.content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PromptMessage;
  return Object.hash(runtimeType,_this.role,_this.content);
}

@override
String toString() {
  final _this = this as PromptMessage;
  return 'PromptMessage(role: ${_this.role}, content: ${_this.content})';
}


}

/// @nodoc
abstract mixin class $PromptMessageCopyWith<$Res>  {
  factory $PromptMessageCopyWith(PromptMessage value, $Res Function(PromptMessage) _then) = _$PromptMessageCopyWithImpl;
@useResult
$Res call({
 PromptRole role, ContentBlock content
});


$ContentBlockCopyWith<$Res> get content;

}
/// @nodoc
class _$PromptMessageCopyWithImpl<$Res>
    implements $PromptMessageCopyWith<$Res> {
  _$PromptMessageCopyWithImpl(this._self, this._then);

  final PromptMessage _self;
  final $Res Function(PromptMessage) _then;

/// Create a copy of PromptMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? content = null,}) {
  return _then(PromptMessage(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as PromptRole,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as ContentBlock,
  ));
}
/// Create a copy of PromptMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentBlockCopyWith<$Res> get content {
  
  return $ContentBlockCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}


/// Adds pattern-matching-related methods to [PromptMessage].
extension PromptMessagePatterns on PromptMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PromptMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PromptMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PromptMessage value)  $default,){
final _that = this;
switch (_that) {
case _PromptMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PromptMessage value)?  $default,){
final _that = this;
switch (_that) {
case _PromptMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PromptRole role,  ContentBlock content)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PromptMessage() when $default != null:
return $default(_that.role,_that.content);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PromptRole role,  ContentBlock content)  $default,) {final _that = this;
switch (_that) {
case _PromptMessage():
return $default(_that.role,_that.content);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PromptRole role,  ContentBlock content)?  $default,) {final _that = this;
switch (_that) {
case _PromptMessage() when $default != null:
return $default(_that.role,_that.content);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.none)
class _PromptMessage implements PromptMessage {
  const _PromptMessage({required this.role, required this.content});
  factory _PromptMessage.fromJson(Map<String, dynamic> json) => _$PromptMessageFromJson(json);

@override final  PromptRole role;
@override final  ContentBlock content;

/// Create a copy of PromptMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PromptMessageCopyWith<_PromptMessage> get copyWith => __$PromptMessageCopyWithImpl<_PromptMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromptMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PromptMessage&&(identical(other.role, role) || other.role == role)&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,role,content);
}

@override
String toString() {
    return 'PromptMessage(role: $role, content: $content)';
}


}

/// @nodoc
abstract mixin class _$PromptMessageCopyWith<$Res> implements $PromptMessageCopyWith<$Res> {
  factory _$PromptMessageCopyWith(_PromptMessage value, $Res Function(_PromptMessage) _then) = __$PromptMessageCopyWithImpl;
@override @useResult
$Res call({
 PromptRole role, ContentBlock content
});


@override $ContentBlockCopyWith<$Res> get content;

}
/// @nodoc
class __$PromptMessageCopyWithImpl<$Res>
    implements _$PromptMessageCopyWith<$Res> {
  __$PromptMessageCopyWithImpl(this._self, this._then);

  final _PromptMessage _self;
  final $Res Function(_PromptMessage) _then;

/// Create a copy of PromptMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? content = null,}) {
  return _then(_PromptMessage(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as PromptRole,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as ContentBlock,
  ));
}

/// Create a copy of PromptMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentBlockCopyWith<$Res> get content {
  
  return $ContentBlockCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}

// dart format on
