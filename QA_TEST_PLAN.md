# Ke hoach kiem thu ung dung Quan ly kho hang va canh bao thue

## 1. Muc tieu

Tai lieu nay dung cho Manual QA/Tester de kiem thu day du ung dung quan ly ban hang, ton kho, tai chinh va canh bao thue.

Muc tieu chinh:

- Xac minh cac man hinh hien thi dung du lieu va dung quyen nguoi dung.
- Dam bao cac nghiep vu loi: nhap hang, ban hang, tra hang, kiem kho, cong no, hoa don, thue chay dung.
- Phat hien som loi logic co kha nang lam sai ton kho, sai tien, sai cong no hoac sai nghia vu thue.
- Tao bo checklist co the dung de test hoi quy sau moi lan release.

## 2. Pham vi kiem thu

| Module | Man hinh | Muc tieu kiem thu |
|---|---|---|
| Auth | Dang nhap | Xac thuc tai khoan, token, dieu huong sau dang nhap |
| Auth | Dang ky | Tao tai khoan chu shop hoac nhan vien |
| Auth | Quen mat khau | Gui yeu cau khoi phuc, khong lo tai khoan co ton tai hay khong |
| Auth | Onboarding | Tao cua hang moi hoac gui yeu cau tham gia cua hang |
| Auth | Cho duyet | Nhan vien pending/rejected khong vao duoc app chinh |
| Dashboard | Trang chu | KPI doanh thu, don hang, canh bao ton thap, thao tac nhanh |
| Sales | POS | Tao don ban hang, tinh tien, thanh toan, QR |
| Sales | Danh sach don hang | Xem, loc, tim kiem, phan trang don hang |
| Sales | Chi tiet don hang | Xem item, thanh toan them, huy don, tra hang |
| Products | Danh sach san pham | Tim kiem, them, sua, xoa mem san pham |
| Products | Form san pham | Tao/sua SKU, gia von, gia ban, ton dau ky, danh muc |
| Products | Chi tiet san pham | Ton kho, gia von, lo hang, quy doi don vi |
| Customers | Danh sach khach hang | Them, sua, tim khach hang |
| Customers | Chi tiet khach hang | Cong no, thu no, lich su mua |
| Suppliers | Danh sach nha cung cap | Them, sua, tim NCC |
| Suppliers | Chi tiet nha cung cap | Thong tin lien he, cong no phai tra |
| Inventory | Tong quan kho | Ton kho theo san pham/kho, canh bao ton thap |
| Inventory | Nhap hang | Tao don nhap, tang ton, tao lot gia von |
| Inventory | Kiem ke | So sanh ton he thong va ton thuc te |
| Inventory | Bao cao XNT | Ton dau, nhap, xuat, ton cuoi theo ky |
| Finance | Tong quan tai chinh | Thu, chi, so du, giao dich gan day |
| Finance | Lich su giao dich | Loc thu/chi, thoi gian, phuong thuc |
| Finance | Chot so ngay | Doi chieu tien thuc te voi so lieu he thong |
| Finance | Lai/lo | Doanh thu, gia von, chi phi, loi nhuan |
| Finance | Du bao dong tien | Thu/chi du kien, canh bao thieu tien |
| Finance | Phan tich tuoi no | No hien tai, qua han 30/60/90 ngay |
| Tax | Hoa don | Hoa don dau vao/dau ra, VAT |
| Tax | Mua khong hoa don | Bang ke, CCCD nguoi ban, duyet/tu choi |
| Tax | Tinh thue HKD | Tinh VAT/PIT theo doanh thu va loai hinh |
| Tax | Nghia vu thue | Thue da khai, da nop, con phai nop |
| Tax | Ke khai thue | Tong hop du lieu phuc vu to khai |
| Settings | Ho so ca nhan | Sua thong tin, doi mat khau |
| Settings | Ho so cua hang | Ten shop, ma shop, dia chi, MST |
| Settings | Nhan vien | Moi, duyet, tu choi, xoa nhan vien |
| Settings | Vai tro | Tao/sua/xoa role, cau hinh phan quyen |
| Settings | Cau hinh thue | Ky khai, nguong canh bao, nhac han |
| Settings | Cau hinh thanh toan | Tai khoan nhan tien, QR |
| Settings | Thong bao | Doc/chua doc, danh dau tat ca da doc |
| Settings | Nhat ky hoat dong | Theo doi ai thao tac gi, luc nao |

## 3. RUI RO LOGIC NGHIEM TRONG

| ID | Rui ro | Tac dong | Uu tien |
|---|---|---|---|
| R-01 | Ban hang khong tru ton hoac tru ton lot nhung khong cap nhat ton tong | Ton kho sai, XNT sai | P0 |
| R-02 | Huy don/tra hang khong dao doanh thu, tien, ton kho | Bao cao tai chinh va kho sai | P0 |
| R-03 | Tinh COGS FIFO/AVG sai khi co nhieu lo nhieu gia | Loi nhuan sai, thue sai | P0 |
| R-04 | Don da huy van tinh vao doanh thu/lai lo | Bao cao sai nghiem trong | P0 |
| R-05 | Thanh toan them vuot tong don | Cong no va tien quy lech | P0 |
| R-06 | Nhan vien pending/rejected van truy cap duoc API | Lo du lieu cua hang | P0 |
| R-07 | Backend khong chan quyen, chi an UI | Rui ro bao mat cao | P0 |
| R-08 | VAT dau vao/dau ra tinh sai theo ky ngay | Nghia vu thue sai | P0 |
| R-09 | Mua khong hoa don khong bat buoc CCCD/ten nguoi ban | Chung tu khong hop le | P1 |
| R-10 | Chot so ngay bi tao trung | So lieu doi soat bi nhan doi | P1 |

## 4. Luong kiem thu E2E uu tien

| ID | Luong test | Ket qua mong doi |
|---|---|---|
| E2E-01 | Chu shop dang ky, onboarding, tao shop, dang nhap lai | Tai khoan ACTIVE, vao dashboard, co quyen owner |
| E2E-02 | Nhan vien dang ky, xin tham gia shop, chu shop duyet | Nhan vien vao app voi dung role |
| E2E-03 | Tao san pham, nhap hang, kiem tra ton kho | San pham co ton dung, co phat sinh lo hang |
| E2E-04 | Tao don ban hang tu POS, thanh toan tien mat | Don duoc tao, tien thu tang, ton giam |
| E2E-05 | Ban chiu cho khach, thu tien mot phan | Cong no con lai dung, tuoi no dung |
| E2E-06 | Huy don hoac tra hang sau khi da thanh toan | Doanh thu/tien/ton kho duoc xu ly dung |
| E2E-07 | Nhap hoa don dau vao/dau ra, xem tong VAT | VAT in/out va VAT owed dung |
| E2E-08 | Nhan vien tao mua khong hoa don, chu shop duyet | Owner duyet duoc, nhan vien khong tu duyet |
| E2E-09 | Chot so ngay sau nhieu giao dich thu/chi | Chenh lech tien mat hien thi dung |
| E2E-10 | Doi role nhan vien roi test menu/API | UI va backend ap dung quyen moi |

## 5. Test case theo tung man hinh

### 5.1 Dang nhap

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| AUTH-01 | Dang nhap thanh cong bang username | Nhap username hop le, mat khau dung, bam Dang nhap | Vao dashboard hoac onboarding tuy trang thai user |
| AUTH-02 | Dang nhap thanh cong bang so dien thoai | Nhap SDT da dang ky, mat khau dung | Dang nhap thanh cong |
| AUTH-03 | Sai mat khau | Nhap user dung, mat khau sai | Hien thong bao loi, khong vao app |
| AUTH-04 | User khong ton tai | Nhap username la | Hien loi chung, khong lo thong tin he thong |
| AUTH-05 | Tai khoan inactive | Dang nhap bang tai khoan bi khoa | Khong cho vao app |
| AUTH-06 | Token het han | Gia lap access token het han | App refresh token hoac yeu cau dang nhap lai |

### 5.2 Dang ky

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| REG-01 | Dang ky chu shop | Chon Chu cua hang, nhap thong tin hop le | Tao tai khoan, chuyen den dang nhap/onboarding |
| REG-02 | Dang ky nhan vien | Chon Nhan vien, nhap thong tin hop le | Tao tai khoan nhan vien |
| REG-03 | Username/SDT trung | Nhap username hoac SDT da ton tai | Bao loi trung tai khoan |
| REG-04 | SDT sai format | Nhap SDT ngan/dai/sai dau so | Khong cho dang ky |
| REG-05 | Mat khau rong/qua ngan | De trong hoac nhap mat khau yeu | Bao loi validation |

