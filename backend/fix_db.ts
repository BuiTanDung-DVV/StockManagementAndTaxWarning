import { DataSource } from 'typeorm';

const AppDataSource = new DataSource({
    type: 'postgres',
    url: 'postgresql://postgres.tmvbmanqegzzlzdrahqv:YOsthmbfkOmB6nwp@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true',
    synchronize: false,
});

async function fix() {
    await AppDataSource.initialize();
    console.log("Connected");
    await AppDataSource.query(`ALTER TABLE stock_takes ADD COLUMN IF NOT EXISTS warehouse_id INT;`);
    await AppDataSource.query(`ALTER TABLE stock_takes ADD COLUMN IF NOT EXISTS shop_id INT;`);
    console.log("Added warehouse_id and shop_id columns");
    await AppDataSource.destroy();
}
fix().catch(console.error);
