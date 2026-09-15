#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '..');
const RUNNER_SCRIPT = path.join(PROJECT_ROOT, '.agents', 'antigravity', 'runner.mjs');
const TEST_RUNS_BASE = path.join(PROJECT_ROOT, 'BA_DOCUMENTS', 'TEST_RUNS');
const RUN_ID_REGEX = /^[a-f0-9]{16}$/;

function printHelp() {
  process.stdout.write(`Usage:
  node scripts/antigravity-test.mjs [prepare]
  node scripts/antigravity-test.mjs run
  node scripts/antigravity-test.mjs resume --run <16_hex_run_id>
  node scripts/antigravity-test.mjs --help

Commands:
  prepare (default)   Generate a timestamped visual audit plan under BA_DOCUMENTS/TEST_RUNS and print its path.
  run                 Generate audit plan and invoke runner.mjs via spawn({shell:false, stdio:'inherit'}).
  resume              Generate a continuation plan and invoke runner.mjs resume for the given run ID.
  --help, -h          Display this help message with no filesystem changes (must be used alone).

Notes:
  - This wrapper operates only within an active interactive session; it is not a background daemon.
  - Runner exit code 0 indicates runner CLI execution completion only, not a test PASS verdict.
  - Codex must independently inspect generated screenshots, report.md, and results.json before issuing a verdict.
`);
}

function parseCliArgs(rawArgs) {
  // Lone help flag check: only accepted when alone
  if (rawArgs.length === 1 && (rawArgs[0] === '--help' || rawArgs[0] === '-h' || rawArgs[0] === 'help')) {
    return { command: 'help' };
  }

  if (rawArgs.includes('--help') || rawArgs.includes('-h') || rawArgs.includes('help')) {
    throw new Error('The help flag (--help, -h) must be used alone without other commands or arguments.');
  }

  if (rawArgs.length === 0 || (rawArgs.length === 1 && rawArgs[0] === 'prepare')) {
    return { command: 'prepare' };
  }

  if (rawArgs.length === 1 && rawArgs[0] === 'run') {
    return { command: 'run' };
  }

  if (rawArgs[0] === 'resume') {
    if (rawArgs.length !== 3 || rawArgs[1] !== '--run') {
      throw new Error('resume command requires exactly: --run <16_hex_run_id>');
    }
    const runId = rawArgs[2];
    if (!RUN_ID_REGEX.test(runId)) {
      throw new Error('Run ID must be exactly 16 lowercase hexadecimal characters.');
    }
    return { command: 'resume', runId };
  }

  throw new Error(`Unknown or invalid arguments: ${rawArgs.join(' ')}. Use --help for usage.`);
}

function getTimestamp() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const year = now.getFullYear();
  const month = pad(now.getMonth() + 1);
  const day = pad(now.getDate());
  const hours = pad(now.getHours());
  const minutes = pad(now.getMinutes());
  const seconds = pad(now.getSeconds());
  return `${year}${month}${day}_${hours}${minutes}${seconds}`;
}

