export type PurchasePaymentInstallment = {
  date: Date;
  amount: number;
};

const DAY_MS = 24 * 60 * 60 * 1000;
const INSTALLMENT_RATIOS = [0.16, 0.17, 0.15, 0.18, 0.17, 0.17] as const;

/**
 * Spread a supplier payment over a few nearby business days so a generated
 * cash-flow chart reflects normal settlement behaviour instead of one large
 * artificial spike on every replenishment day.
 */
export function buildPurchasePaymentSchedule(
  anchorDate: Date,
  total: number,
  lastAllowedDate: Date,
  roundMoney: (value: number) => number,
): PurchasePaymentInstallment[] {
  if (!Number.isFinite(total) || total <= 0) return [];

  const availableDays = Math.max(
    0,
    Math.floor((lastAllowedDate.getTime() - anchorDate.getTime()) / DAY_MS),
  );
  const installmentCount = Math.min(
    INSTALLMENT_RATIOS.length,
    availableDays + 1,
  );
  const selectedRatios = INSTALLMENT_RATIOS.slice(0, installmentCount);
  const selectedRatioTotal = selectedRatios.reduce(
    (sum, ratio) => sum + ratio,
    0,
  );
  let remaining = roundMoney(total);
  return selectedRatios.map((ratio, index) => {
    const amount = index === selectedRatios.length - 1
      ? remaining
      : Math.min(
          remaining,
          roundMoney(total * (ratio / selectedRatioTotal)),
        );
    remaining = roundMoney(remaining - amount);
    return {
      date: new Date(anchorDate.getTime() + index * DAY_MS),
      amount,
    };
  }).filter((installment) => installment.amount > 0);
}
