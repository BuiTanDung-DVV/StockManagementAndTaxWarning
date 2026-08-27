const VIETNAMESE_GROUPS: ReadonlyArray<readonly [string, string]> = [
    ['a', 'áàảãạăắằẳẵặâấầẩẫậ'],
    ['e', 'éèẻẽẹêếềểễệ'],
    ['i', 'íìỉĩị'],
    ['o', 'óòỏõọôốồổỗộơớờởỡợ'],
    ['u', 'úùủũụưứừửữự'],
    ['y', 'ýỳỷỹỵ'],
    ['d', 'đ'],
];

const VIETNAMESE_ACCENTS = VIETNAMESE_GROUPS.map(([, chars]) => chars).join('');
const VIETNAMESE_PLAIN = VIETNAMESE_GROUPS.map(([plain, chars]) =>
    plain.repeat([...chars].length),
).join('');

export const foldVietnameseSearchText = (value: string): string =>
    value
        .trim()
        .toLocaleLowerCase('vi')
        .normalize('NFD')
        .replace(/\p{M}/gu, '')
        .replace(/đ/g, 'd');

export const vietnameseSearchExpression = (columnExpression: string): string =>
    `translate(lower(COALESCE(${columnExpression}, '')), :viAccents, :viPlain) LIKE :search`;

export const vietnameseSearchParams = (value: string) => ({
    viAccents: VIETNAMESE_ACCENTS,
    viPlain: VIETNAMESE_PLAIN,
    search: `%${foldVietnameseSearchText(value)}%`,
});
