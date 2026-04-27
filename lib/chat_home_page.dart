import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_client.dart';
import 'models.dart';
import 'ollama_client.dart';
import 'online_catalog_client.dart';
import 'storage.dart';

enum _EditorSection { characters, chats, aiSettings, appSettings, account }

class _ProviderPreset {
  const _ProviderPreset({
    required this.label,
    required this.icon,
    required this.backend,
    this.host,
    this.mobileHost,
    this.useMobileHost,
    this.apiBaseUrl,
    this.apiModel,
  });

  final String label;
  final IconData icon;
  final AiBackend backend;
  final String? host;
  final String? mobileHost;
  final bool? useMobileHost;
  final String? apiBaseUrl;
  final String? apiModel;
}

const _providerPresets = [
  _ProviderPreset(
    label: 'Ollama PC',
    icon: Icons.computer,
    backend: AiBackend.ollama,
    host: 'http://localhost:11434',
    useMobileHost: false,
  ),
  _ProviderPreset(
    label: 'Ollama phone',
    icon: Icons.phone_android,
    backend: AiBackend.ollama,
    mobileHost: 'http://192.168.1.34:11434',
    useMobileHost: true,
  ),
  _ProviderPreset(
    label: 'LM Studio',
    icon: Icons.developer_board_outlined,
    backend: AiBackend.api,
    apiBaseUrl: 'http://localhost:1234/v1',
    apiModel: 'local-model',
  ),
  _ProviderPreset(
    label: 'OpenAI',
    icon: Icons.cloud_outlined,
    backend: AiBackend.api,
    apiBaseUrl: 'https://api.openai.com/v1',
    apiModel: 'gpt-4.1-mini',
  ),
  _ProviderPreset(
    label: 'OpenRouter',
    icon: Icons.hub_outlined,
    backend: AiBackend.api,
    apiBaseUrl: 'https://openrouter.ai/api/v1',
    apiModel: 'openai/gpt-4.1-mini',
  ),
];

extension _LocalizedBuildContext on BuildContext {
  String tr(String value) {
    return _AppTextScope.maybeOf(this)?.text(value) ?? value;
  }
}

class _AppTextScope extends InheritedWidget {
  const _AppTextScope({required this.language, required super.child});

  final AppLanguage language;

  static _AppTextScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AppTextScope>();
  }

  String text(String value) {
    if (language != AppLanguage.ru) {
      return value;
    }
    return _ruText[value] ?? value;
  }

  @override
  bool updateShouldNotify(_AppTextScope oldWidget) {
    return language != oldWidget.language;
  }
}

