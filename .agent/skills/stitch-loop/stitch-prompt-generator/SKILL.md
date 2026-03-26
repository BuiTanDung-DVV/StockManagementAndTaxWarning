---
name: stitch-prompt-generator
description: >-
  Agent sinh prompt UI cho Stitch DỰA TRÊN backend/database hiện tại.
  Phân tích API endpoints + DB schema → sinh giao diện ĐẦY ĐỦ chức năng.
  Không dựa vào frontend hiện tại mà dựa vào khả năng thực tế của backend.
tools: Read, Grep, Glob, Edit, MultiEdit
category: general
displayName: 🧩 Stitch Prompt Generator
color: green
---

# 🧩 Stitch Prompt Generator - HealthCare247

Agent tạo prompt UI cho Stitch. **Nguồn chân lý là BACKEND + DATABASE**, không phải frontend hiện tại.

---

## NGUYÊN TẮC CỐT LÕI

> ❌ KHÔNG: Nhìn frontend hiện tại → tạo prompt giống vậy  
> ✅ ĐÚNG: Nhìn backend API + database → tạo prompt UI bao phủ MỌI chức năng

---

## QUY TRÌNH

### Bước 1: Scan Backend (BẮT BUỘC)

```bash
# 1. Đọc toàn bộ API routes để biết MỌI chức năng
cat backend/src/routes/index.ts
cat backend/src/routes/*.routes.ts

# 2. Đọc controllers để hiểu input/output
cat backend/src/controllers/*.controller.ts

# 3. Đọc database schema
cat resources/HealthCare.sql
```

### Bước 2: Mapping chức năng

Từ backend, liệt kê TẤT CẢ chức năng cần có UI:

| API Module | Endpoints | UI cần tạo |
|-----------|-----------|------------|
| auth | login, register, google, update profile, upload avatar/background | Login, Register, Profile Edit |
| exercises | list (filter/search/paginate), detail, muscles, categories, equipments | Exercise Library, Exercise Detail, Filter |
| recipes | list (filter/search/paginate), detail, categories, areas, random | Recipe Gallery, Recipe Detail |
| foods | list, search, detail | Food Database, Food Detail |
| favorites | toggle foods/recipes/exercises, list by type | Favorites Tab, Heart button |
| tracking | log/get/delete exercise, meal, weight, water + daily/weekly stats | Tracking Dashboard, Log Forms |
| plans | CRUD plans, add/remove/clear details, schedule_days | Plan Builder, Plan Detail, Schedule |
| workout-sessions | start, active, progress, complete, cancel, history | Live Workout, Session History |
| goals | get/update goals (calorie, protein, carbs, fat, water, weight, body areas, activity level) | Goal Settings |

### Bước 3: Sinh prompt UI

Mỗi prompt PHẢI:
1. Liệt kê API endpoints sẽ gọi
2. Mô tả TẤT CẢ chức năng từ backend (không bỏ sót)
3. Thiết kế premium, hiện đại, đồng nhất
4. Giao diện tiếng Việt

---

## BACKEND API ĐẦY ĐỦ

### Auth (9 endpoints)
```
POST   /auth/register          → Đăng ký (name, email, password, gender, dob, height, weight)
POST   /auth/login             → Đăng nhập (email, password)
POST   /auth/google            → Đăng nhập Google
GET    /auth/profile           → Lấy profile
PUT    /auth/profile           → Cập nhật profile
POST   /auth/profile/avatar    → Upload avatar (multipart)
POST   /auth/profile/background → Upload ảnh nền
DELETE /auth/profile/avatar    → Xóa avatar
DELETE /auth/profile/background → Xóa ảnh nền
```

### Exercises (6 endpoints)
```
GET /exercises                → Danh sách (page, limit, search, level, category, equipment, muscle, language_id)
GET /exercises/:id            → Chi tiết (bao gồm muscles, instructions, images)
GET /exercises/muscles        → Danh sách nhóm cơ
GET /exercises/categories     → Danh sách loại bài tập
GET /exercises/equipments     → Danh sách thiết bị
GET /exercises/levels         → Danh sách cấp độ
```

### Recipes (6 endpoints)
```
GET /recipes                 → Danh sách (page, limit, search, category, area, language_id)
GET /recipes/:id             → Chi tiết (ingredients, instructions)
GET /recipes/categories      → Danh sách categories
GET /recipes/areas            → Danh sách vùng miền
GET /recipes/random           → Random recipes
GET /recipes/latest           → Mới nhất
```

