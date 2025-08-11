
fun deployFunctionCell(): cell 
    asm """<{
    DECLPROC builder.storeStrFloat()
      DECLPROC builder.storeStrJettons()
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
        2 LDU                   	//  '5 s
        LDGRAMS                 	//  '5 '6 s
        LDGRAMS                 	//  '5 '6 '7 s
        32 LDU                  	//  '5 '6 '7 '9 s
        LDMSGADDR               	//  '5 '6 '7 '9 '10 s
        LDMSGADDR               	//  '5 '6 '7 '9 '10 '11 s
        1 LDI                   	//  '5 '6 '7 '9 '10 '11 '13 s
        LDGRAMS                 	//  '5 '6 '7 '9 '10 '11 '13 '14 s
        32 LDU                  	//  '5 '6 '7 '9 '10 '11 '13 '14 '16 s
        LDREF                   	//  '5 '6 '7 '9 '10 '11 '13 '14 '16 '17 s
        ENDS                    	//  '5 '6 '7 '9 '10 '11 '13 '14 '16 '17
      }>
      Storage.save() PROCINLINE:<{	//  self.state self.price self.commission self.validUntil self.sellerAddress self.jettonWalletAddress self.cancelledBySeller self.sellerPrice self.createdAt self.ds2
        s0 s9 XCHG
        NEWC                    	//  self.ds2 self.price self.commission self.validUntil self.sellerAddress self.jettonWalletAddress self.cancelledBySeller self.sellerPrice self.createdAt self.state b
        2 STU                   	//  self.ds2 self.price self.commission self.validUntil self.sellerAddress self.jettonWalletAddress self.cancelledBySeller self.sellerPrice self.createdAt b
        s0 s8 XCHG2             	//  self.ds2 self.createdAt self.commission self.validUntil self.sellerAddress self.jettonWalletAddress self.cancelledBySeller self.sellerPrice b self.price
        STGRAMS                 	//  self.ds2 self.createdAt self.commission self.validUntil self.sellerAddress self.jettonWalletAddress self.cancelledBySeller self.sellerPrice b
        s0 s6 XCHG2             	//  self.ds2 self.createdAt self.sellerPrice self.validUntil self.sellerAddress self.jettonWalletAddress self.cancelledBySeller b self.commission
        STGRAMS                 	//  self.ds2 self.createdAt self.sellerPrice self.validUntil self.sellerAddress self.jettonWalletAddress self.cancelledBySeller b
        s1 s4 XCHG              	//  self.ds2 self.createdAt self.sellerPrice self.cancelledBySeller self.sellerAddress self.jettonWalletAddress self.validUntil b
        32 STU                  	//  self.ds2 self.createdAt self.sellerPrice self.cancelledBySeller self.sellerAddress self.jettonWalletAddress b
        s1 s2 XCHG              	//  self.ds2 self.createdAt self.sellerPrice self.cancelledBySeller self.jettonWalletAddress self.sellerAddress b
        STSLICE                 	//  self.ds2 self.createdAt self.sellerPrice self.cancelledBySeller self.jettonWalletAddress b
        STSLICE                 	//  self.ds2 self.createdAt self.sellerPrice self.cancelledBySeller b
        1 STI                   	//  self.ds2 self.createdAt self.sellerPrice b
        SWAP                    	//  self.ds2 self.createdAt b self.sellerPrice
        STGRAMS                 	//  self.ds2 self.createdAt b
        32 STU                  	//  self.ds2 b
        STREF                   	//  b
        ENDC                    	//  '15
        c4 POP                  	// 
      }>

    // Main deploy function content:
	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3
    DUP                     	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 args.isWeb3
    IF:<{                   	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3
      x{800DAE17C1207C7BA7C4A480F975A3B953AD3F6CCA249D4E97E33A88F2EF1E5DB17_} PUSHSLICE	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress
      x{205745423320666f7220} PUSHSLICE	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix
      1000 PUSHINT          	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix oneJetton=1000
      s0 s11 XCHG           	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix args.commonArgs.deployInfoSlice
      PLDREF                	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix '23
      CTOS                  	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix s
      LDGRAMS               	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix '28 s
      16 LDU                	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix '28 '30 s
      LDGRAMS               	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix '28 '30 '31 s
      32 LDU                	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix '28 '30 '31 '33 s
      ENDS                  	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
      s12 PUSH              	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration args.commonArgs.commissionDiscount
      0 NEQINT              	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration '35
      IF:<{                 	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
        10000 PUSHINT
        s13 POP             	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount=10000 args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
      }>                    	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
    }>ELSE<{                	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3
      x{801622753296A04942CE33ED2272651D6EB2B2D87144BEB2051628DFD9B86C43BFD_} PUSHSLICE	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress
      x{205553445420666f7220} PUSHSLICE	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix
      1000000 PUSHINT       	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice s args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix oneJetton=1000000
      s0 s11 XCHG           	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix s
      LDGRAMS               	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix '43 s
      16 LDU                	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix '43 '45 s
      LDGRAMS               	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix '43 '45 '46 s
      32 PLDU               	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice oneJetton=1000000 args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
    }>                      	//  args.commonArgs.fromAddress s oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
    s0 s15 XCHG             	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission s
    32 LDU                  	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission '57 s
    LDMSGADDR               	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission '57 '58 s
    1 LDI                   	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission '57 '58 '60 s
    LDREF                   	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission '57 '58 '60 '61 s
    ENDS                    	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller payload.domainNameCell
    s0 s12 XCHG             	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller args.commonArgs.contractCodes
    CTOS                    	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller lazyS
    NOW                     	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller lazyS '71
    SWAP                    	//  args.commonArgs.fromAddress deployInfo.minDuration oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '71 lazyS
    s0 19 s() XCHG          	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '71 deployInfo.minDuration
    ADD                     	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '72
    s3 PUSH                 	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '72 payload.validUntil
    LEQ                     	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '73
    IF:<{                   	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller
      NOW                   	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '75
      2592000 PUSHINT       	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '75 '82
      ADD                   	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '83
      s3 PUSH               	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '83 payload.validUntil
      GEQ                   	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '84
      0 NEQINT              	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '74
    }>ELSE<{                	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller
      0 PUSHINT             	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '74=0
    }>
    72 THROWIFNOT           	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller
    10000 PUSHINT           	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress payload.notifySeller '90=10000
    s0 s15 XCHG2            	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress '90=10000 args.commonArgs.commissionDiscount
    SUB                     	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress commissionDiscountFactor
    s4 s4 XCPU
    10000 PUSHINT           	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice commissionDiscountFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress deployInfo.commissionFactor commissionDiscountFactor '93=10000
    MULDIV                  	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice commissionDiscountFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress commissionFactor
    10000 PUSHINT           	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice commissionDiscountFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress commissionFactor '96=10000
    OVER                    	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice commissionDiscountFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress commissionFactor '96=10000 commissionFactor
    ADD                     	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice commissionDiscountFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress commissionFactor '97
    s10 PUSH
    -ROT                    	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice commissionDiscountFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress args.transferredJettons commissionFactor '97
    MULDIV                  	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice commissionDiscountFactor deployInfo.maxCommission payload.validUntil payload.sellerAddress '98
    s3 s4 XCHG2
    10000 PUSHINT           	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice '98 payload.sellerAddress payload.validUntil deployInfo.maxCommission commissionDiscountFactor '99=10000
    MULDIV                  	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice '98 payload.sellerAddress payload.validUntil '100
    s1 s3 XCHG              	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice payload.validUntil payload.sellerAddress '98 '100
    MIN                     	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice payload.validUntil payload.sellerAddress commission
    s7 s0 PUSH2             	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice payload.validUntil payload.sellerAddress commission args.transferredJettons commission
    SUB                     	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix deployInfo.minPrice payload.validUntil payload.sellerAddress commission price
    s0 s4 PUXC              	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission price deployInfo.minPrice
    GEQ                     	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '105
    70 THROWIFNOT           	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission
    228000000 PUSHINT       	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code payload.notifySeller args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission requiredGas
    s0 s13 XCHG             	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission payload.notifySeller
    IF:<{                   	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission
      b{00} PUSHSLICE       	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '122
      s2 PUSH               	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '122 payload.sellerAddress
      SDEQ                  	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '123
      55 THROWIF            	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission
      100000000 PUSHINT     	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '127=100000000
      NEWC                  	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '127=100000000 '138
      x{00000000} STSLICECONST	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '127=100000000 '138
      x{4e6577206f66666572206f6e20776562646f6d2e6d61726b65742120} PUSHSLICE	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '127=100000000 '138 '141
      STSLICER              	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '127=100000000 '138
      s5 s1 PUXC            	//  args.commonArgs.fromAddress lazyS oneJetton args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '138 price '127=100000000
      s0 17 s() XCHG        	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '138 price oneJetton
      builder.storeStrFloat() INLINECALLDICT	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '143 '144
      NIP                   	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress jettonPostfix price payload.validUntil payload.sellerAddress commission '145
      s1 s5 XCHG            	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress jettonPostfix '145
      STSLICE               	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress '145
      s9 PUSH               	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress '145 payload.domainNameCell
      STREFR                	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress '145
      ENDC                  	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress '148
      NEWC                  	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress '148 b
      b{010000} STSLICECONST	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress '148 b
      s2 PUSH               	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress '148 b payload.sellerAddress
      STSLICER              	//  args.commonArgs.fromAddress lazyS '127=100000000 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress '148 b
      s0 s15 XCHG2          	//  args.commonArgs.fromAddress lazyS '148 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress b '127=100000000
      STGRAMS               	//  args.commonArgs.fromAddress lazyS '148 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress b
      1 PUSHINT
      107 STUR              	//  args.commonArgs.fromAddress lazyS '148 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.sellerAddress b
      s1 s14 XCHG           	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil '148 b
      STREF                 	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil b
      ENDC                  	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil deployMsg
      1 PUSHINT             	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil deployMsg '198=1
      SENDMSG               	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil '199
      100000000 PUSHINT     	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil '199 '200=100000000
      ADD                   	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil '201
      s1 s11 XCHG           	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code payload.validUntil args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price requiredGas '201
      ADD                   	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code payload.validUntil args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price requiredGas
      s0 s10 XCHG           	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil
    }>ELSE<{
      s4 POP
      s13 POP               	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil
    }>
    s7 PUSH                 	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil payload.domainNameCell
    CTOS                    	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice
    DUP
    40 PUSHINT              	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice domainNameSlice '215
    SDCUTLAST               	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice '216
    x{2e742e6d65} PUSHSLICE 	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice '216 '217
    SDEQ                    	//  args.commonArgs.fromAddress lazyS payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice isTgUsername
    s0 s15 XCHG             	//  args.commonArgs.fromAddress isTgUsername payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice lazyS
    LDREF                   	//  args.commonArgs.fromAddress isTgUsername payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice contractCodes.domainCode lazyS
    LDREF                   	//  args.commonArgs.fromAddress isTgUsername payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice contractCodes.domainCode contractCodes.tgUsernameCode lazyS
    LDREF                   	//  args.commonArgs.fromAddress isTgUsername payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice contractCodes.domainCode contractCodes.tgUsernameCode contractCodes.web3WalletCode lazyS
    PLDREF                  	//  args.commonArgs.fromAddress isTgUsername payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice contractCodes.domainCode contractCodes.tgUsernameCode contractCodes.web3WalletCode contractCodes.usdtWalletCode
    s0 18 s() XCHG          	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice contractCodes.domainCode contractCodes.tgUsernameCode contractCodes.web3WalletCode isTgUsername
    IF:<{                   	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice contractCodes.domainCode contractCodes.tgUsernameCode contractCodes.web3WalletCode
      s2 POP                	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice contractCodes.web3WalletCode contractCodes.tgUsernameCode
      s0 s2 XCHG
      40 PUSHINT            	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode domainNameSlice '226
      SDSKIPLAST            	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode domainNameSlice
      SHA256U               	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode usernameIndex
      NEWC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode usernameIndex '232
      SWAP
      NEWC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode '232 usernameIndex '233
      256 STU               	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode '232 '233
      x{80101AF146BF2AB4296CF3F5510FFE99AB7F81E876949DD454FCD24FE6E0364E785_} PUSHSLICE	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode '232 '233 '236
      STSLICER              	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode '232 '233
      ENDC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode '232 '238
      STREFR                	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode '232
      b{0} STSLICECONST     	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode '232
      ENDC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.tgUsernameCode contractCodes.web3WalletCode data
      s1 s2 XCHG            	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode contractCodes.tgUsernameCode data
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
          ONE HASHEXT_SHA256	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode '254
      NEWC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode '254 '253
      b{10000000000} STSLICECONST	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode '254 '253
      256 STU               	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode domainAddressBuilder
    }>ELSE<{                	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice contractCodes.domainCode contractCodes.tgUsernameCode contractCodes.web3WalletCode
      NIP                   	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil domainNameSlice contractCodes.domainCode contractCodes.web3WalletCode
      s0 s2 XCHG
      32 PUSHINT            	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode contractCodes.domainCode domainNameSlice '275
      SDSKIPLAST            	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode contractCodes.domainCode domainNameSlice
      HASHSU                	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode contractCodes.domainCode domainIndex
      NEWC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode contractCodes.domainCode domainIndex '281
      256 STU               	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode contractCodes.domainCode '281
      x{8016EE9B2BD640A87E30D80D66E357115AE09EFC4AC26195F2C3126D14FA196D99F_} PUSHSLICE	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode contractCodes.domainCode '281 '284
      STSLICER              	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode contractCodes.domainCode '281
      ENDC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode contractCodes.domainCode data
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
          ONE HASHEXT_SHA256	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode '297
      NEWC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode '297 '296
      b{10000000000} STSLICECONST	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode '297 '296
      256 STU               	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode domainAddressBuilder
    }>
    NEWC                    	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode domainAddressBuilder '318
    b{00} STSLICECONST      	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission price payload.validUntil contractCodes.web3WalletCode domainAddressBuilder '318
    s0 s4 XCHG2             	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission domainAddressBuilder payload.validUntil contractCodes.web3WalletCode '318 price
    STGRAMS                 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress commission domainAddressBuilder payload.validUntil contractCodes.web3WalletCode '318
    s0 s4 XCHG2             	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode domainAddressBuilder payload.validUntil '318 commission
    STGRAMS                 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode domainAddressBuilder payload.validUntil '318
    32 STU                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode payload.sellerAddress args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode domainAddressBuilder '318
    s1 s12 XCHG             	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode domainAddressBuilder args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode payload.sellerAddress '318
    STSLICE                 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode domainAddressBuilder args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode '318
    b{0000000} STSLICECONST 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode domainAddressBuilder args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode '318
    NOW                     	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode domainAddressBuilder args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode '318 '329
    32 STUR                 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode domainAddressBuilder args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode '318
    s0 s11 XCHG
    NEWC                    	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode domainAddressBuilder '332
    STB                     	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode '332
    s13 PUSH                	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode '332 args.commonArgs.fromAddress
    STSLICER                	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 jettonMinterAddress contractCodes.web3WalletCode '332
    s1 s2 XCHG              	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 contractCodes.web3WalletCode jettonMinterAddress '332
    STSLICE                 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey payload.domainNameCell args.jettonWalletAddress args.transferredJettons args.isWeb3 contractCodes.web3WalletCode '332
    s1 s5 XCHG              	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey contractCodes.web3WalletCode args.jettonWalletAddress args.transferredJettons args.isWeb3 payload.domainNameCell '332
    STREF                   	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.commonArgs.publicKey contractCodes.web3WalletCode args.jettonWalletAddress args.transferredJettons args.isWeb3 '332
    s0 s5 XCHG
    NEWC                    	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId '332 contractCodes.web3WalletCode args.jettonWalletAddress args.transferredJettons args.isWeb3 args.commonArgs.publicKey b
    256 STU                 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId '332 contractCodes.web3WalletCode args.jettonWalletAddress args.transferredJettons args.isWeb3 b
    ENDC                    	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId '332 contractCodes.web3WalletCode args.jettonWalletAddress args.transferredJettons args.isWeb3 '340
    s0 s5 XCHG2             	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress args.transferredJettons '340 '332
    STOPTREF                	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress args.transferredJettons '332
    ENDC                    	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode '318 args.commonArgs.code requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress args.transferredJettons '342
    s0 s8 XCHG2             	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons args.commonArgs.code requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress '342 '318
    STREF                   	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons args.commonArgs.code requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress '318
    ENDC                    	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2
    s6 s0 PUSH2             	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 '363
    NEWC                    	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 '363 '362
    b{10000000000} STSLICECONST	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 '363 '362
    256 STU                 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder
    178000000 PUSHINT       	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '394
    NEWC                    	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '394 '399
    x{0609e47b} STSLICECONST	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '394 '399
    s7 PUSH                 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '394 '399 args.commonArgs.queryId
    64 STUR                 	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId args.isWeb3 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '394 '399
    s0 s6 XCHG              	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '394 args.isWeb3
    IF:<{                   	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '394
      s10 POP               	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder
      NEWC                  	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '407
      x{0} STSLICECONST     	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '407
      OVER                  	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '407 offerAddressBuilder
      STBR                  	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '407
      x{800DAE17C1207C7BA7C4A480F975A3B953AD3F6CCA249D4E97E33A88F2EF1E5DB17_} PUSHSLICE	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '407 '411
      STSLICER              	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '407
      s4 PUSH               	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '407 contractCodes.web3WalletCode
      STREFR                	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '407
      ENDC                  	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder data
      s1 s4 XCHG            	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 offerAddressBuilder args.jettonWalletAddress offerAddress.stateInit.USlot2 contractCodes.web3WalletCode data
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
          ONE HASHEXT_SHA256	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 offerAddressBuilder args.jettonWalletAddress offerAddress.stateInit.USlot2 '425
      NEWC                  	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 offerAddressBuilder args.jettonWalletAddress offerAddress.stateInit.USlot2 '425 '424
      b{10000000000} STSLICECONST	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 offerAddressBuilder args.jettonWalletAddress offerAddress.stateInit.USlot2 '425 '424
      256 STU               	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 offerAddressBuilder args.jettonWalletAddress offerAddress.stateInit.USlot2 '404
    }>ELSE<{                	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 contractCodes.web3WalletCode args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '394
      s4 POP                	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder
      NEWC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '447
      x{00} STSLICECONST    	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '447
      OVER                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '447 offerAddressBuilder
      STBR                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '447
      x{801622753296A04942CE33ED2272651D6EB2B2D87144BEB2051628DFD9B86C43BFD_} PUSHSLICE	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '447 '451
      STSLICER              	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder '447
      ENDC                  	//  args.commonArgs.fromAddress contractCodes.usdtWalletCode args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 offerAddressBuilder data
      s1 s10 XCHG           	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 contractCodes.usdtWalletCode data
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
          ONE HASHEXT_SHA256	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 '464
      NEWC                  	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 '464 '463
      b{10000000000} STSLICECONST	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 '464 '463
      256 STU               	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 '394 args.jettonWalletAddress offerAddress.stateInit.USlot2 '404
      s3 s9 XCHG            	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId '399 offerAddressBuilder args.jettonWalletAddress offerAddress.stateInit.USlot2 '404
    }>
    s0 s4 XCHG2             	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress '404 '399
    STB                     	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress '399
    ENDC                    	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress '484
    NEWC                    	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress '484 b
    b{01000010000000000} STSLICECONST	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress '484 b
    s7 s4 PUSH2             	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress '484 b offerAddress.stateInit.USlot1 offerAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress '484 b '506
    256 STUR                	//  args.commonArgs.fromAddress '394 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress '484 b
    s0 s9 XCHG2             	//  args.commonArgs.fromAddress '484 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress b '394
    STGRAMS                 	//  args.commonArgs.fromAddress '484 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress b
    141 PUSHINT
    113 STUR                	//  args.commonArgs.fromAddress '484 args.transferredJettons offerAddress.stateInit.USlot1 requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder args.jettonWalletAddress b
    s1 s6 XCHG              	//  args.commonArgs.fromAddress '484 args.transferredJettons args.jettonWalletAddress requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder offerAddress.stateInit.USlot1 b
    STREF                   	//  args.commonArgs.fromAddress '484 args.transferredJettons args.jettonWalletAddress requiredGas args.commonArgs.queryId offerAddress.stateInit.USlot2 offerAddressBuilder b
    s1 s2 XCHG              	//  args.commonArgs.fromAddress '484 args.transferredJettons args.jettonWalletAddress requiredGas args.commonArgs.queryId offerAddressBuilder offerAddress.stateInit.USlot2 b
    STREF                   	//  args.commonArgs.fromAddress '484 args.transferredJettons args.jettonWalletAddress requiredGas args.commonArgs.queryId offerAddressBuilder b
    s1 s6 XCHG              	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress requiredGas args.commonArgs.queryId '484 b
    STREF                   	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress requiredGas args.commonArgs.queryId b
    ENDC                    	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress requiredGas args.commonArgs.queryId deployMsg
    1 PUSHINT               	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress requiredGas args.commonArgs.queryId deployMsg '534=1
    SENDMSG                 	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress requiredGas args.commonArgs.queryId '535
    s1 s2 XCHG              	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress args.commonArgs.queryId requiredGas '535
    ADD                     	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress args.commonArgs.queryId requiredGas
    50000000 PUSHINT        	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress args.commonArgs.queryId requiredGas '538=50000000
    PUSHNULL                	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress args.commonArgs.queryId requiredGas '538=50000000 '548
    PUSHNULL                	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress args.commonArgs.queryId requiredGas '538=50000000 '548 '550
    NEWC                    	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress args.commonArgs.queryId requiredGas '538=50000000 '548 '550 refb
    x{0f8a7ea5} STSLICECONST	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress args.commonArgs.queryId requiredGas '538=50000000 '548 '550 refb
    s1 s5 XCHG              	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress '550 requiredGas '538=50000000 '548 args.commonArgs.queryId refb
    64 STU                  	//  args.commonArgs.fromAddress offerAddressBuilder args.transferredJettons args.jettonWalletAddress '550 requiredGas '538=50000000 '548 refb
    s0 s6 XCHG2             	//  args.commonArgs.fromAddress offerAddressBuilder '548 args.jettonWalletAddress '550 requiredGas '538=50000000 refb args.transferredJettons
    STGRAMS                 	//  args.commonArgs.fromAddress offerAddressBuilder '548 args.jettonWalletAddress '550 requiredGas '538=50000000 refb
    s1 s6 XCHG              	//  args.commonArgs.fromAddress '538=50000000 '548 args.jettonWalletAddress '550 requiredGas offerAddressBuilder refb
    STB                     	//  args.commonArgs.fromAddress '538=50000000 '548 args.jettonWalletAddress '550 requiredGas refb
    s1 s6 XCHG              	//  requiredGas '538=50000000 '548 args.jettonWalletAddress '550 args.commonArgs.fromAddress refb
    STSLICE                 	//  requiredGas '538=50000000 '548 args.jettonWalletAddress '550 refb
    s1 s3 XCHG              	//  requiredGas '538=50000000 '550 args.jettonWalletAddress '548 refb
    STOPTREF                	//  requiredGas '538=50000000 '550 args.jettonWalletAddress refb
    x{0} STSLICECONST       	//  requiredGas '538=50000000 '550 args.jettonWalletAddress refb
    s1 s2 XCHG              	//  requiredGas '538=50000000 args.jettonWalletAddress '550 refb
    STOPTREF                	//  requiredGas '538=50000000 args.jettonWalletAddress refb
    ENDC                    	//  requiredGas '538=50000000 args.jettonWalletAddress '567
    NEWC                    	//  requiredGas '538=50000000 args.jettonWalletAddress '567 b
    b{010000} STSLICECONST  	//  requiredGas '538=50000000 args.jettonWalletAddress '567 b
    s1 s2 XCHG              	//  requiredGas '538=50000000 '567 args.jettonWalletAddress b
    STSLICE                 	//  requiredGas '538=50000000 '567 b
    ROT                     	//  requiredGas '567 b '538=50000000
    STGRAMS                 	//  requiredGas '567 b
    1 PUSHINT
    107 STUR                	//  requiredGas '567 b
    STREF                   	//  requiredGas b
    ENDC                    	//  requiredGas '604
    0 PUSHINT               	//  requiredGas '604 '605=0
    SENDRAWMSG              	//  requiredGas
}>c PUSHREF""";
 

fun onInternalMessage(): void {
}

get fun getDeployFunctionCell(): cell {
    return deployFunctionCell();
}