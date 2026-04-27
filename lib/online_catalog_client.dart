import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'text_encoding_repair.dart';

const supabaseProjectUrl = 'https://eqdofudwlylibxbehxvv.supabase.co';
const supabasePublishableKey = 'sb_publishable_K5efEqwWwW2WKZwCEUSzjw_wxg7i_St';

class OnlineCharacter {
  const OnlineCharacter({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.tags,
    required this.avatarUrl,
    required this.backgroundUrl,
    required this.authorName,
    required this.systemPrompt,
    required this.scenario,
    required this.firstMessage,
    required this.exampleDialogue,
    required this.downloads,
    required this.likes,
    required this.createdAt,
  });

  factory OnlineCharacter.fromJson(Map<String, dynamic> json) {
    return OnlineCharacter(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      name: repairTextEncoding(json['name'] as String? ?? 'Untitled'),
      description: repairTextEncoding(json['description'] as String? ?? ''),
      tags: repairTextListEncoding(
        (json['tags'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(),
      ),
      avatarUrl: json['avatar_url'] as String? ?? '',
      backgroundUrl: json['background_url'] as String? ?? '',
      authorName: repairTextEncoding(json['author_name'] as String? ?? ''),
      systemPrompt: repairTextEncoding(json['system_prompt'] as String? ?? ''),
      scenario: repairTextEncoding(json['scenario'] as String? ?? ''),
      firstMessage: repairTextEncoding(json['first_message'] as String? ?? ''),
      exampleDialogue: repairTextEncoding(
        json['example_dialogue'] as String? ?? '',
      ),
      downloads: json['downloads'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final List<String> tags;
  final String avatarUrl;
  final String backgroundUrl;
  final String authorName;
  final String systemPrompt;
  final String scenario;
  final String firstMessage;
  final String exampleDialogue;
  final int downloads;
  final int likes;
  final DateTime? createdAt;

  CharacterProfile toCharacterProfile() {
    final now = DateTime.now();
    return CharacterProfile(
      id: 'character_${now.microsecondsSinceEpoch}',
      name: name.trim(),
      userName: '',
      avatarPath: avatarUrl.trim(),
      backgroundPath: backgroundUrl.trim(),
      accentColorValue: ChatSettings.defaults.accentColorValue,
      systemPrompt: systemPrompt.trim(),
      scenario: scenario.trim(),
      firstMessage: firstMessage.trim(),
      exampleDialogue: exampleDialogue.trim(),
      memory: '',
      lore: '',
      createdAt: now,
      updatedAt: now,
    );
  }
}

class OnlineCatalogException implements Exception {
  const OnlineCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OnlineCatalogClient {
  OnlineCatalogClient({
    this.projectUrl = supabaseProjectUrl,
    this.publishableKey = supabasePublishableKey,
  });

  final String projectUrl;
  final String publishableKey;

  String get _normalizedProjectUrl => projectUrl.replaceAll(RegExp(r'/$'), '');

  Future<List<OnlineCharacter>> fetchCharacters({String query = ''}) async {
    try {
      return await _fetchCharacters(query: query, includeOwner: true);
    } on OnlineCatalogException catch (error) {
      final message = error.message.toLowerCase();
      if (!message.contains('owner_id') && !message.contains('42703')) {
        rethrow;
      }
      return _fetchCharacters(query: query, includeOwner: false);
    }
  }

  Future<List<OnlineCharacter>> _fetchCharacters({
    required String query,
    required bool includeOwner,
  }) async {
    final uri = Uri.parse('$_normalizedProjectUrl/rest/v1/characters').replace(
      queryParameters: {
        'select': [
          'id',
          if (includeOwner) 'owner_id',
          'name',
          'description',
          'tags',
          'avatar_url',
          'background_url',
          'author_name',
          'system_prompt',
          'scenario',
          'first_message',
          'example_dialogue',
          'downloads',
          'likes',
          'created_at',
        ].join(','),
        'order': 'created_at.desc',
        if (query.trim().isNotEmpty) 'name': 'ilike.*${query.trim()}*',
      },
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers
        ..set('apikey', publishableKey)
        ..set('Authorization', 'Bearer $publishableKey')
        ..set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OnlineCatalogException(
          'Catalog request failed (${response.statusCode}): $body',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! List<dynamic>) {
        throw const OnlineCatalogException('Catalog response is not a list.');
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(OnlineCharacter.fromJson)
          .where((character) => character.name.trim().isNotEmpty)
          .toList();
    } on SocketException catch (error) {
      throw OnlineCatalogException('Network error: ${error.message}');
    } on FormatException catch (error) {
      throw OnlineCatalogException(
        'Invalid catalog response: ${error.message}',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<CharacterProfile> publishCharacter(
    CharacterProfile profile, {
    required String description,
    required List<String> tags,
    required String accessToken,
    required String ownerId,
    required String authorName,
  }) async {
    final avatarUrl = await _tryPublicAssetUrl(
      profile.avatarPath,
      'avatars',
      accessToken: accessToken,
    );
    final backgroundUrl = await _tryPublicAssetUrl(
      profile.backgroundPath,
      'backgrounds',
      accessToken: accessToken,
    );
    final publicProfile = profile.copyWith(
      avatarPath: avatarUrl.isEmpty ? profile.avatarPath : avatarUrl,
      backgroundPath: backgroundUrl.isEmpty
          ? profile.backgroundPath
          : backgroundUrl,
    );

    final uri = Uri.parse('$_normalizedProjectUrl/rest/v1/characters');
    final resolvedAuthorName = publicProfile.userName.trim().isNotEmpty
        ? publicProfile.userName.trim()
        : authorName.trim();
    final body = jsonEncode({
      'owner_id': ownerId.trim(),
      'name': publicProfile.name.trim(),
      'description': description.trim(),
      'tags': tags,
      'avatar_url': avatarUrl,
      'background_url': backgroundUrl,
      'author_name': resolvedAuthorName,
      'system_prompt': publicProfile.systemPrompt.trim(),
      'scenario': publicProfile.scenario.trim(),
      'first_message': publicProfile.firstMessage.trim(),
      'example_dialogue': publicProfile.exampleDialogue.trim(),
    });

    final bodyBytes = utf8.encode(body);
    for (var attempt = 0; attempt < 3; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      try {
        final request = await client.postUrl(uri);
        request.contentLength = bodyBytes.length;
        request.headers
          ..set('apikey', publishableKey)
          ..set('Authorization', 'Bearer ${accessToken.trim()}')
          ..set(
            HttpHeaders.contentTypeHeader,
            'application/json; charset=utf-8',
          )
          ..set(HttpHeaders.acceptHeader, 'application/json')
          ..set('Prefer', 'return=minimal');
        request.add(bodyBytes);

        final response = await request.close().timeout(
          const Duration(seconds: 45),
        );
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw OnlineCatalogException(
            'Publish failed (${response.statusCode}): $responseBody',
          );
        }

        return publicProfile;
      } on SocketException catch (error) {
        if (attempt == 2) {
          throw OnlineCatalogException('Network error: ${error.message}');
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      } on HttpException catch (error) {
        if (attempt == 2) {
          throw OnlineCatalogException('Network error: ${error.message}');
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      } on TimeoutException catch (_) {
        if (attempt == 2) {
          throw const OnlineCatalogException(
            'Network error: request timed out',
          );
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      } finally {
        client.close(force: true);
      }
    }

    return publicProfile;
  }

  Future<OnlineCharacter> updateCharacter(
    OnlineCharacter character,
    CharacterProfile profile, {
    required String description,
    required List<String> tags,
    required String accessToken,
    required String authorName,
  }) async {
    final avatarUrl = await _tryPublicAssetUrl(
      profile.avatarPath,
      'avatars',
      accessToken: accessToken,
      fallbackUrl: character.avatarUrl,
    );
    final backgroundUrl = await _tryPublicAssetUrl(
      profile.backgroundPath,
      'backgrounds',
      accessToken: accessToken,
      fallbackUrl: character.backgroundUrl,
    );

    final resolvedAuthorName = profile.userName.trim().isNotEmpty
        ? profile.userName.trim()
        : authorName.trim();
    final body = jsonEncode({
      'name': profile.name.trim(),
      'description': description.trim(),
      'tags': tags,
      'avatar_url': avatarUrl,
      'background_url': backgroundUrl,
      'author_name': resolvedAuthorName,
      'system_prompt': profile.systemPrompt.trim(),
      'scenario': profile.scenario.trim(),
      'first_message': profile.firstMessage.trim(),
      'example_dialogue': profile.exampleDialogue.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    final uri = Uri.parse(
      '$_normalizedProjectUrl/rest/v1/characters',
    ).replace(queryParameters: {'id': 'eq.${character.id}'});

    final response = await _sendJsonWithRetry(
      uri: uri,
      method: 'PATCH',
      body: body,
      accessToken: accessToken,
      prefer: 'return=representation',
      errorPrefix: 'Update failed',
    );

    final decoded = jsonDecode(response);
    if (decoded is List<dynamic> && decoded.isNotEmpty) {
      final row = decoded.first;
      if (row is Map<String, dynamic>) {
        return OnlineCharacter.fromJson(row);
      }
    }

    throw const OnlineCatalogException('Update response is empty.');
  }

  Future<void> deleteCharacter({
    required String characterId,
    required String accessToken,
  }) async {
    final uri = Uri.parse(
      '$_normalizedProjectUrl/rest/v1/characters',
    ).replace(queryParameters: {'id': 'eq.${characterId.trim()}'});

    final client = HttpClient();
    try {
      final request = await client.deleteUrl(uri);
      request.headers
        ..set('apikey', publishableKey)
        ..set('Authorization', 'Bearer ${accessToken.trim()}')
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set('Prefer', 'return=representation');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OnlineCatalogException(
          'Delete failed (${response.statusCode}): $responseBody',
        );
      }

      if (responseBody.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is List<dynamic> && decoded.isEmpty) {
        throw const OnlineCatalogException(
          'Delete failed: item not found or not owned by this account.',
        );
      }
    } on SocketException catch (error) {
      throw OnlineCatalogException('Network error: ${error.message}');
    } on FormatException catch (error) {
      throw OnlineCatalogException('Invalid delete response: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _sendJsonWithRetry({
    required Uri uri,
    required String method,
    required String body,
    required String accessToken,
    required String prefer,
    required String errorPrefix,
  }) async {
    final bodyBytes = utf8.encode(body);
    for (var attempt = 0; attempt < 3; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      try {
        final request = await client.openUrl(method, uri);
        request.contentLength = bodyBytes.length;
        request.headers
          ..set('apikey', publishableKey)
          ..set('Authorization', 'Bearer ${accessToken.trim()}')
          ..set(
            HttpHeaders.contentTypeHeader,
            'application/json; charset=utf-8',
          )
          ..set(HttpHeaders.acceptHeader, 'application/json')
          ..set('Prefer', prefer);
        request.add(bodyBytes);

        final response = await request.close().timeout(
          const Duration(seconds: 45),
        );
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw OnlineCatalogException(
            '$errorPrefix (${response.statusCode}): $responseBody',
          );
        }
        return responseBody;
      } on SocketException catch (error) {
        if (attempt == 2) {
          throw OnlineCatalogException('Network error: ${error.message}');
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      } on HttpException catch (error) {
        if (attempt == 2) {
          throw OnlineCatalogException('Network error: ${error.message}');
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      } on TimeoutException catch (_) {
        if (attempt == 2) {
          throw const OnlineCatalogException(
            'Network error: request timed out',
          );
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      } finally {
        client.close(force: true);
      }
    }

    return '';
  }

  Future<String> _tryPublicAssetUrl(
    String rawPath,
    String folder, {
    required String accessToken,
    String fallbackUrl = '',
  }) async {
    final normalizedPath = rawPath.trim();
    if (normalizedPath.isEmpty) {
      return '';
    }
    if (_isHttpUrl(normalizedPath)) {
      return normalizedPath;
    }
    if (normalizedPath.startsWith('data:image/')) {
      return normalizedPath.length <= 30000 ? normalizedPath : fallbackUrl;
    }

    try {
      return await _publicAssetUrl(rawPath, folder, accessToken);
    } catch (_) {
      return fallbackUrl;
    }
  }

  Future<String> _publicAssetUrl(
    String rawPath,
    String folder,
    String accessToken,
  ) async {
    final normalizedPath = rawPath.trim();
    if (normalizedPath.isEmpty || _isHttpUrl(normalizedPath)) {
      return normalizedPath;
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      return '';
    }

    final extension = _extensionFor(file.path);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return '';
    }

    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}_${_safeName(file.uri.pathSegments.last)}$extension';
    final storagePath = '$folder/$fileName';
    final uri = Uri.parse(
      '$_normalizedProjectUrl/storage/v1/object/character-assets/${_encodeStoragePath(storagePath)}',
    );

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _uploadAssetBytes(uri, bytes, extension, accessToken);

        return '$_normalizedProjectUrl/storage/v1/object/public/character-assets/${_encodeStoragePath(storagePath)}';
      } on HttpException {
        if (attempt == 2) {
          rethrow;
        }
      } on SocketException {
        if (attempt == 2) {
          rethrow;
        }
      } on TimeoutException {
        if (attempt == 2) {
          rethrow;
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }

    return '';
  }

  Future<void> _uploadAssetBytes(
    Uri uri,
    List<int> bytes,
    String extension,
    String accessToken,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(uri);
      request.contentLength = bytes.length;
      request.headers
        ..set('apikey', publishableKey)
        ..set('Authorization', 'Bearer ${accessToken.trim()}')
        ..set(HttpHeaders.contentTypeHeader, _contentTypeFor(extension))
        ..set(HttpHeaders.cacheControlHeader, '3600')
        ..set('x-upsert', 'false');
      request.add(bytes);

      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OnlineCatalogException(
          'Asset upload failed (${response.statusCode}): $body',
        );
      }
    } finally {
      client.close(force: true);
    }
  }
}

bool _isHttpUrl(String rawValue) {
  final uri = Uri.tryParse(rawValue.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

String _encodeStoragePath(String value) {
  return value.split('/').map(Uri.encodeComponent).join('/');
}

String _extensionFor(String path) {
  final fileName = path.split(RegExp(r'[\\/]')).last;
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1) {
    return '.png';
  }
  final extension = fileName.substring(dotIndex).toLowerCase();
  return switch (extension) {
    '.jpg' || '.jpeg' || '.png' || '.webp' || '.gif' || '.bmp' => extension,
    _ => '.png',
  };
}

String _safeName(String value) {
  final dotIndex = value.lastIndexOf('.');
  final name = dotIndex == -1 ? value : value.substring(0, dotIndex);
  final normalized = name.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9_-]+'),
    '-',
  );
  return normalized
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String _contentTypeFor(String extension) {
  return switch (extension.toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.webp' => 'image/webp',
    '.gif' => 'image/gif',
    '.bmp' => 'image/bmp',
    _ => 'image/png',
  };
}
