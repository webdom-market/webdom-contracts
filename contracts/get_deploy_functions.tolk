
fun deployFunctionCell(): cell 
    asm """<{
    DECLPROC builder.storeStrFloat()
      DECLPROC builder.storeStrJettons()
      DECLPROC calculateWeb3WalletAddress()
      DECLPROC calculateUsdtWalletAddress()
      DECLPROC forceSameWorkchain()
      DECLPROC getPayoutNotificationBody()
      DECLPROC loadOpAndQueryId()
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
      Storage.load() PROC:<{      	// 
        c4 PUSH                 	//  '0
        CTOS                    	//  s
        LDMSGADDR               	//  '4 s
        LDREF                   	//  '4 '5 s
        LDMSGADDR               	//  '4 '5 '6 s
        LDREF                   	//  '4 '5 '6 '7 s
        2 LDU                   	//  '4 '5 '6 '7 '9 s
        32 LDU                  	//  '4 '5 '6 '7 '9 '11 s
        32 LDU                  	//  '4 '5 '6 '7 '9 '11 '13 s
        32 LDU                  	//  '4 '5 '6 '7 '9 '11 '13 '15 s
        LDGRAMS                 	//  '4 '5 '6 '7 '9 '11 '13 '15 '16 s
        1 LDI                   	//  '4 '5 '6 '7 '9 '11 '13 '15 '16 '18 s
        1 LDI                   	//  '4 '5 '6 '7 '9 '11 '13 '15 '16 '18 '20 s
        ENDS                    	//  '4 '5 '6 '7 '9 '11 '13 '15 '16 '18 '20
      }>
      Storage.save() PROC:<{      	//  self.leftParticipantAddress self.leftInfo self.rightParticipantAddress self.rightInfo self.state self.createdAt self.validUntil self.lastActionTime self.completionCommission self.needsAlert self.cancelledByLeft
        s0 s10 XCHG
        NEWC                    	//  self.cancelledByLeft self.leftInfo self.rightParticipantAddress self.rightInfo self.state self.createdAt self.validUntil self.lastActionTime self.completionCommission self.needsAlert self.leftParticipantAddress b
        STSLICE                 	//  self.cancelledByLeft self.leftInfo self.rightParticipantAddress self.rightInfo self.state self.createdAt self.validUntil self.lastActionTime self.completionCommission self.needsAlert b
        s1 s9 XCHG              	//  self.cancelledByLeft self.needsAlert self.rightParticipantAddress self.rightInfo self.state self.createdAt self.validUntil self.lastActionTime self.completionCommission self.leftInfo b
        STREF                   	//  self.cancelledByLeft self.needsAlert self.rightParticipantAddress self.rightInfo self.state self.createdAt self.validUntil self.lastActionTime self.completionCommission b
        s1 s7 XCHG              	//  self.cancelledByLeft self.needsAlert self.completionCommission self.rightInfo self.state self.createdAt self.validUntil self.lastActionTime self.rightParticipantAddress b
        STSLICE                 	//  self.cancelledByLeft self.needsAlert self.completionCommission self.rightInfo self.state self.createdAt self.validUntil self.lastActionTime b
        s1 s5 XCHG              	//  self.cancelledByLeft self.needsAlert self.completionCommission self.lastActionTime self.state self.createdAt self.validUntil self.rightInfo b
        STREF                   	//  self.cancelledByLeft self.needsAlert self.completionCommission self.lastActionTime self.state self.createdAt self.validUntil b
        s1 s3 XCHG              	//  self.cancelledByLeft self.needsAlert self.completionCommission self.lastActionTime self.validUntil self.createdAt self.state b
        2 STU                   	//  self.cancelledByLeft self.needsAlert self.completionCommission self.lastActionTime self.validUntil self.createdAt b
        32 STU                  	//  self.cancelledByLeft self.needsAlert self.completionCommission self.lastActionTime self.validUntil b
        32 STU                  	//  self.cancelledByLeft self.needsAlert self.completionCommission self.lastActionTime b
        32 STU                  	//  self.cancelledByLeft self.needsAlert self.completionCommission b
        SWAP                    	//  self.cancelledByLeft self.needsAlert b self.completionCommission
        STGRAMS                 	//  self.cancelledByLeft self.needsAlert b
        1 STI                   	//  self.cancelledByLeft b
        1 STI                   	//  b
        ENDC                    	//  '17
        c4 POP                  	// 
      }>

    // Main deploy function content:
  	//  args.fromAddress args.payloadSlice args.deployInfoSlice args.code args.commissionDiscount args.queryId args.publicKey args.contractCodes
    2DROP                   	//  args.fromAddress lazyS lazyS args.code args.commissionDiscount args.queryId
    s0 s4 XCHG              	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount lazyS
    LDOPTREF                	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.leftDomainsList lazyS
    LDGRAMS                 	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal lazyS
    LDMSGADDR               	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress lazyS
    LDOPTREF                	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList lazyS
    LDGRAMS                 	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal lazyS
    32 LDU                  	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil lazyS
    1 PLDI                  	//  args.fromAddress args.queryId lazyS args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil payload.needsAlert
    s0 s9 XCHG              	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil lazyS
    LDGRAMS                 	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission lazyS
    32 PLDU                 	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission deployInfo.minDuration
    NOW                     	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission deployInfo.minDuration '38
    ADD                     	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '39
    s2 PUSH                 	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '39 payload.validUntil
    LEQ                     	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '40
    IF:<{                   	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission
      NOW                   	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '42
      31622400 PUSHINT      	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '42 '49
      ADD                   	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '50
      86400 PUSHINT         	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '50 '55
      SUB                   	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '56
      s2 PUSH               	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '56 payload.validUntil
      GEQ                   	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '57
      0 NEQINT              	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '41
    }>ELSE<{                	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission
      0 PUSHINT             	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission '41=0
    }>
    49 THROWIFNOT           	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission
    0 PUSHINT               	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal=0
    s7 PUSH
    267 PUSHINT             	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal=0 payload.leftDomainsList '67=267
    DICTMIN
    NULLSWAPIFNOT2          	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal=0 received domainAddress found
    WHILE:<{
    }>DO<{                  	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal received domainAddress
      s0 s2 XCHG            	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission domainAddress received leftDomainsTotal
      INC                   	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission domainAddress received leftDomainsTotal
      b{0} PUSHSLICE        	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission domainAddress received leftDomainsTotal '74
      s1 s2 XCHG            	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission domainAddress leftDomainsTotal received '74
      SDEQ                  	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission domainAddress leftDomainsTotal '75
      47 THROWIFNOT         	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission domainAddress leftDomainsTotal
      s1 s8 XCPU
      267 PUSHINT           	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal domainAddress payload.leftDomainsList '77=267
      DICTGETNEXT
      NULLSWAPIFNOT2        	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal received domainAddress found
    }>                      	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal received domainAddress
    2DROP                   	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal
    0 PUSHINT               	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal=0
    s5 PUSH
    267 PUSHINT             	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal=0 payload.rightDomainsList '83=267
    DICTMIN
    NULLSWAPIFNOT2          	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal=0 received domainAddress found
    WHILE:<{
    }>DO<{                  	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal received domainAddress
      s0 s2 XCHG            	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal domainAddress received rightDomainsTotal
      INC                   	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal domainAddress received rightDomainsTotal
      b{0} PUSHSLICE        	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal domainAddress received rightDomainsTotal '90
      s1 s2 XCHG            	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal domainAddress rightDomainsTotal received '90
      SDEQ                  	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal domainAddress rightDomainsTotal '91
      47 THROWIFNOT         	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal domainAddress rightDomainsTotal
      s1 s6 XCPU
      267 PUSHINT           	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal domainAddress payload.rightDomainsList '93=267
      DICTGETNEXT
      NULLSWAPIFNOT2        	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal received domainAddress found
    }>                      	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal received domainAddress
    2DROP                   	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal
    2DUP                    	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal leftDomainsTotal rightDomainsTotal
    ADD                     	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal '98
    0 GTINT                 	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal '100
    71 THROWIFNOT           	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal
    10000 PUSHINT           	//  args.fromAddress args.queryId payload.needsAlert args.code args.commissionDiscount payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal rightDomainsTotal '102=10000
    s0 s10 XCHG2            	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal '102=10000 args.commissionDiscount
    SUB                     	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal '103
    s1 s2 XCHG
    10000 PUSHINT           	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil leftDomainsTotal deployInfo.completionCommission '103 '104=10000
    MULDIV                  	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil leftDomainsTotal deployInfo.completionCommission
    SWAP
    NEWC                    	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission leftDomainsTotal b
    8 STU                   	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission b
    x{00} STSLICECONST      	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal payload.leftDomainsList payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil deployInfo.completionCommission b
    s1 s7 XCHG              	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal deployInfo.completionCommission payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil payload.leftDomainsList b
    STOPTREF                	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal deployInfo.completionCommission payload.leftPaymentTotal payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal payload.validUntil b
    s0 s5 XCHG2             	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal b payload.leftPaymentTotal
    STGRAMS                 	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal b
    x{0} STSLICECONST       	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal b
    ENDC                    	//  args.fromAddress args.queryId payload.needsAlert args.code rightDomainsTotal deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal '113
    s0 s6 XCHG
    NEWC                    	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal rightDomainsTotal b
    8 STU                   	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal b
    x{00} STSLICECONST      	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress payload.rightDomainsList payload.rightPaymentTotal b
    s1 s2 XCHG              	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress payload.rightPaymentTotal payload.rightDomainsList b
    STOPTREF                	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress payload.rightPaymentTotal b
    SWAP                    	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress b payload.rightPaymentTotal
    STGRAMS                 	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress b
    x{0} STSLICECONST       	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress b
    ENDC                    	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress '120
    NOW                     	//  args.fromAddress args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress '120 '122
    s0 s9 XCHG
    NEWC                    	//  '122 args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress '120 args.fromAddress b
    STSLICE                 	//  '122 args.queryId payload.needsAlert args.code '113 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress '120 b
    s1 s5 XCHG              	//  '122 args.queryId payload.needsAlert args.code '120 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress '113 b
    STREF                   	//  '122 args.queryId payload.needsAlert args.code '120 deployInfo.completionCommission payload.validUntil payload.rightParticipantAddress b
    STSLICE                 	//  '122 args.queryId payload.needsAlert args.code '120 deployInfo.completionCommission payload.validUntil b
    s1 s3 XCHG              	//  '122 args.queryId payload.needsAlert args.code payload.validUntil deployInfo.completionCommission '120 b
    STREF                   	//  '122 args.queryId payload.needsAlert args.code payload.validUntil deployInfo.completionCommission b
    b{11} STSLICECONST      	//  '122 args.queryId payload.needsAlert args.code payload.validUntil deployInfo.completionCommission b
    s1 s6 XCHG              	//  deployInfo.completionCommission args.queryId payload.needsAlert args.code payload.validUntil '122 b
    32 STU                  	//  deployInfo.completionCommission args.queryId payload.needsAlert args.code payload.validUntil b
    32 STU                  	//  deployInfo.completionCommission args.queryId payload.needsAlert args.code b
    x{00000000} STSLICECONST	//  deployInfo.completionCommission args.queryId payload.needsAlert args.code b
    s4 PUSH                 	//  deployInfo.completionCommission args.queryId payload.needsAlert args.code b deployInfo.completionCommission
    STGRAMS                 	//  deployInfo.completionCommission args.queryId payload.needsAlert args.code b
    s2 PUSH                 	//  deployInfo.completionCommission args.queryId payload.needsAlert args.code b payload.needsAlert
    1 STIR                  	//  deployInfo.completionCommission args.queryId payload.needsAlert args.code b
    b{0} STSLICECONST       	//  deployInfo.completionCommission args.queryId payload.needsAlert args.code b
    ENDC                    	//  deployInfo.completionCommission args.queryId payload.needsAlert domainSwapAddress.stateInit.USlot1 domainSwapAddress.stateInit.USlot2
    40000000 PUSHINT        	//  deployInfo.completionCommission args.queryId payload.needsAlert domainSwapAddress.stateInit.USlot1 domainSwapAddress.stateInit.USlot2 '145=40000000
    s0 s3 XCHG              	//  deployInfo.completionCommission args.queryId '145=40000000 domainSwapAddress.stateInit.USlot1 domainSwapAddress.stateInit.USlot2 payload.needsAlert
    IF:<{                   	//  deployInfo.completionCommission args.queryId '145=40000000 domainSwapAddress.stateInit.USlot1 domainSwapAddress.stateInit.USlot2
      100000000 PUSHINT     	//  deployInfo.completionCommission args.queryId '145=40000000 domainSwapAddress.stateInit.USlot1 domainSwapAddress.stateInit.USlot2 '146=100000000
    }>ELSE<{                	//  deployInfo.completionCommission args.queryId '145=40000000 domainSwapAddress.stateInit.USlot1 domainSwapAddress.stateInit.USlot2
      0 PUSHINT             	//  deployInfo.completionCommission args.queryId '145=40000000 domainSwapAddress.stateInit.USlot1 domainSwapAddress.stateInit.USlot2 '146=0
    }>
    s1 s3 XCHG              	//  deployInfo.completionCommission args.queryId domainSwapAddress.stateInit.USlot2 domainSwapAddress.stateInit.USlot1 '145=40000000 '146
    ADD                     	//  deployInfo.completionCommission args.queryId domainSwapAddress.stateInit.USlot2 domainSwapAddress.stateInit.USlot1 '149
    s0 s4 XCHG2             	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 '149 deployInfo.completionCommission
    ADD                     	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 msgValue
    NEWC                    	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 msgValue b
    b{01000010000000000} STSLICECONST	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 msgValue b
    s4 s2 PUSH2             	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 msgValue b domainSwapAddress.stateInit.USlot1 domainSwapAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 msgValue b '177
    256 STUR                	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 msgValue b
    OVER                    	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 msgValue b msgValue
    STGRAMS                 	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 msgValue b
    140 PUSHINT
    113 STUR                	//  domainSwapAddress.stateInit.USlot1 args.queryId domainSwapAddress.stateInit.USlot2 msgValue b
    s1 s4 XCHG              	//  msgValue args.queryId domainSwapAddress.stateInit.USlot2 domainSwapAddress.stateInit.USlot1 b
    STREF                   	//  msgValue args.queryId domainSwapAddress.stateInit.USlot2 b
    STREF                   	//  msgValue args.queryId b
    x{0609e47b} STSLICECONST	//  msgValue args.queryId b
    64 STU                  	//  msgValue b
    ENDC                    	//  msgValue msg
    1 PUSHINT               	//  msgValue msg '208=1
    SENDMSG                 	//  msgValue '209
    ADD                     	//  '210
}>c PUSHREF""";
 

fun onInternalMessage(): void {
}

get fun getDeployFunctionCell(): cell {
    return deployFunctionCell();
}