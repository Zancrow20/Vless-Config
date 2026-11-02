#!/bin/bash

# 0. Проверка прав суперпользователя
if [ "$EUID" -ne 0 ]; then
  echo "Ошибка: Скрипт должен быть запущен от имени root (используйте sudo)."
  exit 1
fi

# 1. Проверка и обновление Xray
echo "============================================="
echo " Проверка версии и обновление Xray..."
echo "============================================="
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

if ! command -v xray &> /dev/null; then
    echo "Ошибка: Xray не удалось установить!"
    exit 1
fi

echo "Текущая версия Xray:"
xray version | head -n 1

# 2. Генерация ключей и UUID
echo " Генерация криптографических ключей и UUID..."
# Генерируем новый уникальный UUID при каждом запуске
UUID=$(xray uuid)
KEYS=$(xray x25519)
PRIV_KEY=$(echo "$KEYS" | grep -i "private" | sed 's/.*: //')
PUB_KEY=$(echo "$KEYS" | grep -i "public" | sed 's/.*: //')
# Генерируем случайный shortId (8 символов в hex)
SHORT_ID=$(openssl rand -hex 8)

# 3. Запись конфигурации
# ⚠️ ВАЖНО: Замените 2a0a:4cc0:c1:3f20::1 на РЕАЛЬНЫЙ IPv6-адрес вашего сервера!
# Проверить его можно командой: ip -6 addr show
SERVER_IPv6="2a0a:4cc0:c1:3f20::1"

echo " Запись конфигурации VLESS + Reality..."
cat << EOF > /usr/local/etc/xray/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "listen": "$SERVER_IPv6",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
  "show": false,
  "dest": "microsoft.com:443",
  "xver": 0,
  "serverNames": [
    "microsoft.com",
    "www.microsoft.com"
  ],
  "privateKey": "$PRIV_KEY",
  "shortIds": ["$SHORT_ID"]
}
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

# 4. Тестирование и перезапуск службы
echo " Тестирование конфигурации..."
if xray run -test -c /usr/local/etc/xray/config.json | grep -q "Configuration OK"; then
    echo " Конфигурация успешна! Перезапуск службы..."
    systemctl restart xray
    systemctl enable xray
else
    echo " Ошибка: Финальный конфиг содержит синтаксические ошибки!"
    echo "Детали ошибки:"
    xray run -test -c /usr/local/etc/xray/config.json
    exit 1
fi

# 5. Напоминание о брандмауэре
echo " Напоминание: Убедитесь, что порт 443 (TCP) открыт для IPv6."
echo " Для UFW: sudo ufw allow 443/tcp"
echo " Для iptables: sudo ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT"

# 6. Формирование ссылки и вывод QR-кода в терминал
FULL_LINK="vless://${UUID}@[${SERVER_IPv6}]:443?security=reality&encryption=none&pbk=${PUB_KEY}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=microsoft.com&sid=${SHORT_ID}#Netcup_Reality"

echo "============================================="
echo " НАСТРОЙКИ ДЛЯ КЛИЕНТА:"
echo "============================================="
echo "Адрес (Server):   $SERVER_IPv6"
echo "Порт (Port):      443"
echo "ID (UUID):        $UUID"
echo "Flow:             xtls-rprx-vision"
echo "Security:         reality"
echo "SNI:              microsoft.com"
echo "Public Key (pbk): $PUB_KEY"
echo "ShortId (sid):    $SHORT_ID"
echo "Fingerprint (fp): chrome"
echo "============================================="

# Генерация компактного QR-кода прямо в терминале
if command -v qrencode &> /dev/null; then
    echo " QR-КОД (наведите камеру телефона на экран):"
    echo "============================================="
    # -t ANSIUTF8 - цветной UTF-8
    # -m 1 - минимальные поля
    # -s 3 - маленький размер блока
    qrencode -t ANSIUTF8 -m 1 -s 3 "$FULL_LINK"
    echo "============================================="
else
    echo "⚠️ qrencode не установлен"
    echo "Установите: sudo apt install qrencode"
fi

echo ""
echo "Ссылка для ручного копирования:"
echo "$FULL_LINK"
echo "============================================="
# Сохранение ссылки в файл
echo "$FULL_LINK" > /root/vless_link.txt
echo "✅ Ссылка сохранена в файл: /root/vless_link.txt"
echo ""
echo "Содержимое файла:"
cat /root/vless_link.txt
echo "============================================="