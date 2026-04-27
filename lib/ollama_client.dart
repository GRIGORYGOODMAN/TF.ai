import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

class OllamaCancelToken {
  HttpClient? _client;
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void attach(HttpClient client) {
    if (_isCancelled) {
      client.close(force: true);
      return;
    }
    _client = client;
  }

  void cancel() {
    _isCancelled = true;
    _client?.close(force: true);
  }
}

class OllamaProbeResult {
  const OllamaProbeResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}

class OllamaClient {
  OllamaClient(this.settings, {this.autoMemory = ''});

  final ChatSettings settings;
  final String autoMemory;

  Future<String> send(
    List<ChatMessage> history, {
    OllamaCancelToken? cancelToken,
    String? instruction,
  }) async {
    if (settings.backend == AiBackend.api) {
      return _sendApi(
        history,
        cancelToken: cancelToken,
        instruction: instruction,
      );
    }

    return _sendOllama(
      history,
      cancelToken: cancelToken,
      instruction: instruction,
    );
  }

  Future<OllamaProbeResult> probe() async {
    if (settings.backend == AiBackend.api) {
      return _probeApi();
    }
    return _probeOllama();
  }

  Future<String> summarizeMemory(
    List<ChatMessage> history, {
    String existingMemory = '',
    OllamaCancelToken? cancelToken,
  }) async {
    final usableHistory = history
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    final recentHistory = usableHistory.length > 80
        ? usableHistory.sublist(usableHistory.length - 80)
        : usableHistory;
    final transcript = recentHistory
        .map((message) {
          final role = message.role == MessageRole.user ? 'User' : 'Character';
          return '$role: ${message.content.trim()}';
        })
        .join('\n\n');

    if (transcript.trim().isEmpty) {
      throw const OllamaException('No chat messages to summarize.');
    }

    final memorySettings = settings.copyWith(
      characterName: 'Memory Writer',
      userName: '',
      systemPrompt:
          'You update durable chat memory for a private character chat app. Return only concise memory notes. Keep stable facts, preferences, relationship changes, and unresolved threads. Remove small talk, filler, and temporary emotions unless they matter later.',
      scenario: '',
      exampleDialogue: '',
      memory: '',
      lore: '',
      temperature: 0.2,
      maxTokens: 650,
    );
    final prompt =
        '''
Existing chat memory:
${existingMemory.trim().isEmpty ? 'None yet.' : existingMemory.trim()}

New transcript:
$transcript

Write the updated memory. Use short bullets. Preserve names and important wording. If nothing important should be remembered, return "No durable memory yet.".
''';

    return OllamaClient(
      memorySettings,
    ).send([ChatMessage.user(prompt)], cancelToken: cancelToken);
  }

  Future<String> _sendOllama(
    List<ChatMessage> history, {
    OllamaCancelToken? cancelToken,
    String? instruction,
  }) async {
    final uri = Uri.parse(_joinUrl(settings.activeHost, '/api/chat'));
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    cancelToken?.attach(client);

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(_ollamaChatBody(history, instruction: instruction)),
      );

      final response = await request.close().timeout(
        const Duration(minutes: 4),
      );
      final body = await response.transform(utf8.decoder).join();

