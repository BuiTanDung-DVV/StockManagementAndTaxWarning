import * as nodemailer from 'nodemailer';

export class EmailService {
    private transporter: nodemailer.Transporter | null = null;

    constructor() {
        this.initTransporter();
    }

    private initTransporter() {
        const smtpUser = process.env.SMTP_USER;
        const smtpPass = process.env.SMTP_PASS;

        if (smtpUser && smtpPass) {
            this.transporter = nodemailer.createTransport({
                service: 'gmail',
                auth: {
                    user: smtpUser,
                    pass: smtpPass,
                },
            });
        }
    }

    async sendOtp(email: string, otpCode: string): Promise<boolean> {
        try {
            if (!this.transporter) {
                if (process.env.OTP_DEBUG_RESPONSE === 'true') {
                    console.log(`[Email Service - DEBUG] OTP for ${email}: ${otpCode}`);
                    return true;
                }
                console.error('[Email Service] SMTP is not configured');
                return false;
            }

            const mailOptions = {
                from: `"SmartStock POS & Tax" <${process.env.SMTP_USER}>`,
                to: email,
                subject: `${otpCode} là mã xác thực SmartStock POS & Tax của bạn`,
                html: `
                    <div style="background-color: #f8fafc; padding: 48px 16px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased;">
                        <div style="max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.03); overflow: hidden;">
                            
                            <!-- Subtle Gradient Top Accent Bar -->
                            <div style="height: 4px; background: linear-gradient(90deg, #0284c7 0%, #2563eb 50%, #3b82f6 100%);"></div>
                            
                            <div style="padding: 36px 32px 32px 32px;">
                                <!-- Brand Header -->
                                <div style="margin-bottom: 24px;">
                                    <div style="display: inline-block; background-color: #0f172a; padding: 8px 14px; border-radius: 8px; font-size: 15px; font-weight: 700; color: #ffffff; letter-spacing: -0.3px;">
                                        SmartStock <span style="color: #38bdf8; font-weight: 800;">POS & Tax</span>
                                    </div>
                                </div>

                                <h1 style="color: #0f172a; margin: 0 0 12px 0; font-size: 20px; font-weight: 700; letter-spacing: -0.4px;">Mã xác thực tài khoản</h1>
                                
                                <p style="font-size: 14px; color: #475569; line-height: 1.6; margin: 0 0 24px 0;">
                                    Mã OTP dùng để xác thực giao dịch đăng ký hoặc khôi phục mật khẩu tài khoản SmartStock của bạn là:
                                </p>

                                <!-- OTP Box -->
                                <div style="background-color: #f1f5f9; border-radius: 10px; padding: 20px; text-align: center; margin: 0 0 24px 0; border: 1px solid #e2e8f0;">
                                    <span style="font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 36px; font-weight: 800; letter-spacing: 10px; color: #0f172a; padding-left: 10px;">${otpCode}</span>
                                    <div style="font-size: 12px; color: #64748b; margin-top: 8px; font-weight: 500;">
                                        Mã có hiệu lực trong <strong>5 phút</strong>.
                                    </div>
                                </div>

                                <p style="font-size: 13px; color: #64748b; line-height: 1.5; margin: 0;">
                                    Nếu bạn không gửi yêu cầu này, vui lòng bỏ qua email hoặc liên hệ quản trị viên để bảo mật tài khoản.
                                </p>
                            </div>

                            <!-- Footer -->
                            <div style="background-color: #f8fafc; padding: 20px 32px; border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8; text-align: center; line-height: 1.5;">
                                SmartStock POS & Tax &bull; Hệ thống quản lý bán hàng & cảnh báo thuế<br>
                                Email này được gửi tự động, vui lòng không phản hồi trực tiếp.
                            </div>
                        </div>
                    </div>
                `,
            };

            await this.transporter.sendMail(mailOptions);
            return true;
        } catch (error) {
            console.error(
                '[Email Service] Error sending email:',
                error instanceof Error ? error.message : 'Unknown error'
            );
            return false;
        }
    }
}
