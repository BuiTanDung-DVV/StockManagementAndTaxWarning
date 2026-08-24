export interface AddressSuggestion {
    display_name: string;
    place_id: string;
    lat: string;
    lon: string;
}

export class AddressLookupService {
    async searchVietnameseAddresses(query: string): Promise<AddressSuggestion[]> {
        const normalized = query.trim();
        if (normalized.length < 3 || normalized.length > 200) return [];

        const url = new URL('https://nominatim.openstreetmap.org/search');
        url.searchParams.set('q', normalized);
        url.searchParams.set('format', 'jsonv2');
        url.searchParams.set('limit', '5');
        url.searchParams.set('countrycodes', 'vn');
        url.searchParams.set('addressdetails', '0');

        const response = await fetch(url, {
            headers: {
                'User-Agent': 'SmartStockTaxApp/1.0 (address lookup)',
                'Accept-Language': 'vi',
            },
            signal: AbortSignal.timeout(8_000),
        });
        if (!response.ok) {
            throw new Error('Dịch vụ tra cứu địa chỉ đang tạm thời không khả dụng');
        }
        const payload = await response.json();
        if (!Array.isArray(payload)) return [];
        return payload
            .filter(item => item && item.display_name && item.lat && item.lon)
            .slice(0, 5)
            .map(item => ({
                display_name: String(item.display_name),
                place_id: String(item.place_id ?? item.osm_id ?? ''),
                lat: String(item.lat),
                lon: String(item.lon),
            }));
    }
}

export const addressLookupService = new AddressLookupService();
