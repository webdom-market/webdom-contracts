export function abs(x: bigint) {
    return x < 0n ? -x : x;
}

export function min(a: bigint, b: bigint) {
    return a < b ? a : b;
}

export function max(a: bigint, b: bigint) {
    return a > b ? a : b;
}
