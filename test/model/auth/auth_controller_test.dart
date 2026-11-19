import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/network/http.dart';

import '../../fakes.dart';

const userConfig = {
  'user': {'id': 42, 'username': 'alice', 'ranking': 25.0},
  'user_jwt': 'alice-jwt',
};

void main() {
  test('starts as a guest', () async {
    final (:container, sockets: _) = await makeContainer();
    addTearDown(container.dispose);
    final auth = await container.read(authProvider.future);
    expect(auth.isSignedIn, isFalse);
    expect(auth.jwt, 'guest-jwt');
  });

  test('signs in with the password and stores the session', () async {
    final (:container, sockets: _) = await makeContainer(
      http: (request) {
        if (request.url.path == '/api/v1/ui/config') {
          return http.Response(
            jsonEncode(guestConfig),
            200,
            headers: {'set-cookie': 'csrftoken=tok; Path=/'},
          );
        }
        if (request.url.path == '/api/v0/login') {
          expect(request.headers['X-CSRFToken'], 'tok');
          expect(jsonDecode(request.body), {'username': 'alice', 'password': 'secret'});
          return http.Response(
            jsonEncode(userConfig),
            200,
            headers: {'set-cookie': 'sessionid=s1; HttpOnly; Path=/'},
          );
        }
        return null;
      },
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    await container.read(authProvider.notifier).signIn(' alice ', 'secret');
    final auth = container.read(authProvider).value!;
    expect(auth.isSignedIn, isTrue);
    expect(auth.user.username, 'alice');
    expect(auth.user.rankLabel, '5k');
    expect(auth.jwt, 'alice-jwt');
    final stored = await container.read(secureStorageProvider).read(key: 'ogs.cookies');
    expect(jsonDecode(stored!), {'csrftoken': 'tok', 'sessionid': 's1'});
  });

  test('restores a stored session', () async {
    final (:container, sockets: _) = await makeContainer(
      secureStorage: {
        'ogs.cookies': jsonEncode({'sessionid': 's1', 'csrftoken': 'tok'}),
      },
      http: (request) {
        if (request.url.path != '/api/v1/ui/config') return null;
        return request.headers['Cookie']?.contains('sessionid=s1') ?? false
            ? userConfig
            : guestConfig;
      },
    );
    addTearDown(container.dispose);
    final auth = await container.read(authProvider.future);
    expect(auth.user.id, 42);
    expect(container.read(ogsHttpProvider).cookies['sessionid'], 's1');
  });
}
