# Запустить на Windows (PowerShell от администратора), чтобы хаб в LAN видел Ollama.
# Слушать все интерфейсы: в системных переменных OLLAMA_HOST=0.0.0.0:11434 и перезапуск службы Ollama.

New-NetFirewallRule -DisplayName "Ollama LAN 11434" `
  -Direction Inbound -Protocol TCP -LocalPort 11434 `
  -Action Allow -Profile Private
Write-Host "Правило firewall добавлено (профиль Private). OLLAMA_HOST=0.0.0.0:11434"
