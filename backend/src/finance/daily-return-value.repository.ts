import type { EntityManager } from 'typeorm';
import { openingEffectCents, openingEffectValue } from './opening-balance-effects.repository';

/** Merchandise returned on this day, including item tax, excluding delivery and cash refunds. */
export async function readDailyReturnValue(manager: EntityManager, shopId: number, from: Date, to: Date): Promise<number> {
    const [result] = await manager.query(`WITH selected_returns AS (
        SELECT r.id,r.order_id,o.id AS scoped_order,o.subtotal,o.discount_amount
        FROM sales_returns r LEFT JOIN sales_orders o ON o.id=r.order_id AND o.shop_id=$1
        WHERE r.shop_id=$1 AND r.return_date >= $2 AND r.return_date <= $3
          AND UPPER(COALESCE(r.status,''))='COMPLETED'
    ), returned_products AS (
        SELECT ri.return_id,ri.product_id,SUM(ri.quantity)::numeric AS quantity,
            COUNT(*) FILTER(WHERE ri.quantity<=0 OR (ri.shop_id IS NOT NULL AND ri.shop_id<>$1)) AS invalid
        FROM sales_return_items ri JOIN selected_returns r ON r.id=ri.return_id
        GROUP BY ri.return_id,ri.product_id
    ), sold_products AS (
        SELECT oi.order_id,oi.product_id,SUM(oi.quantity)::numeric AS quantity,
            SUM(oi.subtotal) AS subtotal,SUM(oi.tax_amount) AS tax,
            COUNT(*) FILTER(WHERE oi.quantity<=0 OR oi.subtotal<0 OR oi.tax_amount<0
                OR (oi.shop_id IS NOT NULL AND oi.shop_id<>$1)) AS invalid
        FROM sales_order_items oi JOIN sales_orders o ON o.id=oi.order_id AND o.shop_id=$1
        WHERE EXISTS(SELECT 1 FROM selected_returns r WHERE r.order_id=o.id)
        GROUP BY oi.order_id,oi.product_id
    ) SELECT COALESCE(ROUND(SUM(CASE WHEN s.quantity>0 THEN
        (CASE WHEN r.subtotal>0 THEN s.subtotal*(1-r.discount_amount/r.subtotal) ELSE 0 END
            + COALESCE(s.tax,0))*p.quantity/s.quantity ELSE 0 END),2),0)::text AS value,
        COUNT(*) FILTER(WHERE r.scoped_order IS NULL OR p.product_id IS NULL OR s.product_id IS NULL
            OR s.quantity<=0 OR p.quantity<=0 OR p.quantity>s.quantity OR p.invalid>0 OR s.invalid>0
            OR r.subtotal<0 OR r.discount_amount<0 OR r.discount_amount>r.subtotal) AS invalid
        FROM selected_returns r LEFT JOIN returned_products p ON p.return_id=r.id
        LEFT JOIN sold_products s ON s.order_id=r.order_id AND s.product_id=p.product_id`, [shopId, from, to]);
    if (Number(result?.invalid) !== 0) throw new Error('Validation: Cần đối chiếu dữ liệu trả hàng trước khi chốt ngày.');
    return openingEffectValue(openingEffectCents(result.value));
}
