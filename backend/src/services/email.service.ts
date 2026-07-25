import * as nodemailer from 'nodemailer';

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
                    <div style="background-color: #f1f5f9; padding: 40px 20px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
                        <div style="max-width: 560px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03); border: 1px solid #e2e8f0;">
                            <!-- Header -->
                            <div style="background-color: #1e3a8a; padding: 24px; text-align: center;">
                                <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.5px;">SmartStock <span style="color: #3b82f6;">FinTech</span></h1>
                                <p style="color: #93c5fd; margin: 4px 0 0 0; font-size: 13px; font-weight: 500;">Hệ thống Quản lý Bán hàng & Cảnh báo Thuế</p>
                            </div>

                            <!-- Body -->
                            <div style="padding: 32px 24px;">
                                <h2 style="color: #0f172a; margin: 0 0 16px 0; font-size: 18px; font-weight: 700; text-align: center;">Xác thực tài khoản (OTP)</h2>
                                <p style="font-size: 15px; color: #334155; line-height: 1.6; margin: 0 0 20px 0;">Chào bạn,</p>
                                <p style="font-size: 15px; color: #334155; line-height: 1.6; margin: 0 0 24px 0;">Bạn đang thực hiện đăng ký hoặc đổi mật khẩu trên hệ thống <strong>SmartStock</strong>. Vui lòng nhập mã xác thực OTP dưới đây để tiếp tục:</p>

                                <!-- OTP Box -->
                                <div style="text-align: center; margin: 32px 0;">
                                    <div style="display: inline-block; background-color: #eff6ff; border: 1px dashed #3b82f6; padding: 16px 36px; border-radius: 12px;">
                                        <span style="font-family: 'Courier New', Courier, monospace; font-size: 38px; font-weight: 800; letter-spacing: 6px; color: #1d4ed8;">${otpCode}</span>
                                    </div>
                                    <p style="font-size: 12px; color: #64748b; margin: 12px 0 0 0;">Mã OTP này có hiệu lực trong vòng <strong>2 phút</strong></p>
                                </div>

                                <!-- Warning Alert Box -->
                                <div style="background-color: #fef3c7; border-left: 4px solid #d97706; padding: 16px; border-radius: 6px; margin: 28px 0 0 0;">
                                    <h4 style="color: #92400e; margin: 0 0 6px 0; font-size: 14px; font-weight: 700;">⚠️ Cảnh báo bảo mật</h4>
                                    <p style="color: #b45309; margin: 0; font-size: 13px; line-height: 1.5;">Để bảo vệ an toàn cho tài khoản và số liệu kinh doanh của bạn, tuyệt đối không chia sẻ mã OTP này cho bất kỳ ai, kể cả nhân viên kỹ thuật hoặc quản trị viên hệ thống.</p>
                                </div>
                            </div>

                            <!-- Footer -->
                            <div style="background-color: #f8fafc; padding: 24px; text-align: center; border-top: 1px solid #e2e8f0;">
                                <p style="font-size: 12px; color: #64748b; margin: 0 0 8px 0;">Hỗ trợ khách hàng: <a href="mailto:support@smartstock.vn" style="color: #2563eb; text-decoration: none; font-weight: 600;">support@smartstock.vn</a></p>
                                <p style="font-size: 11px; color: #94a3b8; margin: 0;">Đây là email tự động từ SmartStock FinTech. Vui lòng không phản hồi email này.</p>
                            </div>
                        </div>
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