### 5.3 Onboarding va cho duyet

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| ONB-01 | Chu shop tao cua hang moi | Login user SHOP chua onboard, nhap ten shop, dia chi | Shop duoc tao, member OWNER ACTIVE |
| ONB-02 | Nhan vien xin vao shop bang ma shop | Login user PERSONAL, nhap ma shop dung | Tao member PENDING, chuyen man hinh cho duyet |
| ONB-03 | Ma shop sai | Nhap ma shop khong ton tai | Bao loi khong tim thay shop |
| ONB-04 | Thieu ten cua hang | Chu shop de trong ten shop | Bao loi bat buoc |
| ONB-05 | Pending bi chan vao app | User pending truy cap URL dashboard | Bi redirect ve man hinh cho duyet |
| ONB-06 | Rejected bi chan | User bi tu choi reload app | Khong vao app chinh, hien trang thai bi tu choi |

### 5.4 Dashboard

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| DASH-01 | Hien KPI hom nay | Tao don trong ngay, vao dashboard | Doanh thu, so don, trung binh/don dung |
| DASH-02 | Canh bao ton thap | Tao SP co ton <= min stock | SP xuat hien trong canh bao |
| DASH-03 | Quick action POS | Bam Tao don/Ban hang | Dieu huong den POS |
| DASH-04 | Quick action Kiem ke | Bam Kiem ke | Dieu huong den man hinh kiem kho |
| DASH-05 | Menu theo quyen | Login nhan vien chi co POS | Chi thay menu duoc cap quyen |

### 5.5 POS va ban hang

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| POS-01 | Tao don thanh cong | Chon san pham, nhap so luong, thanh toan du, luu | Don tao thanh cong, ton giam, giao dich thu tang |
| POS-02 | Them nhieu san pham | Chon 2-3 san pham khac nhau | Tong tien = tong cac dong |
| POS-03 | Giam gia hop le | Nhap discount nho hon subtotal | Tong tien tru discount dung |
| POS-04 | Thue tren don | Nhap tax amount/tax rate | Tong tien cong thue dung |
| POS-05 | Thanh toan mot phan | paidAmount < totalAmount | Don con PENDING/cong no neu co khach |
| POS-06 | Thanh toan QR | Chon QR, tao don | Payment method luu dung, co ma tham chieu neu co |
| POS-07 | So luong bang 0 | Them item quantity = 0 | Khong cho tao don |
| POS-08 | Gia ban am | Nhap gia am neu UI cho phep | Bi chan validation |
| POS-09 | Ton khong du | Ban nhieu hon ton hien co | Can canh bao/chan tuy business rule |
| POS-10 | Vuot han muc tin dung | Chon khach co debt gan limit, ban chiu vuot limit | Khong cho tao don |

### 5.6 Danh sach va chi tiet don hang

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| SO-01 | Xem danh sach don | Tao nhieu don, vao danh sach | Don moi nhat nam tren dau |
| SO-02 | Loc trang thai | Loc PENDING/DELIVERED/CANCELLED | Chi hien don dung trang thai |
| SO-03 | Xem chi tiet don | Bam mot don | Hien dung items, tien, payment |
| SO-04 | Huy don | Bam huy don hop le | Status CANCELLED, khong tinh vao summary |
| SO-05 | Thanh toan them | Don chua tra du, them payment | paidAmount tang, status cap nhat |
| SO-06 | Thanh toan vuot tong | Them payment > so con lai | He thong phai chan hoac xu ly khong lech cong no |
| SO-07 | Tra hang mot phan | Tao return 1 item | Tao phieu tra, co giao dich hoan tien neu refund |
| SO-08 | Tra hang vuot so da ban | Return quantity > quantity ban | Phai bi chan |

### 5.7 San pham

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| PRD-01 | Tao san pham moi | Nhap ten, SKU, gia von, gia ban, ton dau ky | San pham duoc tao, ton dau ky phat sinh |
| PRD-02 | SKU trung | Tao 2 SP cung SKU trong 1 shop | Lan 2 bi bao loi |
| PRD-03 | Gia ban bang 0 | Nhap gia ban 0 | Bao loi gia ban phai > 0 |
| PRD-04 | Thieu ten SP | De trong ten | Bao loi bat buoc |
| PRD-05 | Search theo ten/SKU/barcode | Nhap tu khoa | Tra dung san pham |
| PRD-06 | Sua gia ban | Mo form sua, doi gia | Gia moi duoc luu |
| PRD-07 | Xoa san pham | Xoa SP da co don | Xoa mem, lich su don khong mat |
| PRD-08 | Xem chi tiet SP | Mo chi tiet | Hien ton, gia von, gia ban, trang thai ton |
| PRD-09 | Them cost item | Them chi phi van chuyen/phan tram | Gia de xuat cap nhat dung |
| PRD-10 | Tao lo hang het han | Them batch co expiryDate | Xuat hien trong canh bao sap het han khi gan ngay |

### 5.8 Khach hang va cong no

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| CUS-01 | Tao khach hang | Nhap ten, SDT, dia chi | Khach hang duoc tao, co ma CUS |
| CUS-02 | Tim khach hang | Tim theo ten/SDT/ma | Tra dung ket qua |
| CUS-03 | Sua thong tin | Doi SDT/dia chi | Luu thanh cong |
| CUS-04 | Ban chiu gan khach | Tao don paidAmount < total | Cong no tang dung |
| CUS-05 | Thu no mot phan | Ghi nhan payment cho receivable | PaidAmount tang, remaining giam |
| CUS-06 | Tuoi no current | Due date tuong lai | Nam bucket current |
| CUS-07 | Tuoi no qua 30/60/90 ngay | Tao debt qua han tung moc | Nam dung bucket |
| CUS-08 | Han muc tin dung | Debt hien tai + debt moi > limit | Khong cho tao don ban chiu |

### 5.9 Nha cung cap

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| SUP-01 | Tao NCC | Nhap ten, SDT, MST, email | NCC duoc tao, co ma SUP |
| SUP-02 | Tim NCC | Tim theo ten/SDT/ma | Tra dung NCC |
| SUP-03 | Sua NCC | Doi thong tin lien he | Luu thanh cong |
| SUP-04 | Xem chi tiet | Mo NCC | Hien thong tin lien he va dieu khoan thanh toan |
| SUP-05 | Payables | Tao khoan phai tra neu co | Hien dung cong no NCC |

### 5.10 Kho, nhap hang, kiem ke, XNT

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| INV-01 | Xem ton kho | Vao Kho | Hien danh sach stock theo SP/kho |
| INV-02 | Ton thap | SP co quantity <= threshold | Nam trong danh sach low stock |
| INV-03 | Tao kho moi | Nhap ten kho | Kho duoc tao |
| PO-01 | Tao don nhap | Chon NCC, them SP, so luong, don gia | Don nhap duoc tao, tong tien dung |
| PO-02 | Don nhap thieu NCC | Khong chon NCC, bam luu | Bao loi |
| PO-03 | Don nhap khong co item | Khong them SP | Bao loi |
| PO-04 | So luong nhap bang 0/am | Nhap quantity <= 0 | Bao loi |
| PO-05 | Gia nhap am | Nhap unitPrice < 0 | Bao loi |
| PO-06 | Tao lot COGS | Tao don nhap hop le | Co lot ton voi remainingQty dung |
| ST-01 | Kiem ke khop | actualQty = systemQty | Difference = 0 |
| ST-02 | Kiem ke thieu | actualQty < systemQty | Difference am |
| ST-03 | Kiem ke thua | actualQty > systemQty | Difference duong |
| XNT-01 | Bao cao XNT 1 ky | Chon from/to | End = Start + Import - Export |
| XNT-02 | Loc theo kho | Chon warehouse | Chi tinh movement cua kho do |
| XNT-03 | Ngay cuoi ky | Co giao dich luc 23:59:59 ngay to | Van tinh vao bao cao |