      if (cancelToken?.isCancelled ?? false) {
        throw const OllamaException('Generation stopped.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OllamaException('Ollama returned ${response.statusCode}: $body');
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final content = _extractContent(decoded);

      if (content == null || content.trim().isEmpty) {
        throw OllamaException(_emptyResponseMessage(decoded));
      }

      return _visibleAssistantContent(content).trim();
    } on SocketException catch (error) {
      if (cancelToken?.isCancelled ?? false) {
        throw const OllamaException('Generation stopped.');
      }
      throw OllamaException('Could not connect to Ollama: ${error.message}');
    } on TimeoutException {
      throw const OllamaException(
        'The model is taking too long to respond. Try a smaller context.',
      );
    } on FormatException {
      throw const OllamaException(
        'Ollama returned an unexpected response format.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _sendApi(
    List<ChatMessage> history, {
    OllamaCancelToken? cancelToken,
    String? instruction,
  }) async {
    final model = settings.activeModel;
    if (model.isEmpty) {
      throw const OllamaException('API model is empty.');
    }
    if (settings.apiBaseUrl.trim().isEmpty) {
      throw const OllamaException('API base URL is empty.');
    }

    final uri = Uri.parse(_joinUrl(settings.apiBaseUrl, '/chat/completions'));
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    cancelToken?.attach(client);

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      final apiKey = settings.apiKey.trim();
      if (apiKey.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
      request.write(
        jsonEncode(_apiChatBody(history, instruction: instruction)),
      );

      final response = await request.close().timeout(
        const Duration(minutes: 4),
      );
      final body = await response.transform(utf8.decoder).join();

      if (cancelToken?.isCancelled ?? false) {
        throw const OllamaException('Generation stopped.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OllamaException(
          'API returned ${response.statusCode}: ${_extractErrorMessage(body)}',
        );
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final content = _extractContent(decoded);

      if (content == null || content.trim().isEmpty) {
        throw OllamaException(_emptyResponseMessage(decoded));
      }

      return _visibleAssistantContent(content).trim();
    } on SocketException catch (error) {
      if (cancelToken?.isCancelled ?? false) {
        throw const OllamaException('Generation stopped.');
      }
      throw OllamaException('Could not connect to API: ${error.message}');
    } on TimeoutException {
      throw const OllamaException(
        'The API is taking too long to respond. Try fewer max tokens.',
      );
    } on FormatException {
      throw const OllamaException(
        'API returned an unexpected response format.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<OllamaProbeResult> _probeOllama() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

    try {
      final versionUri = Uri.parse(
        _joinUrl(settings.activeHost, '/api/version'),
      );
      final versionRequest = await client.getUrl(versionUri);
      final versionResponse = await versionRequest.close().timeout(
        const Duration(seconds: 10),
      );
      final versionBody = await versionResponse.transform(utf8.decoder).join();

      if (versionResponse.statusCode < 200 ||
          versionResponse.statusCode >= 300) {
        return OllamaProbeResult(
          ok: false,
          message:
              'Ollama returned ${versionResponse.statusCode}: $versionBody',
        );
      }

      final tagsUri = Uri.parse(_joinUrl(settings.activeHost, '/api/tags'));
      final tagsRequest = await client.getUrl(tagsUri);
      final tagsResponse = await tagsRequest.close().timeout(
        const Duration(seconds: 10),
      );
      final tagsBody = await tagsResponse.transform(utf8.decoder).join();
      final modelExists = _tagsContainModel(tagsBody, settings.model);

      if (!modelExists) {
        return OllamaProbeResult(
          ok: false,
          message:
              'Ollama is reachable, but model "${settings.model}" was not found. Download it with ollama pull.',
        );
      }

      return const OllamaProbeResult(
        ok: true,
        message: 'Connection works, model found.',
      );
    } on SocketException catch (error) {
      return OllamaProbeResult(
        ok: false,
        message: 'No connection to Ollama: ${error.message}',
      );
    } on TimeoutException {
      return const OllamaProbeResult(
        ok: false,
        message: 'Ollama did not respond in time.',
      );
    } on FormatException {
      return const OllamaProbeResult(
        ok: false,
        message: 'Ollama returned an unexpected response format.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<OllamaProbeResult> _probeApi() async {
    final model = settings.activeModel;
    if (model.isEmpty) {
      return const OllamaProbeResult(ok: false, message: 'API model is empty.');
    }
    if (settings.apiBaseUrl.trim().isEmpty) {
      return const OllamaProbeResult(
        ok: false,
        message: 'API base URL is empty.',
      );
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

    try {
      final uri = Uri.parse(_joinUrl(settings.apiBaseUrl, '/models'));
      final request = await client.getUrl(uri);
      final apiKey = settings.apiKey.trim();
      if (apiKey.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }

      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 401 || response.statusCode == 403) {
        return OllamaProbeResult(
          ok: false,
          message:
              'API rejected the request. Check the key: ${_extractErrorMessage(body)}',
        );
      }

      if (response.statusCode == 404 || response.statusCode == 405) {
        return const OllamaProbeResult(
          ok: true,
          message:
              'API is reachable, but /models is not available. Chat may still work if /chat/completions is supported.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return OllamaProbeResult(
          ok: false,
          message:
              'API returned ${response.statusCode}: ${_extractErrorMessage(body)}',
        );
      }

      final modelExists = _modelsContainModel(body, model);
      if (modelExists == false) {
        return OllamaProbeResult(
          ok: true,
          message:
              'API connection works. Model "$model" was not listed, but the provider may still accept it.',
        );
      }

      return const OllamaProbeResult(
        ok: true,
        message: 'API connection works.',
      );
    } on SocketException catch (error) {
      return OllamaProbeResult(
        ok: false,
        message: 'No connection to API: ${error.message}',
      );
    } on TimeoutException {
      return const OllamaProbeResult(
        ok: false,
        message: 'API did not respond in time.',
      );
    } on FormatException {
      return const OllamaProbeResult(
        ok: false,
        message: 'API URL is invalid or returned unexpected data.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _ollamaChatBody(
    List<ChatMessage> history, {
    String? instruction,
  }) {
    final oneShotInstruction = instruction?.trim();
    return {
      'model': settings.model,
      'stream': false,
      'think': false,
      'messages': _messages(history, oneShotInstruction),
      'options': {
        'temperature': settings.temperature,
        'top_p': 0.95,
        'repeat_penalty': 1.08,
        'num_ctx': settings.contextSize,
        'num_predict': settings.maxTokens,
      },
    };
  }

  Map<String, dynamic> _apiChatBody(
    List<ChatMessage> history, {
    String? instruction,
  }) {
    final oneShotInstruction = instruction?.trim();
    final body = <String, dynamic>{
      'model': settings.activeModel,
      'messages': _messages(history, oneShotInstruction),
      'temperature': settings.temperature,
      'max_tokens': settings.maxTokens,
    };

    if (_isOpenRouterEndpoint(settings.apiBaseUrl)) {
      body['reasoning'] = {'exclude': true};
    }

    return body;
  }

  List<Map<String, String>> _messages(
    List<ChatMessage> history,
    String? oneShotInstruction,
  ) {
    return [
      {
        'role': 'system',
        'content': settings.buildSystemPrompt(autoMemory: autoMemory),
      },
      {'role': 'system', 'content': _finalAnswerOnlyInstruction},
      if (oneShotInstruction != null && oneShotInstruction.isNotEmpty)
        {
          'role': 'system',
          'content':
              'One-time generation instruction for the next assistant reply only:\n$oneShotInstruction',
        },
      ...history.map((message) => message.toOllamaMessage()),
    ];
  }

  bool _tagsContainModel(String tagsBody, String modelName) {
    final decoded = jsonDecode(tagsBody) as Map<String, dynamic>;
    final models = decoded['models'];
    if (models is! List) {
      return false;
    }

    return models.whereType<Map<String, dynamic>>().any((model) {
      final name = model['name'];
      final modelId = model['model'];
      return name == modelName || modelId == modelName;
    });
  }

  bool? _modelsContainModel(String body, String modelName) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final data = decoded['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().any((model) {
        final id = model['id'];
        return id == modelName;
      });
    }

    final models = decoded['models'];
    if (models is List) {
      return models.whereType<Map<String, dynamic>>().any((model) {
        final id = model['id'];
        final name = model['name'];
        final modelId = model['model'];
        return id == modelName || name == modelName || modelId == modelName;
      });
    }

    return null;
  }

  String _visibleAssistantContent(String rawContent) {
    final original = rawContent.trim();
    var text = original;

    text = text
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<thinking>[\s\S]*?</thinking>', caseSensitive: false),
          '',
        )
        .trim();

    final markerExtracted = _extractAfterFinalMarker(text);
    if (markerExtracted != null) {
      return markerExtracted;
    }

    final quotedDraft = _extractQuotedDraft(text);
    if (quotedDraft != null) {
      return quotedDraft;
    }

    return text.trim().isEmpty ? original : text.trim();
  }

  String? _extractAfterFinalMarker(String text) {
    const markers = [
      'Final answer:',
      'Final response:',
      'Answer:',
      'Ответ:',
      'Итоговый ответ:',
      'Финальный ответ:',
    ];
    var markerIndex = -1;
    var markerLength = 0;
    for (final marker in markers) {
      final index = text.toLowerCase().lastIndexOf(marker.toLowerCase());
      if (index > markerIndex) {
        markerIndex = index;
        markerLength = marker.length;
      }
    }

    if (markerIndex < 0) {
      return null;
    }

    final result = text.substring(markerIndex + markerLength).trim();
    return result.isEmpty ? null : _stripWrappingQuotes(result);
  }

  String? _extractQuotedDraft(String text) {
    final hasDraftMarker =
        text.contains('Примерный ответ') ||
        text.contains('Возможный ответ') ||
        text.toLowerCase().contains('draft answer') ||
        text.toLowerCase().contains('sample answer');
    if (!hasDraftMarker) {
      return null;
    }

    final matches = RegExp(
      r'["“«]([^"”»]{12,})["”»]',
      multiLine: true,
    ).allMatches(text).toList();
    if (matches.isEmpty) {
      return null;
    }

    final result = matches.last.group(1)?.trim();
    return result == null || result.isEmpty ? null : result;
  }

  String _stripWrappingQuotes(String text) {
    var result = text.trim();
    while (result.length >= 2) {
      final first = result[0];
      final last = result[result.length - 1];
      final wraps =
          (first == '"' && last == '"') ||
          (first == '“' && last == '”') ||
          (first == '«' && last == '»');
      if (!wraps) {
        break;
      }
      result = result.substring(1, result.length - 1).trim();
    }
    return result;
  }

  String? _extractContent(Map<String, dynamic> decoded) {
    final message = decoded['message'];
    if (message is Map<String, dynamic>) {
      final content = message['content'];
      if (content is String && content.trim().isNotEmpty) {
        return content;
      }
    }

    final response = decoded['response'];
    if (response is String && response.trim().isNotEmpty) {
      return response;
    }

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final choiceMessage = first['message'];
        if (choiceMessage is Map<String, dynamic>) {
          final content = choiceMessage['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content;
          }
        }
      }
    }

    return null;
  }

  String _emptyResponseMessage(Map<String, dynamic> decoded) {
    final message = decoded['message'];
    final thinkingOnly =
        message is Map<String, dynamic> &&
        message['thinking'] is String &&
        (message['thinking'] as String).trim().isNotEmpty;
    final doneReason = decoded['done_reason'];

    if (thinkingOnly) {
      return 'The model returned thinking only, without text. Restart the app and try again.';
    }

    if (doneReason is String && doneReason.isNotEmpty) {
      return 'Empty model response. Ollama reason: $doneReason.';
    }

    return 'Empty model response.';
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      // Fall through to a compact raw body.
    }

    final trimmed = body.trim();
    if (trimmed.length <= 700) {
      return trimmed.isEmpty ? 'empty error body' : trimmed;
    }
    return '${trimmed.substring(0, 700)}...';
  }

  String _joinUrl(String host, String path) {
    final normalizedHost = host.endsWith('/')
        ? host.substring(0, host.length - 1)
        : host;
    return '$normalizedHost$path';
  }

  bool _isOpenRouterEndpoint(String baseUrl) {
    return Uri.tryParse(baseUrl.trim())?.host.toLowerCase() == 'openrouter.ai';
  }
}

const _finalAnswerOnlyInstruction =
    'Response format: write only the final message that should be shown in the chat. Do not reveal analysis, chain-of-thought, planning, self-checks, draft notes, or prompt interpretation. Do not write phrases like "I will think", "Need to answer", "Draft answer", "Примерный ответ", or "Сначала подумаю". If reasoning is needed, keep it internal.';

class OllamaException implements Exception {
  const OllamaException(this.message);

  final String message;

  @override
  String toString() => message;
}
