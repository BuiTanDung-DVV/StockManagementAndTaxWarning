import 'reflect-metadata';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { QueryRunner } from 'typeorm';
import { AppDataSource } from '../config/db.config';
import { buildPurchasePaymentSchedule } from '../finance/purchase-payment-schedule.utils';

type DbValue = string | number | boolean | Date | null;
type Row = Record<string, DbValue>;

const DAY_MS = 24 * 60 * 60 * 1000;
const END_DATE = new Date('2026-08-31T17:30:00+07:00');
const START_DATE = new Date('2023-08-28T08:00:00+07:00');
const DATA_SCALE = 5;
const PURCHASE_CYCLES_PER_MONTH = 5;
const STOCK_TAKE_COUNT = 60;
type ProfileKey = 'construction' | 'agriculture';

type ProductDefinition = {
  name: string;
  imageFamily?: string;
  category: string;
  unit: string;
  cost: number;
  sell: number;
  minStock: number;
  maxOrderQty: number;
};

const PRODUCT_VARIANTS: Record<ProfileKey, string[]> = {
  construction: [
    'Kiến Tạo Tiêu chuẩn',
    'An Gia Phổ thông',
    'Minh Long Bền chắc',
    'Phú Khang Công trình',
    'Tân Việt Chuyên dụng',
  ],
  agriculture: [
    'Đại Nông Phổ thông',
    'Việt Nông Mùa vụ',
    'Sinh Học Xanh',
    'Phú Nông Chuyên dụng',
    'An Phát Nhà vườn',
  ],
};

const CUSTOMER_CONTEXTS: Record<ProfileKey, string[]> = {
  construction: [
    'Nhà phố Tân Phú',
    'Công trình Bình Tân',
    'Đội thi công Thủ Đức',
    'Công trình Hóc Môn',
    'Nội thất Gò Vấp',
  ],
  agriculture: [
    'Vườn Củ Chi',
    'Nông hộ Đức Hòa',
    'Trang trại Hóc Môn',
    'Nhà vườn Bình Chánh',
    'Đại lý vật tư Long An',
  ],
};

const SUPPLIER_REGIONS = [
  'Kho TP.HCM',
  'Kho Bình Dương',
  'Kho Đồng Nai',
  'Kho Long An',
  'Kênh dự án miền Nam',
];

function expandStoreProfile(base: StoreProfile): StoreProfile {
  const variants = PRODUCT_VARIANTS[base.key];
  if (variants.length !== DATA_SCALE) {
    throw new Error(`Hồ sơ ${base.key} phải có đúng ${DATA_SCALE} biến thể sản phẩm`);
  }
  const multipliers = [0.94, 1, 1.06, 1.12, 1.18];
  const products = base.products.flatMap((product) =>
    variants.map((variant, index) => ({
      ...product,
      name: `${product.name} · ${variant}`,
      imageFamily: product.name,
      cost: roundMoney(product.cost * multipliers[index]),
      sell: roundMoney(product.sell * multipliers[index]),
      minStock: Math.max(
        1,
        Math.round(product.minStock * (0.82 + index * 0.09)),
      ),
      maxOrderQty: Math.max(
        1,
        Math.round(product.maxOrderQty * (0.9 + index * 0.05)),
      ),
    })),
  );
  const customers = base.customers.flatMap((name) => {
    const displayName = name.split(' · ')[0].trim();
    return CUSTOMER_CONTEXTS[base.key].map(
      (context) => `${displayName} · ${context}`,
    );
  });
  const suppliers = base.suppliers.flatMap((name) =>
    SUPPLIER_REGIONS.map((region) => `${name} · ${region}`),
  );
  return {
    ...base,
    datasetVersion: `${base.datasetVersion}_DENSE_V3`,
    openingCash: base.openingCash * DATA_SCALE,
    openingBank: base.openingBank * DATA_SCALE,
    products,
    customers,
    suppliers,
  };
}

type StoreProfile = {
  key: ProfileKey;
  datasetVersion: string;
  skuPrefix: string;
  description: string;
  peakMonths: number[];
  openingCash: number;
  openingBank: number;
  products: ProductDefinition[];
  customers: string[];
  suppliers: string[];
};

const constructionRetailCustomers = [
  'Nguyễn Văn Hùng · Nhà ở Tân Phú', 'Trần Minh Khôi · Công trình Bình Tân',
  'Lê Hoàng Nam · Thợ hồ Quận 12', 'Phạm Quốc Việt · Sửa nhà Gò Vấp',
  'Võ Thanh Tùng · Công trình Thủ Đức', 'Đặng Gia Bảo · Nhà phố Hóc Môn',
  'Bùi Đức Thành · Thầu xây tô', 'Đỗ Minh Trí · Thi công điện nước',
  'Hồ Quang Phúc · Nội thất căn hộ', 'Ngô Thành Luân · Đội ốp lát',
  'Dương Anh Khoa · Sửa chữa dân dụng', 'Mai Tuấn Kiệt · Nhà trọ Bình Chánh',
];

const agricultureRetailCustomers = [
  'Nguyễn Thị Hạnh · Vườn rau Củ Chi', 'Trần Văn Lợi · Ruộng lúa Đức Hòa',
  'Lê Minh Tâm · Vườn mai Hóc Môn', 'Phạm Thị Ngọc · Trại cây giống',
  'Võ Văn Sang · Vườn cây ăn trái', 'Đặng Quốc Thái · Trang trại dưa lưới',
  'Bùi Thanh Bình · Đại lý vật tư xã', 'Đỗ Thị Lan · Vườn hoa kiểng',
  'Hồ Văn Phát · Tổ trồng rau sạch', 'Ngô Minh Đức · Nông hộ trồng bắp',
  'Dương Thị Mai · Vườn ươm cây', 'Tạ Quốc Cường · Trang trại tổng hợp',
];

const STORE_PROFILES: Record<ProfileKey, StoreProfile> = {
  construction: {
    key: 'construction',
    datasetVersion: 'STORE_HISTORY_3Y_CONSTRUCTION_V2',
    skuPrefix: 'VL',
    description: 'Vật liệu xây dựng, điện nước, đồ gia dụng và thiết bị phòng tắm',
    peakMonths: [1, 2, 10, 11],
    openingCash: 1800000000,
    openingBank: 200000000,
    products: [
      { name: 'Xi măng PCB40 50kg', category: 'Vật liệu thô', unit: 'Bao', cost: 76000, sell: 92000, minStock: 80, maxOrderQty: 8 },
      { name: 'Gạch ống 4 lỗ', category: 'Vật liệu thô', unit: 'Viên', cost: 1250, sell: 1650, minStock: 1500, maxOrderQty: 120 },
      { name: 'Gạch thẻ', category: 'Vật liệu thô', unit: 'Viên', cost: 980, sell: 1350, minStock: 1200, maxOrderQty: 100 },
      { name: 'Cát xây tô', category: 'Vật liệu thô', unit: 'm³', cost: 310000, sell: 390000, minStock: 15, maxOrderQty: 4 },
      { name: 'Cát bê tông', category: 'Vật liệu thô', unit: 'm³', cost: 365000, sell: 455000, minStock: 15, maxOrderQty: 4 },
      { name: 'Đá 1x2', category: 'Vật liệu thô', unit: 'm³', cost: 420000, sell: 510000, minStock: 12, maxOrderQty: 4 },
      { name: 'Thép cuộn phi 6', category: 'Sắt thép', unit: 'Kg', cost: 14200, sell: 16900, minStock: 300, maxOrderQty: 30 },
      { name: 'Thép cây phi 10', category: 'Sắt thép', unit: 'Cây', cost: 73500, sell: 88000, minStock: 80, maxOrderQty: 12 },
      { name: 'Lưới thép hàn D4', category: 'Sắt thép', unit: 'Tấm', cost: 365000, sell: 445000, minStock: 20, maxOrderQty: 4 },
      { name: 'Ống PVC phi 21', category: 'Điện nước', unit: 'Cây', cost: 28000, sell: 38000, minStock: 60, maxOrderQty: 12 },
      { name: 'Ống PVC phi 60', category: 'Điện nước', unit: 'Cây', cost: 92000, sell: 118000, minStock: 35, maxOrderQty: 8 },
      { name: 'Dây điện 2.5mm²', category: 'Điện nước', unit: 'Mét', cost: 11200, sell: 14500, minStock: 250, maxOrderQty: 30 },
      { name: 'Ổ cắm đôi', category: 'Điện nước', unit: 'Cái', cost: 58000, sell: 82000, minStock: 30, maxOrderQty: 5 },
      { name: 'Đèn LED âm trần 9W', category: 'Điện nước', unit: 'Cái', cost: 72000, sell: 105000, minStock: 35, maxOrderQty: 8 },
      { name: 'Sơn nội thất 18L', category: 'Sơn & chống thấm', unit: 'Thùng', cost: 1190000, sell: 1480000, minStock: 18, maxOrderQty: 3 },
      { name: 'Sơn lót 18L', category: 'Sơn & chống thấm', unit: 'Thùng', cost: 980000, sell: 1240000, minStock: 15, maxOrderQty: 3 },
      { name: 'Bột trét tường 40kg', category: 'Sơn & chống thấm', unit: 'Bao', cost: 168000, sell: 215000, minStock: 35, maxOrderQty: 6 },
      { name: 'Keo dán gạch 25kg', category: 'Sơn & chống thấm', unit: 'Bao', cost: 185000, sell: 238000, minStock: 30, maxOrderQty: 6 },
      { name: 'Chống thấm gốc xi măng 20kg', category: 'Sơn & chống thấm', unit: 'Thùng', cost: 620000, sell: 790000, minStock: 12, maxOrderQty: 3 },
      { name: 'Bồn cầu một khối', category: 'Thiết bị phòng tắm', unit: 'Bộ', cost: 2350000, sell: 2890000, minStock: 6, maxOrderQty: 2 },
      { name: 'Lavabo đặt bàn', category: 'Thiết bị phòng tắm', unit: 'Cái', cost: 720000, sell: 950000, minStock: 8, maxOrderQty: 2 },
      { name: 'Vòi lavabo inox', category: 'Thiết bị phòng tắm', unit: 'Bộ', cost: 315000, sell: 425000, minStock: 12, maxOrderQty: 3 },
      { name: 'Bộ sen tắm nóng lạnh', category: 'Thiết bị phòng tắm', unit: 'Bộ', cost: 890000, sell: 1190000, minStock: 8, maxOrderQty: 2 },
      { name: 'Tủ lavabo PVC 80cm', category: 'Thiết bị phòng tắm', unit: 'Bộ', cost: 2850000, sell: 3590000, minStock: 4, maxOrderQty: 1 },
      { name: 'Gương phòng tắm chống ố', category: 'Thiết bị phòng tắm', unit: 'Cái', cost: 430000, sell: 610000, minStock: 8, maxOrderQty: 2 },
      { name: 'Kệ góc inox phòng tắm', category: 'Thiết bị phòng tắm', unit: 'Cái', cost: 165000, sell: 235000, minStock: 15, maxOrderQty: 3 },
      { name: 'Chậu rửa chén inox', category: 'Đồ gia dụng', unit: 'Bộ', cost: 980000, sell: 1290000, minStock: 7, maxOrderQty: 2 },
      { name: 'Vòi rửa chén nóng lạnh', category: 'Đồ gia dụng', unit: 'Bộ', cost: 520000, sell: 720000, minStock: 10, maxOrderQty: 2 },
      { name: 'Kệ chén inox 2 tầng', category: 'Đồ gia dụng', unit: 'Cái', cost: 340000, sell: 475000, minStock: 12, maxOrderQty: 2 },
      { name: 'Thùng rác đạp chân 20L', category: 'Đồ gia dụng', unit: 'Cái', cost: 185000, sell: 265000, minStock: 15, maxOrderQty: 3 },
      { name: 'Giàn phơi inox gấp gọn', category: 'Đồ gia dụng', unit: 'Bộ', cost: 620000, sell: 820000, minStock: 8, maxOrderQty: 2 },
      { name: 'Khóa cửa tay gạt', category: 'Đồ gia dụng', unit: 'Bộ', cost: 285000, sell: 395000, minStock: 15, maxOrderQty: 3 },
    ],
    customers: [
      ...constructionRetailCustomers,
      'Công ty Xây dựng An Phát', 'Đội thầu Minh Tâm', 'Nội thất Gia Hưng',
      'Cửa hàng Điện nước Phú Thành', 'Công ty Kiến trúc Nam Việt',
      'Đội xây dựng Hòa Bình', 'Nhà thầu Thành Công', 'Xưởng nội thất Mộc Việt',
    ],
    suppliers: [
      'Nhà phân phối Vật liệu Minh Long', 'Kho thép Thành Đạt',
      'Nhà phân phối Sơn Đại Việt', 'Thiết bị điện nước Phú Khang',
      'Thiết bị vệ sinh An Gia', 'Gia dụng và Nội thất Hoàng Nam',
    ],
  },
  agriculture: {
    key: 'agriculture',
    datasetVersion: 'STORE_HISTORY_3Y_AGRICULTURE_V2',
    skuPrefix: 'NN',
    description: 'Phân bón, hạt giống, bảo vệ thực vật và vật tư nông nghiệp',
    peakMonths: [0, 1, 4, 5, 8, 9],
    openingCash: 4000000000,
    openingBank: 900000000,
    products: [
      { name: 'Phân NPK 16-16-8 50kg', category: 'Phân vô cơ', unit: 'Bao', cost: 620000, sell: 715000, minStock: 35, maxOrderQty: 6 },
      { name: 'Phân NPK 20-20-15 50kg', category: 'Phân vô cơ', unit: 'Bao', cost: 795000, sell: 920000, minStock: 30, maxOrderQty: 6 },
      { name: 'Phân urê 46% 50kg', category: 'Phân vô cơ', unit: 'Bao', cost: 690000, sell: 790000, minStock: 30, maxOrderQty: 6 },
      { name: 'Phân DAP 18-46-0 50kg', category: 'Phân vô cơ', unit: 'Bao', cost: 1080000, sell: 1230000, minStock: 24, maxOrderQty: 5 },
      { name: 'Phân kali KCl 50kg', category: 'Phân vô cơ', unit: 'Bao', cost: 760000, sell: 875000, minStock: 24, maxOrderQty: 5 },
      { name: 'Vôi nông nghiệp 25kg', category: 'Phân vô cơ', unit: 'Bao', cost: 62000, sell: 85000, minStock: 50, maxOrderQty: 10 },
      { name: 'Phân hữu cơ vi sinh 25kg', category: 'Phân hữu cơ & vi sinh', unit: 'Bao', cost: 145000, sell: 195000, minStock: 40, maxOrderQty: 8 },
      { name: 'Phân trùn quế 10kg', category: 'Phân hữu cơ & vi sinh', unit: 'Bao', cost: 78000, sell: 115000, minStock: 35, maxOrderQty: 6 },
      { name: 'Chế phẩm vi sinh xử lý đất 1kg', category: 'Phân hữu cơ & vi sinh', unit: 'Gói', cost: 92000, sell: 135000, minStock: 25, maxOrderQty: 4 },
      { name: 'Phân bón lá vi lượng 500ml', category: 'Phân hữu cơ & vi sinh', unit: 'Chai', cost: 68000, sell: 98000, minStock: 30, maxOrderQty: 4 },
      { name: 'Thuốc trừ sâu sinh học 500ml', category: 'Bảo vệ thực vật', unit: 'Chai', cost: 118000, sell: 158000, minStock: 20, maxOrderQty: 4 },
      { name: 'Thuốc trừ bệnh sinh học 500g', category: 'Bảo vệ thực vật', unit: 'Gói', cost: 135000, sell: 179000, minStock: 20, maxOrderQty: 4 },
      { name: 'Thuốc trừ cỏ chọn lọc 500ml', category: 'Bảo vệ thực vật', unit: 'Chai', cost: 98000, sell: 139000, minStock: 18, maxOrderQty: 3 },
      { name: 'Bẫy côn trùng sinh học', category: 'Bảo vệ thực vật', unit: 'Bộ', cost: 42000, sell: 65000, minStock: 30, maxOrderQty: 5 },
      { name: 'Hạt giống lúa xác nhận 10kg', category: 'Hạt giống', unit: 'Bao', cost: 285000, sell: 345000, minStock: 25, maxOrderQty: 5 },
      { name: 'Hạt giống bắp lai 1kg', category: 'Hạt giống', unit: 'Gói', cost: 112000, sell: 148000, minStock: 25, maxOrderQty: 4 },
      { name: 'Hạt giống rau cải 100g', category: 'Hạt giống', unit: 'Gói', cost: 36000, sell: 55000, minStock: 35, maxOrderQty: 5 },
      { name: 'Hạt giống dưa leo 50g', category: 'Hạt giống', unit: 'Gói', cost: 52000, sell: 78000, minStock: 25, maxOrderQty: 4 },
      { name: 'Hạt giống cà chua 20g', category: 'Hạt giống', unit: 'Gói', cost: 68000, sell: 99000, minStock: 20, maxOrderQty: 4 },
      { name: 'Đất sạch trồng rau 20L', category: 'Giá thể & đất trồng', unit: 'Bao', cost: 42000, sell: 62000, minStock: 40, maxOrderQty: 8 },
      { name: 'Xơ dừa đã xử lý 20L', category: 'Giá thể & đất trồng', unit: 'Bao', cost: 38000, sell: 58000, minStock: 35, maxOrderQty: 8 },
      { name: 'Trấu hun 20L', category: 'Giá thể & đất trồng', unit: 'Bao', cost: 35000, sell: 52000, minStock: 35, maxOrderQty: 8 },
      { name: 'Khay ươm 105 lỗ', category: 'Vật tư nông nghiệp', unit: 'Cái', cost: 28000, sell: 42000, minStock: 30, maxOrderQty: 5 },
      { name: 'Bầu ươm cây 12x18cm', category: 'Vật tư nông nghiệp', unit: 'Kg', cost: 58000, sell: 82000, minStock: 20, maxOrderQty: 4 },
      { name: 'Bình phun điện 20L', category: 'Vật tư nông nghiệp', unit: 'Cái', cost: 780000, sell: 990000, minStock: 6, maxOrderQty: 2 },
      { name: 'Dây tưới PE phi 16', category: 'Vật tư nông nghiệp', unit: 'Cuộn', cost: 265000, sell: 345000, minStock: 12, maxOrderQty: 3 },
      { name: 'Béc tưới phun mưa', category: 'Vật tư nông nghiệp', unit: 'Cái', cost: 18000, sell: 29000, minStock: 80, maxOrderQty: 15 },
      { name: 'Lưới che nắng 2m x 50m', category: 'Vật tư nông nghiệp', unit: 'Cuộn', cost: 690000, sell: 875000, minStock: 8, maxOrderQty: 2 },
      { name: 'Kéo cắt cành', category: 'Vật tư nông nghiệp', unit: 'Cái', cost: 125000, sell: 185000, minStock: 15, maxOrderQty: 3 },
      { name: 'Găng tay làm vườn', category: 'Vật tư nông nghiệp', unit: 'Đôi', cost: 18000, sell: 32000, minStock: 40, maxOrderQty: 6 },
    ],
    customers: [
      ...agricultureRetailCustomers,
      'Hợp tác xã Nông nghiệp Bình Minh', 'Trang trại Rau sạch An Nhiên',
      'Tổ hợp tác Lúa giống Hòa Phát', 'Nhà vườn Cây ăn trái Thành Công',
      'Đại lý Nông nghiệp Phú Điền', 'Trang trại Hoa màu Tân Lập',
      'Hợp tác xã Rau an toàn Việt Xanh', 'Nhà vườn Minh Tâm',
    ],
    suppliers: [
      'Nhà phân phối Phân bón Đại Nông', 'Kho vật tư Nông nghiệp Miền Nam',
      'Công ty Hạt giống Việt Nông', 'Nhà phân phối Sinh học Xanh',
      'Thiết bị tưới Phú Nông', 'Giá thể và Đất sạch An Phát',
    ],
  },
};

