export class ProductImportCsvError extends Error {}

export const productImportFields = [
    'sku', 'name', 'unit', 'costPrice', 'sellingPrice', 'wholesalePrice',
    'minStock', 'barcode', 'categoryName', 'tags', 'description',
] as const;
export type ProductImportField = typeof productImportFields[number];
export type ProductImportNumberFormat = 'decimal-dot' | 'vi-VN' | 'en-US';
type CsvRecord = { line: number; cells: string[] };
export type ProductImportCsvRow = CsvRecord & {
    values: Partial<Record<ProductImportField, string | number | string[]>>;
    errors: string[];
};
export type ProductImportCsvOptions = {
    headerLine?: number;
    columns?: Array<ProductImportField | null>;
    numberFormat?: ProductImportNumberFormat;
};

const fieldNames: Record<ProductImportField, string> = {
    sku: 'SKU', name: 'Tên sản phẩm', unit: 'Đơn vị', costPrice: 'Giá nhập',
    sellingPrice: 'Giá bán', wholesalePrice: 'Giá bán sỉ', minStock: 'Mức tối thiểu',
    barcode: 'Mã vạch', categoryName: 'Danh mục', tags: 'Nhãn',
    description: 'Mô tả',
};
const aliases: Record<ProductImportField, string[]> = {
    sku: ['sku', 'ma san pham', 'ma hang', 'product code'],
    name: ['name', 'product name', 'ten san pham', 'ten hang'],
    unit: ['unit', 'don vi', 'don vi tinh'],
    costPrice: ['cost price', 'costprice', 'gia von', 'gia nhap'],
    sellingPrice: ['selling price', 'sellingprice', 'gia ban', 'gia ban vnd', 'gia ban le'],
    wholesalePrice: ['wholesale price', 'wholesaleprice', 'gia ban si'],
    minStock: ['min stock', 'minstock', 'muc toi thieu', 'ton toi thieu'],
    barcode: ['barcode', 'ma vach', 'ean', 'upc'],
    categoryName: ['category', 'category name', 'categoryname', 'danh muc', 'nhom hang'],
    tags: ['tag', 'tags', 'nhan', 'labels'],
    description: ['description', 'mo ta', 'ghi chu', 'notes'],
};
const normalizeHeader = (value: string) => value.normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D')
    .toLowerCase().replace(/[^a-z0-9]/g, '');
const headerFields = new Map(productImportFields.flatMap(field =>
    aliases[field].map(alias => [normalizeHeader(alias), field] as const)));

// Strict quoting avoids silently shifting values into the wrong columns.
function readRecords(source: string, delimiter: string): CsvRecord[] {
    const records: CsvRecord[] = [];
    let cells: string[] = []; let cell = ''; let quoted = false; let afterQuote = false;
    let line = 1; let recordLine = 1;
    const finishCell = () => {
        cells.push(cell); cell = ''; afterQuote = false;
        if (cells.length > 64) throw new ProductImportCsvError('Tệp vượt quá 64 cột.');
    };
    const finishRecord = () => {
        finishCell();
        if (cells.some(value => value.trim())) records.push({ line: recordLine, cells });
        if (records.length > 1010) throw new ProductImportCsvError('Tệp quá nhiều dòng; tối đa 500 dòng sản phẩm mỗi lần.');
        cells = [];
    };
    for (let index = 0; index < source.length; index++) {
        const character = source[index];
        if (quoted) {
            if (character === '"') {
                if (source[index + 1] === '"') { cell += '"'; index++; }
                else { quoted = false; afterQuote = true; }
            } else if (character === '\r' || character === '\n') {
                if (character === '\r' && source[index + 1] === '\n') index++;
                cell += '\n'; line++;
            } else cell += character;
        } else if (character === delimiter) {
            finishCell();
        } else if (character === '\r' || character === '\n') {
            if (character === '\r' && source[index + 1] === '\n') index++;
            finishRecord(); line++; recordLine = line;
        } else if (character === '"') {
            if (afterQuote || cell.trim()) {
                throw new ProductImportCsvError(`Dấu nháy không hợp lệ tại dòng ${line}.`);
            }
            cell = ''; quoted = true;
        } else if (afterQuote) {
            if (character !== ' ' && character !== '\t') {
                throw new ProductImportCsvError(`Ký tự sau dấu nháy tại dòng ${line}.`);
            }
        } else cell += character;
    }
    if (quoted) throw new ProductImportCsvError(`Ô chưa đóng dấu nháy từ dòng ${recordLine}.`);
    if (cell || cells.length || afterQuote) finishRecord();
    return records;
}

