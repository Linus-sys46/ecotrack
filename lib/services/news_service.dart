import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NewsArticle {
  final String title;
  final String source;
  final String url;
  final String? description;
  final DateTime? publishedAt;

  NewsArticle({
    required this.title,
    required this.source,
    required this.url,
    this.description,
    this.publishedAt,
  });
}

class NewsService {
  /// Fetches recent climate / emissions related news.
  ///
  /// By default this is wired for NewsAPI-style endpoints, but the
  /// base URL and API key are read from `.env` so you can swap
  /// in any climate-specific provider you prefer.
  Future<List<NewsArticle>> fetchNews() async {
    final apiKey = dotenv.env['NEWS_API_KEY'];
    final baseUrl =
        dotenv.env['NEWS_API_BASE_URL'] ?? 'https://newsapi.org/v2/everything';

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'NEWS_API_KEY is not configured. Add it to your .env file.',
      );
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'q': 'greenhouse gas OR carbon emissions OR climate change',
      'language': 'en',
      'sortBy': 'publishedAt',
      'pageSize': '20',
      'apiKey': apiKey,
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load news (status ${response.statusCode}).',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final articles = data['articles'] as List<dynamic>? ?? [];

    return articles
        .map((raw) {
          final map = raw as Map<String, dynamic>;
          return NewsArticle(
            title: map['title'] ?? 'Untitled',
            source: (map['source']?['name'] ?? 'Unknown') as String,
            url: map['url'] ?? '',
            description: map['description'],
            publishedAt: map['publishedAt'] != null
                ? DateTime.tryParse(map['publishedAt'])
                : null,
          );
        })
        .where((article) => article.url.isNotEmpty)
        .toList();
  }
}