function parseNumberArg(name: string): number | undefined {
  const raw = process.argv.find((arg) => arg.startsWith(`--${name}=`));
  if (!raw) return undefined;
  const value = Number(raw.slice(name.length + 3));
  return Number.isInteger(value) && value > 0 ? value : undefined;
}

function parseProfileArg(): ProfileKey | undefined {
  const raw = process.argv.find((arg) => arg.startsWith('--profile='));
  const value = raw?.slice('--profile='.length);
  return value === 'construction' || value === 'agriculture' ? value : undefined;
}

function hasFlag(name: string): boolean {
  return process.argv.includes(`--${name}`);
}

function createRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state += 0x6d2b79f5;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function customerBaseIndex(profile: StoreProfile, customerIndex: number): number {
  return Math.floor(customerIndex / CUSTOMER_CONTEXTS[profile.key].length);
}

function customerType(profile: StoreProfile, customerIndex: number): 'RETAIL' | 'VIP' | 'WHOLESALE' {
  const baseIndex = customerBaseIndex(profile, customerIndex);
  if (baseIndex >= 12) return 'WHOLESALE';
  return baseIndex % 7 === 0 ? 'VIP' : 'RETAIL';
}

function buildCustomerWeights(profile: StoreProfile): number[] {
  return profile.customers.map((_, index) => {
    const baseIndex = customerBaseIndex(profile, index);
    if (baseIndex < 3) return 8;
    if (baseIndex < 4) return 3;
    if (baseIndex < 8) return 1.5;
    if (baseIndex < 12) return 1;
    if (baseIndex < 16) return 3;
    return 1.2;
  });
}

function buildProductWeights(profile: StoreProfile): number[] {
  const categoryWeights: Record<ProfileKey, Record<string, number>> = {
    construction: {
      'Vật liệu thô': 1.8,
      'Sắt thép': 1.65,
      'Điện nước': 2.05,
      'Sơn & chống thấm': 2.1,
      'Thiết bị phòng tắm': 2.55,
      'Đồ gia dụng': 1,
    },
    agriculture: {
      'Phân vô cơ': 2.35,
      'Phân hữu cơ & vi sinh': 1.8,
      'Bảo vệ thực vật': 1.55,
      'Hạt giống': 2.15,
      'Giá thể & đất trồng': 1.25,
      'Vật tư nông nghiệp': 1.45,
    },
  };
  const variantWeights = [1.08, 1.02, 0.98, 0.93, 0.87];
  return profile.products.map((product, index) => (
    (categoryWeights[profile.key][product.category] ?? 1) * variantWeights[index % DATA_SCALE]
  ));
}

function pickWeightedIndex(random: () => number, weights: number[]): number {
  const totalWeight = weights.reduce((sum, weight) => sum + weight, 0);
  let cursor = random() * totalWeight;
  for (let index = 0; index < weights.length; index += 1) {
    cursor -= weights[index];
    if (cursor < 0) return index;
  }
  return Math.max(weights.length - 1, 0);
}

function roundMoney(value: number): number {
  if (value < 10_000) return Math.round(value / 50) * 50;
  if (value < 100_000) return Math.round(value / 500) * 500;
  return Math.round(value / 1000) * 1000;
}

function dateOnly(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function atLocalTime(date: Date, hour: number, minute: number): Date {
  const value = new Date(date);
  value.setHours(hour, minute, 0, 0);
  return value;
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * DAY_MS);
}

function monthKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

function quarterKey(date: Date): string {
  return `Q${Math.floor(date.getMonth() / 3) + 1}/${date.getFullYear()}`;
}

async function bulkInsert(
  runner: QueryRunner,
  table: string,
  columns: string[],
  rows: Row[],
  returning = '',
  chunkSize = 500,
): Promise<Record<string, unknown>[]> {
  const result: Record<string, unknown>[] = [];
  for (let offset = 0; offset < rows.length; offset += chunkSize) {
    const chunk = rows.slice(offset, offset + chunkSize);
    const values: DbValue[] = [];
    const tuples = chunk.map((row) => {
      const placeholders = columns.map((column) => {
        values.push(row[column] ?? null);
        return `$${values.length}`;
      });
      return `(${placeholders.join(', ')})`;
    });
    const returned = await runner.query(
      `INSERT INTO ${table} (${columns.join(', ')}) VALUES ${tuples.join(', ')}${returning ? ` RETURNING ${returning}` : ''}`,
      values,
    );
    if (Array.isArray(returned)) result.push(...returned);
  }
  return result;
}

async function clearExistingShopData(
  runner: QueryRunner,
  shopId: number,
): Promise<void> {
  const statements = [
    'DELETE FROM journal_lines WHERE journal_entry_id IN (SELECT id FROM journal_entries WHERE shop_id = $1)',
    'DELETE FROM journal_entries WHERE shop_id = $1',
    'DELETE FROM sales_order_lot_deductions WHERE order_id IN (SELECT id FROM sales_orders WHERE shop_id = $1)',
    'DELETE FROM sales_return_items WHERE return_id IN (SELECT id FROM sales_returns WHERE shop_id = $1)',
    'DELETE FROM sales_returns WHERE shop_id = $1',
    'DELETE FROM debt_evidences WHERE shop_id = $1',
    'DELETE FROM debt_payment_history WHERE shop_id = $1',
    'DELETE FROM receivables WHERE shop_id = $1',
    'DELETE FROM sales_order_payments WHERE shop_id = $1',
    'DELETE FROM sales_order_items WHERE shop_id = $1',
    'DELETE FROM sales_orders WHERE shop_id = $1',
    'DELETE FROM invoice_items WHERE invoice_id IN (SELECT id FROM invoices WHERE shop_id = $1)',
    'DELETE FROM invoices WHERE shop_id = $1',
    'DELETE FROM invoice_scans WHERE shop_id = $1',
    'DELETE FROM stock_take_items WHERE stock_take_id IN (SELECT id FROM stock_takes WHERE shop_id = $1)',
    'DELETE FROM stock_takes WHERE shop_id = $1',
    'DELETE FROM inventory_lots WHERE shop_id = $1',
    'DELETE FROM inventory_movements WHERE shop_id = $1',
    'DELETE FROM inventory_stocks WHERE shop_id = $1',
    'DELETE FROM purchase_order_items WHERE order_id IN (SELECT id FROM purchase_orders WHERE shop_id = $1)',
    'DELETE FROM payables WHERE shop_id = $1',
    'DELETE FROM purchase_orders WHERE shop_id = $1',
    'DELETE FROM purchase_without_invoice_items WHERE shop_id = $1',
    'DELETE FROM purchases_without_invoice WHERE shop_id = $1',
    'DELETE FROM cash_transactions WHERE shop_id = $1',
    'DELETE FROM cash_accounts WHERE shop_id = $1',
    'DELETE FROM budget_plans WHERE shop_id = $1',
    'DELETE FROM cashflow_forecasts WHERE shop_id = $1',
    'DELETE FROM daily_closings WHERE shop_id = $1',
    'DELETE FROM tax_obligations WHERE shop_id = $1',
    'DELETE FROM financial_ledger WHERE shop_id = $1',
    'DELETE FROM ai_knowledge_documents WHERE shop_id = $1',
    'DELETE FROM activity_logs WHERE shop_id = $1',
    'DELETE FROM product_cost_items WHERE shop_id = $1',
    'DELETE FROM product_batches WHERE shop_id = $1',
    'DELETE FROM unit_conversions WHERE shop_id = $1',
    'DELETE FROM product_price_history WHERE shop_id = $1',
    'DELETE FROM products WHERE shop_id = $1',
    'DELETE FROM categories WHERE shop_id = $1',
    'DELETE FROM tags WHERE shop_id = $1',
    'DELETE FROM cost_types WHERE shop_id = $1',
    'DELETE FROM customers WHERE shop_id = $1',
    'DELETE FROM suppliers WHERE shop_id = $1',
    'DELETE FROM warehouses WHERE shop_id = $1',
  ];
  for (const statement of statements) {
    await runner.query(statement, [shopId]);
  }
}

async function ensureValidationSchema(runner: QueryRunner): Promise<void> {
  const rows = await runner.query(
    `
      SELECT
        TO_REGCLASS('public.ai_knowledge_documents') AS "aiTable",
        EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conrelid = 'public.daily_closings'::regclass
            AND conname = 'UQ_daily_closings_shop_date'
            AND pg_get_constraintdef(oid) LIKE '%shop_id, closing_date%'
        ) AS "closingConstraintReady",
        NOT EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'purchase_without_invoice_items'
            AND column_name = 'item_name'
            AND is_nullable = 'NO'
        ) AS "purchaseItemReady"
    `,
  );
  const migrationFiles = [
    ...(!rows[0]?.aiTable ? ['20260728_create_ai_knowledge_documents.sql'] : []),
    ...(!rows[0]?.closingConstraintReady
      ? ['20260728_fix_daily_closing_multi_shop_unique.sql']
      : []),
    ...(!rows[0]?.purchaseItemReady
      ? ['20260729_fix_purchase_without_invoice_item_compatibility.sql']
      : []),
  ];
  for (const fileName of migrationFiles) {
    const migrationPath = resolve(process.cwd(), 'database', fileName);
    const migration = (await readFile(migrationPath, 'utf8'))
      .replace(/^\s*BEGIN;\s*/i, '')
      .replace(/\s*COMMIT;\s*$/i, '');
    await runner.query(migration);
  }
}

