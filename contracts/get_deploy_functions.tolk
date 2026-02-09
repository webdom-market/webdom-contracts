
fun deployFunctionCell(): cell 
    asm """<{
    DECLPROC builder.storeStrFloat()
      DECLPROC builder.storeStrJettons()
      DECLPROC calculateWeb3WalletAddress()
      DECLPROC calculateUsdtWalletAddress()
      DECLPROC forceSameWorkchain()
      DECLPROC getPayoutNotificationBody()
      DECLPROC loadOpAndQueryId()
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
        x{800BCFB13B3494CA795F167E94C52640B273E64B78229A15DB992A844E26F351AE9_} PUSHSLICE	//  web3WalletCode '3 '7
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
      loadOpAndQueryId() PROCINLINE:<{	//  inMsgBody
        0 PUSHINT               	//  inMsgBody op=0
        s0 s1 PUSH2             	//  inMsgBody op=0 queryId=0 inMsgBody
        SBITS                   	//  inMsgBody op=0 queryId=0 '5
        31 GTINT                	//  inMsgBody op=0 queryId=0 '7
        IF:<{                   	//  inMsgBody op=0 queryId=0
          NIP                   	//  inMsgBody queryId=0
          SWAP                  	//  queryId=0 inMsgBody
          32 LDU                	//  queryId=0 op inMsgBody
          OVER                  	//  queryId=0 op inMsgBody op
          0 EQINT               	//  queryId=0 op inMsgBody '13
          IF:<{                 	//  queryId=0 op inMsgBody
            DUP
            x{63616e63656c} PUSHSLICE	//  queryId=0 op inMsgBody inMsgBody '15
            SDEQ                	//  queryId=0 op inMsgBody '16
            IF:<{               	//  queryId=0 op inMsgBody
              -1 PUSHINT        	//  queryId=0 op inMsgBody '17=-1
            }>ELSE<{            	//  queryId=0 op inMsgBody
              DUP
              x{73746f70} PUSHSLICE	//  queryId=0 op inMsgBody inMsgBody '19
              SDEQ              	//  queryId=0 op inMsgBody '20
              0 NEQINT          	//  queryId=0 op inMsgBody '17
            }>
            0 NEQINT            	//  queryId=0 op inMsgBody '14
          }>ELSE<{              	//  queryId=0 op inMsgBody
            s2 PUSH             	//  queryId=0 op inMsgBody '14=0
          }>
          IF:<{                 	//  queryId=0 op inMsgBody
            2393192597 PUSHINT
            s2 POP              	//  queryId=0 op=2393192597 inMsgBody
          }>                    	//  queryId=0 op inMsgBody
          OVER                  	//  queryId=0 op inMsgBody op
          0 NEQINT              	//  queryId=0 op inMsgBody '28
          IF:<{                 	//  queryId=0 op inMsgBody
            DUP                 	//  queryId=0 op inMsgBody inMsgBody
            SBITS               	//  queryId=0 op inMsgBody '30
            63 GTINT            	//  queryId=0 op inMsgBody '32
            0 NEQINT            	//  queryId=0 op inMsgBody '29
          }>ELSE<{              	//  queryId=0 op inMsgBody
            s2 PUSH             	//  queryId=0 op inMsgBody '29=0
          }>
          IF:<{                 	//  queryId=0 op inMsgBody
            1 2 BLKDROP2        	//  op inMsgBody
            64 LDU              	//  op queryId inMsgBody
            s1 s2 XCHG          	//  queryId op inMsgBody
          }>                    	//  queryId op inMsgBody
          s0 s2 XCHG            	//  inMsgBody op queryId
        }>                      	//  inMsgBody op queryId
      }>
      domainNameToAddress() PROCINLINE:<{	//  domainName domainCode
        SWAP                    	//  domainCode domainName
        HASHSU                  	//  domainCode domainIndex
        NEWC                    	//  domainCode domainIndex '5
        256 STU                 	//  domainCode '5
        x{801266F4F9970315CF7C6A89F6248C29AEDE38C16D877343F0F402CD339FB6114D1_} PUSHSLICE	//  domainCode '5 '8
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
        x{8007495287F55129699983DBD292B2CAE425A2659E0074CC60DFC1E236EF321FA85_} PUSHSLICE	//  tgUsernameCode '5 '6 '9
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
        LDOPTREF                	//  '4 '5 s
        8 LDU                   	//  '4 '5 '7 s
        8 LDU                   	//  '4 '5 '7 '9 s
        LDGRAMS                 	//  '4 '5 '7 '9 '10 s
        LDGRAMS                 	//  '4 '5 '7 '9 '10 '11 s
        2 LDU                   	//  '4 '5 '7 '9 '10 '11 '13 s
        32 LDU                  	//  '4 '5 '7 '9 '10 '11 '13 '15 s
        32 LDU                  	//  '4 '5 '7 '9 '10 '11 '13 '15 '17 s
        32 LDU                  	//  '4 '5 '7 '9 '10 '11 '13 '15 '17 '19 s
        LDMSGADDR               	//  '4 '5 '7 '9 '10 '11 '13 '15 '17 '19 '20 s
        32 LDU                  	//  '4 '5 '7 '9 '10 '11 '13 '15 '17 '19 '20 '22 s
        32 LDU                  	//  '4 '5 '7 '9 '10 '11 '13 '15 '17 '19 '20 '22 '24 s
        LDREF                   	//  '4 '5 '7 '9 '10 '11 '13 '15 '17 '19 '20 '22 '24 '25 s
        ENDS                    	//  '4 '5 '7 '9 '10 '11 '13 '15 '17 '19 '20 '22 '24 '25
      }>
      Storage.save() PROCINLINE:<{	//  self.sellerAddress self.domainsDict self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.buyerAddress self.hotUntil self.coloredUntil self.autoRenewData
        s0 s13 XCHG
        NEWC                    	//  self.autoRenewData self.domainsDict self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.buyerAddress self.hotUntil self.coloredUntil self.sellerAddress b
        STSLICE                 	//  self.autoRenewData self.domainsDict self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.buyerAddress self.hotUntil self.coloredUntil b
        s1 s12 XCHG             	//  self.autoRenewData self.coloredUntil self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.buyerAddress self.hotUntil self.domainsDict b
        STOPTREF                	//  self.autoRenewData self.coloredUntil self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.buyerAddress self.hotUntil b
        s1 s10 XCHG             	//  self.autoRenewData self.coloredUntil self.hotUntil self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.buyerAddress self.domainsTotal b
        8 STU                   	//  self.autoRenewData self.coloredUntil self.hotUntil self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.buyerAddress b
        s1 s8 XCHG              	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.domainsReceived b
        8 STU                   	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil b
        s0 s6 XCHG2             	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.validUntil self.commission self.state self.createdAt self.lastRenewalTime b self.price
        STGRAMS                 	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.validUntil self.commission self.state self.createdAt self.lastRenewalTime b
        s0 s4 XCHG2             	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.validUntil self.lastRenewalTime self.state self.createdAt b self.commission
        STGRAMS                 	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.validUntil self.lastRenewalTime self.state self.createdAt b
        s1 s2 XCHG              	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.validUntil self.lastRenewalTime self.createdAt self.state b
        2 STU                   	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.validUntil self.lastRenewalTime self.createdAt b
        32 STU                  	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.validUntil self.lastRenewalTime b
        32 STU                  	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress self.validUntil b
        32 STU                  	//  self.autoRenewData self.coloredUntil self.hotUntil self.buyerAddress b
        STSLICE                 	//  self.autoRenewData self.coloredUntil self.hotUntil b
        32 STU                  	//  self.autoRenewData self.coloredUntil b
        32 STU                  	//  self.autoRenewData b
        STREF                   	//  b
        ENDC                    	//  '24
        c4 POP                  	// 
      }>

    // Main deploy function content:
	//  args.fromAddress args.payloadSlice args.deployInfoSlice args.code args.commissionDiscount args.queryId args.publicKey args.contractCodes
    2DROP                   	//  args.fromAddress payloadSlice lazyS args.code args.commissionDiscount args.queryId
    s0 s4 XCHG              	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payloadSlice
    LDDICT                  	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount '24 payloadSlice
    LDGRAMS                 	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount '24 '27 payloadSlice
    32 LDU                  	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount '24 '27 '31 payloadSlice
    31536000 PUSHINT        	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount '24 '27 '31 payloadSlice '44
    0 PUSHINT               	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0
    s2 PUSH                 	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0 payloadSlice
    SBITS                   	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0 '46
    0 GTINT                 	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0 '48
    IF:<{                   	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0
      2DROP                 	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payloadSlice
      32 LDU                	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewCooldown payloadSlice
      8 PLDU                	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewCooldown payload.autoRenewIterations
      SWAP                  	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations payload.autoRenewCooldown
    }>ELSE<{
      s2 POP                	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations=0 payload.autoRenewCooldown
    }>
    s0 s7 XCHG              	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations lazyS
    LDGRAMS                 	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice lazyS
    16 LDU                  	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor lazyS
    LDGRAMS                 	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission lazyS
    32 PLDU                 	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
    s6 s3 PUXC              	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission payload.price deployInfo.minPrice
    GEQ                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission '64
    70 THROWIFNOT           	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission
    NOW                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission '67
    s0 s3 XCHG2             	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '67 deployInfo.minDuration
    ADD                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '68
    s4 PUSH                 	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '68 payload.validUntil
    LEQ                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '69
    IF:<{                   	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
      NOW                   	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '71
      31622400 PUSHINT      	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '71 '78
      ADD                   	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '79
      86400 PUSHINT         	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '79 '84
      SUB                   	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '85
      s4 PUSH               	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '85 payload.validUntil
      GEQ                   	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '86
      IF:<{                 	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
        -1 PUSHINT          	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '87=-1
      }>ELSE<{              	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
        s2 PUSH             	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor payload.autoRenewIterations
        0 GTINT             	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '90
        0 NEQINT            	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '87
      }>
      0 NEQINT              	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '70
    }>ELSE<{                	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
      0 PUSHINT             	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '70=0
    }>
    49 THROWIFNOT           	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
    s8 PUSH
    86400 PUSHINT           	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor payload.autoRenewCooldown '102
    GEQ                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '103
    IF:<{                   	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
      s8 PUSH
      31536000 PUSHINT      	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor payload.autoRenewCooldown '117
      LEQ                   	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '118
      0 NEQINT              	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '104
    }>ELSE<{                	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
      0 PUSHINT             	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '104=0
    }>
    49 THROWIFNOT           	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
    s4 s(-1) PUXC
    10000 PUSHINT           	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission payload.price deployInfo.commissionFactor '124=10000
    MULDIV                  	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission '125
    MIN                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '126
    10000 PUSHINT           	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code args.commissionDiscount payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '126 '127=10000
    s0 s6 XCHG2             	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code '126 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '127=10000 args.commissionDiscount
    SUB                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code '126 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '128
    s1 s5 XCHG
    10000 PUSHINT           	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil '126 '128 '129=10000
    MULDIV                  	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission
    0 PUSHINT               	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal=0
    s4 PUSH
    267 PUSHINT             	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal=0 payload.domainsAddresses '136=267
    DICTMIN
    NULLSWAPIFNOT2          	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal=0 received domainAddress found
    WHILE:<{
    }>DO<{                  	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal received domainAddress
      s0 s2 XCHG            	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainAddress received domainsTotal
      INC                   	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainAddress received domainsTotal
      b{0} PUSHSLICE        	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainAddress received domainsTotal '143
      s1 s2 XCHG            	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainAddress domainsTotal received '143
      SDEQ                  	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainAddress domainsTotal '144
      47 THROWIFNOT         	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainAddress domainsTotal
      s1 s5 XCPU
      267 PUSHINT           	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal domainAddress payload.domainsAddresses '146=267
      DICTGETNEXT
      NULLSWAPIFNOT2        	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal received domainAddress found
    }>                      	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal received domainAddress
    2DROP                   	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal
    DUP                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal domainsTotal
    0 GTINT                 	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '152
    71 THROWIFNOT           	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal
    35000000 PUSHINT        	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '156=35000000
    40000000 PUSHINT        	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '156=35000000 '157=40000000
    s2 PUSH                 	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '156=35000000 '157=40000000 domainsTotal
    MUL                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '156=35000000 '158
    ADD                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '155
    s6 PUSH                 	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '155 payload.autoRenewIterations
    MUL                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve
    100000000 PUSHINT       	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve '162=100000000
    s7 PUSH                 	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve '162=100000000 payload.autoRenewIterations
    MUL                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay
    NOW                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167
    NOW                     	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167 '168
    b{00} PUSHSLICE         	//  args.fromAddress args.queryId payload.autoRenewCooldown args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167 '168 '169
    s0 s12 XCHG
    NEWC                    	//  args.fromAddress args.queryId '169 args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167 '168 payload.autoRenewCooldown b
    32 STU                  	//  args.fromAddress args.queryId '169 args.code payload.autoRenewIterations payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167 '168 b
    s1 s10 XCHG             	//  args.fromAddress args.queryId '169 args.code '168 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167 payload.autoRenewIterations b
    8 STU                   	//  args.fromAddress args.queryId '169 args.code '168 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167 b
    ENDC                    	//  args.fromAddress args.queryId '169 args.code '168 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167 '176
    s0 s13 XCHG
    NEWC                    	//  '176 args.queryId '169 args.code '168 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167 args.fromAddress b
    STSLICE                 	//  '176 args.queryId '169 args.code '168 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '167 b
    s1 s8 XCHG              	//  '176 args.queryId '169 args.code '168 '167 payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay payload.domainsAddresses b
    STOPTREF                	//  '176 args.queryId '169 args.code '168 '167 payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay b
    s1 s3 XCHG              	//  '176 args.queryId '169 args.code '168 '167 payload.price payload.validUntil commission autoRenewPrepay autoRenewReserve domainsTotal b
    8 STU                   	//  '176 args.queryId '169 args.code '168 '167 payload.price payload.validUntil commission autoRenewPrepay autoRenewReserve b
    x{00} STSLICECONST      	//  '176 args.queryId '169 args.code '168 '167 payload.price payload.validUntil commission autoRenewPrepay autoRenewReserve b
    s0 s5 XCHG2             	//  '176 args.queryId '169 args.code '168 '167 autoRenewReserve payload.validUntil commission autoRenewPrepay b payload.price
    STGRAMS                 	//  '176 args.queryId '169 args.code '168 '167 autoRenewReserve payload.validUntil commission autoRenewPrepay b
    ROT                     	//  '176 args.queryId '169 args.code '168 '167 autoRenewReserve payload.validUntil autoRenewPrepay b commission
    STGRAMS                 	//  '176 args.queryId '169 args.code '168 '167 autoRenewReserve payload.validUntil autoRenewPrepay b
    b{00} STSLICECONST      	//  '176 args.queryId '169 args.code '168 '167 autoRenewReserve payload.validUntil autoRenewPrepay b
    s1 s4 XCHG              	//  '176 args.queryId '169 args.code '168 autoRenewPrepay autoRenewReserve payload.validUntil '167 b
    32 STU                  	//  '176 args.queryId '169 args.code '168 autoRenewPrepay autoRenewReserve payload.validUntil b
    s1 s4 XCHG              	//  '176 args.queryId '169 args.code payload.validUntil autoRenewPrepay autoRenewReserve '168 b
    32 STU                  	//  '176 args.queryId '169 args.code payload.validUntil autoRenewPrepay autoRenewReserve b
    s1 s3 XCHG              	//  '176 args.queryId '169 args.code autoRenewReserve autoRenewPrepay payload.validUntil b
    32 STU                  	//  '176 args.queryId '169 args.code autoRenewReserve autoRenewPrepay b
    s1 s4 XCHG              	//  '176 args.queryId autoRenewPrepay args.code autoRenewReserve '169 b
    STSLICE                 	//  '176 args.queryId autoRenewPrepay args.code autoRenewReserve b
    0 PUSHINT
    64 STUR                 	//  '176 args.queryId autoRenewPrepay args.code autoRenewReserve b
    s1 s5 XCHG              	//  autoRenewReserve args.queryId autoRenewPrepay args.code '176 b
    STREF                   	//  autoRenewReserve args.queryId autoRenewPrepay args.code b
    ENDC                    	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2
    50000000 PUSHINT        	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '202=50000000
    s5 PUSH                 	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '202=50000000 autoRenewReserve
    ADD                     	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '203
    NEWC                    	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '203 b
    b{01000010000000000} STSLICECONST	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '203 b
    2OVER                   	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '203 b saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '203 b '228
    256 STUR                	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '203 b
    SWAP                    	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 b '203
    STGRAMS                 	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 b
    140 PUSHINT
    113 STUR                	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 b
    s1 s2 XCHG              	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot2 saleAddress.stateInit.USlot1 b
    STREF                   	//  autoRenewReserve args.queryId autoRenewPrepay saleAddress.stateInit.USlot2 b
    STREF                   	//  autoRenewReserve args.queryId autoRenewPrepay b
    x{0609e47b} STSLICECONST	//  autoRenewReserve args.queryId autoRenewPrepay b
    s1 s2 XCHG              	//  autoRenewReserve autoRenewPrepay args.queryId b
    64 STU                  	//  autoRenewReserve autoRenewPrepay b
    ENDC                    	//  autoRenewReserve autoRenewPrepay msg
    50000000 PUSHINT        	//  autoRenewReserve autoRenewPrepay msg '259=50000000
    s0 s3 XCHG2             	//  msg autoRenewPrepay '259=50000000 autoRenewReserve
    ADD                     	//  msg autoRenewPrepay '260
    ADD                     	//  msg '261
    SWAP
    1 PUSHINT               	//  '261 msg '262=1
    SENDMSG                 	//  '261 '263
    ADD                     	//  '264
}>c PUSHREF""";
 

fun onInternalMessage(): void {
}

get fun getDeployFunctionCell(): cell {
    return deployFunctionCell();
}