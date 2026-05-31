/**
 * Seed script — Generate mock data for Fertilizer & Building Materials Shop
 * Run: npx ts-node src/scripts/seed-fertilizer.ts
 */
import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { User } from '../auth/entities';
import { ShopProfile } from '../system/entities';
import { ShopRole, ShopMember } from '../shop/entities';
import { Category, Product } from '../product/entities';
import { Customer } from '../customer/entities';
import { Supplier } from '../supplier/entities';
import * as bcrypt from 'bcrypt';

async function seed() {
  // Object.assign(AppDataSource.options, { synchronize: true });
  await AppDataSource.initialize();
  console.log('✅ DB connected — generating fertilizer shop mock data...');

  const userRepo = AppDataSource.getRepository(User);
  const shopRepo = AppDataSource.getRepository(ShopProfile);
  const roleRepo = AppDataSource.getRepository(ShopRole);
  const memberRepo = AppDataSource.getRepository(ShopMember);
  const catRepo = AppDataSource.getRepository(Category);
  const prodRepo = AppDataSource.getRepository(Product);
  const custRepo = AppDataSource.getRepository(Customer);
  const suppRepo = AppDataSource.getRepository(Supplier);

  const defaultPassword = await bcrypt.hash('123456', 10);

  // 1. Create Owner User
  let owner = await userRepo.findOne({ where: { username: 'chushop_binhminh' } });
  if (!owner) {
    owner = userRepo.create({
      username: 'chushop_binhminh',
      passwordHash: defaultPassword,
      fullName: 'Ông Nguyễn Văn Bình Minh',
      email: 'owner@binhminh.local',
      phone: '0988000111',
      role: 'MANAGER',
      accountType: 'SHOP',
      isOnboarded: true,
      isActive: true,
    });
    owner = await userRepo.save(owner);
    console.log('  ➜ Owner created: chushop_binhminh');
  } else {
    console.log('  ➜ Owner chushop_binhminh already exists');
  }

  // 2. Create Shop
  let shop = await shopRepo.findOne({ where: { shopName: 'Đại lý VTNN & VLXD Bình Minh' } });
  if (!shop) {
    shop = shopRepo.create({
      shopName: 'Đại lý VTNN & VLXD Bình Minh',
      shopCode: `BM-${Date.now().toString().slice(-6)}`,
      phone: '0988000111',
      address: '123 Quốc Lộ 1A, Huyện Bình Chánh, TP.HCM',
      taxCode: '0311223344',
      accountHolder: 'NGUYEN VAN BINH MINH',
    });
    shop = await shopRepo.save(shop);
    console.log('  ➜ Shop created:', shop.shopName);
  } else {
    console.log('  ➜ Shop already exists');
  }

  // Link Owner
  let ownerMember = await memberRepo.findOne({ where: { userId: owner.id, shopId: shop.id } });
  if (!ownerMember) {
    await memberRepo.save(memberRepo.create({
      shopId: shop.id,
      userId: owner.id,
      memberType: 'OWNER',
      status: 'ACTIVE',
      isActive: true,
    }));
  }

  // 3. Create Roles
  const rolesData = [
    { name: 'Quản lý (Manager)', perms: '{"pos":"full","products":"full","finance":"full","inventory":"full"}' },
    { name: 'Kế toán (Accountant)', perms: '{"pos":"view","products":"view","finance":"full","inventory":"view"}' },
    { name: 'Thủ kho (Warehouse)', perms: '{"pos":"none","products":"full","finance":"none","inventory":"full"}' },
    { name: 'Bán hàng (Sales)', perms: '{"pos":"full","products":"view","finance":"none","inventory":"view"}' },
  ];
  
  const savedRoles = [];
  for (const r of rolesData) {
    let role = await roleRepo.findOne({ where: { shopId: shop.id, name: r.name } });
    if (!role) {
      role = await roleRepo.save(roleRepo.create({ shopId: shop.id, name: r.name, permissions: r.perms }));
    }
    savedRoles.push(role);
  }
  console.log('  ➜ 4 Roles created');

  // 4. Create 20 Staff
  const staffConfigs = [
    { prefix: 'quanly', count: 2, roleId: savedRoles[0].id, namePrefix: 'Quản lý' },
    { prefix: 'ketoan', count: 3, roleId: savedRoles[1].id, namePrefix: 'Kế toán' },
    { prefix: 'thukho', count: 5, roleId: savedRoles[2].id, namePrefix: 'Thủ kho' },
    { prefix: 'banhang', count: 10, roleId: savedRoles[3].id, namePrefix: 'NV Bán hàng' },
  ];

  let staffCount = 0;
  for (const cfg of staffConfigs) {
    for (let i = 1; i <= cfg.count; i++) {
      const username = `${cfg.prefix}_${i.toString().padStart(2, '0')}`;
      let staff = await userRepo.findOne({ where: { username } });
      if (!staff) {
        staff = await userRepo.save(userRepo.create({
          username,
          passwordHash: defaultPassword,
          fullName: `${cfg.namePrefix} ${i}`,
          phone: `0900111${i.toString().padStart(3, '0')}`,
          role: 'STAFF',
          accountType: 'PERSONAL',
          isOnboarded: true,
          isActive: true,
        }));
      }
      
      let member = await memberRepo.findOne({ where: { userId: staff.id, shopId: shop.id } });
      if (!member) {
        await memberRepo.save(memberRepo.create({
          shopId: shop.id,
          userId: staff.id,
          roleId: cfg.roleId,
          memberType: 'EMPLOYEE',
          status: 'ACTIVE',
          isActive: true,
        }));
        staffCount++;
      }
    }
  }
  console.log(`  ➜ ${staffCount} Staff members created & linked`);

  // 5. Create Categories
  const categoryNames = [
    'Phân bón NPK', 'Phân hữu cơ', 'Thuốc trừ sâu', 'Thuốc diệt cỏ', 
    'Xi măng', 'Sắt thép xây dựng', 'Cát đá', 'Gạch ốp lát', 
    'Sơn nước', 'Dụng cụ nông nghiệp', 'Hạt giống', 'Vật tư phụ'
  ];
  const savedCategories = [];
  for (const cName of categoryNames) {
    let cat = await catRepo.findOne({ where: { name: cName, shopId: shop.id } });
    if (!cat) {
      cat = await catRepo.save(catRepo.create({ name: cName, shopId: shop.id }));
    }
    savedCategories.push(cat);
  }
  console.log(`  ➜ ${savedCategories.length} Categories created`);

  // 6. Create 100+ Products
  const prodCount = await prodRepo.count({ where: { shopId: shop.id } });
  if (prodCount < 100) {
    const products = [];
    let pIdx = 1;
    for (let cat of savedCategories) {
      // Create 10 products per category
      for (let i = 1; i <= 10; i++) {
        const isBuilding = ['Xi măng', 'Sắt thép xây dựng', 'Cát đá', 'Gạch ốp lát', 'Sơn nước'].includes(cat.name);
        const costPrice = Math.floor(Math.random() * 500) * 1000 + 50000;
        products.push({
          shopId: shop.id,
          categoryId: cat.id,
          name: `${cat.name} loại ${isBuilding ? 'cao cấp' : 'chuyên dụng'} số ${i}`,
          sku: `SP${pIdx.toString().padStart(4, '0')}`,
          barcode: `893${pIdx.toString().padStart(10, '0')}`,
          unit: isBuilding ? (cat.name === 'Xi măng' ? 'Bao' : 'Kg') : 'Gói',
          costPrice: costPrice,
          sellingPrice: costPrice * 1.3,
          wholesalePrice: costPrice * 1.15,
          currentStock: Math.floor(Math.random() * 500) + 50,
          minStock: 20,
          description: `Sản phẩm ${cat.name} nhập khẩu/sản xuất trong nước đạt chuẩn.`,
          isActive: true
        });
        pIdx++;
      }
    }
    // Batch save
    for (let i = 0; i < products.length; i += 20) {
      const chunk = products.slice(i, i + 20);
      await prodRepo.save(chunk.map(p => prodRepo.create(p)));
    }
    console.log(`  ➜ ${products.length} Products created`);
  } else {
    console.log(`  ➜ Products already populated (${prodCount})`);
  }

  // 7. Create 100+ Customers
  const custCount = await custRepo.count({ where: { shopId: shop.id } });
  if (custCount < 100) {
    const customers = [];
    for (let i = 1; i <= 100; i++) {
      const isContractor = i % 3 === 0;
      customers.push({
        shopId: shop.id,
        code: `CUST-${i.toString().padStart(4, '0')}`,
        name: isContractor ? `Nhà thầu xây dựng ${i}` : `Chủ vườn/Nông dân ${i}`,
        phone: `090${Math.floor(Math.random() * 10000000).toString().padStart(7, '0')}`,
        address: `Xã/Phường ${Math.floor(Math.random() * 20) + 1}, Tỉnh miền Tây/Đông Nam Bộ`,
        taxCode: isContractor ? `031${Math.floor(Math.random() * 10000000)}` : undefined,
        debtAmount: isContractor ? Math.floor(Math.random() * 50000000) : 0,
        type: isContractor ? 'B2B' : 'RETAIL'
      });
    }
    for (let i = 0; i < customers.length; i += 20) {
      await custRepo.save(customers.slice(i, i + 20).map(c => custRepo.create(c)));
    }
    console.log(`  ➜ ${customers.length} Customers created`);
  } else {
    console.log(`  ➜ Customers already populated (${custCount})`);
  }

  // 8. Create 100+ Suppliers
  const suppCount = await suppRepo.count({ where: { shopId: shop.id } });
  if (suppCount < 100) {
    const suppliers = [];
    for (let i = 1; i <= 100; i++) {
      suppliers.push({
        shopId: shop.id,
        code: `SUPP-${i.toString().padStart(4, '0')}`,
        name: `Công ty ${i % 2 === 0 ? 'Phân bón' : 'Vật liệu'} cấp 1 - CN ${i}`,
        phone: `028${Math.floor(Math.random() * 10000000).toString().padStart(7, '0')}`,
        address: `KCN số ${Math.floor(Math.random() * 10) + 1}, Tỉnh/Thành phố lớn`,
        taxCode: `010${Math.floor(Math.random() * 10000000)}`,
        contactPerson: `Đại diện kinh doanh ${i}`
      });
    }
    for (let i = 0; i < suppliers.length; i += 20) {
      await suppRepo.save(suppliers.slice(i, i + 20).map(s => suppRepo.create(s)));
    }
    console.log(`  ➜ ${suppliers.length} Suppliers created`);
  } else {
    console.log(`  ➜ Suppliers already populated (${suppCount})`);
  }

  console.log('\n🎉 Fertilizer Shop Seed completed successfully!');
  await AppDataSource.destroy();
}

seed().catch((err) => { 
  console.error('❌ Seed error:', err); 
  process.exit(1); 
});