async function validateGeneratedData(
  runner: QueryRunner,
  shopId: number,
  expectedProductCount: number,
): Promise<void> {
  const rows = await runner.query(`
    SELECT
      (
        SELECT COUNT(*)
        FROM (
          SELECT o.id
          FROM sales_orders o
          LEFT JOIN sales_order_items i ON i.order_id = o.id
          WHERE o.shop_id = $1
          GROUP BY o.id
          HAVING ABS(COALESCE(o.subtotal, 0) - COALESCE(SUM(i.subtotal), 0)) > 1
            OR ABS(
              COALESCE(o.total_amount, 0) -
              (COALESCE(o.subtotal, 0) - COALESCE(o.discount_amount, 0) + COALESCE(o.tax_amount, 0))
            ) > 1
        ) invalid_orders
      )::int AS "invalidOrders",
      (
        SELECT COUNT(*)
        FROM (
          SELECT
            COALESCE(s.product_id, m.product_id) AS product_id,
            COALESCE(s.warehouse_id, m.warehouse_id) AS warehouse_id,
            COALESCE(s.quantity, 0) AS stock_quantity,
            COALESCE(m.quantity, 0) AS movement_quantity
          FROM (
            SELECT product_id, warehouse_id, SUM(quantity) AS quantity
            FROM inventory_stocks WHERE shop_id = $1
            GROUP BY product_id, warehouse_id
          ) s
          FULL JOIN (
            SELECT product_id, warehouse_id,
              SUM(CASE
                WHEN movement_type IN ('IN', 'RETURN') THEN quantity
                WHEN movement_type = 'OUT' THEN -quantity
                ELSE quantity
              END) AS quantity
            FROM inventory_movements WHERE shop_id = $1
            GROUP BY product_id, warehouse_id
          ) m ON m.product_id = s.product_id AND m.warehouse_id = s.warehouse_id
        ) stock_compare
        WHERE ABS(stock_quantity - movement_quantity) > 0.001
      )::int AS "invalidStocks",
      (
        SELECT COUNT(*) FROM inventory_stocks
        WHERE shop_id = $1 AND quantity < 0
      )::int AS "negativeStocks",
      (
        SELECT COUNT(*)
        FROM customers c
        LEFT JOIN (
          SELECT customer_id, SUM(GREATEST(amount - paid_amount, 0)) AS remaining
          FROM receivables WHERE shop_id = $1
          GROUP BY customer_id
        ) debt ON debt.customer_id = c.id
        WHERE c.shop_id = $1
          AND ABS(COALESCE(c.balance, 0) - COALESCE(debt.remaining, 0)) > 1
      )::int AS "invalidCustomerBalances",
      (
        SELECT COUNT(*)
        FROM suppliers s
        LEFT JOIN (
          SELECT supplier_id, SUM(GREATEST(amount - paid_amount, 0)) AS remaining
          FROM payables WHERE shop_id = $1
          GROUP BY supplier_id
        ) debt ON debt.supplier_id = s.id
        WHERE s.shop_id = $1
          AND ABS(COALESCE(s.balance, 0) - COALESCE(debt.remaining, 0)) > 1
      )::int AS "invalidSupplierBalances",
      (
        SELECT COUNT(*)
        FROM (
          SELECT e.id
          FROM journal_entries e
          JOIN journal_lines l ON l.journal_entry_id = e.id
          WHERE e.shop_id = $1 AND e.is_voided = false
          GROUP BY e.id
          HAVING ABS(
            SUM(CASE WHEN l.entry_type = 'DEBIT' THEN l.amount ELSE 0 END) -
            SUM(CASE WHEN l.entry_type = 'CREDIT' THEN l.amount ELSE 0 END)
          ) > 1
        ) invalid_journals
      )::int AS "invalidJournals",
      (
        SELECT COUNT(*)
        FROM cash_accounts a
        LEFT JOIN (
          SELECT account_id,
            SUM(CASE WHEN type = 'INCOME' THEN amount ELSE -amount END) AS balance
          FROM cash_transactions WHERE shop_id = $1
          GROUP BY account_id
        ) tx ON tx.account_id = a.id
        WHERE a.shop_id = $1
          AND ABS(COALESCE(a.balance, 0) - COALESCE(tx.balance, 0)) > 1
      )::int AS "invalidCashBalances",
      (
        SELECT COUNT(*)
        FROM generate_series($2::date, $3::date, interval '1 day') day
        WHERE NOT EXISTS (
          SELECT 1 FROM sales_orders o
          WHERE o.shop_id = $1 AND o.order_date::date = day::date
        )
      )::int AS "missingSalesDays",
      (SELECT COUNT(*)::int FROM daily_closings WHERE shop_id = $1) AS "closingCount",
      (SELECT COUNT(*)::int FROM purchase_orders WHERE shop_id = $1) AS "purchaseCount",
      (SELECT COUNT(*)::int FROM sales_returns WHERE shop_id = $1) AS "returnCount",
      (SELECT COUNT(*)::int FROM invoices WHERE shop_id = $1) AS "invoiceCount",
      (SELECT COUNT(*)::int FROM receivables WHERE shop_id = $1) AS "receivableCount",
      (SELECT COUNT(*)::int FROM ai_knowledge_documents WHERE shop_id = $1) AS "knowledgeCount",
      (SELECT COUNT(*)::int FROM products WHERE shop_id = $1) AS "productCount",
      (
        SELECT COUNT(*)::int FROM products
        WHERE shop_id = $1 AND COALESCE(TRIM(image_url), '') = ''
      ) AS "productsWithoutImage",
      (SELECT COUNT(*)::int FROM invoice_scans WHERE shop_id = $1) AS "invoiceScanCount",
      (SELECT COUNT(*)::int FROM debt_evidences WHERE shop_id = $1) AS "debtEvidenceCount",
      (
        SELECT COUNT(*)::int FROM cash_transactions
        WHERE shop_id = $1 AND COALESCE(TRIM(receipt_image_url), '') != ''
      ) AS "receiptImageCount",
      (SELECT COUNT(*)::int FROM tags WHERE shop_id = $1) AS "tagCount",
      (SELECT COUNT(*)::int FROM product_batches WHERE shop_id = $1) AS "batchCount",
      (SELECT COUNT(*)::int FROM inventory_lots WHERE shop_id = $1) AS "lotCount",
      (SELECT COUNT(*)::int FROM stock_takes WHERE shop_id = $1) AS "stockTakeCount",
      (SELECT COUNT(*)::int FROM cashflow_forecasts WHERE shop_id = $1) AS "forecastCount",
      (
        SELECT COUNT(*)::int FROM purchases_without_invoice WHERE shop_id = $1
      ) AS "purchaseWithoutInvoiceCount",
      (SELECT COUNT(*)::int FROM activity_logs WHERE shop_id = $1) AS "activityLogCount",
      (SELECT COUNT(*)::int FROM financial_ledger WHERE shop_id = $1) AS "ledgerCount",
      (SELECT COUNT(*)::int FROM cash_transactions WHERE shop_id = $1) AS "cashTransactionCount",
      (
        SELECT ABS(
          COALESCE((
            SELECT SUM(CASE WHEN l.entry_type = 'CREDIT' THEN l.amount ELSE -l.amount END)
            FROM journal_lines l
            JOIN journal_entries e ON e.id = l.journal_entry_id
            WHERE e.shop_id = $1 AND e.is_voided = false AND l.account_code = '511'
          ), 0) -
          (
            COALESCE((SELECT SUM(total_amount) FROM sales_orders WHERE shop_id = $1 AND status != 'CANCELLED'), 0) -
            COALESCE((SELECT SUM(refund_amount) FROM sales_returns WHERE shop_id = $1 AND status != 'CANCELLED'), 0)
          )
        )
      ) AS "revenueDifference",
      (
        SELECT ABS(
          COALESCE((
            SELECT SUM(CASE WHEN l.entry_type = 'DEBIT' THEN l.amount ELSE -l.amount END)
            FROM journal_lines l
            JOIN journal_entries e ON e.id = l.journal_entry_id
            WHERE e.shop_id = $1 AND e.is_voided = false AND l.account_code = '632'
          ), 0) -
          (
            COALESCE((SELECT SUM(total_cogs) FROM sales_orders WHERE shop_id = $1 AND status != 'CANCELLED'), 0) -
            COALESCE((
              SELECT SUM(o.total_cogs)
              FROM sales_returns r
              JOIN sales_orders o ON o.id = r.order_id
              WHERE r.shop_id = $1 AND r.status != 'CANCELLED'
            ), 0)
          )
        )
      ) AS "cogsDifference"
  `, [shopId, dateOnly(START_DATE), dateOnly(END_DATE)]);
  const result = rows[0];
  const expectedDays =
    Math.floor((END_DATE.getTime() - START_DATE.getTime()) / DAY_MS) + 1;
  const failures = [
    ['invalidOrders', Number(result.invalidOrders)],
    ['invalidStocks', Number(result.invalidStocks)],
    ['negativeStocks', Number(result.negativeStocks)],
    ['invalidCustomerBalances', Number(result.invalidCustomerBalances)],
    ['invalidSupplierBalances', Number(result.invalidSupplierBalances)],
    ['invalidJournals', Number(result.invalidJournals)],
    ['invalidCashBalances', Number(result.invalidCashBalances)],
    ['missingSalesDays', Number(result.missingSalesDays)],
    ['closingCount', Math.abs(Number(result.closingCount) - expectedDays)],
    ['purchaseCount', Math.abs(Number(result.purchaseCount) - 37 * PURCHASE_CYCLES_PER_MONTH)],
    ['returnCount', Number(result.returnCount) > 0 ? 0 : 1],
    ['invoiceCount', Number(result.invoiceCount) > 0 ? 0 : 1],
    ['receivableCount', Number(result.receivableCount) > 0 ? 0 : 1],
    ['knowledgeCount', Number(result.knowledgeCount) >= 3 ? 0 : 1],
    ['productCount', Math.abs(Number(result.productCount) - expectedProductCount)],
    ['productsWithoutImage', Number(result.productsWithoutImage)],
    ['tagCount', Number(result.tagCount) >= 8 ? 0 : 1],
    ['batchCount', Math.abs(Number(result.batchCount) - expectedProductCount)],
    ['lotCount', Math.abs(Number(result.lotCount) - expectedProductCount)],
    ['stockTakeCount', Math.abs(Number(result.stockTakeCount) - STOCK_TAKE_COUNT)],
    ['forecastCount', Math.abs(Number(result.forecastCount) - 90)],
    ['purchaseWithoutInvoiceCount', Number(result.purchaseWithoutInvoiceCount) >= 7 ? 0 : 1],
    ['activityLogCount', Number(result.activityLogCount) >= 50 ? 0 : 1],
    ['ledgerCount', Math.abs(Number(result.ledgerCount) - Number(result.cashTransactionCount))],
    ['revenueDifference', Number(result.revenueDifference) > 1 ? Number(result.revenueDifference) : 0],
    ['cogsDifference', Number(result.cogsDifference) > 1 ? Number(result.cogsDifference) : 0],
  ].filter(([, violations]) => Number(violations) > 0);

  if (failures.length > 0) {
    throw new Error(
      `Đối soát dữ liệu tạo mới thất bại: ${failures
        .map(([name, violations]) => `${name}=${violations}`)
        .join(', ')}`,
    );
  }

  const metricRows = await runner.query(`
    WITH sales AS (
      SELECT
        COALESCE(SUM(total_amount), 0) AS gross_revenue,
        COUNT(*) AS order_count,
        COALESCE(SUM(total_amount) FILTER (
          WHERE order_date >= $2::date AND order_date < ($2::date + interval '1 year')
        ), 0) AS year_1,
        COALESCE(SUM(total_amount) FILTER (
          WHERE order_date >= ($2::date + interval '1 year')
            AND order_date < ($2::date + interval '2 years')
        ), 0) AS year_2,
        COALESCE(SUM(total_amount) FILTER (
          WHERE order_date >= ($2::date + interval '2 years')
            AND order_date <= $3::date + interval '1 day'
        ), 0) AS year_3
      FROM sales_orders
      WHERE shop_id = $1 AND status != 'CANCELLED'
    ),
    returns AS (
      SELECT COALESCE(SUM(refund_amount), 0) AS refund
      FROM sales_returns
      WHERE shop_id = $1 AND status != 'CANCELLED'
    ),
    ledger AS (
      SELECT
        COALESCE(SUM(
          CASE
            WHEN l.account_code = '511' AND l.entry_type = 'CREDIT' THEN l.amount
            WHEN l.account_code = '511' AND l.entry_type = 'DEBIT' THEN -l.amount
            ELSE 0
          END
        ), 0) AS revenue,
        COALESCE(SUM(
          CASE
            WHEN l.account_code = '632' AND l.entry_type = 'DEBIT' THEN l.amount
            WHEN l.account_code = '632' AND l.entry_type = 'CREDIT' THEN -l.amount
            ELSE 0
          END
        ), 0) AS cogs,
        COALESCE(SUM(
          CASE
            WHEN l.account_code = '642' AND l.entry_type = 'DEBIT' THEN l.amount
            WHEN l.account_code = '642' AND l.entry_type = 'CREDIT' THEN -l.amount
            ELSE 0
          END
        ), 0) AS operating_expense
      FROM journal_lines l
      JOIN journal_entries e ON e.id = l.journal_entry_id
      WHERE e.shop_id = $1 AND e.is_voided = false
    )
    SELECT
      sales.gross_revenue::numeric AS "grossRevenue",
      (sales.gross_revenue - returns.refund)::numeric AS "netRevenue",
      returns.refund::numeric AS "refundAmount",
      sales.order_count::int AS "orderCount",
      ledger.cogs::numeric AS "cogs",
      ledger.operating_expense::numeric AS "operatingExpense",
      (ledger.revenue - ledger.cogs - ledger.operating_expense)::numeric AS "netProfit",
      CASE WHEN ledger.revenue > 0
        THEN ((ledger.revenue - ledger.cogs) / ledger.revenue * 100)
        ELSE 0 END::numeric AS "grossMarginPct",
      CASE WHEN ledger.revenue > 0
        THEN ((ledger.revenue - ledger.cogs - ledger.operating_expense) / ledger.revenue * 100)
        ELSE 0 END::numeric AS "netMarginPct",
      CASE WHEN sales.gross_revenue > 0
        THEN (returns.refund / sales.gross_revenue * 100)
        ELSE 0 END::numeric AS "returnRatePct",
      COALESCE((
        SELECT SUM(GREATEST(amount - paid_amount, 0))
        FROM receivables WHERE shop_id = $1
      ), 0)::numeric AS "receivables",
      COALESCE((
        SELECT SUM(balance) FROM cash_accounts WHERE shop_id = $1
      ), 0)::numeric AS "cashBalance",
      COALESCE((
        SELECT SUM(balance) FROM cash_accounts
        WHERE shop_id = $1 AND account_type = 'CASH'
      ), 0)::numeric AS "cashAccountBalance",
      COALESCE((
        SELECT SUM(balance) FROM cash_accounts
        WHERE shop_id = $1 AND account_type = 'BANK'
      ), 0)::numeric AS "bankAccountBalance",
      COALESCE((
        SELECT MIN(closing_cash) FROM daily_closings WHERE shop_id = $1
      ), 0)::numeric AS "minimumClosingCash",
      COALESCE((
        SELECT SUM(s.quantity * p.cost_price)
        FROM inventory_stocks s
        JOIN products p ON p.id = s.product_id
        WHERE s.shop_id = $1
      ), 0)::numeric AS "inventoryValue",
      sales.year_1::numeric AS "year1Revenue",
      sales.year_2::numeric AS "year2Revenue",
      sales.year_3::numeric AS "year3Revenue"
    FROM sales, returns, ledger
  `, [shopId, dateOnly(START_DATE), dateOnly(END_DATE)]);
  const metrics = metricRows[0];
  const netRevenue = Number(metrics.netRevenue);
  const grossMargin = Number(metrics.grossMarginPct);
  const netMargin = Number(metrics.netMarginPct);
  const returnRate = Number(metrics.returnRatePct);
  const receivableRatio =
    netRevenue > 0 ? (Number(metrics.receivables) / netRevenue) * 100 : 0;
  const year1 = Number(metrics.year1Revenue);
  const year2 = Number(metrics.year2Revenue);
  const year3 = Number(metrics.year3Revenue);
  const qualitySummary = {
    netRevenue: Math.round(netRevenue),
    grossMarginPct: Number(grossMargin.toFixed(2)),
    netMarginPct: Number(netMargin.toFixed(2)),
    returnRatePct: Number(returnRate.toFixed(2)),
    receivableRatioPct: Number(receivableRatio.toFixed(2)),
    cashBalance: Math.round(Number(metrics.cashBalance)),
    cashAccountBalance: Math.round(Number(metrics.cashAccountBalance)),
    bankAccountBalance: Math.round(Number(metrics.bankAccountBalance)),
    minimumClosingCash: Math.round(Number(metrics.minimumClosingCash)),
    inventoryValue: Math.round(Number(metrics.inventoryValue)),
    year1Revenue: Math.round(year1),
    year2Revenue: Math.round(year2),
    year3Revenue: Math.round(year3),
  };
  console.table([qualitySummary]);
  const qualityFailures = [
    netRevenue <= 0 ? 'doanh thu không dương' : '',
    grossMargin < 15 || grossMargin > 35
      ? `biên gộp ${grossMargin.toFixed(2)}% ngoài 15–35%`
      : '',
    netMargin < 5 || netMargin > 25
      ? `biên ròng ${netMargin.toFixed(2)}% ngoài 5–25%`
      : '',
    returnRate < 0.2 || returnRate > 3
      ? `tỷ lệ trả ${returnRate.toFixed(2)}% ngoài 0,2–3%`
      : '',
    receivableRatio < 0.5 || receivableRatio > 12
      ? `công nợ ${receivableRatio.toFixed(2)}% doanh thu ngoài 0,5–12%`
      : '',
    Number(metrics.cashBalance) <= 0 ? 'số dư tiền không dương' : '',
    Number(metrics.cashAccountBalance) < 0 ? 'tài khoản tiền mặt bị âm' : '',
    Number(metrics.bankAccountBalance) < 0 ? 'tài khoản ngân hàng bị âm' : '',
    Number(metrics.minimumClosingCash) < 0 ? 'quỹ tiền mặt có ngày bị âm' : '',
    Number(metrics.inventoryValue) <= 0 ? 'giá trị tồn không dương' : '',
    year2 <= year1 * 1.02 ? 'doanh thu năm 2 không tăng tối thiểu 2%' : '',
    year3 <= year2 * 1.02 ? 'doanh thu năm 3 không tăng tối thiểu 2%' : '',
  ].filter(Boolean);
  if (qualityFailures.length > 0) {
    throw new Error(`Chất lượng số liệu chưa đạt: ${qualityFailures.join('; ')}`);
  }

  console.log('Đối soát nội bộ: PASS (tính đúng và chất lượng số liệu hiển thị).');
}

function printPlan(shopId?: number, profile?: StoreProfile): void {
  const days = Math.floor((END_DATE.getTime() - START_DATE.getTime()) / DAY_MS) + 1;
  console.log('Kế hoạch bộ dữ liệu vận hành 3 năm');
  console.log(`- Phiên bản: ${profile?.datasetVersion ?? '(chưa chọn hồ sơ ngành)'}`);
  console.log(`- Cửa hàng: ${shopId ?? '(chưa chỉ định)'}`);
  console.log(`- Hồ sơ ngành: ${profile?.description ?? '(chưa chỉ định)'}`);
  console.log(`- Thời gian: ${dateOnly(START_DATE)} đến ${dateOnly(END_DATE)} (${days} ngày)`);
  console.log(
    `- Quy mô dự kiến: ${profile?.products.length ?? 0} sản phẩm, ` +
    `${profile?.customers.length ?? 0} khách hàng, ${profile?.suppliers.length ?? 0} nhà cung cấp`,
  );
  console.log(
    `- Khoảng 35.000–42.000 đơn bán, ${37 * PURCHASE_CYCLES_PER_MONTH} kỳ nhập hàng ` +
    `và ${STOCK_TAKE_COUNT} lần kiểm kê`,
  );
  console.log('- Mặc định không ghi database. Dùng --apply sau khi đã kiểm tra đúng shop-id.');
}

