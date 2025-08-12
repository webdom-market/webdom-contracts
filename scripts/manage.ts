/* eslint-disable no-console */
import { spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';

// Try to load .env if available. If not installed, continue gracefully.
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  require('dotenv').config();
} catch (_) {
  // dotenv is optional; environment can be provided by the shell
}

type Action = 'build' | 'test' | 'run' | 'get_deploy_functions';

const WORKSPACE_ROOT = process.cwd();
const CONSTANTS_FILE_RELATIVE = 'contracts/imports/constants.tolk';
const CONSTANTS_FILE = path.join(WORKSPACE_ROOT, CONSTANTS_FILE_RELATIVE);

const CONTRACTS: string[] = [
  'TonSimpleSale',
  'Jett_onSimpleSale',
  'TonMultipleSale',
  'Jett_onMultipleSale',
  'DomainSwap',
  'TonSimpleAuction',
  'Jett_onSimpleAuction',
  'TonMultipleAuction',
  'Jett_onMultipleAuction',
  'TonSimpleOffer',
  'Jett_onSimpleOffer',
  'Marketplace',
  'MultipleOffer',
];

// Replacement tuples must include surrounding quotes to match the Python script behavior
const REPLACES_TESTS: Array<[string, string]> = [
  ['"MARKETPLACE_ADDRESS"', '"EQAX21A4fIw7hX1jmRjvJT0DX7H_FUItj2duCBWtK4ayEiC_"'],
  ['"ADMIN_ADDRESS"', '"EQAX21A4fIw7hX1jmRjvJT0DX7H_FUItj2duCBWtK4ayEiC_"'],
  ['"TON_DNS_ADDRESS"', '"EQCTN6fMuBiue-NUT7EkYU128cYLbDuaH4egFmmc_bCKaMHK"'],
  ['"WEB3_ADDRESS"', '"EQBefYnZpKZTyviz9KYpMgWTnzJbwRTQrtzJVCJxN5qNdLJM"'],
  ['"USDT_ADDRESS"', '"EQCmj3-TgcVq-mCOwFMG7Z7OKkLdJxQTdPU11St93_oIzRaU"'],
  ['"TON_VAULT_ADDRESS"', '"EQDshQ2nyhezZleRdlZT12pvrj_cYp9XGmcRgYirA71DWugR"'],
  ['"USDT_VAULT_ADDRESS"', '"EQAtwRp7c0vR82jID5S2c34HleVxaiYjJBgMvFgdeXIkPjjm"'],
  ['"WEB3_VAULT_ADDRESS"', '"EQByrIjpJYer4sxHzKb12sxVfYIZ358RFHdAdfY2SEr3P-EX"'],
  ['"USDT_TON_POOL_ADDRESS"', '"EQBJyOz6bLTrI-QWQbmmnC5vFZOj-CN8VTIr-EIt8dnR9ZBC"'],
  ['"WEB3_TON_POOL_ADDRESS"', '"EQBHKpZrJdpABx0kCFGQ201Aix_9GviqOXoyBpvvTRc_r9-j"'],
  ['"WEB3_USDT_POOL_ADDRESS"', '"EQAYSAN3tEDQre7rUVik6cczd5gcxqyVdpi3JHvu4mrr3326"'],
  ['"USERNAMES_COLLECTION_ADDRESS"', '"EQA6SpQ_qolLTMwe3pSVllchLRMs8AOmYwb-DxG3eZD9Qk0c"'],
];