function buildAuditPlanBody({ runFolder, timestamp, previousRunId = null }) {
  const isResume = Boolean(previousRunId);
  const runFolderJson = JSON.stringify(runFolder);
  const sampleJson = `{
  "runFolder": ${runFolderJson},
  "timestamp": "${timestamp}",
  "overallStatus": "BLOCKED",
  "summary": {
    "total": 12,
    "pass": 9,
    "fail": 0,
    "blocked": 3,
    "notTested": 0
  },
  "cases": [
    {
      "id": "TC-AUTH-LOGIN-390",
      "route": "/#/login",
      "actualUrl": "https://smartstock-tax.vercel.app/#/login",
      "viewport": "390x844",
      "capturedAt": "${new Date().toISOString()}",
      "status": "PASS",
      "expected": "Login form rendered with mobile density without overflow",
      "actual": "Form rendered completely, no clipping or overflow observed",
      "repro": "Navigate to https://smartstock-tax.vercel.app/#/login at 390x844",
      "screenshot": "screenshots/TC-AUTH-LOGIN-390.png",
      "issues": []
    },
    {
      "id": "TC-DASH-390",
      "route": "/#/",
      "actualUrl": "https://smartstock-tax.vercel.app/#/login",
      "viewport": "390x844",
      "capturedAt": "${new Date().toISOString()}",
      "status": "BLOCKED",
      "expected": "Dashboard metrics rendered",
      "actual": "Redirected to /#/login due to unauthenticated session",
      "repro": "Navigate to https://smartstock-tax.vercel.app/#/ at 390x844 without auth session",
      "screenshot": "screenshots/TC-DASH-390.png",
      "issues": [
        {
          "severity": "MEDIUM",
          "description": "Dashboard blocked: requires authenticated test session; read-only plan prevents credential injection"
        }
      ]
    }
  ],
  "coverageGaps": [
    "Dashboard interactive metrics and shell navigation blocked by authentication gate",
    "Form submission and auth mutations not tested (read-only audit)"
  ]
}`;

  return `# Production Read-Only Visual Audit Plan: Auth & Dashboard${isResume ? ` (Continuation of Run ${previousRunId})` : ''}
Generated At: ${new Date().toISOString()}
Run Directory: ${runFolder}
Target Environment: Production https://smartstock-tax.vercel.app/
${isResume ? `Previous Run Context: Resuming investigation and corrective actions for Run ID: ${previousRunId}\n` : ''}
## 1. Mục tiêu & Phạm vi (Scope)
Thực hiện kiểm toán trực quan chỉ đọc (read-only visual audit) trên môi trường production của hệ thống SmartStock.
- Khám phá route thực tế từ router nguồn: Executor PHẢI đối chiếu lại mã nguồn \`lib/core/router/app_router.dart\` trước khi điều hướng trong mỗi phiên kiểm thử.
- URLs sử dụng định dạng Flutter hash routing (\`/#/route\`):
  - \`/#/login\`: Màn hình đăng nhập (LoginScreen)
  - \`/#/register\`: Màn hình đăng ký (RegisterScreen)
  - \`/#/forgot-password\`: Màn hình quên mật khẩu (ForgotPasswordScreen)
  - \`/#/\`: Màn hình Dashboard (DashboardScreen trong MainShell; unauthenticated access redirects to \`/#/login\`)
- Ma trận Viewport bắt buộc:
  - Mobile: 390x844
  - Tablet: 768x1024
  - Desktop: 1440x900

## 2. Giới hạn công cụ & An toàn bảo mật (Security & Tool Restrictions)
- CHỈ ĐƯỢC PHÉP dùng các công cụ MCP Playwright sau:
  - \`browser_navigate\`
  - \`browser_snapshot\`
  - \`browser_resize\`
  - \`browser_take_screenshot\`
- TUYỆT ĐỐI KHÔNG cấp quyền và KHÔNG sử dụng:
  - \`browser_click\`, \`browser_type\`, \`browser_evaluate\`
  - Lệnh shell hoặc command execution trên hệ thống
- TUYỆT ĐỐI KHÔNG đọc bí mật, credentials, tokens, hay tệp \`.env\`.
- TUYỆT ĐỐI KHÔNG tạo tài khoản mới, KHÔNG yêu cầu OTP, KHÔNG gửi email, KHÔNG thực hiện thao tác ghi/sửa dữ liệu trên production.
- Mọi kiểm thử chức năng cần đột biến dữ liệu (mutations) thuộc về môi trường local/test và phải có nhiệm vụ phê duyệt riêng.

## 3. Xử lý trạng thái Dashboard & Chặn đăng nhập (Auth Blocker Rule)
- Theo logic \`app_router.dart\`, truy cập \`/#/\` khi chưa đăng nhập sẽ tự động redirect về \`/#/login\`.
- Nếu chưa có phiên đăng nhập hợp lệ:
  - Điều hướng tới \`/#/\`, ghi nhận hành vi redirect về \`/#/login\`.
  - Chụp ảnh màn hình kết quả tại các kích thước viewport quy định.
  - Đánh dấu trạng thái của Dashboard là **BLOCKED** (TUYỆT ĐỐI KHÔNG ĐƯỢC ĐÁNH DẤU LÀ PASS).
  - TUYỆT ĐỐI KHÔNG thử lại (retry) đăng nhập khi đã bị chặn. Dừng ngay tại rào cản thực tế.

## 4. Quy chuẩn bằng chứng & Chụp màn hình (Evidence Quality Gates)
- Thư mục lưu trữ ảnh chụp:
  \`${runFolder}/screenshots/\`
- Yêu cầu ảnh chụp màn hình:
  - Phải chụp khi giao diện đã kết xuất hoàn tất (actual rendered screen), KHÔNG chụp màn hình splash hoặc loading spinner.
  - Sử dụng chế độ fullPage khi chụp màn hình.
  - Lưu ý kiến trúc Flutter Web: Flutter kết xuất trên canvas (CanvasKit/HTML), nội dung chụp có thể bị giới hạn trong viewport canvas. Không tự nhận là đã bắt trọn vẹn toàn bộ nội dung cuộn nếu thực tế chỉ chụp trong viewport của canvas.
  - Ghi nhận đầy đủ: Tên file ảnh, viewport, URL thực tế (\`actualUrl\`), thời điểm chụp (\`capturedAt\`), bước tái hiện (\`repro\`).
- Tiêu chí kiểm tra trực quan chi tiết:
  1. Chart/table clipping: kiểm tra biểu đồ hoặc bảng biểu có bị tràn lề, cắt xén nhãn trục, mất chữ hay không.
  2. KPI density: khoảng cách, độ giãn cách và độ rõ của các thẻ KPI trên màn hình nhỏ (đặc biệt 390x844).
  3. Equal edges of paired cards: kiểm tra độ cao và căn lề mép bằng nhau của các cặp thẻ dữ liệu cùng hàng (Lưu ý: hình minh họa auth illustration và khung đăng nhập là thiết kế bất đối xứng có chủ đích, không áp dụng quy tắc này).
  4. Large monetary values: định dạng số tiền lớn (VND), phân cách hàng nghìn, không đè chữ hoặc hiển thị lỗi overflow.
  5. Loading/empty/error states: CHỈ lập hồ sơ nếu THỰC TẾ quan sát thấy trong phiên kiểm tra. Nếu không xuất hiện, ghi nhận rõ là **NOT_TESTED**. Không suy đoán.

## 5. Danh sách ca kiểm thử (Test Matrix)
| Case ID | Route | Viewport | Expected Result | Mandatory |
|---|---|---|---|---|
| TC-AUTH-LOGIN-390 | /#/login | 390x844 | Form đăng nhập hiển thị đầy đủ, không tràn màn hình | Yes |
| TC-AUTH-LOGIN-768 | /#/login | 768x1024 | Giao diện tablet hiển thị cân đối, rõ ràng | Yes |
| TC-AUTH-LOGIN-1440 | /#/login | 1440x900 | Layout desktop hiển thị thẻ form và ảnh minh họa | Yes |
| TC-AUTH-REG-390 | /#/register | 390x844 | Form đăng ký hiển thị đầy đủ trên mobile | Yes |
| TC-AUTH-REG-768 | /#/register | 768x1024 | Form đăng ký cân đối trên tablet | Yes |
| TC-AUTH-REG-1440 | /#/register | 1440x900 | Layout đăng ký desktop chuẩn | Yes |
| TC-AUTH-FORGOT-390 | /#/forgot-password | 390x844 | Form quên mật khẩu hiển thị chuẩn trên mobile | Yes |
| TC-AUTH-FORGOT-768 | /#/forgot-password | 768x1024 | Form quên mật khẩu hiển thị chuẩn trên tablet | Yes |
| TC-AUTH-FORGOT-1440 | /#/forgot-password | 1440x900 | Form quên mật khẩu hiển thị chuẩn trên desktop | Yes |
| TC-DASH-390 | /#/ | 390x844 | Truy cập Dashboard; nếu chưa đăng nhập -> redirect /#/login -> BLOCKED | Yes |
| TC-DASH-768 | /#/ | 768x1024 | Truy cập Dashboard; nếu chưa đăng nhập -> redirect /#/login -> BLOCKED | Yes |
| TC-DASH-1440 | /#/ | 1440x900 | Truy cập Dashboard; nếu chưa đăng nhập -> redirect /#/login -> BLOCKED | Yes |

## 6. Sản phẩm bàn giao bắt buộc (Deliverables in Run Folder)
Trong thư mục \`${runFolder}\`, executor phải tạo:
1. \`report.md\`:
   - Bảng tổng hợp từng ca kiểm thử: ID, Route, Viewport, Status (PASS | FAIL | BLOCKED | NOT_TESTED), URL thực tế (\`actualUrl\`), kết quả mong đợi, kết quả thực tế, bước tái hiện (\`repro\`), thời điểm chụp (\`capturedAt\`), đường dẫn ảnh chụp.
   - Bảng danh sách vấn đề (Issues) kèm mức độ nghiêm trọng: CRITICAL | HIGH | MEDIUM | LOW.
   - Mục Khoảng trống bao phủ (Coverage Gaps): nêu rõ các luồng chức năng auth/dashboard chưa được kiểm tra do kế hoạch chỉ đọc.
2. \`results.json\`:
   - Định dạng cấu trúc máy đọc chuẩn:
\`\`\`json
${sampleJson}
\`\`\`
   - Quy tắc xác định overallStatus:
     - **BLOCKED**: Nếu có bất kỳ ca kiểm thử bắt buộc nào bị **BLOCKED** hoặc **NOT_TESTED** (ca bắt buộc chưa được kiểm thử trọn vẹn đồng nghĩa với trạng thái bị chặn/chưa hoàn thành, TUYỆT ĐỐI KHÔNG ĐƯỢC ĐÁNH DẤU LÀ PASS).
     - **FAIL**: Nếu có ca kiểm thử thất bại và không có ca nào bị chặn.
     - **PASS**: CHỈ KHI TẤT CẢ các ca kiểm thử bắt buộc đều đạt **PASS**.

## 7. Phân vai, Bản chất điều phối & Quy trình duyệt (Review & Approval Rules)
- Runner exit code 0 chỉ biểu thị tiến trình CLI hoàn tất việc thực thi lệnh kỹ thuật, TUYỆT ĐỐI KHÔNG mang ý nghĩa kiểm thử đạt (PASS).
- Executor (Antigravity) TUYỆT ĐỐI KHÔNG tự cấp quyền duyệt hoàn thành (No final approval from executor).
- Wrapper này không tự triển khai một Codex agent hay background daemon độc lập, mà chỉ đóng vai trò kích hoạt (dispatch) và tiếp tục (resume) tác vụ kiểm thử trong phiên làm việc đang hoạt động (active session).
- Codex là bên duy nhất xem xét ảnh chụp thực tế, diff và nhật ký thực thi.
- Codex lưu đánh giá riêng tại \`review.json\` và \`review.md\` kèm phương án sửa lỗi chi tiết.
- TUYỆT ĐỐI KHÔNG tự động deploy (no auto-deploy) như một phần của quy trình kiểm thử này.
- Không thử lại vô tận (no endless retries). Dừng lại ngay khi gặp blocker.
`;
}

