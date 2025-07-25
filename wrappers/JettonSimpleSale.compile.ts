import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'func',
    targets: ['contracts/fix_price_sales/jetton_simple_sale.fc'],
};
