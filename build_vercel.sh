#!/bin/bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
echo "🚀 Bắt đầu cài đặt Flutter trên Vercel..."
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
# Nếu trên Vercel có cài biến API_URL thì tự động truyền vào, nếu không thì build mặc định
if [ -z "$API_URL" ]; then
  echo "⚠️ Không tìm thấy biến môi trường API_URL. Build với cấu hình mặc định."
  flutter build web --release
else
  echo "✅ Đã nhận được API_URL: $API_URL. Đang build với --dart-define"
  flutter build web --release --dart-define=API_URL=$API_URL
fi

echo "✨ Hoàn thành quá trình Build!"
