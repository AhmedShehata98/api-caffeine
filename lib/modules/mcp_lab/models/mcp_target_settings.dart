/// A captured copy of the app's network settings used for one resolution.
/// Keeps transport contracts usable independently of Flutter/providers.
class McpTargetSettings {
  const McpTargetSettings({
    this.timeout = const Duration(seconds: 30),
    this.proxyUrl,
  });
  final Duration timeout;
  final String? proxyUrl;
}
