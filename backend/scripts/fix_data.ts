import { AppDataSource } from '../src/config/db.config';

async function fix() {
    await AppDataSource.initialize();
    
    // Check what is causing the huge "Chưa phân loại" stock
    const badStock = await AppDataSource.query(`
        SELECT p.name, i.quantity 
        FROM inventory_stocks i
        JOIN products p ON i.product_id = p.id
        WHERE i.shop_id = 22 AND p.category_id IS NULL
    `);
    console.log("Uncategorized stock:", badStock);

    // Delete or update the bad stock
    await AppDataSource.query(`
        DELETE FROM inventory_stocks 
        WHERE shop_id = 22 AND product_id IN (
            SELECT id FROM products WHERE category_id IS NULL
        )
    `);
    console.log("Deleted uncategorized stock for shop 22.");

    await AppDataSource.destroy();
}

fix().catch(console.error);
