import * as nodemailer from 'nodemailer';
import { config } from '../config/env.config';

export class EmailService {
    private transporter: nodemailer.Transporter;

    constructor() {
        this.transporter = nodemailer.createTransport({
            service: 'gmail',
            auth: {
                user: process.env.SMTP_USER || 'your-email@gmail.com', // fallback or real env
                pass: process.env.SMTP_PASS || 'your-app-password', // generated app password
            },
        });
    }

    async sendOtp(email: string, otpCode: string): Promise<boolean> {
        try {
            console.log(`[Email Service] Sending OTP to ${email}`);

            const isSandbox = !process.env.SMTP_USER || process.env.SMTP_USER === 'your-email@gmail.com';
            
            if (isSandbox) {
                console.log(`=========================================`);
                console.log(`[EMAIL SANDBOX] To: ${email}`);
                console.log(`[EMAIL SANDBOX] OTP: ${otpCode}`);
                console.log(`=========================================`);
                return true;
            }

            const mailOptions = {
                from: `"SmartStock & Tax Warning" <${process.env.SMTP_USER}>`,
                to: email,
                subject: 'Xác thực OTP - SmartStock',
                html: `
                    <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #f9f9f9;">
                        <h2 style="color: #2b5cff; text-align: center;">Mã Xác Thực Của Bạn</h2>
                        <p style="font-size: 16px; color: #333;">Chào bạn,</p>
                        <p style="font-size: 16px; color: #333;">Mã xác thực OTP của bạn là:</p>
                        <div style="text-align: center; margin: 24px 0;">
                            <span style="font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #2b5cff; background-color: #eef2ff; padding: 12px 24px; border-radius: 8px;">${otpCode}</span>
                        </div>
                        <p style="font-size: 14px; color: #666; text-align: center;">Mã OTP có hiệu lực trong 2 phút. Xin đừng chia sẻ mã này cho bất kỳ ai.</p>
                        <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 24px 0;" />
                        <p style="font-size: 12px; color: #999; text-align: center;">SmartStock & Tax Warning - Hệ thống Quản lý Bán hàng</p>
                    </div>
                `,
            };

            await this.transporter.sendMail(mailOptions);
            console.log('[Email Service] OTP sent successfully to', email);
            return true;
        } catch (error) {
            console.error('[Email Service] Error sending email:', error);
            return false;
        }
    }
}