function detectDelimiter(source: string) {
    for (const delimiter of [',', ';']) {
        try {
            if (readRecords(source, delimiter).slice(0, 10).some(record => {
                const fields = record.cells.map(value => headerFields.get(normalizeHeader(value)));
                return fields.includes('sku') && fields.filter(Boolean).length >= 2;
            })) return delimiter;
        } catch { /* Try the other dialect; final parsing reports actual errors. */ }
    }
    let quoted = false; let commas = 0; let semicolons = 0; let line = 1;
    for (let index = 0; index < source.length && line <= 12; index++) {
        const character = source[index];
        if (character === '"') {
            if (quoted && source[index + 1] === '"') index++;
            else quoted = !quoted;
        } else if (!quoted) {
            if (character === ',') commas++;
            if (character === ';') semicolons++;
            if (character === '\n') line++;
        }
    }
    return semicolons > commas ? ';' : ',';
}

export function parseProductImportNumber(value: string, format: ProductImportNumberFormat, integer = false) {
    if (value.length > 32) throw new Error('Invalid number');
    let normalized: string;
    if (format === 'vi-VN') {
        if (!/^\d+(?:,\d{1,2})?$/.test(value) &&
            !/^\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?$/.test(value)) throw new Error('Invalid number');
        normalized = value.replace(/\./g, '').replace(',', '.');
    } else if (format === 'en-US') {
        if (!/^\d+(?:\.\d{1,2})?$/.test(value) &&
            !/^\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?$/.test(value)) throw new Error('Invalid number');
        normalized = value.replace(/,/g, '');
    } else {
        if (!/^\d+(?:\.\d{1,2})?$/.test(value)) throw new Error('Invalid number');
        normalized = value;
    }
    const [whole, fraction = ''] = normalized.split('.');
    const cents = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
    const max = BigInt(Number.MAX_SAFE_INTEGER);
    if (integer) {
        if (cents % 100n || cents / 100n > max) throw new Error('Invalid number');
        return Number(cents / 100n);
    }
    if (cents > max) throw new Error('Invalid number');
    const number = Number(cents) / 100;
    const [returnedWhole, returnedFraction = ''] = String(number).split('.');
    if (!/^\d{0,2}$/.test(returnedFraction) ||
        BigInt(returnedWhole) * 100n + BigInt(returnedFraction.padEnd(2, '0')) !== cents) {
        throw new Error('Invalid number');
    }
    return number;
}

function readImportSource(input: unknown) {
    if (typeof input !== 'string' || !input.trim()) throw new ProductImportCsvError('Tệp CSV trống.');
    if (Buffer.byteLength(input, 'utf8') > 1024 * 1024) throw new ProductImportCsvError('Tệp CSV không được vượt quá 1 MB.');
    if (input.includes('\0')) throw new ProductImportCsvError('Tệp CSV có ký tự không hợp lệ.');
    let source = input.replace(/^\uFEFF/, '');
    const separator = /^sep=([,;])(?:\r?\n|\r)/i.exec(source);
    const delimiter = separator?.[1] || detectDelimiter(source);
    source = separator ? source.slice(separator[0].length) : source;
    const records = readRecords(source, delimiter);
    for (const record of records) record.line += separator ? 1 : 0;
    return { delimiter, records };
}

/** Inspect headers before mapping. This never validates or writes catalog rows. */
export function inspectProductImportCsv(input: unknown) {
    const { delimiter, records } = readImportSource(input);
    const candidates = records.slice(0, 10).map(record => ({ ...record,
        columns: record.cells.map(value => headerFields.get(normalizeHeader(value)) || null) }));
    if (!candidates.length) throw new ProductImportCsvError('Tệp CSV trống.');
    const detected = candidates.find(row => row.columns.includes('sku') && row.columns.filter(Boolean).length >= 2);
    return { delimiter, candidates, defaultHeaderLine: (detected || candidates[0]).line };
}