const REPLACES_ONCHAIN_TESTNET: Array<[string, string]> = [
  ['"MARKETPLACE_ADDRESS"', `"${process.env.MARKETPLACE_ADDRESS_TESTNET ?? ''}"`],
  ['"ADMIN_ADDRESS"', `"${process.env.ADMIN_ADDRESS_TESTNET ?? ''}"`],
  ['"TON_DNS_ADDRESS"', '"EQC3dNlesgVD8YbAazcauIrXBPfiVhMMr5YYk2in0Mtsz0Bz"'],
  ['"WEB3_ADDRESS"', '"kQAAsaFsxbeo6paoe9fNCMwRApFR9LIsyGM8bGy4B53DlN_W"'],
  ['"USDT_ADDRESS"', '"kQAke45nLBq-0fO-Vaxl8NwNwKibNtr7SheU0xqB4JTKexSm"'],
  ['"TON_VAULT_ADDRESS"', '"kQDshQ2nyhezZleRdlZT12pvrj_cYp9XGmcRgYirA71DWlOb"'],
  ['"USDT_VAULT_ADDRESS"', '"kQCYNvxl8U0kBV4SdtAI1Fc6ekN2oOJyl4fGtXUYsnJQRrps"'],
  ['"WEB3_VAULT_ADDRESS"', '"kQBhDY5O1rzLL9xbDDR8kpZDSsFSMVWfkBcfjJLTmF9pNyur"'],
  ['"USDT_TON_POOL_ADDRESS"', '"kQD5NnXlulLDVWM_ICHETwOQJJDfRH3XWjGXLT8TDXja4DgF"'],
  ['"WEB3_TON_POOL_ADDRESS"', '"kQDJGTmBoTCM5CZa4lKpVmSDwCDRVxzL7kP_arFWNFaXeSgr"'],
  ['"WEB3_USDT_POOL_ADDRESS"', '"kQC8xi6NzgtJGVmWks3RnBBbJhb7MtAcukMFwtCoAWzFja8D"'],
  ['"USERNAMES_COLLECTION_ADDRESS"', '"EQCA14o1-VWhS2efqoh_9M1b_A9DtKTuoqfmkn83AbJzwnPi"'],
];

const REPLACES_ONCHAIN_MAINNET: Array<[string, string]> = [
  ['"MARKETPLACE_ADDRESS"', `"${process.env.MARKETPLACE_ADDRESS ?? ''}"`],
  ['"ADMIN_ADDRESS"', `"${process.env.ADMIN_ADDRESS ?? ''}"`],
  ['"TON_DNS_ADDRESS"', '"EQC3dNlesgVD8YbAazcauIrXBPfiVhMMr5YYk2in0Mtsz0Bz"'],
  ['"WEB3_ADDRESS"', '"EQBtcL4JA-PdPiUkB8utHcqdaftmUSTqdL8Z1EeXePLti_nK"'],
  ['"USDT_ADDRESS"', '"EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"'],
  ['"TON_VAULT_ADDRESS"', '"EQDa4VOnTYlLvDJ0gZjNYm5PXfSmmtL6Vs6A_CZEtXCNICq_"'],
  ['"USDT_VAULT_ADDRESS"', '"EQAYqo4u7VF0fa4DPAebk4g9lBytj2VFny7pzXR0trjtXQaO"'],
  ['"WEB3_VAULT_ADDRESS"', '"EQA_Au61onx7O5q1C2Q92S2bMaEL5v96HAYH4fjms1NIERVE"'],
  ['"USDT_TON_POOL_ADDRESS"', '"EQA-X_yo3fzzbDbJ_0bzFWKqtRuZFIRa1sJsveZJ1YpViO3r"'],
  ['"WEB3_TON_POOL_ADDRESS"', '"EQBTzDJyEgoXm88EkVTciyyZBfQYI-8OfOEDZphfHaQcoY8V"'],
  ['"WEB3_USDT_POOL_ADDRESS"', '"EQBJe_ykU9KEvg3c2kDyxGykbJoNCCMLQ6dJjaONDUfDgEL8"'],
  ['"USERNAMES_COLLECTION_ADDRESS"', '"EQCA14o1-VWhS2efqoh_9M1b_A9DtKTuoqfmkn83AbJzwnPi"'],
];

function readFile(filePath: string): string {
  return fs.readFileSync(filePath, 'utf-8');
}

function writeFile(filePath: string, content: string) {
  fs.writeFileSync(filePath, content);
}

function prepareConstantsFile(replaces: Array<[string, string]>): string {
  const originalContent = readFile(CONSTANTS_FILE);
  let newContent = originalContent;
  for (const [from, to] of replaces) {
    newContent = newContent.split(from).join(to);
  }
  writeFile(CONSTANTS_FILE, newContent);
  return originalContent;
}

