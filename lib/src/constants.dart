/// The OGS server, without scheme. Override with `--dart-define=OGS_HOST=beta.online-go.com`.
const kOgsHost = String.fromEnvironment('OGS_HOST', defaultValue: 'online-go.com');

/// The realtime server, without scheme. Defaults to [kOgsHost].
const kOgsWsHost = String.fromEnvironment('OGS_WS_HOST', defaultValue: kOgsHost);

const kAppName = 'Tengen';
const kAppVersion = '0.8.3';

/// Identifies this client to the OGS realtime server.
const kOgsClientName = 'tengen';

Uri ogsUri(String path, [Map<String, String>? query]) =>
    Uri(scheme: 'https', host: kOgsHost, path: path, queryParameters: query);

Uri ogsWsUri() => Uri(scheme: 'wss', host: kOgsWsHost, path: '/');
