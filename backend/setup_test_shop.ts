import 'reflect-metadata';
import { AppDataSource } from './src/config/db.config';
import { User } from './src/auth/entities';
import { ShopProfile } from './src/system/entities';
import { ShopMember } from './src/shop/entities';

async function setupTestShop() {
    await AppDataSource.initialize();
    
    const userRepo = AppDataSource.getRepository(User);
    const shopRepo = AppDataSource.getRepository(ShopProfile);
    const memberRepo = AppDataSource.getRepository(ShopMember);
    
    const user = await userRepo.findOne({ where: { phone: '0988776655' } });
    if (!user) {
        console.error('Test user 0988776655 not found. Please run create_test_user.ts first.');
        await AppDataSource.destroy();
        return;
    }
    
    // Check if user already has a membership
    const existingMember = await memberRepo.findOne({ where: { userId: user.id } });
    if (existingMember) {
        console.log(`User already has a membership in shop ID: ${existingMember.shopId}`);
        await AppDataSource.destroy();
        return;
    }
    
    // Check if shop already exists
    let shop = await shopRepo.findOne({ where: { shopCode: 'TESTQA' } });
    if (!shop) {
        shop = shopRepo.create({
            shopName: 'Cửa hàng Kiểm thử QA',
            ownerName: 'Nguyen Van Test',
            address: '123 Đường QA, Quận 1, TP. HCM',
            shopCode: 'TESTQA',
            phone: '0988776655',
            businessSector: 'TRADE',
            applyVatReduction: false
        });
        shop = await shopRepo.save(shop);
        console.log(`Created shop: ${shop.shopName} with code: ${shop.shopCode}`);
    } else {
        console.log(`Shop with code ${shop.shopCode} already exists.`);
    }
    
    // Create Owner membership
    const member = memberRepo.create({
        shopId: shop.id,
        userId: user.id,
        memberType: 'OWNER',
        status: 'ACTIVE',
        isActive: true
    });
    
    await memberRepo.save(member);
    console.log('Linked test user as Owner of the test shop!');
    
    await AppDataSource.destroy();
}

setupTestShop().catch(console.error);
