
fun deployFunctionCell(): cell 
    asm """<{
    DECLPROC builder.storeStrFloat()
      DECLPROC builder.storeStrJettons()
      DECLPROC calculateWeb3WalletAddress()
      DECLPROC calculateUsdtWalletAddress()
      DECLPROC forceSameWorkchain()
      DECLPROC getPayoutNotificationBody()
      DECLPROC domainNameToAddress()
      DECLPROC tgUsernameToAddress()
      DECLPROC Storage.load()
      DECLPROC Storage.save()
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
      calculateWeb3WalletAddress() PROCINLINE:<{	//  ownerAddress web3WalletCode
        NEWC                    	//  ownerAddress web3WalletCode '3
        x{0} STSLICECONST       	//  ownerAddress web3WalletCode '3
        s1 s2 XCHG              	//  web3WalletCode ownerAddress '3
        STB                     	//  web3WalletCode '3
        x{800DAE17C1207C7BA7C4A480F975A3B953AD3F6CCA249D4E97E33A88F2EF1E5DB17_} PUSHSLICE	//  web3WalletCode '3 '7
        STSLICER                	//  web3WalletCode '3
        OVER                    	//  web3WalletCode '3 web3WalletCode
        STREFR                  	//  web3WalletCode '3
        ENDC                    	//  web3WalletCode data
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
      calculateUsdtWalletAddress() PROCINLINE:<{	//  ownerAddress usdtWalletCode
        NEWC                    	//  ownerAddress usdtWalletCode '4
        x{00} STSLICECONST      	//  ownerAddress usdtWalletCode '4
        s1 s2 XCHG              	//  usdtWalletCode ownerAddress '4
        STB                     	//  usdtWalletCode '4
        x{801622753296A04942CE33ED2272651D6EB2B2D87144BEB2051628DFD9B86C43BFD_} PUSHSLICE	//  usdtWalletCode '4 '10
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
            ONE HASHEXT_SHA256  	//  '23
        NEWC                    	//  '23 '22
        b{10000000000} STSLICECONST	//  '23 '22
        256 STU                 	//  '22
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
      domainNameToAddress() PROCINLINE:<{	//  domainName domainCode
        SWAP                    	//  domainCode domainName
        HASHSU                  	//  domainCode domainIndex
        NEWC                    	//  domainCode domainIndex '5
        256 STU                 	//  domainCode '5
        x{8016EE9B2BD640A87E30D80D66E357115AE09EFC4AC26195F2C3126D14FA196D99F_} PUSHSLICE	//  domainCode '5 '8
        STSLICER                	//  domainCode '5
        ENDC                    	//  domainCode data
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
      tgUsernameToAddress() PROCINLINE:<{	//  tgUsername tgUsernameCode
        SWAP                    	//  tgUsernameCode tgUsername
        SHA256U                 	//  tgUsernameCode usernameIndex
        NEWC                    	//  tgUsernameCode usernameIndex '5
        SWAP
        NEWC                    	//  tgUsernameCode '5 usernameIndex '6
        256 STU                 	//  tgUsernameCode '5 '6
        x{80101AF146BF2AB4296CF3F5510FFE99AB7F81E876949DD454FCD24FE6E0364E785_} PUSHSLICE	//  tgUsernameCode '5 '6 '9
        STSLICER                	//  tgUsernameCode '5 '6
        ENDC                    	//  tgUsernameCode '5 '11
        STREFR                  	//  tgUsernameCode '5
        b{0} STSLICECONST       	//  tgUsernameCode '5
        ENDC                    	//  tgUsernameCode data
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
            ONE HASHEXT_SHA256  	//  '27
        NEWC                    	//  '27 '26
        b{10000000000} STSLICECONST	//  '27 '26
        256 STU                 	//  '26
      }>
      Storage.load() PROC:<{      	// 
        c4 PUSH                 	//  '0
        CTOS                    	//  s
        LDMSGADDR               	//  '4 s
        LDMSGADDR               	//  '4 '5 s
        LDGRAMS                 	//  '4 '5 '6 s
        2 LDU                   	//  '4 '5 '6 '8 s
        LDGRAMS                 	//  '4 '5 '6 '8 '9 s
        32 LDU                  	//  '4 '5 '6 '8 '9 '11 s
        32 LDU                  	//  '4 '5 '6 '8 '9 '11 '13 s
        32 LDU                  	//  '4 '5 '6 '8 '9 '11 '13 '15 s
        LDOPTREF                	//  '4 '5 '6 '8 '9 '11 '13 '15 '16 s
        LDREF                   	//  '4 '5 '6 '8 '9 '11 '13 '15 '16 '17 s
        32 LDU                  	//  '4 '5 '6 '8 '9 '11 '13 '15 '16 '17 '19 s
        32 LDU                  	//  '4 '5 '6 '8 '9 '11 '13 '15 '16 '17 '19 '21 s
        ENDS                    	//  '4 '5 '6 '8 '9 '11 '13 '15 '16 '17 '19 '21
      }>
      Storage.save() PROCINLINE:<{	//  self.domainAddress self.sellerAddress self.price self.state self.commission self.createdAt self.lastRenewalTime self.validUntil self.buyerAddressCell self.domainNameCell self.hotUntil self.coloredUntil
        s0 s11 XCHG
        NEWC                    	//  self.coloredUntil self.sellerAddress self.price self.state self.commission self.createdAt self.lastRenewalTime self.validUntil self.buyerAddressCell self.domainNameCell self.hotUntil self.domainAddress b
        STSLICE                 	//  self.coloredUntil self.sellerAddress self.price self.state self.commission self.createdAt self.lastRenewalTime self.validUntil self.buyerAddressCell self.domainNameCell self.hotUntil b
        s1 s10 XCHG             	//  self.coloredUntil self.hotUntil self.price self.state self.commission self.createdAt self.lastRenewalTime self.validUntil self.buyerAddressCell self.domainNameCell self.sellerAddress b
        STSLICE                 	//  self.coloredUntil self.hotUntil self.price self.state self.commission self.createdAt self.lastRenewalTime self.validUntil self.buyerAddressCell self.domainNameCell b
        s0 s8 XCHG2             	//  self.coloredUntil self.hotUntil self.domainNameCell self.state self.commission self.createdAt self.lastRenewalTime self.validUntil self.buyerAddressCell b self.price
        STGRAMS                 	//  self.coloredUntil self.hotUntil self.domainNameCell self.state self.commission self.createdAt self.lastRenewalTime self.validUntil self.buyerAddressCell b
        s1 s6 XCHG              	//  self.coloredUntil self.hotUntil self.domainNameCell self.buyerAddressCell self.commission self.createdAt self.lastRenewalTime self.validUntil self.state b
        2 STU                   	//  self.coloredUntil self.hotUntil self.domainNameCell self.buyerAddressCell self.commission self.createdAt self.lastRenewalTime self.validUntil b
        s0 s4 XCHG2             	//  self.coloredUntil self.hotUntil self.domainNameCell self.buyerAddressCell self.validUntil self.createdAt self.lastRenewalTime b self.commission
        STGRAMS                 	//  self.coloredUntil self.hotUntil self.domainNameCell self.buyerAddressCell self.validUntil self.createdAt self.lastRenewalTime b
        s1 s2 XCHG              	//  self.coloredUntil self.hotUntil self.domainNameCell self.buyerAddressCell self.validUntil self.lastRenewalTime self.createdAt b
        32 STU                  	//  self.coloredUntil self.hotUntil self.domainNameCell self.buyerAddressCell self.validUntil self.lastRenewalTime b
        32 STU                  	//  self.coloredUntil self.hotUntil self.domainNameCell self.buyerAddressCell self.validUntil b
        32 STU                  	//  self.coloredUntil self.hotUntil self.domainNameCell self.buyerAddressCell b
        STOPTREF                	//  self.coloredUntil self.hotUntil self.domainNameCell b
        STREF                   	//  self.coloredUntil self.hotUntil b
        32 STU                  	//  self.coloredUntil b
        32 STU                  	//  b
        ENDC                    	//  '20
        c4 POP                  	// 
      }>

    // Main deploy function content:
	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.domainAddress args.domainNameCell
    2 2 BLKDROP2            	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice s args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress args.domainNameCell
    s0 s5 XCHG              	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress s
    LDGRAMS                 	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress '17 s
    16 LDU                  	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress '17 '19 s
    LDGRAMS                 	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress '17 '19 '20 s
    32 LDU                  	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress '17 '19 '20 '22 s
    ENDS                    	//  args.commonArgs.fromAddress s args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
    s0 s9 XCHG              	//  args.commonArgs.fromAddress deployInfo.minDuration args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission s
    LDGRAMS                 	//  args.commonArgs.fromAddress deployInfo.minDuration args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission '28 s
    32 LDU                  	//  args.commonArgs.fromAddress deployInfo.minDuration args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission '28 '30 s
    ENDS                    	//  args.commonArgs.fromAddress deployInfo.minDuration args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.price payload.validUntil
    s1 s4 PUXC              	//  args.commonArgs.fromAddress deployInfo.minDuration args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission payload.price payload.price deployInfo.minPrice
    GEQ                     	//  args.commonArgs.fromAddress deployInfo.minDuration args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission payload.price '32
    70 THROWIFNOT           	//  args.commonArgs.fromAddress deployInfo.minDuration args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission payload.price
    NOW                     	//  args.commonArgs.fromAddress deployInfo.minDuration args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission payload.price '35
    s0 s10 XCHG2            	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '35 deployInfo.minDuration
    ADD                     	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '36
    s3 PUSH                 	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '36 payload.validUntil
    LEQ                     	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '37
    IF:<{                   	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission
      NOW                   	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '39
      31622400 PUSHINT      	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '39 '46
      ADD                   	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '47
      86400 PUSHINT         	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '47 '52
      SUB                   	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '53
      s3 PUSH               	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '53 payload.validUntil
      GEQ                   	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '54
      0 NEQINT              	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '38
    }>ELSE<{                	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission
      0 PUSHINT             	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission '38=0
    }>
    49 THROWIFNOT           	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.commissionFactor deployInfo.maxCommission
    s8 s1 PUXC
    10000 PUSHINT           	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.maxCommission payload.price deployInfo.commissionFactor '60=10000
    MULDIV                  	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil deployInfo.maxCommission '61
    MIN                     	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil '62
    10000 PUSHINT           	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.validUntil '62 '63=10000
    s0 s5 XCHG2             	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code '62 args.commonArgs.queryId args.domainAddress payload.validUntil '63=10000 args.commonArgs.commissionDiscount
    SUB                     	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code '62 args.commonArgs.queryId args.domainAddress payload.validUntil '64
    s1 s4 XCHG
    10000 PUSHINT           	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress '62 '64 '65=10000
    MULDIV                  	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission
    NOW                     	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69
    NOW                     	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69 '70
    PUSHNULL                	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69 '70 '71
    s4 PUSH
    NEWC                    	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69 '70 '71 args.domainAddress b
    STSLICE                 	//  args.commonArgs.fromAddress payload.price args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69 '70 '71 b
    s1 s11 XCHG             	//  '71 payload.price args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69 '70 args.commonArgs.fromAddress b
    STSLICE                 	//  '71 payload.price args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69 '70 b
    s0 s9 XCHG2             	//  '71 '70 args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69 b payload.price
    STGRAMS                 	//  '71 '70 args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69 b
    b{00} STSLICECONST      	//  '71 '70 args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress commission '69 b
    ROT                     	//  '71 '70 args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress '69 b commission
    STGRAMS                 	//  '71 '70 args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress '69 b
    32 STU                  	//  '71 '70 args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId args.domainAddress b
    s1 s6 XCHG              	//  '71 args.domainAddress args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId '70 b
    32 STU                  	//  '71 args.domainAddress args.domainNameCell args.commonArgs.code payload.validUntil args.commonArgs.queryId b
    s1 s2 XCHG              	//  '71 args.domainAddress args.domainNameCell args.commonArgs.code args.commonArgs.queryId payload.validUntil b
    32 STU                  	//  '71 args.domainAddress args.domainNameCell args.commonArgs.code args.commonArgs.queryId b
    s1 s5 XCHG              	//  args.commonArgs.queryId args.domainAddress args.domainNameCell args.commonArgs.code '71 b
    STOPTREF                	//  args.commonArgs.queryId args.domainAddress args.domainNameCell args.commonArgs.code b
    s1 s2 XCHG              	//  args.commonArgs.queryId args.domainAddress args.commonArgs.code args.domainNameCell b
    STREF                   	//  args.commonArgs.queryId args.domainAddress args.commonArgs.code b
    0 PUSHINT
    64 STUR                 	//  args.commonArgs.queryId args.domainAddress args.commonArgs.code b
    ENDC                    	//  args.commonArgs.queryId args.domainAddress args.commonArgs.code data
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
        ONE HASHEXT_SHA256  	//  args.commonArgs.queryId args.domainAddress '94
    NEWC                    	//  args.commonArgs.queryId args.domainAddress '94 '93
    b{10000000000} STSLICECONST	//  args.commonArgs.queryId args.domainAddress '94 '93
    256 STU                 	//  args.commonArgs.queryId args.domainAddress saleAddress
    30000000 PUSHINT        	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000
    b{00} PUSHSLICE         	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '125
    PUSHNULL                	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '125 '126
    PUSHNULL                	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '125 '126 '128
    NEWC                    	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '125 '126 '128 refb
    x{5fcc3d140000000000000000} STSLICECONST	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '125 '126 '128 refb
    s5 PUSH                 	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '125 '126 '128 refb saleAddress
    STBR                    	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '125 '126 '128 refb
    s1 s3 XCHG              	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '128 '126 '125 refb
    STSLICE                 	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '128 '126 refb
    STOPTREF                	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '128 refb
    x{0} STSLICECONST       	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '128 refb
    STOPTREF                	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 refb
    ENDC                    	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '145
    NEWC                    	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '145 b
    b{010000} STSLICECONST  	//  args.commonArgs.queryId args.domainAddress saleAddress '114=30000000 '145 b
    s1 s4 XCHG              	//  args.commonArgs.queryId '145 saleAddress '114=30000000 args.domainAddress b
    STSLICE                 	//  args.commonArgs.queryId '145 saleAddress '114=30000000 b
    SWAP                    	//  args.commonArgs.queryId '145 saleAddress b '114=30000000
    STGRAMS                 	//  args.commonArgs.queryId '145 saleAddress b
    1 PUSHINT
    107 STUR                	//  args.commonArgs.queryId '145 saleAddress b
    s1 s2 XCHG              	//  args.commonArgs.queryId saleAddress '145 b
    STREF                   	//  args.commonArgs.queryId saleAddress b
    ENDC                    	//  args.commonArgs.queryId saleAddress '182
    0 PUSHINT               	//  args.commonArgs.queryId saleAddress '182 '183=0
    SENDRAWMSG              	//  args.commonArgs.queryId saleAddress
    65000000 PUSHINT        	//  args.commonArgs.queryId saleAddress '192
    NEWC                    	//  args.commonArgs.queryId saleAddress '192 b
    b{010000} STSLICECONST  	//  args.commonArgs.queryId saleAddress '192 b
    s1 s2 XCHG              	//  args.commonArgs.queryId '192 saleAddress b
    STB                     	//  args.commonArgs.queryId '192 b
    SWAP                    	//  args.commonArgs.queryId b '192
    STGRAMS                 	//  args.commonArgs.queryId b
    101311611 PUSHINT
    139 STUR                	//  args.commonArgs.queryId b
    64 STU                  	//  b
    ENDC                    	//  msg
    95000000 PUSHINT        	//  msg '262
    SWAP
    1 PUSHINT               	//  '262 msg '263=1
    SENDMSG                 	//  '262 '264
    ADD                     	//  '265
}>c PUSHREF""";
 

fun onInternalMessage(): void {
}

get fun getDeployFunctionCell(): cell {
    return deployFunctionCell();
}