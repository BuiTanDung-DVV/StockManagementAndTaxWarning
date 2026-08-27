import * as fs from 'fs/promises';
import * as path from 'path';
import { v2 as cloudinary } from 'cloudinary';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';

type ShopMedia = {
    slug: 'vlxd' | 'nong-nghiep';
    profileId: number;
    productSlugs: Set<string>;
};

let mediaRoot = process.env.TEST_MEDIA_ROOT
    ? path.resolve(process.env.TEST_MEDIA_ROOT)
    : path.resolve(process.cwd(), 'database/seed-assets/test-media');
const backupRoot = process.env.VERCEL === '1'
    ? '/tmp'
    : path.resolve(process.cwd(), 'database/backups');

const constructionSlugs = new Set([
    'bo-sen-tam-nong-lanh',
    'bon-cau-mot-khoi',
    'bot-tret-tuong-40kg',
    'cat-be-tong',
    'cat-xay-to',
    'chau-rua-chen-inox',
    'chong-tham-goc-xi-mang-20kg',
    'da-1x2',
    'day-dien-2-5mm2',
    'den-led-am-tran-9w',
    'gach-ong-4-lo',
    'gach-the',
    'gian-phoi-inox-gap-gon',
    'guong-phong-tam-chong-o',
    'ke-chen-inox-2-tang',
    'ke-goc-inox-phong-tam',
    'keo-dan-gach-25kg',
    'khoa-cua-tay-gat',
    'lavabo-dat-ban',
    'luoi-thep-han-d4',
    'o-cam-doi',
    'ong-pvc-phi-21',
    'ong-pvc-phi-60',
    'son-lot-18l',
    'son-noi-that-18l',
    'thep-cay-phi-10',
    'thep-cuon-phi-6',
    'thung-rac-dap-chan-20l',
    'tu-lavabo-pvc-80cm',
    'voi-lavabo-inox',
    'voi-rua-chen-nong-lanh',
    'xi-mang-pcb40-50kg',
]);

const agricultureSlugs = new Set([
    'bau-uom-cay-12x18cm',
    'bay-con-trung-sinh-hoc',
    'bec-tuoi-phun-mua',
    'binh-phun-dien-20l',
    'che-pham-vi-sinh-xu-ly-dat-1kg',
    'dat-sach-trong-rau-20l',
    'day-tuoi-pe-phi-16',
    'hat-giong-bap-lai-1kg',
    'hat-giong-ca-chua-20g',
    'hat-giong-dua-leo-50g',
    'hat-giong-lua-xac-nhan-10kg',
    'hat-giong-rau-cai-100g',
    'khay-uom-105-lo',
    'keo-cat-canh',
    'luoi-che-nang-2m-x-50m',
    'phan-bon-la-vi-luong-500ml',
    'phan-dap-18-46-0-50kg',
    'phan-huu-co-vi-sinh-25kg',
    'phan-kali-kcl-50kg',
    'phan-npk-16-16-8-50kg',
    'phan-npk-20-20-15-50kg',
    'phan-trun-que-10kg',
    'phan-ure-46-50kg',
    'thuoc-tru-benh-sinh-hoc-500g',
    'thuoc-tru-co-chon-loc-500ml',
    'thuoc-tru-sau-sinh-hoc-500ml',
    'trau-hun-20l',
    'gang-tay-lam-vuon',
    'voi-nong-nghiep-25kg',
    'xo-dua-da-xu-ly-20l',
]);

const shops: ShopMedia[] = [
    { slug: 'vlxd', profileId: 34, productSlugs: constructionSlugs },
    { slug: 'nong-nghiep', profileId: 35, productSlugs: agricultureSlugs },
];

function slugify(value: string): string {
    return value
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/đ/gi, 'd')
        .replace(/²/g, '2')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '');
}