const _ruText = {
  'Characters': 'Персонажи',
  'Chats': 'Чаты',
  'AI Settings': 'ИИ',
  'App Settings': 'Настройки',
  'Account': 'Аккаунт',
  'Library': 'Библиотека',
  'Profile': 'Профиль',
  'Prompt': 'Промпт',
  'Memory': 'Память',
  'New character': 'Новый персонаж',
  'Online catalog': 'Онлайн-каталог',
  'Start new chat': 'Новый чат',
  'Clear current chat': 'Очистить чат',
  'No chats yet': 'Чатов пока нет',
  'Start a chat for this character.': 'Начни чат с этим персонажем.',
  'Duplicate': 'Дублировать',
  'Delete': 'Удалить',
  'Rename': 'Переименовать',
  'Sign in': 'Войти',
  'Sign out': 'Выйти',
  'Create': 'Создать',
  'Email': 'Почта',
  'Password': 'Пароль',
  'Signed in': 'Вход выполнен',
  'Connection': 'Подключение',
  'Generation': 'Генерация',
  'Debug': 'Отладка',
  'API base URL': 'Адрес API',
  'API model': 'Модель API',
  'API key': 'Ключ API',
  'Phone / local network': 'Телефон / локальная сеть',
  'PC address': 'Адрес ПК',
  'Phone address': 'Адрес телефона',
  'Ollama model': 'Модель Ollama',
  'Test': 'Проверить',
  'Save': 'Сохранить',
  'Local Ollama': 'Локальная Ollama',
  'View final prompt': 'Показать итоговый промпт',
  'Save before debug': 'Сохранить перед отладкой',
  'Character name': 'Имя персонажа',
  'Your name': 'Твоё имя',
  'Avatar': 'Аватар',
  'Background': 'Фон',
  'Save profile': 'Сохранить профиль',
  'Character prompt': 'Промпт персонажа',
  'Scenario': 'Сценарий',
  'Example dialogue': 'Пример диалога',
  'Save character': 'Сохранить персонажа',
  'Persistent memory': 'Постоянная память',
  'Auto chat memory': 'Автопамять чата',
  'Summarize current chat': 'Суммировать текущий чат',
  'Save memory': 'Сохранить память',
  'Temperature': 'Температура',
  'Context': 'Контекст',
  'Max tokens': 'Макс. токены',
  'Save generation': 'Сохранить генерацию',
  'Private': 'Приватный',
  'Public': 'Публичный',
  'Tags': 'Теги',
  'First message': 'Первое сообщение',
  'Create public': 'Создать публично',
  'Catalog is unavailable': 'Каталог недоступен',
  'No characters yet': 'Персонажей пока нет',
  'Retry': 'Повторить',
  'Search characters': 'Поиск персонажей',
  'Import': 'Импорт',
  'Message': 'Сообщение',
  'Stop': 'Стоп',
  'Regenerate': 'Перегенерировать',
  'Edit last': 'Изменить последнее',
  'Choose': 'Выбрать',
  'Remove': 'Убрать',
  'Close': 'Закрыть',
  'Dismiss': 'Скрыть',
  'Refresh': 'Обновить',
  'Language': 'Язык',
  'Font': 'Шрифт',
  'System default': 'Системный',
  'English': 'Английский',
  'Russian': 'Русский',
};

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  final _storage = AppStorage();
  final _authClient = SupabaseAuthClient();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  final _hostController = TextEditingController();
  final _mobileHostController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiBaseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiModelController = TextEditingController();
  final _characterNameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _avatarPathController = TextEditingController();
  final _backgroundPathController = TextEditingController();
  final _promptController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _firstMessageController = TextEditingController();
  final _exampleDialogueController = TextEditingController();
  final _memoryController = TextEditingController();
  final _autoMemoryController = TextEditingController();
  final _loreController = TextEditingController();

  var _settings = ChatSettings.defaults;
  var _uiSettings = UiSettings.defaults;
  var _characters = <CharacterProfile>[];
  var _activeCharacterId = '';
  var _chatSessions = <ChatSession>[];
  var _activeChatId = '';
  var _messages = <ChatMessage>[];
  var _autoMemory = '';

  bool _isLoading = true;
  bool _isSending = false;
  bool _isTestingConnection = false;
  bool _isAuthLoading = true;
  bool _isAuthBusy = false;
  bool _isSummarizingMemory = false;
  bool _isEditorCollapsed = false;
  _EditorSection _editorSection = _EditorSection.characters;
  String? _error;
  String? _connectionMessage;
  String? _authMessage;
  AuthSession? _authSession;
  bool? _connectionOk;
  int _requestSerial = 0;
  OllamaCancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _syncControllersFromSettings(_settings);
    unawaited(_loadState());
    unawaited(_loadAuth());
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _hostController.dispose();
    _mobileHostController.dispose();
    _modelController.dispose();
    _apiBaseUrlController.dispose();
    _apiKeyController.dispose();
    _apiModelController.dispose();
    _characterNameController.dispose();
    _userNameController.dispose();
    _avatarPathController.dispose();
    _backgroundPathController.dispose();
    _promptController.dispose();
    _scenarioController.dispose();
    _firstMessageController.dispose();
    _exampleDialogueController.dispose();
    _memoryController.dispose();
    _autoMemoryController.dispose();
    _loreController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final appState = await _storage.loadAppState();
    ChatSession? activeChat;
    for (final chat in appState.chats) {
      if (chat.id == appState.activeChatId) {
        activeChat = chat;
        break;
      }
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = appState.settings;
      _uiSettings = appState.uiSettings;
      _characters = List<CharacterProfile>.of(appState.characters);
      _activeCharacterId = appState.selectedCharacterId;
      _chatSessions = List<ChatSession>.of(appState.chats);
      _activeChatId = activeChat?.id ?? '';
      _messages = List<ChatMessage>.of(activeChat?.messages ?? []);
      _autoMemory = activeChat?.autoMemory ?? '';
      _isLoading = false;
    });
    _syncControllersFromSettings(appState.settings);
    _autoMemoryController.text = activeChat?.autoMemory ?? '';
    _scrollToBottom(animated: false);
  }

  Future<void> _loadAuth() async {
    try {
      final session = await _authClient.loadSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _authSession = session;
        _isAuthLoading = false;
        _authMessage = session == null ? null : 'Signed in';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authSession = null;
        _isAuthLoading = false;
        _authMessage = 'Auth restore failed: $error';
      });
    }
  }

  Future<AuthSession?> _freshAuthSession() async {
    final session = _authSession;
    if (session == null) {
      return null;
    }
    if (!session.shouldRefresh) {
      return session;
    }

    try {
      final refreshed = await _authClient.refreshSession(session);
      if (mounted) {
        setState(() {
          _authSession = refreshed;
          _authMessage = null;
        });
      }
      return refreshed;
    } catch (_) {
      await _authClient.clearSession();
      if (mounted) {
        setState(() {
          _authSession = null;
          _authMessage = 'Session expired. Sign in again.';
        });
      }
      return null;
    }
  }

  Future<void> _signIn(String email, String password) async {
    setState(() {
      _isAuthBusy = true;
      _authMessage = null;
    });

    try {
      final session = await _authClient.signInWithPassword(
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _authSession = session;
        _authMessage = 'Signed in';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _authMessage = 'Sign in failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthBusy = false);
      }
    }
  }

  Future<void> _createAccount(String email, String password) async {
    setState(() {
      _isAuthBusy = true;
      _authMessage = null;
    });

    try {
      final result = await _authClient.signUp(email: email, password: password);
      if (!mounted) {
        return;
      }
      setState(() {
        _authSession = result.session;
        _authMessage = result.message;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _authMessage = 'Account creation failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthBusy = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isAuthBusy = true;
      _authMessage = null;
    });

    try {
      await _authClient.signOut(_authSession);
      if (!mounted) {
        return;
      }
      setState(() {
        _authSession = null;
        _authMessage = 'Signed out';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _authMessage = 'Sign out failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthBusy = false);
      }
    }
  }

  ChatSettings _settingsFromControllers() {
    return _settings.copyWith(
      host: _hostController.text.trim(),
      mobileHost: _mobileHostController.text.trim(),
      model: _modelController.text.trim(),
      apiBaseUrl: _apiBaseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      apiModel: _apiModelController.text.trim(),
      characterName: _characterNameController.text.trim(),
      userName: _userNameController.text.trim(),
      avatarPath: _avatarPathController.text.trim(),
      backgroundPath: _backgroundPathController.text.trim(),
      systemPrompt: _promptController.text.trim(),
      scenario: _scenarioController.text.trim(),
      firstMessage: _firstMessageController.text.trim(),
      exampleDialogue: _exampleDialogueController.text.trim(),
      memory: _memoryController.text.trim(),
      lore: _loreController.text.trim(),
    );
  }

  void _syncControllersFromSettings(ChatSettings settings) {
    _hostController.text = settings.host;
    _mobileHostController.text = settings.mobileHost;
    _modelController.text = settings.model;
    _apiBaseUrlController.text = settings.apiBaseUrl;
    _apiKeyController.text = settings.apiKey;
    _apiModelController.text = settings.apiModel;
    _characterNameController.text = settings.characterName;
    _userNameController.text = settings.userName;
    _avatarPathController.text = settings.avatarPath;
    _backgroundPathController.text = settings.backgroundPath;
    _promptController.text = settings.systemPrompt;
    _scenarioController.text = settings.scenario;
    _firstMessageController.text = settings.firstMessage;
    _exampleDialogueController.text = settings.exampleDialogue;
    _memoryController.text = settings.memory;
    _loreController.text = settings.lore;
  }

  Future<void> _saveAppState() {
    return _storage.saveAppState(
      AppState(
        settings: _settings,
        uiSettings: _uiSettings,
        characters: _characters,
        selectedCharacterId: _activeCharacterId,
        chats: _chatSessions,
        activeChatId: _activeChatId,
      ),
    );
  }

  Future<void> _saveSettings() {
    _updateActiveCharacter(_settings);
    _updateActiveChat(autoMemory: _autoMemory);
    return _saveAppState();
  }

  Future<void> _saveMessages() async {
    _updateActiveChat(
      messages: List<ChatMessage>.of(_messages),
      autoMemory: _autoMemory,
    );
    await _saveAppState();
  }

  Future<void> _setUiSettings(UiSettings settings) async {
    setState(() {
      _uiSettings = settings;
    });
    await _saveAppState();
  }

  Future<void> _applySettings({bool showSnack = true}) async {
    final nextSettings = _settingsFromControllers();
    final nextAutoMemory = _autoMemoryController.text.trim();
    setState(() {
      final canReplaceGreeting =
          _messages.length == 1 &&
          _messages.first.role == MessageRole.assistant;
      _settings = nextSettings;
      _autoMemory = nextAutoMemory;
      _updateActiveCharacter(nextSettings);
      _updateActiveChat(autoMemory: nextAutoMemory);
      if (canReplaceGreeting) {
        _messages = _initialMessages(nextSettings);
        _updateActiveChat(messages: List<ChatMessage>.of(_messages));
      }
    });

    await _saveAppState();

    if (showSnack && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  List<ChatMessage> _initialMessages(ChatSettings settings) {
    final first = settings.firstMessage.trim();
    return first.isEmpty
        ? <ChatMessage>[]
        : <ChatMessage>[ChatMessage.assistant(first)];
  }

  bool get _hasActiveCharacter => _activeCharacterOrNull != null;

  CharacterProfile? get _activeCharacterOrNull {
    for (final character in _characters) {
      if (character.id == _activeCharacterId) {
        return character;
      }
    }
    return null;
  }

  void _updateActiveCharacter(ChatSettings settings) {
    final index = _characters.indexWhere(
      (character) => character.id == _activeCharacterId,
    );
    if (index == -1) {
      return;
    }
    final current = _characters[index];
    _characters[index] = CharacterProfile.fromSettings(
      settings,
      id: current.id,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  void _updateActiveChat({
    List<ChatMessage>? messages,
    String? autoMemory,
    String? title,
  }) {
    final index = _chatSessions.indexWhere((chat) => chat.id == _activeChatId);
    if (index == -1) {
      return;
    }
    final current = _chatSessions[index];
    final nextMessages = messages ?? current.messages;
    _chatSessions[index] = current.copyWith(
      title: title ?? _chatTitle(current.title, nextMessages),
      messages: nextMessages,
      autoMemory: autoMemory ?? current.autoMemory,
      updatedAt: DateTime.now(),
    );
  }

  String _chatTitle(String currentTitle, List<ChatMessage> messages) {
    if (currentTitle.trim().isNotEmpty && currentTitle != 'New chat') {
      return currentTitle;
    }

    for (final message in messages) {
      if (message.role != MessageRole.user) {
        continue;
      }
      final text = message.content.trim();
      if (text.isEmpty) {
        continue;
      }
      return text.length <= 42 ? text : '${text.substring(0, 42)}...';
    }

    return 'New chat';
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }
    if (!_hasActiveCharacter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or select a character first')),
      );
      setState(() => _editorSection = _EditorSection.characters);
      return;
    }

    await _applySettings(showSnack: false);
    setState(() {
      _error = null;
      _connectionMessage = null;
      _messages.add(ChatMessage.user(text));
      _inputController.clear();
    });
    await _saveMessages();
    _scrollToBottom();
    await _requestAssistantReply();
  }

  Future<void> _requestAssistantReply({String? instruction}) async {
    if (_isSending || !_hasUserMessage || !_hasActiveCharacter) {
      return;
    }

    final requestId = ++_requestSerial;
    final cancelToken = OllamaCancelToken();
    setState(() {
      _error = null;
      _isSending = true;
      _cancelToken = cancelToken;
    });
    _scrollToBottom();

    try {
      final response = await OllamaClient(_settings, autoMemory: _autoMemory)
          .send(
            List<ChatMessage>.of(_messages),
            cancelToken: cancelToken,
            instruction: instruction,
          );
      if (!mounted || requestId != _requestSerial || cancelToken.isCancelled) {
        return;
      }

      setState(() {
        _messages.add(ChatMessage.assistant(response));
      });
      await _saveMessages();
    } on OllamaException catch (error) {
      if (!mounted || requestId != _requestSerial) {
        return;
      }
      if (!cancelToken.isCancelled) {
        setState(() {
          _error = error.message;
        });
      }
    } catch (error) {
      if (!mounted || requestId != _requestSerial) {
        return;
      }
      setState(() {
        _error = 'Unexpected error: $error';
      });
    } finally {
      if (mounted && requestId == _requestSerial) {
        setState(() {
          _isSending = false;
          _cancelToken = null;
        });
        _scrollToBottom();
        _focusNode.requestFocus();
      }
    }
  }

  void _stopGeneration() {
    if (!_isSending) {
      return;
    }

    _cancelToken?.cancel();
    _requestSerial++;
    setState(() {
      _isSending = false;
      _cancelToken = null;
      _error = null;
    });
  }

  Future<void> _regenerateLastReply() async {
    if (_isSending || !_hasUserMessage) {
      return;
    }

    final lastUserIndex = _lastUserIndex;
    if (lastUserIndex == -1) {
      return;
    }

    setState(() {
      _messages = _messages.take(lastUserIndex + 1).toList();
      _error = null;
    });
    await _saveMessages();
    await _requestAssistantReply();
  }

  Future<void> _editLastUserMessage() async {
    if (_isSending) {
      return;
    }

    final lastUserIndex = _lastUserIndex;
    if (lastUserIndex == -1) {
      return;
    }

    final text = _messages[lastUserIndex].content;
    setState(() {
      _inputController.text = text;
      _inputController.selection = TextSelection.collapsed(offset: text.length);
      _messages = _messages.take(lastUserIndex).toList();
      _error = null;
    });
    await _saveMessages();
    _focusNode.requestFocus();
  }

  Future<void> _openMessageMenu(int index, Offset position) async {
    if (_isSending || index < 0 || index >= _messages.length) {
      return;
    }

    final message = _messages[index];
    final canGenerateFromHere = _canGenerateFromMessage(index);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final menuPosition = overlay == null
        ? RelativeRect.fromLTRB(position.dx, position.dy, 0, 0)
        : RelativeRect.fromRect(
            Rect.fromLTWH(position.dx, position.dy, 0, 0),
            Offset.zero & overlay.size,
          );
    final selected = await showMenu<String>(
      context: context,
      position: menuPosition,
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
          ),
        ),
        if (message.role == MessageRole.assistant && canGenerateFromHere)
          const PopupMenuItem(
            value: 'regenerate',
            child: ListTile(
              leading: Icon(Icons.refresh),
              title: Text('Regenerate'),
            ),
          ),
        if (canGenerateFromHere)
          const PopupMenuItem(
            value: 'instruction',
            child: ListTile(
              leading: Icon(Icons.tune),
              title: Text('Generation instruction'),
            ),
          ),
      ],
    );

    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case 'edit':
        await _editMessageAt(index);
      case 'delete':
        await _deleteMessageAt(index);
      case 'regenerate':
        await _regenerateFromMessage(index);
      case 'instruction':
        await _generateFromInstructionAt(index);
    }
  }

  bool _canGenerateFromMessage(int index) {
    if (index < 0 || index >= _messages.length) {
      return false;
    }

    final message = _messages[index];
    final historyEnd = message.role == MessageRole.assistant
        ? index
        : index + 1;
    return _messages
        .take(historyEnd)
        .any((message) => message.role == MessageRole.user);
  }

  Future<void> _editMessageAt(int index) async {
    if (_isSending || index < 0 || index >= _messages.length) {
      return;
    }

    final original = _messages[index];
    final controller = TextEditingController(text: original.content);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 4,
              maxLines: 12,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (edited == null || edited.trim().isEmpty || !mounted) {
      return;
    }

    setState(() {
      _messages[index] = ChatMessage(
        role: original.role,
        content: edited.trim(),
        createdAt: original.createdAt,
      );
      _error = null;
    });
    await _saveMessages();
  }

  Future<void> _deleteMessageAt(int index) async {
    if (_isSending || index < 0 || index >= _messages.length) {
      return;
    }

    setState(() {
      _messages.removeAt(index);
      _error = null;
    });
    await _saveMessages();
  }

  Future<void> _regenerateFromMessage(int index, {String? instruction}) async {
    if (_isSending || index < 0 || index >= _messages.length) {
      return;
    }

    final message = _messages[index];
    final historyEnd = message.role == MessageRole.assistant
        ? index
        : index + 1;
    final nextMessages = _messages.take(historyEnd).toList();

    if (!nextMessages.any((message) => message.role == MessageRole.user)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A user message is required before generation'),
        ),
      );
      return;
    }

    setState(() {
      _messages = nextMessages;
      _error = null;
    });
    await _saveMessages();
    await _requestAssistantReply(instruction: instruction);
  }

  Future<void> _generateFromInstructionAt(int index) async {
    final instruction = await _askGenerationInstruction();
    if (instruction == null || instruction.trim().isEmpty) {
      return;
    }

    await _regenerateFromMessage(index, instruction: instruction.trim());
  }

  Future<String?> _askGenerationInstruction() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Generation instruction'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Example: answer colder, shorter, without jokes',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Generate'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _clearChat() async {
    _stopGeneration();
    setState(() {
      _error = null;
      _messages = _initialMessages(_settings);
      _autoMemory = '';
      _autoMemoryController.clear();
    });
    await _saveMessages();
  }

  Future<void> _startNewChat() async {
    if (_isSending) {
      return;
    }
    if (_activeCharacterOrNull == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or select a character first')),
      );
      setState(() => _editorSection = _EditorSection.characters);
      return;
    }

    await _applySettings(showSnack: false);
    final activeCharacter = _activeCharacterOrNull;
    if (activeCharacter == null) {
      return;
    }
    final chat = ChatSession.empty(activeCharacter);
    setState(() {
      _chatSessions.add(chat);
      _activeChatId = chat.id;
      _messages = chat.messages;
      _autoMemory = chat.autoMemory;
      _autoMemoryController.text = chat.autoMemory;
      _error = null;
    });
    await _saveAppState();
    _scrollToBottom(animated: false);
  }

  Future<void> _selectChat(String chatId) async {
    if (_isSending || chatId == _activeChatId) {
      return;
    }

    await _applySettings(showSnack: false);
    final chat = _chatSessions.firstWhere((chat) => chat.id == chatId);
    CharacterProfile? character;
    for (final item in _characters) {
      if (item.id == chat.characterId) {
        character = item;
        break;
      }
    }
    character ??= _activeCharacterOrNull;
    if (character == null) {
      return;
    }
    final selectedCharacter = character;

    setState(() {
      _activeChatId = chat.id;
      _activeCharacterId = selectedCharacter.id;
      _settings = selectedCharacter.applyTo(_settings);
      _messages = chat.messages;
      _autoMemory = chat.autoMemory;
      _autoMemoryController.text = chat.autoMemory;
      _error = null;
    });
    _syncControllersFromSettings(_settings);
    await _saveAppState();
    _scrollToBottom(animated: false);
  }

  Future<void> _renameChat(String chatId) async {
    final chat = _chatSessions.firstWhere((chat) => chat.id == chatId);
    final controller = TextEditingController(text: chat.displayTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename chat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (title == null || title.trim().isEmpty || !mounted) {
      return;
    }

    setState(() {
      final index = _chatSessions.indexWhere((chat) => chat.id == chatId);
      if (index != -1) {
        _chatSessions[index] = _chatSessions[index].copyWith(
          title: title.trim(),
          updatedAt: DateTime.now(),
        );
      }
    });
    await _saveAppState();
  }

  Future<void> _deleteChat(String chatId) async {
    if (_isSending || _chatSessions.length <= 1) {
      return;
    }

    final confirmed = await _confirm(
      title: 'Delete chat',
      message: 'This chat will be removed from the local library.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _chatSessions.removeWhere((chat) => chat.id == chatId);
      if (_activeChatId == chatId) {
        ChatSession? replacement;
        for (final chat in _chatSessions) {
          if (chat.characterId == _activeCharacterId) {
            replacement = chat;
            break;
          }
        }
        final nextChat = replacement ?? _chatSessions.first;
        CharacterProfile? character;
        for (final item in _characters) {
          if (item.id == nextChat.characterId) {
            character = item;
            break;
          }
        }
        character ??= _activeCharacterOrNull;
        if (character == null) {
          _activeChatId = '';
          _activeCharacterId = '';
          _settings = ChatSettings.defaults;
          _messages = <ChatMessage>[];
          _autoMemory = '';
          _autoMemoryController.clear();
          return;
        }
        _activeChatId = nextChat.id;
        _activeCharacterId = character.id;
        _settings = character.applyTo(_settings);
        _messages = nextChat.messages;
        _autoMemory = nextChat.autoMemory;
        _autoMemoryController.text = nextChat.autoMemory;
      }
    });
    _syncControllersFromSettings(_settings);
    await _saveAppState();
  }

  Future<void> _selectCharacter(String characterId) async {
    if (_isSending || characterId == _activeCharacterId) {
      return;
    }

    await _applySettings(showSnack: false);
    final character = _characters.firstWhere(
      (character) => character.id == characterId,
    );
    var characterChats = _chatSessions
        .where((chat) => chat.characterId == character.id)
        .toList();
    ChatSession chat;
    if (characterChats.isEmpty) {
      chat = ChatSession.empty(character);
      _chatSessions.add(chat);
    } else {
      characterChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      chat = characterChats.first;
    }

    setState(() {
      _activeCharacterId = character.id;
      _activeChatId = chat.id;
      _settings = character.applyTo(_settings);
      _messages = chat.messages;
      _autoMemory = chat.autoMemory;
      _autoMemoryController.text = chat.autoMemory;
      _error = null;
    });
    _syncControllersFromSettings(_settings);
    await _saveAppState();
    _scrollToBottom(animated: false);
  }

  Future<void> _createCharacter() async {
    final draft = await showDialog<_CharacterCreationDraft>(
      context: context,
      builder: (context) => _CreateCharacterDialog(
        accentColorValue: _settings.accentColorValue,
        userName: _settings.userName,
        canPublishPublic: _authSession != null,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }

    await _applySettings(showSnack: false);
    final now = DateTime.now();
    var base = draft.profile.copyWith(
      id: 'character_${now.microsecondsSinceEpoch}',
      createdAt: now,
      updatedAt: now,
    );
    final chat = ChatSession.empty(base);
    await _addCharacter(base, chat);

    if (draft.isPublic) {
      final session = await _freshAuthSession();
      if (session == null) {
        if (!mounted) {
          return;
        }
        setState(() => _editorSection = _EditorSection.account);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally. Sign in to publish publicly.'),
          ),
        );
        return;
      }
      unawaited(_publishCharacter(base.id, draft, session));
    }
  }

  Future<void> _publishCharacter(
    String characterId,
    _CharacterCreationDraft draft,
    AuthSession session,
  ) async {
    final index = _characters.indexWhere(
      (character) => character.id == characterId,
    );
    if (index == -1) {
      return;
    }

    final localProfile = _characters[index];
    try {
      final publicProfile = await OnlineCatalogClient().publishCharacter(
        localProfile,
        description: draft.description,
        tags: draft.tags,
        accessToken: session.accessToken,
        ownerId: session.user.id,
        authorName: session.user.displayName,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        final currentIndex = _characters.indexWhere(
          (character) => character.id == characterId,
        );
        if (currentIndex == -1) {
          return;
        }
        final current = _characters[currentIndex];
        final updated = publicProfile.copyWith(
          id: current.id,
          createdAt: current.createdAt,
          updatedAt: DateTime.now(),
        );
        _characters[currentIndex] = updated;
        if (_activeCharacterId == updated.id) {
          _settings = updated.applyTo(_settings);
          _syncControllersFromSettings(_settings);
        }
      });
      await _saveAppState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Published to online catalog')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally. Publish failed: $error')),
        );
      }
    }
  }

  Future<void> _importOnlineCharacter(OnlineCharacter onlineCharacter) async {
    final base = onlineCharacter.toCharacterProfile();
    final chat = ChatSession.empty(base);
    await _addCharacter(base, chat);
  }

  Future<void> _addCharacter(CharacterProfile base, ChatSession chat) async {
    setState(() {
      _characters.add(base);
      _chatSessions.add(chat);
      _activeCharacterId = base.id;
      _activeChatId = chat.id;
      _settings = base.applyTo(_settings);
      _messages = chat.messages;
      _autoMemory = chat.autoMemory;
      _autoMemoryController.text = chat.autoMemory;
      _error = null;
    });
    _syncControllersFromSettings(_settings);
    await _saveAppState();
  }

  Future<void> _openOnlineCatalog() async {
    final session = await _freshAuthSession();
    if (!mounted) {
      return;
    }
    final character = await showDialog<OnlineCharacter>(
      context: context,
      builder: (context) => _OnlineCatalogDialog(session: session),
    );
    if (character == null || !mounted) {
      return;
    }

    await _importOnlineCharacter(character);
  }

  Future<void> _duplicateCharacter(String characterId) async {
    await _applySettings(showSnack: false);
    final source = _characters.firstWhere(
      (character) => character.id == characterId,
    );
    final copy = source.copyWith(
      id: 'character_${DateTime.now().microsecondsSinceEpoch}',
      name: '${source.displayName} copy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final chat = ChatSession.empty(copy);

    setState(() {
      _characters.add(copy);
      _chatSessions.add(chat);
      _activeCharacterId = copy.id;
      _activeChatId = chat.id;
      _settings = copy.applyTo(_settings);
      _messages = chat.messages;
      _autoMemory = chat.autoMemory;
      _autoMemoryController.text = chat.autoMemory;
      _error = null;
    });
    _syncControllersFromSettings(_settings);
    await _saveAppState();
  }

  Future<void> _deleteCharacter(String characterId) async {
    if (_isSending || _characters.isEmpty) {
      return;
    }

    final confirmed = await _confirm(
      title: 'Delete character',
      message: 'This also removes chats attached to the character.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _characters.removeWhere((character) => character.id == characterId);
      _chatSessions.removeWhere((chat) => chat.characterId == characterId);

      if (_activeCharacterId == characterId) {
        if (_characters.isEmpty) {
          _activeCharacterId = '';
          _activeChatId = '';
          _settings = ChatSettings.defaults;
          _messages = <ChatMessage>[];
          _autoMemory = '';
          _autoMemoryController.clear();
          return;
        }

        final character = _characters.first;
        ChatSession? chat;
        for (final item in _chatSessions) {
          if (item.characterId == character.id) {
            chat = item;
            break;
          }
        }
        if (chat == null) {
          chat = ChatSession.empty(character);
          _chatSessions.add(chat);
        }
        _activeCharacterId = character.id;
        _activeChatId = chat.id;
        _settings = character.applyTo(_settings);
        _messages = chat.messages;
        _autoMemory = chat.autoMemory;
        _autoMemoryController.text = chat.autoMemory;
      }
    });
    _syncControllersFromSettings(_settings);
    await _saveAppState();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _testConnection() async {
    await _applySettings(showSnack: false);
    setState(() {
      _isTestingConnection = true;
      _connectionMessage = 'Checking ${_settings.activeEndpoint}...';
      _connectionOk = null;
    });

    final result = await OllamaClient(_settings).probe();
    if (!mounted) {
      return;
    }

    setState(() {
      _isTestingConnection = false;
      _connectionMessage = result.message;
      _connectionOk = result.ok;
    });
  }

  Future<void> _applyProviderPreset(_ProviderPreset preset) async {
    setState(() {
      _settings = _settings.copyWith(
        backend: preset.backend,
        host: preset.host,
        mobileHost: preset.mobileHost,
        useMobileHost: preset.useMobileHost,
        apiBaseUrl: preset.apiBaseUrl,
        apiModel: preset.apiModel,
      );
      if (preset.host != null) {
        _hostController.text = preset.host!;
      }
      if (preset.mobileHost != null) {
        _mobileHostController.text = preset.mobileHost!;
      }
      if (preset.apiBaseUrl != null) {
        _apiBaseUrlController.text = preset.apiBaseUrl!;
      }
      if (preset.apiModel != null) {
        _apiModelController.text = preset.apiModel!;
      }
      _connectionMessage = null;
      _connectionOk = null;
    });
    await _applySettings(showSnack: false);
  }

  Future<void> _summarizeMemory() async {
    if (_isSending || _isSummarizingMemory) {
      return;
    }
    if (!_messages.any((message) => message.role == MessageRole.user)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A user message is required first')),
      );
      return;
    }

    await _applySettings(showSnack: false);
    setState(() {
      _isSummarizingMemory = true;
      _error = null;
    });

    try {
      final summary = await OllamaClient(_settings).summarizeMemory(
        List<ChatMessage>.of(_messages),
        existingMemory: _autoMemory,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _autoMemory = summary.trim();
        _autoMemoryController.text = _autoMemory;
      });
      await _saveMessages();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat memory updated')));
      }
    } on OllamaException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Unexpected error: $error');
    } finally {
      if (mounted) {
        setState(() => _isSummarizingMemory = false);
      }
    }
  }

  Future<void> _showPromptDebug() async {
    await _applySettings(showSnack: false);
    if (!mounted) {
      return;
    }

    final prompt = _buildPromptDebugText();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Final prompt'),
          content: SizedBox(
            width: 760,
            height: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                prompt,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prompt));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Prompt copied')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _buildPromptDebugText() {
    final buffer = StringBuffer()
      ..writeln('Backend: ${_settings.backendLabel}')
      ..writeln('Model: ${_settings.activeModel}')
      ..writeln('Endpoint: ${_settings.activeEndpoint}')
      ..writeln()
      ..writeln('--- SYSTEM ---')
      ..writeln(_settings.buildSystemPrompt(autoMemory: _autoMemory))
      ..writeln()
      ..writeln('--- CHAT HISTORY ---');

    if (_messages.isEmpty) {
      buffer.writeln('No messages yet.');
    } else {
      for (final message in _messages) {
        final role = message.role == MessageRole.user ? 'user' : 'assistant';
        buffer
          ..writeln('[$role]')
          ..writeln(message.content.trim())
          ..writeln();
      }
    }

    return buffer.toString().trimRight();
  }

  Future<void> _pickAvatar() async {
    await _pickImage((path) {
      _avatarPathController.text = path;
      _settings = _settings.copyWith(avatarPath: path);
    });
  }

  Future<void> _pickBackground() async {
    await _pickImage((path) {
      _backgroundPathController.text = path;
      _settings = _settings.copyWith(backgroundPath: path);
    });
  }

  Future<void> _pickImage(ValueChanged<String> onSelected) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
        ),
      ],
    );

    if (file == null) {
      return;
    }

    setState(() {
      onSelected(file.path);
    });
    await _saveSettings();
  }

  Future<void> _clearAvatar() async {
    setState(() {
      _avatarPathController.clear();
      _settings = _settings.copyWith(avatarPath: '');
    });
    await _saveSettings();
  }

  Future<void> _clearBackground() async {
    setState(() {
      _backgroundPathController.clear();
      _settings = _settings.copyWith(backgroundPath: '');
    });
    await _saveSettings();
  }

  Future<void> _setMobileMode(bool value) async {
    setState(() {
      _settings = _settings.copyWith(useMobileHost: value);
      _connectionMessage = null;
      _connectionOk = null;
    });
    await _applySettings(showSnack: false);
  }

  Future<void> _setBackend(AiBackend backend) async {
    setState(() {
      _settings = _settings.copyWith(backend: backend);
      _connectionMessage = null;
      _connectionOk = null;
    });
    await _applySettings(showSnack: false);
  }

  Future<void> _setAccentColor(int colorValue) async {
    setState(() {
      _settings = _settings.copyWith(accentColorValue: colorValue);
    });
    await _saveSettings();
  }

  bool get _hasUserMessage =>
      _messages.any((message) => message.role == MessageRole.user);

  int get _lastUserIndex {
    for (var index = _messages.length - 1; index >= 0; index--) {
      if (_messages[index].role == MessageRole.user) {
        return index;
      }
    }
    return -1;
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final baseTheme = Theme.of(context);
    final fontFamily = _uiSettings.fontFamily.trim();
    final theme = fontFamily.isEmpty
        ? baseTheme
        : baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(fontFamily: fontFamily),
            primaryTextTheme: baseTheme.primaryTextTheme.apply(
              fontFamily: fontFamily,
            ),
          );

    return _AppTextScope(
      language: _uiSettings.language,
      child: Theme(
        data: theme,
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;

                if (isWide) {
                  return Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: _isEditorCollapsed ? 72 : 390,
                        child: _buildSettingsPane(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _buildChatPanel(showSettingsButton: false),
                      ),
                    ],
                  );
                }

                return _buildChatPanel(showSettingsButton: true);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPane({bool allowCollapse = true}) {
    return _SettingsPane(
      settings: _settings,
      uiSettings: _uiSettings,
      characters: _characters,
      activeCharacterId: _activeCharacterId,
      chatSessions: _chatSessions,
      activeChatId: _activeChatId,
      messages: _messages,
      authSession: _authSession,
      selectedSection: _editorSection,
      isCollapsed: allowCollapse && _isEditorCollapsed,
      allowCollapse: allowCollapse,
      hostController: _hostController,
      mobileHostController: _mobileHostController,
      modelController: _modelController,
      apiBaseUrlController: _apiBaseUrlController,
      apiKeyController: _apiKeyController,
      apiModelController: _apiModelController,
      characterNameController: _characterNameController,
      userNameController: _userNameController,
      avatarPathController: _avatarPathController,
      backgroundPathController: _backgroundPathController,
      promptController: _promptController,
      scenarioController: _scenarioController,
      firstMessageController: _firstMessageController,
      exampleDialogueController: _exampleDialogueController,
      memoryController: _memoryController,
      autoMemoryController: _autoMemoryController,
      loreController: _loreController,
      isTestingConnection: _isTestingConnection,
      isAuthLoading: _isAuthLoading,
      isAuthBusy: _isAuthBusy,
      isSummarizingMemory: _isSummarizingMemory,
      connectionMessage: _connectionMessage,
      connectionOk: _connectionOk,
      authMessage: _authMessage,
      onBackendChanged: _setBackend,
      onProviderPresetSelected: _applyProviderPreset,
      onMobileModeChanged: _setMobileMode,
      onTemperatureChanged: (value) {
        setState(() => _settings = _settings.copyWith(temperature: value));
      },
      onContextSizeChanged: (value) {
        setState(
          () => _settings = _settings.copyWith(contextSize: value.round()),
        );
      },
      onMaxTokensChanged: (value) {
        setState(
          () => _settings = _settings.copyWith(maxTokens: value.round()),
        );
      },
      onAccentColorChanged: _setAccentColor,
      onApply: _applySettings,
      onClearChat: _clearChat,
      onNewChat: _startNewChat,
      onSelectChat: _selectChat,
      onRenameChat: _renameChat,
      onDeleteChat: _deleteChat,
      onSelectCharacter: _selectCharacter,
      onCreateCharacter: _createCharacter,
      onOpenOnlineCatalog: _openOnlineCatalog,
      onDuplicateCharacter: _duplicateCharacter,
      onDeleteCharacter: _deleteCharacter,
      onToggleCollapsed: () {
        setState(() {
          _isEditorCollapsed = !_isEditorCollapsed;
        });
      },
      onSectionSelected: (section) {
        setState(() {
          _editorSection = section;
          if (allowCollapse) {
            _isEditorCollapsed = false;
          }
        });
      },
      onTestConnection: _testConnection,
      onSummarizeMemory: _summarizeMemory,
      onShowPromptDebug: _showPromptDebug,
      onUiSettingsChanged: _setUiSettings,
      onSignIn: _signIn,
      onCreateAccount: _createAccount,
      onSignOut: _signOut,
      onClearAuthMessage: () {
        setState(() => _authMessage = null);
      },
      onPickAvatar: _pickAvatar,
      onClearAvatar: _clearAvatar,
      onPickBackground: _pickBackground,
      onClearBackground: _clearBackground,
    );
  }

  Widget _buildChatPanel({required bool showSettingsButton}) {
    if (!_hasActiveCharacter) {
      return _EmptyChatPanel(
        showSettingsButton: showSettingsButton,
        accentColor: _settings.accentColor,
        onOpenSettings: _openSettingsSheet,
        onCreateCharacter: _createCharacter,
      );
    }

    return Column(
      children: [
        _ChatHeader(
          settings: _settings,
          isSending: _isSending,
          showSettingsButton: showSettingsButton,
          onOpenSettings: _openSettingsSheet,
          onClearChat: _clearChat,
        ),
        Expanded(
          child: _ChatBackdrop(
            backgroundPath: _settings.backgroundPath,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isSending && index == _messages.length) {
                  return _TypingBubble(settings: _settings);
                }
                return _MessageBubble(
                  index: index,
                  message: _messages[index],
                  settings: _settings,
                  onOpenMenu: _openMessageMenu,
                );
              },
            ),
          ),
        ),
        _ChatActions(
          isSending: _isSending,
          canRegenerate: _hasUserMessage,
          canEditLast: _lastUserIndex != -1,
          onStop: _stopGeneration,
          onRegenerate: _regenerateLastReply,
          onEditLast: _editLastUserMessage,
        ),
        if (_error != null)
          _ErrorStrip(
            message: _error!,
            onDismiss: () => setState(() => _error = null),
          ),
        _Composer(
          controller: _inputController,
          focusNode: _focusNode,
          isSending: _isSending,
          accentColor: _settings.accentColor,
          onSend: _sendMessage,
        ),
      ],
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff171b22),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.92,
              child: _buildSettingsPane(allowCollapse: false),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsPane extends StatelessWidget {
  const _SettingsPane({
    required this.settings,
    required this.uiSettings,
    required this.characters,
    required this.activeCharacterId,
    required this.chatSessions,
    required this.activeChatId,
    required this.messages,
    required this.authSession,
    required this.selectedSection,
    required this.isCollapsed,
    required this.allowCollapse,
    required this.hostController,
    required this.mobileHostController,
    required this.modelController,
    required this.apiBaseUrlController,
    required this.apiKeyController,
    required this.apiModelController,
    required this.characterNameController,
    required this.userNameController,
    required this.avatarPathController,
    required this.backgroundPathController,
    required this.promptController,
    required this.scenarioController,
    required this.firstMessageController,
    required this.exampleDialogueController,
    required this.memoryController,
    required this.autoMemoryController,
    required this.loreController,
    required this.isTestingConnection,
    required this.isAuthLoading,
    required this.isAuthBusy,
    required this.isSummarizingMemory,
    required this.connectionMessage,
    required this.connectionOk,
    required this.authMessage,
    required this.onBackendChanged,
    required this.onProviderPresetSelected,
    required this.onMobileModeChanged,
    required this.onTemperatureChanged,
    required this.onContextSizeChanged,
    required this.onMaxTokensChanged,
    required this.onAccentColorChanged,
    required this.onApply,
    required this.onClearChat,
    required this.onNewChat,
    required this.onSelectChat,
    required this.onRenameChat,
    required this.onDeleteChat,
    required this.onSelectCharacter,
    required this.onCreateCharacter,
    required this.onOpenOnlineCatalog,
    required this.onDuplicateCharacter,
    required this.onDeleteCharacter,
    required this.onToggleCollapsed,
    required this.onSectionSelected,
    required this.onTestConnection,
    required this.onSummarizeMemory,
    required this.onShowPromptDebug,
    required this.onUiSettingsChanged,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onSignOut,
    required this.onClearAuthMessage,
    required this.onPickAvatar,
    required this.onClearAvatar,
    required this.onPickBackground,
    required this.onClearBackground,
  });

  final ChatSettings settings;
  final UiSettings uiSettings;
  final List<CharacterProfile> characters;
  final String activeCharacterId;
  final List<ChatSession> chatSessions;
  final String activeChatId;
  final List<ChatMessage> messages;
  final AuthSession? authSession;
  final _EditorSection selectedSection;
  final bool isCollapsed;
  final bool allowCollapse;
  final TextEditingController hostController;
  final TextEditingController mobileHostController;
  final TextEditingController modelController;
  final TextEditingController apiBaseUrlController;
  final TextEditingController apiKeyController;
  final TextEditingController apiModelController;
  final TextEditingController characterNameController;
  final TextEditingController userNameController;
  final TextEditingController avatarPathController;
  final TextEditingController backgroundPathController;
  final TextEditingController promptController;
  final TextEditingController scenarioController;
  final TextEditingController firstMessageController;
  final TextEditingController exampleDialogueController;
  final TextEditingController memoryController;
  final TextEditingController autoMemoryController;
  final TextEditingController loreController;
  final bool isTestingConnection;
  final bool isAuthLoading;
  final bool isAuthBusy;
  final bool isSummarizingMemory;
  final String? connectionMessage;
  final bool? connectionOk;
  final String? authMessage;
  final ValueChanged<AiBackend> onBackendChanged;
  final ValueChanged<_ProviderPreset> onProviderPresetSelected;
  final ValueChanged<bool> onMobileModeChanged;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<double> onContextSizeChanged;
  final ValueChanged<double> onMaxTokensChanged;
  final ValueChanged<int> onAccentColorChanged;
  final Future<void> Function({bool showSnack}) onApply;
  final Future<void> Function() onClearChat;
  final Future<void> Function() onNewChat;
  final ValueChanged<String> onSelectChat;
  final ValueChanged<String> onRenameChat;
  final ValueChanged<String> onDeleteChat;
  final ValueChanged<String> onSelectCharacter;
  final Future<void> Function() onCreateCharacter;
  final Future<void> Function() onOpenOnlineCatalog;
  final ValueChanged<String> onDuplicateCharacter;
  final ValueChanged<String> onDeleteCharacter;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<_EditorSection> onSectionSelected;
  final Future<void> Function() onTestConnection;
  final Future<void> Function() onSummarizeMemory;
  final Future<void> Function() onShowPromptDebug;
  final ValueChanged<UiSettings> onUiSettingsChanged;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String email, String password) onCreateAccount;
  final Future<void> Function() onSignOut;
  final VoidCallback onClearAuthMessage;
  final Future<void> Function() onPickAvatar;
  final Future<void> Function() onClearAvatar;
  final Future<void> Function() onPickBackground;
  final Future<void> Function() onClearBackground;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return _EditorRail(
        selectedSection: selectedSection,
        onSectionSelected: onSectionSelected,
        onToggleCollapsed: onToggleCollapsed,
      );
    }

    return Material(
      color: const Color(0xff171b22),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(_sectionTitle(selectedSection)),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear chat',
                  onPressed: onClearChat,
                  icon: const Icon(Icons.delete_outline),
                ),
                if (allowCollapse)
                  IconButton(
                    tooltip: 'Collapse editor',
                    onPressed: onToggleCollapsed,
                    icon: const Icon(Icons.keyboard_double_arrow_left),
                  ),
              ],
            ),
          ),
          _EditorSectionButtons(
            selectedSection: selectedSection,
            onSectionSelected: onSectionSelected,
          ),
          const Divider(height: 1),
          Expanded(child: _buildSectionContent()),
        ],
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (selectedSection) {
      case _EditorSection.characters:
        return _CharactersSection(
          settings: settings,
          characters: characters,
          activeCharacterId: activeCharacterId,
          characterNameController: characterNameController,
          userNameController: userNameController,
          avatarPathController: avatarPathController,
          backgroundPathController: backgroundPathController,
          firstMessageController: firstMessageController,
          promptController: promptController,
          scenarioController: scenarioController,
          exampleDialogueController: exampleDialogueController,
          memoryController: memoryController,
          autoMemoryController: autoMemoryController,
          loreController: loreController,
          isSummarizingMemory: isSummarizingMemory,
          onAccentColorChanged: onAccentColorChanged,
          onSelectCharacter: onSelectCharacter,
          onCreateCharacter: onCreateCharacter,
          onOpenOnlineCatalog: onOpenOnlineCatalog,
          onDuplicateCharacter: onDuplicateCharacter,
          onDeleteCharacter: onDeleteCharacter,
          onPickAvatar: onPickAvatar,
          onClearAvatar: onClearAvatar,
          onPickBackground: onPickBackground,
          onClearBackground: onClearBackground,
          onSummarizeMemory: onSummarizeMemory,
          onApply: onApply,
        );
      case _EditorSection.chats:
        return _ChatsSection(
          settings: settings,
          chatSessions: chatSessions,
          activeChatId: activeChatId,
          activeCharacterId: activeCharacterId,
          onClearChat: onClearChat,
          onNewChat: onNewChat,
          onSelectChat: onSelectChat,
          onRenameChat: onRenameChat,
          onDeleteChat: onDeleteChat,
        );
      case _EditorSection.aiSettings:
        return _AiSettingsSection(
          settings: settings,
          hostController: hostController,
          mobileHostController: mobileHostController,
          modelController: modelController,
          apiBaseUrlController: apiBaseUrlController,
          apiKeyController: apiKeyController,
          apiModelController: apiModelController,
          isTestingConnection: isTestingConnection,
          connectionMessage: connectionMessage,
          connectionOk: connectionOk,
          onBackendChanged: onBackendChanged,
          onProviderPresetSelected: onProviderPresetSelected,
          onMobileModeChanged: onMobileModeChanged,
          onTemperatureChanged: onTemperatureChanged,
          onContextSizeChanged: onContextSizeChanged,
          onMaxTokensChanged: onMaxTokensChanged,
          onTestConnection: onTestConnection,
          onShowPromptDebug: onShowPromptDebug,
          onApply: onApply,
        );
      case _EditorSection.appSettings:
        return _AppSettingsSection(
          settings: uiSettings,
          onChanged: onUiSettingsChanged,
        );
      case _EditorSection.account:
        return _AccountSection(
          session: authSession,
          isLoading: isAuthLoading,
          isBusy: isAuthBusy,
          message: authMessage,
          onSignIn: onSignIn,
          onCreateAccount: onCreateAccount,
          onSignOut: onSignOut,
          onClearMessage: onClearAuthMessage,
        );
    }
  }

  String _sectionTitle(_EditorSection section) {
    switch (section) {
      case _EditorSection.characters:
        return 'Characters';
      case _EditorSection.chats:
        return 'Chats';
      case _EditorSection.aiSettings:
        return 'AI Settings';
      case _EditorSection.appSettings:
        return 'App Settings';
      case _EditorSection.account:
        return 'Account';
    }
  }
}

