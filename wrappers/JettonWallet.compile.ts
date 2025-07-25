import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'func',
    targets: ['contracts/simple_jetton_contracts/jetton-wallet.func'],
};
