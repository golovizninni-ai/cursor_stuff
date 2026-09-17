#!/usr/bin/env bash
# Нативная установка / доустановка варианта поверх уже стоящего.
# Карты (AC_DATA), пароль MySQL и IP реалма — общие. У каждого варианта своя БД мира
# (разные форки ядра). Аккаунты копируются с предыдущего активного, если он уже
# хотя раз поднимал worldserver.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-}"
[[ -n "$VARIANT" ]] || die "usage: $0 playerbots|npcbots|lonewolf

Варианты (одновременно на портах 3724/8085 крутится только один):
  lonewolf    — без ИИ-ботов, 1–3 живых игрока
  npcbots     — наёмные спутники (до 4)
  playerbots  — ~200 ботов в мире (нужно больше RAM)

Поверх уже стоящего lonewolf можно поставить playerbots — это вторая сборка,
не «переключение модулей». Общими остаются карты и (после первого старта) аккаунты."

PREV_ACTIVE="$(read_active_variant || true)"

log "остановка других вариантов (порты 3724/8085)"
stop_other_variants "$VARIANT"
stop_variant_stack "$VARIANT"

"$SCRIPT_DIR/01-deps.sh"
"$SCRIPT_DIR/02-clone.sh" "$VARIANT"
"$SCRIPT_DIR/03-build.sh" "$VARIANT"
"$SCRIPT_DIR/04-configure.sh" "$VARIANT"

carry_over_shared_settings "$VARIANT" "$PREV_ACTIVE"
write_active_variant "$VARIANT"

echo
echo "=============================================="
echo " Установка $VARIANT завершена"
echo "=============================================="
echo "Активный вариант записан: $VARIANT"
echo "  (scripts/start.sh без аргумента поднимет именно его)"
if [[ -n "$PREV_ACTIVE" && "$PREV_ACTIVE" != "$VARIANT" ]]; then
  echo "Раньше был активен: $PREV_ACTIVE — он остановлен, БД мира у него своя и на месте."
fi
echo
echo "Дальше по шагам:"
echo
echo "  1) Клиентские data (dbc/maps/vmaps/mmaps) → $AC_DATA"
echo "     Один раз на всю ВМ (общие для всех вариантов):"
echo "       # архив enUS с GitHub wowgaming/client-data →"
echo "       scripts/import-data.sh /path/to/data.zip"
echo "     Подробнее: desktop/README.md"
echo
echo "  2) Первый запуск ЭТОГО варианта — в tmux (импорт SQL в пустые БД):"
echo "       tmux new -s ac-$VARIANT"
echo "       $AC_ROOT/$VARIANT/dist/bin/authserver &"
echo "       $AC_ROOT/$VARIANT/dist/bin/worldserver"
echo "     Дождитесь строк вроде World initialized / AzerothCore."
echo "     В консоли worldserver (без точки в начале):"
echo "       account create МойЛогин МойПароль"
echo "       account set gmlevel МойЛогин 3 -1"
echo "     Выйти из worldserver: Ctrl+C. Отцепить tmux: Ctrl+B затем D."
echo
echo "  3) IP для клиентов (LAN или белый IP ВМ):"
echo "       scripts/set-realm-address.sh $VARIANT \$(hostname -I | awk '{print \$1}')"
echo
echo "  4) Обычный день:"
echo "       scripts/start.sh $VARIANT"
echo "       scripts/status.sh"
echo "       scripts/stop.sh"
echo
echo "  5) Переключить на другой уже установленный вариант:"
echo "       scripts/switch.sh lonewolf|npcbots|playerbots"
echo "     Или поставить второй вариант поверх:"
echo "       scripts/install.sh <другой>   # сборка заново, аккаунты подтянутся если можно"
echo
echo "Документация: README.md"
[[ "$VARIANT" == "playerbots" ]] && echo "Опция чата ботов (GPU): scripts/enable-ollama-chat.sh playerbots"
