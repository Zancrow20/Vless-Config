#!/bin/bash
LINK=$(cat /root/vless_link.txt 2>/dev/null)
[ -z "$LINK" ] && echo "Нет файла vless_link.txt!" && exit 1
for fmt in "ANSI -s 1 -m 0" "ANSI2 -s 1 -m 0" "ANSI -s 1 -m 1"; do
  clear
  echo "=== Формат: $fmt ==="
  qrencode -t ${fmt} "$LINK"
  echo -e "\nEnter = дальше, y = готово"
  read -p "> " ans
  [ "$ans" = "y" ] && break
done