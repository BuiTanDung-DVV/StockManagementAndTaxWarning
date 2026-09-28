export const AI_REQUEST_TIMEOUT_MS = 45000;
export const AI_TIMEOUT_MESSAGE = 'Trợ lý AI phản hồi quá lâu. Vui lòng gửi lại câu hỏi.';

export async function withAiDeadline<T>(
  work: (remainingMs: () => number) => Promise<T>,
  timeoutMs = AI_REQUEST_TIMEOUT_MS,
): Promise<T> {
  const deadline = Date.now() + timeoutMs;
  const remainingMs = () => {
    const remaining = deadline - Date.now();
    if (remaining <= 0) throw new Error(AI_TIMEOUT_MESSAGE);
    return remaining;
  };
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      Promise.resolve().then(() => work(remainingMs)),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error(AI_TIMEOUT_MESSAGE)), timeoutMs);
      }),
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}