async function seed(
  shopId: number,
  profile: StoreProfile,
  commitChanges: boolean,
  replaceExisting: boolean,
): Promise<void> {
  await AppDataSource.initialize();
  const runner = AppDataSource.createQueryRunner();
  await runner.connect();
  await runner.startTransaction();
  await runner.query("SET LOCAL statement_timeout = '10min'");

  try {
    if (!commitChanges) {
      await ensureValidationSchema(runner);
    }
    const shops = await runner.query(
      'SELECT id, shop_name FROM shop_profiles WHERE id = $1 FOR UPDATE',
      [shopId],
    );
    if (!shops.length) throw new Error(`Không tìm thấy cửa hàng id=${shopId}`);

    const existingProductMedia = await runner.query(
      `SELECT
         TRIM(SPLIT_PART(name, CHR(183), 1)) AS family,
         MAX(image_url) FILTER (WHERE image_url IS NOT NULL) AS image_url
       FROM products
       WHERE shop_id = $1
       GROUP BY TRIM(SPLIT_PART(name, CHR(183), 1))`,
      [shopId],
    );
    const imageUrlByFamily = new Map<string, string>(
      existingProductMedia
        .filter((row: { image_url?: string | null }) => row.image_url)
        .map((row: { family: string; image_url: string }) => [row.family, row.image_url]),
    );
    const existingMedia = await runner.query(
      `SELECT
         ARRAY_REMOVE(ARRAY_AGG(DISTINCT c.avatar_url), NULL) AS customer_avatars,
         ARRAY_REMOVE(ARRAY_AGG(DISTINCT c.identity_image_url), NULL) AS customer_identities,
         (SELECT ARRAY_REMOVE(ARRAY_AGG(DISTINCT receipt_image_url), NULL)
            FROM cash_transactions WHERE shop_id = $1) AS receipt_images,
         (SELECT ARRAY_REMOVE(ARRAY_AGG(DISTINCT image_url), NULL)
            FROM invoices WHERE shop_id = $1) AS invoice_images
       FROM customers c
       WHERE c.shop_id = $1`,
      [shopId],
    );
    const customerAvatarUrls = (existingMedia[0]?.customer_avatars ?? []) as string[];
    const customerIdentityUrls = (existingMedia[0]?.customer_identities ?? []) as string[];
    const receiptImageUrls = (existingMedia[0]?.receipt_images ?? []) as string[];
    const invoiceImageUrls = (existingMedia[0]?.invoice_images ?? []) as string[];

    const existingMarker = await runner.query(
      "SELECT id FROM activity_logs WHERE shop_id = $1 AND entity_type = 'DATASET' AND entity_name = $2 LIMIT 1",
      [shopId, profile.datasetVersion],
    );
    if (existingMarker.length && !replaceExisting) {
      throw new Error(`Bộ dữ liệu ${profile.datasetVersion} đã tồn tại tại cửa hàng này`);
    }

    const owners = await runner.query(
      "SELECT user_id FROM shop_members WHERE shop_id = $1 AND member_type = 'OWNER' AND status = 'ACTIVE' AND is_active = true ORDER BY id",
      [shopId],
    );
    if (owners.length !== 1) {
      throw new Error(`Cửa hàng phải có đúng 1 owner đang hoạt động, hiện có ${owners.length}`);
    }
    const ownerId = Number(owners[0].user_id);
    if (replaceExisting) {
      await clearExistingShopData(runner, shopId);
    }
    const key = shopId.toString(36).toUpperCase();
    const random = createRandom(shopId * 1009 + 20260728);
    let sequence = 1;

    const categoryNames = [...new Set(profile.products.map((product) => product.category))];
    const categoryRows = categoryNames
      .map((name) => ({
        name,
        shop_id: shopId,
        description: `Danh mục ${profile.description.toLocaleLowerCase('vi-VN')}`,
        is_active: true,
      }));
    const categories = await bulkInsert(
      runner,
      'categories',
      ['name', 'shop_id', 'description', 'is_active'],
      categoryRows,
      'id',
    );
    const operationalTagNames = [
      ...categoryNames,
      'Bán chạy',
      'Hàng cần theo dõi',
      profile.key === 'agriculture' ? 'Theo mùa vụ' : 'Hàng công trình',
    ];
    await bulkInsert(
      runner,
      'tags',
      ['shop_id', 'name', 'color', 'type'],
      operationalTagNames.map((name, index) => ({
        shop_id: shopId,
        name,
        color: [
          '#2563EB',
          '#0F766E',
          '#7C3AED',
          '#C2410C',
          '#0369A1',
          '#4D7C0F',
          '#DC2626',
          '#D97706',
          '#0891B2',
        ][index % 9],
        type: 'product',
      })),
    );

    const categoryIdByName = new Map(
      categoryNames.map((name, index) => [name, Number(categories[index].id)]),
    );
    const productRows = profile.products.map((definition, index) => ({
      sku: `${profile.skuPrefix}-${key}-${String(index + 1).padStart(3, '0')}`,
      shop_id: shopId,
      name: definition.name,
      image_url: imageUrlByFamily.get(definition.imageFamily ?? definition.name) ?? null,
      category_id: categoryIdByName.get(definition.category)!,
      unit: definition.unit,
      cost_price: roundMoney(definition.cost * 1.07),
      selling_price: roundMoney(definition.sell * 1.10),
      wholesale_price: roundMoney(definition.sell * 1.10 * 0.94),
      wholesale_min_qty: 10,
      tax_rate: 0,
      min_stock: definition.minStock,
      description: `Sản phẩm thuộc nhóm ${definition.category.toLocaleLowerCase('vi-VN')}`,
      tags: [
        definition.category,
        index < Math.ceil(profile.products.length * 0.25)
          ? 'Bán chạy'
          : index >= Math.floor(profile.products.length * 0.75)
            ? 'Hàng cần theo dõi'
            : null,
        profile.key === 'agriculture' ? 'Theo mùa vụ' : 'Hàng công trình',
      ].filter(Boolean).join(','),
      is_active: true,
      created_at: START_DATE,
      updated_at: END_DATE,
    }));
    const products = await bulkInsert(
      runner,
      'products',
      ['sku', 'shop_id', 'name', 'image_url', 'category_id', 'unit', 'cost_price', 'selling_price',
        'wholesale_price', 'wholesale_min_qty', 'tax_rate', 'min_stock', 'description',
        'tags', 'is_active', 'created_at', 'updated_at'],
      productRows,
      'id, sku',
    );
    const costTypes = await bulkInsert(
      runner,
      'cost_types',
      ['name', 'shop_id', 'description', 'is_active', 'sort_order', 'created_at'],
      (profile.key === 'construction'
        ? [
          ['Vận chuyển vật liệu', 'Chi phí đưa vật liệu và thiết bị về kho'],
          ['Bốc xếp công trình', 'Chi phí bốc xếp vật liệu nặng và hàng công trình'],
          ['Bảo quản kho VLXD', 'Chi phí che chắn và bảo quản vật liệu, nội thất'],
          ['Hao hụt vật liệu', 'Hao hụt hợp lý theo đặc tính vật liệu xây dựng'],
        ]
        : [
          ['Vận chuyển vật tư nông nghiệp', 'Chi phí đưa phân bón và vật tư về kho'],
          ['Bốc xếp phân bón', 'Chi phí bốc xếp phân bón và hàng bao'],
          ['Bảo quản vật tư nông nghiệp', 'Chi phí bảo quản hạt giống và thuốc đúng điều kiện'],
          ['Hao hụt vật tư nông nghiệp', 'Hao hụt hợp lý theo nhóm vật tư nông nghiệp'],
        ]).map(([name, description], index) => ({
        name,
        shop_id: shopId,
        description,
        is_active: true,
        sort_order: index + 1,
        created_at: START_DATE,
      })),
      'id',
    );
    const productCostRows: Row[] = [];
    const priceHistoryRows: Row[] = [];
    const conversionRows: Row[] = [];
    for (let index = 0; index < products.length; index += 1) {
      const definition = profile.products[index];
      const productId = Number(products[index].id);
      if (index % 4 === 0) {
        productCostRows.push({
          product_id: productId,
          shop_id: shopId,
          cost_type_id: Number(costTypes[index % costTypes.length].id),
          amount: roundMoney(Math.max(definition.cost * 0.015, 1000)),
          calculation_type: 'FIXED',
          notes: 'Phân bổ theo lần nhập gần nhất',
        });
      }
      const currentSellingPrice = roundMoney(definition.sell * 1.10);
      priceHistoryRows.push(
        {
          product_id: productId,
          shop_id: shopId,
          price_type: 'SELLING',
          old_price: roundMoney(currentSellingPrice / 1.10),
          new_price: roundMoney(currentSellingPrice / 1.05),
          change_reason: 'Điều chỉnh theo chi phí đầu vào năm 2025',
          changed_by: ownerId,
          changed_at: new Date('2025-01-03T08:00:00+07:00'),
        },
        {
          product_id: productId,
          shop_id: shopId,
          price_type: 'SELLING',
          old_price: roundMoney(currentSellingPrice / 1.05),
          new_price: currentSellingPrice,
          change_reason: 'Cập nhật bảng giá bán năm 2026',
          changed_by: ownerId,
          changed_at: new Date('2026-01-05T08:00:00+07:00'),
        },
      );
      const conversion = definition.unit === 'Bao'
        ? { toUnit: 'Kg', rate: definition.name.includes('25kg') ? 25 : definition.name.includes('10kg') ? 10 : 50 }
        : definition.unit === 'Thùng'
          ? { toUnit: 'Lít', rate: definition.name.includes('18L') ? 18 : 20 }
          : definition.unit === 'Cuộn'
            ? { toUnit: 'Mét', rate: 100 }
            : null;
      if (conversion) {
        conversionRows.push({
          product_id: productId,
          shop_id: shopId,
          from_unit: definition.unit,
          to_unit: conversion.toUnit,
          conversion_rate: conversion.rate,
          selling_price_per_unit: roundMoney(currentSellingPrice / conversion.rate),
        });
      }
    }
    await bulkInsert(
      runner,
      'product_cost_items',
      ['product_id', 'shop_id', 'cost_type_id', 'amount', 'calculation_type', 'notes'],
      productCostRows,
    );
    await bulkInsert(
      runner,
      'product_price_history',
      ['product_id', 'shop_id', 'price_type', 'old_price', 'new_price', 'change_reason',
        'changed_by', 'changed_at'],
      priceHistoryRows,
      '',
      500,
    );
    await bulkInsert(
      runner,
      'unit_conversions',
      ['product_id', 'shop_id', 'from_unit', 'to_unit', 'conversion_rate', 'selling_price_per_unit'],
      conversionRows,
    );

    const customerRows = profile.customers.map((name, index) => ({
      code: `KH${key}${String(index + 1).padStart(4, '0')}`,
      shop_id: shopId,
      name,
      phone: `090${String(shopId % 100).padStart(2, '0')}${String(index + 1).padStart(5, '0')}`,
      address: `${12 + index} Đường số ${1 + (index % 12)}, TP. Hồ Chí Minh`,
      avatar_url: customerAvatarUrls.length
        ? customerAvatarUrls[index % customerAvatarUrls.length]
        : null,
      identity_image_url: customerIdentityUrls.length && index % 4 === 0
        ? customerIdentityUrls[index % customerIdentityUrls.length]
        : null,
      customer_type: customerType(profile, index),
      credit_limit: customerType(profile, index) === 'WHOLESALE' ? 120000000 : 25000000,
      balance: 0,
      notes: customerType(profile, index) === 'WHOLESALE'
        ? `Khách mua sỉ ngành ${profile.description.toLocaleLowerCase('vi-VN')}`
        : 'Khách hàng thường xuyên',
      is_active: true,
      created_at: START_DATE,
      updated_at: END_DATE,
    }));
    const customers = await bulkInsert(
      runner,
      'customers',
      ['code', 'shop_id', 'name', 'phone', 'address', 'avatar_url', 'identity_image_url',
        'customer_type', 'credit_limit',
        'balance', 'notes', 'is_active', 'created_at', 'updated_at'],
      customerRows,
      'id, code',
    );

    const supplierRows = profile.suppliers.map((name, index) => ({
      code: `NCC${key}${String(index + 1).padStart(3, '0')}`,
      shop_id: shopId,
      name,
      phone: `028730${String(shopId % 100).padStart(2, '0')}${String(index + 1).padStart(2, '0')}`,
      address: `${80 + index} Đường Kho Vận, TP. Hồ Chí Minh`,
      balance: 0,
      contact_person: `Phụ trách ${index + 1}`,
      payment_term_days: 30,
      notes: 'Nhà cung cấp định kỳ của cửa hàng',
      is_active: true,
      created_at: START_DATE,
      updated_at: END_DATE,
    }));
    const suppliers = await bulkInsert(
      runner,
      'suppliers',
      ['code', 'shop_id', 'name', 'phone', 'address', 'balance', 'contact_person',
        'payment_term_days', 'notes', 'is_active', 'created_at', 'updated_at'],
      supplierRows,
      'id, code',
    );
    const supplierNameById = new Map(
      suppliers.map((supplier, index) => [Number(supplier.id), profile.suppliers[index]]),
    );

    const warehouseResult = await bulkInsert(
      runner,
      'warehouses',
      ['name', 'shop_id', 'address', 'is_active'],
      [{
        name: `Kho trung tâm · ${key} · ${profile.datasetVersion}`,
        shop_id: shopId,
        address: 'Khu kho vận cửa hàng',
        is_active: true,
      }],
      'id',
    );
    const warehouseId = Number(warehouseResult[0].id);

    const accountRows = [
      { name: `Tiền mặt · ${profile.datasetVersion}`, shop_id: shopId, account_type: 'CASH', balance: 0, is_active: true },
      { name: `Tài khoản ngân hàng · ${profile.datasetVersion}`, shop_id: shopId, account_type: 'BANK', balance: 0, is_active: true },
    ];
    const accounts = await bulkInsert(
      runner,
      'cash_accounts',
      ['name', 'shop_id', 'account_type', 'balance', 'is_active'],
      accountRows,
      'id, account_type',
    );
    const cashAccountId = Number(accounts.find((account) => account.account_type === 'CASH')?.id);
    const bankAccountId = Number(accounts.find((account) => account.account_type === 'BANK')?.id);

    type GeneratedItem = { productIndex: number; quantity: number; unitPrice: number; costPrice: number; subtotal: number };
    type GeneratedOrder = {
      code: string; date: Date; customerIndex: number; status: string; method: string;
      subtotal: number; discount: number; total: number; initialPaid: number;
      debtPaid: number; items: GeneratedItem[]; cancelled: boolean;
    };

    const generatedOrders: GeneratedOrder[] = [];
    const monthlySold = new Map<string, number[]>();
    const customerWeights = buildCustomerWeights(profile);
    const productWeights = buildProductWeights(profile);
    const days = Math.floor((END_DATE.getTime() - START_DATE.getTime()) / DAY_MS) + 1;

    for (let dayIndex = 0; dayIndex < days; dayIndex += 1) {
      const day = addDays(START_DATE, dayIndex);
      const weekend = day.getDay() === 0 || day.getDay() === 6;
      const seasonal = profile.peakMonths.includes(day.getMonth()) ? 1 : 0;
      const operatingYear = Math.min(Math.floor(dayIndex / 365), 2);
      const orderCount =
        26 +
        operatingYear * 3 +
        (weekend ? 4 : 0) +
        seasonal * 3 +
        Math.floor(random() * 6);

      for (let orderIndex = 0; orderIndex < orderCount; orderIndex += 1) {
        const code = `SO${key}${String(dayIndex).padStart(4, '0')}${String(orderIndex).padStart(2, '0')}`;
        const itemCount = 1 + Math.floor(random() * 4);
        const used = new Set<number>();
        const items: GeneratedItem[] = [];
        let subtotal = 0;
        while (items.length < itemCount) {
          const productIndex = pickWeightedIndex(random, productWeights);
          if (used.has(productIndex)) continue;
          used.add(productIndex);
          const definition = profile.products[productIndex];
          const quantity = 1 + Math.floor(random() * definition.maxOrderQty);
          const unitPrice = roundMoney(
            definition.sell * (1 + operatingYear * 0.05),
          );
          const costPrice = roundMoney(
            definition.cost * (1 + operatingYear * 0.035),
          );
          const lineSubtotal = quantity * unitPrice;
          subtotal += lineSubtotal;
          items.push({
            productIndex,
            quantity,
            unitPrice,
            costPrice,
            subtotal: lineSubtotal,
          });
        }

        const discount = subtotal >= 2000000 && random() < 0.22
          ? roundMoney(subtotal * (0.02 + random() * 0.03))
          : 0;
        const total = subtotal - discount;
        const cancelled = random() < 0.018;
        const debtRatio = random();
        const initialPaid = cancelled
          ? 0
          : debtRatio < 0.07
            ? 0
            : debtRatio < 0.17
              ? roundMoney(total * 0.5)
              : total;
        const unpaid = total - initialPaid;
        const canCollect = addDays(day, 45) <= END_DATE;
        const debtPaid = unpaid > 0 && canCollect && random() < 0.68 ? unpaid : 0;
        const finalPaid = initialPaid + debtPaid;
        const methodRoll = random();
        const method =
          methodRoll < 0.28
            ? 'CASH'
            : methodRoll < 0.72
              ? 'TRANSFER'
              : 'QR';
        const orderDate = atLocalTime(day, 8 + Math.floor(random() * 10), Math.floor(random() * 60));
        generatedOrders.push({
          code,
          date: orderDate,
          customerIndex: pickWeightedIndex(random, customerWeights),
          status: cancelled ? 'CANCELLED' : finalPaid >= total ? 'DELIVERED' : 'PENDING',
          method,
          subtotal,
          discount,
          total,
          initialPaid,
          debtPaid,
          items,
          cancelled,
        });

        if (!cancelled) {
          const keyMonth = monthKey(day);
          const quantities = monthlySold.get(keyMonth) ?? Array(profile.products.length).fill(0);
          for (const item of items) quantities[item.productIndex] += item.quantity;
          monthlySold.set(keyMonth, quantities);
        }
      }
    }

    const orderRows = generatedOrders.map((order) => ({
      order_code: order.code,
      shop_id: shopId,
      customer_id: Number(customers[order.customerIndex].id),
      order_date: order.date,
      status: order.status,
      subtotal: order.subtotal,
      discount_amount: order.discount,
      tax_amount: 0,
      total_amount: order.total,
      total_cogs: order.cancelled ? 0 : order.items.reduce((sum, item) => sum + item.costPrice * item.quantity, 0),
      paid_amount: order.cancelled ? 0 : order.initialPaid + order.debtPaid,
      payment_method: order.method,
      notes: order.status === 'PENDING' ? 'Đơn bán có công nợ' : 'Đơn bán tại cửa hàng',
      return_status: 'NONE',
      created_by: ownerId,
      created_at: order.date,
      updated_at: order.date,
    }));
    const insertedOrders = await bulkInsert(
      runner,
      'sales_orders',
      ['order_code', 'shop_id', 'customer_id', 'order_date', 'status', 'subtotal',
        'discount_amount', 'tax_amount', 'total_amount', 'total_cogs', 'paid_amount',
        'payment_method', 'notes', 'return_status', 'created_by', 'created_at', 'updated_at'],
      orderRows,
      'id, order_code',
      300,
    );
    const orderIds = new Map(insertedOrders.map((order) => [String(order.order_code), Number(order.id)]));

    const itemRows: Row[] = [];
    const paymentRows: Row[] = [];
    const receivableRows: Row[] = [];
    const movementRows: Row[] = [];
    const cashRows: Row[] = [];
    const invoiceRows: Row[] = [];
    const journalRows: Row[] = [];
    const selectedReturns: {
      orderId: number;
      code: string;
      date: Date;
      refund: number;
      cogs: number;
      method: string;
      items: GeneratedItem[];
    }[] = [];

    cashRows.push({
      transaction_code: `T3${key}${String(sequence++).padStart(7, '0')}`,
      shop_id: shopId,
      type: 'INCOME',
      category: 'CAPITAL',
      amount: profile.openingCash,
      payment_method: 'CASH',
      account_id: cashAccountId,
      counterparty: 'Vốn đầu kỳ',
      reference_type: 'DATASET',
      reference_id: null,
      transaction_date: dateOnly(START_DATE),
      notes: 'Số dư tiền đầu kỳ',
      created_by: ownerId,
      created_at: START_DATE,
    });
    cashRows.push({
      transaction_code: `T3${key}${String(sequence++).padStart(7, '0')}`,
      shop_id: shopId,
      type: 'INCOME',
      category: 'CAPITAL',
      amount: profile.openingBank,
      payment_method: 'TRANSFER',
      account_id: bankAccountId,
      counterparty: 'Vốn đầu kỳ',
      reference_type: 'DATASET',
      reference_id: null,
      transaction_date: dateOnly(START_DATE),
      notes: 'Số dư tài khoản ngân hàng đầu kỳ',
      created_by: ownerId,
      created_at: START_DATE,
    });

    for (const order of generatedOrders) {
      const orderId = orderIds.get(order.code)!;
      for (const item of order.items) {
        itemRows.push({
          order_id: orderId,
          shop_id: shopId,
          product_id: Number(products[item.productIndex].id),
          quantity: item.quantity,
          unit_price: item.unitPrice,
          subtotal: item.subtotal,
          cost_price: item.costPrice,
          tax_rate: 0,
          tax_amount: 0,
        });
        if (!order.cancelled) {
          movementRows.push({
            product_id: Number(products[item.productIndex].id),
            shop_id: shopId,
            warehouse_id: warehouseId,
            movement_type: 'OUT',
            quantity: item.quantity,
            reference_type: 'SALES_ORDER',
            reference_id: orderId,
            notes: `Xuất bán ${order.code}`,
            created_by: ownerId,
            created_at: order.date,
          });
        }
      }

      if (order.initialPaid > 0) {
        paymentRows.push({
          order_id: orderId,
          shop_id: shopId,
          amount: order.initialPaid,
          method: order.method,
          reference_code: `${order.code}-P1`,
          notes: 'Thanh toán khi bán',
          paid_at: order.date,
        });
        cashRows.push({
          transaction_code: `T3${key}${String(sequence++).padStart(7, '0')}`,
          shop_id: shopId,
          type: 'INCOME',
          category: 'SALES',
          amount: order.initialPaid,
          payment_method: order.method,
          account_id: order.method === 'CASH' ? cashAccountId : bankAccountId,
          counterparty: profile.customers[order.customerIndex],
          reference_type: 'SALES_ORDER',
          reference_id: orderId,
          transaction_date: dateOnly(order.date),
          notes: `Thu tiền ${order.code}`,
          created_by: ownerId,
          created_at: order.date,
        });
      }

      const originalDebt = order.total - order.initialPaid;
      if (!order.cancelled && originalDebt > 0) {
        const dueDate = addDays(order.date, 30);
        receivableRows.push({
          customer_id: Number(customers[order.customerIndex].id),
          shop_id: shopId,
          order_id: orderId,
          amount: originalDebt,
          paid_amount: order.debtPaid,
          due_date: dateOnly(dueDate),
          status: order.debtPaid >= originalDebt
            ? 'PAID'
            : dueDate < END_DATE ? 'OVERDUE' : 'UNPAID',
          notes: `Công nợ từ ${order.code}`,
          debt_reason: 'Khách hàng mua vật tư theo tiến độ công trình',
          reminder_enabled: order.debtPaid < originalDebt,
          created_at: order.date,
          updated_at: order.debtPaid > 0 ? addDays(order.date, 15) : order.date,
        });
        if (order.debtPaid > 0) {
          const paidAt = addDays(order.date, 15);
          paymentRows.push({
            order_id: orderId,
            shop_id: shopId,
            amount: order.debtPaid,
            method: order.method === 'CASH' ? 'TRANSFER' : order.method,
            reference_code: `${order.code}-D1`,
            notes: 'Thu công nợ',
            paid_at: paidAt,
          });
          cashRows.push({
            transaction_code: `T3${key}${String(sequence++).padStart(7, '0')}`,
            shop_id: shopId,
            type: 'INCOME',
            category: 'DEBT_COLLECTION',
            amount: order.debtPaid,
            payment_method: 'TRANSFER',
            account_id: bankAccountId,
            counterparty: profile.customers[order.customerIndex],
            reference_type: 'SALES_ORDER',
            reference_id: orderId,
            transaction_date: dateOnly(paidAt),
            notes: `Thu nợ ${order.code}`,
            created_by: ownerId,
            created_at: paidAt,
          });
          journalRows.push({
            shop_id: shopId,
            entry_date: paidAt,
            reference_type: 'DEBT_COLLECTION',
            reference_id: orderId,
            description: `Thu công nợ ${order.code}`,
            is_voided: false,
            created_at: paidAt,
          });
        }
      }

      if (!order.cancelled && random() < 0.32) {
        invoiceRows.push({
          invoice_number: `HD${order.code}`,
          shop_id: shopId,
          invoice_symbol: 'C26TSS',
          invoice_type: 'OUT',
          invoice_date: dateOnly(order.date),
          partner_name: profile.customers[order.customerIndex],
          reference_type: 'SALES_ORDER',
          reference_id: orderId,
          subtotal: order.subtotal,
          discount_amount: order.discount,
          tax_amount: 0,
          total_amount: order.total,
          payment_method: order.method,
          payment_status: order.initialPaid + order.debtPaid >= order.total ? 'PAID' : 'PARTIAL',
          image_url: invoiceImageUrls.length
            ? invoiceImageUrls[orderId % invoiceImageUrls.length]
            : null,
          notes: 'Hóa đơn bán hàng',
          created_by: ownerId,
          created_at: order.date,
        });
      }

      if (!order.cancelled) {
        journalRows.push({
          shop_id: shopId,
          entry_date: order.date,
          reference_type: 'SALES_ORDER',
          reference_id: orderId,
          description: `Bán hàng ${order.code}`,
          is_voided: false,
          created_at: order.date,
        });
      }

      if (
        !order.cancelled &&
        order.initialPaid >= order.total &&
        addDays(order.date, 10) <= END_DATE &&
        random() < 0.014
      ) {
        selectedReturns.push({
          orderId,
          code: `RT${key}${String(selectedReturns.length + 1).padStart(5, '0')}`,
          date: addDays(order.date, 2 + Math.floor(random() * 8)),
          refund: order.total,
          cogs: order.items.reduce(
            (sum, item) => sum + item.costPrice * item.quantity,
            0,
          ),
          method: order.method,
          items: order.items,
        });
      }
    }

    const insertedReturns = await bulkInsert(
      runner,
      'sales_returns',
      ['return_code', 'shop_id', 'order_id', 'return_date', 'reason', 'refund_amount',
        'refund_method', 'status', 'processed_by', 'notes', 'created_at'],
      selectedReturns.map((salesReturn) => ({
        return_code: salesReturn.code,
        shop_id: shopId,
        order_id: salesReturn.orderId,
        return_date: salesReturn.date,
        reason: 'Khách đổi phương án thi công và hoàn lại toàn bộ hàng',
        refund_amount: salesReturn.refund,
        refund_method: salesReturn.method,
        status: 'COMPLETED',
        processed_by: ownerId,
        notes: 'Hàng nguyên vẹn được nhập lại kho',
        created_at: salesReturn.date,
      })),
      'id, return_code, order_id',
      300,
    );
    const returnByCode = new Map(
      selectedReturns.map((salesReturn) => [salesReturn.code, salesReturn]),
    );
    const returnItemRows: Row[] = [];
    for (const insertedReturn of insertedReturns) {
      const salesReturn = returnByCode.get(String(insertedReturn.return_code));
      if (!salesReturn) continue;
      for (const item of salesReturn.items) {
        returnItemRows.push({
          return_id: Number(insertedReturn.id),
          shop_id: shopId,
          product_id: Number(products[item.productIndex].id),
          quantity: item.quantity,
          unit_price: item.unitPrice,
          subtotal: item.subtotal,
          reason: 'Hoàn lại hàng nguyên vẹn',
        });
        movementRows.push({
          product_id: Number(products[item.productIndex].id),
          shop_id: shopId,
          warehouse_id: warehouseId,
          movement_type: 'RETURN',
          quantity: item.quantity,
          reference_type: 'SALES_RETURN',
          reference_id: Number(insertedReturn.id),
          notes: `Nhập hàng trả ${salesReturn.code}`,
          created_by: ownerId,
          created_at: salesReturn.date,
        });
      }
      cashRows.push({
        transaction_code: `T3${key}${String(sequence++).padStart(7, '0')}`,
        shop_id: shopId,
        type: 'EXPENSE',
        category: 'SALES_RETURN',
        amount: salesReturn.refund,
        payment_method: salesReturn.method,
        account_id: salesReturn.method === 'CASH' ? cashAccountId : bankAccountId,
        counterparty: 'Khách trả hàng',
        reference_type: 'SALES_RETURN',
        reference_id: Number(insertedReturn.id),
        transaction_date: dateOnly(salesReturn.date),
        notes: `Hoàn tiền ${salesReturn.code}`,
        created_by: ownerId,
        created_at: salesReturn.date,
      });
    }
    await bulkInsert(
      runner,
      'sales_return_items',
      ['return_id', 'shop_id', 'product_id', 'quantity', 'unit_price', 'subtotal', 'reason'],
      returnItemRows,
      '',
      500,
    );
    if (selectedReturns.length > 0) {
      await runner.query(
        "UPDATE sales_orders SET return_status = 'FULL_RETURN' WHERE shop_id = $1 AND id = ANY($2::int[])",
        [shopId, selectedReturns.map((salesReturn) => salesReturn.orderId)],
      );
    }

    await bulkInsert(
      runner, 'sales_order_items',
      ['order_id', 'shop_id', 'product_id', 'quantity', 'unit_price', 'subtotal', 'cost_price', 'tax_rate', 'tax_amount'],
      itemRows, '', 700,
    );
    await bulkInsert(
      runner, 'sales_order_payments',
      ['order_id', 'shop_id', 'amount', 'method', 'reference_code', 'notes', 'paid_at'],
      paymentRows, '', 700,
    );
    const insertedReceivables = await bulkInsert(
      runner, 'receivables',
      ['customer_id', 'shop_id', 'order_id', 'amount', 'paid_amount', 'due_date', 'status',
        'notes', 'debt_reason', 'reminder_enabled', 'created_at', 'updated_at'],
      receivableRows, 'id, order_id, paid_amount, updated_at', 500,
    );
    await bulkInsert(
      runner, 'inventory_movements',
      ['product_id', 'shop_id', 'warehouse_id', 'movement_type', 'quantity',
        'reference_type', 'reference_id', 'notes', 'created_by', 'created_at'],
      movementRows, '', 700,
    );
    const insertedInvoices = await bulkInsert(
      runner, 'invoices',
      ['invoice_number', 'shop_id', 'invoice_symbol', 'invoice_type', 'invoice_date',
        'partner_name', 'reference_type', 'reference_id', 'subtotal', 'discount_amount', 'tax_amount',
        'total_amount', 'payment_method', 'payment_status', 'image_url', 'notes', 'created_by',
        'created_at'],
      invoiceRows, 'id, reference_id', 400,
    );

    if (invoiceImageUrls.length) {
      await bulkInsert(
        runner,
        'invoice_scans',
        ['scan_code', 'shop_id', 'image_url', 'image_thumbnail_url', 'invoice_type', 'status',
          'ocr_raw_text', 'ocr_parsed_data', 'confirmed_data', 'confidence_score', 'total_amount',
          'reference_type', 'reference_id', 'ocr_engine', 'scanned_by', 'scanned_at',
          'confirmed_at', 'notes'],
        insertedInvoices
          .filter((_, index) => index % 30 === 0)
          .map((invoice, index) => ({
            scan_code: `SC${key}${String(index + 1).padStart(6, '0')}`,
            shop_id: shopId,
            image_url: invoiceImageUrls[index % invoiceImageUrls.length],
            image_thumbnail_url: invoiceImageUrls[index % invoiceImageUrls.length],
            invoice_type: 'SALE',
            status: 'CONFIRMED',
            ocr_raw_text: 'Hóa đơn bán hàng đã được đối soát',
            ocr_parsed_data: JSON.stringify({ source: 'test-dataset', verified: true }),
            confirmed_data: JSON.stringify({ invoiceId: Number(invoice.id) }),
            confidence_score: 96,
            total_amount: null,
            reference_type: 'INVOICE',
            reference_id: Number(invoice.id),
            ocr_engine: 'TEST_DATASET',
            scanned_by: ownerId,
            scanned_at: END_DATE,
            confirmed_at: END_DATE,
            notes: 'Ảnh hóa đơn tái sử dụng từ bộ dữ liệu kiểm thử trước',
          })),
        '',
        300,
      );
    }

    if (receiptImageUrls.length) {
      await bulkInsert(
        runner,
        'debt_evidences',
        ['receivable_id', 'shop_id', 'type', 'file_url', 'file_name', 'file_size',
          'description', 'uploaded_by', 'uploaded_at'],
        insertedReceivables
          .filter((_, index) => index % 25 === 0)
          .map((receivable, index) => ({
            receivable_id: Number(receivable.id),
            shop_id: shopId,
            type: 'PAYMENT_RECEIPT',
            file_url: receiptImageUrls[index % receiptImageUrls.length],
            file_name: `bien-nhan-cong-no-${index + 1}.webp`,
            file_size: null,
            description: 'Biên nhận thanh toán công nợ mẫu',
            uploaded_by: ownerId,
            uploaded_at: receivable.updated_at
              ? new Date(String(receivable.updated_at))
              : END_DATE,
          })),
        '',
        300,
      );
    }

    const invoiceIdByOrder = new Map(insertedInvoices.map((invoice) => [Number(invoice.reference_id), Number(invoice.id)]));
    const invoiceItemRows: Row[] = [];
    for (const order of generatedOrders) {
      const orderId = orderIds.get(order.code)!;
      const invoiceId = invoiceIdByOrder.get(orderId);
      if (!invoiceId) continue;
      for (const item of order.items) {
        invoiceItemRows.push({
          invoice_id: invoiceId,
          product_id: Number(products[item.productIndex].id),
          item_name: profile.products[item.productIndex].name,
          unit: profile.products[item.productIndex].unit,
          quantity: item.quantity,
          unit_price: item.unitPrice,
          subtotal: item.subtotal,
          tax_rate: 0,
          tax_amount: 0,
        });
      }
    }
    await bulkInsert(
      runner, 'invoice_items',
      ['invoice_id', 'product_id', 'item_name', 'unit', 'quantity', 'unit_price', 'subtotal', 'tax_rate', 'tax_amount'],
      invoiceItemRows, '', 700,
    );

    const debtHistoryRows = insertedReceivables
      .filter((receivable) => Number(receivable.paid_amount) > 0)
      .map((receivable) => ({
        receivable_id: Number(receivable.id),
        shop_id: shopId,
        amount: Number(receivable.paid_amount),
        payment_method: 'TRANSFER',
        payment_date: receivable.updated_at as Date,
        notes: 'Thu công nợ theo lịch',
        recorded_by: ownerId,
        created_at: receivable.updated_at as Date,
      }));
    await bulkInsert(
      runner, 'debt_payment_history',
      ['receivable_id', 'shop_id', 'amount', 'payment_method', 'payment_date', 'notes', 'recorded_by', 'created_at'],
      debtHistoryRows, '', 500,
    );

    const purchaseRows: Row[] = [];
    const purchaseItemsByCode = new Map<string, Row[]>();
    const payableByCode = new Map<string, Row>();
    const payablePaymentSchedules = new Map<
      string,
      ReturnType<typeof buildPurchasePaymentSchedule>
    >();
    const purchasePaymentMethods = new Map<string, string>();
    const purchaseWithoutInvoiceCodes = new Set<string>();
    let purchaseSequence = 1;
    for (const [keyMonth, soldQuantities] of [...monthlySold.entries()].sort()) {
      for (
        let cycleIndex = 0;
        cycleIndex < PURCHASE_CYCLES_PER_MONTH;
        cycleIndex += 1
      ) {
        const purchaseDate = keyMonth === monthKey(START_DATE)
          ? atLocalTime(addDays(START_DATE, cycleIndex), 7, 30)
          : new Date(
              `${keyMonth}-${String(2 + cycleIndex * 6).padStart(2, '0')}T07:30:00+07:00`,
            );
      const purchaseYear = Math.min(
        Math.max(
          Math.floor((purchaseDate.getTime() - START_DATE.getTime()) / (365 * DAY_MS)),
          0,
        ),
        2,
      );
      const purchaseNumber = purchaseSequence++;
      const code = `P3${key}${String(purchaseNumber).padStart(4, '0')}`;
      const isWithoutInvoice = purchaseNumber % 5 === 0;
      if (isWithoutInvoice) purchaseWithoutInvoiceCodes.add(code);
        const items = soldQuantities.flatMap((sold, index) => {
          if (sold <= 0) return [];
          return [{
            product_id: Number(products[index].id),
            quantity:
              Math.ceil(sold / PURCHASE_CYCLES_PER_MONTH) +
              (purchaseNumber === 1
                ? profile.products[index].minStock * 2
                : 0),
            unit_price: roundMoney(
              profile.products[index].cost * (1 + purchaseYear * 0.035),
            ),
          }];
        });
      const total = items.reduce((sum, item) => sum + item.quantity * item.unit_price, 0);
      const initialPaid = roundMoney(total * 0.82);
      const outstanding = total - initialPaid;
      const debtPaymentDate = addDays(purchaseDate, 25);
      const debtPaid =
        debtPaymentDate < END_DATE && random() < 0.92 ? outstanding : 0;
      const debtPaymentSchedule = buildPurchasePaymentSchedule(
        debtPaymentDate,
        debtPaid,
        END_DATE,
        roundMoney,
      );
      payablePaymentSchedules.set(code, debtPaymentSchedule);
      const finalPaid = initialPaid + debtPaid;
      const purchasePaymentMethod = random() < 0.32 ? 'CASH' : 'TRANSFER';
      purchasePaymentMethods.set(code, purchasePaymentMethod);
      purchaseRows.push({
        order_code: code,
        shop_id: shopId,
        supplier_id: Number(suppliers[(purchaseSequence - 2) % suppliers.length].id),
        warehouse_id: warehouseId,
        order_date: purchaseDate,
        payment_due_date: dateOnly(addDays(purchaseDate, 30)),
        invoice_number: isWithoutInvoice ? null : `MUA-${code}`,
        status: 'COMPLETED',
        subtotal: total,
        discount_amount: 0,
        tax_amount: 0,
        total_amount: total,
        paid_amount: finalPaid,
        notes: 'Nhập hàng định kỳ',
        created_by: ownerId,
        created_at: purchaseDate,
      });
      purchaseItemsByCode.set(code, items);
      payableByCode.set(code, {
        supplier_id: Number(suppliers[(purchaseSequence - 2) % suppliers.length].id),
        shop_id: shopId,
        amount: outstanding,
        paid_amount: debtPaid,
        due_date: dateOnly(addDays(purchaseDate, 30)),
        status: debtPaid >= outstanding
          ? 'PAID'
          : addDays(purchaseDate, 30) < END_DATE
            ? 'OVERDUE'
            : 'UNPAID',
        notes: `Phải trả từ ${code}`,
        created_at: purchaseDate,
        updated_at: debtPaymentSchedule.length > 0
          ? debtPaymentSchedule[debtPaymentSchedule.length - 1].date
          : purchaseDate,
      });
      const initialPaymentSchedule = buildPurchasePaymentSchedule(
        purchaseDate,
        initialPaid,
        END_DATE,
        roundMoney,
      );
      initialPaymentSchedule.forEach((payment, index) => {
        cashRows.push({
          transaction_code: `T3${key}${String(sequence++).padStart(7, '0')}`,
          shop_id: shopId,
          type: 'EXPENSE',
          category: 'PURCHASE',
          amount: payment.amount,
          payment_method: purchasePaymentMethod,
          account_id: purchasePaymentMethod === 'CASH'
            ? cashAccountId
            : bankAccountId,
          counterparty: profile.suppliers[(purchaseSequence - 2) % suppliers.length],
          reference_type: 'PURCHASE_ORDER',
          reference_id: null,
          transaction_date: dateOnly(payment.date),
          notes: initialPaymentSchedule.length === 1
            ? `Thanh toán nhập hàng ${code}`
            : `Thanh toán đợt ${index + 1}/${initialPaymentSchedule.length} nhập hàng ${code}`,
          created_by: ownerId,
          created_at: payment.date,
        });
      });
      debtPaymentSchedule.forEach((payment, index) => {
        cashRows.push({
          transaction_code: `T3${key}${String(sequence++).padStart(7, '0')}`,
          shop_id: shopId,
          type: 'EXPENSE',
          category: 'PURCHASE',
          amount: payment.amount,
          payment_method: purchasePaymentMethod,
          account_id: purchasePaymentMethod === 'CASH'
            ? cashAccountId
            : bankAccountId,
          counterparty: profile.suppliers[(purchaseSequence - 2) % suppliers.length],
          reference_type: 'PURCHASE_ORDER',
          reference_id: null,
          transaction_date: dateOnly(payment.date),
          notes: debtPaymentSchedule.length === 1
            ? `Thanh toán công nợ nhập hàng ${code}`
            : `Thanh toán công nợ đợt ${index + 1}/${debtPaymentSchedule.length} nhập hàng ${code}`,
          created_by: ownerId,
          created_at: payment.date,
        });
      });
      }
    }

    const insertedPurchases = await bulkInsert(
      runner, 'purchase_orders',
      ['order_code', 'shop_id', 'supplier_id', 'warehouse_id', 'order_date', 'payment_due_date',
        'invoice_number', 'status', 'subtotal', 'discount_amount', 'tax_amount', 'total_amount',
        'paid_amount', 'notes', 'created_by', 'created_at'],
      purchaseRows, 'id, order_code, order_date, supplier_id, total_amount, paid_amount', 200,
    );
    const purchaseItemRows: Row[] = [];
    const purchaseMovementRows: Row[] = [];
    const payableRows: Row[] = [];
    const purchaseInvoiceRows: Row[] = [];
    const purchaseWithoutInvoiceRows: Row[] = [];
    const purchaseWithoutInvoiceItemsByCode = new Map<string, Row[]>();
    const purchaseCodeById = new Map(
      insertedPurchases.map((purchase) => [
        Number(purchase.id),
        String(purchase.order_code),
      ]),
    );
    for (const purchase of insertedPurchases) {
      const code = String(purchase.order_code);
      const purchaseId = Number(purchase.id);
      const items = purchaseItemsByCode.get(code) ?? [];
      for (const item of items) {
        purchaseItemRows.push({
          order_id: purchaseId,
          product_id: item.product_id,
          quantity: item.quantity,
          unit_price: item.unit_price,
          subtotal: Number(item.quantity) * Number(item.unit_price),
        });
        purchaseMovementRows.push({
          product_id: item.product_id,
          shop_id: shopId,
          warehouse_id: warehouseId,
          movement_type: 'IN',
          quantity: item.quantity,
          reference_type: 'PURCHASE_ORDER',
          reference_id: purchaseId,
          notes: `Nhập kho ${code}`,
          created_by: ownerId,
          created_at: purchase.order_date as Date,
        });
      }
      payableRows.push({ ...payableByCode.get(code)!, purchase_order_id: purchaseId });
      if (purchaseWithoutInvoiceCodes.has(code)) {
        const documentItems = items
          .filter((_, index) => index % Math.max(Math.floor(items.length / 8), 1) === 0)
          .slice(0, 8);
        const documentTotal = documentItems.reduce(
          (sum, item) => sum + Number(item.quantity) * Number(item.unit_price),
          0,
        );
        const documentIndex = purchaseWithoutInvoiceRows.length;
        const approvalStatus = documentIndex % 4 === 1
          ? 'PENDING'
          : documentIndex % 4 === 3
            ? 'REJECTED'
            : 'APPROVED';
        purchaseWithoutInvoiceRows.push({
          record_code: `BK${key}${code.slice(-4)}`,
          shop_id: shopId,
          purchase_date: dateOnly(new Date(purchase.order_date as string)),
          seller_name: supplierNameById.get(Number(purchase.supplier_id)) ?? 'Nhà cung cấp',
          seller_identity_number: `07926${String(shopId).padStart(2, '0')}${String(documentIndex + 1).padStart(5, '0')}`,
          seller_address: 'Khu thương mại và kho vận địa phương',
          seller_phone: `0908${String(shopId).padStart(2, '0')}${String(documentIndex + 1).padStart(4, '0')}`,
          total_amount: documentTotal,
          payment_method: documentTotal >= 20000000
            ? 'TRANSFER'
            : purchasePaymentMethods.get(code) ?? 'TRANSFER',
          market_price_reference: roundMoney(documentTotal * 1.02),
          notes: `Bảng kê chứng từ bổ sung cho đơn nhập ${code}`,
          approval_status: approvalStatus,
          approval_notes: approvalStatus === 'REJECTED'
            ? 'Thiếu xác nhận người bán, cần bổ sung trước khi ghi nhận'
            : approvalStatus === 'APPROVED'
              ? 'Đã đối chiếu đơn nhập, thanh toán và hàng nhận kho'
              : 'Đang chờ chủ cửa hàng kiểm tra chứng từ',
          approved_at: approvalStatus === 'PENDING' ? null : purchase.order_date as Date,
          approved_by: approvalStatus === 'PENDING' ? null : ownerId,
          created_by: ownerId,
          created_at: purchase.order_date as Date,
        });
        purchaseWithoutInvoiceItemsByCode.set(
          `BK${key}${code.slice(-4)}`,
          documentItems,
        );
      } else {
        purchaseInvoiceRows.push({
          invoice_number: `MUA-${code}`,
          shop_id: shopId,
          invoice_symbol: 'M26TSS',
          invoice_type: 'IN',
          invoice_date: dateOnly(new Date(purchase.order_date as string)),
          partner_name: supplierNameById.get(Number(purchase.supplier_id)) ?? 'Nhà cung cấp',
          reference_type: 'PURCHASE_ORDER',
          reference_id: purchaseId,
          subtotal: Number(purchase.total_amount),
          tax_amount: 0,
          total_amount: Number(purchase.total_amount),
          payment_method: purchasePaymentMethods.get(code) ?? 'TRANSFER',
          payment_status: Number(purchase.paid_amount) >= Number(purchase.total_amount) ? 'PAID' : 'PARTIAL',
          notes: 'Hóa đơn mua hàng',
          created_by: ownerId,
          created_at: purchase.order_date as Date,
        });
      }
    }
    await bulkInsert(runner, 'purchase_order_items', ['order_id', 'product_id', 'quantity', 'unit_price', 'subtotal'], purchaseItemRows, '', 700);
    await bulkInsert(
      runner, 'inventory_movements',
      ['product_id', 'shop_id', 'warehouse_id', 'movement_type', 'quantity',
        'reference_type', 'reference_id', 'notes', 'created_by', 'created_at'],
      purchaseMovementRows, '', 700,
    );
    const insertedPurchaseDocuments = await bulkInsert(
      runner,
      'purchases_without_invoice',
      ['record_code', 'shop_id', 'purchase_date', 'seller_name', 'seller_identity_number',
        'seller_address', 'seller_phone', 'total_amount', 'payment_method',
        'market_price_reference', 'notes', 'approval_status', 'approval_notes',
        'approved_at', 'approved_by', 'created_by', 'created_at'],
      purchaseWithoutInvoiceRows,
      'id, record_code',
    );
    const purchaseDocumentItemRows: Row[] = [];
    for (const document of insertedPurchaseDocuments) {
      const documentItems = purchaseWithoutInvoiceItemsByCode.get(String(document.record_code)) ?? [];
      for (const item of documentItems) {
        const productIndex = products.findIndex(
          (product) => Number(product.id) === Number(item.product_id),
        );
        purchaseDocumentItemRows.push({
          purchase_id: Number(document.id),
          shop_id: shopId,
          product_name: productIndex >= 0
            ? profile.products[productIndex].name
            : 'Hàng hóa nhập kho',
          item_name: productIndex >= 0
            ? profile.products[productIndex].name
            : 'Hàng hóa nhập kho',
          unit: productIndex >= 0 ? profile.products[productIndex].unit : 'Cái',
          product_id: Number(item.product_id),
          warehouse_id: warehouseId,
          quantity: Number(item.quantity),
          unit_price: Number(item.unit_price),
          subtotal: Number(item.quantity) * Number(item.unit_price),
        });
      }
    }
    await bulkInsert(
      runner,
      'purchase_without_invoice_items',
      ['purchase_id', 'shop_id', 'product_name', 'item_name', 'unit',
        'product_id', 'warehouse_id',
        'quantity', 'unit_price', 'subtotal'],
      purchaseDocumentItemRows,
    );
    const insertedPayables = await bulkInsert(
      runner, 'payables',
      ['supplier_id', 'shop_id', 'purchase_order_id', 'amount', 'paid_amount', 'due_date',
        'status', 'notes', 'created_at', 'updated_at'],
      payableRows, 'id, purchase_order_id, paid_amount, updated_at', 300,
    );
    const payableHistoryRows = insertedPayables.flatMap((payable) => {
      const code = purchaseCodeById.get(Number(payable.purchase_order_id)) ?? '';
      const schedule = payablePaymentSchedules.get(code) ?? [];
      return schedule.map((payment, index) => ({
          payable_id: Number(payable.id),
          shop_id: shopId,
          amount: payment.amount,
          payment_method: purchasePaymentMethods.get(code) ?? 'TRANSFER',
          payment_date: payment.date,
          notes: schedule.length === 1
            ? 'Thanh toán công nợ nhà cung cấp'
            : `Thanh toán công nợ nhà cung cấp đợt ${index + 1}/${schedule.length}`,
          recorded_by: ownerId,
          created_at: payment.date,
        }));
    });
    await bulkInsert(
      runner,
      'debt_payment_history',
      ['payable_id', 'shop_id', 'amount', 'payment_method', 'payment_date', 'notes', 'recorded_by', 'created_at'],
      payableHistoryRows,
      '',
      300,
    );
    const insertedPurchaseInvoices = await bulkInsert(
      runner, 'invoices',
      ['invoice_number', 'shop_id', 'invoice_symbol', 'invoice_type', 'invoice_date',
        'partner_name', 'reference_type', 'reference_id', 'subtotal', 'discount_amount', 'tax_amount',
        'total_amount', 'payment_method', 'payment_status', 'notes', 'created_by', 'created_at'],
      purchaseInvoiceRows.map((invoice) => ({ ...invoice, discount_amount: 0 })),
      'id, reference_id', 300,
    );
    const purchaseInvoiceItemRows: Row[] = [];
    for (const invoice of insertedPurchaseInvoices) {
      const purchaseId = Number(invoice.reference_id);
      const code = purchaseCodeById.get(purchaseId);
      const items = code ? purchaseItemsByCode.get(code) ?? [] : [];
      for (const item of items) {
        const productIndex = products.findIndex(
          (product) => Number(product.id) === Number(item.product_id),
        );
        purchaseInvoiceItemRows.push({
          invoice_id: Number(invoice.id),
          product_id: Number(item.product_id),
          item_name: productIndex >= 0
            ? profile.products[productIndex].name
            : 'Hàng hóa nhập kho',
          unit: productIndex >= 0 ? profile.products[productIndex].unit : 'Cái',
          quantity: Number(item.quantity),
          unit_price: Number(item.unit_price),
          subtotal: Number(item.quantity) * Number(item.unit_price),
          tax_rate: 0,
          tax_amount: 0,
        });
      }
    }
    await bulkInsert(
      runner,
      'invoice_items',
      ['invoice_id', 'product_id', 'item_name', 'unit', 'quantity', 'unit_price',
        'subtotal', 'tax_rate', 'tax_amount'],
      purchaseInvoiceItemRows,
      '',
      700,
    );

    const expenseRows: Row[] = [];
    for (let cursor = new Date(START_DATE); cursor <= END_DATE; cursor = addDays(cursor, 1)) {
      const dayIndex = Math.floor((cursor.getTime() - START_DATE.getTime()) / DAY_MS);
      if (cursor.getDate() === 5) {
        expenseRows.push({ date: atLocalTime(cursor, 9, 0), category: 'RENT', amount: 18000000, note: 'Thuê mặt bằng' });
      }
      if (cursor.getDate() === 10) {
        expenseRows.push({ date: atLocalTime(cursor, 10, 0), category: 'SALARY', amount: 42000000, note: 'Lương nhân viên' });
      }
      if (cursor.getDate() === 18) {
        expenseRows.push({ date: atLocalTime(cursor, 15, 0), category: 'UTILITIES', amount: 4500000 + Math.floor(random() * 2000000), note: 'Điện, nước và Internet' });
      }
      if (dayIndex % 3 === 0) {
        expenseRows.push({ date: atLocalTime(cursor, 16, 30), category: 'DELIVERY', amount: 180000 + Math.floor(random() * 520000), note: 'Giao nhận và bốc xếp' });
      }
    }
    for (const expense of expenseRows) {
      cashRows.push({
        transaction_code: `T3${key}${String(sequence++).padStart(7, '0')}`,
        shop_id: shopId,
        type: 'EXPENSE',
        category: expense.category,
        amount: roundMoney(Number(expense.amount)),
        payment_method: expense.category === 'DELIVERY' ? 'CASH' : 'TRANSFER',
        account_id: expense.category === 'DELIVERY' ? cashAccountId : bankAccountId,
        counterparty: String(expense.note),
        reference_type: 'OPERATING_EXPENSE',
        reference_id: null,
        transaction_date: dateOnly(expense.date as Date),
        notes: String(expense.note),
        created_by: ownerId,
        created_at: expense.date,
      });
    }
    if (receiptImageUrls.length) {
      cashRows.forEach((transaction, index) => {
        if (index % 6 === 0) {
          transaction.receipt_image_url = receiptImageUrls[index % receiptImageUrls.length];
        }
      });
    }
    await bulkInsert(
      runner, 'cash_transactions',
      ['transaction_code', 'shop_id', 'type', 'category', 'amount', 'payment_method',
        'account_id', 'counterparty', 'reference_type', 'reference_id', 'transaction_date',
        'notes', 'receipt_image_url', 'created_by', 'created_at'],
      cashRows, '', 500,
    );
    await bulkInsert(
      runner, 'financial_ledger',
      ['shop_id', 'event_type', 'amount', 'payment_method', 'account_id',
        'reference_id', 'description', 'created_at', 'created_by'],
      cashRows.map((transaction) => ({
        shop_id: shopId,
        event_type: transaction.type === 'INCOME'
          ? (transaction.reference_type === 'SALES_ORDER' ? 'SALE' : 'DEBT_COLLECTION')
          : (transaction.category === 'SALARY' ? 'SALARY'
              : transaction.reference_type === 'PURCHASE_ORDER' ? 'PURCHASE' : 'EXPENSE'),
        amount: transaction.amount,
        payment_method: transaction.payment_method,
        account_id: transaction.account_id,
        reference_id: transaction.reference_id,
        description: transaction.notes,
        created_at: transaction.created_at,
        created_by: ownerId,
      })),
      '',
      500,
    );

    const insertedJournals = await bulkInsert(
      runner, 'journal_entries',
      ['shop_id', 'entry_date', 'reference_type', 'reference_id', 'description', 'is_voided', 'created_at'],
      journalRows, 'id, reference_type, reference_id', 500,
    );
    const orderById = new Map(generatedOrders.map((order) => [orderIds.get(order.code)!, order]));
    const journalLineRows: Row[] = [];
    for (const journal of insertedJournals) {
      const order = orderById.get(Number(journal.reference_id));
      if (!order) continue;
      if (String(journal.reference_type) === 'DEBT_COLLECTION') {
        if (order.debtPaid <= 0) continue;
        const paidAt = addDays(order.date, 15);
        const method = order.method === 'CASH' ? 'TRANSFER' : order.method;
        journalLineRows.push(
          {
            journal_entry_id: Number(journal.id),
            account_code: method === 'CASH' ? '111' : '112',
            amount: order.debtPaid,
            entry_type: 'DEBIT',
            created_at: paidAt,
          },
          {
            journal_entry_id: Number(journal.id),
            account_code: '131',
            amount: order.debtPaid,
            entry_type: 'CREDIT',
            created_at: paidAt,
          },
        );
        continue;
      }
      const cogs = order.items.reduce((sum, item) => sum + item.costPrice * item.quantity, 0);
      const originalDebt = order.total - order.initialPaid;
      if (order.initialPaid > 0) {
        journalLineRows.push({
          journal_entry_id: Number(journal.id),
          account_code: order.method === 'CASH' ? '111' : '112',
          amount: order.initialPaid,
          entry_type: 'DEBIT',
          created_at: order.date,
        });
      }
      if (originalDebt > 0) {
        journalLineRows.push({
          journal_entry_id: Number(journal.id),
          account_code: '131',
          amount: originalDebt,
          entry_type: 'DEBIT',
          created_at: order.date,
        });
      }
      journalLineRows.push(
        { journal_entry_id: Number(journal.id), account_code: '511', amount: order.total, entry_type: 'CREDIT', created_at: order.date },
        { journal_entry_id: Number(journal.id), account_code: '632', amount: cogs, entry_type: 'DEBIT', created_at: order.date },
        { journal_entry_id: Number(journal.id), account_code: '156', amount: cogs, entry_type: 'CREDIT', created_at: order.date },
      );
    }
    await bulkInsert(
      runner, 'journal_lines',
      ['journal_entry_id', 'account_code', 'amount', 'entry_type', 'created_at'],
      journalLineRows, '', 700,
    );

    const returnJournalRows = selectedReturns.map((salesReturn) => {
      const insertedReturn = insertedReturns.find(
        (row) => String(row.return_code) === salesReturn.code,
      );
      return {
        shop_id: shopId,
        entry_date: salesReturn.date,
        reference_type: 'SALES_RETURN',
        reference_id: Number(insertedReturn?.id),
        description: `Trả hàng ${salesReturn.code}`,
        is_voided: false,
        created_at: salesReturn.date,
      };
    });
    const insertedReturnJournals = await bulkInsert(
      runner,
      'journal_entries',
      ['shop_id', 'entry_date', 'reference_type', 'reference_id', 'description', 'is_voided', 'created_at'],
      returnJournalRows,
      'id, reference_id',
      300,
    );
    const returnById = new Map(
      insertedReturns.map((insertedReturn) => [
        Number(insertedReturn.id),
        returnByCode.get(String(insertedReturn.return_code))!,
      ]),
    );
    const returnJournalLineRows: Row[] = [];
    for (const journal of insertedReturnJournals) {
      const salesReturn = returnById.get(Number(journal.reference_id));
      if (!salesReturn) continue;
      returnJournalLineRows.push(
        { journal_entry_id: Number(journal.id), account_code: '511', amount: salesReturn.refund, entry_type: 'DEBIT', created_at: salesReturn.date },
        { journal_entry_id: Number(journal.id), account_code: salesReturn.method === 'CASH' ? '111' : '112', amount: salesReturn.refund, entry_type: 'CREDIT', created_at: salesReturn.date },
        { journal_entry_id: Number(journal.id), account_code: '156', amount: salesReturn.cogs, entry_type: 'DEBIT', created_at: salesReturn.date },
        { journal_entry_id: Number(journal.id), account_code: '632', amount: salesReturn.cogs, entry_type: 'CREDIT', created_at: salesReturn.date },
      );
    }
    await bulkInsert(
      runner,
      'journal_lines',
      ['journal_entry_id', 'account_code', 'amount', 'entry_type', 'created_at'],
      returnJournalLineRows,
      '',
      500,
    );

    const expenseJournalRows = expenseRows.map((expense, index) => ({
      shop_id: shopId,
      entry_date: expense.date,
      reference_type: 'OPERATING_EXPENSE',
      reference_id: index + 1,
      description: String(expense.note),
      is_voided: false,
      created_at: expense.date,
    }));
    const insertedExpenseJournals = await bulkInsert(
      runner,
      'journal_entries',
      ['shop_id', 'entry_date', 'reference_type', 'reference_id', 'description', 'is_voided', 'created_at'],
      expenseJournalRows,
      'id, reference_id',
      500,
    );
    const expenseJournalLineRows: Row[] = [];
    for (const journal of insertedExpenseJournals) {
      const expense = expenseRows[Number(journal.reference_id) - 1];
      if (!expense) continue;
      const amount = roundMoney(Number(expense.amount));
      expenseJournalLineRows.push(
        {
          journal_entry_id: Number(journal.id),
          account_code: '642',
          amount,
          entry_type: 'DEBIT',
          created_at: expense.date,
        },
        {
          journal_entry_id: Number(journal.id),
          account_code: expense.category === 'DELIVERY' ? '111' : '112',
          amount,
          entry_type: 'CREDIT',
          created_at: expense.date,
        },
      );
    }
    await bulkInsert(
      runner,
      'journal_lines',
      ['journal_entry_id', 'account_code', 'amount', 'entry_type', 'created_at'],
      expenseJournalLineRows,
      '',
      700,
    );

    await runner.query(`
      INSERT INTO inventory_stocks (product_id, shop_id, warehouse_id, quantity, updated_at)
      SELECT p.id, $1, $2,
        COALESCE(SUM(CASE WHEN m.movement_type IN ('IN', 'RETURN') THEN m.quantity ELSE -m.quantity END), 0),
        $3
      FROM products p
      LEFT JOIN inventory_movements m
        ON m.product_id = p.id AND m.shop_id = $1 AND m.warehouse_id = $2
      WHERE p.shop_id = $1 AND p.sku LIKE $4
      GROUP BY p.id
    `, [shopId, warehouseId, END_DATE, `${profile.skuPrefix}-${key}-%`]);

    const stockBeforeAdjustments = await runner.query(`
      SELECT p.id AS product_id, p.min_stock, s.quantity
      FROM products p
      JOIN inventory_stocks s
        ON s.product_id = p.id
        AND s.shop_id = p.shop_id
      WHERE p.shop_id = $1
      ORDER BY p.id
    `, [shopId]);
    const stockAdjustmentRows: Row[] = [];
    for (let index = 0; index < stockBeforeAdjustments.length; index += 1) {
      const stock = stockBeforeAdjustments[index];
      const currentQuantity = Number(stock.quantity);
      const minStock = Number(stock.min_stock);
      const targetQuantity = index % 31 === 0
        ? 0
        : index % 9 === 0
          ? Math.max(Math.floor(minStock * 0.55), 1)
          : currentQuantity;
      const adjustment = Math.max(currentQuantity - targetQuantity, 0);
      if (adjustment <= 0) continue;
      stockAdjustmentRows.push({
        product_id: Number(stock.product_id),
        shop_id: shopId,
        warehouse_id: warehouseId,
        movement_type: 'OUT',
        quantity: adjustment,
        reference_type: 'STOCK_ADJUSTMENT',
        reference_id: null,
        notes: index % 31 === 0
          ? 'Điều chỉnh hết tồn do hư hỏng hoặc thanh lý cuối kỳ'
          : 'Điều chỉnh tồn thấp để lập kế hoạch nhập hàng',
        created_by: ownerId,
        created_at: END_DATE,
      });
    }
    await bulkInsert(
      runner,
      'inventory_movements',
      ['product_id', 'shop_id', 'warehouse_id', 'movement_type', 'quantity',
        'reference_type', 'reference_id', 'notes', 'created_by', 'created_at'],
      stockAdjustmentRows,
      '',
      300,
    );
    await runner.query(`
      UPDATE inventory_stocks stock
      SET quantity = movement.quantity, updated_at = $3
      FROM (
        SELECT product_id,
          COALESCE(SUM(
            CASE WHEN movement_type IN ('IN', 'RETURN') THEN quantity ELSE -quantity END
          ), 0) AS quantity
        FROM inventory_movements
        WHERE shop_id = $1 AND warehouse_id = $2
        GROUP BY product_id
      ) movement
      WHERE stock.product_id = movement.product_id
        AND stock.shop_id = $1
        AND stock.warehouse_id = $2
    `, [shopId, warehouseId, END_DATE]);

    const stockSnapshot = await runner.query(`
      SELECT
        p.id AS product_id,
        p.cost_price,
        s.quantity
      FROM products p
      JOIN inventory_stocks s
        ON s.product_id = p.id
        AND s.shop_id = p.shop_id
      WHERE p.shop_id = $1
      ORDER BY p.id
    `, [shopId]);
    const batchRows: Row[] = [];
    for (let index = 0; index < stockSnapshot.length; index += 1) {
      const definition = profile.products[index];
      const tracksExpiry = profile.key === 'agriculture' ||
        /Xi măng|Sơn|Bột trét|Keo dán|Chống thấm/i.test(definition.name);
      const nearExpiry = tracksExpiry &&
        (profile.key === 'agriculture' ? index < 18 : index < 8);
      const expired = tracksExpiry && index % 23 === 0;
      const expiryDate = tracksExpiry
        ? addDays(
            END_DATE,
            expired
              ? -(3 + (index % 17))
              : nearExpiry
                ? 10 + index
                : 180 + (index % 240),
          )
        : null;
      batchRows.push({
        product_id: Number(stockSnapshot[index].product_id),
        shop_id: shopId,
        batch_number: `LOT${key}${String(index + 1).padStart(5, '0')}`,
        manufacturing_date: expiryDate ? dateOnly(addDays(expiryDate, -365)) : null,
        expiry_date: expiryDate ? dateOnly(expiryDate) : null,
        quantity: Number(stockSnapshot[index].quantity),
        cost_price: Number(stockSnapshot[index].cost_price),
        supplier_name: profile.suppliers[index % profile.suppliers.length],
        notes: tracksExpiry
          ? 'Lô đang theo dõi hạn sử dụng và điều kiện bảo quản'
          : 'Lô hàng đang lưu kho',
        is_active: true,
        created_at: new Date('2026-06-02T08:00:00+07:00'),
      });
    }
    const insertedBatches = await bulkInsert(
      runner,
      'product_batches',
      ['product_id', 'shop_id', 'batch_number', 'manufacturing_date', 'expiry_date',
        'quantity', 'cost_price', 'supplier_name', 'notes', 'is_active', 'created_at'],
      batchRows,
      'id, product_id',
      500,
    );
    const batchIdByProduct = new Map(
      insertedBatches.map((batch) => [Number(batch.product_id), Number(batch.id)]),
    );
    await bulkInsert(
      runner,
      'inventory_lots',
      ['product_id', 'shop_id', 'purchase_id', 'batch_id', 'lot_date', 'initial_qty',
        'remaining_qty', 'cost_price', 'notes', 'created_at'],
      stockSnapshot.map((stock: Record<string, unknown>) => ({
        product_id: Number(stock.product_id),
        shop_id: shopId,
        purchase_id: null,
        batch_id: batchIdByProduct.get(Number(stock.product_id)) ?? null,
        lot_date: new Date('2026-06-02T08:00:00+07:00'),
        initial_qty: Number(stock.quantity),
        remaining_qty: Number(stock.quantity),
        cost_price: Number(stock.cost_price),
        notes: 'Số dư lô được đối chiếu với tồn kho cuối kỳ',
        created_at: new Date('2026-06-02T08:00:00+07:00'),
      })),
      '',
      500,
    );

    const stockTakeRows: Row[] = [];
    const stockTakeDates: Date[] = [];
    for (let index = 0; index < STOCK_TAKE_COUNT; index += 1) {
      const stockTakeDate = addDays(
        START_DATE,
        Math.min(17 + index * 18, Math.floor((END_DATE.getTime() - START_DATE.getTime()) / DAY_MS)),
      );
      stockTakeDates.push(stockTakeDate);
      stockTakeRows.push({
        stock_take_code: `KK${key}${String(index + 1).padStart(3, '0')}`,
        shop_id: shopId,
        warehouse_id: warehouseId,
        stock_take_date: dateOnly(stockTakeDate),
        status: 'COMPLETED',
        notes: 'Kiểm kê định kỳ, số liệu đã được đối chiếu với sổ kho',
        created_by: ownerId,
        approved_by: ownerId,
        completed_at: atLocalTime(stockTakeDate, 18, 0),
        created_at: atLocalTime(stockTakeDate, 8, 0),
      });
    }
    const insertedStockTakes = await bulkInsert(
      runner,
      'stock_takes',
      ['stock_take_code', 'shop_id', 'warehouse_id', 'stock_take_date', 'status',
        'notes', 'created_by', 'approved_by', 'completed_at', 'created_at'],
      stockTakeRows,
      'id',
    );
    const stockTakeItemRows: Row[] = [];
    for (let index = 0; index < insertedStockTakes.length; index += 1) {
      const selectedProductIds = products
        .filter((_, productIndex) => productIndex % STOCK_TAKE_COUNT === index)
        .slice(0, 24)
        .map((product) => Number(product.id));
      const historicalStocks = await runner.query(`
        SELECT
          p.id AS product_id,
          COALESCE(SUM(
            CASE
              WHEN m.movement_type IN ('IN', 'RETURN') THEN m.quantity
              ELSE -m.quantity
            END
          ), 0)::numeric AS quantity
        FROM products p
        LEFT JOIN inventory_movements m
          ON m.product_id = p.id
          AND m.shop_id = $1
          AND m.created_at::date <= $2::date
        WHERE p.id = ANY($3::int[])
        GROUP BY p.id
        ORDER BY p.id
      `, [shopId, dateOnly(stockTakeDates[index]), selectedProductIds]);
      for (const stock of historicalStocks) {
        const quantity = Math.max(Number(stock.quantity), 0);
        stockTakeItemRows.push({
          stock_take_id: Number(insertedStockTakes[index].id),
          product_id: Number(stock.product_id),
          system_qty: quantity,
          actual_qty: quantity,
          difference: 0,
          notes: 'Khớp số lượng thực tế',
        });
      }
    }
    await bulkInsert(
      runner,
      'stock_take_items',
      ['stock_take_id', 'product_id', 'system_qty', 'actual_qty', 'difference', 'notes'],
      stockTakeItemRows,
      '',
      500,
    );

    await runner.query(`
      UPDATE customers c SET balance = debt.remaining
      FROM (
        SELECT customer_id, COALESCE(SUM(amount - paid_amount), 0) AS remaining
        FROM receivables WHERE shop_id = $1 GROUP BY customer_id
      ) debt
      WHERE c.id = debt.customer_id AND c.shop_id = $1
    `, [shopId]);
    await runner.query(`
      UPDATE suppliers s SET balance = debt.remaining
      FROM (
        SELECT supplier_id, COALESCE(SUM(amount - paid_amount), 0) AS remaining
        FROM payables WHERE shop_id = $1 GROUP BY supplier_id
      ) debt
      WHERE s.id = debt.supplier_id AND s.shop_id = $1
    `, [shopId]);
    await runner.query(`
      UPDATE cash_accounts a SET balance = totals.balance
      FROM (
        SELECT account_id,
          COALESCE(SUM(CASE WHEN type = 'INCOME' THEN amount ELSE -amount END), 0) AS balance
        FROM cash_transactions WHERE shop_id = $1 GROUP BY account_id
      ) totals
      WHERE a.id = totals.account_id AND a.shop_id = $1
    `, [shopId]);

    const dailyRows = await runner.query(`
      SELECT d::date AS day,
        COALESCE(SUM(CASE WHEN t.type = 'INCOME' THEN t.amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' THEN t.amount ELSE 0 END), 0) AS expense,
        COALESCE(SUM(CASE WHEN t.payment_method = 'CASH' AND t.type = 'INCOME' THEN t.amount
                          WHEN t.payment_method = 'CASH' AND t.type = 'EXPENSE' THEN -t.amount ELSE 0 END), 0) AS cash_delta,
        (
          SELECT COALESCE(SUM(so.total_amount), 0)
          FROM sales_orders so
          WHERE so.shop_id = $1 AND so.order_date::date = d::date AND so.status != 'CANCELLED'
        ) AS sales,
        (
          SELECT COUNT(*)
          FROM sales_orders so
          WHERE so.shop_id = $1 AND so.order_date::date = d::date AND so.status != 'CANCELLED'
        ) AS order_count,
        (
          SELECT COALESCE(SUM(sr.refund_amount), 0)
          FROM sales_returns sr
          WHERE sr.shop_id = $1
            AND sr.return_date::date = d::date
            AND sr.status != 'CANCELLED'
        ) AS returns
      FROM generate_series($2::date, $3::date, interval '1 day') d
      LEFT JOIN cash_transactions t ON t.shop_id = $1 AND t.transaction_date = d::date
      GROUP BY d ORDER BY d
    `, [shopId, dateOnly(START_DATE), dateOnly(END_DATE)]);
    const closingRows: Row[] = [];
    let runningCash = 0;
    for (const day of dailyRows) {
      const openingCash = runningCash;
      runningCash += Number(day.cash_delta);
      const dayText = dateOnly(new Date(day.day));
      closingRows.push({
        closing_date: dayText,
        shop_id: shopId,
        opening_cash: openingCash,
        closing_cash: runningCash,
        expected_cash: runningCash,
        cash_difference: 0,
        total_sales: Number(day.sales),
        total_returns: Number(day.returns),
        total_income: Number(day.income),
        total_expense: Number(day.expense),
        order_count: Number(day.order_count),
        notes: 'Đối chiếu và chốt quỹ cuối ngày',
        closed_by: ownerId,
        closed_at: atLocalTime(new Date(day.day), 21, 0),
      });
    }
    await bulkInsert(
      runner, 'daily_closings',
      ['closing_date', 'shop_id', 'opening_cash', 'closing_cash', 'expected_cash',
        'cash_difference', 'total_sales', 'total_returns', 'total_income', 'total_expense',
        'order_count', 'notes', 'closed_by', 'closed_at'],
      closingRows, '', 500,
    );

    const recentDays = dailyRows.slice(-60);
    const averageIncome = recentDays.reduce(
      (sum: number, day: Record<string, unknown>) => sum + Number(day.income),
      0,
    ) / recentDays.length;
    const averageExpense = recentDays.reduce(
      (sum: number, day: Record<string, unknown>) => sum + Number(day.expense),
      0,
    ) / recentDays.length;
    const forecastRows: Row[] = [];
    for (let index = 1; index <= 90; index += 1) {
      const forecastDate = addDays(END_DATE, index);
      const weekday = forecastDate.getDay();
      const salesFactor = weekday === 0 ? 0.72 : weekday === 6 ? 1.13 : 1;
      const seasonalFactor = 1 + Math.sin(index / 11) * 0.04;
      const expectedIncome = roundMoney(averageIncome * salesFactor * seasonalFactor);
      const expectedExpense = roundMoney(
        averageExpense * (weekday === 1 ? 1.08 : 0.99) * (1 + Math.cos(index / 9) * 0.03),
      );
      forecastRows.push({
        forecast_date: dateOnly(forecastDate),
        shop_id: shopId,
        expected_income: expectedIncome,
        expected_expense: expectedExpense,
        expected_balance: roundMoney(expectedIncome - expectedExpense),
        notes: 'Dự báo từ bình quân 60 ngày gần nhất, có điều chỉnh theo thứ trong tuần',
        created_at: END_DATE,
      });
    }
    await bulkInsert(
      runner,
      'cashflow_forecasts',
      ['forecast_date', 'shop_id', 'expected_income', 'expected_expense',
        'expected_balance', 'notes', 'created_at'],
      forecastRows,
      '',
      200,
    );

    const monthTotals = await runner.query(`
      SELECT TO_CHAR(transaction_date, 'YYYY-MM') AS month,
        SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) AS income,
        SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) AS expense
      FROM cash_transactions WHERE shop_id = $1
      GROUP BY TO_CHAR(transaction_date, 'YYYY-MM') ORDER BY month
    `, [shopId]);
    const budgetRows = monthTotals.map((month: Record<string, unknown>) => {
      const start = new Date(`${month.month}-01T00:00:00+07:00`);
      return {
        name: `Ngân sách ${month.month}`,
        shop_id: shopId,
        period: 'MONTHLY',
        start_date: dateOnly(start),
        end_date: dateOnly(new Date(start.getFullYear(), start.getMonth() + 1, 0)),
        planned_income: roundMoney(Number(month.income) * 0.96),
        planned_expense: roundMoney(Number(month.expense) * 1.03),
        actual_income: Number(month.income),
        actual_expense: Number(month.expense),
        notes: 'Kế hoạch và thực tế theo tháng',
        created_at: start,
      };
    });
    await bulkInsert(
      runner, 'budget_plans',
      ['name', 'shop_id', 'period', 'start_date', 'end_date', 'planned_income',
        'planned_expense', 'actual_income', 'actual_expense', 'notes', 'created_at'],
      budgetRows, '', 200,
    );

    const quarterRevenue = new Map<string, number>();
    for (const order of generatedOrders) {
      if (order.cancelled) continue;
      const period = quarterKey(order.date);
      quarterRevenue.set(period, (quarterRevenue.get(period) ?? 0) + order.total);
    }
    const taxRows = [...quarterRevenue.entries()].map(([period, revenue]) => {
      const [quarter, yearText] = period.split('/');
      const quarterNumber = Number(quarter.slice(1));
      const dueDate = new Date(Number(yearText), quarterNumber * 3, 30);
      const vat = roundMoney(revenue * 0.01);
      const pit = roundMoney(revenue * 0.005);
      const isPast = dueDate < END_DATE;
      return {
        period,
        shop_id: shopId,
        vat_declared: vat,
        pit_declared: pit,
        vat_paid: isPast ? vat : 0,
        pit_paid: isPast ? pit : 0,
        due_date: dateOnly(dueDate),
        status: isPast ? 'done' : 'pending',
        created_at: new Date(Number(yearText), (quarterNumber - 1) * 3, 1),
      };
    });
    await bulkInsert(
      runner, 'tax_obligations',
      ['period', 'shop_id', 'vat_declared', 'pit_declared', 'vat_paid', 'pit_paid',
        'due_date', 'status', 'created_at'],
      taxRows, '', 100,
    );

    await bulkInsert(
      runner, 'ai_knowledge_documents',
      ['shop_id', 'title', 'category', 'content', 'is_active', 'created_by', 'created_at', 'updated_at'],
      [
        {
          shop_id: shopId,
          title: 'Quy trình bán chịu và thu công nợ',
          category: 'Bán hàng & Sổ nợ',
          content: 'Chỉ bán chịu cho khách hàng đã có hồ sơ và hạn mức. Ghi nhận số tiền đã trả, ngày đến hạn và phương thức thu nợ. Đối chiếu công nợ vào cuối mỗi tuần.',
          is_active: true,
          created_by: ownerId,
          created_at: START_DATE,
          updated_at: END_DATE,
        },
        {
          shop_id: shopId,
          title: 'Quy trình nhập hàng và kiểm kê',
          category: 'Kho & Tài chính',
          content: 'Đơn nhập phải có nhà cung cấp, kho nhận và danh sách hàng. Kiểm đếm trước khi hoàn thành đơn nhập. Thực hiện kiểm kê định kỳ và ghi rõ nguyên nhân mọi chênh lệch.',
          is_active: true,
          created_by: ownerId,
          created_at: START_DATE,
          updated_at: END_DATE,
        },
        {
          shop_id: shopId,
          title: 'Quy trình chốt quỹ cuối ngày',
          category: 'Kho & Tài chính',
          content: 'Đối chiếu tiền mặt thực tế với số dư hệ thống, kiểm tra giao dịch chuyển khoản và ghi nhận chênh lệch trước khi bàn giao ca.',
          is_active: true,
          created_by: ownerId,
          created_at: START_DATE,
          updated_at: END_DATE,
        },
      ],
    );

    const activityLogRows: Row[] = monthTotals.map(
      (month: Record<string, unknown>, index: number) => ({
        user_id: ownerId,
        shop_id: shopId,
        action: 'EXPORT',
        entity_type: 'MONTHLY_REPORT',
        entity_id: null,
        entity_name: `Báo cáo ${month.month}`,
        old_value: null,
        new_value: JSON.stringify({
          income: roundMoney(Number(month.income)),
          expense: roundMoney(Number(month.expense)),
        }),
        description: 'Đã tổng hợp và đối chiếu báo cáo vận hành tháng',
        ip_address: null,
        created_at: addDays(START_DATE, Math.min(index * 30 + 27, 1095)),
      }),
    );
    activityLogRows.push(
      ...insertedStockTakes.map((stockTake, index) => ({
        user_id: ownerId,
        shop_id: shopId,
        action: 'UPDATE',
        entity_type: 'STOCK_TAKE',
        entity_id: Number(stockTake.id),
        entity_name: stockTakeRows[index].stock_take_code,
        old_value: JSON.stringify({ status: 'DRAFT' }),
        new_value: JSON.stringify({ status: 'COMPLETED' }),
        description: 'Hoàn thành và phê duyệt kiểm kê định kỳ',
        ip_address: null,
        created_at: stockTakeRows[index].completed_at,
      })),
      ...insertedPurchaseDocuments.map((document, index) => ({
        user_id: ownerId,
        shop_id: shopId,
        action: 'CREATE',
        entity_type: 'PURCHASE_WITHOUT_INVOICE',
        entity_id: Number(document.id),
        entity_name: String(document.record_code),
        old_value: null,
        new_value: JSON.stringify({
          status: purchaseWithoutInvoiceRows[index].approval_status,
          totalAmount: purchaseWithoutInvoiceRows[index].total_amount,
        }),
        description: 'Ghi nhận bảng kê mua hàng chưa có hóa đơn',
        ip_address: null,
        created_at: purchaseWithoutInvoiceRows[index].purchase_date,
      })),
      {
        user_id: ownerId,
        shop_id: shopId,
        action: 'IMPORT',
        entity_type: 'DATASET',
        entity_id: null,
        entity_name: profile.datasetVersion,
        old_value: null,
        new_value: JSON.stringify({
          from: dateOnly(START_DATE),
          to: dateOnly(END_DATE),
          orders: generatedOrders.length,
          products: products.length,
          customers: customers.length,
          profile: profile.key,
        }),
        description: 'Khởi tạo dữ liệu lịch sử vận hành 3 năm',
        ip_address: null,
        created_at: END_DATE,
      },
    );
    await bulkInsert(
      runner, 'activity_logs',
      ['user_id', 'shop_id', 'action', 'entity_type', 'entity_id', 'entity_name',
        'old_value', 'new_value', 'description', 'ip_address', 'created_at'],
      activityLogRows,
      '',
      200,
    );

    await validateGeneratedData(runner, shopId, profile.products.length);

    if (commitChanges) {
      await runner.commitTransaction();
    } else {
      await runner.rollbackTransaction();
    }
    console.log(
      commitChanges
        ? `Đã tạo ${profile.datasetVersion} cho cửa hàng "${shops[0].shop_name}".`
        : `Đã kiểm tra toàn bộ quá trình tạo ${profile.datasetVersion} và rollback an toàn.`,
    );
    console.log(`- ${generatedOrders.length} đơn bán; ${itemRows.length} dòng hàng`);
    console.log(`- ${purchaseRows.length} đơn nhập; ${cashRows.length} giao dịch tiền`);
    console.log(`- ${receivableRows.length} khoản phải thu; ${closingRows.length} lần chốt quỹ`);
  } catch (error) {
    await runner.rollbackTransaction();
    throw error;
  } finally {
    await runner.release();
    await AppDataSource.destroy();
  }
}

async function main(): Promise<void> {
  const shopId = parseNumberArg('shop-id');
  const profileKey = parseProfileArg();
  const profile = profileKey
    ? expandStoreProfile(STORE_PROFILES[profileKey])
    : undefined;
  printPlan(shopId, profile);
  const shouldApply = hasFlag('apply');
  const shouldValidate = hasFlag('validate-write');
  const replaceExisting = hasFlag('replace-existing');
  if (!shouldApply && !shouldValidate) return;
  if (shouldApply && shouldValidate) {
    throw new Error('Chỉ dùng một trong hai cờ --apply hoặc --validate-write');
  }
  if (!shopId) {
    throw new Error('Thiếu --shop-id=<id>. Script không tự chọn cửa hàng.');
  }
  if (!profile) {
    throw new Error('Thiếu hoặc sai --profile=construction|agriculture.');
  }
  if (replaceExisting) {
    const expectedConfirmation = `--confirm=REPLACE-${shopId}`;
    if (!process.argv.includes(expectedConfirmation)) {
      throw new Error(
        `Thay dữ liệu hiện có yêu cầu xác nhận chính xác ${expectedConfirmation}`,
      );
    }
  }
  await seed(shopId, profile, shouldApply, replaceExisting);
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
