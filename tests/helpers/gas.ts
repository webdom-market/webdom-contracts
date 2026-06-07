import { Transaction, fromNano } from '@ton/core';
import { SendMessageResult } from '@ton/sandbox';

export type TxGas = {
    idx: number;
    from?: string;
    to?: string;
    op?: string;
    success: boolean;
    exitCode?: number;
    gasUsed: bigint;       // gas units consumed in compute phase
    gasFees: bigint;       // nanoTON paid for gas
    storageFees: bigint;   // nanoTON storage rent collected this tx
    fwdFees: bigint;       // nanoTON total forward fees of actions
    actionFees: bigint;    // nanoTON total action fees
    totalFees: bigint;     // nanoTON total fees charged to this account
    outMsgs: number;
};

function shortAddr(a: any): string | undefined {
    try {
        return a ? a.toString().slice(0, 6) + '…' + a.toString().slice(-4) : undefined;
    } catch {
        return undefined;
    }
}

function readOp(tx: Transaction): string | undefined {
    try {
        const body = tx.inMessage?.body;
        if (!body) return undefined;
        const s = body.beginParse();
        if (s.remainingBits < 32) return 'empty';
        const op = s.loadUint(32);
        return '0x' + op.toString(16).padStart(8, '0');
    } catch {
        return undefined;
    }
}

export function txGas(tx: Transaction, idx: number): TxGas {
    const d: any = tx.description;
    const compute = d.computePhase;
    const isVm = compute && compute.type === 'vm';
    const storage = d.storagePhase;
    const action = d.action;
    return {
        idx,
        from: shortAddr(tx.inMessage?.info?.src),
        to: shortAddr(tx.inMessage?.info?.dest),
        op: readOp(tx),
        success: isVm ? compute.success : false,
        exitCode: isVm ? compute.exitCode : undefined,
        gasUsed: isVm ? compute.gasUsed : 0n,
        gasFees: isVm ? compute.gasFees : 0n,
        storageFees: storage?.storageFeesCollected ?? 0n,
        fwdFees: action?.totalFwdFees ?? 0n,
        actionFees: action?.totalActionFees ?? 0n,
        totalFees: tx.totalFees.coins,
        outMsgs: tx.outMessagesCount,
    };
}

export function collectGas(res: SendMessageResult): TxGas[] {
    return res.transactions.map((t, i) => txGas(t as Transaction, i));
}

/** Derive the basechain gas price (nanoTON per gas unit) empirically from any compute-heavy tx. */
export function deriveGasPrice(res: SendMessageResult): number | undefined {
    for (const t of res.transactions) {
        const d: any = (t as Transaction).description;
        const c = d.computePhase;
        if (c && c.type === 'vm' && c.gasUsed > 0n) {
            return Number(c.gasFees) / Number(c.gasUsed);
        }
    }
    return undefined;
}

const pad = (s: string, n: number) => s.padEnd(n);
const padL = (s: string, n: number) => s.padStart(n);

/** Write without jest's per-line source-location annotation. */
export function log(s: string = '') {
    process.stdout.write(s + '\n');
}

export function printGas(title: string, res: SendMessageResult) {
    const rows = collectGas(res);
    const lines: string[] = [];
    lines.push('\n=== ' + title + ' ===');
    lines.push(
        pad('#', 3) + pad('op', 12) + pad('from→to', 16) +
        padL('gasUsed', 9) + padL('gasFee', 12) + padL('storage', 12) +
        padL('fwdFee', 12) + padL('totalFee', 13) + '  ok',
    );
    for (const r of rows) {
        lines.push(
            pad(String(r.idx), 3) +
            pad(r.op ?? '-', 12) +
            pad(((r.from ?? '?') + '→' + (r.to ?? '?')).slice(0, 15), 16) +
            padL(String(r.gasUsed), 9) +
            padL(fromNano(r.gasFees), 12) +
            padL(fromNano(r.storageFees), 12) +
            padL(fromNano(r.fwdFees), 12) +
            padL(fromNano(r.totalFees), 13) +
            '  ' + (r.success ? '✓' : '✗' + (r.exitCode !== undefined ? r.exitCode : '')),
        );
    }
    const totGas = rows.reduce((a, r) => a + r.gasUsed, 0n);
    const totFees = rows.reduce((a, r) => a + r.totalFees, 0n);
    const totFwd = rows.reduce((a, r) => a + r.fwdFees, 0n);
    lines.push(
        `   Σ gasUsed=${totGas}  Σ fwdFees=${fromNano(totFwd)}  Σ totalFees=${fromNano(totFees)} TON`,
    );
    log(lines.join('\n'));
    return rows;
}

/** Sum of gasUsed across all txs in the chain. */
export function totalGasUsed(res: SendMessageResult): bigint {
    return collectGas(res).reduce((a, r) => a + r.gasUsed, 0n);
}

/** Sum of all validator-collected fees (gas + storage + action fwd) across the chain, in nanoTON. */
export function totalNetworkFees(res: SendMessageResult): bigint {
    return collectGas(res).reduce((a, r) => a + r.totalFees, 0n);
}
