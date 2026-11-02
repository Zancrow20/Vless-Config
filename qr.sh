#!/bin/bash
LINK=$(cat /root/vless_link.txt 2>/dev/null)
[ -z "$LINK" ] && echo "Нет файла vless_link.txt!" && exit 1
for fmt in "ANSI -s 1" "ANSI -s 2" "ANSIUTF8 -s 3" "ANSI2 -s 2"; do
  clear
  echo "=== Формат: $fmt ==="
  qrencode -t ${fmt} -m 1 "$LINK"
  echo -e "\nEnter = дальше, y = готово"
  read -p "> " ans
  [ "$ans" = "y" ] && break
done