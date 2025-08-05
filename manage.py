import sys
import subprocess
import typing


CONTRACTS = ["TonSimpleSale", "Jett_onSimpleSale", "TonMultipleSale", "Jett_onMultipleSale", "DomainSwap", "TonSimpleAuction", "Jett_onSimpleAuction", "TonMultipleAuction", "Jett_onMultipleAuction", "TonSimpleOffer", "Jett_onSimpleOffer", "Marketplace", "MultipleOffer"]

REPLACES_TESTS = [
    ('"MARKETPLACE_ADDRESS"', '"EQAX21A4fIw7hX1jmRjvJT0DX7H_FUItj2duCBWtK4ayEiC_"'), 
    ('"ADMIN_ADDRESS"', '"EQAX21A4fIw7hX1jmRjvJT0DX7H_FUItj2duCBWtK4ayEiC_"'),
    ('"TON_DNS_ADDRESS"', '"EQCTN6fMuBiue-NUT7EkYU128cYLbDuaH4egFmmc_bCKaMHK"'),
    ('"WEB3_ADDRESS"', '"EQBefYnZpKZTyviz9KYpMgWTnzJbwRTQrtzJVCJxN5qNdLJM"'),
    ('"USDT_ADDRESS"', '"EQCmj3-TgcVq-mCOwFMG7Z7OKkLdJxQTdPU11St93_oIzRaU"'),
    ('"TON_VAULT_ADDRESS"', '"EQDshQ2nyhezZleRdlZT12pvrj_cYp9XGmcRgYirA71DWugR"'),
    ('"USDT_VAULT_ADDRESS"', '"EQAtwRp7c0vR82jID5S2c34HleVxaiYjJBgMvFgdeXIkPjjm"'),
    ('"WEB3_VAULT_ADDRESS"', '"EQByrIjpJYer4sxHzKb12sxVfYIZ358RFHdAdfY2SEr3P-EX"'),
    ('"USDT_TON_POOL_ADDRESS"', '"EQBJyOz6bLTrI-QWQbmmnC5vFZOj-CN8VTIr-EIt8dnR9ZBC"'),
    ('"WEB3_TON_POOL_ADDRESS"', '"EQBHKpZrJdpABx0kCFGQ201Aix_9GviqOXoyBpvvTRc_r9-j"'),
    ('"WEB3_USDT_POOL_ADDRESS"', '"EQAYSAN3tEDQre7rUVik6cczd5gcxqyVdpi3JHvu4mrr3326"'),
    ('"USERNAMES_COLLECTION_ADDRESS"', '"EQA6SpQ_qolLTMwe3pSVllchLRMs8AOmYwb-DxG3eZD9Qk0c"'),
]

REPLACES_ONCHAIN_TESTNET = [
    ('"MARKETPLACE_ADDRESS"', '"EQBE486yq6DUJMt-cvqj-_kk4Ft0NkPW5t8tjWLZkIR_WEB3"'), 
    ('"ADMIN_ADDRESS"', '"0QCovSj8c8Ik1I-RZt7dbIOEulYe-MfJ2SN5eMhxwfACviV7"'),
    ('"TON_DNS_ADDRESS"', '"EQC3dNlesgVD8YbAazcauIrXBPfiVhMMr5YYk2in0Mtsz0Bz"'),
    ('"WEB3_ADDRESS"', '"kQAAsaFsxbeo6paoe9fNCMwRApFR9LIsyGM8bGy4B53DlN_W"'),
    ('"USDT_ADDRESS"', '"kQAke45nLBq-0fO-Vaxl8NwNwKibNtr7SheU0xqB4JTKexSm"'),
    
    ('"TON_VAULT_ADDRESS"', '"kQDshQ2nyhezZleRdlZT12pvrj_cYp9XGmcRgYirA71DWlOb"'),
    ('"USDT_VAULT_ADDRESS"', '"kQCYNvxl8U0kBV4SdtAI1Fc6ekN2oOJyl4fGtXUYsnJQRrps"'),
    ('"WEB3_VAULT_ADDRESS"', '"kQBhDY5O1rzLL9xbDDR8kpZDSsFSMVWfkBcfjJLTmF9pNyur"'),
    ('"USDT_TON_POOL_ADDRESS"', '"kQD5NnXlulLDVWM_ICHETwOQJJDfRH3XWjGXLT8TDXja4DgF"'),
    ('"WEB3_TON_POOL_ADDRESS"', '"kQDJGTmBoTCM5CZa4lKpVmSDwCDRVxzL7kP_arFWNFaXeSgr"'),
    ('"WEB3_USDT_POOL_ADDRESS"', '"kQC8xi6NzgtJGVmWks3RnBBbJhb7MtAcukMFwtCoAWzFja8D"'),

    ('"USERNAMES_COLLECTION_ADDRESS"', '"EQCA14o1-VWhS2efqoh_9M1b_A9DtKTuoqfmkn83AbJzwnPi"'),
]


