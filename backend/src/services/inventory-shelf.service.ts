import { AppDataSource } from '../config/db.config';

export function listInventoryShelves(shopId: number) {
    return AppDataSource.query(
        `SELECT s.warehouse_id AS "warehouseId", s.product_id AS "productId",
                w.name AS "warehouseName", p.name AS "productName", p.sku, p.image_url AS "imageUrl", s.rack, s.level, s.bin
         FROM inventory_shelf_positions s
         JOIN warehouses w ON w.id = s.warehouse_id AND w.shop_id = s.shop_id AND w.is_active
         JOIN products p ON p.id = s.product_id AND p.shop_id = s.shop_id AND p.is_active
         WHERE s.shop_id = $1
         ORDER BY w.name, s.rack, s.level, s.bin, p.name`,
        [shopId],
    );
}

type ShelfAddress = { rack: string; level: number; bin: number };

export async function saveInventoryShelf(
    shopId: number,
    input: ShelfAddress & { warehouseId: number; productId: number; expectedPosition?: ShelfAddress | null },
) {
    const [position] = await AppDataSource.query(
        `INSERT INTO inventory_shelf_positions (shop_id, warehouse_id, product_id, rack, level, bin)
         SELECT $1, w.id, p.id, $4, $5, $6
         FROM warehouses w
         JOIN products p ON p.id = $3 AND p.shop_id = $1 AND p.is_active
         WHERE w.id = $2 AND w.shop_id = $1 AND w.is_active
           AND ($7::text IS NULL OR EXISTS (
             SELECT 1 FROM inventory_shelf_positions current
             WHERE current.shop_id=$1 AND current.warehouse_id=$2 AND current.product_id=$3
           ))
         ON CONFLICT (shop_id, warehouse_id, product_id)
         DO UPDATE SET rack = EXCLUDED.rack, level = EXCLUDED.level, bin = EXCLUDED.bin
         WHERE NOT $10::boolean OR (
           inventory_shelf_positions.rack = $7
           AND inventory_shelf_positions.level = $8
           AND inventory_shelf_positions.bin = $9
         )
         RETURNING product_id AS "productId"`,
        [shopId, input.warehouseId, input.productId, input.rack, input.level, input.bin,
            input.expectedPosition?.rack ?? null, input.expectedPosition?.level ?? null,
            input.expectedPosition?.bin ?? null, input.expectedPosition !== undefined],
    );
    return position;
}