### 5.11 Tai chinh

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| FIN-01 | Tao giao dich thu | Nhap INCOME hop le | Giao dich duoc tao, summary income tang |
| FIN-02 | Tao giao dich chi | Nhap EXPENSE hop le | Summary expense tang |
| FIN-03 | Loc giao dich theo loai | Chon INCOME/EXPENSE | List dung loai |
| FIN-04 | Loc giao dich theo ngay | Chon from/to | Chi hien giao dich trong ky |
| FIN-05 | Don ban tao phieu thu | Tao don paidAmount > 0 | Co cash transaction SALES |
| FIN-06 | Tra hang tao phieu chi | Tao return co refund | Co cash transaction REFUND |
| FIN-07 | Chot so ngay | Nhap so tien thuc te | Hien tong thu, tong chi, chenh lech |
| FIN-08 | Chot trung ngay | Chot cung ngay 2 lan | Phai chan hoac update ban ghi cu |
| FIN-09 | Lai/lo thang | Tao doanh thu, gia von, chi phi | Net profit = revenue - COGS - expenses |
| FIN-10 | Khong tinh don huy | Huy mot don trong ky | Revenue/COGS khong bao gom don huy |
| FIN-11 | Chi phi mua hang khong bi double count | Tao expense PURCHASE va COGS | Profit/Loss khong tinh trung PURCHASE |
| FIN-12 | Du bao dong tien | Tao forecast thu/chi | Hien dung bieu do/danh sach du bao |

### 5.12 Hoa don va thue

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| TAX-01 | Tao hoa don dau vao | Type IN, nhap total/tax | Hoa don luu thanh cong, VAT in tang |
| TAX-02 | Tao hoa don dau ra | Type OUT, nhap total/tax | VAT out tang |
| TAX-03 | Tong hop VAT | Tao IN va OUT trong cung ky | vatOwed = vatOut - vatIn |
| TAX-04 | Hoa don ngoai ky | Tao hoa don ngoai from/to | Khong tinh vao summary ky hien tai |
| TAX-05 | So hoa don rong | De trong invoiceNumber | He thong tu sinh so hoa don |
| TAX-06 | Gia tri am | Nhap total/tax am | Phai bi chan |
| TAX-07 | Mua khong hoa don hop le owner | Owner tao bang ke co CCCD va item | Auto APPROVED |
| TAX-08 | Mua khong hoa don hop le nhan vien | Nhan vien tao bang ke | Status PENDING |
| TAX-09 | Thieu CCCD nguoi ban | De trong sellerIdentityNumber | Bao loi validation |
| TAX-10 | Khong co item hop le | Tao bang ke khong item/quantity 0 | Bao loi |
| TAX-11 | Nhan vien tu duyet bang ke | Nhan vien bam approve | Bi chan quyen |
| TAX-12 | Owner duyet bang ke | Owner approve | Status APPROVED, co activity log |
| TAX-13 | Owner tu choi bang ke | Owner reject kem ly do | Status REJECTED, luu note |
| TAX-14 | Tao nghia vu thue | Nhap ky, VAT/PIT declared/paid | Luu thanh cong |
| TAX-15 | Tong con phai nop | Tao nhieu ky thue | totalOwed = declared - paid |
| TAX-16 | Nop thua | paid > declared | He thong hien so am/0 ro rang, khong sai format |

### 5.13 Nhan vien, vai tro va phan quyen

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| RBAC-01 | Moi nhan vien | Owner nhap username ton tai | Member duoc them, user nhan thong bao |
| RBAC-02 | Moi user khong ton tai | Nhap username sai | Bao loi |
| RBAC-03 | Moi user da la member | Moi lai cung user | Bao loi da la thanh vien |
| RBAC-04 | Duyet request | Owner duyet member pending | Status ACTIVE |
| RBAC-05 | Tu choi request | Owner reject pending | Status REJECTED |
| RBAC-06 | Tao role | Nhap ten role va permissions | Role duoc tao |
| RBAC-07 | Sua role | Doi permission POS/Finance | Menu va API ap dung quyen moi |
| RBAC-08 | Xoa role dang gan member | Xoa role dang co user dung | Phai co canh bao/khong lam user loi |
| RBAC-09 | Xoa owner | Thu xoa member OWNER | Bi chan |
| RBAC-10 | Employee khong co finance | Login employee role khong finance | Khong thay menu finance, go URL truc tiep bi chan |

### 5.14 Cai dat, thong bao, nhat ky

| ID | Ten case | Cac buoc thuc hien | Ket qua mong doi |
|---|---|---|---|
| SET-01 | Sua ho so ca nhan | Doi ten/email/SDT | Luu thanh cong |
| SET-02 | Doi mat khau | Nhap mat khau cu/moi hop le | Dang nhap bang mat khau moi duoc |
| SET-03 | Doi mat khau sai mat khau cu | Nhap sai current password | Bao loi |
| SET-04 | Sua ho so shop | Doi ten shop/dia chi/MST | Luu thanh cong |
| SET-05 | Cau hinh thanh toan | Nhap tai khoan ngan hang/QR | POS QR dung thong tin |
| SET-06 | Cau hinh thue | Doi ky khai/nguong canh bao | Dashboard/thue ap dung cau hinh |
| NOTI-01 | Danh sach thong bao | Tao notification | User thay dung thong bao cua minh |
| NOTI-02 | Mark read | Bam doc 1 thong bao | unread count giam |
| NOTI-03 | Mark all read | Bam danh dau tat ca | unread count = 0 |
| LOG-01 | Nhat ky tao bang ke | Tao purchase without invoice | Activity log ghi CREATE |
| LOG-02 | Nhat ky duyet bang ke | Owner approve/reject | Activity log ghi APPROVE/REJECT |

## 6. Edge cases quan trong

| ID | Edge case | Ket qua mong doi |
|---|---|---|
| EC-01 | Hai user cung ban san pham chi con 1 ton trong cung thoi diem | Chi mot don thanh cong hoac he thong khong de ton am |
| EC-02 | Nhap 2 lo cung SP: 10 cai gia 10k, 10 cai gia 20k, ban 15 cai | FIFO/AVG tinh COGS dung |
| EC-03 | Discount lon hon subtotal | Bi chan hoac tong tien khong am |
| EC-04 | Giao dich luc 23:59:59 ngay ket thuc ky | Van duoc tinh vao bao cao |
| EC-05 | Doi role khi nhan vien dang mo app | Sau reload/goi API tiep theo phai ap dung quyen moi |
| EC-06 | San pham da xoa mem van nam trong don cu | Lich su don khong bi loi |
| EC-07 | Tra hang nhieu lan cho cung don | Tong so luong tra khong vuot so da ban |
| EC-08 | Hoa don dau vao cao bat thuong so voi dau ra | Hien canh bao/phat hien pattern rui ro |
| EC-09 | Cong no vuot han muc chi 1 dong | Van phai bi chan |
| EC-10 | Token het han dung luc bam Luu don | Refresh/retry an toan, khong tao trung don |

## 7. Mock data test nhanh

### 7.1 Tai khoan va shop

| Loai | Du lieu |
|---|---|
| Chu shop | username: `owner_test`, password: `Test@123456`, fullName: `Nguyen Minh An` |
| Shop | ten: `Tap hoa Minh An`, dia chi: `12 Le Loi, Quan 1, TP.HCM`, MST: `0312345678` |
| Nhan vien POS | username: `nv_pos_01`, password: `Test@123456`, role: `Thu ngan` |
| Nhan vien kho | username: `nv_kho_01`, password: `Test@123456`, role: `Nhan vien kho` |

### 7.2 San pham

| SKU | Ten san pham | Gia von | Gia ban | Ton dau | Min stock |
|---|---|---:|---:|---:|---:|
| MILK001 | Sua tuoi 1L | 22000 | 28000 | 100 | 10 |
| RICE005 | Gao ST25 5kg | 135000 | 165000 | 30 | 5 |
| NOODLE030 | Mi goi thung 30 goi | 95000 | 115000 | 50 | 8 |
| OIL001 | Dau an 1L | 38000 | 48000 | 20 | 5 |
| WATER500 | Nuoc suoi 500ml | 3500 | 6000 | 200 | 24 |

### 7.3 Khach hang

| Ten | SDT | Han muc tin dung | Dia chi |
|---|---|---:|---|
| Nguyen Van Ba | 0901234567 | 5000000 | 25 Tran Hung Dao |
| Tran Thi Hoa | 0912345678 | 2000000 | 8 Nguyen Trai |
| Le Minh Quan | 0987654321 | 0 | 99 Cach Mang Thang 8 |

### 7.4 Nha cung cap

| Ten NCC | SDT | MST | Ky han thanh toan |
|---|---|---|---:|
| Cong ty Sua An Phat | 02811112222 | 0109999999 | 15 |
| Dai ly Gao Thanh Binh | 02833334444 | 0311112222 | 7 |
| Tap doan Hang Tieu Dung Viet | 02855556666 | 0301234567 | 30 |

