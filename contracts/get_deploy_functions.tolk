
fun deployFunctionCell(): cell 
    asm """<{
    DECLPROC builder.storeStrFloat()
      DECLPROC builder.storeStrJettons()
      DECLPROC forceSameWorkchain()
      DECLPROC getPayoutNotificationBody()
      DECLPROC loadOpAndQueryId()
      DECLPROC checkTgUsername()
      DECLPROC Storage.load()
      DECLPROC Storage.save()
      DECLPROC domainRefillFee()
      DECLPROC cancelGasBudget()
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
      checkTgUsername() PROCINLINE:<{	//  domainNameCell
        CTOS                    	//  domainNameSlice
        DUP                     	//  domainNameSlice domainNameSlice
        SBITS                   	//  domainNameSlice '3
        39 GTINT                	//  domainNameSlice '7
        IF:<{                   	//  domainNameSlice
          40 PUSHINT            	//  domainNameSlice '11
          SDCUTLAST             	//  '12
          x{2e742e6d65} PUSHSLICE	//  '12 '13
          SDEQ                  	//  '14
          0 NEQINT              	//  '8
        }>ELSE<{                	//  domainNameSlice
          DROP                  	// 
          0 PUSHINT             	//  '8=0
        }>
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
      Storage.save() PROCINLINE:<{	//  self.sellerAddress self.domainsDict self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.coloredUntil self.ds2
        s0 s13 XCHG
        NEWC                    	//  self.ds2 self.domainsDict self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.coloredUntil self.sellerAddress b
        STSLICE                 	//  self.ds2 self.domainsDict self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.coloredUntil b
        s1 s12 XCHG             	//  self.ds2 self.coloredUntil self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil self.domainsDict b
        STOPTREF                	//  self.ds2 self.coloredUntil self.domainsTotal self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.hotUntil b
        s1 s10 XCHG             	//  self.ds2 self.coloredUntil self.hotUntil self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress self.domainsTotal b
        8 STU                   	//  self.ds2 self.coloredUntil self.hotUntil self.domainsReceived self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.jettonWalletAddress b
        s1 s8 XCHG              	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil self.domainsReceived b
        8 STU                   	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.price self.commission self.state self.createdAt self.lastRenewalTime self.validUntil b
        s0 s6 XCHG2             	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.commission self.state self.createdAt self.lastRenewalTime b self.price
        STGRAMS                 	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.commission self.state self.createdAt self.lastRenewalTime b
        s0 s4 XCHG2             	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.lastRenewalTime self.state self.createdAt b self.commission
        STGRAMS                 	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.lastRenewalTime self.state self.createdAt b
        s1 s2 XCHG              	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.lastRenewalTime self.createdAt self.state b
        2 STU                   	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.lastRenewalTime self.createdAt b
        32 STU                  	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil self.lastRenewalTime b
        32 STU                  	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress self.validUntil b
        32 STU                  	//  self.ds2 self.coloredUntil self.hotUntil self.jettonWalletAddress b
        STSLICE                 	//  self.ds2 self.coloredUntil self.hotUntil b
        32 STU                  	//  self.ds2 self.coloredUntil b
        32 STU                  	//  self.ds2 b
        STREF                   	//  b
        ENDC                    	//  '24
        c4 POP                  	// 
      }>
      domainRefillFee() PROCINLINE:<{	// 
        16000 PUSHINT           	//  '1=16000
        0 PUSHINT               	//  '1=16000 '3=0
        GETGASFEE               	//  '2
        10 PUSHPOW2DEC          	//  '2 '5=1023
        1 PUSHINT               	//  '2 '5=1023 '6=1
        SWAP
        0 PUSHINT               	//  '2 '6=1 '5=1023 '8=0
        GETFORWARDFEE           	//  '2 '7
        1 LSHIFT#               	//  '2 '11
        ADD                     	//  '0
        31622400 PUSHINT        	//  '0 '20
        34000 PUSHINT           	//  '0 '20 '21=34000
        200 PUSHINT             	//  '0 '20 '21=34000 '22=200
        s0 s2 XCHG
        0 PUSHINT               	//  '0 '22=200 '21=34000 '20 '24=0
        GETSTORAGEFEE           	//  '0 '13
        ADD                     	//  '26
      }>
      cancelGasBudget() PROCINLINE:<{	//  domainsTotal
        10000 PUSHINT           	//  domainsTotal '1=10000
        5000 PUSHINT
        ROT                     	//  '1=10000 '2=5000 domainsTotal
        MUL                     	//  '1=10000 '3
        ADD                     	//  '4
        0 PUSHINT               	//  '4 '6=0
        GETGASFEE               	//  '5
      }>

    // Main deploy function content:
	//  args.fromAddress args.payloadSlice args.deployInfoSlice args.code args.commissionDiscount args.queryId args.publicKey args.contractCodes
    NIP                     	//  args.fromAddress payloadSlice args.deployInfoSlice args.code args.commissionDiscount args.queryId args.contractCodes
    s0 s5 XCHG              	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payloadSlice
    1 LDI                   	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId '17 payloadSlice
    LDDICT                  	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId '17 '20 payloadSlice
    LDGRAMS                 	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId '17 '20 '23 payloadSlice
    32 LDU                  	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId '17 '20 '23 '27 payloadSlice
    31536000 PUSHINT        	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId '17 '20 '23 '27 payloadSlice '40
    0 PUSHINT               	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0
    s2 PUSH                 	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0 payloadSlice
    SBITS                   	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0 '42
    0 GTINT                 	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0 '44
    IF:<{                   	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payloadSlice payload.autoRenewCooldown payload.autoRenewIterations=0
      2DROP                 	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payloadSlice
      32 LDU                	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewCooldown payloadSlice
      8 PLDU                	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewCooldown payload.autoRenewIterations
      SWAP                  	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations payload.autoRenewCooldown
    }>ELSE<{
      s2 POP                	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations=0 payload.autoRenewCooldown
    }>
    s5 PUSH                 	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations payload.autoRenewCooldown payload.isWeb3
    IF:<{                   	//  args.fromAddress args.contractCodes args.deployInfoSlice args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations payload.autoRenewCooldown
      s0 s9 XCHG            	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations args.deployInfoSlice
      PLDREF                	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '59
      CTOS                  	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations s
      LDGRAMS               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '64 s
      16 LDU                	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '64 '66 s
      LDGRAMS               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '64 '66 '67 s
      32 LDU                	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '64 '66 '67 '69 s
      ENDS                  	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
      s10 PUSH              	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration args.commissionDiscount
      0 NEQINT              	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration '71
      IF:<{                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
        10000 PUSHINT
        s11 POP             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount=10000 args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
      }>                    	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
    }>ELSE<{                	//  args.fromAddress args.contractCodes s args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations payload.autoRenewCooldown
      s0 s9 XCHG            	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations s
      LDGRAMS               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '76 s
      16 LDU                	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '76 '78 s
      LDGRAMS               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '76 '78 '79 s
      32 PLDU               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minDuration
    }>
    s6 s3 PUXC              	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission payload.price deployInfo.minPrice
    GEQ                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission '83
    70 THROWIFNOT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission
    NOW                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.minDuration deployInfo.commissionFactor deployInfo.maxCommission '86
    s0 s3 XCHG2             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '86 deployInfo.minDuration
    ADD                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '87
    s4 PUSH                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '87 payload.validUntil
    LEQ                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '88
    IF:<{                   	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
      NOW                   	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '90
      31622400 PUSHINT      	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '90 '97
      ADD                   	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '98
      86400 PUSHINT         	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '98 '103
      SUB                   	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '104
      s4 PUSH               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '104 payload.validUntil
      GEQ                   	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '105
      IF:<{                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
        -1 PUSHINT          	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '106=-1
      }>ELSE<{              	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
        s2 PUSH             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor payload.autoRenewIterations
        0 GTINT             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '109
        0 NEQINT            	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '106
      }>
      0 NEQINT              	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '89
    }>ELSE<{                	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
      0 PUSHINT             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '89=0
    }>
    49 THROWIFNOT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
    s10 PUSH
    86400 PUSHINT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor payload.autoRenewCooldown '121
    GEQ                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '122
    IF:<{                   	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
      s10 PUSH
      31536000 PUSHINT      	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor payload.autoRenewCooldown '136
      LEQ                   	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '137
      0 NEQINT              	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '123
    }>ELSE<{                	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
      0 PUSHINT             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor '123=0
    }>
    49 THROWIFNOT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission deployInfo.commissionFactor
    s4 s(-1) PUXC
    10000 PUSHINT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission payload.price deployInfo.commissionFactor '143=10000
    MULDIV                  	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations deployInfo.maxCommission '144
    MIN                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '145
    10000 PUSHINT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code args.commissionDiscount args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '145 '146=10000
    s0 s8 XCHG2             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code '145 args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '146=10000 args.commissionDiscount
    SUB                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code '145 args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil payload.autoRenewIterations '147
    s1 s7 XCHG
    10000 PUSHINT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil '145 '147 '148=10000
    MULDIV                  	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission
    0 PUSHINT               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal=0
    s4 PUSH
    267 PUSHINT             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal=0 payload.domainsAddresses '155=267
    DICTMIN
    NULLSWAPIFNOT2          	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal=0 received domainAddress found
    WHILE:<{
    }>DO<{                  	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal received domainAddress
      s0 s2 XCHG            	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainAddress received domainsTotal
      INC                   	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainAddress received domainsTotal
      b{0} PUSHSLICE        	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainAddress received domainsTotal '162
      s1 s2 XCHG            	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainAddress domainsTotal received '162
      SDEQ                  	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainAddress domainsTotal '163
      47 THROWIFNOT         	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainAddress domainsTotal
      s1 s5 XCPU
      267 PUSHINT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal domainAddress payload.domainsAddresses '165=267
      DICTGETNEXT
      NULLSWAPIFNOT2        	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal received domainAddress found
    }>                      	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal received domainAddress
    2DROP                   	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal
    DUP                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal domainsTotal
    0 GTINT                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '171
    71 THROWIFNOT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal
    DUP
    7 PUSHPOW2              	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal domainsTotal '174=128
    LESS                    	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '175
    75 THROWIFNOT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal
    50000 PUSHINT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '180=50000
    320 PUSHINT             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '180=50000 '181=320
    s2 PUSH                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '180=50000 '181=320 domainsTotal
    MUL                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '180=50000 '182
    ADD                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '183
    OVER                    	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '183 domainsTotal
    3 MULCONST              	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '183 '186
    90 ADDCONST             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '183 '187
    s1 s11 XCPU
    0 PUSHINT               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '187 '183 payload.autoRenewCooldown '189=0
    GETSTORAGEFEE           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179
    31622400 PUSHINT        	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '199
    34000 PUSHINT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '199 '200=34000
    200 PUSHINT             	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '199 '200=34000 '201=200
    s0 s2 XCHG
    0 PUSHINT               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '201=200 '200=34000 '199 '203=0
    GETSTORAGEFEE           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '192
    8000 PUSHINT            	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '192 '205=8000
    0 PUSHINT               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '192 '205=8000 '207=0
    GETGASFEE               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '192 '206
    ADD                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '209
    10 PUSHPOW2DEC          	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '209 '210=1023
    1 PUSHINT               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '209 '210=1023 '211=1
    SWAP
    0 PUSHINT               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '209 '211=1 '210=1023 '213=0
    GETFORWARDFEE           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '209 '212
    ADD                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '191
    s2 PUSH                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '191 domainsTotal
    MUL                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '179 '216
    ADD                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '217
    12000 PUSHINT           	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '217 '218=12000
    5000 PUSHINT            	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '217 '218=12000 '219=5000
    s3 PUSH                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '217 '218=12000 '219=5000 domainsTotal
    MUL                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '217 '218=12000 '220
    ADD                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '217 '221
    0 PUSHINT               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '217 '221 '223=0
    GETGASFEE               	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '217 '222
    ADD                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '178
    s8 PUSH                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal '178 payload.autoRenewIterations
    MUL                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve
    100000000 PUSHINT       	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve '228=100000000
    s9 PUSH                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve '228=100000000 payload.autoRenewIterations
    MUL                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay
    NOW                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233
    NOW                     	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234
    b{00} PUSHSLICE         	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234 '235
    b{00} PUSHSLICE         	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234 '235 '238
    s11 PUSH
    x{800BCFB13B3494CA795F167E94C52640B273E64B78229A15DB992A844E26F351AE9_} PUSHSLICE
    x{8014D1EFF27038AD5F4C11D80A60DDB3D9C5485BA4E2826E9EA6BAA56FBBFF4119B_} PUSHSLICE	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234 '235 '238 payload.isWeb3 '240 '241
    CONDSEL                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234 '235 '238 '239
    SWAP
    NEWC                    	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234 '235 '239 '238 b
    STSLICE                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234 '235 '239 b
    STSLICE                 	//  args.fromAddress args.contractCodes payload.autoRenewCooldown args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234 '235 b
    s1 s15 XCHG             	//  args.fromAddress args.contractCodes '235 args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234 payload.autoRenewCooldown b
    32 STU                  	//  args.fromAddress args.contractCodes '235 args.code payload.autoRenewIterations args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '234 b
    s1 s12 XCHG             	//  args.fromAddress args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 payload.autoRenewIterations b
    8 STU                   	//  args.fromAddress args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 b
    ENDC                    	//  args.fromAddress args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 '246
    s0 s15 XCHG
    NEWC                    	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 args.fromAddress b
    STSLICE                 	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 payload.domainsAddresses payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay '233 b
    s1 s8 XCHG              	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay payload.domainsAddresses b
    STOPTREF                	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay b
    s3 PUSH                 	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay b domainsTotal
    8 STUR                  	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay b
    x{00} STSLICECONST      	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 payload.price payload.validUntil commission domainsTotal autoRenewReserve autoRenewPrepay b
    s0 s6 XCHG2             	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 autoRenewPrepay payload.validUntil commission domainsTotal autoRenewReserve b payload.price
    STGRAMS                 	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 autoRenewPrepay payload.validUntil commission domainsTotal autoRenewReserve b
    s0 s3 XCHG2             	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 autoRenewPrepay payload.validUntil autoRenewReserve domainsTotal b commission
    STGRAMS                 	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 autoRenewPrepay payload.validUntil autoRenewReserve domainsTotal b
    b{00} STSLICECONST      	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 '233 autoRenewPrepay payload.validUntil autoRenewReserve domainsTotal b
    s1 s5 XCHG              	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 domainsTotal autoRenewPrepay payload.validUntil autoRenewReserve '233 b
    32 STU                  	//  '246 args.contractCodes '235 args.code '234 args.queryId payload.isWeb3 domainsTotal autoRenewPrepay payload.validUntil autoRenewReserve b
    s1 s7 XCHG              	//  '246 args.contractCodes '235 args.code autoRenewReserve args.queryId payload.isWeb3 domainsTotal autoRenewPrepay payload.validUntil '234 b
    32 STU                  	//  '246 args.contractCodes '235 args.code autoRenewReserve args.queryId payload.isWeb3 domainsTotal autoRenewPrepay payload.validUntil b
    32 STU                  	//  '246 args.contractCodes '235 args.code autoRenewReserve args.queryId payload.isWeb3 domainsTotal autoRenewPrepay b
    s1 s7 XCHG              	//  '246 args.contractCodes autoRenewPrepay args.code autoRenewReserve args.queryId payload.isWeb3 domainsTotal '235 b
    STSLICE                 	//  '246 args.contractCodes autoRenewPrepay args.code autoRenewReserve args.queryId payload.isWeb3 domainsTotal b
    0 PUSHINT
    64 STUR                 	//  '246 args.contractCodes autoRenewPrepay args.code autoRenewReserve args.queryId payload.isWeb3 domainsTotal b
    s1 s8 XCHG              	//  domainsTotal args.contractCodes autoRenewPrepay args.code autoRenewReserve args.queryId payload.isWeb3 '246 b
    STREF                   	//  domainsTotal args.contractCodes autoRenewPrepay args.code autoRenewReserve args.queryId payload.isWeb3 b
    ENDC                    	//  domainsTotal args.contractCodes autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2
    s4 s0 PUSH2             	//  domainsTotal args.contractCodes autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  domainsTotal args.contractCodes autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 '276
    NEWC                    	//  domainsTotal args.contractCodes autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 '276 '275
    b{10000000000} STSLICECONST	//  domainsTotal args.contractCodes autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 '276 '275
    256 STU                 	//  domainsTotal args.contractCodes autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 saleAddressBuilder
    s0 s7 XCHG              	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 args.contractCodes
    CTOS                    	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 lazyS
    LDREF                   	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 '303 lazyS
    NIP                     	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 lazyS
    LDREF                   	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 '304 lazyS
    NIP                     	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 lazyS
    LDREF                   	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode lazyS
    PLDREF                  	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode
    31622400 PUSHINT        	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '315
    50000 PUSHINT           	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '315 '317=50000
    320 PUSHINT             	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '315 '317=50000 '318=320
    s12 PUSH                	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '315 '317=50000 '318=320 domainsTotal
    MUL                     	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '315 '317=50000 '319
    ADD                     	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '315 '320
    s11 PUSH                	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '315 '320 domainsTotal
    3 MULCONST              	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '315 '320 '323
    90 ADDCONST             	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '315 '320 '324
    s0 s2 XCHG
    0 PUSHINT               	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '324 '320 '315 '326=0
    GETSTORAGEFEE           	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '316
    s6 PUSH                 	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '316 autoRenewReserve
    ADD                     	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '328
    s8 PUSH                 	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '328 autoRenewPrepay
    ADD                     	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '329
    NEWC                    	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '329 '334
    x{0609e47b} STSLICECONST	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve args.queryId payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '329 '334
    s1 s6 XCHG              	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode args.queryId '334
    64 STU                  	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 payload.isWeb3 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode '334
    s0 s4 XCHG              	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode payload.isWeb3
    IF:<{                   	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode
      DROP                  	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode
      NEWC                  	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode '342
      x{0} STSLICECONST     	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode '342
      s1 s8 XCHG            	//  domainsTotal contractCodes.web3WalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 saleAddressBuilder '342
      STB                   	//  domainsTotal contractCodes.web3WalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 '342
      x{800BCFB13B3494CA795F167E94C52640B273E64B78229A15DB992A844E26F351AE9_} PUSHSLICE	//  domainsTotal contractCodes.web3WalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 '342 '346
      STSLICER              	//  domainsTotal contractCodes.web3WalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 '342
      s7 PUSH               	//  domainsTotal contractCodes.web3WalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 '342 contractCodes.web3WalletCode
      STREFR                	//  domainsTotal contractCodes.web3WalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 '342
      ENDC                  	//  domainsTotal contractCodes.web3WalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 data
      s1 s7 XCHG            	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 contractCodes.web3WalletCode data
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
          ONE HASHEXT_SHA256	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 '360
      NEWC                  	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 '360 '359
      b{10000000000} STSLICECONST	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 '360 '359
      256 STU               	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 '339
    }>ELSE<{                	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 contractCodes.web3WalletCode contractCodes.usdtWalletCode
      NIP                   	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 contractCodes.usdtWalletCode
      NEWC                  	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 contractCodes.usdtWalletCode '382
      x{00} STSLICECONST    	//  domainsTotal saleAddressBuilder autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 contractCodes.usdtWalletCode '382
      s1 s8 XCHG            	//  domainsTotal contractCodes.usdtWalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 saleAddressBuilder '382
      STB                   	//  domainsTotal contractCodes.usdtWalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 '382
      x{8014D1EFF27038AD5F4C11D80A60DDB3D9C5485BA4E2826E9EA6BAA56FBBFF4119B_} PUSHSLICE	//  domainsTotal contractCodes.usdtWalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 '382 '386
      STSLICER              	//  domainsTotal contractCodes.usdtWalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 '382
      ENDC                  	//  domainsTotal contractCodes.usdtWalletCode autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 saleAddress.stateInit.USlot2 data
      s1 s7 XCHG            	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 contractCodes.usdtWalletCode data
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
          ONE HASHEXT_SHA256	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 '399
      NEWC                  	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 '399 '398
      b{10000000000} STSLICECONST	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 '399 '398
      256 STU               	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334 '339
    }>
    STBR                    	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '334
    ENDC                    	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '419
    NEWC                    	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '419 b
    b{01000010000000000} STSLICECONST	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '419 b
    s4 s6 PUSH2             	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '419 b saleAddress.stateInit.USlot1 saleAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '419 b '441
    256 STUR                	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '329 '419 b
    ROT                     	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '419 b '329
    STGRAMS                 	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '419 b
    141 PUSHINT
    113 STUR                	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay saleAddress.stateInit.USlot1 autoRenewReserve '419 b
    s1 s3 XCHG              	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay '419 autoRenewReserve saleAddress.stateInit.USlot1 b
    STREF                   	//  domainsTotal saleAddress.stateInit.USlot2 autoRenewPrepay '419 autoRenewReserve b
    s1 s4 XCHG              	//  domainsTotal autoRenewReserve autoRenewPrepay '419 saleAddress.stateInit.USlot2 b
    STREF                   	//  domainsTotal autoRenewReserve autoRenewPrepay '419 b
    STREF                   	//  domainsTotal autoRenewReserve autoRenewPrepay b
    ENDC                    	//  domainsTotal autoRenewReserve autoRenewPrepay msg
    31622400 PUSHINT        	//  domainsTotal autoRenewReserve autoRenewPrepay msg '475
    50000 PUSHINT           	//  domainsTotal autoRenewReserve autoRenewPrepay msg '475 '477=50000
    320 PUSHINT             	//  domainsTotal autoRenewReserve autoRenewPrepay msg '475 '477=50000 '478=320
    s6 PUSH                 	//  domainsTotal autoRenewReserve autoRenewPrepay msg '475 '477=50000 '478=320 domainsTotal
    MUL                     	//  domainsTotal autoRenewReserve autoRenewPrepay msg '475 '477=50000 '479
    ADD                     	//  domainsTotal autoRenewReserve autoRenewPrepay msg '475 '480
    s0 s5 XCHG              	//  '480 autoRenewReserve autoRenewPrepay msg '475 domainsTotal
    3 MULCONST              	//  '480 autoRenewReserve autoRenewPrepay msg '475 '483
    90 ADDCONST             	//  '480 autoRenewReserve autoRenewPrepay msg '475 '484
    s0 s5 s5 XCHG3
    0 PUSHINT               	//  msg autoRenewReserve autoRenewPrepay '484 '480 '475 '486=0
    GETSTORAGEFEE           	//  msg autoRenewReserve autoRenewPrepay '476
    ROT                     	//  msg autoRenewPrepay '476 autoRenewReserve
    ADD                     	//  msg autoRenewPrepay '488
    ADD                     	//  msg '489
    SWAP
    1 PUSHINT               	//  '489 msg '490=1
    SENDMSG                 	//  '489 '491
    ADD                     	//  '492
}>c PUSHREF""";
 

fun onInternalMessage(): void {
}

get fun getDeployFunctionCell(): cell {
    return deployFunctionCell();
}