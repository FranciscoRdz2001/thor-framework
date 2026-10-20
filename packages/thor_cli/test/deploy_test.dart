// `thor deploy init`: which target fits which app, and what each writes.
// The Docker image itself is built and run in CI's deploy job.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

late Directory _tmp;

/// A project at [rel] under the temp folder, with its pubspec and [files].
Project _project(
  String rel, {
  String dependency = '  thor_ui:\n    path: ../../packages/thor_ui\n',
  bool workspace = false,
  String thor = '',
  Map<String, String> files = const {},
}) {
  final dir = p.join(_tmp.path, rel);
  Directory(dir).createSync(recursive: true);
  File(p.join(dir, 'pubspec.yaml')).writeAsStringSync(
    'name: ${p.basename(dir)}\n'
    '${workspace ? 'resolution: workspace\n' : ''}'
    'environment:\n  sdk: ^3.8.0\n'
    'dependencies:\n$dependency'
    '$thor',
  );
  for (final MapEntry(key: path, value: content) in files.entries) {
    File(p.join(dir, path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }
  return Project(dir);
}

/// A thor-like monorepo: root workspace with packages/thor_cli.
void _monorepo() {
  File(
    p.join(_tmp.path, 'pubspec.yaml'),
  ).writeAsStringSync('name: root\nworkspace:\n  - apps/shop\n');
  File(p.join(_tmp.path, 'packages/thor_cli/pubspec.yaml'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('name: thor_cli\n');
  Directory(p.join(_tmp.path, 'packages/thor_ui')).createSync();
}

TypeMatcher<ThorException> _code(String code) =>
    isA<ThorException>().having((e) => e.message, 'message', contains(code));

void main() {
  setUp(() => _tmp = Directory.systemTemp.createTempSync('thor_deploy'));
  tearDown(() => _tmp.deleteSync(recursive: true));

  group('targets', () {
    test('every target parses by its id', () {
      for (final target in DeployTarget.values) {
        expect(DeployTarget.parse(target.id), target);
      }
    });

    test('a serverless host is THOR-B017 with what to use instead', () {
      for (final id in ['cloudflare-workers', 'vercel-functions', 'lambda']) {
        expect(
          () => DeployTarget.parse(id),
          throwsA(
            _code(
              'THOR-B017',
            ).having((e) => e.message, 'message', contains('container')),
          ),
        );
      }
    });

    test('an unknown target lists the ones there are', () {
      expect(
        () => DeployTarget.parse('heroku'),
        throwsA(
          isA<ThorException>().having(
            (e) => e.message,
            'message',
            allOf(contains('docker'), contains('netlify')),
          ),
        ),
      );
    });

    test('a server target for a static site is THOR-B017', () {
      final site = _project('site', files: {'lib/main.server.dart': ''});
      expect(
        () => planDeploy(site, DeployTarget.fly),
        throwsA(_code('THOR-B017')),
      );
    });

    test('a static target for a server without export is THOR-B017', () {
      final app = _project('app', files: {'bin/server.dart': ''});
      expect(
        () => planDeploy(app, DeployTarget.vercel),
        throwsA(_code('THOR-B017')),
      );
    });

    test('a server that also exports can go to a static host', () {
      final app = _project(
        'app',
        files: {'bin/server.dart': '', 'bin/export.dart': ''},
      );
      final plan = planDeploy(app, DeployTarget.netlify);
      expect(plan.files['deploy/build.sh'], contains('thor export'));
    });
  });

  group('a server image', () {
    test('in a monorepo: built from the root, thor from its checkout', () {
      _monorepo();
      final shop = _project(
        'apps/shop',
        workspace: true,
        files: {'bin/server.dart': ''},
      );
      final plan = planDeploy(shop, DeployTarget.docker, dartImage: '3.12');
      final docker = plan.files['Dockerfile']!;
      expect(docker, contains('FROM dart:3.12 AS build'));
      expect(
        docker,
        contains('dart pub global activate --source path packages/thor_cli'),
      );
      expect(docker, contains('WORKDIR /src/apps/shop'));
      expect(docker, contains('RUN dart pub global run thor_cli:thor build'));
      // Only what runs: the executable, its public files, the manifest.
      expect(docker, contains('FROM scratch'));
      expect(docker, contains('COPY --from=build /runtime/ /'));
      expect(docker, contains('build/images.json'));
      expect(docker, contains('USER 65532:65532'));
      expect(docker, contains('HEALTHCHECK'));
      expect(docker, contains('STOPSIGNAL SIGTERM'));
      expect(docker, isNot(contains('apt-get')));
      expect(
        plan.steps.first,
        'docker build -f apps/shop/Dockerfile -t shop .',
      );
      expect(plan.files['Dockerfile.dockerignore'], contains('**/build'));
      expect(
        plan.files['deploy/healthcheck.dart'],
        contains("'/_thor/health'"),
      );
    });

    test('the image sets the GC flag for more than four isolates', () {
      _monorepo();
      final shop = _project(
        'apps/shop',
        workspace: true,
        files: {'bin/server.dart': ''},
      );
      final docker = planDeploy(shop, DeployTarget.docker).files['Dockerfile']!;
      expect(
        docker,
        contains('ENV DART_VM_OPTIONS=--new_gen_semi_max_size=256'),
      );
      // In the final stage: that is the image that runs.
      expect(
        docker.indexOf('DART_VM_OPTIONS'),
        greaterThan(docker.indexOf('FROM scratch')),
      );
    });

    test('the launcher sets the flag unless the user already did', () {
      expect(serverGcFlag, '--new_gen_semi_max_size=256');
      expect(serverLauncher(), startsWith('#!/bin/sh'));
      expect(serverLauncher(), contains(serverGcFlag));
      final app = _project('app', files: {'bin/server.dart': ''});
      final path = writeServerLauncher(app);
      expect(path, app.path('build/run.sh'));
      if (Platform.isWindows) return;
      // A fake server that prints what the VM would read.
      File(
        app.path('build/server'),
      ).writeAsStringSync('#!/bin/sh\necho "\$DART_VM_OPTIONS"\n');
      Process.runSync('chmod', ['+x', app.path('build/server')]);
      String run(Map<String, String> env) =>
          (Process.runSync(
                    path,
                    const [],
                    environment: env,
                    includeParentEnvironment: false,
                  ).stdout
                  as String)
              .trim();
      expect(run({}), serverGcFlag);
      expect(
        run({'DART_VM_OPTIONS': '--old_gen_growth_rate=2'}),
        '--old_gen_growth_rate=2 $serverGcFlag',
      );
      expect(
        run({'DART_VM_OPTIONS': '--new_gen_semi_max_size=64'}),
        '--new_gen_semi_max_size=64',
      );
      // Started through a symlink elsewhere (a link in PATH), it still finds
      // build/server next to the real script.
      final bin = Directory(p.join(_tmp.path, 'bin'))..createSync();
      final link = Link(p.join(bin.path, 'app-server'))..createSync(path);
      final viaLink =
          Process.runSync(
                link.path,
                const [],
                environment: const {},
                includeParentEnvironment: false,
                workingDirectory: '/',
              ).stdout
              as String;
      expect(viaLink.trim(), serverGcFlag);
    });

    test('a new app ships the Dockerfile when thor comes from git', () {
      final dir = p.join(_tmp.path, 'shop');
      final written = writeApp(
        dir,
        'shop',
        source: const GitSource('https://example.com/thor.git'),
      );
      expect(written, contains(p.relative(p.join(dir, 'Dockerfile'))));
      final docker = File(p.join(dir, 'Dockerfile')).readAsStringSync();
      expect(docker, contains('DART_VM_OPTIONS=--new_gen_semi_max_size=256'));
      expect(docker, contains('dart pub global activate --source git'));
      expect(File(p.join(dir, 'deploy/healthcheck.dart')).existsSync(), isTrue);
    });

    test('a new app on a local checkout outside the build gets none', () {
      final dir = p.join(_tmp.path, 'shop');
      final written = writeApp(
        dir,
        'shop',
        source: const LocalSource('/elsewhere'),
      );
      expect(written.any((f) => f.endsWith('Dockerfile')), isFalse);
    });

    test('its own repository: thor from the git url and ref', () {
      final shop = _project(
        'shop',
        dependency:
            '  thor_ui:\n    git:\n      url: https://example.com/thor.git\n'
            '      ref: v1\n      path: packages/thor_ui\n',
        files: {'bin/server.dart': ''},
      );
      final docker = planDeploy(shop, DeployTarget.docker).files['Dockerfile']!;
      expect(
        docker,
        contains(
          'dart pub global activate --source git https://example.com/thor.git '
          '--git-path packages/thor_cli --git-ref v1',
        ),
      );
      expect(docker, contains('WORKDIR /src\n'));
      expect(docker, contains('COPY --from=build /src/build/server'));
    });

    test('declared resources go into the final image', () {
      final shop = _project(
        'shop',
        dependency:
            '  thor_ui:\n    git:\n      url: https://example.com/thor.git\n'
            '      path: packages/thor_ui\n',
        thor: 'thor:\n  sdk: true\n',
        files: {'bin/server.dart': ''},
      );
      final docker = planDeploy(shop, DeployTarget.docker).files['Dockerfile']!;
      expect(
        docker,
        contains('COPY --from=build /src/build/resources build/resources\n'),
      );
      final plain = _project(
        'plain',
        dependency:
            '  thor_ui:\n    git:\n      url: https://example.com/thor.git\n'
            '      path: packages/thor_ui\n',
        files: {'bin/server.dart': ''},
      );
      expect(
        planDeploy(plain, DeployTarget.docker).files['Dockerfile'],
        isNot(contains('build/resources')),
      );
    });

    test('thor_ui from a path outside the build is THOR-B017', () {
      final shop = _project(
        'shop',
        dependency: '  thor_ui:\n    path: ../../elsewhere/packages/thor_ui\n',
        files: {'bin/server.dart': ''},
      );
      expect(
        () => planDeploy(shop, DeployTarget.docker),
        throwsA(_code('THOR-B017')),
      );
    });

    test('images and AVIF install their encoders in the build stage', () {
      _monorepo();
      final shop = _project(
        'apps/shop',
        workspace: true,
        thor: 'thor:\n  images:\n    formats: [webp, avif]\n',
        files: {'bin/server.dart': ''},
      );
      final docker = planDeploy(shop, DeployTarget.docker).files['Dockerfile']!;
      expect(docker, contains('apt-get install -y --no-install-recommends'));
      expect(docker, contains('webp imagemagick'));
    });

    test('the env schema names secrets and settings, never PORT', () {
      _monorepo();
      final shop = _project(
        'apps/shop',
        workspace: true,
        files: {
          'bin/server.dart': '',
          'lib/env.dart': '''
static const port = EnvInt('PORT', fallback: 8080);
static const api = EnvUrl('API_URL');
static const secret = EnvOptional(EnvSecret('SESSION_SECRET', minLength: 32));
''',
        },
      );
      expect(envVars(shop).map((v) => v.name), [
        'PORT',
        'API_URL',
        'SESSION_SECRET',
      ]);
      final fly = planDeploy(shop, DeployTarget.fly);
      final toml = fly.files['fly.toml']!;
      expect(toml, contains('fly secrets set SESSION_SECRET=…'));
      expect(toml, contains('# API_URL = "…"'));
      expect(toml, contains('path = "/_thor/health"'));
      expect(toml, isNot(contains('# PORT')));
      expect(fly.steps.last, isNot(contains('PORT')));
      final render = planDeploy(
        shop,
        DeployTarget.render,
      ).files['render.yaml']!;
      expect(render, contains('key: API_URL'));
      expect(render, isNot(contains('key: PORT')));
      expect(render, contains('healthCheckPath: /_thor/health'));
    });

    test('railway points at the Dockerfile and the health path', () {
      _monorepo();
      final shop = _project(
        'apps/shop',
        workspace: true,
        files: {'bin/server.dart': ''},
      );
      final json =
          jsonDecode(
                planDeploy(shop, DeployTarget.railway).files['railway.json']!,
              )
              as Map<String, Object?>;
      expect((json['build']! as Map)['dockerfilePath'], 'apps/shop/Dockerfile');
      expect((json['deploy']! as Map)['healthcheckPath'], '/_thor/health');
    });
  });

  group('a static site', () {
    test('vercel: hashed files and _thor forever, pages revalidate', () {
      final site = _project('site', files: {'lib/main.server.dart': ''});
      final plan = planDeploy(site, DeployTarget.vercel);
      final json =
          jsonDecode(plan.files['deploy/vercel.json']!) as Map<String, Object?>;
      final rules = <String, String>{
        for (final rule
            in (json['headers']! as List).cast<Map<String, Object?>>())
          rule['source']! as String:
              ((rule['headers']! as List).single
                      as Map<String, Object?>)['value']!
                  as String,
      };
      expect(rules['/(.*)'], 'no-cache');
      expect(rules['/_thor/(.*)'], contains('immutable'));
      final hashed = RegExp(
        '^${rules.keys.firstWhere((k) => k.contains('0-9a-f'))}\$',
      );
      expect(hashed.hasMatch('/engine.dart.3f9a1c2e.js'), isTrue);
      expect(hashed.hasMatch('/pricing.html'), isFalse);
      expect(plan.files['deploy/build.sh'], contains('thor build'));
      expect(plan.files['deploy/build.sh'], contains('cp deploy/vercel.json'));
      expect(plan.steps.last, 'vercel deploy build/site --prod');
    });

    test('an exported site is not fingerprinted twice (export does it)', () {
      final site = _project('site', files: {'bin/export.dart': ''});
      final build = planDeploy(
        site,
        DeployTarget.cloudflarePages,
      ).files['deploy/build.sh']!;
      expect(build, contains('thor export'));
      expect(build, isNot(contains('thor_engine:fingerprint')));
    });

    test('netlify and cloudflare publish build/site', () {
      final site = _project('site', files: {'lib/main.server.dart': ''});
      expect(
        planDeploy(site, DeployTarget.netlify).files['netlify.toml'],
        contains('publish = "build/site"'),
      );
      expect(
        planDeploy(site, DeployTarget.cloudflarePages).files['wrangler.toml'],
        contains('pages_build_output_dir = "build/site"'),
      );
    });
  });

  group('writing', () {
    test('files that exist stay unless --force', () {
      final site = _project(
        'site',
        files: {'lib/main.server.dart': '', 'netlify.toml': 'mine'},
      );
      final plan = planDeploy(site, DeployTarget.netlify);
      expect(
        () => writeDeployPlan(site, plan),
        throwsA(
          isA<ThorException>().having(
            (e) => e.message,
            'message',
            contains('netlify.toml'),
          ),
        ),
      );
      expect(File(site.path('netlify.toml')).readAsStringSync(), 'mine');
      expect(File(site.path('deploy/build.sh')).existsSync(), isFalse);
      writeDeployPlan(site, plan, force: true);
      expect(
        File(site.path('netlify.toml')).readAsStringSync(),
        contains('build/site'),
      );
    });

    test('the build script is executable', () {
      final site = _project('site', files: {'lib/main.server.dart': ''});
      writeDeployPlan(site, planDeploy(site, DeployTarget.vercel));
      final mode = File(site.path('deploy/build.sh')).statSync().modeString();
      expect(mode, startsWith('rwx'));
    }, testOn: '!windows');
  });
}