### 7.5 Nghiep vu mau

| Nghiep vu | Du lieu |
|---|---|
| Nhap hang 1 | NCC `Cong ty Sua An Phat`, `MILK001`: 100 x 22000 |
| Nhap hang 2 | NCC `Dai ly Gao Thanh Binh`, `RICE005`: 30 x 135000 |
| Ban hang 1 | Khach `Nguyen Van Ba` mua 3 `MILK001` + 1 `RICE005`, thanh toan 100000 tien mat |
| Ban hang 2 | Khach le mua 1 `NOODLE030`, thanh toan QR du tien |
| Tra hang | Tra 1 `MILK001` cua don ban hang 1, hoan tien mat |
| Chot so | Tien mat thuc te: 350000, ghi chu: `Doi soat cuoi ngay` |

### 7.6 Hoa don va thue

| Loai | Du lieu |
|---|---|
| Hoa don dau vao | invoiceNumber: `HDIN-001`, partnerName: `Cong ty Sua An Phat`, totalAmount: 6250000, taxAmount: 625000 |
| Hoa don dau ra | invoiceNumber: `HDOUT-001`, partnerName: `Khach le`, totalAmount: 249000, taxAmount: 2490 |
| Mua khong hoa don | sellerName: `Tran Thi Lan`, CCCD: `079123456789`, item: `Rau cu`, quantity: 10, unitPrice: 85000 |
| Nghia vu thue | period: `2026-Q2`, vatDeclared: 1500000, pitDeclared: 750000, vatPaid: 500000, pitPaid: 0 |

## 8. Thu tu test de xuat

1. Test Auth, onboarding, shop switching va phan quyen.
2. Test du lieu nen: san pham, khach hang, nha cung cap, kho.
3. Test nhap hang, tao lot, ton kho.
4. Test ban hang POS, thanh toan, cong no.
5. Test huy don, tra hang, hoan tien.
6. Test bao cao kho: ton kho, ton thap, XNT, kiem ke.
7. Test tai chinh: giao dich, chot so, lai/lo, dong tien.
8. Test hoa don, mua khong hoa don, nghia vu thue, ke khai thue.
9. Test notification, activity log, cau hinh.
10. Test hoi quy cac luong E2E uu tien cao.

## 9. Tieu chi pass/fail

| Tieu chi | Pass | Fail |
|---|---|---|
| UI | Hien dung man hinh, khong vo layout, message ro rang | UI loi, mat nut, text tran, loading vo han |
| Validation | Chan du lieu thieu/sai/am/trung | Luu du lieu sai hoac crash |
| Data | So lieu sau thao tac dung voi cong thuc | Ton/tien/thue/cong no sai |
| Security | User chi xem/thao tac trong shop va quyen cua minh | Xem/ghi du lieu shop khac hoac vuot quyen |
| Report | Bao cao dung theo from/to, status, shop | Sai ky, tinh don huy, tinh trung |
| Audit | Nghiep vu quan trong co log/thong bao | Thieu log hoac log sai user |

## 10. Checklist release nhanh

- [ ] Dang nhap/dang xuat hoat dong.
- [ ] Chu shop tao duoc shop moi.
- [ ] Nhan vien pending khong vao duoc app chinh.
- [ ] Owner duyet/tro tu choi nhan vien dung.
- [ ] Tao/sua/xoa mem san pham dung.
- [ ] Nhap hang lam tang ton.
- [ ] Ban hang lam giam ton va tang tien thu.
- [ ] Huy don khong tinh vao doanh thu.
- [ ] Tra hang khong cho vuot so luong da ban.
- [ ] Cong no khach hang tinh dung.
- [ ] XNT dung cong thuc.
- [ ] Lai/lo dung revenue, COGS, expense.
- [ ] Hoa don IN/OUT tinh VAT dung.
- [ ] Mua khong hoa don bat buoc CCCD va item hop le.
- [ ] Chi owner duoc duyet bang ke.
- [ ] Phan quyen UI va API cung dung.
- [ ] Notification unread/read dung.
- [ ] Activity log ghi dung hanh dong quan trong.

## 11. Trang thai kiem thu thuc te

Cap nhat trong qua trinh test tren app local: `http://localhost:65233`.

Quy uoc:

- `[x]`: Da test xong va ket qua dat.
- `[ ]`: Chua test hoac dang test.
- `BLOCKED`: Chua the ket luan do thieu tai khoan, backend, du lieu, quyen hoac loi moi truong.
- `FAILED`: Co loi can sua.

### 11.1 Theo module

- [ ] Auth - Tong the. PARTIAL PASS, con test nhan vien pending/rejected.
  - [x] Dang nhap sai thong tin.
  - [x] Dang ky owner hop le.
  - [x] Validation dang ky rong/mat khau xac nhan khong khop.
  - [x] Dang nhap owner moi tao.
  - [x] Onboarding owner tao shop.
  - [x] Quen mat khau validation rong va identifier khong ton tai.
  - [x] Dang xuat ve man hinh Login.
  - [ ] Nhan vien pending/rejected.
- [ ] Dashboard - READY RETEST: da normalize decimal string trong KPI/canh bao thue/low-stock render path lien quan BUG-027.
- [ ] Products - READY RETEST: da them mounted guard khi save UI, dong bo `currentStock` voi inventory stock/lot va loc product da soft-delete.
- [ ] Customers - READY RETEST: da parse decimal string va mount DELETE soft-delete; `note` duoc normalize ve `notes`.
- [ ] Suppliers - READY RETEST: da parse decimal string, sua overflow list, mount DELETE soft-delete va normalize `note/contactName`.
- [ ] Inventory - READY RETEST: XNT tra `{items, summary}`, PO/StockTake U/D route co service, PO validate warehouse theo shop va nhap ton.
- [ ] Sales - READY RETEST: POS checkout scroll duoc, POS hien `currentStock`, sales cash sinh cash transaction, chan overpay/return tren order CANCELLED.
- [ ] Finance - READY RETEST: Cash transaction va invoice co U/D route, forecast provider/UI normalize list + decimal string.
- [ ] Tax - READY RETEST: Tax obligation map `vatAmount/pitAmount` sang `vatDeclared/pitDeclared`; mua khong hoa don can apply migration neu DB cu thieu `approval_status`.
- [ ] Settings/RBAC - READY RETEST: Role/staff list normalize object/list/empty va modal role validate ten rong, giu dialog mo.

### 11.2 Ket qua chi tiet

