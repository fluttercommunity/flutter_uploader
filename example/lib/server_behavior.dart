/// Configure server behavior
class ServerBehavior {
  /// User visible
  final String title;

  /// Backend server understands this
  final String name;

  ServerBehavior._(this.title, this.name);

  static ServerBehavior defaultOk200 = ServerBehavior._('OK - 200', 'ok200');

  static List<ServerBehavior> all = [
    defaultOk200,
    ServerBehavior._('OK - 200, add random data', 'ok200randomdata'),
    ServerBehavior._('OK - 201', 'ok201'),
    ServerBehavior._('Error - 401', 'error401'),
    ServerBehavior._('Error - 403', 'error403'),
    ServerBehavior._('Error - 500', 'error500')
  ];
}