class _EditorRail extends StatelessWidget {
  const _EditorRail({
    required this.selectedSection,
    required this.onSectionSelected,
    required this.onToggleCollapsed,
  });

  final _EditorSection selectedSection;
  final ValueChanged<_EditorSection> onSectionSelected;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff171b22),
      child: Column(
        children: [
          const SizedBox(height: 10),
          IconButton(
            tooltip: 'Expand editor',
            onPressed: onToggleCollapsed,
            icon: const Icon(Icons.keyboard_double_arrow_right),
          ),
          const SizedBox(height: 10),
          _RailButton(
            tooltip: 'Characters',
            icon: Icons.theater_comedy_outlined,
            selected: selectedSection == _EditorSection.characters,
            onPressed: () => onSectionSelected(_EditorSection.characters),
          ),
          _RailButton(
            tooltip: 'Chats',
            icon: Icons.chat_bubble_outline,
            selected: selectedSection == _EditorSection.chats,
            onPressed: () => onSectionSelected(_EditorSection.chats),
          ),
          _RailButton(
            tooltip: 'AI Settings',
            icon: Icons.memory,
            selected: selectedSection == _EditorSection.aiSettings,
            onPressed: () => onSectionSelected(_EditorSection.aiSettings),
          ),
          _RailButton(
            tooltip: 'App Settings',
            icon: Icons.tune,
            selected: selectedSection == _EditorSection.appSettings,
            onPressed: () => onSectionSelected(_EditorSection.appSettings),
          ),
          _RailButton(
            tooltip: 'Account',
            icon: Icons.account_circle_outlined,
            selected: selectedSection == _EditorSection.account,
            onPressed: () => onSectionSelected(_EditorSection.account),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Tooltip(
        message: context.tr(tooltip),
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: selected ? const Color(0xff2a303b) : null,
            foregroundColor: selected ? Colors.white : const Color(0xffaab2c0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _EditorSectionButtons extends StatelessWidget {
  const _EditorSectionButtons({
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final _EditorSection selectedSection;
  final ValueChanged<_EditorSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          _SectionButton(
            label: 'Characters',
            icon: Icons.theater_comedy_outlined,
            selected: selectedSection == _EditorSection.characters,
            onPressed: () => onSectionSelected(_EditorSection.characters),
          ),
          const SizedBox(height: 8),
          _SectionButton(
            label: 'Chats',
            icon: Icons.chat_bubble_outline,
            selected: selectedSection == _EditorSection.chats,
            onPressed: () => onSectionSelected(_EditorSection.chats),
          ),
          const SizedBox(height: 8),
          _SectionButton(
            label: 'AI Settings',
            icon: Icons.memory,
            selected: selectedSection == _EditorSection.aiSettings,
            onPressed: () => onSectionSelected(_EditorSection.aiSettings),
          ),
          const SizedBox(height: 8),
          _SectionButton(
            label: 'App Settings',
            icon: Icons.tune,
            selected: selectedSection == _EditorSection.appSettings,
            onPressed: () => onSectionSelected(_EditorSection.appSettings),
          ),
          const SizedBox(height: 8),
          _SectionButton(
            label: 'Account',
            icon: Icons.account_circle_outlined,
            selected: selectedSection == _EditorSection.account,
            onPressed: () => onSectionSelected(_EditorSection.account),
          ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: selected ? const Color(0xff2a303b) : null,
          side: BorderSide(
            color: selected ? const Color(0xff697386) : const Color(0xff383f4d),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon),
        label: Text(context.tr(label)),
      ),
    );
  }
}

class _CharactersSection extends StatelessWidget {
  const _CharactersSection({
    required this.settings,
    required this.characters,
    required this.activeCharacterId,
    required this.characterNameController,
    required this.userNameController,
    required this.avatarPathController,
    required this.backgroundPathController,
    required this.firstMessageController,
    required this.promptController,
    required this.scenarioController,
    required this.exampleDialogueController,
    required this.memoryController,
    required this.autoMemoryController,
    required this.loreController,
    required this.isSummarizingMemory,
    required this.onAccentColorChanged,
    required this.onSelectCharacter,
    required this.onCreateCharacter,
    required this.onOpenOnlineCatalog,
    required this.onDuplicateCharacter,
    required this.onDeleteCharacter,
    required this.onPickAvatar,
    required this.onClearAvatar,
    required this.onPickBackground,
    required this.onClearBackground,
    required this.onSummarizeMemory,
    required this.onApply,
  });

  final ChatSettings settings;
  final List<CharacterProfile> characters;
  final String activeCharacterId;
  final TextEditingController characterNameController;
  final TextEditingController userNameController;
  final TextEditingController avatarPathController;
  final TextEditingController backgroundPathController;
  final TextEditingController firstMessageController;
  final TextEditingController promptController;
  final TextEditingController scenarioController;
  final TextEditingController exampleDialogueController;
  final TextEditingController memoryController;
  final TextEditingController autoMemoryController;
  final TextEditingController loreController;
  final bool isSummarizingMemory;
  final ValueChanged<int> onAccentColorChanged;
  final ValueChanged<String> onSelectCharacter;
  final Future<void> Function() onCreateCharacter;
  final Future<void> Function() onOpenOnlineCatalog;
  final ValueChanged<String> onDuplicateCharacter;
  final ValueChanged<String> onDeleteCharacter;
  final Future<void> Function() onPickAvatar;
  final Future<void> Function() onClearAvatar;
  final Future<void> Function() onPickBackground;
  final Future<void> Function() onClearBackground;
  final Future<void> Function() onSummarizeMemory;
  final Future<void> Function({bool showSnack}) onApply;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: context.tr('Library')),
              Tab(text: context.tr('Profile')),
              Tab(text: context.tr('Prompt')),
              Tab(text: context.tr('Memory')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CharacterLibraryTab(
                  settings: settings,
                  characters: characters,
                  activeCharacterId: activeCharacterId,
                  onSelectCharacter: onSelectCharacter,
                  onCreateCharacter: onCreateCharacter,
                  onOpenOnlineCatalog: onOpenOnlineCatalog,
                  onDuplicateCharacter: onDuplicateCharacter,
                  onDeleteCharacter: onDeleteCharacter,
                ),
                _ProfileTab(
                  settings: settings,
                  characterNameController: characterNameController,
                  userNameController: userNameController,
                  avatarPathController: avatarPathController,
                  backgroundPathController: backgroundPathController,
                  firstMessageController: firstMessageController,
                  onAccentColorChanged: onAccentColorChanged,
                  onPickAvatar: onPickAvatar,
                  onClearAvatar: onClearAvatar,
                  onPickBackground: onPickBackground,
                  onClearBackground: onClearBackground,
                  onApply: onApply,
                ),
                _CharacterTab(
                  promptController: promptController,
                  scenarioController: scenarioController,
                  exampleDialogueController: exampleDialogueController,
                  onApply: onApply,
                ),
                _MemoryTab(
                  memoryController: memoryController,
                  autoMemoryController: autoMemoryController,
                  loreController: loreController,
                  isSummarizingMemory: isSummarizingMemory,
                  onSummarizeMemory: onSummarizeMemory,
                  onApply: onApply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterLibraryTab extends StatelessWidget {
  const _CharacterLibraryTab({
    required this.settings,
    required this.characters,
    required this.activeCharacterId,
    required this.onSelectCharacter,
    required this.onCreateCharacter,
    required this.onOpenOnlineCatalog,
    required this.onDuplicateCharacter,
    required this.onDeleteCharacter,
  });

  final ChatSettings settings;
  final List<CharacterProfile> characters;
  final String activeCharacterId;
  final ValueChanged<String> onSelectCharacter;
  final Future<void> Function() onCreateCharacter;
  final Future<void> Function() onOpenOnlineCatalog;
  final ValueChanged<String> onDuplicateCharacter;
  final ValueChanged<String> onDeleteCharacter;

  @override
  Widget build(BuildContext context) {
    return _SettingsList(
      children: [
        FilledButton.icon(
          onPressed: onCreateCharacter,
          icon: const Icon(Icons.add),
          label: Text(context.tr('New character')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onOpenOnlineCatalog,
          icon: const Icon(Icons.public),
          label: Text(context.tr('Online catalog')),
        ),
        const SizedBox(height: 12),
        ...characters.map((character) {
          final selected = character.id == activeCharacterId;
          final characterSettings = character.applyTo(settings);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CharacterTile(
              settings: characterSettings,
              character: character,
              selected: selected,
              canDelete: true,
              onSelect: () => onSelectCharacter(character.id),
              onDuplicate: () => onDuplicateCharacter(character.id),
              onDelete: () => onDeleteCharacter(character.id),
            ),
          );
        }),
      ],
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.settings,
    required this.character,
    required this.selected,
    required this.canDelete,
    required this.onSelect,
    required this.onDuplicate,
    required this.onDelete,
  });

  final ChatSettings settings;
  final CharacterProfile character;
  final bool selected;
  final bool canDelete;
  final VoidCallback onSelect;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff2a303b) : const Color(0xff202530),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? settings.accentColor : const Color(0xff383f4d),
          ),
        ),
        child: Row(
          children: [
            _AvatarBadge(settings: settings, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    character.scenario.trim().isEmpty
                        ? 'No scenario'
                        : character.scenario.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffaab2c0),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Character actions',
              onSelected: (value) {
                switch (value) {
                  case 'duplicate':
                    onDuplicate();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Duplicate'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: canDelete,
                  child: const ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatsSection extends StatelessWidget {
  const _ChatsSection({
    required this.settings,
    required this.chatSessions,
    required this.activeChatId,
    required this.activeCharacterId,
    required this.onClearChat,
    required this.onNewChat,
    required this.onSelectChat,
    required this.onRenameChat,
    required this.onDeleteChat,
  });

  final ChatSettings settings;
  final List<ChatSession> chatSessions;
  final String activeChatId;
  final String activeCharacterId;
  final Future<void> Function() onClearChat;
  final Future<void> Function() onNewChat;
  final ValueChanged<String> onSelectChat;
  final ValueChanged<String> onRenameChat;
  final ValueChanged<String> onDeleteChat;

  @override
  Widget build(BuildContext context) {
    final characterChats =
        chatSessions
            .where((chat) => chat.characterId == activeCharacterId)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return _SettingsList(
      children: [
        FilledButton.icon(
          onPressed: onNewChat,
          icon: const Icon(Icons.add_comment_outlined),
          label: Text(context.tr('Start new chat')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onClearChat,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: Text(context.tr('Clear current chat')),
        ),
        const SizedBox(height: 14),
        if (characterChats.isEmpty)
          _EmptyPane(
            icon: Icons.chat_bubble_outline,
            title: context.tr('No chats yet'),
            body: context.tr('Start a chat for this character.'),
          )
        else
          ...characterChats.map((chat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChatSessionTile(
                chat: chat,
                selected: chat.id == activeChatId,
                canDelete: chatSessions.length > 1,
                accentColor: settings.accentColor,
                onSelect: () => onSelectChat(chat.id),
                onRename: () => onRenameChat(chat.id),
                onDelete: () => onDeleteChat(chat.id),
              ),
            );
          }),
      ],
    );
  }
}

class _ChatSessionTile extends StatelessWidget {
  const _ChatSessionTile({
    required this.chat,
    required this.selected,
    required this.canDelete,
    required this.accentColor,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final ChatSession chat;
  final bool selected;
  final bool canDelete;
  final Color accentColor;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff2a303b) : const Color(0xff202530),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accentColor : const Color(0xff383f4d),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.chat_bubble : Icons.chat_bubble_outline,
              color: selected ? accentColor : const Color(0xffaab2c0),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    chat.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffc8ced8),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${chat.userMessageCount} user · ${chat.assistantMessageCount} assistant',
                    style: const TextStyle(
                      color: Color(0xffaab2c0),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Chat actions',
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    onRename();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.drive_file_rename_outline),
                    title: Text('Rename'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: canDelete,
                  child: const ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff202530),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff383f4d)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xffaab2c0)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xffaab2c0),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FontOption {
  const _FontOption({required this.label, required this.family});

  final String label;
  final String family;
}

const _fontOptions = [
  _FontOption(label: 'System default', family: ''),
  _FontOption(label: 'Segoe UI', family: 'Segoe UI'),
  _FontOption(label: 'Arial', family: 'Arial'),
  _FontOption(label: 'Calibri', family: 'Calibri'),
  _FontOption(label: 'Georgia', family: 'Georgia'),
  _FontOption(label: 'Consolas', family: 'Consolas'),
  _FontOption(label: 'Verdana', family: 'Verdana'),
];

class _AppSettingsSection extends StatelessWidget {
  const _AppSettingsSection({required this.settings, required this.onChanged});

  final UiSettings settings;
  final ValueChanged<UiSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedFont =
        _fontOptions.any((option) => option.family == settings.fontFamily)
        ? settings.fontFamily
        : '';

    return _SettingsList(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AppLanguage>(
            segments: [
              ButtonSegment(
                value: AppLanguage.en,
                icon: const Icon(Icons.language),
                label: Text(context.tr('English')),
              ),
              ButtonSegment(
                value: AppLanguage.ru,
                icon: const Icon(Icons.translate),
                label: Text(context.tr('Russian')),
              ),
            ],
            selected: {settings.language},
            onSelectionChanged: (selection) {
              onChanged(settings.copyWith(language: selection.first));
            },
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: selectedFont,
          decoration: InputDecoration(
            labelText: context.tr('Font'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.text_fields),
          ),
          items: _fontOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option.family,
              child: Text(
                context.tr(option.label),
                style: option.family.isEmpty
                    ? null
                    : TextStyle(fontFamily: option.family),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            onChanged(settings.copyWith(fontFamily: value));
          },
        ),
      ],
    );
  }
}

class _AccountSection extends StatefulWidget {
  const _AccountSection({
    required this.session,
    required this.isLoading,
    required this.isBusy,
    required this.message,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onSignOut,
    required this.onClearMessage,
  });

  final AuthSession? session;
  final bool isLoading;
  final bool isBusy;
  final String? message;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String email, String password) onCreateAccount;
  final Future<void> Function() onSignOut;
  final VoidCallback onClearMessage;

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_refresh);
    _passwordController.addListener(_refresh);
  }

  @override
  void dispose() {
    _emailController.removeListener(_refresh);
    _passwordController.removeListener(_refresh);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canSubmit {
    return !widget.isBusy &&
        _emailController.text.trim().contains('@') &&
        _passwordController.text.length >= 6;
  }

  Future<void> _signIn() async {
    if (!_canSubmit) {
      return;
    }
    await widget.onSignIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  Future<void> _createAccount() async {
    if (!_canSubmit) {
      return;
    }
    await widget.onCreateAccount(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const _SettingsList(
        children: [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    final session = widget.session;
    if (session != null) {
      return _SettingsList(
        children: [
          _AccountCard(session: session),
          if (widget.message != null) ...[
            const SizedBox(height: 14),
            _DismissibleStatus(
              message: widget.message!,
              ok: !widget.message!.toLowerCase().contains('failed'),
              onDismiss: widget.onClearMessage,
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.isBusy ? null : widget.onSignOut,
            icon: widget.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: Text(context.tr('Sign out')),
          ),
        ],
      );
    }

    return _SettingsList(
      children: [
        if (widget.message != null) ...[
          _DismissibleStatus(
            message: widget.message!,
            ok:
                !widget.message!.toLowerCase().contains('failed') &&
                !widget.message!.toLowerCase().contains('expired'),
            onDismiss: widget.onClearMessage,
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: context.tr('Email'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.alternate_email),
          ),
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: context.tr('Password'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _canSubmit ? _signIn : null,
                icon: widget.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(context.tr('Sign in')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _canSubmit ? _createAccount : null,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(context.tr('Create')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff202530),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff383f4d)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xff2a303b),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xff697386)),
            ),
            child: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Signed in'),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  session.user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xffd9dde5)),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  session.user.id,
                  style: const TextStyle(
                    color: Color(0xff7f8796),
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DismissibleStatus extends StatelessWidget {
  const _DismissibleStatus({
    required this.message,
    required this.ok,
    required this.onDismiss,
  });

  final String message;
  final bool ok;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: ok ? const Color(0xff153b2e) : const Color(0xff4a1f28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff383f4d)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          IconButton(
            tooltip: context.tr('Dismiss'),
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff242833),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff383f4d)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xffffb4cc)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xffd9dde5))),
          ),
        ],
      ),
    );
  }
}

class _AiSettingsSection extends StatelessWidget {
  const _AiSettingsSection({
    required this.settings,
    required this.hostController,
    required this.mobileHostController,
    required this.modelController,
    required this.apiBaseUrlController,
    required this.apiKeyController,
    required this.apiModelController,
    required this.isTestingConnection,
    required this.connectionMessage,
    required this.connectionOk,
    required this.onBackendChanged,
    required this.onProviderPresetSelected,
    required this.onMobileModeChanged,
    required this.onTemperatureChanged,
    required this.onContextSizeChanged,
    required this.onMaxTokensChanged,
    required this.onTestConnection,
    required this.onShowPromptDebug,
    required this.onApply,
  });

  final ChatSettings settings;
  final TextEditingController hostController;
  final TextEditingController mobileHostController;
  final TextEditingController modelController;
  final TextEditingController apiBaseUrlController;
  final TextEditingController apiKeyController;
  final TextEditingController apiModelController;
  final bool isTestingConnection;
  final String? connectionMessage;
  final bool? connectionOk;
  final ValueChanged<AiBackend> onBackendChanged;
  final ValueChanged<_ProviderPreset> onProviderPresetSelected;
  final ValueChanged<bool> onMobileModeChanged;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<double> onContextSizeChanged;
  final ValueChanged<double> onMaxTokensChanged;
  final Future<void> Function() onTestConnection;
  final Future<void> Function() onShowPromptDebug;
  final Future<void> Function({bool showSnack}) onApply;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: context.tr('Connection')),
              Tab(text: context.tr('Generation')),
              Tab(text: context.tr('Debug')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ConnectionTab(
                  settings: settings,
                  hostController: hostController,
                  mobileHostController: mobileHostController,
                  modelController: modelController,
                  apiBaseUrlController: apiBaseUrlController,
                  apiKeyController: apiKeyController,
                  apiModelController: apiModelController,
                  isTestingConnection: isTestingConnection,
                  connectionMessage: connectionMessage,
                  connectionOk: connectionOk,
                  onBackendChanged: onBackendChanged,
                  onProviderPresetSelected: onProviderPresetSelected,
                  onMobileModeChanged: onMobileModeChanged,
                  onTestConnection: onTestConnection,
                  onApply: onApply,
                ),
                _GenerationTab(
                  settings: settings,
                  onTemperatureChanged: onTemperatureChanged,
                  onContextSizeChanged: onContextSizeChanged,
                  onMaxTokensChanged: onMaxTokensChanged,
                  onApply: onApply,
                ),
                _PromptDebugTab(
                  onShowPromptDebug: onShowPromptDebug,
                  onApply: onApply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionTab extends StatelessWidget {
  const _ConnectionTab({
    required this.settings,
    required this.hostController,
    required this.mobileHostController,
    required this.modelController,
    required this.apiBaseUrlController,
    required this.apiKeyController,
    required this.apiModelController,
    required this.isTestingConnection,
    required this.connectionMessage,
    required this.connectionOk,
    required this.onBackendChanged,
    required this.onProviderPresetSelected,
    required this.onMobileModeChanged,
    required this.onTestConnection,
    required this.onApply,
  });

  final ChatSettings settings;
  final TextEditingController hostController;
  final TextEditingController mobileHostController;
  final TextEditingController modelController;
  final TextEditingController apiBaseUrlController;
  final TextEditingController apiKeyController;
  final TextEditingController apiModelController;
  final bool isTestingConnection;
  final String? connectionMessage;
  final bool? connectionOk;
  final ValueChanged<AiBackend> onBackendChanged;
  final ValueChanged<_ProviderPreset> onProviderPresetSelected;
  final ValueChanged<bool> onMobileModeChanged;
  final Future<void> Function() onTestConnection;
  final Future<void> Function({bool showSnack}) onApply;

  @override
  Widget build(BuildContext context) {
    final isApi = settings.backend == AiBackend.api;
    return _SettingsList(
      children: [
        _BackendSelector(
          selected: settings.backend,
          onSelected: onBackendChanged,
        ),
        const SizedBox(height: 16),
        _ProviderPresetGrid(onSelected: onProviderPresetSelected),
        const SizedBox(height: 16),
        if (isApi) ...[
          _TextSetting(
            label: context.tr('API base URL'),
            controller: apiBaseUrlController,
            icon: Icons.link,
            hintText: 'https://api.openai.com/v1',
          ),
          const SizedBox(height: 14),
          _TextSetting(
            label: context.tr('API model'),
            controller: apiModelController,
            icon: Icons.memory,
            hintText: 'model id',
          ),
          const SizedBox(height: 14),
          _TextSetting(
            label: context.tr('API key'),
            controller: apiKeyController,
            icon: Icons.key_outlined,
            hintText: 'optional for local servers',
            obscureText: true,
          ),
        ] else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.useMobileHost,
            onChanged: onMobileModeChanged,
            title: Text(context.tr('Phone / local network')),
            subtitle: Text(
              settings.useMobileHost ? settings.mobileHost : settings.host,
            ),
          ),
          _TextSetting(
            label: context.tr('PC address'),
            controller: hostController,
            icon: Icons.computer,
          ),
          const SizedBox(height: 14),
          _TextSetting(
            label: context.tr('Phone address'),
            controller: mobileHostController,
            icon: Icons.phone_android,
          ),
          const SizedBox(height: 14),
          _TextSetting(
            label: context.tr('Ollama model'),
            controller: modelController,
            icon: Icons.memory,
          ),
        ],
        const SizedBox(height: 16),
        _StatusStrip(
          message: connectionMessage ?? _activeConnectionText(settings),
          ok: connectionOk,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isTestingConnection ? null : onTestConnection,
                icon: isTestingConnection
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(context.tr('Test')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onApply(),
                icon: const Icon(Icons.check),
                label: Text(context.tr('Save')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _activeConnectionText(ChatSettings settings) {
    if (settings.backend == AiBackend.api) {
      return 'Active API: ${settings.apiBaseUrl} · ${settings.activeModel}';
    }
    return 'Active address: ${settings.activeHost} · ${settings.model}';
  }
}

class _BackendSelector extends StatelessWidget {
  const _BackendSelector({required this.selected, required this.onSelected});

  final AiBackend selected;
  final ValueChanged<AiBackend> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<AiBackend>(
        segments: [
          ButtonSegment(
            value: AiBackend.ollama,
            icon: const Icon(Icons.computer),
            label: Text(context.tr('Local Ollama')),
          ),
          ButtonSegment(
            value: AiBackend.api,
            icon: const Icon(Icons.cloud_outlined),
            label: Text(context.tr('API')),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onSelected(selection.first),
      ),
    );
  }
}

class _ProviderPresetGrid extends StatelessWidget {
  const _ProviderPresetGrid({required this.onSelected});

  final ValueChanged<_ProviderPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _providerPresets.map((preset) {
        return OutlinedButton.icon(
          onPressed: () => onSelected(preset),
          icon: Icon(preset.icon, size: 18),
          label: Text(preset.label),
        );
      }).toList(),
    );
  }
}

class _PromptDebugTab extends StatelessWidget {
  const _PromptDebugTab({
    required this.onShowPromptDebug,
    required this.onApply,
  });

  final Future<void> Function() onShowPromptDebug;
  final Future<void> Function({bool showSnack}) onApply;

  @override
  Widget build(BuildContext context) {
    return _SettingsList(
      children: [
        OutlinedButton.icon(
          onPressed: onShowPromptDebug,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('View final prompt'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => onApply(),
          icon: const Icon(Icons.check),
          label: const Text('Save before debug'),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.settings,
    required this.characterNameController,
    required this.userNameController,
    required this.avatarPathController,
    required this.backgroundPathController,
    required this.firstMessageController,
    required this.onAccentColorChanged,
    required this.onPickAvatar,
    required this.onClearAvatar,
    required this.onPickBackground,
    required this.onClearBackground,
    required this.onApply,
  });

  final ChatSettings settings;
  final TextEditingController characterNameController;
  final TextEditingController userNameController;
  final TextEditingController avatarPathController;
  final TextEditingController backgroundPathController;
  final TextEditingController firstMessageController;
  final ValueChanged<int> onAccentColorChanged;
  final Future<void> Function() onPickAvatar;
  final Future<void> Function() onClearAvatar;
  final Future<void> Function() onPickBackground;
  final Future<void> Function() onClearBackground;
  final Future<void> Function({bool showSnack}) onApply;

  @override
  Widget build(BuildContext context) {
    return _SettingsList(
      children: [
        _TextSetting(
          label: context.tr('Character name'),
          controller: characterNameController,
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 14),
        _TextSetting(
          label: context.tr('Your name'),
          controller: userNameController,
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 18),
        _ImagePickerRow(
          title: context.tr('Avatar'),
          pathController: avatarPathController,
          preview: _AvatarBadge(settings: settings, size: 72),
          onPick: onPickAvatar,
          onClear: onClearAvatar,
        ),
        const SizedBox(height: 18),
        _ImagePickerRow(
          title: context.tr('Background'),
          pathController: backgroundPathController,
          preview: _BackgroundThumb(path: settings.backgroundPath),
          onPick: onPickBackground,
          onClear: onClearBackground,
        ),
        const SizedBox(height: 18),
        _ColorSwatches(
          selected: settings.accentColorValue,
          onSelected: onAccentColorChanged,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: firstMessageController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: context.tr('First message'),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.waving_hand_outlined),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => onApply(),
          icon: const Icon(Icons.check),
          label: Text(context.tr('Save profile')),
        ),
      ],
    );
  }
}

class _CharacterTab extends StatelessWidget {
  const _CharacterTab({
    required this.promptController,
    required this.scenarioController,
    required this.exampleDialogueController,
    required this.onApply,
  });

  final TextEditingController promptController;
  final TextEditingController scenarioController;
  final TextEditingController exampleDialogueController;
  final Future<void> Function({bool showSnack}) onApply;

  @override
  Widget build(BuildContext context) {
    return _SettingsList(
      children: [
        TextField(
          controller: scenarioController,
          minLines: 5,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: context.tr('Scenario'),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.map_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: promptController,
          minLines: 9,
          maxLines: 14,
          decoration: InputDecoration(
            labelText: context.tr('Character prompt'),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.theater_comedy_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: exampleDialogueController,
          minLines: 6,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: context.tr('Example dialogue'),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.forum_outlined),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => onApply(),
          icon: const Icon(Icons.check),
          label: Text(context.tr('Save character')),
        ),
      ],
    );
  }
}

class _MemoryTab extends StatelessWidget {
  const _MemoryTab({
    required this.memoryController,
    required this.autoMemoryController,
    required this.loreController,
    required this.isSummarizingMemory,
    required this.onSummarizeMemory,
    required this.onApply,
  });

  final TextEditingController memoryController;
  final TextEditingController autoMemoryController;
  final TextEditingController loreController;
  final bool isSummarizingMemory;
  final Future<void> Function() onSummarizeMemory;
  final Future<void> Function({bool showSnack}) onApply;

  @override
  Widget build(BuildContext context) {
    return _SettingsList(
      children: [
        TextField(
          controller: memoryController,
          minLines: 7,
          maxLines: 12,
          decoration: InputDecoration(
            labelText: context.tr('Persistent memory'),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.psychology_alt_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: autoMemoryController,
          minLines: 6,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: context.tr('Auto chat memory'),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.auto_awesome_outlined),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: isSummarizingMemory ? null : onSummarizeMemory,
          icon: isSummarizingMemory
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.summarize_outlined),
          label: Text(context.tr('Summarize current chat')),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: loreController,
          minLines: 7,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'Lore / facts',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.menu_book_outlined),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => onApply(),
          icon: const Icon(Icons.check),
          label: Text(context.tr('Save memory')),
        ),
      ],
    );
  }
}

class _GenerationTab extends StatelessWidget {
  const _GenerationTab({
    required this.settings,
    required this.onTemperatureChanged,
    required this.onContextSizeChanged,
    required this.onMaxTokensChanged,
    required this.onApply,
  });

  final ChatSettings settings;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<double> onContextSizeChanged;
  final ValueChanged<double> onMaxTokensChanged;
  final Future<void> Function({bool showSnack}) onApply;

  @override
  Widget build(BuildContext context) {
    return _SettingsList(
      children: [
        _SliderSetting(
          label: context.tr('Temperature'),
          value: settings.temperature,
          min: 0.1,
          max: 1.4,
          divisions: 13,
          displayValue: settings.temperature.toStringAsFixed(1),
          onChanged: onTemperatureChanged,
        ),
        const SizedBox(height: 16),
        _SliderSetting(
          label: context.tr('Context'),
          value: settings.contextSize.toDouble(),
          min: 2048,
          max: 16384,
          divisions: 7,
          displayValue: settings.contextSize.toString(),
          onChanged: onContextSizeChanged,
        ),
        const SizedBox(height: 16),
        _SliderSetting(
          label: context.tr('Max tokens'),
          value: settings.maxTokens.toDouble(),
          min: 128,
          max: 1200,
          divisions: 16,
          displayValue: settings.maxTokens.toString(),
          onChanged: onMaxTokensChanged,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => onApply(),
          icon: const Icon(Icons.check),
          label: Text(context.tr('Save generation')),
        ),
      ],
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      children: children,
    );
  }
}

class _CharacterCreationDraft {
  const _CharacterCreationDraft({
    required this.profile,
    required this.isPublic,
    required this.description,
    required this.tags,
  });

  final CharacterProfile profile;
  final bool isPublic;
  final String description;
  final List<String> tags;
}

class _OnlineCharacterEditDraft {
  const _OnlineCharacterEditDraft({
    required this.profile,
    required this.description,
    required this.tags,
  });

  final CharacterProfile profile;
  final String description;
  final List<String> tags;
}

class _CreateCharacterDialog extends StatefulWidget {
  const _CreateCharacterDialog({
    required this.accentColorValue,
    required this.userName,
    required this.canPublishPublic,
  });

  final int accentColorValue;
  final String userName;
  final bool canPublishPublic;

  @override
  State<_CreateCharacterDialog> createState() => _CreateCharacterDialogState();
}

class _CreateCharacterDialogState extends State<_CreateCharacterDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late final TextEditingController _userNameController;
  late final TextEditingController _avatarPathController;
  late final TextEditingController _backgroundPathController;
  late final TextEditingController _firstMessageController;
  late final TextEditingController _scenarioController;
  late final TextEditingController _promptController;
  late final TextEditingController _exampleDialogueController;
  late int _accentColorValue;
  var _isPublic = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagsController = TextEditingController();
    _userNameController = TextEditingController(text: widget.userName);
    _avatarPathController = TextEditingController();
    _backgroundPathController = TextEditingController();
    _firstMessageController = TextEditingController();
    _scenarioController = TextEditingController();
    _promptController = TextEditingController();
    _exampleDialogueController = TextEditingController();
    _accentColorValue = widget.accentColorValue;
    _nameController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _userNameController.dispose();
    _avatarPathController.dispose();
    _backgroundPathController.dispose();
    _firstMessageController.dispose();
    _scenarioController.dispose();
    _promptController.dispose();
    _exampleDialogueController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canCreate => _nameController.text.trim().isNotEmpty;

  List<String> get _tags => _tagsController.text
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .take(8)
      .toList();

  ChatSettings get _previewSettings => ChatSettings.defaults.copyWith(
    characterName: _nameController.text.trim(),
    userName: _userNameController.text.trim(),
    avatarPath: _avatarPathController.text.trim(),
    backgroundPath: _backgroundPathController.text.trim(),
    accentColorValue: _accentColorValue,
    firstMessage: _firstMessageController.text.trim(),
    scenario: _scenarioController.text.trim(),
    systemPrompt: _promptController.text.trim(),
    exampleDialogue: _exampleDialogueController.text.trim(),
  );

  Future<void> _pickImage(TextEditingController controller) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
        ),
      ],
    );

    if (file == null) {
      return;
    }

    setState(() {
      controller.text = file.path;
    });
  }

  void _submit() {
    if (!_canCreate) {
      return;
    }

    final now = DateTime.now();
    final settings = _previewSettings;
    Navigator.of(context).pop(
      _CharacterCreationDraft(
        isPublic: _isPublic,
        description: _descriptionController.text.trim(),
        tags: _tags,
        profile: CharacterProfile.fromSettings(
          settings,
          id: 'draft_character',
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _previewSettings;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
                child: Row(
                  children: [
                    _AvatarBadge(settings: settings, size: 50),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Create character',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.badge_outlined), text: 'Profile'),
                  Tab(
                    icon: Icon(Icons.theater_comedy_outlined),
                    text: 'Prompt',
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _DialogSettingsList(
                      children: [
                        TextField(
                          controller: _nameController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Character name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.lock_outline),
                                label: Text('Private'),
                              ),
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.public),
                                label: Text('Public'),
                              ),
                            ],
                            selected: {_isPublic},
                            onSelectionChanged: (selection) {
                              setState(() => _isPublic = selection.first);
                            },
                          ),
                        ),
                        if (_isPublic && !widget.canPublishPublic) ...[
                          const SizedBox(height: 10),
                          const _InlineNotice(
                            icon: Icons.lock_outline,
                            text:
                                'Sign in to publish. This will be saved locally.',
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Card description',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _TextSetting(
                          label: 'Tags',
                          controller: _tagsController,
                          icon: Icons.sell_outlined,
                          hintText: 'anime, drama, writer',
                        ),
                        const SizedBox(height: 14),
                        _TextSetting(
                          label: 'Your name',
                          controller: _userNameController,
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 18),
                        _ImagePickerRow(
                          title: 'Avatar',
                          pathController: _avatarPathController,
                          preview: _AvatarBadge(settings: settings, size: 72),
                          onPick: () => _pickImage(_avatarPathController),
                          onClear: () async {
                            setState(_avatarPathController.clear);
                          },
                        ),
                        const SizedBox(height: 18),
                        _ImagePickerRow(
                          title: 'Background',
                          pathController: _backgroundPathController,
                          preview: _BackgroundThumb(
                            path: settings.backgroundPath,
                          ),
                          onPick: () => _pickImage(_backgroundPathController),
                          onClear: () async {
                            setState(_backgroundPathController.clear);
                          },
                        ),
                        const SizedBox(height: 18),
                        _ColorSwatches(
                          selected: _accentColorValue,
                          onSelected: (value) {
                            setState(() => _accentColorValue = value);
                          },
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _firstMessageController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'First message',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.waving_hand_outlined),
                          ),
                        ),
                      ],
                    ),
                    _DialogSettingsList(
                      children: [
                        TextField(
                          controller: _scenarioController,
                          minLines: 5,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Scenario',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _promptController,
                          minLines: 8,
                          maxLines: 12,
                          decoration: const InputDecoration(
                            labelText: 'Character prompt',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.theater_comedy_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _exampleDialogueController,
                          minLines: 5,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Example dialogue',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.forum_outlined),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xff2a303b))),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _canCreate ? _submit : null,
                      icon: Icon(_isPublic ? Icons.public : Icons.add),
                      label: Text(_isPublic ? 'Create public' : 'Create'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditOnlineCharacterDialog extends StatefulWidget {
  const _EditOnlineCharacterDialog({required this.character});

  final OnlineCharacter character;

  @override
  State<_EditOnlineCharacterDialog> createState() =>
      _EditOnlineCharacterDialogState();
}

class _EditOnlineCharacterDialogState
    extends State<_EditOnlineCharacterDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late final TextEditingController _userNameController;
  late final TextEditingController _avatarPathController;
  late final TextEditingController _backgroundPathController;
  late final TextEditingController _firstMessageController;
  late final TextEditingController _scenarioController;
  late final TextEditingController _promptController;
  late final TextEditingController _exampleDialogueController;
  late int _accentColorValue;

  @override
  void initState() {
    super.initState();
    final character = widget.character;
    _nameController = TextEditingController(text: character.name);
    _descriptionController = TextEditingController(text: character.description);
    _tagsController = TextEditingController(text: character.tags.join(', '));
    _userNameController = TextEditingController(text: character.authorName);
    _avatarPathController = TextEditingController(text: character.avatarUrl);
    _backgroundPathController = TextEditingController(
      text: character.backgroundUrl,
    );
    _firstMessageController = TextEditingController(
      text: character.firstMessage,
    );
    _scenarioController = TextEditingController(text: character.scenario);
    _promptController = TextEditingController(text: character.systemPrompt);
    _exampleDialogueController = TextEditingController(
      text: character.exampleDialogue,
    );
    _accentColorValue = ChatSettings.defaults.accentColorValue;
    _nameController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _userNameController.dispose();
    _avatarPathController.dispose();
    _backgroundPathController.dispose();
    _firstMessageController.dispose();
    _scenarioController.dispose();
    _promptController.dispose();
    _exampleDialogueController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  List<String> get _tags => _tagsController.text
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .take(8)
      .toList();

  ChatSettings get _previewSettings => ChatSettings.defaults.copyWith(
    characterName: _nameController.text.trim(),
    userName: _userNameController.text.trim(),
    avatarPath: _avatarPathController.text.trim(),
    backgroundPath: _backgroundPathController.text.trim(),
    accentColorValue: _accentColorValue,
    firstMessage: _firstMessageController.text.trim(),
    scenario: _scenarioController.text.trim(),
    systemPrompt: _promptController.text.trim(),
    exampleDialogue: _exampleDialogueController.text.trim(),
  );

  Future<void> _pickImage(TextEditingController controller) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
        ),
      ],
    );

    if (file == null) {
      return;
    }

    setState(() {
      controller.text = file.path;
    });
  }

  void _submit() {
    if (!_canSave) {
      return;
    }

    final now = DateTime.now();
    final settings = _previewSettings;
    Navigator.of(context).pop(
      _OnlineCharacterEditDraft(
        description: _descriptionController.text.trim(),
        tags: _tags,
        profile: CharacterProfile.fromSettings(
          settings,
          id: 'online_${widget.character.id}',
          createdAt: widget.character.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _previewSettings;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
                child: Row(
                  children: [
                    _AvatarBadge(settings: settings, size: 50),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Edit published character',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.badge_outlined), text: 'Profile'),
                  Tab(
                    icon: Icon(Icons.theater_comedy_outlined),
                    text: 'Prompt',
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _DialogSettingsList(
                      children: [
                        TextField(
                          controller: _nameController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Character name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Card description',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _TextSetting(
                          label: 'Tags',
                          controller: _tagsController,
                          icon: Icons.sell_outlined,
                          hintText: 'anime, drama, writer',
                        ),
                        const SizedBox(height: 14),
                        _TextSetting(
                          label: 'Author name',
                          controller: _userNameController,
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 18),
                        _ImagePickerRow(
                          title: 'Avatar',
                          pathController: _avatarPathController,
                          preview: _AvatarBadge(settings: settings, size: 72),
                          onPick: () => _pickImage(_avatarPathController),
                          onClear: () async {
                            setState(_avatarPathController.clear);
                          },
                        ),
                        const SizedBox(height: 18),
                        _ImagePickerRow(
                          title: 'Background',
                          pathController: _backgroundPathController,
                          preview: _BackgroundThumb(
                            path: settings.backgroundPath,
                          ),
                          onPick: () => _pickImage(_backgroundPathController),
                          onClear: () async {
                            setState(_backgroundPathController.clear);
                          },
                        ),
                        const SizedBox(height: 18),
                        _ColorSwatches(
                          selected: _accentColorValue,
                          onSelected: (value) {
                            setState(() => _accentColorValue = value);
                          },
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _firstMessageController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'First message',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.waving_hand_outlined),
                          ),
                        ),
                      ],
                    ),
                    _DialogSettingsList(
                      children: [
                        TextField(
                          controller: _scenarioController,
                          minLines: 5,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Scenario',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _promptController,
                          minLines: 8,
                          maxLines: 12,
                          decoration: const InputDecoration(
                            labelText: 'Character prompt',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.theater_comedy_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _exampleDialogueController,
                          minLines: 5,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Example dialogue',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.forum_outlined),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xff2a303b))),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _canSave ? _submit : null,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save changes'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogSettingsList extends StatelessWidget {
  const _DialogSettingsList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      children: children,
    );
  }
}

class _OnlineCatalogDialog extends StatefulWidget {
  const _OnlineCatalogDialog({required this.session});

  final AuthSession? session;

  @override
  State<_OnlineCatalogDialog> createState() => _OnlineCatalogDialogState();
}

class _OnlineCatalogDialogState extends State<_OnlineCatalogDialog> {
  final _client = OnlineCatalogClient();
  final _searchController = TextEditingController();
  final _deletingIds = <String>{};
  final _updatingIds = <String>{};
  late Future<List<OnlineCharacter>> _future;

  @override
  void initState() {
    super.initState();
    _future = _client.fetchCharacters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _client.fetchCharacters(query: _searchController.text);
    });
  }

  Future<void> _deleteCharacter(OnlineCharacter character) async {
    final session = widget.session;
    if (session == null || character.ownerId != session.user.id) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete public character'),
          content: Text(
            'Remove "${character.name}" from the online catalog? Local copies and imported chats will stay untouched.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deletingIds.add(character.id));
    try {
      await _client.deleteCharacter(
        characterId: character.id,
        accessToken: session.accessToken,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted from online catalog')),
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(character.id));
      }
    }
  }

  Future<void> _editCharacter(OnlineCharacter character) async {
    final session = widget.session;
    if (session == null || character.ownerId != session.user.id) {
      return;
    }

    final draft = await showDialog<_OnlineCharacterEditDraft>(
      context: context,
      builder: (context) => _EditOnlineCharacterDialog(character: character),
    );
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _updatingIds.add(character.id));
    try {
      await _client.updateCharacter(
        character,
        draft.profile,
        description: draft.description,
        tags: draft.tags,
        accessToken: session.accessToken,
        authorName: session.user.displayName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Updated online character')));
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(character.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.public, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Online catalog',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search characters',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: _reload,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _reload(),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<OnlineCharacter>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _OnlineCatalogMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Catalog is unavailable',
                      message: snapshot.error.toString(),
                      action: OutlinedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    );
                  }

                  final characters = snapshot.data ?? const <OnlineCharacter>[];
                  if (characters.isEmpty) {
                    return const _OnlineCatalogMessage(
                      icon: Icons.inventory_2_outlined,
                      title: 'No characters yet',
                      message: 'Add rows to the Supabase characters table.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(18),
                    itemCount: characters.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final character = characters[index];
                      final canDelete =
                          widget.session != null &&
                          character.ownerId == widget.session!.user.id;
                      return _OnlineCharacterTile(
                        character: character,
                        canDelete: canDelete,
                        canEdit: canDelete,
                        isDeleting: _deletingIds.contains(character.id),
                        isUpdating: _updatingIds.contains(character.id),
                        onImport: () => Navigator.of(context).pop(character),
                        onEdit: () => _editCharacter(character),
                        onDelete: () => _deleteCharacter(character),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineCharacterTile extends StatelessWidget {
  const _OnlineCharacterTile({
    required this.character,
    required this.canDelete,
    required this.canEdit,
    required this.isDeleting,
    required this.isUpdating,
    required this.onImport,
    required this.onEdit,
    required this.onDelete,
  });

  final OnlineCharacter character;
  final bool canDelete;
  final bool canEdit;
  final bool isDeleting;
  final bool isUpdating;
  final VoidCallback onImport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isBusy = isDeleting || isUpdating;
    final description = character.description.trim().isNotEmpty
        ? character.description.trim()
        : character.scenario.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff202530),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff383f4d)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NetworkThumb(url: character.avatarUrl, size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                if (description.trim().isNotEmpty)
                  Text(
                    description.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffaab2c0),
                      height: 1.3,
                      letterSpacing: 0,
                    ),
                  ),
                if (character.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: character.tags.take(4).map((tag) {
                      return _SmallChip(label: tag);
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  [
                    if (character.authorName.trim().isNotEmpty)
                      'by ${character.authorName.trim()}',
                    '${character.likes} likes',
                    '${character.downloads} imports',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff7f8796),
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: isBusy ? null : onImport,
                icon: const Icon(Icons.download),
                label: const Text('Import'),
              ),
              if (canEdit) ...[
                const SizedBox(height: 8),
                IconButton.outlined(
                  tooltip: 'Edit published bot',
                  onPressed: isBusy ? null : onEdit,
                  icon: isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_outlined),
                ),
              ],
              if (canDelete) ...[
                const SizedBox(height: 8),
                IconButton.outlined(
                  tooltip: 'Delete from catalog',
                  onPressed: isBusy ? null : onDelete,
                  icon: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  const _NetworkThumb({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = url.trim();
    final dataUriBytes = _imageDataUriBytes(trimmedUrl);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xff2a303b),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff383f4d)),
      ),
      child: dataUriBytes != null
          ? Image.memory(dataUriBytes, fit: BoxFit.cover)
          : _isHttpUrl(trimmedUrl)
          ? Image.network(
              trimmedUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported_outlined);
              },
            )
          : const Icon(Icons.person_outline),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff2a303b),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff383f4d)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, letterSpacing: 0),
      ),
    );
  }
}

class _OnlineCatalogMessage extends StatelessWidget {
  const _OnlineCatalogMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: const Color(0xffffb4cc)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xffaab2c0), height: 1.35),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

class _EmptyChatPanel extends StatelessWidget {
  const _EmptyChatPanel({
    required this.showSettingsButton,
    required this.accentColor,
    required this.onOpenSettings,
    required this.onCreateCharacter,
  });

  final bool showSettingsButton;
  final Color accentColor;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onCreateCharacter;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xff14171d)),
          ),
        ),
        if (showSettingsButton)
          Positioned(
            top: 14,
            right: 14,
            child: IconButton.filledTonal(
              tooltip: 'Settings',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune),
            ),
          ),
        Center(
          child: FilledButton.icon(
            onPressed: () {
              onCreateCharacter();
            },
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('New character'),
          ),
        ),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.settings,
    required this.isSending,
    required this.showSettingsButton,
    required this.onOpenSettings,
    required this.onClearChat,
  });

  final ChatSettings settings;
  final bool isSending;
  final bool showSettingsButton;
  final VoidCallback onOpenSettings;
  final VoidCallback onClearChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xff191d25),
        border: Border(bottom: BorderSide(color: Color(0xff2a303b))),
      ),
      child: Row(
        children: [
          _AvatarBadge(settings: settings, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.characterName.trim().isEmpty
                      ? 'TF.ai'
                      : settings.characterName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isSending
                            ? const Color(0xffffc857)
                            : const Color(0xff42d392),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${settings.backendLabel} · ${settings.activeModel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffaab2c0),
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: onClearChat,
            icon: const Icon(Icons.delete_outline),
          ),
          if (showSettingsButton)
            IconButton(
              tooltip: 'Settings',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune),
            ),
        ],
      ),
    );
  }
}

