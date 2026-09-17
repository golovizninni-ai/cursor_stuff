# Чат playerbots через Ollama (опция)

Только **playerbots** и только **нативная** установка. Нужен GPU на ВМ (1660 Ti / 3070 Ti).

```bash
./scripts/enable-ollama-chat.sh playerbots
```

1660 Ti 6 ГБ → модель по умолчанию `qwen2.5:3b`.  
После 3070 Ti:

```bash
OLLAMA_MODEL=qwen2.5:7b ./scripts/enable-ollama-chat.sh playerbots
```

Скрипт ставит Ollama на хост, качает модель, клонирует `mod-ollama-chat`, пересобирает worldserver.

Проверка:

```bash
curl -s http://127.0.0.1:11434/api/tags
```

В игре: шепот боту по-русски; ГМ `.ollama reload`.  
**TCP 11434** друзьям не пробрасывать.
