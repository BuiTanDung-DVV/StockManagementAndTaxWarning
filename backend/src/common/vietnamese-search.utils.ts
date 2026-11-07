const VIETNAMESE_GROUPS: ReadonlyArray<readonly [string, string]> = [
    ['a', 'áàảãạăắằẳẵặâấầẩẫậ'],
    ['e', 'éèẻẽẹêếềểễệ'],
    ['i', 'íìỉĩị'],
    ['o', 'óòỏõọôốồổỗộơớờởỡợ'],
    ['u', 'úùủũụưứừửữự'],
    ['y', 'ýỳỷỹỵ'],
    ['d', 'đ'],
];

// Include uppercase accents explicitly: PostgreSQL's lower() under the C
// locale does not fold non-ASCII capitals such as Đ or Ạ.
const VIETNAMESE_ACCENTS = VIETNAMESE_GROUPS.map(([, chars]) => chars + chars.toUpperCase()).join('');
const VIETNAMESE_PLAIN = VIETNAMESE_GROUPS.map(([plain, chars]) =>
    plain.repeat([...chars].length * 2),
).join('');

export const foldVietnameseSearchText = (value: string): string =>
    value
        .trim()
        .toLocaleLowerCase('vi')
        .normalize('NFD')
        .replace(/\p{M}/gu, '')
        .replace(/đ/g, 'd');

export const vietnameseSearchExpression = (columnExpression: string): string =>
    `translate(lower(COALESCE(${columnExpression}, '')), :viAccents, :viPlain) LIKE :search ESCAPE '!'`;

export const vietnameseSearchParams = (value: string) => ({
    viAccents: VIETNAMESE_ACCENTS,
    viPlain: VIETNAMESE_PLAIN,
    search: `%${foldVietnameseSearchText(value).replace(/[!%_]/g, char => '!' + char)}%`,
});
