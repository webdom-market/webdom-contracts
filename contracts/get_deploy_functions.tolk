
fun deployFunctionCell(): cell 
    asm """<{
    DECLPROC builder.storeStrFloat()
      DECLPROC builder.storeStrJettons()
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
        LDREF                   	//  '4 '5 '7 '9 '10 '11 '13 '15 '17 '19 '20 '22 '24 '25 '26 s
        ENDS                    	//  '4 '5 '7 '9 '10 '11 '13 '15 '17 '19 '20 '22 '24 '25 '26
      }>
      Storage.save() PROCINLINE:<{	//  self.sellerAddress self.domainsDict self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.coloredUntil self.buyerAddressCell self.jettonMinterAddressCell
        s0 s14 XCHG
        NEWC                    	//  self.jettonMinterAddressCell self.domainsDict self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.coloredUntil self.buyerAddressCell self.sellerAddress b
        STSLICE                 	//  self.jettonMinterAddressCell self.domainsDict self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.coloredUntil self.buyerAddressCell b
        s1 s13 XCHG             	//  self.jettonMinterAddressCell self.buyerAddressCell self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.coloredUntil self.domainsDict b
        STOPTREF                	//  self.jettonMinterAddressCell self.buyerAddressCell self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.coloredUntil b
        s1 s11 XCHG             	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.domainsTotal b
        8 STU                   	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil b
        s1 s9 XCHG              	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.domainsReceived b
        8 STU                   	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress b
        s0 s7 XCHG2             	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.jettonWalletAddress self.commission self.state self.createdAt self.lastRenewalTime self.validUntil b self.price
        STGRAMS                 	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.jettonWalletAddress self.commission self.state self.createdAt self.lastRenewalTime self.validUntil b
        s0 s5 XCHG2             	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.state self.createdAt self.lastRenewalTime b self.commission
        STGRAMS                 	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.state self.createdAt self.lastRenewalTime b
        s1 s3 XCHG              	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.lastRenewalTime self.createdAt self.state b
        2 STU                   	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.lastRenewalTime self.createdAt b
        32 STU                  	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.lastRenewalTime b
        32 STU                  	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil b
        32 STU                  	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil self.jettonWalletAddress b
        STSLICE                 	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil self.hotUntil b
        32 STU                  	//  self.jettonMinterAddressCell self.buyerAddressCell self.coloredUntil b
        32 STU                  	//  self.jettonMinterAddressCell self.buyerAddressCell b
        STREF                   	//  self.jettonMinterAddressCell b
        STREF                   	//  b
        ENDC                    	//  '25
        c4 POP                  	// 
      }>

    // Main deploy function content:
	//  args.fromAddress args.payloadSlice args.deployInfoSlice args.code args.commissionDiscount args.queryId args.publicKey args.contractCodes
    NIP                     	//  args.fromAddress lazyS args.deployInfoSlice args.code args.commissionDiscount args.queryId args.contractCodes
    s0 s5 XCHG              	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId lazyS
    1 LDI                   	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 lazyS
    LDOPTREF                	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses lazyS
    LDGRAMS                 	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price lazyS
    32 PLDU                 	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil
    s3 PUSH                 	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.isWeb3
    IF:<{                   	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil
      s0 s7 XCHG            	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price args.deployInfoSlice
      PLDREF                	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '28
      CTOS                  	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price s
      LDGRAMS               	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '33 s
      16 LDU                	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '33 '35 s
      LDGRAMS               	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '33 '35 '36 s
      32 LDU                	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '33 '35 '36 '38 s
      ENDS                  	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
      s8 PUSH               	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration args.commissionDiscount
      0 NEQINT              	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration '40
      IF:<{                 	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
        10000 PUSHINT
        s9 POP              	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount=10000 args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
      }>                    	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
    }>ELSE<{                	//  args.fromAddress args.contractCodes s args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil
      s0 s7 XCHG            	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price s
      LDGRAMS               	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '45 s
      16 LDU                	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '45 '47 s
      LDGRAMS               	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '45 '47 '48 s
      32 PLDU               	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
    }>
    s4 s3 PUXC              	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission payload.price deployInfo.minPrice
    GEQ                     	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission '52
    70 THROWIFNOT           	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission
    NOW                     	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission '55
    s0 s3 XCHG2             	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '55 deployInfo.minDuration
    ADD                     	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '56
    s9 PUSH                 	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '56 payload.validUntil
    LEQ                     	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '57
    IF:<{                   	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor
      NOW                   	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '59
      31622400 PUSHINT      	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '59 '66
      ADD                   	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '67
      86400 PUSHINT         	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '67 '72
      SUB                   	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '73
      s9 PUSH               	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '73 payload.validUntil
      GEQ                   	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '74
      0 NEQINT              	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '58
    }>ELSE<{                	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor
      0 PUSHINT             	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor '58=0
    }>
    49 THROWIFNOT           	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission deployInfo.commissionFactor
    s2 s(-1) PUXC
    10000 PUSHINT           	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission payload.price deployInfo.commissionFactor '80=10000
    MULDIV                  	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price deployInfo.maxCommission '81
    MIN                     	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '82
    10000 PUSHINT           	//  args.fromAddress args.contractCodes payload.validUntil args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price '82 '83=10000
    s0 s6 XCHG2             	//  args.fromAddress args.contractCodes payload.validUntil args.code '82 args.queryId payload.isWeb3 payload.domainsAddresses payload.price '83=10000 args.commissionDiscount
    SUB                     	//  args.fromAddress args.contractCodes payload.validUntil args.code '82 args.queryId payload.isWeb3 payload.domainsAddresses payload.price '84
    s1 s5 XCHG
    10000 PUSHINT           	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses '82 '84 '85=10000
    MULDIV                  	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission
    0 PUSHINT               	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal=0
    s2 PUSH
    267 PUSHINT             	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal=0 payload.domainsAddresses '92=267
    DICTMIN
    NULLSWAPIFNOT2          	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal=0 received domainAddress found
    WHILE:<{
    }>DO<{                  	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal received domainAddress
      s0 s2 XCHG            	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainAddress received domainsTotal
      INC                   	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainAddress received domainsTotal
      b{0} PUSHSLICE        	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainAddress received domainsTotal '99
      s1 s2 XCHG            	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainAddress domainsTotal received '99
      SDEQ                  	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainAddress domainsTotal '100
      47 THROWIFNOT         	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainAddress domainsTotal
      s1 s3 XCPU
      267 PUSHINT           	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal domainAddress payload.domainsAddresses '102=267
      DICTGETNEXT
      NULLSWAPIFNOT2        	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal received domainAddress found
    }>                      	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal received domainAddress
    2DROP                   	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal
    DUP                     	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal domainsTotal
    0 GTINT                 	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '108
    71 THROWIFNOT           	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal
    NOW                     	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113
    NOW                     	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114
    b{00} PUSHSLICE         	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115
    b{00} PUSHSLICE         	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '118
    NEWC                    	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '118 b
    STSLICE                 	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 b
    ENDC                    	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121
    s7 PUSH                 	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 payload.isWeb3
    IF:<{                   	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121
      x{800BCFB13B3494CA795F167E94C52640B273E64B78229A15DB992A844E26F351AE9_} PUSHSLICE	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 '123
      NEWC                  	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 '123 b
      STSLICE               	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 b
      ENDC                  	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 '122
    }>ELSE<{                	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121
      x{8014D1EFF27038AD5F4C11D80A60DDB3D9C5485BA4E2826E9EA6BAA56FBBFF4119B_} PUSHSLICE	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 '127
      NEWC                  	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 '127 b
      STSLICE               	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 b
      ENDC                  	//  args.fromAddress args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 '122
    }>
    s0 s14 XCHG
    NEWC                    	//  '122 args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 args.fromAddress b
    STSLICE                 	//  '122 args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 payload.domainsAddresses commission domainsTotal '113 '114 '115 '121 b
    s1 s7 XCHG              	//  '122 args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 '121 commission domainsTotal '113 '114 '115 payload.domainsAddresses b
    STOPTREF                	//  '122 args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 '121 commission domainsTotal '113 '114 '115 b
    s1 s4 XCHG              	//  '122 args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 '121 commission '115 '113 '114 domainsTotal b
    8 STU                   	//  '122 args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 '121 commission '115 '113 '114 b
    x{00} STSLICECONST      	//  '122 args.contractCodes payload.validUntil args.code payload.price args.queryId payload.isWeb3 '121 commission '115 '113 '114 b
    s0 s8 XCHG2             	//  '122 args.contractCodes payload.validUntil args.code '114 args.queryId payload.isWeb3 '121 commission '115 '113 b payload.price
    STGRAMS                 	//  '122 args.contractCodes payload.validUntil args.code '114 args.queryId payload.isWeb3 '121 commission '115 '113 b
    s0 s3 XCHG2             	//  '122 args.contractCodes payload.validUntil args.code '114 args.queryId payload.isWeb3 '121 '113 '115 b commission
    STGRAMS                 	//  '122 args.contractCodes payload.validUntil args.code '114 args.queryId payload.isWeb3 '121 '113 '115 b
    b{00} STSLICECONST      	//  '122 args.contractCodes payload.validUntil args.code '114 args.queryId payload.isWeb3 '121 '113 '115 b
    s1 s2 XCHG              	//  '122 args.contractCodes payload.validUntil args.code '114 args.queryId payload.isWeb3 '121 '115 '113 b
    32 STU                  	//  '122 args.contractCodes payload.validUntil args.code '114 args.queryId payload.isWeb3 '121 '115 b
    s1 s5 XCHG              	//  '122 args.contractCodes payload.validUntil args.code '115 args.queryId payload.isWeb3 '121 '114 b
    32 STU                  	//  '122 args.contractCodes payload.validUntil args.code '115 args.queryId payload.isWeb3 '121 b
    s1 s6 XCHG              	//  '122 args.contractCodes '121 args.code '115 args.queryId payload.isWeb3 payload.validUntil b
    32 STU                  	//  '122 args.contractCodes '121 args.code '115 args.queryId payload.isWeb3 b
    s1 s3 XCHG              	//  '122 args.contractCodes '121 args.code payload.isWeb3 args.queryId '115 b
    STSLICE                 	//  '122 args.contractCodes '121 args.code payload.isWeb3 args.queryId b
    0 PUSHINT
    64 STUR                 	//  '122 args.contractCodes '121 args.code payload.isWeb3 args.queryId b
    s1 s4 XCHG              	//  '122 args.contractCodes args.queryId args.code payload.isWeb3 '121 b
    STREF                   	//  '122 args.contractCodes args.queryId args.code payload.isWeb3 b
    s1 s5 XCHG              	//  payload.isWeb3 args.contractCodes args.queryId args.code '122 b
    STREF                   	//  payload.isWeb3 args.contractCodes args.queryId args.code b
    ENDC                    	//  payload.isWeb3 args.contractCodes args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2
    2DUP                    	//  payload.isWeb3 args.contractCodes args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  payload.isWeb3 args.contractCodes args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '160
    NEWC                    	//  payload.isWeb3 args.contractCodes args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '160 '159
    b{10000000000} STSLICECONST	//  payload.isWeb3 args.contractCodes args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '160 '159
    256 STU                 	//  payload.isWeb3 args.contractCodes args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 saleAddressBuilder
    s0 s4 XCHG              	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 args.contractCodes
    CTOS                    	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 lazyS
    LDREF                   	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '187 lazyS
    NIP                     	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 lazyS
    LDREF                   	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '188 lazyS
    NIP                     	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 lazyS
    LDREF                   	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode lazyS
    PLDREF                  	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode
    50000000 PUSHINT        	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '193=50000000
    NEWC                    	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '193=50000000 '198
    x{0609e47b} STSLICECONST	//  payload.isWeb3 saleAddressBuilder args.queryId saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '193=50000000 '198
    s1 s6 XCHG              	//  payload.isWeb3 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode args.queryId '198
    64 STU                  	//  payload.isWeb3 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '198
    s0 s7 XCHG              	//  '198 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode payload.isWeb3
    IF:<{                   	//  '198 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode
      DROP                  	//  '198 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode
      NEWC                  	//  '198 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode '206
      x{0} STSLICECONST     	//  '198 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode '206
      s1 s5 XCHG            	//  '198 contractCodes.web3WalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 saleAddressBuilder '206
      STB                   	//  '198 contractCodes.web3WalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '206
      x{800BCFB13B3494CA795F167E94C52640B273E64B78229A15DB992A844E26F351AE9_} PUSHSLICE	//  '198 contractCodes.web3WalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '206 '210
      STSLICER              	//  '198 contractCodes.web3WalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '206
      s4 PUSH               	//  '198 contractCodes.web3WalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '206 contractCodes.web3WalletCode
      STREFR                	//  '198 contractCodes.web3WalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '206
      ENDC                  	//  '198 contractCodes.web3WalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 data
      s1 s4 XCHG            	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 contractCodes.web3WalletCode data
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
          ONE HASHEXT_SHA256	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 '224
      NEWC                  	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 '224 '223
      b{10000000000} STSLICECONST	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 '224 '223
      256 STU               	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 '203
    }>ELSE<{                	//  '198 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode
      NIP                   	//  '198 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.usdtWalletCode
      NEWC                  	//  '198 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.usdtWalletCode '246
      x{00} STSLICECONST    	//  '198 saleAddressBuilder '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 contractCodes.usdtWalletCode '246
      s1 s5 XCHG            	//  '198 contractCodes.usdtWalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 saleAddressBuilder '246
      STB                   	//  '198 contractCodes.usdtWalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '246
      x{8014D1EFF27038AD5F4C11D80A60DDB3D9C5485BA4E2826E9EA6BAA56FBBFF4119B_} PUSHSLICE	//  '198 contractCodes.usdtWalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '246 '250
      STSLICER              	//  '198 contractCodes.usdtWalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '246
      ENDC                  	//  '198 contractCodes.usdtWalletCode '193=50000000 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 data
      s1 s4 XCHG            	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 contractCodes.usdtWalletCode data
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
          ONE HASHEXT_SHA256	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 '263
      NEWC                  	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 '263 '262
      b{10000000000} STSLICECONST	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 '263 '262
      256 STU               	//  '198 saleAddress.stateInit.USlot2 '193=50000000 saleAddress.stateInit.USlot1 '203
    }>
    s0 s4 XCHG2             	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '193=50000000 '203 '198
    STB                     	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '193=50000000 '198
    ENDC                    	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '193=50000000 '283
    NEWC                    	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '193=50000000 '283 b
    b{01000010000000000} STSLICECONST	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '193=50000000 '283 b
    s4 s3 PUSH2             	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '193=50000000 '283 b saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '193=50000000 '283 b '305
    256 STUR                	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '193=50000000 '283 b
    ROT                     	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '283 b '193=50000000
    STGRAMS                 	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '283 b
    141 PUSHINT
    113 STUR                	//  saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2 '283 b
    s1 s3 XCHG              	//  '283 saleAddress.stateInit.USlot2 saleAddress.stateInit.USlot1 b
    STREF                   	//  '283 saleAddress.stateInit.USlot2 b
    STREF                   	//  '283 b
    STREF                   	//  b
    ENDC                    	//  msg
    50000000 PUSHINT        	//  msg '333=50000000
    SWAP
    1 PUSHINT               	//  '333=50000000 msg '334=1
    SENDMSG                 	//  '333=50000000 '335
    ADD                     	//  '336
}>c PUSHREF""";
 

fun onInternalMessage(): void {
}

get fun getDeployFunctionCell(): cell {
    return deployFunctionCell();
}