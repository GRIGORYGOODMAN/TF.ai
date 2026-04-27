# Privacy

TF.ai is local-first.

## Local Data

The app stores characters, chats, prompts, provider settings, and memory locally using Flutter shared preferences.

## API Providers

When API mode is enabled, chat content is sent to the configured API provider so the provider can generate a response. The app does not send chat content to any other service.

API keys are stored locally by the app. Treat your local device profile as sensitive if you store provider keys.

## Local Providers

When Ollama or a local OpenAI-compatible server is used, requests stay on the configured local or LAN endpoint.

## Public Repositories

Do not commit private chat exports, API keys, local configuration files, copyrighted assets, or personal images.
