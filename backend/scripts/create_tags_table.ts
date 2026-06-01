import 'reflect-metadata';
import { AppDataSource } from '../src/config/db.config';

async function main() {
  try {
    console.log('Initializing database connection...');
    await AppDataSource.initialize();
    console.log('Database connected!');

    const query = `
      CREATE TABLE IF NOT EXISTS tags (
        id SERIAL PRIMARY KEY,
        shop_id INT NOT NULL,
        name VARCHAR(100) NOT NULL,
        color VARCHAR(20) DEFAULT '#3B82F6',
        UNIQUE(shop_id, name)
      );
    `;
    
    console.log('Executing query...');
    await AppDataSource.query(query);
    console.log('Table "tags" created successfully.');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await AppDataSource.destroy();
    console.log('Database connection closed.');
  }
}

main();
