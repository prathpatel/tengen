import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tengen/src/network/http.dart';

void main() {
  test('keeps the session cookies, and sends the CSRF token on POST', () async {
    final requests = <http.Request>[];
    final api = OgsHttp(
      MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{}',
          200,
          headers: {
            // The IO client joins repeated headers with commas.
            'set-cookie':
                'csrftoken=abc123; expires=Thu, 18 Nov 2027 10:00:00 GMT; Path=/, '
                'sessionid=sess42; expires=Wed, 19 Nov 2031 10:00:00 GMT; HttpOnly; Path=/, '
                'other=ignored',
          },
        );
      }),
    );
    await api.get('/api/v1/ui/config');
    expect(api.cookies, {'csrftoken': 'abc123', 'sessionid': 'sess42'});

    await api.post('/api/v0/login', {'username': 'a'});
    final post = requests.last;
    expect(post.headers['X-CSRFToken'], 'abc123');
    expect(post.headers['Referer'], 'https://online-go.com/');
    expect(post.headers['Cookie'], contains('sessionid=sess42'));
    expect(post.body, '{"username":"a"}');
    expect(requests.first.headers.containsKey('X-CSRFToken'), isFalse);
  });

  test('throws with the server message on errors', () async {
    final api = OgsHttp(
      MockClient((_) async => http.Response('{"error": "Invalid username or password"}', 403)),
    );
    await expectLater(
      api.post('/api/v0/login', const <String, Object?>{}),
      throwsA(
        isA<OgsHttpException>()
            .having((e) => e.statusCode, 'status', 403)
            .having((e) => e.message, 'message', 'Invalid username or password'),
      ),
    );
  });
}