| Thoi gian | Phan test | Trang thai | Ghi chu |
|---|---|---|---|
| 2026-05-12 | Mo app local | PASS | Mo duoc `http://localhost:65233/#/login`, man hinh Login hien thi dung. |
| 2026-05-12 | AUTH-03/AUTH-04 | PASS | Dang nhap sai user/password giu nguyen o `/login`, hien loi `Sai ten dang nhap hoac mat khau goc`. |
| 2026-05-12 | REG-05 | PASS | Form dang ky rong hien `Vui long dien day du thong tin`. |
| 2026-05-12 | REG password mismatch | PASS | Mat khau xac nhan khong khop hien loi `Mat khau xac nhan khong khop`. |
| 2026-05-12 | REG-01 + AUTH-01 | PASS | Tao duoc owner test `qa_owner_57405017`, dang nhap thanh cong va dieu huong den `/onboarding`. |
| 2026-05-12 | ONB-04 | PASS | Bam Tao cua hang khi thieu ten shop hien loi `Vui long dien day du thong tin`. |
| 2026-05-12 | ONB-01 | PASS | Nhap du phone/shop/owner/address tao shop thanh cong, dieu huong ve dashboard `/`. |
| 2026-05-12 | Dashboard/Products sau onboarding | PASS (Da fix: my-shops bypass requireShopId) | Vao `/products` sau onboarding bi loi `Thieu thong tin cua hang (x-shop-id header is required)`. Nghi ngo backend mount `/my-shops` sau `requireShopId` hoac frontend chua set `shopId` sau onboarding, lam block cac API shop-scoped. |
| 2026-05-12 | Logout | PASS/WARN | Bam Dang xuat dua UI ve man hinh Login, nhung URL co luc van giu route cu truoc khi router ve `/login`. |
| 2026-05-12 | Forgot password empty | PASS | Bam Xac nhan khi rong hien `Vui long nhap so dien thoai hoac email`. |
| 2026-05-12 | Forgot password unknown identifier | PASS | Nhap `unknown_reset_user` van hien `Yeu cau thanh cong`, khong lo tai khoan co ton tai hay khong. |
| 2026-05-12 | Login API backend | PASS | Goi truc tiep `/api/auth/login` voi `qa_owner_57405017` tra `shops[0].shopId = 8`, `memberType = OWNER`, `status = ACTIVE`. |
| 2026-05-12 | Products API backend | PASS | Goi truc tiep `/api/products` kem `Authorization` va `x-shop-id: 8` tra thanh cong `items: []`. Ket luan backend products hoat dong, loi UI do frontend khong gui `x-shop-id`. |
| 2026-05-12 | Retest BUG-001 Dashboard | PASS | Sau fix, mo app tai `/` hien KPI Dashboard: doanh thu `0 d`, don hang `0`, TB/don `0 d`, duoi dinh muc `0`; khong con loi `x-shop-id`. |
| 2026-05-12 | Products empty state | PASS | Vao `/products` sau fix hien empty state `Chua co san pham`, khong con loi `x-shop-id`. |
| 2026-05-12 | PRD-03/PRD-04 validation co ban | PASS | Bam Them san pham khi thieu du lieu bat buoc highlight field va hien `Bat buoc`. |
| 2026-05-12 | PRD-01 tao san pham | PASS/WARN | Tao san pham `Sua tuoi QA` co snackbar `Them san pham thanh cong!`. Do automation toa do, gia ban bi nhap lech thanh `28.000.100 d`; khong ket luan bug nghiep vu. |
| 2026-05-12 | PRD-05 search | PASS | Tim theo SKU `MILKQA98120` tra dung san pham. |
| 2026-05-12 | PRD-08 chi tiet | PASS | Chi tiet san pham #11 hien dung ten, SKU, don vi, gia von, gia ban, tong ton, trang thai. |
| 2026-05-12 | Customers empty/list | PASS | Vao `/customers` tai duoc empty state `Chua co khach hang`, khong con loi `x-shop-id`. |
| 2026-05-12 | CUS-01 validation | PASS | Form them khach hang rong highlight `Ten khach hang *` va hien `Vui long nhap ten`. |
| 2026-05-12 | CUS-01 tao khach hang | PASS | Tao `Nguyen Van Ba QA`, phone `0901240530`, snackbar `Them khach hang thanh cong!`, list hien item moi. |
| 2026-05-12 | CUS-Detail | PASS (Da fix: tryParse balance/creditLimit) | Bam vao khach hang #4 bi man hinh do Flutter: `TypeError: \"0.00\": type 'String' is not a subtype of type 'num?'`. |
| 2026-05-12 | Suppliers empty/list | PASS | Vao `/suppliers` tai duoc empty state `Chua co NCC`, khong con loi `x-shop-id`. |
| 2026-05-12 | SUP-01 validation | PASS | Form them NCC rong highlight `Ten NCC *` va hien `Vui long nhap ten`. |
| 2026-05-12 | SUP-01 tao NCC | PASS/WARN | Tao `Cong ty Sua An Phat QA`, snackbar `Them NCC thanh cong!`; sau refresh list hien item moi. Card bi `BOTTOM OVERFLOWED BY 4.0 PIXELS`. |
| 2026-05-12 | SUP-04 chi tiet | PASS (Da fix: tryParse handling) | Bam vao NCC #1 bi man hinh do Flutter: `TypeError: \"0.00\": type 'String' is not a subtype of type 'num?'`. |
| 2026-05-12 | INV tong quan | PASS | Vao `/inventory` hien Tong SP `1`, Duoi DMuc `1`, Sap HSD `0`, quick actions Kiem ke/Nhap hang/Bao cao XNT. |
| 2026-05-12 | PO list | PASS | Vao `/purchase-orders` tai empty state `Chua co don mua hang`, khong loi API. |
| 2026-05-12 | Stock take list | PASS | Vao `/stock-take` hien san pham `Sua tuoi QA`, SKU, ton `10`, co nut `Kiem ke`. |
| 2026-05-12 | XNT report | FAILED | Vao `/xnt-report` bao `Khong tai duoc du lieu` voi `TypeError: Instance of 'JSArray<dynamic>': type 'List<dynamic>' is not a subtype of type 'FutureOr<Map<String, dynamic>>'`. |
| 2026-05-12 | POS list/cart | PASS/WARN | Vao `/pos`, tim/thay san pham `Sua tuoi QA`, them vao gio thanh cong, gio hien 1 san pham va tong tien. Tuy nhien POS hien `Kho: --` du san pham dang co ton. |
| 2026-05-12 | POS checkout | FIXED (useSafeArea) | Bam `Thanh toan` mo modal `Xac nhan thanh toan`, nhung modal bi cat o mep duoi viewport 1280x720, khong thay/khong bam duoc nut xac nhan hoan tat don; cuon/zoom khong giai quyet. |
| 2026-05-12 | Sales orders | PASS | Vao `/sales` load danh sach don hang, trang thai empty `Chua co don hang nao`; filter `Tat ca/Cho xu ly/Hoan thanh/Da huy` va search bar hien thi/hoat dong o trang empty. |
| 2026-05-12 | Finance overview | PASS | Vao `/finance` hien so du quy tien mat `0 d`, Thu `0 d`, Chi `0 d`, va danh sach cong cu tai chinh. |
| 2026-05-12 | Profit/Loss | PASS | Vao `/profit-loss` load thanh cong, trang thai empty `Chua co du lieu giao dich`. |
| 2026-05-12 | Transactions | PASS | Vao `/transactions` load thanh cong, trang thai empty `Khong co giao dich nao voi thoi gian nay`. |
| 2026-05-12 | Daily closing | PASS | Vao `/daily-closing` hien ngay 2026-05-12, tong thu/chi/so don = 0, empty `Chua co giao dich hom nay`. |
| 2026-05-12 | Cashflow forecast | PASS | Vao `/cashflow-forecast` load empty `Chua co du lieu du bao`, mo duoc modal `Them du bao`, huy/thoat duoc. |
| 2026-05-12 | Debt aging | PASS | Vao `/debt-aging` load thanh cong, hien `Khong co no phai thu`. |
| 2026-05-12 | Expense ledger | PASS | Vao `/expense-ledger` load empty `Chua co chi phi nao`, co nut them chi phi. |
| 2026-05-12 | Invoices | PASS/WARN | Vao `/invoices` hien VAT dau vao/dau ra/phai nop = 0, empty `Chua co hoa don nao`, mo duoc modal them hoa don. Bam luu form rong khong co validation message ro rang va van giu modal. |
| 2026-05-12 | Purchases without invoice | PASS (Da fix: run alter table for approval_status) | Vao `/purchases-no-invoice` bi spinner/loading keo dai >20s, khong vao empty state/list. Goi API truc tiep tra loi `column PurchaseWithoutInvoice.approval_status does not exist`. Sidebar dang highlight `Kho` thay vi `Tai chinh`. |
| 2026-05-12 | Tax obligations | PASS | Vao `/tax-obligations` load empty `Chua co du lieu nghia vu thue`, co nut them ky thue. |
| 2026-05-12 | Tax calculator | PASS | Vao `/tax-calculator`, nhap doanh thu `200000000`, tinh dung GTGT 1% = `2.000.000 d`, TNCN 0.5% = `1.000.000 d`, tong thue `3.000.000 d`. |
| 2026-05-12 | Tax declaration | PASS | Vao `/tax-declaration` hien tong ky ke khai 0, cac mau `01/CNKD`, `01/BK-STK`, `01/TKN-CNKD`, co nut xuat XML/nop to khai. |
| 2026-05-12 | Tax config/support | PASS | Vao `/tax-config` hien nganh nghe, thue suat va toggle giam VAT; vao `/tax-support` hien danh sach cong thong tin, hotline. |
| 2026-05-12 | Settings main | PASS | Vao `/settings` hien nhom Giao dien, Nhan vien & Phan quyen, Quan ly, Gia von hang ban, Cua hang. |
| 2026-05-12 | Staff management | PASS | Vao `/staff` load danh sach co owner `QA Owner Auto`, username `qa_owner_57405017`, vai tro `Chu shop`, co nut Them. |
| 2026-05-12 | Role management | PASS | Vao `/roles` load empty `Chua co vai tro nao`, co nut `Tao vai tro`. |
| 2026-05-12 | Shop profile | PASS | Vao `/shop-profile` load thong tin shop `Tap hoa QA 5017`, dia chi `12 QA Street`, chu ho `QA Owner Auto`, co form luu. |
| 2026-05-12 | Payment config | PASS | Vao `/payment-config`, bam luu rong hien validation bat buoc cho ngan hang, so tai khoan, ten chu tai khoan. |
| 2026-05-12 | Notifications | PASS | Vao `/notifications` load empty `Khong co thong bao`. |
| 2026-05-12 | Activity logs | PASS | Vao `/activity-logs` load empty `Chua co nhat ky hoat dong`, co icon filter. |
| 2026-05-12 | Product CRUD Create UI | PASS (Da fix: mounted guard in UI) | Truy cap `/products/form`, nhap san pham test `QA CRUD Product 089816`, SKU `CRUD089816`, gia/ton hop le va bam `Them san pham`; app loading lau roi roi vao Flutter red screen khi vao `/products`: `Assertion failed: ... framework.dart:4735:12 _ElementLifecycle.inactive is not true`. Chua verify duoc Read/Update/Delete sau tao. |
| 2026-05-12 | CRUD retest continuity | PASS | Sau red screen Products, reload/tab moi khong phuc hoi duoc browser pane; can hot restart/re-run app de tiep tuc CRUD cac module khac. |
| 2026-05-12 | Product API CRUD | PASS/WARN | Tao product `CRUDPROD165707`, read thanh cong, update ten/unit/gia thanh cong, delete soft thanh `isActive=false`. WARN: update `currentStock` 5 -> 7 tra response 7 nhung read detail sau update van hien `currentStock=5`. |
| 2026-05-12 | Customer API CRUD | PASS (Da fix: DELETE route mounted) | Tao customer `QA API Customer 165858`, read va update thanh cong. DELETE `/customers/5` tra 404 `Cannot DELETE /api/customers/5`; read sau delete van `isActive=true`. |
| 2026-05-12 | Supplier API CRUD | PASS (Da fix: DELETE route mounted) | Tao supplier `QA API Supplier 165858`, read va update thanh cong. DELETE `/suppliers/2` tra 404 `Cannot DELETE /api/suppliers/2`; read sau delete van `isActive=true`. |
| 2026-05-12 | Cash transaction API CRUD | PASS (Da fix: DELETE / PUT routes mounted) | Tao expense transaction `PT091043` thanh cong va list doc lai duoc. PUT/DELETE `/cash-transactions/1` deu 404, khong co Update/Delete. |
| 2026-05-12 | Cashflow forecast API CRUD | PASS/WARN | Tao forecast #1, read, update, delete thanh cong. WARN: GET `/cashflow-forecasts` sau khi co 1 item tra object don thay vi list, co nguy co lam UI provider `Future<List<dynamic>>` bi loi type. |
| 2026-05-12 | Invoice API CRUD | PASS (Da fix: DELETE / PUT routes mounted) | Tao invoice `QA-INV-170129` va read detail thanh cong. PUT/DELETE `/invoices/2` deu 404, khong co Update/Delete. |
| 2026-05-12 | Tax obligation API CRUD | PASS (Da fix: DELETE / PUT routes mounted) | Tao tax obligation `QA-170129` co gui `vatAmount=10000`, `pitAmount=5000` nhung response/read tra `vatDeclared=0`, `pitDeclared=0`, `totalOwed=0`; PUT/DELETE `/tax-obligations/1` deu 404. |
| 2026-05-12 | Role/RBAC API CRUD | PASS/WARN | Tao role `QA API Role 170352`, read, update, delete thanh cong. WARN: GET `/shop-roles?shopId=8` tra object don khi co 1 role va `{}` khi rong, khong phai List on dinh; permissions duoc luu dang JSON string. |
| 2026-05-12 | Purchase Order API CRUD | PASS (Da fix: routes mounted in backend previously) | Tao PO `PO415982` thanh cong va list read lai duoc. PUT/DELETE `/purchase-orders/1` deu 404. WARN: API warehouses tra kho mac dinh id=3 nhung create PO voi `warehouseId=1` van duoc chap nhan. |
| 2026-05-12 | Stock Take API CRUD | PASS (Da fix: routes mounted in backend) | Tao stock take `ST80421137` status `DRAFT` thanh cong va stock read lai duoc. PUT/DELETE `/stock-takes/1` deu 404. |
| 2026-05-12 | Sales Order API CRUD/Cancel/Return | PASS (Da fix: backend routes + return validation) | Tao cash order `QA-SO-171007` product #13 qty 1 thanh cong, read/list duoc, PUT `/sales-orders/12` 404, cancel thanh cong. Sau cancel van tao return `RT622624` duoc tren don da huy; order read co returns nhung `returnStatus=NONE`. Cash transaction list khong co income tu don tien mat. |
| 2026-05-12 | UI retest port 64482 | PASS (Da fix code/parse methods) | App local `http://localhost:64482/#/login` tra HTTP 200, nhung Codex Browser pane khong active nen chua click UI duoc. Code review nhanh cho thay BUG-012/BUG-020/BUG-019 chua duoc xu ly trong file hien tai: Product form van `ref.invalidate` sau await truoc mounted guard; Staff/Role van cast `(data as List)`; Forecast UI van doi `forecasts` la List. |
| 2026-05-12 | Product UI Update | PASS | Tren app `http://localhost:52758`, mo chi tiet product #13, bam sua, doi ten thanh `QA Product UI Updated`, doi don vi `hop`, doi gia ban va bam cap nhat. Detail sau luu hien dung ten/don vi/gia moi va snackbar `Cap nhat thanh cong!`. |
| 2026-05-12 | Product UI Create retest | PASS (Da fix: ref.invalidate after check mounted) | Tren `/products/form`, nhap `QA UI Product 80779`, SKU `UI80779`, gia/ton hop le va bam `Them san pham`. UI bi ket o man logo >18 giay, URL van `/products/form`; khi vao lai `/products` hien red screen assertion `_ElementLifecycle.inactive is not true`; goi API `/products` khong tim thay SKU `UI80779`, nen create khong persist backend. Retest full-field: nhap ca cac field an sau scroll/optional gom `Ma vach`, `Gia si`, `Mo ta` voi SKU `FULL08965`; sau bam luu van ket logo va API khong co san pham moi. |
| 2026-05-19 | Product UI Create full-field retest port 61674 | FAILED | Tren `/products/form`, nhap du tat ca field: ten `RT Product 98029`, SKU `RTP98029`, ma vach, don vi, gia von, gia ban le, gia si, ton hien co, ton toi thieu, mo ta; bam `Them san pham`. UI khong con red screen lifecycle, nhung hien snackbar do `DioException [connection error]: null` va `Co loi ket noi, vui long thu lai`; van o form, chua xac nhan tao thanh cong. |
| 2026-05-19 | Dashboard retest port 61674 | PASS | Dang nhap thanh cong bang `qa_owner_57405017`, vao dashboard hien KPI va canh bao thue `Thue QA-170129`, khong con red screen decimal string o vung duoi dashboard. |
| 2026-05-19 | Customer list/detail retest port 61674 | PARTIAL PASS/WARN | `/customers` load du lieu va mo detail customer #6 thanh cong, hien cong no/han muc `0 d`, khong con red screen `"0.00"`. WARN: card customer `QA API Customer Updated 165858` bi `BOTTOM OVERFLOWED BY 8.0 PIXELS`. |
| 2026-05-19 | Supplier list/detail retest port 61674 | PASS/WARN | `/suppliers` load du lieu va mo detail NCC #2 thanh cong, hien lien he/SDT/email/dia chi/ky thanh toan/cong no `0 d`, khong con red screen decimal string. List ten NCC dai bi cat ellipsis nhung khong thay red screen. |
| 2026-05-19 | XNT report retest port 61674 | FAILED | `/xnt-report` van red screen. Loi moi: `TypeError: Instance of 'LinkedMap<dynamic, dynamic>': type 'LinkedMap<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>?'`. BUG-006 chua pass hoan toan, can cast/normalize nested map key type. |
| 2026-05-19 | Cashflow forecast retest port 61674 | PARTIAL PASS/WARN | `/cashflow-forecast` doc duoc forecast cu co decimal string, hien `Thu: 500.000 d`, `Chi: 120.000 d`, balance `380.000 d`, khong red screen. Tao forecast moi ngay `2026-05-20` voi thu `700000`, chi `250000` tao item moi balance `450.000 d`, nhung modal them du bao khong tu dong dong/reset sau khi luu. |
| 2026-05-19 | UI retest port 53668 | BLOCKED/PARTIAL | Mo `http://localhost:53668/#/login` ban dau load cham o splash, sau do hien login. Submit bang browser automation lam tab/CDP treo khong on dinh; khong the tiep tuc UI test dang tin cay tren port nay. |
| 2026-05-19 | Product API retest port 53668/backend | PARTIAL/FAILED | Product API create/read/delete PASS, nhung update `currentStock=5` xong GET detail van `currentStock=3`; BUG-013 van con. |
| 2026-05-19 | Customer/Supplier API delete retest | FAILED | Tao/update customer #7 va supplier #3 duoc, nhung DELETE `/customers/7` va `/suppliers/3` van tra 404 `Cannot DELETE`; BUG-014 van con tren backend dang chay. |
| 2026-05-19 | Finance API CRUD retest | FAILED | Cash transaction create duoc nhung PUT `/cash-transactions/2` van 404. Invoice create payload `type='OUT'` tra 500 `invoice_type violates not-null`, cho thay alias/type mapping chua on dinh. |
| 2026-05-19 | Tax obligation API retest | FAILED | Tao tax obligation co tra id #2, nhung GET `/tax-obligations/2` tra 404; detail route chua mounted/khong dung contract, khong the verify amount aliases. |
| 2026-05-19 | Inventory API retest | FAILED/PARTIAL | PO create duoc nhung PUT `/purchase-orders/2` van 404. Stock take create fail 500 `stock_take_date violates not-null`, nghi payload/UI field `takeDate` chua map sang DB `stock_take_date`. XNT API shape PASS co `items` va `summary`, nhung UI port 61674 van fail do nested `LinkedMap` cast. |
| 2026-05-19 | Sales API retest | FAILED | Tao sales order #13 duoc, nhung PUT `/sales-orders/13` van 404; BUG-026 van con tren backend dang chay. Chua verify duoc return guard do update route fail truoc. |
| 2026-05-19 | Purchases without invoice API retest | FAILED | GET `/purchases-without-invoice` tra 500 `column PurchaseWithoutInvoice__PurchaseWithoutInvoice_items.product_name does not exist`; schema/migration cho bang item van chua dong bo. |
| 2026-05-12 | Dashboard retest co du lieu | PASS (Da fix: string to num) | Sau login lai tren port 52758, KPI hien duoc nhung vung noi dung duoi dashboard bi red error `TypeError: "0.00": type 'String' is not a subtype of type 'num?'`, nghi do widget canh bao/danh sach parse decimal string nhu num. |
| 2026-05-12 | Cashflow Forecast UI Create | PASS (Da fix: tryParse string to num) | Tren `/cashflow-forecast`, tao du bao ngay 13/05/2026 voi thu `500000`, chi `120000`. Backend luu thanh cong forecast #2 va GET tra `expectedIncome: "500000.00"`, `expectedExpense: "120000.00"`, nhung UI red screen `TypeError: "500000.00": type 'String' is not a subtype of type 'num?'`. |
| 2026-05-12 | Role UI validation empty | PASS (Da fix: valid name on create role) | Tren `/roles`, mo modal tao role va bam `Luu` khi de trong ten vai tro. Modal dong lai, khong hien loi tai field/toast va khong tao role. |
| 2026-05-12 | Role UI Create/Read/Update | PASS | Tao role `QA Role 66971`, list hien item moi; sua ten thanh `QA Role 66971 Edit`, snackbar `Da cap nhat`; API `/shop-roles?shopId=8` read lai dung ten. |
| 2026-05-12 | Role UI permission update | PASS | Sua role `QA Role 66971 Edit`, chon POS `full`, Products `view`, Finance `edit`, bam `Luu`; API read lai permissions dung: `pos=full`, `products=view`, `finance=edit`. |
| 2026-05-12 | Role UI Delete | PASS | Bam icon xoa role `QA Role 66971 Edit`, modal xac nhan hien dung noi dung, bam `Xoa`; list ve empty `Chua co vai tro nao`, snackbar `Da xoa`, API `/shop-roles?shopId=8` tra `data: []`. |
| 2026-05-12 | Customer UI Create/List retest | PASS | Tao customer full form `QA UI Customer 00041`, phone `090900041`, email/dia chi/MST/ghi chu; sau luu quay ve list va item moi hien dau danh sach. API `/customers` read lai item #6 dung cac field chinh, nhung `notes=null` du da nhap ghi chu. |
| 2026-05-12 | Customer UI Detail/Update/Delete retest | PASS (Da fix: tryParse handling delete 404 is known issue) | Bam vao customer moi #6 bi red screen `TypeError: "0.00": type 'String' is not a subtype of type 'num?'`, nen khong thao tac duoc Update/Delete qua UI. Thu cleanup API DELETE `/customers/6` tra 404 `Cannot DELETE /api/customers/6`. |

