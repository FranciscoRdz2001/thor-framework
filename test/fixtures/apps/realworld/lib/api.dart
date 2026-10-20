/// The RealWorld (Conduit) REST API, called from the server.
library;

import 'dart:async';

import 'package:thor_server/thor_server.dart';

import 'env.dart';

/// A signed-in user (what the session cookie carries).
class User {
  /// A user.
  const User({
    required this.username,
    required this.email,
    required this.token,
    this.bio,
    this.image,
  });

  /// From the API's `user` object.
  factory User.fromJson(Map<String, Object?> json) => User(
    username: json['username']! as String,
    email: json['email']! as String,
    token: json['token']! as String,
    bio: json['bio'] as String?,
    image: json['image'] as String?,
  );

  /// Username.
  final String username;

  /// Email.
  final String email;

  /// API token.
  final String token;

  /// Bio (`null` when empty).
  final String? bio;

  /// Avatar URL (`null` when empty).
  final String? image;

  /// For the session cookie.
  Map<String, Object?> toJson() => {
    'username': username,
    'email': email,
    'token': token,
    'bio': bio,
    'image': image,
  };
}

/// An author as another user sees them.
class Profile {
  /// From the API's `profile` / `author` object.
  Profile.fromJson(Map<String, Object?> json)
    : username = json['username']! as String,
      bio = json['bio'] as String?,
      image = json['image'] as String?,
      following = json['following'] == true;

  /// Username.
  final String username;

  /// Bio.
  final String? bio;

  /// Avatar URL.
  final String? image;

  /// Whether the viewer follows them.
  final bool following;
}

/// An article (the list omits [body]).
class Article {
  /// From the API's `article` object.
  Article.fromJson(Map<String, Object?> json)
    : slug = json['slug']! as String,
      title = json['title']! as String,
      description = json['description'] as String? ?? '',
      body = json['body'] as String? ?? '',
      tagList = [...(json['tagList'] as List? ?? const []).cast<String>()],
      createdAt = parseIsoDateTime(json['createdAt']! as String),
      favorited = json['favorited'] == true,
      favoritesCount = json['favoritesCount'] as int? ?? 0,
      author = Profile.fromJson(json['author']! as Map<String, Object?>);

  /// URL key.
  final String slug;

  /// Title.
  final String title;

  /// One-line summary.
  final String description;

  /// Markdown body.
  final String body;

  /// Tags, in order.
  final List<String> tagList;

  /// Publication date.
  final DateTime createdAt;

  /// Whether the viewer favorited it.
  final bool favorited;

  /// Favorites.
  final int favoritesCount;

  /// Its author.
  final Profile author;
}

/// A comment on an article.
class Comment {
  /// From the API's `comment` object.
  Comment.fromJson(Map<String, Object?> json)
    : id = json['id']! as int,
      body = json['body']! as String,
      createdAt = parseIsoDateTime(json['createdAt']! as String),
      author = Profile.fromJson(json['author']! as Map<String, Object?>);

  /// Id.
  final int id;

  /// Text (plain; shown escaped).
  final String body;

  /// When it was posted.
  final DateTime createdAt;

  /// Who wrote it.
  final Profile author;
}

/// A page of articles.
typedef ArticlePage = ({List<Article> articles, int count});

/// Validation errors from the API (`{"errors": {"email": ["is invalid"]}}`).
class ApiErrors implements Exception {
  /// Errors by field.
  const ApiErrors(this.status, this.errors);

  /// HTTP status (401, 403, 409, 422…).
  final int status;

  /// Field → messages.
  final Map<String, List<String>> errors;

  /// "email is invalid", one per message.
  List<String> get messages => [
    for (final e in errors.entries)
      for (final m in e.value) '${e.key} $m',
  ];
}

/// Articles per page (like the reference).
const pageSize = 10;

/// The API client.
class ConduitApi {
  /// Talks to [base] (`REALWORLD_API`).
  ConduitApi(this.base);

  /// API root (`…/api`).
  final String base;

