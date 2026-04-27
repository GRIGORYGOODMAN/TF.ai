import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppStorage {
  static const _appStateKey = 'tf_ai.app.v1';

  Future<AppState> loadAppState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appStateKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final state = _decodeAppState(decoded);
        if (_isRetiredSeedState(state)) {
          return _defaultState(state.settings, state.uiSettings);
        }
        final normalized = _normalizeState(state);
        await prefs.setString(_appStateKey, jsonEncode(normalized.toJson()));
        return normalized;
      } catch (_) {
        return _defaultState();
      }
    }

    return _defaultState();
  }

  Future<void> saveAppState(AppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _appStateKey,
      jsonEncode(_normalizeState(state).toJson()),
    );
  }

  Future<ChatSettings> loadSettings() async {
    return (await loadAppState()).settings;
  }

  Future<List<ChatMessage>> loadMessages(ChatSettings settings) async {
    return (await loadAppState()).chats.first.messages;
  }

  Future<void> saveSettings(ChatSettings settings) async {
    final state = await loadAppState();
    await saveAppState(
      AppState(
        settings: settings,
        uiSettings: state.uiSettings,
        characters: state.characters,
        selectedCharacterId: state.selectedCharacterId,
        chats: state.chats,
        activeChatId: state.activeChatId,
      ),
    );
  }

  Future<void> saveMessages(List<ChatMessage> messages) async {
    final state = await loadAppState();
    final activeChatId = state.activeChatId;
    final chats = state.chats.map((chat) {
      if (chat.id != activeChatId) {
        return chat;
      }
      return chat.copyWith(messages: messages, updatedAt: DateTime.now());
    }).toList();

    await saveAppState(
      AppState(
        settings: state.settings,
        uiSettings: state.uiSettings,
        characters: state.characters,
        selectedCharacterId: state.selectedCharacterId,
        chats: chats,
        activeChatId: state.activeChatId,
      ),
    );
  }

  AppState _decodeAppState(Map<String, dynamic> json) {
    final settingsJson = json['settings'];
    final settings = settingsJson is Map<String, dynamic>
        ? ChatSettings.fromJson(settingsJson)
        : ChatSettings.defaults;

    final uiSettingsJson = json['uiSettings'];
    final uiSettings = uiSettingsJson is Map<String, dynamic>
        ? UiSettings.fromJson(uiSettingsJson)
        : UiSettings.defaults;

    final characters = (json['characters'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CharacterProfile.fromJson)
        .where((character) => character.id.trim().isNotEmpty)
        .toList();

    final chats = (json['chats'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChatSession.fromJson)
        .where((chat) => chat.id.trim().isNotEmpty)
        .toList();

    return AppState(
      settings: settings,
      uiSettings: uiSettings,
      characters: characters,
      selectedCharacterId: json['selectedCharacterId'] as String? ?? '',
      chats: chats,
      activeChatId: json['activeChatId'] as String? ?? '',
    );
  }

  AppState _defaultState([ChatSettings? settings, UiSettings? uiSettings]) {
    return AppState(
      settings: _settingsWithoutCharacter(settings ?? ChatSettings.defaults),
      uiSettings: uiSettings ?? UiSettings.defaults,
      characters: const [],
      selectedCharacterId: '',
      chats: const [],
      activeChatId: '',
    );
  }

  AppState _normalizeState(AppState state) {
    final characters = state.characters;

    if (characters.isEmpty) {
      return _defaultState(state.settings, state.uiSettings);
    }

    var selectedCharacterId = state.selectedCharacterId;
    if (!characters.any((character) => character.id == selectedCharacterId)) {
      selectedCharacterId = characters.first.id;
    }

    var chats = state.chats
        .where(
          (chat) =>
              characters.any((character) => character.id == chat.characterId),
        )
        .toList();

    final selectedCharacter = characters.firstWhere(
      (character) => character.id == selectedCharacterId,
      orElse: () => characters.first,
    );

    if (chats.isEmpty) {
      chats = [ChatSession.empty(selectedCharacter)];
    }

    var activeChatId = state.activeChatId;
    if (!chats.any((chat) => chat.id == activeChatId)) {
      final selectedCharacterChats = chats
          .where((chat) => chat.characterId == selectedCharacterId)
          .toList();
      activeChatId = selectedCharacterChats.isEmpty
          ? chats.first.id
          : selectedCharacterChats.first.id;
    }

    final activeChat = chats.firstWhere(
      (chat) => chat.id == activeChatId,
      orElse: () => chats.first,
    );

    selectedCharacterId = activeChat.characterId;
    final activeCharacter = characters.firstWhere(
      (character) => character.id == selectedCharacterId,
      orElse: () => characters.first,
    );

    return AppState(
      settings: activeCharacter.applyTo(state.settings),
      uiSettings: state.uiSettings,
      characters: characters,
      selectedCharacterId: selectedCharacterId,
      chats: chats,
      activeChatId: activeChat.id,
    );
  }

  bool _isRetiredSeedState(AppState state) {
    if (state.characters.length != 1) {
      return false;
    }

    final character = state.characters.single;
    if (character.id != 'default_character') {
      return false;
    }

    return !state.chats.any(
      (chat) =>
          chat.messages.any((message) => message.role == MessageRole.user),
    );
  }

  ChatSettings _settingsWithoutCharacter(ChatSettings settings) {
    return ChatSettings.defaults.copyWith(
      backend: settings.backend,
      host: settings.host,
      mobileHost: settings.mobileHost,
      useMobileHost: settings.useMobileHost,
      model: settings.model,
      apiBaseUrl: settings.apiBaseUrl,
      apiKey: settings.apiKey,
      apiModel: settings.apiModel,
      temperature: settings.temperature,
      contextSize: settings.contextSize,
      maxTokens: settings.maxTokens,
    );
  }
}