class _ChatBackdrop extends StatelessWidget {
  const _ChatBackdrop({required this.backgroundPath, required this.child});

  final String backgroundPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final normalizedPath = backgroundPath.trim();
    final dataUriBytes = _imageDataUriBytes(normalizedPath);
    final file = _fileOrNull(normalizedPath);

    return Stack(
      children: [
        Positioned.fill(
          child: file != null
              ? Image.file(file, fit: BoxFit.cover)
              : dataUriBytes != null
              ? Image.memory(dataUriBytes, fit: BoxFit.cover)
              : _isHttpUrl(normalizedPath)
              ? Image.network(
                  normalizedPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xff14171d)),
                    );
                  },
                )
              : const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xff14171d)),
                ),
        ),
        Positioned.fill(child: Container(color: const Color(0xcc14171d))),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.index,
    required this.message,
    required this.settings,
    required this.onOpenMenu,
  });

  final int index;
  final ChatMessage message;
  final ChatSettings settings;
  final void Function(int index, Offset position) onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xff244054) : const Color(0xff242833),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: Radius.circular(isUser ? 8 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 8),
          ),
          border: Border.all(
            color: isUser ? const Color(0xff3f6c86) : const Color(0xff383f4d),
          ),
        ),
        child: SelectableText(
          message.content,
          style: const TextStyle(fontSize: 15, height: 1.42, letterSpacing: 0),
        ),
      ),
    );

    Widget withMenu(Widget child) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) {
          onOpenMenu(index, details.globalPosition);
        },
        onLongPressStart: (details) {
          onOpenMenu(index, details.globalPosition);
        },
        child: child,
      );
    }

    if (!isUser) {
      return withMenu(
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarBadge(settings: settings, size: 34),
              const SizedBox(width: 10),
              Flexible(child: bubble),
            ],
          ),
        ),
      );
    }

    return withMenu(Align(alignment: Alignment.centerRight, child: bubble));
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.settings});

  final ChatSettings settings;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarBadge(settings: settings, size: 34),
            const SizedBox(width: 10),
            const _DotsIndicator(),
          ],
        ),
      ),
    );
  }
}

