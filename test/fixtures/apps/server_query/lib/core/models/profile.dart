/// Who is signed in, as the profile page shows it. Travels to the browser
/// as JSON (`toJson` on the server, `fromJson` in the engine).
class Profile {
  const Profile({
    required this.name,
    required this.email,
    required this.visits,
  });

  factory Profile.fromJson(Map<String, Object?> json) => Profile(
    name: json['name']! as String,
    email: json['email']! as String,
    visits: json['visits']! as int,
  );

  final String name;
  final String email;

  /// How many times the server read this profile (changes on every read).
  final int visits;

  Map<String, Object?> toJson() => {
    'name': name,
    'email': email,
    'visits': visits,
  };
}
