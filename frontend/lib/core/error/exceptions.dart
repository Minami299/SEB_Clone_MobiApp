class ServerException implements Exception {
  final String message;
  ServerException([this.message = 'Server Error']);
}

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Network Connection Error']);
}