  // Idle sockets close before the API's keep-alive (4 s < Node's 5 s); a
  // GET on a socket closed under it is retried once, nothing else is.
  final _client = ThorHttpClient(
    maxConnectionsPerHost: 64,
    headers: const {HttpHeader.accept: 'application/json'},
  );

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final response = await _client.send(
      HttpMethod.tryParse(method)!,
      '$base/$path',
      headers: {if (token != null) HttpHeader.authorization: 'Token $token'},
      json: body,
    );
    final json = response.json() as Map<String, Object?>? ?? {};
    if (response.statusCode < 300) return json;
    if (json['errors'] case final Map<String, Object?> errors) {
      final byField = {
        for (final e in errors.entries)
          e.key: [...(e.value as List? ?? const []).map((m) => '$m')],
      };
      // A missing article or profile is the page's 404.
      if (response.statusCode == StatusCode.notFound) throw const NotFound();
      throw ApiErrors(response.statusCode, byField);
    }
    throw HttpError(response.statusCode == StatusCode.notFound ? 404 : 502);
  }

  /// Signs in; throws [ApiErrors] on bad credentials.
  Future<User> login(String email, String password) async => User.fromJson(
    (await _send(
          'POST',
          'users/login',
          body: {
            'user': {'email': email, 'password': password},
          },
        ))['user']!
        as Map<String, Object?>,
  );

  /// Creates an account.
  Future<User> register(String username, String email, String password) async =>
      User.fromJson(
        (await _send(
              'POST',
              'users',
              body: {
                'user': {
                  'username': username,
                  'email': email,
                  'password': password,
                },
              },
            ))['user']!
            as Map<String, Object?>,
      );

  /// Updates the signed-in user ([changes] as the API takes them).
  Future<User> updateUser(String token, Map<String, Object?> changes) async =>
      User.fromJson(
        (await _send(
              'PUT',
              'user',
              body: {'user': changes},
              token: token,
            ))['user']!
            as Map<String, Object?>,
      );

  /// A page of articles: [feed] = followed authors only; filters by
  /// [tag], [author] or [favorited].
  Future<ArticlePage> articles({
    String? token,
    bool feed = false,
    int page = 1,
    String? tag,
    String? author,
    String? favorited,
  }) async {
    final query = Uri(
      queryParameters: {
        'limit': '$pageSize',
        'offset': '${(page - 1) * pageSize}',
        'tag': ?tag,
        'author': ?author,
        'favorited': ?favorited,
      },
    ).query;
    final json = await _send(
      'GET',
      '${feed ? 'articles/feed' : 'articles'}?$query',
      token: token,
    );
    return (
      articles: [
        for (final a in json['articles']! as List)
          Article.fromJson(a as Map<String, Object?>),
      ],
      count: json['articlesCount']! as int,
    );
  }

  /// Popular tags.
  Future<List<String>> tags() async => [
    ...((await _send('GET', 'tags'))['tags']! as List).cast<String>(),
  ];

  /// One article (404 → `NotFound`).
  Future<Article> article(String slug, {String? token}) async =>
      Article.fromJson(
        (await _send(
              'GET',
              'articles/${Uri.encodeComponent(slug)}',
              token: token,
            ))['article']!
            as Map<String, Object?>,
      );

  /// Its comments, newest first.
  Future<List<Comment>> comments(String slug, {String? token}) async => [
    for (final c
        in (await _send(
              'GET',
              'articles/${Uri.encodeComponent(slug)}/comments',
              token: token,
            ))['comments']!
            as List)
      Comment.fromJson(c as Map<String, Object?>),
  ];

  /// A user's profile (404 → `NotFound`).
  Future<Profile> profile(String username, {String? token}) async =>
      Profile.fromJson(
        (await _send(
              'GET',
              'profiles/${Uri.encodeComponent(username)}',
              token: token,
            ))['profile']!
            as Map<String, Object?>,
      );

  /// Creates an article; returns its slug.
  Future<String> createArticle(
    String token,
    Map<String, Object?> article,
  ) async =>
      ((await _send(
                'POST',
                'articles',
                body: {'article': article},
                token: token,
              ))['article']!
              as Map<String, Object?>)['slug']!
          as String;

  /// Updates an article; returns its slug.
  Future<String> updateArticle(
    String token,
    String slug,
    Map<String, Object?> article,
  ) async =>
      ((await _send(
                'PUT',
                'articles/${Uri.encodeComponent(slug)}',
                body: {'article': article},
                token: token,
              ))['article']!
              as Map<String, Object?>)['slug']!
          as String;

  /// Deletes an article.
  Future<void> deleteArticle(String token, String slug) =>
      _send('DELETE', 'articles/${Uri.encodeComponent(slug)}', token: token);

  /// Posts a comment.
  Future<void> addComment(String token, String slug, String body) => _send(
    'POST',
    'articles/${Uri.encodeComponent(slug)}/comments',
    body: {
      'comment': {'body': body},
    },
    token: token,
  );

  /// Deletes a comment.
  Future<void> deleteComment(String token, String slug, String id) => _send(
    'DELETE',
    'articles/${Uri.encodeComponent(slug)}/comments/${Uri.encodeComponent(id)}',
    token: token,
  );

  /// Favorites (or, with [on] false, unfavorites) an article.
  Future<void> favorite(String token, String slug, {required bool on}) => _send(
    on ? 'POST' : 'DELETE',
    'articles/${Uri.encodeComponent(slug)}/favorite',
    token: token,
  );

  /// Follows (or unfollows) a user.
  Future<void> follow(String token, String username, {required bool on}) =>
      _send(
        on ? 'POST' : 'DELETE',
        'profiles/${Uri.encodeComponent(username)}/follow',
        token: token,
      );
}

/// The app's client.
final api = ConduitApi('${env.of(RealworldEnv.api)}');