REPLACES_ONCHAIN_MAINNET = [
    ('"MARKETPLACE_ADDRESS"', '"EQA7QIKU3j1ipe88gg8euLxKupXEjc_czkigjw9mpZ5qXT8N"'), #'"EQD7-a6WPtb7w5VgoUfHJmMvakNFgitXPk3sEM8Gf_WEBDOM"'), 
    ('"ADMIN_ADDRESS"', '"0QCovSj8c8Ik1I-RZt7dbIOEulYe-MfJ2SN5eMhxwfACviV7"'),
    ('"TON_DNS_ADDRESS"', '"EQC3dNlesgVD8YbAazcauIrXBPfiVhMMr5YYk2in0Mtsz0Bz"'),
    ('"WEB3_ADDRESS"', '"EQBtcL4JA-PdPiUkB8utHcqdaftmUSTqdL8Z1EeXePLti_nK"'),
    ('"USDT_ADDRESS"', '"EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"'),
    
    ('"TON_VAULT_ADDRESS"', '"EQDa4VOnTYlLvDJ0gZjNYm5PXfSmmtL6Vs6A_CZEtXCNICq_"'),
    ('"USDT_VAULT_ADDRESS"', '"EQAYqo4u7VF0fa4DPAebk4g9lBytj2VFny7pzXR0trjtXQaO"'),
    ('"WEB3_VAULT_ADDRESS"', '"EQA_Au61onx7O5q1C2Q92S2bMaEL5v96HAYH4fjms1NIERVE"'),
    ('"USDT_TON_POOL_ADDRESS"', '"EQA-X_yo3fzzbDbJ_0bzFWKqtRuZFIRa1sJsveZJ1YpViO3r"'),
    ('"WEB3_TON_POOL_ADDRESS"', '"EQBTzDJyEgoXm88EkVTciyyZBfQYI-8OfOEDZphfHaQcoY8V"'),
    ('"WEB3_USDT_POOL_ADDRESS"', '"EQBJe_ykU9KEvg3c2kDyxGykbJoNCCMLQ6dJjaONDUfDgEL8"'),
 
    ('"USERNAMES_COLLECTION_ADDRESS"', '"EQCA14o1-VWhS2efqoh_9M1b_A9DtKTuoqfmkn83AbJzwnPi"'),

]


def prepare_constants_file(replaces: list[tuple[str, str]]) -> str:
    with open('contracts/imports/constants.tolk', 'r') as file:
        content = file.read()

    new_content = content
    for i in range(len(replaces)):
        new_content = new_content.replace(replaces[i][0], replaces[i][1])

    with open('contracts/imports/constants.tolk', 'w') as file:
        file.write(new_content)

    return content

def roll_back_constants_file(old_content: str):
    with open('contracts/imports/constants.tolk', 'w') as file:
        file.write(old_content)


action: typing.Literal["build", "test", "run", "get_deploy_functions"] = sys.argv[1]
target: str = sys.argv[2]
if action == "get_deploy_functions":
    if "--test" in sys.argv:
        replaces = REPLACES_TESTS
        replaces[0] = '"MARKETPLACE_ADDRESS"', '"EQDS7a_9kvBzUjikv_j2_JdU8q1_T21OlSbgpPFEWGG_WEB3"'
    else:
        replaces = REPLACES_ONCHAIN_MAINNET
    old_content = prepare_constants_file(replaces)
    output = subprocess.run(["npx", "ts-node", "scripts/getDeployFunctionCode.ts", target])
    roll_back_constants_file(old_content)
    exit(0)

if "--gas-report" in sys.argv:
    sys.argv.remove("--gas-report")
    gas_report = True
else:
    gas_report = False

if action == "build" or action == "run":
    if "--testnet" in sys.argv:
        if action == "build":
            sys.argv.remove("--testnet")
        replaces = REPLACES_ONCHAIN_TESTNET
    else:
        replaces = REPLACES_ONCHAIN_MAINNET
else:
    replaces = REPLACES_TESTS
    

args = ["npx", "blueprint", action, target]
if len(sys.argv) > 3:
    args.extend(sys.argv[3:])

if action != "run":
    if target == "--all":
        contracts = CONTRACTS
        if action == "build":
            contracts = list(map(lambda x: x.replace('_', ''), contracts))
    else:
        contracts = [target]

    for contract in contracts:
        if contract.lower() == "marketplace":
            replaces[0] = REPLACES_ONCHAIN_MAINNET[0] if action == "build" else ('"MARKETPLACE_ADDRESS"', '"EQDS7a_9kvBzUjikv_j2_JdU8q1_T21OlSbgpPFEWGG_WEB3"')
        if gas_report:
            args = ["npx", "blueprint", action,  "--gas-report", contract]
        else:
            args[-1] = contract
        old_content = prepare_constants_file(replaces)
        output = subprocess.run(args)
        roll_back_constants_file(old_content)

else:
    try:
        old_content = prepare_constants_file(replaces)
        output = subprocess.run(args)
    except Exception as e:
        print(e)
    roll_back_constants_file(old_content)
