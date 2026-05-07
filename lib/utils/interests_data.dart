class InterestsData {
  static const List<String> allInterests = [
    'Travel', 'Coffee', 'Music', 'Art', 'Photography',
    'Hiking', 'Cooking', 'Reading', 'Gaming', 'Yoga',
    'Nightlife', 'Architecture', 'Jazz', 'Vinyl', 'Cinema',
    'Fashion', 'Fitness', 'Swimming', 'Dancing', 'Nature',
    'Technology', 'Science', 'History', 'Politics', 'Business',
    'Entrepreneurship', 'Startups', 'Coding', 'Design', 'Marketing',
    'Writing', 'Poetry', 'Philosophy', 'Psychology', 'Sociology',
    'Sustainability', 'Environment', 'Gardening', 'Pets', 'Dogs',
    'Cats', 'Horses', 'Wildlife', 'Astronomy', 'Space',
    'Meditation', 'Mindfulness', 'Spirituality', 'Astrology', 'Tarot',
    'Cuisine', 'Baking', 'Wine', 'Beer', 'Craft Beer',
    'Spirits', 'Cocktails', 'Coffee Roasting', 'Tea', 'Veganism',
    'Vegetarianism', 'Fitness Training', 'Running', 'Cycling', 'Triathlon',
    'Surfing', 'Skateboarding', 'Snowboarding', 'Skiing', 'Mountain Biking',
    'Climbing', 'Bouldering', 'Tennis', 'Padel', 'Golf',
    'Football', 'Basketball', 'Baseball', 'Hockey', 'Cricket',
    'Rugby', 'Boxing', 'Martial Arts', 'MMA', 'Wrestling',
    'Anime', 'Manga', 'Comics', 'Graphic Novels', 'Board Games',
    'Chess', 'Card Games', 'Magic', 'Cosplay', 'D&D',
    'Roleplaying', 'Thrifting', 'Vintage', 'Sneakers', 'Streetwear',
    'Minimalism', 'Interior Design', 'DIY', 'Crafting', 'Knitting',
    'Pottery', 'Painting', 'Drawing', 'Sculpting', 'Calligraphy',
    'Musicals', 'Theater', 'Opera', 'Ballet', 'Classical Music',
    'Rock', 'Pop', 'Hip Hop', 'R&B', 'Electronic Music',
    'Techno', 'House Music', 'Indie', 'Alternative', 'Country Music',
    'Blues', 'Soul', 'Reggae', 'Salsa', 'Tango',
    'Self-Care', 'Skincare', 'Beauty', 'Wellness', 'Nutrition',
    'Podcasts', 'Audiobooks', 'Documentaries', 'True Crime', 'Sci-Fi',
    'Fantasy', 'Mystery', 'Horror', 'Romance', 'Comedy',
    'Stand-up Comedy', 'Improv', 'Festivals', 'Concerts', 'Museums',
    'Galleries', 'Volunteering', 'Charity', 'Social Justice', 'Human Rights',
    'Languages', 'Cultural Exchange', 'Road Trips', 'Backpacking', 'Solo Travel',
    'Luxury Travel', 'Camping', 'Glamping', 'Fishing', 'Sailing',
  ];

  static List<String> getRandomInterests(int count) {
    final List<String> shuffled = List.from(allInterests)..shuffle();
    return shuffled.take(count).toList();
  }
}
