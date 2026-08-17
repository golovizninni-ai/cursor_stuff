# 8BitDo Ultimate 2 — экспериментальное выключение при XInput (`2dc8:310b`)

**Не ставить вместе с рабочим sleep/dock фиксами.** Техническая возможность не проверена.

## Зачем

Идеальный UX: снял с дока → ПК проснулся → если XInput, геймпад сам гаснет → включаешь **Home+B** (D-Input).

## Почему может не сработать

В Linux `2dc8:310b` — **XTYPE_XBOX360** (wired-клон), не Microsoft wireless receiver.

Пакет `{00 00 08 C0 …}` из `xpad` выключает только Xbox 360 Wireless Receiver. Ultimate 2 может его проигнорировать. 8BitDo не публикует vendor power-off; штатно — Home 3 сек.

Скрипт: временно unbind `xpad`, interrupt-OUT на XInput-интерфейс, проверка исчез ли `310b`.

## Установка (только для теста)

```bash
sudo cp 8bitdo-xinput-poweroff.py /usr/local/bin/
sudo chmod +x /usr/local/bin/8bitdo-xinput-poweroff.py
sudo cp systemd/8bitdo-xinput-poweroff.service /etc/systemd/system/
sudo cp udev/74-8bitdo-xinput-poweroff.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo systemctl daemon-reload
```

Нужны root, `python3`, `libusb-1.0`.

## Killswitch (прошивка Ultimate Software — нужен XInput)

```bash
sudo touch /etc/8bitdo-allow-xinput
```

Пока файл есть, скрипт ничего не шлёт.

## Проверка

```bash
# геймпад в XInput (Home без B)
lsusb | grep -i 8bitdo    # 2dc8:310b
sudo /usr/local/bin/8bitdo-xinput-poweroff.py
lsusb | grep -i 8bitdo    # успех: 6013; неудача: всё ещё 310b
journalctl -t 8bitdo-xinput-poweroff -n 20
```

Код выхода `2` = пакет, скорее всего, проигнорирован.

## Снятие

```bash
sudo rm -f /etc/udev/rules.d/74-8bitdo-xinput-poweroff.rules \
           /etc/systemd/system/8bitdo-xinput-poweroff.service \
           /usr/local/bin/8bitdo-xinput-poweroff.py
sudo udevadm control --reload
sudo systemctl daemon-reload
```
