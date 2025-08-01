    import { compile, sleep } from '@ton/blueprint';
import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { TestConts } from '../wrappers/DeployFunctions';
import { writeFileSync, readFileSync, mkdirSync } from 'fs';
import { join } from 'path';
import '@ton/test-utils';

// Маппинг имен контрактов к их путям (без префикса contracts/, так как компилятор добавляет его автоматически)
const CONTRACT_PATHS: Record<string, string> = {
    'JettonSimpleAuction': 'auctions/jetton_simple_auction',
    'JettonMultipleAuction': 'auctions/jetton_multiple_auction',
    'TonSimpleAuction': 'auctions/ton_simple_auction',
    'TonMultipleAuction': 'auctions/ton_multiple_auction',
    'JettonSimpleSale': 'fix_price_sales/jetton_simple_sale',
    'JettonMultipleSale': 'fix_price_sales/jetton_multiple_sale',
    'TonSimpleSale': 'fix_price_sales/ton_simple_sale',
    'TonMultipleSale': 'fix_price_sales/ton_multiple_sale',
    'JettonSimpleOffer': 'purchase_offers/jetton_simple_offer',
    'TonSimpleOffer': 'purchase_offers/ton_simple_offer',
    'MultipleOffer': 'purchase_offers/multiple_offer'
};

/**
 * Обновляет файл get_deploy_functions.tolk с путем к deploy файлу
 */
function updateDeployFunctionsFileWithPath(contractName: string): void {
    const contractPath = CONTRACT_PATHS[contractName];
    if (!contractPath) {
        throw new Error(`Contract ${contractName} not found in CONTRACT_PATHS`);
    }

    const template = `import "${contractPath}/deploy_function.tolk";

fun onInternalMessage(): void {
}`;

    writeFileSync('contracts/get_deploy_functions.tolk', template);
    console.log(`Updated get_deploy_functions.tolk with path: ${contractPath}`);
}

/**
 * Извлекает весь ASM-код из .fif файла, исключая служебные строки и основную deploy функцию
 */
function extractDeployFunctionCode(contractName: string): string {
    const fifPath = 'build/DeployFunctions/DeployFunctions.fif';
    const content = readFileSync(fifPath, 'utf-8');
    const lines = content.split('\n');
    
    let helperCode = '';
    let mainFunctionCode = '';
    let insideProgram = false;
    let insideMainFunction = false;
    
    const functionName = `deploy${contractName}`;
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        
        // Начинаем извлечение после строки PROGRAM{
        if (line.trim() === 'PROGRAM{') {
            insideProgram = true;
            continue;
        }
        
        // Заканчиваем извлечение перед строкой }END>c
        if (line.trim() === '}END>c') {
            break;
        }
        
        if (insideProgram) {
            const trimmedLine = line.trim();
            
            // Пропускаем пустые строки и комментарии
            if (trimmedLine === '' || trimmedLine.startsWith('//')) {
                continue;
            }
            
            // Пропускаем DECLMETHOD строки (это методы контракта)
            if (trimmedLine.includes('DECLMETHOD')) {
                continue;
            }
            if (trimmedLine.includes(`DECLPROC ${functionName}`)) {
                continue;
            }
            
            // Проверяем, не началась ли основная deploy функция
            if (line.includes(`${functionName}() PROC:<{`)) {                
                // Извлекаем содержимое основной функции
                let braceCount = 1;
                const codeStart = line.indexOf('PROC:<{') + 7;
                mainFunctionCode = line.substring(codeStart) + '\n';
                i++;
                
                // Извлекаем тело основной функции
                while (i < lines.length && braceCount > 0) {
                    const currentLine = lines[i];
                    
                    for (const char of currentLine) {
                        if (char === '{') braceCount++;
                        if (char === '}') braceCount--;
                    }
                    
                    mainFunctionCode += currentLine + '\n';
                    
                    if (braceCount === 0) {
                        // Убираем закрывающую скобку
                        mainFunctionCode = mainFunctionCode.replace(/\s*\}>\s*$/, '');
                        break;
                    }
                    i++;
                }
                break;
            }
            
            helperCode += '    ' + line + '\n';
        }
    }
    
    if (!helperCode.trim() && !mainFunctionCode.trim()) {
        throw new Error(`No code extracted from ${fifPath}`);
    }
    
    // Объединяем helper код и основную функцию
    let finalCode = helperCode + '\n    // Main deploy function content:\n' + mainFunctionCode;
    
    return finalCode.trim();
}

