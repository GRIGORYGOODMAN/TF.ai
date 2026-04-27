# TF.ai

**Version:** 0.01 alpha

TF.ai is a local-first character chat client built with Flutter. It can talk to a local Ollama server or to any OpenAI-compatible chat completions API.

The app is designed for private character chats, editable character profiles, per-chat memory, and simple desktop-first use before mobile packaging.

## Features

- Local Ollama mode
- OpenAI-compatible API mode
- Character library
- Multiple chats per character
- Editable system prompt, scenario, first message, examples, memory, and lore
- Manual and generated chat memory summaries
- Avatar and background image picker
- Provider presets for Ollama, LM Studio, OpenAI, and OpenRouter
- Final prompt debug viewer
- Supabase-backed public catalog
- Supabase email/password accounts for publishing
- Windows desktop build
- Android project scaffold

## Requirements

- Flutter 3.41 or newer
- Dart 3.11 or newer
- Windows, macOS, Linux, or Android toolchain depending on target
- Optional: Ollama for local models

## Quick Start

```powershell
flutter pub get
flutter run -d windows
```

For a release build on Windows:

```powershell
flutter build windows
```

The Windows release output is created in:

```text
build/windows/x64/runner/Release
```

Zip the entire `Release` folder for a GitHub Release. Do not upload only the `.exe`, because Flutter desktop apps need the adjacent DLL and data files.

## Ollama Setup

Install Ollama, pull a model, and keep the server running:

```powershell
ollama pull qwen3.5:latest
ollama serve
```

In TF.ai:

1. Open `AI Settings`.
2. Choose `Local Ollama`.
3. Set the PC address to `http://localhost:11434`.
4. Set the model name to the model you pulled.
5. Press `Test`.

## API Setup

TF.ai supports OpenAI-compatible `/v1/chat/completions` providers.

In `AI Settings`:

1. Choose `API`.
2. Set `API base URL`.
3. Set `API model`.
4. Paste your API key if the provider requires one.
5. Press `Test`.

Examples:

- OpenAI: `https://api.openai.com/v1`
- OpenRouter: `https://openrouter.ai/api/v1`
- LM Studio: `http://localhost:1234/v1`

## Online Catalog

Run `docs/supabase-schema.sql` in the Supabase SQL Editor before publishing
public characters. Account setup notes are in `docs/supabase-auth-setup.md`.

## GitHub Pages Docs

The static documentation site lives in `docs/`.

To publish it:

1. Push this repository to GitHub.
2. Open repository `Settings`.
3. Open `Pages`.
4. Set source to `Deploy from a branch`.
5. Choose the `main` branch and `/docs` folder.

## Privacy

TF.ai stores app data locally through Flutter shared preferences. Chats, characters, and settings remain on the user's device unless the user chooses an external API provider. API keys are stored locally by the app and are sent only to the configured provider.

## Disclaimer

TF.ai is an unofficial character chat client. Do not include copyrighted character art, proprietary prompts, API keys, private chats, or third-party assets in the public repository unless you have permission to publish them.

## License

MIT. See [LICENSE](LICENSE).
