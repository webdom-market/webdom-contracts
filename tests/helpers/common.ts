import { readFileSync } from 'fs';
import { Cell } from '@ton/core';
import { Blockchain } from '@ton/sandbox';
import { runTolkCompiler } from '@ton/tolk-js';
import { TestConts } from '../../wrappers/DeployFunctions';

/** Builds a continuation with the current test constants without rewriting sources or shipped BOCs. */
export async function compileDeployFunctionCode(name: string): Promise<Cell> {
    const { compile: config } = await import(`../../wrappers/${name}.compile`);
    const directory = (config.entrypoint as string).replace(/^contracts\//, '').replace(/\/contract\.tolk$/, '');
    const entrypoint = 'contracts/deploy_function_test.tolk';
    async function compileSource(source: string) {
        const result = await runTolkCompiler({
            entrypointFileName: entrypoint,
            fsReadCallback(filename) {
                if (filename === entrypoint) return source;
                return readFileSync(filename, 'utf8');
            },
            withStackComments: true,
            withSrcLineComments: true,
        });
        if (result.status === 'error') throw new Error(result.message);
        return result;
    }
    const result = await compileSource(`import "${directory}/deploy_function.tolk";
fun onInternalMessage(): void {}
get fun keepDeployFunction(): int { val keep = deploy${name}; return 0; }`);
    const lines = result.fiftCode.split('\n');
    let helper = '';
    let main = '';
    let program = false;
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.trim() === 'PROGRAM{') { program = true; continue; }
        if (line.trim() === '}END>c') break;
        if (!program || !line.trim() || line.trim().startsWith('//') || line.includes('DECLMETHOD') || line.includes(`DECLPROC deploy${name}`)) continue;
        if (line.includes(`deploy${name}() PROC:<{`)) {
            let balance = 1;
            main = line.slice(line.indexOf('PROC:<{') + 7) + '\n';
            while (++i < lines.length && balance > 0) {
                const current = lines[i];
                for (const ch of current.split('//')[0]) { if (ch === '{') balance++; if (ch === '}') balance--; }
                main += current + '\n';
            }
            main = main.replace(/\s*}>\s*$/, '');
            break;
        }
        helper += line + '\n';
    }
    if (!main.trim()) throw new Error('No deployment function extracted');
    const assembled = await compileSource(`fun deployFunctionCell(): cell asm """<{ ${helper}\n${main}\n}>c PUSHREF""";
fun onInternalMessage(): void {}
get fun getDeployFunctionCell(): cell { return deployFunctionCell(); }`);
    const bc = await Blockchain.create();
    const sender = await bc.treasury('continuation-assembler');
    const contract = bc.openContract(TestConts.create(Cell.fromBase64(assembled.codeBoc64)));
    await contract.sendDeploy(sender.getSender(), 1000000000n);
    return Cell.fromHex(await contract.getDeployFunctionCell());
}

export function abs(x: bigint) {
    return x < 0n ? -x : x;
}

export function min(a: bigint, b: bigint) {
    return a < b ? a : b;
}

export function max(a: bigint, b: bigint) {
    return a > b ? a : b;
}
