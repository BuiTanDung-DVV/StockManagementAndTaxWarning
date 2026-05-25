import { config } from '../config/env.config';

export class SmsService {
    async sendOtp(phone: string, otpCode: string): Promise<boolean> {
        const provider = (process.env.SMS_PROVIDER || 'sandbox').toLowerCase();
        const content = `[SmartStock] Ma OTP xac minh cua ban la: ${otpCode}. Co hieu luc trong 2 phut.`;

        console.log(`[SMS Service] Sending OTP to ${phone} using provider: ${provider}`);

        if (provider === 'esms') {
            const apiKey = process.env.ESMS_API_KEY;
            const secretKey = process.env.ESMS_SECRET_KEY;
            if (!apiKey || !secretKey) {
                console.error('[SMS Service] eSMS config is missing!');
                return false;
            }
            try {
                const url = `http://rest.esms.vn/MainService.svc/json/SendMultipleMessage_G?Phone=${phone}&Content=${encodeURIComponent(content)}&ApiKey=${apiKey}&SecretKey=${secretKey}&SmsType=2`;
                const response = await fetch(url);
                const result = await response.json();
                console.log('[SMS Service] eSMS Response:', result);
                return result.CodeResult === '100';
            } catch (error) {
                console.error('[SMS Service] eSMS Send Error:', error);
                return false;
            }
        } else if (provider === 'twilio') {
            const accountSid = process.env.TWILIO_ACCOUNT_SID;
            const authToken = process.env.TWILIO_AUTH_TOKEN;
            const fromNumber = process.env.TWILIO_PHONE_NUMBER;
            if (!accountSid || !authToken || !fromNumber) {
                console.error('[SMS Service] Twilio config is missing!');
                return false;
            }
            try {
                let normalizedPhone = phone.trim();
                if (normalizedPhone.startsWith('0')) {
                    normalizedPhone = '+84' + normalizedPhone.substring(1);
                } else if (!normalizedPhone.startsWith('+')) {
                    normalizedPhone = '+' + normalizedPhone;
                }

                const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
                const credentials = Buffer.from(`${accountSid}:${authToken}`).toString('base64');
                
                const response = await fetch(url, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Basic ${credentials}`,
                        'Content-Type': 'application/x-www-form-urlencoded'
                    },
                    body: new URLSearchParams({
                        From: fromNumber,
                        To: normalizedPhone,
                        Body: content
                    })
                });
                const result = await response.json();
                console.log('[SMS Service] Twilio Response:', result);
                return response.status === 201 || !!result.sid;
            } catch (error) {
                console.error('[SMS Service] Twilio Send Error:', error);
                return false;
            }
        } else {
            console.log(`=========================================`);
            console.log(`[SMS SANDBOX] To: ${phone}`);
            console.log(`[SMS SANDBOX] Msg: ${content}`);
            console.log(`=========================================`);
            return true;
        }
    }
}
