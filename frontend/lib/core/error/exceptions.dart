class ServerException implements Exception {
  final String message;
  ServerException([this.message = 'Server Error']);

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Network Connection Error']);

  @override
  String toString() => message;
}

