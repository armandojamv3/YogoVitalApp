import 'package:dart_frog/dart_frog.dart';

/// Simple CORS middleware for development.
/// Allows all origins (for dev). In production restrict this.
Handler middleware(Handler handler) {
  return (context) async {
    final request = context.request;

    // Handle preflight requests
    if (request.method == HttpMethod.options) {
      return Response(statusCode: 204, headers: {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'access-control-allow-headers': 'Content-Type, Authorization',
        'access-control-max-age': '86400',
      });
    }

    // Forward request and add CORS headers to the response
    final response = await handler(context);
    return response.copyWith(headers: {
      ...response.headers,
      'access-control-allow-origin': '*',
      'access-control-allow-headers': 'Content-Type, Authorization',
    });
  };
}
