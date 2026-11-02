LINK=$(cat /root/vless_link.txt 2>/dev/null)
if [ -z "$LINK" ]; then echo "Файл /root/vless_link.txt не найден!"; exit 1; fi
for fmt in "ANSIUTF8 -s 3" "ANSIUTF8 -s 4" "ANSIUTF8 -s 5" "ANSI2 -s 2"; do
  clear
  echo "=== Формат: $fmt ==="
  echo "Наведите камеру. Enter = следующий, y = готово"
  qrencode -t ${fmt} -m 1 "$LINK"
  echo ""
  read -p "Считалось? (y/n): " ans
  [ "$ans" = "y" ] && break
done