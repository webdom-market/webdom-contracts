import { readFileSync } from 'fs';
import { Cell } from '@ton/core';

export function getDeployFunctionCode(filename: string): Cell {
    const path = `deploy_functions_compiled/${filename}.boc`;
    const boc = readFileSync(path);
    return Cell.fromBoc(boc)[0];
}