export function parseProductImportCsv(input: unknown, options: ProductImportCsvOptions = {}) {
    if (!options || typeof options !== 'object' || Array.isArray(options) ||
        (options.columns !== undefined && !Array.isArray(options.columns)) ||
        (options.headerLine !== undefined && (!Number.isSafeInteger(options.headerLine) || options.headerLine < 1))) {
        throw new ProductImportCsvError('Ánh xạ cột không hợp lệ.');
    }
    const format = options.numberFormat || 'decimal-dot';
    if (!['decimal-dot', 'vi-VN', 'en-US'].includes(format)) throw new ProductImportCsvError('Chọn lại định dạng số.');
    const { delimiter, records } = readImportSource(input);
    const headerIndex = options.headerLine === undefined
        ? records.slice(0, 10).findIndex(record => {
            const fields = record.cells.map(value => headerFields.get(normalizeHeader(value)));
            return fields.includes('sku') && fields.filter(Boolean).length >= 2;
        })
        : records.findIndex(record => record.line === options.headerLine);
    if (headerIndex < 0) throw new ProductImportCsvError('Không tìm thấy dòng tiêu đề. Chọn dòng tiêu đề và gán cột SKU.');
    const header = records[headerIndex];
    const columns = options.columns || header.cells.map(value => headerFields.get(normalizeHeader(value)) || null);
    if (columns.length !== header.cells.length || columns.some(field =>
        field !== null && !productImportFields.includes(field))) throw new ProductImportCsvError('Ánh xạ cột không hợp lệ.');
    const mapped = columns.filter((field): field is ProductImportField => field !== null);
    if (!mapped.includes('sku')) throw new ProductImportCsvError('Phải gán một cột SKU.');
    if (new Set(mapped).size !== mapped.length) throw new ProductImportCsvError('Một trường đang được gán cho nhiều cột.');
    const data = records.slice(headerIndex + 1);
    if (!data.length) throw new ProductImportCsvError('Tệp chưa có dòng sản phẩm.');
    if (data.length > 500) throw new ProductImportCsvError('Mỗi lần nhập tối đa 500 dòng; không có dòng nào bị cắt bỏ.');
    const rows: ProductImportCsvRow[] = data.map(record => {
        const values: ProductImportCsvRow['values'] = {}; const errors: string[] = [];
        if (record.cells.length !== columns.length) errors.push('Số ô không khớp dòng tiêu đề.');
        columns.forEach((field, index) => {
            if (!field) return;
            const value = (record.cells[index] || '').trim().normalize('NFC');
            // Empty means preserve existing metadata, never clear it implicitly.
            if (!value) return;
            if (['costPrice', 'sellingPrice', 'wholesalePrice', 'minStock'].includes(field)) {
                try { values[field] = parseProductImportNumber(value, format, field === 'minStock'); }
                catch { errors.push(`${fieldNames[field]} không hợp lệ theo định dạng số đã chọn.`); }
            } else if (field === 'tags') {
                const tags = [...new Set(value.split('|').map(tag => tag.trim()).filter(Boolean))];
                if (tags.length > 20 || tags.some(tag => tag.length > 100 || tag.includes(','))) {
                    errors.push('Tối đa 20 nhãn, mỗi nhãn 100 ký tự; dùng | để tách nhãn và không dùng dấu phẩy trong tên nhãn.');
                } else values.tags = tags;
            } else {
                const max = field === 'name' ? 200 : field === 'unit' ? 20 :
                    field === 'description' ? 1000 : field === 'categoryName' ? 100 : 50;
                if (value.length > max) errors.push(`${fieldNames[field]} vượt quá ${max} ký tự.`);
                else values[field] = value;
            }
        });
        if (!values.sku) errors.push('SKU không được để trống.');
        return { ...record, values, errors };
    });
    for (const field of ['sku', 'barcode'] as const) {
        const seen = new Map<string, ProductImportCsvRow>();
        for (const row of rows) {
            const value = row.values[field]; if (typeof value !== 'string' || !value) continue;
            const previous = seen.get(value);
            if (previous) {
                const message = `${fieldNames[field]} trùng trong tệp.`;
                if (!previous.errors.includes(message)) previous.errors.push(message);
                row.errors.push(message);
            } else seen.set(value, row);
        }
    }
    return { delimiter, headerLine: header.line, headers: header.cells, columns,
        ignoredHeaders: header.cells.filter((_, index) => !columns[index]),
        rows, totalRows: rows.length, validRows: rows.filter(row => !row.errors.length).length,
        errorRows: rows.filter(row => row.errors.length).length };
}
