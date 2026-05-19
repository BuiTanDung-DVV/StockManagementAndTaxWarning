# Hướng dẫn Tối ưu hóa Hiệu suất Hệ thống (System Optimization Guide)

Tài liệu này dành cho **Antigravity** (sử dụng MCP Supabase & Vercel) để thực thi các bước tối ưu hóa tình trạng thắt cổ chai hiệu năng, giảm thời gian phản hồi của các tác vụ CRUD và GET từ 4-5s xuống dưới 1.5s.

## Bối cảnh (Context)
Hệ thống hiện tại gặp độ trễ cao do:
1. Thiếu Index trên các cột truy vấn chính (đặc biệt là `shop_id` cho kiến trúc Multi-tenant) và thiếu `pg_trgm` cho tìm kiếm chuỗi.
2. Quá tải Connection Pool khi Vercel Serverless Functions liên tục mở connection mới đến Supabase.
3. Độ trễ địa lý (Vercel mặc định deploy ở US, trong khi DB có thể ở Region khác).

---

## 🛠️ CÁC BƯỚC THỰC THI DÀNH CHO ANTIGRAVITY

### BƯỚC 1: Thực thi Script Tối ưu Cơ sở dữ liệu (Dùng Supabase MCP)
Antigravity hãy đọc nội dung file SQL đã được chuẩn bị sẵn tại:
`backend/database/20260504_optimize_indexes.sql`

Và **sử dụng quyền Supabase MCP để thực thi (execute)** toàn bộ script này lên database hiện tại.
*Tác dụng: Bật extension `pg_trgm`, tạo GIN Indexes và B-Tree Indexes cho `shop_id` cùng các khóa ngoại trên tất cả các bảng phối hợp.*

### BƯỚC 2: Cập nhật Chuỗi kết nối Connection Pooler (Dùng Vercel MCP)
Hệ thống Serverless (Vercel) cần dùng Connection Pooling của Supabase (IPv4/IPv6 PGBouncer) thay vì Direct Connection để tránh dồn ứ kết nối.
1. Dùng Supabase MCP để lấy chuỗi kết nối **Connection Pooler URL** chuẩn (thường sử dụng cổng `6543` và có tham số `?pgbouncer=true`).
2. Dùng Vercel MCP để cập nhật lại biến môi trường `DATABASE_URL` của project backend.

### BƯỚC 3: Cấu hình Vercel Region (Cập nhật Repo / Vercel MCP)
Đảm bảo các Serverless Functions của Vercel chạy cùng một ranh giới khu vực (Region) với Supabase Database (Ví dụ: `sin1` cho khu vực Singapore nếu Database ở Singapore) để giảm thiểu độ trễ vật lý.
1. Chỉnh sửa file `backend/vercel.json` (nếu chưa có thì tạo mới) và thêm block cấu hình regions:
```json
{
  "regions": ["sin1"] 
}
```
*(Lưu ý điều chỉnh "sin1" thành region thực tế của DB Supabase).*

### BƯỚC 4: Trigger Deployment (Dùng Vercel MCP)
Sau khi đã lưu các biến môi trường và thiết lập codebase:
1. Sử dụng Vercel MCP để **Trigger một lượt Deploy mới nhất** (hoặc push thay đổi `vercel.json` lên Git nhánh chính để Vercel tự động build).
2. Theo dõi tiến trình deploy, đảm bảo trạng thái Ready.

---
**Kết quả mong đợi:** Sau khi Serverless Functions khởi động lại ở khu vực mới với Connection Pooler và các bảng đã được Indexing, thời gian phản hồi (Response Time) sẽ giảm ngay lập tức về mức 300ms - 800ms.
