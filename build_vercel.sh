#!/bin/bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
echo "🚀 Bắt đầu cài đặt Flutter Web trên Vercel..."
# Tải Flutter bản stable mới nhất (chỉ lấy commit cuối cùng để tiết kiệm dung lượng và thời gian)
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Thêm Flutter vào biến môi trường
export PATH="$PATH:`pwd`/flutter/bin"

# Cấp quyền thực thi
chmod +x flutter/bin/flutter

# Tắt tính năng gửi dữ liệu ẩn danh để build nhanh hơn
flutter config --no-analytics

echo "📦 Đang tải các thư viện (packages)..."
flutter pub get

echo "🔨 Đang tiến hành Build Web..."
# Truyền các cấu hình public vào Flutter bằng dart-define mà không in giá trị ra build log.
BUILD_ARGS=(--release)
if [ -n "${API_URL:-}" ]; then
  BUILD_ARGS+=(--dart-define="API_URL=$API_URL")
else
  echo "⚠️ Không tìm thấy biến môi trường API_URL. Build với cấu hình mặc định."
fi

GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-124075638912-hk0076lmjvgqa0iqec75aerpoe4lcpfq.apps.googleusercontent.com}"
BUILD_ARGS+=(--dart-define="GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID")

flutter build web "${BUILD_ARGS[@]}"

echo "✨ Hoàn thành quá trình Build!"