class _ChatActions extends StatelessWidget {
  const _ChatActions({
    required this.isSending,
    required this.canRegenerate,
    required this.canEditLast,
    required this.onStop,
    required this.onRegenerate,
    required this.onEditLast,
  });

  final bool isSending;
  final bool canRegenerate;
  final bool canEditLast;
  final VoidCallback onStop;
  final VoidCallback onRegenerate;
  final VoidCallback onEditLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      color: const Color(0xff191d25),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: isSending ? onStop : null,
            icon: const Icon(Icons.stop),
            label: Text(context.tr('Stop')),
          ),
          OutlinedButton.icon(
            onPressed: !isSending && canRegenerate ? onRegenerate : null,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('Regenerate')),
          ),
          OutlinedButton.icon(
            onPressed: !isSending && canEditLast ? onEditLast : null,
            icon: const Icon(Icons.edit_outlined),
            label: Text(context.tr('Edit last')),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.accentColor,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final Color accentColor;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: const BoxDecoration(
        color: Color(0xff191d25),
        border: Border(top: BorderSide(color: Color(0xff2a303b))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: context.tr('Message'),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: const Color(0xff202530),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            height: 52,
            child: FilledButton(
              onPressed: isSending ? null : onSend,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.settings, required this.size});

  final ChatSettings settings;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalizedPath = settings.avatarPath.trim();
    final dataUriBytes = _imageDataUriBytes(normalizedPath);
    final file = _fileOrNull(normalizedPath);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color.lerp(settings.accentColor, const Color(0xff1b1f27), 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: settings.accentColor),
      ),
      child: file != null
          ? Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: const Color(0xffffd7e3),
                    size: size * 0.46,
                  ),
                );
              },
            )
          : dataUriBytes != null
          ? Image.memory(
              dataUriBytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
          : _isHttpUrl(normalizedPath)
          ? Image.network(
              normalizedPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _InitialAvatarText(
                  initial: _initialFor(settings.characterName),
                  size: size,
                );
              },
            )
          : _InitialAvatarText(
              initial: _initialFor(settings.characterName),
              size: size,
            ),
    );
  }

  String _initialFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.characters.first.toUpperCase();
  }
}

