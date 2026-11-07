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

    async sendOtp(email: string, otpCode: string, purpose?: 'PROFILE_EMAIL' | 'EMAIL_CHANGE_OLD' | 'EMAIL_CHANGE_NEW'): Promise<boolean> {
        try {
            if (!this.transporter) {
                const isProduction = process.env.NODE_ENV === 'production'
                    || process.env.VERCEL_ENV === 'production';
                if (!isProduction && process.env.OTP_DEBUG_RESPONSE === 'true') {
                    console.info('[Email Service] Delivery result', { outcome: 'debug_only' });
                    return true;
                }
                console.error('[Email Service] SMTP is not configured');
                return false;
            }

            const mailOptions = {
                from: `"SmartStock" <${process.env.SMTP_USER}>`,
                to: email,
                subject: `${otpCode} là mã xác thực SmartStock của bạn`,
                html: `
                    <!DOCTYPE html>
                    <html lang="vi">
                    <head>
                      <meta charset="UTF-8">
                      <meta name="viewport" content="width=device-width, initial-scale=1.0">
                      <title>Mã xác thực OTP</title>
                    </head>
                    <body style="margin: 0; padding: 0; background-color: #f4f4f5; font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased; color: #09090b;">
                      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #f4f4f5; padding: 48px 16px;">
                        <tr>
                          <td align="center">
                            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width: 460px; background-color: #ffffff; border-radius: 16px; border: 1px solid #e4e4e7; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.03); overflow: hidden;">
                              <!-- Card Padding Area -->
                              <tr>
                                <td style="padding: 40px 36px 36px 36px;">
                                  
                                  <!-- Brand Header Badge -->
                                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-bottom: 32px;">
                                    <tr>
                                      <td>
                                        <div style="display: inline-block;">
                                          <span style="font-size: 18px; font-weight: 800; color: #09090b; letter-spacing: -0.5px; vertical-align: middle;">SmartStock</span>
                                          <span style="display: inline-block; width: 6px; height: 6px; background-color: #2563eb; border-radius: 50%; margin: 0 6px 2px 6px; vertical-align: middle;"></span>
                                          <span style="font-size: 12px; font-weight: 600; color: #2563eb; background-color: #eff6ff; padding: 3px 8px; border-radius: 6px; border: 1px solid #dbeafe; vertical-align: middle;">Bán hàng &amp; Thuế</span>
                                        </div>
                                      </td>
                                    </tr>
                                  </table>

                                  <!-- Heading & Text -->
                                  <h1 style="margin: 0 0 12px 0; font-size: 20px; font-weight: 700; color: #09090b; letter-spacing: -0.4px;">Mã xác thực của bạn</h1>
                                  
                                  <p style="margin: 0 0 28px 0; font-size: 14px; line-height: 1.6; color: #52525b;">
                                    ${purpose === 'PROFILE_EMAIL'
                                        ? 'Sử dụng mã bên dưới để xác minh Gmail hiện có trong hồ sơ SmartStock. Mã này không dùng để đổi Gmail hoặc đặt lại mật khẩu.'
                                        : purpose === 'EMAIL_CHANGE_OLD'
                                            ? 'Bạn đang yêu cầu đổi Gmail của tài khoản SmartStock. Dùng mã này để xác nhận quyền sở hữu Gmail hiện tại. Nếu không phải bạn yêu cầu, không cung cấp mã và hãy kiểm tra bảo mật tài khoản.'
                                            : purpose === 'EMAIL_CHANGE_NEW'
                                                ? 'Dùng mã này để xác nhận Gmail mới cho tài khoản SmartStock. Gmail hiện tại chỉ được thay khi hoàn tất các bước xác nhận.'
                                        : 'Sử dụng mã OTP bên dưới để hoàn tất đăng ký hoặc khôi phục mật khẩu tài khoản SmartStock.'}
                                  </p>

                                  <!-- OTP Display Card -->
                                  <div style="background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 24px 16px; text-align: center; margin-bottom: 28px;">
                                    <div style="font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace; font-size: 34px; font-weight: 800; letter-spacing: 12px; color: #09090b; padding-left: 12px; line-height: 1;">
                                      ${otpCode}
                                    </div>
                                    <div style="margin-top: 14px; font-size: 12px; font-weight: 500; color: #64748b;">
                                      Hiệu lực trong <span style="color: #09090b; font-weight: 600;">5 phút</span> &bull; Không chia sẻ mã này
                                    </div>
                                  </div>

                                  <p style="margin: 0; font-size: 13px; line-height: 1.5; color: #71717a;">
                                    Nếu bạn không thực hiện yêu cầu này, vui lòng bỏ qua email. Tài khoản của bạn vẫn được bảo mật an toàn.
                                  </p>

                                </td>
                              </tr>

                              <!-- Footer -->
                              <tr>
                                <td style="background-color: #fafafa; padding: 20px 36px; border-top: 1px solid #f4f4f5; text-align: center;">
                                  <p style="margin: 0; font-size: 12px; color: #a1a1aa; line-height: 1.5;">
                                    SmartStock &bull; Bán hàng, Kho &amp; Thuế Hộ kinh doanh<br />
                                    Email tự động, xin vui lòng không phản hồi.
                                  </p>
                                </td>
                              </tr>
                            </table>
                          </td>
                        </tr>
                      </table>
                    </body>
                    </html>
                `,
            };

            return await this.deliver(email, mailOptions);
        } catch (error) {
            return this.deliveryError(error);
        }
    }

    async sendEmailChanged(email: string, destination: 'OLD' | 'NEW'): Promise<boolean> {
        if (!this.transporter) return false;
        try {
            return await this.deliver(email, {
                from: `"SmartStock" <${process.env.SMTP_USER}>`, to: email,
                subject: 'Gmail đăng nhập SmartStock đã được cập nhật',
                text: destination === 'OLD'
                    ? 'Gmail này không còn là địa chỉ đăng nhập và khôi phục của tài khoản SmartStock vừa thực hiện thay đổi. Nếu không phải bạn thực hiện, hãy liên hệ hỗ trợ và kiểm tra bảo mật tài khoản.'
                    : 'Gmail này đã được xác minh và trở thành địa chỉ đăng nhập, khôi phục của tài khoản SmartStock. Nếu tài khoản có liên kết Google, liên kết cũng đã chuyển sang Google tương ứng. Dữ liệu và quyền cửa hàng được giữ nguyên.',
            });
        } catch (error) {
            return this.deliveryError(error);
        }
    }

    private async deliver(email: string, mailOptions: nodemailer.SendMailOptions): Promise<boolean> {
            const result = await this.transporter!.sendMail(mailOptions);
            const recipient = email.trim().toLowerCase();
            const accepted = Array.isArray(result.accepted) ? result.accepted : [];
            const rejected = Array.isArray(result.rejected) ? result.rejected : [];
            const matchesRecipient = (value: string | { address?: string }) =>
                (typeof value === 'string' ? value : value.address)?.trim().toLowerCase() === recipient;
            const deliveredToSmtp = accepted.some(matchesRecipient)
                && !rejected.some(matchesRecipient);
            // SMTP acceptance is observable; delivery to the recipient's inbox is not.
            console.info('[Email Service] Delivery result', {
                outcome: deliveredToSmtp ? 'smtp_accepted' : 'smtp_not_accepted',
                acceptedCount: accepted.length,
                rejectedCount: rejected.length,
            });
            return deliveredToSmtp;
    }

    private deliveryError(error: unknown): false {
            const detail = error as { code?: unknown; responseCode?: unknown } | null;
            const allowedCodes = new Set([
                'EAUTH', 'ETIMEDOUT', 'ESOCKET', 'ECONNECTION', 'ECONNREFUSED',
                'EDNS', 'EENVELOPE', 'EMESSAGE', 'ESTREAM', 'ETLS',
            ]);
            const code = typeof detail?.code === 'string' && allowedCodes.has(detail.code)
                ? detail.code : 'UNKNOWN';
            const status = Number(detail?.responseCode);
            console.error('[Email Service] Delivery failed', {
                code,
                smtpStatus: Number.isInteger(status) && status >= 400 && status <= 599
                    ? status : null,
            });
            return false;
    }
}
