class Profile {
  final String id;
  final String name;
  final int age;
  final String gender;
  final List<String> interestedIn;
  final List<String> interests;
  final String bio;
  final List<String> photos;
  final double? latitude;
  final double? longitude;
  final bool isVerified;
  final bool isPremium;
  final bool incognitoMode;

  Profile({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.interestedIn,
    required this.interests,
    required this.bio,
    required this.photos,
    this.latitude,
    this.longitude,
    this.isVerified = false,
    this.isPremium = false,
    this.incognitoMode = false,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      gender: json['gender'] ?? '',
      interestedIn: List<String>.from(json['interested_in'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      bio: json['bio'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      latitude: (json['location'] != null && json['location']['coordinates'] != null)
          ? json['location']['coordinates'][1].toDouble()
          : null,
      longitude: (json['location'] != null && json['location']['coordinates'] != null)
          ? json['location']['coordinates'][0].toDouble()
          : null,
      isVerified: json['is_verified'] ?? false,
      isPremium: json['premium_until'] != null &&
          DateTime.parse(json['premium_until']).isAfter(DateTime.now()),
      incognitoMode: json['incognito_mode'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'interested_in': interestedIn,
      'interests': interests,
      'bio': bio,
      'photos': photos,
      'location': (latitude != null && longitude != null)
          ? 'POINT($longitude $latitude)'
          : null,
      'is_verified': isVerified,
      'incognito_mode': incognitoMode,
    };
  }
}