export function jettonsToString(jettons: number | bigint, decimals: number): string {
    jettons = BigInt(jettons);
    const intPart = jettons / (10n ** BigInt(decimals));
    let decPart = jettons - intPart * (10n ** BigInt(decimals));
    if (decPart == 0n) {
        return intPart.toString();
    }

    let maxDecPart = (intPart > 0n) ? (10000n / intPart) : 10000n;
    let zeros = 0;
    let tmp = 10n ** BigInt(decimals) / (decPart + 1n);
    while (tmp >= 10n) {
        tmp /= 10n;
        maxDecPart /= 10n;
        zeros += 1;
    }
    if (maxDecPart == 0n) {
        return intPart.toString();
    }
    while (decPart > maxDecPart) {
        decPart /= 10n;
    }
    if (decPart) {
        while (decPart % 10n == 0n) {
            decPart /= 10n;
        } 
        let res = intPart.toString() + '.' + '0'.repeat(zeros) + decPart.toString();
        while (res.includes('.') && (res.at(-1) == '0' || res.at(-1) == '.')) {
            res = res.slice(0, res.length - 1);
        }
        return res;
    }
    return intPart.toString();
}