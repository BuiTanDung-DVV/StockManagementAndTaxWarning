import 'reflect-metadata';
import { AppDataSource } from './src/config/db.config';
import { User } from './src/auth/entities';
import * as bcrypt from 'bcrypt';

async function createTestUser() {
    await AppDataSource.initialize();
    const userRepo = AppDataSource.getRepository(User);
    const existing = await userRepo.findOne({ where: { phone: '0988776655' } });
    
    if (existing) {
        console.log('User already exists. Deleting it to recreate cleanly.');
        await userRepo.remove(existing);
    }
    
    const hashedPassword = await bcrypt.hash('123456', 10);
    const user = userRepo.create({
        username: '0988776655',
        phone: '0988776655',
        fullName: 'Nguyen Van Test',
        passwordHash: hashedPassword,
        isOnboarded: true,
        isActive: true,
        role: 'ADMIN',
        accountType: 'SHOP'
    });
    
    await userRepo.save(user);
    console.log('Test user created successfully!');
    await AppDataSource.destroy();
}

createTestUser().catch(console.error);
