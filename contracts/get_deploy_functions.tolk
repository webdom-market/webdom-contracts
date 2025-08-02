
fun deployFunctionCell(): cell 
    asm """<{
    DECLPROC builder.storeStrFloat()
      DECLPROC builder.storeStrJettons()
      DECLPROC calculateUsdtWalletAddress()
      DECLPROC forceSameWorkchain()
      DECLPROC getPayoutNotificationBody()
      builder.storeStrFloat() PROCINLINE:<{	//  self number tenPowDecimals
        TUCK                    	//  self tenPowDecimals number tenPowDecimals
        DIVMOD                  	//  self tenPowDecimals intPart decPart
        s3 s1 XCPU              	//  decPart tenPowDecimals intPart self intPart
          ZERO                                                        
          SWAP                                                        
          UNTIL:<{                                                   
            10 PUSHINT DIVMOD                                         
            48 ADDCONST                                               
            s3 s1 s3 XCHG3                                          
            INC                                                      
            s1 s0 XCPU                                                
            ISZERO
          }>
          DROP
          REPEAT:<{ 8 STU }>                                        	//  decPart tenPowDecimals intPart self
        s3 PUSH                 	//  decPart tenPowDecimals intPart self decPart
        0 EQINT                 	//  decPart tenPowDecimals intPart self '9
        IF:<{                   	//  decPart tenPowDecimals intPart self
          3 1 BLKDROP2          	//  self
          DUP                   	//  self self
        }>ELSE<{                	//  decPart tenPowDecimals intPart self
          OVER                  	//  decPart tenPowDecimals intPart self intPart
          IF:<{                 	//  decPart tenPowDecimals intPart self
            10000 PUSHINT
            ROT                 	//  decPart tenPowDecimals self '12=10000 intPart
            DIV                 	//  decPart tenPowDecimals self '11
          }>ELSE<{              	//  decPart tenPowDecimals intPart self
            NIP                 	//  decPart tenPowDecimals self
            10000 PUSHINT       	//  decPart tenPowDecimals self '11=10000
          }>                    	//  decPart tenPowDecimals self maxDecPart
          0 PUSHINT             	//  decPart tenPowDecimals self maxDecPart zeros=0
          s4 PUSH               	//  decPart tenPowDecimals self maxDecPart zeros=0 decPart
          INC                   	//  decPart tenPowDecimals self maxDecPart zeros=0 '19
          s1 s4 XCHG            	//  decPart zeros=0 self maxDecPart tenPowDecimals '19
          DIV                   	//  decPart zeros=0 self maxDecPart tmp
          WHILE:<{
            DUP                 	//  decPart zeros self maxDecPart tmp tmp
            9 GTINT             	//  decPart zeros self maxDecPart tmp '22
          }>DO<{                	//  decPart zeros self maxDecPart tmp
            10 PUSHINT          	//  decPart zeros self maxDecPart tmp '23=10
            DIV                 	//  decPart zeros self maxDecPart tmp
            SWAP
            10 PUSHINT          	//  decPart zeros self tmp maxDecPart '25=10
            DIV                 	//  decPart zeros self tmp maxDecPart
            s0 s3 XCHG          	//  decPart maxDecPart self tmp zeros
            INC                 	//  decPart maxDecPart self tmp zeros
            s3 s3 XCHG2         	//  decPart zeros self maxDecPart tmp
          }>                    	//  decPart zeros self maxDecPart tmp
          DROP                  	//  decPart zeros self maxDecPart
          DUP                   	//  decPart zeros self maxDecPart maxDecPart
          0 EQINT               	//  decPart zeros self maxDecPart '30
          IFJMP:<{              	//  decPart zeros self maxDecPart
            s1 s3 XCHG
            3 BLKDROP           	//  self
            DUP                 	//  self self
          }>                    	//  decPart zeros self maxDecPart
          WHILE:<{
            s3 s0 PUSH2         	//  decPart zeros self maxDecPart decPart maxDecPart
            GREATER             	//  decPart zeros self maxDecPart '31
          }>DO<{                	//  decPart zeros self maxDecPart
            s0 s3 XCHG
            10 PUSHINT          	//  maxDecPart zeros self decPart '32=10
            DIV                 	//  maxDecPart zeros self decPart
            s0 s3 XCHG          	//  decPart zeros self maxDecPart
          }>                    	//  decPart zeros self maxDecPart
          DROP                  	//  decPart zeros self
          s2 PUSH               	//  decPart zeros self decPart
          IFJMP:<{              	//  decPart zeros self
            WHILE:<{
              s2 PUSH
              10 PUSHINT        	//  decPart zeros self decPart '34=10
              MOD               	//  decPart zeros self '35
              0 EQINT           	//  decPart zeros self '37
            }>DO<{              	//  decPart zeros self
              s0 s2 XCHG
              10 PUSHINT        	//  self zeros decPart '38=10
              DIV               	//  self zeros decPart
              s0 s2 XCHG        	//  decPart zeros self
            }>                  	//  decPart zeros self
            x{2e} STSLICECONST  	//  decPart zeros self
            SWAP                	//  decPart self zeros
            REPEAT:<{           	//  decPart self
              x{30} STSLICECONST	//  decPart self
            }>
            s0 s1 PUXC          	//  self self decPart
              ZERO                                                        
              SWAP                                                        
              UNTIL:<{                                                   
                10 PUSHINT DIVMOD                                         
                48 ADDCONST                                               
                s3 s1 s3 XCHG3                                          
                INC                                                      
                s1 s0 XCPU                                                
                ISZERO
              }>
              DROP
              REPEAT:<{ 8 STU }>                                        	//  self '46
          }>                    	//  decPart zeros self
          2 1 BLKDROP2          	//  self
          DUP                   	//  self self
        }>
      }>
      builder.storeStrJettons() PROCINLINE:<{	//  self jettonAmount oneJetton symbol
        3 -ROLL                 	//  symbol self jettonAmount oneJetton
        builder.storeStrFloat() INLINECALLDICT	//  symbol self '6
        x{20} STSLICECONST      	//  symbol self '6
        s1 s2 XCHG              	//  self symbol '6
        STSLICE                 	//  self '6
      }>
      calculateUsdtWalletAddress() PROCINLINE:<{	//  ownerAddress usdtWalletCode
        NEWC                    	//  ownerAddress usdtWalletCode '4
        x{00} STSLICECONST      	//  ownerAddress usdtWalletCode '4
        s1 s2 XCHG              	//  usdtWalletCode ownerAddress '4
        STB                     	//  usdtWalletCode '4
        x{8014D1EFF27038AD5F4C11D80A60DDB3D9C5485BA4E2826E9EA6BAA56FBBFF4119B_} PUSHSLICE	//  usdtWalletCode '4 '8
        STSLICER                	//  usdtWalletCode '4
        ENDC                    	//  usdtWalletCode data
            DUP2            // code data code data
            HASHCU
            SWAP
            HASHCU          // code data dataHash codeHash
            SWAP2           // dataHash codeHash code data
            CDEPTH
            SWAP
            CDEPTH          // dataHash codeHash dataDepth codeDepth
            NEWC
            x{020134} STSLICECONST // store refs_descriptor | bits_descriptor | data
            16 STU                 // store codeDepth
            16 STU                 // store dataDepth
            256 STU                // store codeHash
            256 STU                // store dataHash
            ONE HASHEXT_SHA256  	//  '21
        NEWC                    	//  '21 '20
        b{10000000000} STSLICECONST	//  '21 '20
        256 STU                 	//  '20
      }>
      forceSameWorkchain() PROCINLINE:<{	//  addr
        REWRITESTDADDR
        DROP                    	//  wc
        0 EQINT                 	//  '5
        333 THROWIFNOT          	// 
      }>
      getPayoutNotificationBody() PROCINLINE:<{	//  domainNameCell
        NEWC                    	//  domainNameCell '2
        x{00000000} STSLICECONST	//  domainNameCell '2
        x{596f757220646f6d61696e2077617320736f6c64206f6e20776562646f6d2e6d61726b65743a20} PUSHSLICE	//  domainNameCell '2 '5
        STSLICER                	//  domainNameCell '2
        STREF                   	//  '2
        ENDC                    	//  '8
      }>

    // Main deploy function content:
	//  args.fromAddress args.payloadSlice args.deployInfoSlice args.code args.commissionDiscount args.queryId args.publicKey args.contractCodes
//  args.fromAddress args.payloadSlice s args.code args.commissionDiscount args.queryId args.publicKey args.contractCodes
    s0 s5 XCHG              	//  args.fromAddress args.payloadSlice args.contractCodes args.code args.commissionDiscount args.queryId args.publicKey s
    16 LDU                  	//  args.fromAddress args.payloadSlice args.contractCodes args.code args.commissionDiscount args.queryId args.publicKey '14 s
    16 LDU                  	//  args.fromAddress args.payloadSlice args.contractCodes args.code args.commissionDiscount args.queryId args.publicKey '14 '16 s
    ENDS                    	//  args.fromAddress args.payloadSlice args.contractCodes args.code args.commissionDiscount args.queryId args.publicKey deployInfo.commissionFactor deployInfo.web3CommissionFactor
    s4 PUSH                 	//  args.fromAddress args.payloadSlice args.contractCodes args.code args.commissionDiscount args.queryId args.publicKey deployInfo.commissionFactor deployInfo.web3CommissionFactor args.commissionDiscount
    IF:<{                   	//  args.fromAddress args.payloadSlice args.contractCodes args.code args.commissionDiscount args.queryId args.publicKey deployInfo.commissionFactor deployInfo.web3CommissionFactor
      DROP                  	//  args.fromAddress args.payloadSlice args.contractCodes args.code args.commissionDiscount args.queryId args.publicKey deployInfo.commissionFactor
      0 PUSHINT             	//  args.fromAddress args.payloadSlice args.contractCodes args.code args.commissionDiscount args.queryId args.publicKey deployInfo.commissionFactor deployInfo.web3CommissionFactor=0
      10000 PUSHINT         	//  args.fromAddress args.payloadSlice args.contractCodes args.code args.commissionDiscount args.queryId args.publicKey deployInfo.commissionFactor deployInfo.web3CommissionFactor=0 '18=10000
      s0 s5 XCHG2           	//  args.fromAddress args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor=0 args.queryId args.publicKey deployInfo.commissionFactor '18=10000 args.commissionDiscount
      SUB                   	//  args.fromAddress args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor=0 args.queryId args.publicKey deployInfo.commissionFactor '19
      10000 PUSHINT         	//  args.fromAddress args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor=0 args.queryId args.publicKey deployInfo.commissionFactor '19 '20=10000
      MULDIV                	//  args.fromAddress args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor=0 args.queryId args.publicKey deployInfo.commissionFactor
    }>ELSE<{
      s4 POP                	//  args.fromAddress args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor args.queryId args.publicKey deployInfo.commissionFactor
    }>
    s0 s7 XCHG
    NEWC                    	//  deployInfo.commissionFactor args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor args.queryId args.publicKey args.fromAddress '23
    STSLICE                 	//  deployInfo.commissionFactor args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor args.queryId args.publicKey '23
    0 PUSHINT
    256 STUR                	//  deployInfo.commissionFactor args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor args.queryId args.publicKey '23
    SWAP
    NEWC                    	//  deployInfo.commissionFactor args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor args.queryId '23 args.publicKey b
    256 STU                 	//  deployInfo.commissionFactor args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor args.queryId '23 b
    ENDC                    	//  deployInfo.commissionFactor args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor args.queryId '23 '31
    STREFR                  	//  deployInfo.commissionFactor args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor args.queryId '23
    0 PUSHINT
    36 STUR                 	//  deployInfo.commissionFactor args.payloadSlice args.contractCodes args.code deployInfo.web3CommissionFactor args.queryId '23
    ENDC                    	//  deployInfo.commissionFactor args.payloadSlice args.contractCodes offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId offerAddress.stateInit.USlot2
    s0 s4 XCHG              	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId args.contractCodes
    CTOS                    	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId lazyS
    LDREF                   	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId '57 lazyS
    NIP                     	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId lazyS
    LDREF                   	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId '58 lazyS
    NIP                     	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId lazyS
    PLDREF                  	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode
    s3 s4 PUSH2             	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2
                     // code data
        DUP2            // code data code data
        HASHCU
        SWAP
        HASHCU          // code data dataHash codeHash
        SWAP2           // dataHash codeHash code data
        CDEPTH
        SWAP
        CDEPTH          // dataHash codeHash dataDepth codeDepth
        NEWC
        x{020134} STSLICECONST // store refs_descriptor | bits_descriptor | data
        16 STU                 // store codeDepth
        16 STU                 // store dataDepth
        256 STU                // store codeHash
        256 STU                // store dataHash
        ONE HASHEXT_SHA256  	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '66
    NEWC                    	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '66 '65
    b{10000000000} STSLICECONST	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '66 '65
    256 STU                 	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '65
    NEWC                    	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '65 '87
    x{0} STSLICECONST       	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '65 '87
    STB                     	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '87
    x{800BCFB13B3494CA795F167E94C52640B273E64B78229A15DB992A844E26F351AE9_} PUSHSLICE	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '87 '91
    STSLICER                	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '87
    OVER                    	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '87 contractCodes.web3WalletCode
    STREFR                  	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode '87
    ENDC                    	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId contractCodes.web3WalletCode data
                     // code data
        DUP2            // code data code data
        HASHCU
        SWAP
        HASHCU          // code data dataHash codeHash
        SWAP2           // dataHash codeHash code data
        CDEPTH
        SWAP
        CDEPTH          // dataHash codeHash dataDepth codeDepth
        NEWC
        x{020134} STSLICECONST // store refs_descriptor | bits_descriptor | data
        16 STU                 // store codeDepth
        16 STU                 // store dataDepth
        256 STU                // store codeHash
        256 STU                // store dataHash
        ONE HASHEXT_SHA256  	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId '105
    NEWC                    	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId '105 '104
    b{10000000000} STSLICECONST	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId '105 '104
    256 STU                 	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId web3OfferAddress
    50000000 PUSHINT        	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId web3OfferAddress '126=50000000
    NEWC                    	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId web3OfferAddress '126=50000000 '131
    x{0609e47b} STSLICECONST	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor args.queryId web3OfferAddress '126=50000000 '131
    s1 s3 XCHG              	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor '126=50000000 web3OfferAddress args.queryId '131
    64 STU                  	//  deployInfo.commissionFactor args.payloadSlice offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor '126=50000000 web3OfferAddress '131
    s1 s6 XCHG              	//  deployInfo.commissionFactor web3OfferAddress offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor '126=50000000 args.payloadSlice '131
    STSLICE                 	//  deployInfo.commissionFactor web3OfferAddress offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor '126=50000000 '131
    s1 s6 XCHG              	//  '126=50000000 web3OfferAddress offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor deployInfo.commissionFactor '131
    16 STU                  	//  '126=50000000 web3OfferAddress offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 deployInfo.web3CommissionFactor '131
    16 STU                  	//  '126=50000000 web3OfferAddress offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 '131
    s1 s3 XCHG              	//  '126=50000000 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 web3OfferAddress '131
    STB                     	//  '126=50000000 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 '131
    ENDC                    	//  '126=50000000 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 '142
    NEWC                    	//  '126=50000000 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 '142 b
    b{01000010000000000} STSLICECONST	//  '126=50000000 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 '142 b
    2OVER                   	//  '126=50000000 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 '142 b offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2
                     // code data
        DUP2            // code data code data
        HASHCU
        SWAP
        HASHCU          // code data dataHash codeHash
        SWAP2           // dataHash codeHash code data
        CDEPTH
        SWAP
        CDEPTH          // dataHash codeHash dataDepth codeDepth
        NEWC
        x{020134} STSLICECONST // store refs_descriptor | bits_descriptor | data
        16 STU                 // store codeDepth
        16 STU                 // store dataDepth
        256 STU                // store codeHash
        256 STU                // store dataHash
        ONE HASHEXT_SHA256  	//  '126=50000000 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 '142 b '164
    256 STUR                	//  '126=50000000 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 '142 b
    s0 s4 XCHG2             	//  '142 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 b '126=50000000
    STGRAMS                 	//  '142 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 b
    141 PUSHINT
    113 STUR                	//  '142 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2 b
    s1 s2 XCHG              	//  '142 offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 b
    STREF                   	//  '142 offerAddress.stateInit.USlot2 b
    STREF                   	//  '142 b
    STREF                   	//  b
    ENDC                    	//  msg
    1 PUSHINT               	//  msg '192=1
    SENDMSG                 	//  '193
    50000000 PUSHINT        	//  '193 '194=50000000
    ADD                     	//  '195
}>c PUSHREF""";
 

fun onInternalMessage(): void {
}

get fun getDeployFunctionCell(): cell {
    return deployFunctionCell();
}