/* GLOBAL OP-CODES */

// Common
const OP_COMMENT: uint32                = 0x00000000;
const OP_GET_STATIC_DATA: uint32        = 0x2fcb26a2;
const OP_REPORT_STATIC_DATA: uint32     = 0x8b771735;
const OP_GET_STORAGE_DATA: uint32       = 0x5b88e5cc;
const OP_REPORT_STORAGE_DATA: uint32    = 0xaab4a8ef;
const OP_EXCESSES: uint32               = 0xd53276db;
const OP_FILL_UP_BALANCE: uint32        = 0x0609e47b;
const OP_DEDUST_PAYOUT: uint32          = 0x474f86cf;

// Jettons
const OP_TRANSFER_JETTON: uint32        = 0x0f8a7ea5;
const OP_TRANSFER_NOTIFICATION: uint32  = 0x7362d09c;
const OP_PROVIDE_WALLET_ADDRESS: uint32 = 0x2c76b973;
const OP_TAKE_WALLET_ADDRESS: uint32    = 0xd1735400;
const OP_BURN_JETTON: uint32            = 0x595f07bc;

// NFTs
const OP_TRANSFER_NFT: uint32           = 0x5fcc3d14;
const OP_OWNERSHIP_ASSIGNED: uint32     = 0x05138d91;

// Domains
const OP_OUTBID_NOTIFICATION: uint32    = 0x557cea20;
const OP_CHANGE_DNS_RECORD: uint32      = 0x4eb1f0f9;
const OP_DNS_BALANCE_RELEASE: uint32    = 0x4ed14b65;

// DEDUST
const OP_SWAP_JETTON: uint32              = 0xe3a0d482;
const OP_DEPOSIT_LIQUIDITY_JETTON: uint32 = 0x40e108d6;
const OP_SWAP_TON: uint32                 = 0xea06185d;
const OP_DEPOSIT_LIQUIDITY_TON: uint32    = 0xd55e4686;


/* LOCAL OP-CODES */

// Common
const OP_SET_NEW_DATA: uint32            = 0xb1f57834;
const OP_CANCEL_DEAL: uint32             = 0x8ea53895;
const OP_CHANGE_PRICE: uint32            = 0x96189f94;
const OP_CHANGE_constID_UNTIL: uint32    = 0xfd265ff8;
const OP_RENEW_DOMAIN: uint32            = 0x2e9ead29;
const OP_RENEWAL_FEE: uint32             = 0x975f5690;
const OP_MAKE_HOT: uint32                = 0x504b6dd7;
const OP_MAKE_COLORED: uint32            = 0x96dc2804;

// Admin
const OP_SEND_ANY_MESSAGE: uint32       = 0xa47d989c;
const OP_SET_CODE: uint32               = 0xe2d2d211;
const OP_WITHDRAW_TON: uint32           = 0x37726bdb;
const OP_WITHDRAW_JETTON: uint32        = 0x11c09682;
const OP_WITHDRAW_DOMAIN: uint32        = 0x00dc315b;


/* TON VALUES */
const TONS_MIN_RESERVE: coins           = ton("0.015");
const TONS_MIN_EXCESS: coins            = ton("0.005");
const TONS_NFT_TRANSFER: coins          = ton("0.03");
const TONS_JETTON_TRANSFER: coins       = ton("0.05");
const TONS_BURN_JETTON: coins           = ton("0.05");
const TONS_RENEW_DOMAIN: coins          = ton("0.01");
const TONS_RENEW_REQUEST: coins         = ton("0.1");
const TONS_PURCHASE_NOTIFICATION: coins = ton("0.03");
const TONS_OFFER_NOTIFICATION: coins    = ton("0.1");
const TONS_DECLINE_REWARD: coins        = ton("0.01");
const TONS_NOTIFY_MARKETPLACE: coins    = ton("0.01");
const TONS_GET_JETTON_WALLET: coins     = ton("0.02");


/* EXCEPTIONS */

const EXC_OUT_OF_GAS: int            = 13;