async function preparePlan() {
  const timestamp = getTimestamp();
  await fs.mkdir(TEST_RUNS_BASE, { recursive: true });
  const runFolder = await fs.mkdtemp(path.join(TEST_RUNS_BASE, `run_${timestamp}_`));
  const planPath = path.join(runFolder, 'audit_plan.md');
  const planContent = buildAuditPlanBody({ runFolder, timestamp });
  await fs.writeFile(planPath, planContent, 'utf8');
  process.stdout.write(`${planPath}\n`);
  return { runFolder, planPath };
}

async function prepareResume(runId) {
  const timestamp = getTimestamp();
  await fs.mkdir(TEST_RUNS_BASE, { recursive: true });
  const runFolder = await fs.mkdtemp(path.join(TEST_RUNS_BASE, `resume_${runId}_${timestamp}_`));
  const planPath = path.join(runFolder, 'continuation_plan.md');
  const planContent = buildAuditPlanBody({ runFolder, timestamp, previousRunId: runId });
  await fs.writeFile(planPath, planContent, 'utf8');
  process.stdout.write(`${planPath}\n`);
  return { runFolder, planPath };
}

function runChild(executable, args, cwd) {
  return new Promise((resolve) => {
    const child = spawn(executable, args, {
      cwd,
      shell: false,
      stdio: 'inherit',
    });

    child.on('error', (err) => {
      process.stderr.write(`Failed to start child process: ${err.message}\n`);
      resolve(1);
    });

    child.on('close', (code, signal) => {
      if (code !== null) {
        resolve(code);
      } else if (signal) {
        resolve(1);
      } else {
        resolve(0);
      }
    });
  });
}

async function main() {
  const rawArgs = process.argv.slice(2);
  let parsed;

  try {
    parsed = parseCliArgs(rawArgs);
  } catch (error) {
    process.stderr.write(`Error: ${error.message}\n`);
    process.exitCode = 1;
    return;
  }

  if (parsed.command === 'help') {
    printHelp();
    process.exitCode = 0;
    return;
  }

  if (parsed.command === 'prepare') {
    await preparePlan();
    process.exitCode = 0;
    return;
  }

  if (parsed.command === 'run') {
    const { planPath } = await preparePlan();
    const exitCode = await runChild(process.execPath, [RUNNER_SCRIPT, 'run', '--plan', planPath], PROJECT_ROOT);
    process.exitCode = exitCode;
    return;
  }

  if (parsed.command === 'resume') {
    const { planPath } = await prepareResume(parsed.runId);
    const exitCode = await runChild(
      process.execPath,
      [RUNNER_SCRIPT, 'resume', '--run', parsed.runId, '--feedback', planPath],
      PROJECT_ROOT
    );
    process.exitCode = exitCode;
    return;
  }
}

main().catch((err) => {
  process.stderr.write(`Unexpected error: ${err.message}\n`);
  process.exitCode = 1;
});
