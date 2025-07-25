import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'func',
    targets: ['contracts/fix_price_sales/ton_multiple_sale.fc'],
};
