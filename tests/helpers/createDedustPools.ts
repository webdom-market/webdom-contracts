import { Asset, Factory, PoolType, ReadinessStatus, VaultJetton } from '../../wrappers/dedust';
import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Address, contractAddress, toNano } from "@ton/ton";
import { factoryCode, factoryData } from '../../wrappers/helpers/dedustFactoryData'
import { JettonWallet } from '../../wrappers/JettonWallet';

export async function createDedustPools(admin: SandboxContract<TreasuryContract>, blockchain: Blockchain, usdtMinterAddress: Address, usdtWallet: SandboxContract<JettonWallet>, web3MinterAddress: Address, web3Wallet: SandboxContract<JettonWallet>) {
    const factoryInit = { code: factoryCode, data: factoryData };
    const factoryAddress = contractAddress(0, factoryInit);
    const factory = blockchain.openContract(new Factory(factoryAddress, factoryInit));

    const usdtAsset = Asset.jetton(usdtMinterAddress);
    const web3Asset = Asset.jetton(web3MinterAddress);
    const tonAsset = Asset.native();

    await factory.sendCreateVault(admin.getSender(), { asset: tonAsset });
    await factory.sendCreateVault(admin.getSender(), { asset: usdtAsset });
    await factory.sendCreateVault(admin.getSender(), { asset: web3Asset });
    const usdtVault = blockchain.openContract(await factory.getJettonVault(usdtMinterAddress));
    const web3Vault = blockchain.openContract(await factory.getJettonVault(web3MinterAddress));
    const tonVault = blockchain.openContract(await factory.getNativeVault());

    await factory.sendCreateVolatilePool(admin.getSender(), { assets: [tonAsset, usdtAsset] });
    await factory.sendCreateVolatilePool(admin.getSender(), { assets: [tonAsset, web3Asset] });
    await factory.sendCreateVolatilePool(admin.getSender(), { assets: [usdtAsset, web3Asset] });
    const usdtTonPool = blockchain.openContract(await factory.getPool(PoolType.VOLATILE, [tonAsset, usdtAsset]));
    const web3TonPool = blockchain.openContract(await factory.getPool(PoolType.VOLATILE, [tonAsset, web3Asset]));
    const web3UsdtPool = blockchain.openContract(await factory.getPool(PoolType.VOLATILE, [usdtAsset, web3Asset]));

    const tonAmount = toNano(10000);
    const usdtAmount = toNano(10000);
    const web3Amount = toNano(10000);

    await tonVault.sendDepositLiquidity(admin.getSender(), {
        poolType: PoolType.VOLATILE,
        assets: [tonAsset, usdtAsset],
        targetBalances: [tonAmount, usdtAmount],
        amount: tonAmount,
    }); 
    await usdtWallet.sendTransfer(admin.getSender(), usdtAmount, usdtVault.address, admin.address, toNano('0.4'),
        VaultJetton.createDepositLiquidityPayload({
            poolType: PoolType.VOLATILE,
            assets: [tonAsset, usdtAsset],
            targetBalances: [tonAmount, usdtAmount],
        }),
    );

    await tonVault.sendDepositLiquidity(admin.getSender(), {
        poolType: PoolType.VOLATILE,
        assets: [tonAsset, web3Asset],
        targetBalances: [tonAmount, web3Amount],
        amount: tonAmount,
    });
    await web3Wallet.sendTransfer(admin.getSender(), web3Amount, web3Vault.address, admin.address, toNano('0.4'),
        VaultJetton.createDepositLiquidityPayload({
            poolType: PoolType.VOLATILE,
            assets: [tonAsset, web3Asset],
            targetBalances: [tonAmount, web3Amount],
        }),
    );

    await usdtWallet.sendTransfer(admin.getSender(), usdtAmount, usdtVault.address, admin.address, toNano('0.4'),
        VaultJetton.createDepositLiquidityPayload({
            poolType: PoolType.VOLATILE,
            assets: [usdtAsset, web3Asset],
            targetBalances: [usdtAmount, web3Amount],
        }),
    );
    await web3Wallet.sendTransfer(admin.getSender(), web3Amount, web3Vault.address, admin.address, toNano('0.4'),
        VaultJetton.createDepositLiquidityPayload({
            poolType: PoolType.VOLATILE,
            assets: [usdtAsset, web3Asset],
            targetBalances: [usdtAmount, web3Amount],
        }),
    );

    return {
        tonVault: tonVault,
        usdtVault: usdtVault,
        web3Vault: web3Vault,
        usdtTonPool: usdtTonPool,
        web3TonPool: web3TonPool,
        web3UsdtPool: web3UsdtPool,
    }
}