/// A paired device that serves `network://` songs in Mornye.
///
/// FluentMusic has no such pairing, so no connection is ever available.
class NetworkConnection {
  const NetworkConnection({required this.id, required this.name});

  final String id;
  final String name;
}

class NetworkStorageService {
  NetworkStorageService._();

  static final NetworkStorageService instance = NetworkStorageService._();

  Future<List<NetworkConnection>> connections() async => const [];

  Future<NetworkConnection> connection(String id) async =>
      throw StateError('Network connection unavailable');

  /// Whether the `network://` [source] can be rewritten in place.
  Future<bool> canEditFile(String source) async => false;
}