### Foods (3 endpoints)
```
GET /foods                   → Danh sách (page, limit, search, category, language_id)
GET /foods/:id               → Chi tiết (full nutrition: calories, protein, carbs, fat, fiber, sugars, cholesterol, sodium, amino_acids, fatty_acids, carotenoids...)
GET /foods/categories        → Categories
```

### Favorites (4 endpoints)
```
POST   /favorites/toggle      → Toggle favorite (type: exercise/recipe/food, item_id)
GET    /favorites/exercises    → DS bài tập yêu thích
GET    /favorites/recipes      → DS công thức yêu thích
GET    /favorites/foods        → DS thực phẩm yêu thích
```

### Tracking (14 endpoints)
```
POST   /tracking/exercise      → Ghi bài tập (exercise_id, sets, reps, weight, duration, calories)
GET    /tracking/exercise      → Lịch sử bài tập (date range)
DELETE /tracking/exercise/:id  → Xóa log bài tập

POST   /tracking/meal          → Ghi bữa ăn (food_id, quantity, meal_type, calories, protein, carbs, fat)
GET    /tracking/meal          → Lịch sử bữa ăn
DELETE /tracking/meal/:id      → Xóa log bữa ăn

POST   /tracking/weight        → Ghi cân nặng (weight, notes)
GET    /tracking/weight        → Lịch sử cân nặng
DELETE /tracking/weight/:id    → Xóa log cân nặng

POST   /tracking/water         → Ghi uống nước (amount_ml)
GET    /tracking/water         → Lịch sử nước
GET    /tracking/water/daily   → Tổng nước hôm nay
DELETE /tracking/water/:id     → Xóa log nước

GET    /tracking/daily-stats   → Stats ngày (tổng calories, macros, exercises, water)
GET    /tracking/weekly-stats  → Stats tuần
```

### Plans (7 endpoints)
```
GET    /plans                  → DS kế hoạch user
GET    /plans/:id              → Chi tiết (exercises + recipes trong plan)
POST   /plans                  → Tạo plan (name, plan_type, description, schedule_days)
PUT    /plans/:id              → Cập nhật plan
DELETE /plans/:id              → Xóa plan
POST   /plans/:id/details      → Thêm item (exercise_id/recipe_id, sets, reps, rest_duration, order_index)
DELETE /plans/:id/details/:did → Xóa item
```

### Workout Sessions (7 endpoints)
```
POST   /workout-sessions              → Bắt đầu session (plan_id?, exercise_id?, name)
GET    /workout-sessions/active       → Session đang chạy
GET    /workout-sessions/:id          → Chi tiết session
PUT    /workout-sessions/:id/exercises/:eid → Cập nhật tiến độ (sets_completed, reps_completed, weight_used, notes)
POST   /workout-sessions/:id/complete  → Hoàn thành (notes, total_duration)
POST   /workout-sessions/:id/cancel    → Hủy session
GET    /workout-sessions/history       → Lịch sử sessions
```

### Goals (2 endpoints)
```
GET    /users/goals            → Lấy goals hiện tại
PUT    /users/goals            → Cập nhật (daily_calorie, protein, carbs, fat, water, target_weight, activity_level, target_areas)
```

---

## DATABASE TABLES QUAN TRỌNG

```
Users: user_id, name, email, gender, date_of_birth, height, weight, avatar_url, background_url, fitness_goal, preferred_language_id
User_Goals: daily_calorie_goal, daily_protein_goal, daily_carbs_goal, daily_fat_goal, daily_water_goal, target_weight, activity_level, target_body_areas, weekly_workout_days
Exercises + Translations + Images + Instructions + Muscles (primary/secondary)
Foods + Translations (full nutrition data 30+ fields)
Recipes + Translations + Ingredients + Instructions
Plans + Plan_Details (exercise_id, recipe_id, sets, reps, rest_duration, order_index)
Workout_Sessions + Workout_Session_Details
Exercise_Tracking, Meal_Tracking, Weight_Tracking, Water_Tracking
Favorite_Foods, Favorite_Recipes (no Favorite_Exercises table but API supports)
Achievements + User_Achievements
Notifications, Friendships
```

---

## QUY TẮC THIẾT KẾ UI

1. **Đầy đủ chức năng**: Mọi API endpoint phải có UI tương ứng
2. **Premium design**: Glassmorphism + Gradients + Micro-animations
3. **Đồng nhất**: Cùng color palette, spacing, typography, card style
4. **Dark/Light mode**: Hỗ trợ cả 2
5. **Tiếng Việt**: Toàn bộ giao diện
6. **CRUD đầy đủ**: Nếu backend có Create/Read/Update/Delete → UI phải có đủ
7. **States**: Loading (shimmer), Empty, Error, Success cho mọi thao tác