async function assertAssetsExist(): Promise<void> {
    const candidates = [
        mediaRoot,
        path.resolve(process.cwd(), 'backend/database/seed-assets/test-media'),
        path.resolve(__dirname, '../../database/seed-assets/test-media'),
        path.resolve(__dirname, '../../../database/seed-assets/test-media'),
    ];
    for (const candidate of candidates) {
        try {
            await fs.access(path.join(candidate, 'products'));
            mediaRoot = candidate;
            break;
        } catch {
            // Try the next Vercel/local runtime layout.
        }
    }

    const required = [
        ...Array.from(constructionSlugs),
        ...Array.from(agricultureSlugs),
    ].map((slug) => path.join(mediaRoot, 'products', `${slug}.webp`));

    for (const shop of shops) {
        required.push(
            path.join(mediaRoot, 'brand', `logo-${shop.slug}.webp`),
            path.join(mediaRoot, 'brand', `qr-${shop.slug}.webp`),
            path.join(mediaRoot, 'brand', `avatar-${shop.slug}.webp`),
            path.join(mediaRoot, 'documents', `receipt-${shop.slug}.webp`),
            path.join(mediaRoot, 'documents', `invoice-${shop.slug}.webp`),
            path.join(mediaRoot, 'documents', `identity-${shop.slug}.webp`),
        );
    }

    const missing: string[] = [];
    for (const file of required) {
        try {
            await fs.access(file);
        } catch {
            missing.push(path.relative(mediaRoot, file));
        }
    }
    if (missing.length) {
        throw new Error(`Thiếu ${missing.length} tệp media: ${missing.join(', ')}`);
    }
}

async function createBackup(): Promise<string> {
    const backup = {
        createdAt: new Date().toISOString(),
        products: await AppDataSource.query(
            'SELECT id, shop_id, image_url FROM public.products WHERE image_url IS NOT NULL',
        ),
        shopProfiles: await AppDataSource.query(
            'SELECT id, logo_url, qr_payment_url FROM public.shop_profiles WHERE id = ANY($1)',
            [shops.map((shop) => shop.profileId)],
        ),
        receipts: await AppDataSource.query(
            'SELECT id, shop_id, receipt_image_url FROM public.cash_transactions WHERE receipt_image_url IS NOT NULL',
        ),
        invoices: await AppDataSource.query(
            'SELECT id, shop_id, image_url FROM public.invoices WHERE image_url IS NOT NULL',
        ),
        customers: await AppDataSource.query(
            `SELECT id, shop_id, avatar_url, identity_image_url
             FROM public.customers
             WHERE avatar_url IS NOT NULL OR identity_image_url IS NOT NULL`,
        ),
        users: await AppDataSource.query(
            'SELECT id, avatar_url FROM public.users WHERE avatar_url IS NOT NULL',
        ),
    };
    await fs.mkdir(backupRoot, { recursive: true });
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const file = path.join(backupRoot, `test-media-before-${timestamp}.json`);
    await fs.writeFile(file, JSON.stringify(backup, null, 2), 'utf8');
    return file;
}

async function upload(
    file: string,
    publicId: string,
): Promise<string> {
    const result = await cloudinary.uploader.upload(file, {
        public_id: publicId,
        resource_type: 'image',
        overwrite: true,
        invalidate: true,
        use_filename: false,
        unique_filename: false,
    });
    return result.secure_url;
}

