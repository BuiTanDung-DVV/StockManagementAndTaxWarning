import { AppDataSource } from '../src/config/db.config';

async function run() {
    await AppDataSource.initialize();
    
    const users = await AppDataSource.query(`SELECT * FROM users WHERE username = 'shopbinhminh'`);
    if (users.length > 0) {
        console.log(`User found: ${users[0].id} - ${users[0].username}`);
        const members = await AppDataSource.query(`SELECT * FROM shop_members WHERE user_id = $1`, [users[0].id]);
        if (members.length > 0) {
            console.log(`Belongs to Shop ID: ${members[0].shop_id}`);
        } else {
            console.log('No shop member record');
        }
    } else {
        console.log('User shopbinhminh not found');
    }

    await AppDataSource.destroy();
}

run().catch(console.error);
