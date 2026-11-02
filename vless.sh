#!/bin/bash

# 0. Проверка прав суперпользователя (обязательно для записи в /usr/local/etc и systemctl)
if [ "$EUID" -ne 0 ]; then
  echo "Ошибка: Скрипт должен быть запущен от имени root (используйте sudo)."
  exit 1
fi

# 1. Проверка и обновление Xray
echo "============================================="
echo " Проверка версии и обновление Xray..."
echo "============================================="
# Скачиваем официальный скрипт установки/обновления ядра Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Проверяем, что бинарник доступен
if ! command -v xray &> /dev/null; then
    echo "Ошибка: Xray не удалось установить!"
    exit 1
fi

echo "Текущая версия Xray:"
xray version | head -n 1

# 2. Генерация ключей и UUID в память (без записи в файлы)
echo " Генерация криптографических ключей..."
UUID="521ea697-c867-4c76-848d-f40ac14d10fe" # Можно заменить на $(uuidgen) для генерации нового
KEYS=$(xray x25519)
# Используем $NF (последнее поле), чтобы избежать ошибок при лишних пробелах в выводе
PRIV_KEY=$(echo "$KEYS" | grep "Private key:" | awk '{print $NF}')
PUB_KEY=$(echo "$KEYS" | grep "Public key:" | awk '{print $NF}')

# 3. Запись идеального JSON-конфига на чистый IPv6
echo " Запись конфигурации VLESS + Reality..."
cat << EOF > /usr/local/etc/xray/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "listen": "2a0a:4cc0:c1:3f20::1",
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
          "privateKey": "$PRIV_KEY"
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
# ПРАВИЛЬНАЯ команда для теста: xray test, а не xray run -test
if xray test -config /usr/local/etc/xray/config.json | grep -q "Configuration OK"; then
    echo " Конфигурация успешна! Перезапуск службы..."
    systemctl restart xray
    systemctl enable xray
else
    echo " Ошибка: Финальный конфиг содержит синтаксические ошибки!"
    echo "Детали ошибки:"
    xray test -config /usr/local/etc/xray/config.json
    exit 1
fi

# 5. Вывод чистых данных для ручной настройки клиента на телефоне
echo "============================================="
echo " НАСТРОЙКИ ДЛЯ КЛИЕНТА (v2rayNG / Hiddify / NekoBox):"
echo "============================================="
echo "Адрес (Server):   2a0a:4cc0:c1:3f20::1"
echo "Порт (Port):      443"
echo "ID (UUID):        $UUID"
echo "Flow:             xtls-rprx-vision"
echo "Network (Type):   tcp"
echo "Security:         reality"
echo "SNI:              microsoft.com"
echo "Public Key (pbk): $PUB_KEY"
echo "Fingerprint (fp): chrome"
echo "============================================="
echo "Готовая ссылка подключения:"
echo "vless://$UUID@[2a0a:4cc0:c1:3f20::1]:443?security=reality&encryption=none&pbk=$PUB_KEY&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=microsoft.com#Netcup_Reality"
echo "============================================="