async function uploadAll(onlyMissingProducts = false): Promise<Map<string, string>> {
    cloudinary.config({
        cloud_name: config.cloudinaryCloudName,
        api_key: config.cloudinaryApiKey,
        api_secret: config.cloudinaryApiSecret,
        secure: true,
    });

    const tasks: Array<{
        key: string;
        file: string;
        publicId: string;
    }> = [];
    const missingProductKeys = new Set<string>();
    if (onlyMissingProducts) {
        const missingProducts = await AppDataSource.query(
            `SELECT shop_id, trim(split_part(name, chr(183), 1)) AS family
             FROM public.products
             WHERE shop_id = ANY($1) AND image_url IS NULL`,
            [shops.map((shop) => shop.profileId)],
        );
        for (const product of missingProducts) {
            missingProductKeys.add(
                `product:${product.shop_id}:${slugify(String(product.family))}`,
            );
        }
    }
    for (const shop of shops) {
        for (const productSlug of shop.productSlugs) {
            const key = `product:${shop.profileId}:${productSlug}`;
            if (onlyMissingProducts && !missingProductKeys.has(key)) continue;
            tasks.push({
                key,
                file: path.join(mediaRoot, 'products', `${productSlug}.webp`),
                publicId: `smartstock/shops/${shop.profileId}/products/test-seed/${productSlug}`,
            });
        }

        if (onlyMissingProducts) continue;
        const items = [
            ['logo', 'brand', `logo-${shop.slug}.webp`, 'branding/test-logo'],
            ['qr', 'brand', `qr-${shop.slug}.webp`, 'payment-qr/test-seed'],
            ['avatar', 'brand', `avatar-${shop.slug}.webp`, 'avatars/test-seed'],
            ['receipt', 'documents', `receipt-${shop.slug}.webp`, 'documents/test-receipt'],
            ['invoice', 'documents', `invoice-${shop.slug}.webp`, 'documents/test-invoice'],
            ['identity', 'documents', `identity-${shop.slug}.webp`, 'documents/test-identity'],
        ] as const;
        for (const [kind, folder, fileName, publicPath] of items) {
            tasks.push({
                key: `${kind}:${shop.profileId}`,
                file: path.join(mediaRoot, folder, fileName),
                publicId: `smartstock/shops/${shop.profileId}/${publicPath}`,
            });
        }
    }

    const urls = new Map<string, string>();
    const concurrency = 12;
    for (let offset = 0; offset < tasks.length; offset += concurrency) {
        const batch = tasks.slice(offset, offset + concurrency);
        const results = await Promise.all(
            batch.map(async (task) => ({
                key: task.key,
                url: await upload(task.file, task.publicId),
            })),
        );
        for (const result of results) {
            urls.set(result.key, result.url);
        }
    }
    return urls;
}

async function updateDatabase(
    urls: Map<string, string>,
    onlyMissingProducts = false,
): Promise<void> {
    await AppDataSource.transaction(async (manager) => {
        const products = await manager.query(
            `SELECT id, shop_id, trim(split_part(name, chr(183), 1)) AS family
             FROM public.products
             WHERE shop_id = ANY($1)`,
            [shops.map((shop) => shop.profileId)],
        );
        const productUpdates: Array<{ id: number; url: string }> = [];
        for (const product of products) {
            const slug = slugify(String(product.family));
            const url = urls.get(`product:${product.shop_id}:${slug}`);
            if (!url && !onlyMissingProducts) {
                throw new Error(`Không có ảnh cho sản phẩm ${product.id}: ${product.family}`);
            }
            if (!url) continue;
            productUpdates.push({ id: Number(product.id), url });
        }
        if (productUpdates.length) {
            await manager.query(
                `UPDATE public.products AS product
                 SET image_url = media.url, updated_at = NOW()
                 FROM jsonb_to_recordset($1::jsonb) AS media(id int, url text)
                 WHERE product.id = media.id`,
                [JSON.stringify(productUpdates)],
            );
        }

        if (onlyMissingProducts) return;
        for (const shop of shops) {
            const logo = urls.get(`logo:${shop.profileId}`);
            const qr = urls.get(`qr:${shop.profileId}`);
            const avatar = urls.get(`avatar:${shop.profileId}`);
            const receipt = urls.get(`receipt:${shop.profileId}`);
            const invoice = urls.get(`invoice:${shop.profileId}`);
            const identity = urls.get(`identity:${shop.profileId}`);
            if (!logo || !qr || !avatar || !receipt || !invoice || !identity) {
                throw new Error(`Thiếu URL media cho cửa hàng ${shop.profileId}`);
            }

            await manager.query(
                `UPDATE public.shop_profiles
                 SET logo_url = $1, qr_payment_url = $2
                 WHERE id = $3`,
                [logo, qr, shop.profileId],
            );
            await manager.query(
                `UPDATE public.cash_transactions
                 SET receipt_image_url = $1
                 WHERE shop_id = $2`,
                [receipt, shop.profileId],
            );
            await manager.query(
                'UPDATE public.invoices SET image_url = $1 WHERE shop_id = $2',
                [invoice, shop.profileId],
            );
            await manager.query(
                `UPDATE public.customers
                 SET avatar_url = $1, identity_image_url = $2, updated_at = NOW()
                 WHERE shop_id = $3`,
                [avatar, identity, shop.profileId],
            );
            await manager.query(
                `UPDATE public.users AS u
                 SET avatar_url = $1, updated_at = NOW()
                 WHERE EXISTS (
                     SELECT 1
                     FROM public.shop_members AS sm
                     WHERE sm.user_id = u.id
                       AND sm.shop_id = $2
                       AND sm.is_active = TRUE
                 )`,
                [avatar, shop.profileId],
            );
        }

        const defaultAvatar = urls.get('avatar:34');
        await manager.query(
            `UPDATE public.users
             SET avatar_url = $1, updated_at = NOW()
             WHERE avatar_url IS NULL`,
            [defaultAvatar],
        );
    });
}

