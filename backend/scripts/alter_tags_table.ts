import 'reflect-metadata';
import { AppDataSource } from '../src/config/db.config';

async function main() {
  try {
    console.log('Initializing database connection...');
    await AppDataSource.initialize();
    console.log('Database connected!');

    const query = `
      ALTER TABLE tags DROP CONSTRAINT IF EXISTS tags_shop_id_name_key;
      ALTER TABLE tags ADD COLUMN IF NOT EXISTS type VARCHAR(50) DEFAULT 'product';
      ALTER TABLE tags ADD CONSTRAINT tags_shop_id_type_name_key UNIQUE(shop_id, type, name);
    `;
    
    console.log('Executing query...');
    await AppDataSource.query(query);
    console.log('Table "tags" altered successfully.');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await AppDataSource.destroy();
    console.log('Database connection closed.');
  }
}

main();