const EXC_INVALID_SIGNATURE: int     = 35;

const EXC_DEAL_NOT_ACTIVE: int       = 44;
const EXC_DOMAIN_EXPIRED: int        = 45;
const EXC_ALREADY_DEPLOYED: int      = 46;
const EXC_INCORRECT_DOMAIN: int      = 47;
const EXC_CANT_CANCEL_DEAL: int      = 48;
const EXC_INCORRECT_VALID_UNTIL: int = 49;
const EXC_INCORRECT_SENDER: int      = 50;
const EXC_DOMAIN_NOT_EXISTS: int     = 51;
const EXC_NOT_ENOUGH_JETTONS: int    = 52;

const EXC_WRONG_CHAIN: int           = 333;
const EXC_UNSUPPORTED_OP: int        = 0xffff;


/* NOTIFICATIONS */

fun BUYER_NOTIFICATION(): cell 
    asm "B{b5ee9c7241010101001f00003a000000005075726368617365206f6e20776562646f6d2e6d61726b65740f51799a} B>boc PUSHREF";  // Purchase on webdom.market

fun EXCESSES_NOTIFICATION(): cell 
    asm "B{b5ee9c7201010101000e000018000000004578636573736573} B>boc PUSHREF";  // Excesses

fun MARKETPLACE_COMMISSION_NOTIFICATION(): cell 
    asm "B{b5ee9c7241010101001c000034000000004d61726b6574706c61636520636f6d6d697373696f6e30480693} B>boc PUSHREF";  // Marketplace commission


/* ADDRESSES */

const MARKETPLACE_ADDRESS: address  = address("EQDS7a_9kvBzUjikv_j2_JdU8q1_T21OlSbgpPFEWGG_WEB3");
const ADMIN_ADDRESS: address        = address("EQAX21A4fIw7hX1jmRjvJT0DX7H_FUItj2duCBWtK4ayEiC_"); 
const WEB3_ADDRESS: address         = address("EQBefYnZpKZTyviz9KYpMgWTnzJbwRTQrtzJVCJxN5qNdLJM");
const USDT_ADDRESS: address         = address("EQCmj3-TgcVq-mCOwFMG7Z7OKkLdJxQTdPU11St93_oIzRaU");
const BURN_ADDRESS: address         = address("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c");
const TON_DNS_ADDRESS: address      = address("EQCTN6fMuBiue-NUT7EkYU128cYLbDuaH4egFmmc_bCKaMHK");  
const TG_USERNAMES_ADDRESS: address = address("EQA6SpQ_qolLTMwe3pSVllchLRMs8AOmYwb-DxG3eZD9Qk0c");

const TON_VAULT_ADDRESS: address    = address("EQDshQ2nyhezZleRdlZT12pvrj_cYp9XGmcRgYirA71DWugR");
const USDT_VAULT_ADDRESS: address   = address("EQAtwRp7c0vR82jID5S2c34HleVxaiYjJBgMvFgdeXIkPjjm");
const WEB3_VAULT_ADDRESS: address   = address("EQByrIjpJYer4sxHzKb12sxVfYIZ358RFHdAdfY2SEr3P-EX");


/* OTHER */

fun BIT_TRUE_SLICE(): slice 
    asm "b{1} PUSHSLICE";

fun BIT_FALSE_SLICE(): slice 
    asm "b{0} PUSHSLICE";

fun TWO_ZEROS_SLICE(): slice 
    asm "b{00} PUSHSLICE";

const WORKCHAIN: int = 0;
const MAX_COINS_VALUE: coins = 0xffffffffffffffffffffffffffffff;
const ONE_HOUR: uint32 = 60 * 60;
const ONE_DAY: uint32 = 24 * ONE_HOUR;
const ONE_YEAR: uint32 = 366 * ONE_DAY;  // taken from TON DNS constants

const COMMISSION_DIVIDER: uint16 = 10000;

const STATE_UNINIT: int = 0;
const STATE_ACTIVE: int = 1;
const STATE_COMPLETED: int = 2;
const STATE_CANCELLED: int = 3;