async function validateResult(): Promise<Record<string, unknown>[]> {
    return AppDataSource.query(`
        SELECT 'products' AS scope, count(*)::int AS total,
               count(image_url)::int AS populated FROM public.products
        UNION ALL
        SELECT 'shop_logos', count(*)::int, count(logo_url)::int
        FROM public.shop_profiles WHERE id IN (34, 35)
        UNION ALL
        SELECT 'shop_qr', count(*)::int, count(qr_payment_url)::int
        FROM public.shop_profiles WHERE id IN (34, 35)
        UNION ALL
        SELECT 'receipts', count(*)::int, count(receipt_image_url)::int
        FROM public.cash_transactions
        UNION ALL
        SELECT 'invoices', count(*)::int, count(image_url)::int
        FROM public.invoices
        UNION ALL
        SELECT 'customer_avatars', count(*)::int, count(avatar_url)::int
        FROM public.customers
        UNION ALL
        SELECT 'customer_identity', count(*)::int, count(identity_image_url)::int
        FROM public.customers
        UNION ALL
        SELECT 'user_avatars', count(*)::int, count(avatar_url)::int
        FROM public.users
    `);
}

export async function seedTestMedia(): Promise<Record<string, unknown>[]> {
    await assertAssetsExist();
    if (!AppDataSource.isInitialized) {
        await AppDataSource.initialize();
    }
    const backupFile = await createBackup();
    console.log(`Đã sao lưu URL hiện tại: ${path.relative(process.cwd(), backupFile)}`);

    if (
        !config.cloudinaryCloudName ||
        !config.cloudinaryApiKey ||
        !config.cloudinaryApiSecret
    ) {
        throw new Error('Thiếu cấu hình Cloudinary');
    }

    const onlyMissingProducts = process.argv.includes('--only-missing-products');
    const urls = await uploadAll(onlyMissingProducts);
    console.log(`Đã tải ${urls.size} tài nguyên lên Cloudinary`);

    await updateDatabase(urls, onlyMissingProducts);
    const result = await validateResult();
    console.table(result);
    return result;
}

if (require.main === module) {
    seedTestMedia()
        .catch((error) => {
            console.error(error instanceof Error ? error.message : error);
            process.exitCode = 1;
        })
        .finally(async () => {
            if (AppDataSource.isInitialized) {
                await AppDataSource.destroy();
            }
        });
}