/**
 * Обновляет файл get_deploy_functions.tolk с ASM-кодом
 */
function updateDeployFunctionsFileWithCode(contractName: string, asmCode: string): void {
    const contractPath = CONTRACT_PATHS[contractName];
    if (!contractPath) {
        throw new Error(`Contract ${contractName} not found in CONTRACT_PATHS`);
    }

    const template = `
fun deployFunctionCell(): cell 
    asm """<{
    ${asmCode}
}>c PUSHREF""";
 

fun onInternalMessage(): void {
}

get fun getDeployFunctionCell(): cell {
    return deployFunctionCell();
}`;

    writeFileSync('contracts/get_deploy_functions.tolk', template);
    console.log(`Updated get_deploy_functions.tolk with ASM code for ${contractName}`);
}

/**
 * Создает BOC файл с результатом выполнения гет-метода
 */
async function createBocFile(contractName: string): Promise<void> {
    console.log('Compiling DeployFunctions...');
    const code = await compile('DeployFunctions');

    console.log('Setting up blockchain...');
    const blockchain = await Blockchain.create();
    const deployer = await blockchain.treasury('deployer');

    console.log('Deploying contract...');
    const contract = blockchain.openContract(TestConts.create(code));
    
    const deployResult = await contract.sendDeploy(deployer.getSender(), BigInt('1000000000'));
    
    console.log('Contract deployed successfully!');

    console.log('Getting deploy function cell...');
    const bocHex = await contract.getDeployFunctionCell();
    console.log('Boc result\n', bocHex);

    // Создаем директорию если её нет
    const outputDir = 'deploy_functions_compiled';
    try {
        mkdirSync(outputDir, { recursive: true });
    } catch (e) {
        // Директория уже существует
    }

    // Записываем BOC файл
    const outputPath = join(outputDir, `${contractName}.boc`);
    const bocBuffer = Buffer.from(bocHex, 'hex');
    writeFileSync(outputPath, bocBuffer);
    
    console.log(`Created BOC file: ${outputPath}`);
}

/**
 * Основная функция скрипта
 */
export async function run(contractName: string): Promise<void> {
    if (!contractName) {
        console.error('Please provide contract name as argument');
        console.log('Available contracts:', Object.keys(CONTRACT_PATHS).join(', '));
        return;
    }

    if (!CONTRACT_PATHS[contractName]) {
        console.error(`Contract ${contractName} not found`);
        console.log('Available contracts:', Object.keys(CONTRACT_PATHS).join(', '));
        return;
    }

    try {
        console.log(`Processing contract: ${contractName}`);

        // Шаг 1-2: Обновляем файл с путем
        console.log('Step 1-2: Updating get_deploy_functions.tolk with path...');
        updateDeployFunctionsFileWithPath(contractName);

        // Шаг 3: Компилируем
        console.log('Step 3: Compiling...');
        await new Promise<void>((resolve, reject) => {
            const { spawn } = require('child_process');
            const proc = spawn('python3', ['manage.py', 'build', 'DeployFunctions'], { stdio: 'inherit' });
            proc.on('close', (code: number) => {
                if (code === 0) {
                    resolve();
                } else {
                    reject(new Error(`python3 manage.py build DeployFunctions exited with code ${code}`));
                }
            });
            proc.on('error', reject);
        });

        // Шаг 4: Извлекаем ASM-код
        console.log('Step 4: Extracting ASM code...');
        const asmCode = extractDeployFunctionCode(contractName);

        // Шаг 5: Обновляем файл с ASM-кодом
        console.log('Step 5: Updating get_deploy_functions.tolk with ASM code...');
        updateDeployFunctionsFileWithCode(contractName, asmCode);

        // Шаг 6-7: Создаем BOC файл
        console.log('Step 6-7: Creating BOC file...');
        await createBocFile(contractName);

        console.log(`Successfully processed ${contractName}!`);

    } catch (error) {
        console.error('Error:', error);
        throw error;
    }
}


async function runAll() {
    for (const contractName of Object.keys(CONTRACT_PATHS)) {
        await run(contractName).catch(console.error);
    }
}

// Если скрипт запущен напрямую
if (require.main === module) {
    const contractName = process.argv[2];
    if (contractName == 'all') {
        runAll().catch(console.error);
    }
    else {
        run(contractName).catch(console.error);
    }
}
