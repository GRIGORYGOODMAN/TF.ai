import 'dart:ui';

import 'text_encoding_repair.dart';

enum MessageRole { user, assistant }

enum AiBackend { ollama, api }

enum AppLanguage { en, ru }

class UiSettings {
  const UiSettings({required this.fontFamily, required this.language});

  static const defaults = UiSettings(fontFamily: '', language: AppLanguage.en);

  factory UiSettings.fromJson(Map<String, dynamic> json) {
    return defaults.copyWith(
      fontFamily: json['fontFamily'] as String?,
      language: switch (json['language'] as String?) {
        'ru' => AppLanguage.ru,
        _ => AppLanguage.en,
      },
    );
  }

  final String fontFamily;
  final AppLanguage language;

  UiSettings copyWith({String? fontFamily, AppLanguage? language}) {
    return UiSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toJson() {
    return {'fontFamily': fontFamily, 'language': language.name};
  }
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      role: MessageRole.assistant,
      content: repairTextEncoding(content),
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.user(String content) {
    return ChatMessage(
      role: MessageRole.user,
      content: repairTextEncoding(content),
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleText = json['role'] as String? ?? 'assistant';
    return ChatMessage(
      role: roleText == 'user' ? MessageRole.user : MessageRole.assistant,
      content: repairTextEncoding(json['content'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final MessageRole role;
  final String content;
  final DateTime createdAt;

  Map<String, String> toOllamaMessage() {
    return {
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'content': content,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    required this.userName,
    required this.avatarPath,
    required this.backgroundPath,
    required this.accentColorValue,
    required this.systemPrompt,
    required this.scenario,
    required this.firstMessage,
    required this.exampleDialogue,
    required this.memory,
    required this.lore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CharacterProfile.blank({String? id}) {
    final now = DateTime.now();
    return CharacterProfile(
      id: id ?? _newId('character'),
      name: '',
      userName: '',
      avatarPath: '',
      backgroundPath: '',
      accentColorValue: ChatSettings.defaults.accentColorValue,
      systemPrompt: '',
      scenario: '',
      firstMessage: '',
      exampleDialogue: '',
      memory: '',
      lore: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory CharacterProfile.fromSettings(
    ChatSettings settings, {
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return CharacterProfile(
      id: id ?? _newId('character'),
      name: settings.characterName,
      userName: settings.userName,
      avatarPath: settings.avatarPath,
      backgroundPath: settings.backgroundPath,
      accentColorValue: settings.accentColorValue,
      systemPrompt: settings.systemPrompt,
      scenario: settings.scenario,
      firstMessage: settings.firstMessage,
      exampleDialogue: settings.exampleDialogue,
      memory: settings.memory,
      lore: settings.lore,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  factory CharacterProfile.fromJson(Map<String, dynamic> json) {
    final defaults = CharacterProfile.blank(id: 'blank_character');
    return defaults.copyWith(
      id: json['id'] as String?,
      name: repairTextEncoding(json['name'] as String? ?? defaults.name),
      userName: repairTextEncoding(
        json['userName'] as String? ?? defaults.userName,
      ),
      avatarPath: json['avatarPath'] as String?,
      backgroundPath: json['backgroundPath'] as String?,
      accentColorValue: json['accentColorValue'] as int?,
      systemPrompt: repairTextEncoding(
        json['systemPrompt'] as String? ?? defaults.systemPrompt,
      ),
      scenario: repairTextEncoding(
        json['scenario'] as String? ?? defaults.scenario,
      ),
      firstMessage: repairTextEncoding(
        json['firstMessage'] as String? ?? defaults.firstMessage,
      ),
      exampleDialogue: repairTextEncoding(
        json['exampleDialogue'] as String? ?? defaults.exampleDialogue,
      ),
      memory: repairTextEncoding(json['memory'] as String? ?? defaults.memory),
      lore: repairTextEncoding(json['lore'] as String? ?? defaults.lore),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  final String id;
  final String name;
  final String userName;
  final String avatarPath;
  final String backgroundPath;
  final int accentColorValue;
  final String systemPrompt;
  final String scenario;
  final String firstMessage;
  final String exampleDialogue;
  final String memory;
  final String lore;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => name.trim().isEmpty ? 'Untitled' : name.trim();

  ChatSettings applyTo(ChatSettings settings) {
    return settings.copyWith(
      characterName: name,
      userName: userName,
      avatarPath: avatarPath,
      backgroundPath: backgroundPath,
      accentColorValue: accentColorValue,
      systemPrompt: systemPrompt,
      scenario: scenario,
      firstMessage: firstMessage,
      exampleDialogue: exampleDialogue,
      memory: memory,
      lore: lore,
    );
  }

  CharacterProfile copyWith({
    String? id,
    String? name,
    String? userName,
    String? avatarPath,
    String? backgroundPath,
    int? accentColorValue,
    String? systemPrompt,
    String? scenario,
    String? firstMessage,
    String? exampleDialogue,
    String? memory,
    String? lore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CharacterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      userName: userName ?? this.userName,
      avatarPath: avatarPath ?? this.avatarPath,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      scenario: scenario ?? this.scenario,
      firstMessage: firstMessage ?? this.firstMessage,
      exampleDialogue: exampleDialogue ?? this.exampleDialogue,
      memory: memory ?? this.memory,
      lore: lore ?? this.lore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'userName': userName,
      'avatarPath': avatarPath,
      'backgroundPath': backgroundPath,
      'accentColorValue': accentColorValue,
      'systemPrompt': systemPrompt,
      'scenario': scenario,
      'firstMessage': firstMessage,
      'exampleDialogue': exampleDialogue,
      'memory': memory,
      'lore': lore,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ChatSession {
  const ChatSession({
    required this.id,
    required this.characterId,
    required this.title,
    required this.messages,
    required this.autoMemory,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.empty(CharacterProfile character) {
    final now = DateTime.now();
    final firstMessage = character.firstMessage.trim();
    return ChatSession(
      id: _newId('chat'),
      characterId: character.id,
      title: 'New chat',
      messages: firstMessage.isEmpty
          ? <ChatMessage>[]
          : <ChatMessage>[ChatMessage.assistant(firstMessage)],
      autoMemory: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final messages = (json['messages'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .where((message) => message.content.trim().isNotEmpty)
        .toList();

    return ChatSession(
      id: json['id'] as String? ?? _newId('chat'),
      characterId: json['characterId'] as String? ?? '',
      title: repairTextEncoding(json['title'] as String? ?? 'New chat'),
      messages: messages,
      autoMemory: repairTextEncoding(json['autoMemory'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }

  final String id;
  final String characterId;
  final String title;
  final List<ChatMessage> messages;
  final String autoMemory;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle => title.trim().isEmpty ? 'New chat' : title.trim();

  String get preview {
    if (messages.isEmpty) {
      return 'No messages yet';
    }
    return messages.last.content;
  }

  int get userMessageCount =>
      messages.where((message) => message.role == MessageRole.user).length;

  int get assistantMessageCount =>
      messages.where((message) => message.role == MessageRole.assistant).length;

  ChatSession copyWith({
    String? id,
    String? characterId,
    String? title,
    List<ChatMessage>? messages,
    String? autoMemory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      autoMemory: autoMemory ?? this.autoMemory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'characterId': characterId,
      'title': title,
      'messages': messages.map((message) => message.toJson()).toList(),
      'autoMemory': autoMemory,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class AppState {
  const AppState({
    required this.settings,
    required this.uiSettings,
    required this.characters,
    required this.selectedCharacterId,
    required this.chats,
    required this.activeChatId,
  });

  final ChatSettings settings;
  final UiSettings uiSettings;
  final List<CharacterProfile> characters;
  final String selectedCharacterId;
  final List<ChatSession> chats;
  final String activeChatId;

  Map<String, dynamic> toJson() {
    return {
      'settings': settings.toJson(),
      'uiSettings': uiSettings.toJson(),
      'characters': characters.map((character) => character.toJson()).toList(),
      'selectedCharacterId': selectedCharacterId,
      'chats': chats.map((chat) => chat.toJson()).toList(),
      'activeChatId': activeChatId,
    };
  }
}

class ChatSettings {
  const ChatSettings({
    required this.backend,
    required this.host,
    required this.mobileHost,
    required this.useMobileHost,
    required this.model,
    required this.apiBaseUrl,
    required this.apiKey,
    required this.apiModel,
    required this.temperature,
    required this.contextSize,
    required this.maxTokens,
    required this.characterName,
    required this.userName,
    required this.avatarPath,
    required this.backgroundPath,
    required this.accentColorValue,
    required this.systemPrompt,
    required this.scenario,
    required this.firstMessage,
    required this.exampleDialogue,
    required this.memory,
    required this.lore,
  });

  static const defaultSystemPrompt = '';

  static const defaultScenario = '';

  static const defaultFirstMessage = '';

  static const defaultExampleDialogue = '';

  static const defaults = ChatSettings(
    backend: AiBackend.ollama,
    host: 'http://localhost:11434',
    mobileHost: 'http://192.168.1.34:11434',
    useMobileHost: false,
    model: 'huihui_ai/qwen3.5-abliterated:9b-q8_0',
    apiBaseUrl: 'https://api.openai.com/v1',
    apiKey: '',
    apiModel: 'gpt-4.1-mini',
    temperature: 0.78,
    contextSize: 8192,
    maxTokens: 450,
    characterName: '',
    userName: '',
    avatarPath: '',
    backgroundPath: '',
    accentColorValue: 0xffb14c70,
    systemPrompt: defaultSystemPrompt,
    scenario: defaultScenario,
    firstMessage: defaultFirstMessage,
    exampleDialogue: defaultExampleDialogue,
    memory: '',
    lore: '',
  );

  factory ChatSettings.fromJson(Map<String, dynamic> json) {
    final defaults = ChatSettings.defaults;
    final loaded = defaults.copyWith(
      backend: _backendFromJson(json['backend'] as String?),
      host: json['host'] as String?,
      mobileHost: json['mobileHost'] as String?,
      useMobileHost: json['useMobileHost'] as bool?,
      model: json['model'] as String?,
      apiBaseUrl: json['apiBaseUrl'] as String?,
      apiKey: json['apiKey'] as String?,
      apiModel: json['apiModel'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      contextSize: json['contextSize'] as int?,
      maxTokens: json['maxTokens'] as int?,
      characterName: repairTextEncoding(
        json['characterName'] as String? ?? defaults.characterName,
      ),
      userName: repairTextEncoding(
        json['userName'] as String? ?? defaults.userName,
      ),
      avatarPath: json['avatarPath'] as String?,
      backgroundPath: json['backgroundPath'] as String?,
      accentColorValue: json['accentColorValue'] as int?,
      systemPrompt: repairTextEncoding(
        json['systemPrompt'] as String? ?? defaults.systemPrompt,
      ),
      scenario: repairTextEncoding(
        json['scenario'] as String? ?? defaults.scenario,
      ),
      firstMessage: repairTextEncoding(
        json['firstMessage'] as String? ?? defaults.firstMessage,
      ),
      exampleDialogue: repairTextEncoding(
        json['exampleDialogue'] as String? ?? defaults.exampleDialogue,
      ),
      memory: repairTextEncoding(json['memory'] as String? ?? defaults.memory),
      lore: repairTextEncoding(json['lore'] as String? ?? defaults.lore),
    );

    return loaded;
  }

  static AiBackend _backendFromJson(String? value) {
    return switch (value) {
      'api' => AiBackend.api,
      _ => AiBackend.ollama,
    };
  }

  final AiBackend backend;
  final String host;
  final String mobileHost;
  final bool useMobileHost;
  final String model;
  final String apiBaseUrl;
  final String apiKey;
  final String apiModel;
  final double temperature;
  final int contextSize;
  final int maxTokens;
  final String characterName;
  final String userName;
  final String avatarPath;
  final String backgroundPath;
  final int accentColorValue;
  final String systemPrompt;
  final String scenario;
  final String firstMessage;
  final String exampleDialogue;
  final String memory;
  final String lore;

  String get activeHost => useMobileHost ? mobileHost : host;

  String get activeModel {
    if (backend == AiBackend.api) {
      final trimmedApiModel = apiModel.trim();
      return trimmedApiModel.isEmpty ? model.trim() : trimmedApiModel;
    }
    return model.trim();
  }

  String get activeEndpoint {
    return backend == AiBackend.api ? apiBaseUrl.trim() : activeHost.trim();
  }

  String get backendLabel {
    return backend == AiBackend.api
        ? 'API'
        : useMobileHost
        ? 'Phone'
        : 'PC';
  }

  Color get accentColor => Color(accentColorValue);

  ChatSettings copyWith({
    AiBackend? backend,
    String? host,
    String? mobileHost,
    bool? useMobileHost,
    String? model,
    String? apiBaseUrl,
    String? apiKey,
    String? apiModel,
    double? temperature,
    int? contextSize,
    int? maxTokens,
    String? characterName,
    String? userName,
    String? avatarPath,
    String? backgroundPath,
    int? accentColorValue,
    String? systemPrompt,
    String? scenario,
    String? firstMessage,
    String? exampleDialogue,
    String? memory,
    String? lore,
  }) {
    return ChatSettings(
      backend: backend ?? this.backend,
      host: host ?? this.host,
      mobileHost: mobileHost ?? this.mobileHost,
      useMobileHost: useMobileHost ?? this.useMobileHost,
      model: model ?? this.model,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiModel: apiModel ?? this.apiModel,
      temperature: temperature ?? this.temperature,
      contextSize: contextSize ?? this.contextSize,
      maxTokens: maxTokens ?? this.maxTokens,
      characterName: characterName ?? this.characterName,
      userName: userName ?? this.userName,
      avatarPath: avatarPath ?? this.avatarPath,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      scenario: scenario ?? this.scenario,
      firstMessage: firstMessage ?? this.firstMessage,
      exampleDialogue: exampleDialogue ?? this.exampleDialogue,
      memory: memory ?? this.memory,
      lore: lore ?? this.lore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backend': backend.name,
      'host': host,
      'mobileHost': mobileHost,
      'useMobileHost': useMobileHost,
      'model': model,
      'apiBaseUrl': apiBaseUrl,
      'apiKey': apiKey,
      'apiModel': apiModel,
      'temperature': temperature,
      'contextSize': contextSize,
      'maxTokens': maxTokens,
      'characterName': characterName,
      'userName': userName,
      'avatarPath': avatarPath,
      'backgroundPath': backgroundPath,
      'accentColorValue': accentColorValue,
      'systemPrompt': systemPrompt,
      'scenario': scenario,
      'firstMessage': firstMessage,
      'exampleDialogue': exampleDialogue,
      'memory': memory,
      'lore': lore,
    };
  }

  String buildSystemPrompt({String autoMemory = ''}) {
    final sections = <String>[systemPrompt.trim()];

    if (characterName.trim().isNotEmpty) {
      sections.add('Character name: ${characterName.trim()}');
    }
    if (userName.trim().isNotEmpty) {
      sections.add('User name: ${userName.trim()}');
    }
    if (scenario.trim().isNotEmpty) {
      sections.add('Current scenario:\n${scenario.trim()}');
    }
    if (memory.trim().isNotEmpty) {
      sections.add('Persistent memory:\n${memory.trim()}');
    }
    if (autoMemory.trim().isNotEmpty) {
      sections.add('Current chat memory summary:\n${autoMemory.trim()}');
    }
    if (lore.trim().isNotEmpty) {
      sections.add('Lore and world facts:\n${lore.trim()}');
    }
    if (exampleDialogue.trim().isNotEmpty) {
      sections.add('Example dialogue:\n${exampleDialogue.trim()}');
    }

    return sections.where((section) => section.trim().isNotEmpty).join('\n\n');
  }
}

String _newId(String prefix) {
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
}