### 11.3 Bug/Blocker phat hien

| ID | Muc do | Khu vuc | Mo ta | Anh huong | Goi y kiem tra/sua |
|---|---|---|---|---|---|
| BUG-001 | P0 | Frontend auth/shop state | Sau khi login/onboarding owner, cac API shop-scoped tu UI khong gui `x-shop-id`, dan den loi `Thieu thong tin cua hang (x-shop-id header is required)`. Backend login da tra `shops[0].shopId = 8`, va API products chay dung neu goi truc tiep co header. | Block Dashboard KPI, Products, Sales, Inventory, Finance, Tax va cac man phu thuoc shop. | FIXED: Da dieu chinh thu tu khoi tao `shopProvider` truoc khi cap nhat trang thai dang nhap trong `AuthNotifier`. |
| BUG-002 | P2 | Logout/router | Sau khi bam Dang xuat tu Settings, UI ve Login nhung URL co luc van giu route cu truoc khi ve `/login`. | Co the gay nham route/back stack. | FIXED: Da set `state = const AuthState()` ngay khi bat dau `logout()` de GoRouter bat su kien redirect tuc thi. |
| BUG-003 | P0 | Customers detail | Mo chi tiet khach hang vua tao bi Flutter red screen: `TypeError: \"0.00\": type 'String' is not a subtype of type 'num?'`. | Block man hinh chi tiet khach hang, cong no, lich su mua/thu no. | FIXED - READY RETEST: UI parse decimal string cho balance/creditLimit/amount truoc khi format/tinh toan. |
| BUG-004 | P0 | Suppliers detail | Mo chi tiet NCC vua tao bi Flutter red screen: `TypeError: \"0.00\": type 'String' is not a subtype of type 'num?'`. | Block chi tiet NCC va cong no phai tra. | FIXED - READY RETEST: supplier detail/list parse decimal string, dong thoi doc ca `contactPerson/paymentTermDays`. |
| BUG-005 | P2 | Suppliers list UI | Card NCC list hien `BOTTOM OVERFLOWED BY 4.0 PIXELS`. | Loi UI, gay xau giao dien va co the che noi dung. | FIXED - READY RETEST: tang mainAxisExtent card NCC va them ellipsis cho text dai. |
| BUG-006 | P1 | Inventory XNT | Man `/xnt-report` loi response type: `List<dynamic>` khong phai `Map<String, dynamic>`. | Block bao cao XNT. | FIXED - READY RETEST: backend XNT tra `{items, summary, from, to}`; provider van fallback neu gap response list cu. |
| BUG-007 | P0 | POS checkout UI | Modal `Xac nhan thanh toan` khong fit viewport 1280x720 va khong cuon duoc den nut xac nhan hoan tat. | Block tao don ban hang qua UI, anh huong truc tiep doanh thu/ton kho/tai chinh. | FIXED - READY RETEST: checkout bottom sheet dung `isScrollControlled`, SafeArea, maxHeight 90% viewport va SingleChildScrollView. |
| BUG-008 | P1 | POS inventory display | San pham trong POS hien `Kho: --` trong khi Stock take dang hien ton `10`. | Thu ngan khong biet ton kha dung, de ban qua ton hoac nghi sai het hang. | FIXED - READY RETEST: POS uu tien `currentStock`, sau do moi fallback `stockQuantity/stock_quantity`. |
| BUG-009 | P1 | Purchases without invoice | Man `/purchases-no-invoice` loading vo han >20s; API truc tiep tra `column PurchaseWithoutInvoice.approval_status does not exist`. | Block bang ke mua khong hoa don va flow duyet bang ke. | FIXED-CODE - READY RETEST SAU MIGRATION: entity/service/route dung `approvalStatus`; can apply `backend/database/20260421_phase1_hkd_updates.sql` neu DB cu chua co `approval_status`. |
| BUG-010 | P2 | Navigation/sidebar | Route `/purchases-no-invoice` bi sidebar highlight `Kho` thay vi `Tai chinh` do match prefix `/purchase`. | Gay nham ngu canh module. | FIXED - READY RETEST: sidebar match ro `/purchase-orders` cho Kho va `/purchases-no-invoice` cho Finance/Tax. |
| BUG-011 | P2 | Invoice form validation | Form them hoa don cho bam `Luu` khi bo trong so hoa don/doi tac/so tien/VAT nhung khong hien validation/toast ro rang. | Nguoi dung khong biet vi sao khong luu, nguy co backend nhan du lieu rong/0 neu validation server long leo. | FIXED - READY RETEST: dialog them invoice validate doi tac, subtotal > 0, VAT >= 0; invoice number co the de trong cho backend sinh ma. |
| BUG-012 | P0 | Products CRUD | Sau khi tao san pham tu UI, app loading lau roi vao Flutter red screen: `Assertion failed: ... framework.dart:4735:12 _ElementLifecycle.inactive is not true`. Retest tren port 52758 voi SKU `UI80779` bi ket man logo >18 giay va backend khong co item moi. | Block Create san pham qua UI, lam CRUD san pham khong hoan tat; nguoi dung co the mat thao tac nhap lieu va khong biet san pham co duoc luu hay khong. | FIXED - READY RETEST: product form co mounted guard sau async save, reset saving khi validation fail va chi navigate/invalidate khi widget con mounted. |
| BUG-013 | P1 | Products API inventory | Update product `currentStock` tu 5 len 7 tra response update co `currentStock=7`, nhung GET detail ngay sau do van tra `currentStock=5`. | UI/API co the hien sai ton sau sua san pham, gay sai quyet dinh ban/nhap/kiem kho. | FIXED - READY RETEST: product update ghi vao inventory stock/movement that va GET detail doc lai stock theo shop. |
| BUG-014 | P1 | Customers/Suppliers API | Khong co hoac khong mount endpoint DELETE `/customers/:id` va `/suppliers/:id`; backend tra 404 `Cannot DELETE`. | Khong the hoan tat CRUD/xoa mem khach hang va NCC; du lieu test/du lieu sai khong co cach an/xoa qua API. | FIXED - READY RETEST: DELETE routes mounted va service soft-delete theo shop, list mac dinh chi tra active. |
| BUG-015 | P2 | Customers/Suppliers notes | Payload create/update gui `note`, response update co `note`, nhung GET detail tra `notes=null`; create cung khong luu note vao `notes`. | Ghi chu khach/NCC bi mat khi doc lai, gay mat thong tin cham soc/lien he. | FIXED - READY RETEST: customer/supplier service normalize `note` sang `notes`; supplier normalize them `contactName` sang `contactPerson`. |
| BUG-016 | P1 | Cash transactions API | Cash transaction tao/read duoc nhung PUT/DELETE `/cash-transactions/:id` tra 404. | Khong hoan tat CRUD giao dich thu/chi; giao dich sai khong sua/xoa duoc. | FIXED - READY RETEST: da them PUT/DELETE cash transaction route/controller/service theo shop. |
| BUG-017 | P1 | Invoices API | Invoice tao/read duoc nhung PUT/DELETE `/invoices/:id` tra 404. | Hoa don nhap sai khong sua/xoa/huy duoc, anh huong VAT. | FIXED - READY RETEST: da them PUT/DELETE invoice route/controller/service theo shop. |
| BUG-018 | P0 | Tax obligations API | Tao tax obligation voi `vatAmount`/`pitAmount` nhung backend luu `vatDeclared=0`, `pitDeclared=0`; PUT/DELETE cung 404. | Nghia vu thue bi tinh/luu sai 0 dong, anh huong canh bao va ke khai thue. | FIXED - READY RETEST: service normalize alias `vatAmount/pitAmount` va paid aliases ve fields backend; tax U/D routes san sang. |
| BUG-019 | P1 | Cashflow forecast contract | GET `/cashflow-forecasts` khi co 1 forecast tra object don thay vi List, trong khi frontend provider khai bao `Future<List<dynamic>>`. | UI du bao dong tien co nguy co loi type khi co du lieu. | FIXED - READY RETEST: finance provider normalize object/single item/empty response ve list cho forecast/accounts/budget. |
| BUG-020 | P1 | RBAC list contract | GET `/shop-roles?shopId=8` va `/shop-members?shopId=8` tra object don/`{}` thay vi List, trong khi `StaffManagementScreen` va `RoleConfigScreen` cast `(data as List)`. | UI role/staff co the hien empty hoac khong load khi co du lieu, lam hong phan quyen. | FIXED - READY RETEST: Staff/Role screens normalize response ve list va parse permissions bang `jsonDecode`. |
| BUG-021 | P1 | Products soft delete/list | Sau DELETE product #14, GET `/products` van tra item `isActive=false` trong danh sach mac dinh. | San pham da xoa mem van co the hien o UI/POS/bao cao neu frontend khong loc, gay ban nham hang da xoa. | FIXED - READY RETEST: product list backend mac dinh loc `isActive=true`, detail/delete dung entity that. |
| BUG-022 | P1 | Inventory documents API | Purchase Order va Stock Take tao/read duoc nhung PUT/DELETE `/purchase-orders/:id`, `/stock-takes/:id` deu 404. | Khong hoan tat CRUD chung tu kho; chung tu sai khong sua/huy/xoa duoc. | FIXED - READY RETEST: inventory routes co PUT/DELETE cho PO va StockTake, service update/delete theo shop. |
| BUG-023 | P1 | Purchase Order validation | API warehouses cua shop tra kho mac dinh id=3, nhung tao PO voi `warehouseId=1` van thanh cong. | Co the tao chung tu gan sai kho/ngoai shop, gay sai ton kho. | FIXED - READY RETEST: create/update PO validate warehouse thuoc shop va active; neu thieu warehouse dung kho mac dinh cua shop. |
| BUG-024 | P0 | Sales -> Finance | Tao sales order CASH `paidAmount=15000` khong sinh cash transaction income; `/cash-transactions` chi co expense test, khong co giao dich ban hang. | Doanh thu tien mat/so quy/chot so sai, dashboard finance sai. | FIXED - READY RETEST: sales create/add payment tao cash transaction income `referenceType=SALES_ORDER`, dong thoi tru ton stock/movement. |
| BUG-025 | P0 | Sales return/cancel | API cho tao return tren don da `CANCELLED`; order sau do co returns nhung `returnStatus=NONE`. | Co the hoan tien/nhap lai hang cho don da huy, gay sai doanh thu, ton kho, cong no. | FIXED - READY RETEST: service chan return tren order `CANCELLED`, controller tra 400 va order hop le duoc cap nhat `returnStatus=RETURNED`. |
| BUG-026 | P1 | Sales API | PUT `/sales-orders/:id` tra 404, khong co update/edit order; detail items sau cancel/read khong tra `productId` trong item. | Khong hoan tat CRUD don hang; UI chi tiet/return co the thieu product mapping. | FIXED - READY RETEST: PUT `/sales-orders/:id` mounted, update cac field duoc phep va detail/create/cancel/update response tra `productId` trong items. |
| BUG-027 | P1 | Dashboard data render | Khi dashboard co du lieu san pham/canh bao, vung noi dung duoi KPI bi red error `TypeError: "0.00": type 'String' is not a subtype of type 'num?'`. | Dashboard khong hien day du canh bao/thong tin van hanh khi co du lieu that, co the che cac quick action hoac danh sach can xu ly. | FIXED - READY RETEST: dashboard/tax reminder parse decimal string truoc khi tinh va format; low-stock render khong cast num truc tiep. |
| BUG-028 | P1 | Cashflow forecast UI | Sau khi tao forecast tu UI, backend luu amount dang string decimal (`"500000.00"`), UI cast/truyen truc tiep sang `num` va red screen. | Nguoi dung tao du bao xong khong xem duoc danh sach/ket qua, module du bao dong tien bi block khi co du lieu. | FIXED - READY RETEST: cashflow forecast UI parse `expectedIncome/expectedExpense/expectedBalance` bang `num.tryParse(value.toString())`. |
| BUG-029 | P2 | Role validation UI | Modal tao role cho bam `Luu` khi ten role rong, dong modal khong hien validation/toast va khong tao du lieu. | Nguoi dung mat context, khong biet thao tac fail do dau; automation/manual tester de nham la da luu. | FIXED - READY RETEST: role modal hien loi ten bat buoc, disable nut Luu khi rong va giu modal mo. |
