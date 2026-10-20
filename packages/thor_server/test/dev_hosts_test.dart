import 'package:test/test.dart';
import 'package:thor_server/src/dev_hosts.dart';

void main() {
  const hosts = DevHosts();

  group('allowed by default', () {
    for (final host in [
      'localhost',
      'localhost:4300',
      'LOCALHOST:4300',
      'LocalHost',
      'localhost.',
      'localhost.:4300',
      'app.localhost:4300',
      '127.0.0.1',
      '127.0.0.1:4300',
      '[::1]',
      '[::1]:4300',
      '[0:0:0:0:0:0:0:1]:4300',
      // An IP literal can't be a rebinding name: what a phone types.
      '192.168.1.20:4300',
      '[fe80::1]:4300',
    ]) {
      test(host, () => expect(hosts.allows(host), isTrue));
    }
  });

  group('refused', () {
    for (final host in [
      'evil.example',
      'evil.example:4300',
      'localhost.evil.example',
      'evil.example.localhost.evil.example:4300',
      'notlocalhost',
      'localhost@evil.example',
      'localhost:4300@evil.example',
      'evil.example/localhost',
      'localhost:abc',
      'localhost:',
      '::1',
      '[::1',
      '[::1]x',
      'local host',
      'localhost,evil.example',
      '',
      ' ',
    ]) {
      test('"$host"', () {
        // The empty one is a missing Host: see below.
        if (host.trim().isEmpty) return;
        expect(hosts.allows(host), isFalse);
      });
    }
  });

  test(
    'a request with no Host (HTTP/1.0) passes: a browser always sends it',
    () {
      expect(hosts.allows(null), isTrue);
      expect(hosts.allows(''), isTrue);
    },
  );

  group('allowed hosts', () {
    const custom = DevHosts(['Dev.Example', '.corp.test', 'mac.local:4300']);

    test('an exact name, any case, with or without a port', () {
      expect(custom.allows('dev.example'), isTrue);
      expect(custom.allows('DEV.EXAMPLE:4300'), isTrue);
      expect(custom.allows('mac.local:9999'), isTrue);
    });

    test('a leading dot: the domain and its subdomains', () {
      expect(custom.allows('corp.test'), isTrue);
      expect(custom.allows('a.b.corp.test:1'), isTrue);
      expect(custom.allows('evilcorp.test'), isFalse);
      expect(custom.allows('corp.test.evil.example'), isFalse);
    });

    test('does not open the rest', () {
      expect(custom.allows('sub.dev.example'), isFalse);
      expect(custom.allows('evil.example'), isFalse);
    });

    test('* allows every host', () {
      expect(const DevHosts(['*']).allows('evil.example'), isTrue);
    });
  });

  test('fromEnvironment reads a comma list', () {
    final fromEnv = DevHosts.parse(' a.test, .b.test ,,');
    expect(fromEnv.allows('a.test'), isTrue);
    expect(fromEnv.allows('x.b.test'), isTrue);
    expect(fromEnv.allows('c.test'), isFalse);
    expect(DevHosts.parse(null).allows('a.test'), isFalse);
  });

  test('the refusal says what to do', () {
    final message = hosts.refusal('evil.example');
    expect(message, contains('evil.example'));
    expect(message, contains('--allowed-host'));
  });

  group('--allowed-host entries that allow nothing are a problem', () {
    for (final entry in [
      '*.example.test',
      'https://dev.example',
      'dev.example/path',
      'a.test,b.test',
      '',
      ' ',
      '.',
      'dev example',
      'user@dev.example',
    ]) {
      test('"$entry"', () => expect(DevHosts.problem(entry), isNotNull));
    }
    for (final entry in [
      '*',
      'dev.example',
      '.example.test',
      'DEV.Example.',
      '[::1]',
      '10.0.0.5',
      'dev.example:8080',
    ]) {
      test('"$entry" is fine', () => expect(DevHosts.problem(entry), isNull));
    }
  });
}
