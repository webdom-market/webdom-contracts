## webdom-tolk

Webdom smart-contracts codebase for .ton domains and Telegram usernames: marketplace, fixed-price sales (TON/jetton, single/multiple), auctions (TON/jetton, single/multiple), purchase offers (TON/jetton, simple/multiple), and a domain swap contract. The repository includes TypeScript wrappers and unit tests.

### Where to read about the contracts

- **Marketplace**: [ru](contracts/marketplace/README-ru.md) & [en](contracts/marketplace/README-en.md)
- **Auctions**:
  - [Jetton simple auction](contracts/auctions/jetton_simple_auction/README.md)
  - [Jetton multiple auction](contracts/auctions/jetton_multiple_auction/README.md)
  - [Ton simple auction](contracts/auctions/ton_simple_auction/README.md)
  - [Ton multiple auction](contracts/auctions/ton_multiple_auction/README.md)
- **Fixed-price sales**:
  - [Jetton simple sale](contracts/fix_price_sales/jetton_simple_sale/README.md)
  - [Jetton multiple sale](contracts/fix_price_sales/jetton_multiple_sale/README.md)
  - [Ton simple sale](contracts/fix_price_sales/ton_simple_sale/README.md)
  - [Ton multiple sale](contracts/fix_price_sales/ton_multiple_sale/README.md)
- **Purchase offers**:
  - [Ton simple offer](contracts/purchase_offers/ton_simple_offer/README.md)
  - [Jetton simple offer](contracts/purchase_offers/jetton_simple_offer/README.md)
  - [Multiple offer](contracts/purchase_offers/multiple_offer/README.md)
- **[Domain swap](contracts/domain_swap/README.md)**

Useful directories:
- `wrappers` — TypeScript wrappers for the contracts, containing the full API for interacting with them
- `tests` — Jest tests
- `scripts` — helper scripts

### How to build and test

Requires Node.js and npm.

1) Install dependencies:

```bash
npm i
```

2) Build contracts:

```bash
# build all
npm run contracts:build -- --all

# or build a single contract
npm run contracts:build -- TonSimpleSale
```

3) Run tests:

```bash
# all tests
npm run contracts:test -- --all

# or tests for a single contract (example)
npm run contracts:test -- TonSimpleSale
```

4) Other commands:

```bash
# run an arbitrary script (see scripts directory)
npm run contracts:run -- <args>

# compile deploy-function code
npm run contracts:get_deploy_functions -- <ContractName>
```