class _InitialAvatarText extends StatelessWidget {
  const _InitialAvatarText({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: const Color(0xffffd7e3),
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _BackgroundThumb extends StatelessWidget {
  const _BackgroundThumb({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final normalizedPath = path.trim();
    final dataUriBytes = _imageDataUriBytes(normalizedPath);
    final file = _fileOrNull(normalizedPath);

    return Container(
      width: 96,
      height: 62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xff242833),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff383f4d)),
      ),
      child: file != null
          ? Image.file(file, fit: BoxFit.cover)
          : dataUriBytes != null
          ? Image.memory(dataUriBytes, fit: BoxFit.cover)
          : _isHttpUrl(normalizedPath)
          ? Image.network(
              normalizedPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.wallpaper_outlined,
                  color: Color(0xffaab2c0),
                );
              },
            )
          : const Icon(Icons.wallpaper_outlined, color: Color(0xffaab2c0)),
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  const _ImagePickerRow({
    required this.title,
    required this.pathController,
    required this.preview,
    required this.onPick,
    required this.onClear,
  });

  final String title;
  final TextEditingController pathController;
  final Widget preview;
  final Future<void> Function() onPick;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        preview,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TextSetting(
                label: title,
                controller: pathController,
                icon: Icons.image_outlined,
                readOnly: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.folder_open),
                    label: Text(context.tr('Choose')),
                  ),
                  IconButton.outlined(
                    tooltip: context.tr('Remove'),
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const colors = [
    0xffb14c70,
    0xffd25f45,
    0xffb59b35,
    0xff2f9d7e,
    0xff4777d9,
    0xff9b6bd3,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((value) {
        final isSelected = value == selected;
        return Tooltip(
          message: 'Accent color',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelected(value),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Color(value),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.white : const Color(0xff383f4d),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 18) : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TextSetting extends StatelessWidget {
  const _TextSetting({
    required this.label,
    required this.controller,
    required this.icon,
    this.readOnly = false,
    this.hintText,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool readOnly;
  final String? hintText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscureText,
      enableSuggestions: !obscureText,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xffd9dde5),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              displayValue,
              style: const TextStyle(
                color: Color(0xffaab2c0),
                fontFeatures: [FontFeature.tabularFigures()],
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.message, required this.ok});

  final String message;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final color = ok == null
        ? const Color(0xff242833)
        : ok!
        ? const Color(0xff153b2e)
        : const Color(0xff4a1f28);
    final icon = ok == null
        ? Icons.info_outline
        : ok!
        ? Icons.check_circle_outline
        : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff383f4d)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
      color: const Color(0xff4a1f28),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xffffc2cc)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xffffd8df),
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatefulWidget {
  const _DotsIndicator();

  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 72,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xff242833),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xff383f4d)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final phase = ((_controller.value * 3) - index).clamp(0.0, 1.0);
              return Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xff596273),
                    const Color(0xffffb4cc),
                    phase,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

File? _fileOrNull(String rawPath) {
  final normalizedPath = rawPath.trim();
  if (normalizedPath.isEmpty) {
    return null;
  }
  if (_isHttpUrl(normalizedPath) ||
      _imageDataUriBytes(normalizedPath) != null) {
    return null;
  }

  try {
    final file = File(normalizedPath);
    return file.existsSync() ? file : null;
  } on FileSystemException {
    return null;
  }
}

bool _isHttpUrl(String rawValue) {
  final uri = Uri.tryParse(rawValue.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

Uint8List? _imageDataUriBytes(String rawValue) {
  final value = rawValue.trim();
  final commaIndex = value.indexOf(',');
  if (!value.startsWith('data:image/') || commaIndex == -1) {
    return null;
  }

  try {
    return base64Decode(value.substring(commaIndex + 1));
  } on FormatException {
    return null;
  }
}
