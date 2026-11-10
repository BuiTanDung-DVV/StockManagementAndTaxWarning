import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { ShippingCarrier, ShopProfile } from '../system/entities';

const SAMPLE_CARRIERS = [
  {
    name: 'Đội xe giao hàng cửa hàng',
    code: 'STORE_TRUCK',
    phone: '0901234567',
    trackingUrlTemplate: null,
    defaultFee: 50000,
    isActive: true,
  },
  {
    name: 'Giao Hàng Nhanh (GHN)',
    code: 'GHN',
    phone: '1900636677',
    trackingUrlTemplate: 'https://donhang.ghn.vn/?order_code={trackingCode}',
    defaultFee: 35000,
    isActive: true,
  },
  {
    name: 'Giao Hàng Tiết Kiệm (GHTK)',
    code: 'GHTK',
    phone: '19006092',
    trackingUrlTemplate: 'https://i.ghtk.vn/{trackingCode}',
    defaultFee: 30000,
    isActive: true,
  },
  {
    name: 'Viettel Post',
    code: 'VIETTELPOST',
    phone: '19008095',
    trackingUrlTemplate: 'https://viettelpost.com.vn/tra-cuu-hanh-trinh-don/{trackingCode}',
    defaultFee: 32000,
    isActive: true,
  },
  {
    name: 'Ahamove Giao Siêu Tốc',
    code: 'AHAMOVE',
    phone: '1900545411',
    trackingUrlTemplate: 'https://app.ahamove.com/tracking/{trackingCode}',
    defaultFee: 40000,
    isActive: true,
  },
];

async function run() {
  await AppDataSource.initialize();
  console.log('Database connected.');

  const shopRepo = AppDataSource.getRepository(ShopProfile);
  const carrierRepo = AppDataSource.getRepository(ShippingCarrier);

  const shops = await shopRepo.find();
  console.log(`Found ${shops.length} shop(s).`);

  let totalInserted = 0;

  for (const shop of shops) {
    console.log(`Processing shop #${shop.id} (${shop.shopName})...`);
    for (const item of SAMPLE_CARRIERS) {
      const existing = await carrierRepo.findOne({
        where: { shopId: shop.id, code: item.code },
      });
      if (!existing) {
        const carrier = carrierRepo.create({
          ...item,
          shopId: shop.id,
        });
        await carrierRepo.save(carrier);
        console.log(`  + Created carrier "${item.name}" (${item.code}) for shop #${shop.id}`);
        totalInserted++;
      } else {
        console.log(`  = Carrier "${item.code}" already exists for shop #${shop.id}`);
      }
    }
  }

  console.log(`Successfully added ${totalInserted} shipping carrier(s) across all shops.`);
  await AppDataSource.destroy();
}

run().catch((err) => {
  console.error('Seed shipping carriers error:', err);
  process.exit(1);
});