function rollBackConstantsFile(originalContent: string) {
  writeFile(CONSTANTS_FILE, originalContent);
}

function runCommand(command: string, args: string[]): number {
  const res = spawnSync(command, args, { stdio: 'inherit' });
  return res.status ?? 1;
}

function blueprint(args: string[]): number {
  return runCommand('npx', ['blueprint', ...args]);
}

function getDeployFunctionCode(target: string): number {
  return runCommand('npx', ['ts-node', 'scripts/getDeployFunctionCode.ts', target]);
}

function withMarketplaceWeb3Override(replaces: Array<[string, string]>): Array<[string, string]> {
  const next = [...replaces];
  // Override MARKETPLACE_ADDRESS to WEB3-coded one
  const idx = next.findIndex(([from]) => from === '"MARKETPLACE_ADDRESS"');
  if (idx >= 0) {
    next[idx] = ['"MARKETPLACE_ADDRESS"', '"EQAd3btl7yW1QJ7oOF0AmaWiwAq8Vtt1-b0359ni8y5muhKJ"'];
  }
  return next;
}

function sanitizeContractsForBuild(contracts: string[]): string[] {
  return contracts.map((c) => c.replace(/_/g, ''));
}

function main() {
  const argv = process.argv.slice(2);
  if (argv.length < 2) {
    console.error('Usage: ts-node scripts/manage.ts <build|test|run|get_deploy_functions> <target|--all> [options]');
    process.exit(1);
  }

  const action = argv[0] as Action;
  const target = argv[1];
  let extraArgs = argv.slice(2);

  // Handle flags
  const hasGasReport = extraArgs.includes('--gas-report');
  if (hasGasReport) {
    extraArgs = extraArgs.filter((a) => a !== '--gas-report');
  }

  const hasTestnet = extraArgs.includes('--testnet');
  const isTestModeForDeployFunctions = extraArgs.includes('--test');

  // When building we do not forward --testnet to blueprint (match Python behavior)
  if (action === 'build' && hasTestnet) {
    extraArgs = extraArgs.filter((a) => a !== '--testnet');
  }

  let replaces: Array<[string, string]>;
  if (action === 'build' || action === 'run') {
    replaces = hasTestnet ? REPLACES_ONCHAIN_TESTNET : REPLACES_ONCHAIN_MAINNET;
  } else if (action === 'get_deploy_functions') {
    replaces = isTestModeForDeployFunctions ? withMarketplaceWeb3Override(REPLACES_TESTS) : REPLACES_ONCHAIN_MAINNET;
  } else {
    replaces = REPLACES_TESTS;
  }

  // Prepare common base args for blueprint invocations
  const baseArgs = [action, target, ...extraArgs];

  if (action === 'get_deploy_functions') {
    const original = prepareConstantsFile(replaces);
    try {
      const code = getDeployFunctionCode(target);
      process.exitCode = code;
    } finally {
      rollBackConstantsFile(original);
    }
    return;
  }

  if (action !== 'run') {
    let contracts: string[];
    if (target === '--all') {
      contracts = CONTRACTS.slice();
      if (action === 'build') {
        contracts = sanitizeContractsForBuild(contracts);
      }
    } else {
      contracts = [target];
    }

    for (const contract of contracts) {
      let effectiveReplaces = replaces;
      if (action === 'test' && contract.toLowerCase() === 'marketplace') {
        effectiveReplaces = withMarketplaceWeb3Override(effectiveReplaces);
      }

      const argsForThisContract = hasGasReport
        ? [action, '--gas-report', contract, ...extraArgs]
        : [action, contract, ...extraArgs];

      const original = prepareConstantsFile(effectiveReplaces);
      try {
        const code = blueprint(argsForThisContract);
        if (code !== 0) {
          process.exitCode = code;
          // Continue iterating but preserve non-zero exit code
        }
      } finally {
        rollBackConstantsFile(original);
      }
    }
  } else {
    // run
    const original = prepareConstantsFile(replaces);
    try {
      const code = blueprint(baseArgs);
      process.exitCode = code;
    } catch (err) {
      console.error(err);
    } finally {
      rollBackConstantsFile(original);
    }
  }
}

main();


