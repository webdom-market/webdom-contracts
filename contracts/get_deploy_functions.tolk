
fun deployFunctionCell(): cell 
    asm """<{
    DECLPROC Storage.load()
      DECLPROC Storage.save()
      Storage.load() PROC:<{      	// 
        c4 PUSH                 	//  '0
        CTOS                    	//  s
        2 LDU                   	//  '5 s
        1 LDI                   	//  '5 '7 s
        32 LDU                  	//  '5 '7 '9 s
        32 LDU                  	//  '5 '7 '9 '11 s
        32 LDU                  	//  '5 '7 '9 '11 '13 s
        LDGRAMS                 	//  '5 '7 '9 '11 '13 '14 s
        32 LDU                  	//  '5 '7 '9 '11 '13 '14 '16 s
        LDMSGADDR               	//  '5 '7 '9 '11 '13 '14 '16 '17 s
        LDREF                   	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 s
        32 LDU                  	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 '20 s
        32 LDU                  	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 '20 '22 s
        LDMSGADDR               	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 '20 '22 '23 s
        64 LDU                  	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 '20 '22 '23 '25 s
        12 LDU                  	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 '20 '22 '23 '25 '27 s
        32 LDU                  	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 '20 '22 '23 '25 '27 '29 s
        16 LDU                  	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 '20 '22 '23 '25 '27 '29 '31 s
        LDREF                   	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 '20 '22 '23 '25 '27 '29 '31 '32 s
        ENDS                    	//  '5 '7 '9 '11 '13 '14 '16 '17 '18 '20 '22 '23 '25 '27 '29 '31 '32
      }>
      Storage.save() PROCINLINE:<{	//  self.state self.isDeferred self.startTime self.endTime self.lastDomainRenewalTime self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.minBidValue self.minBidIncrement self.timeIncrement self.commissionFactor self.ds2
        s0 16 s() XCHG
        NEWC                    	//  self.ds2 self.isDeferred self.startTime self.endTime self.lastDomainRenewalTime self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.minBidValue self.minBidIncrement self.timeIncrement self.commissionFactor self.state b
        2 STU                   	//  self.ds2 self.isDeferred self.startTime self.endTime self.lastDomainRenewalTime self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.minBidValue self.minBidIncrement self.timeIncrement self.commissionFactor b
        s1 s15 XCHG             	//  self.ds2 self.commissionFactor self.startTime self.endTime self.lastDomainRenewalTime self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.minBidValue self.minBidIncrement self.timeIncrement self.isDeferred b
        1 STI                   	//  self.ds2 self.commissionFactor self.startTime self.endTime self.lastDomainRenewalTime self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.minBidValue self.minBidIncrement self.timeIncrement b
        s1 s13 XCHG             	//  self.ds2 self.commissionFactor self.timeIncrement self.endTime self.lastDomainRenewalTime self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.minBidValue self.minBidIncrement self.startTime b
        32 STU                  	//  self.ds2 self.commissionFactor self.timeIncrement self.endTime self.lastDomainRenewalTime self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.minBidValue self.minBidIncrement b
        s1 s11 XCHG             	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.lastDomainRenewalTime self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.minBidValue self.endTime b
        32 STU                  	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.lastDomainRenewalTime self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.minBidValue b
        s1 s9 XCHG              	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress self.lastDomainRenewalTime b
        32 STU                  	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.lastBidValue self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil self.sellerAddress b
        s0 s7 XCHG2             	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.sellerAddress self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil b self.lastBidValue
        STGRAMS                 	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.sellerAddress self.lastBidTime self.lastBidderAddress self.domainNameCell self.hotUntil self.coloredUntil b
        s1 s5 XCHG              	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.sellerAddress self.coloredUntil self.lastBidderAddress self.domainNameCell self.hotUntil self.lastBidTime b
        32 STU                  	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.sellerAddress self.coloredUntil self.lastBidderAddress self.domainNameCell self.hotUntil b
        s1 s3 XCHG              	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.sellerAddress self.coloredUntil self.hotUntil self.domainNameCell self.lastBidderAddress b
        STSLICE                 	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.sellerAddress self.coloredUntil self.hotUntil self.domainNameCell b
        STREF                   	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.sellerAddress self.coloredUntil self.hotUntil b
        32 STU                  	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.sellerAddress self.coloredUntil b
        32 STU                  	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue self.sellerAddress b
        STSLICE                 	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement self.minBidValue b
        64 STU                  	//  self.ds2 self.commissionFactor self.timeIncrement self.minBidIncrement b
        12 STU                  	//  self.ds2 self.commissionFactor self.timeIncrement b
        32 STU                  	//  self.ds2 self.commissionFactor b
        16 STU                  	//  self.ds2 b
        STREF                   	//  b
        ENDC                    	//  '30
        c4 POP                  	// 
      }>

    // Main deploy function content:
	//  args.commonArgs.fromAddress args.commonArgs.payloadSlice args.commonArgs.deployInfoSlice args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.commonArgs.publicKey args.commonArgs.contractCodes args.domainAddress args.domainNameCell
    2 2 BLKDROP2            	//  args.commonArgs.fromAddress lazyS lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress args.domainNameCell
    s0 s6 XCHG              	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress lazyS
    1 LDI                   	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred lazyS
    32 LDU                  	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.startTime lazyS
    32 LDU                  	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.startTime payload.endTime lazyS
    LDGRAMS                 	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.startTime payload.endTime payload.minBidValue lazyS
    LDGRAMS                 	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.startTime payload.endTime payload.minBidValue payload.maxBidValue lazyS
    12 LDU                  	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.startTime payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement lazyS
    32 PLDU                 	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.startTime payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.timeIncrement
    NOW                     	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.startTime payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.timeIncrement '41
    30 ADDCONST             	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.startTime payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.timeIncrement '43
    s0 s6 XCHG2             	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement '43 payload.startTime
    MAX                     	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime
    s0 s5 PUSH2             	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime payload.startTime payload.timeIncrement
    ADD                     	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '46
    s5 PUSH                 	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '46 payload.endTime
    LEQ                     	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '47
    IF:<{                   	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime
      NOW                   	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '49
      31622400 PUSHINT      	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '49 '56
      ADD                   	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '57
      86400 PUSHINT         	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '57 '62
      SUB                   	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '63
      s5 PUSH               	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '63 payload.endTime
      GEQ                   	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '64
      0 NEQINT              	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '48
    }>ELSE<{                	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime
      0 PUSHINT             	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime '48=0
    }>
    72 THROWIFNOT           	//  args.commonArgs.fromAddress args.domainNameCell lazyS args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement payload.startTime
    s0 s11 XCHG             	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement lazyS
    LDGRAMS                 	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minPrice lazyS
    16 LDU                  	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minPrice deployInfo.commissionFactor lazyS
    LDGRAMS                 	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission lazyS
    32 PLDU                 	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minPrice deployInfo.commissionFactor deployInfo.maxCommission deployInfo.minTimeIncrement
    s6 s3 PUXC              	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission payload.minBidValue deployInfo.minPrice
    GEQ                     	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission '76
    IF:<{                   	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission
      s4 s5 PUSH2           	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission payload.maxBidValue payload.minBidValue
      GREATER               	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission '78
      0 NEQINT              	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission '77
    }>ELSE<{                	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission
      0 PUSHINT             	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission '77=0
    }>
    70 THROWIFNOT           	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission
    s3 PUSH
    1000 PUSHINT            	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission payload.minBidIncrement '84=1000
    GREATER                 	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission '85
    73 THROWIFNOT           	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.minTimeIncrement deployInfo.commissionFactor deployInfo.maxCommission
    s7 s2 PUXC              	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission deployInfo.commissionFactor payload.timeIncrement deployInfo.minTimeIncrement
    GEQ                     	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission deployInfo.commissionFactor '88
    74 THROWIFNOT           	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission deployInfo.commissionFactor
    10000 PUSHINT           	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission deployInfo.commissionFactor '91=10000
    s11 PUSH                	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission deployInfo.commissionFactor '91=10000 args.commonArgs.commissionDiscount
    SUB                     	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission deployInfo.commissionFactor '92
    10000 PUSHINT           	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission deployInfo.commissionFactor '92 '93=10000
    MULDIV                  	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission commissionFactor
    10000 PUSHINT           	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code args.commonArgs.commissionDiscount args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission commissionFactor '96=10000
    s0 s11 XCHG2            	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission '96=10000 args.commonArgs.commissionDiscount
    SUB                     	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission '97
    10000 PUSHINT           	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement deployInfo.maxCommission '97 '98=10000
    MULDIV                  	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement maxCommission
    NOW                     	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement maxCommission '102
    b{00} PUSHSLICE         	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement maxCommission '102 '105
    s9 PUSH
    NEWC                    	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement maxCommission '102 '105 args.domainAddress b
    STSLICE                 	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue payload.maxBidValue payload.minBidIncrement maxCommission '102 '105 b
    s0 s5 XCHG2             	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement maxCommission '102 b payload.maxBidValue
    STGRAMS                 	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement maxCommission '102 b
    s1 s2 XCHG              	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement '102 maxCommission b
    64 STU                  	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement '102 b
    ENDC                    	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement '102 '111
    NEWC                    	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement '102 '111 b
    b{00} STSLICECONST      	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.isDeferred payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement '102 '111 b
    s1 s8 XCHG              	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement '102 payload.isDeferred b
    1 STI                   	//  args.commonArgs.fromAddress args.domainNameCell payload.startTime args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement '102 b
    s1 s12 XCHG             	//  args.commonArgs.fromAddress args.domainNameCell '102 args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement payload.startTime b
    32 STU                  	//  args.commonArgs.fromAddress args.domainNameCell '102 args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.endTime payload.minBidValue '105 payload.minBidIncrement b
    s1 s4 XCHG              	//  args.commonArgs.fromAddress args.domainNameCell '102 args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.minBidIncrement payload.minBidValue '105 payload.endTime b
    32 STU                  	//  args.commonArgs.fromAddress args.domainNameCell '102 args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.minBidIncrement payload.minBidValue '105 b
    s1 s10 XCHG             	//  args.commonArgs.fromAddress args.domainNameCell '105 args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.minBidIncrement payload.minBidValue '102 b
    32 STU                  	//  args.commonArgs.fromAddress args.domainNameCell '105 args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.minBidIncrement payload.minBidValue b
    0 PUSHINT
    36 STUR                 	//  args.commonArgs.fromAddress args.domainNameCell '105 args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.minBidIncrement payload.minBidValue b
    s1 s9 XCHG              	//  args.commonArgs.fromAddress args.domainNameCell payload.minBidValue args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.minBidIncrement '105 b
    STSLICE                 	//  args.commonArgs.fromAddress args.domainNameCell payload.minBidValue args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement payload.minBidIncrement b
    s1 s9 XCHG              	//  args.commonArgs.fromAddress payload.minBidIncrement payload.minBidValue args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement args.domainNameCell b
    STREF                   	//  args.commonArgs.fromAddress payload.minBidIncrement payload.minBidValue args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement b
    0 PUSHINT
    64 STUR                 	//  args.commonArgs.fromAddress payload.minBidIncrement payload.minBidValue args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 payload.timeIncrement b
    s1 s9 XCHG              	//  payload.timeIncrement payload.minBidIncrement payload.minBidValue args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 args.commonArgs.fromAddress b
    STSLICE                 	//  payload.timeIncrement payload.minBidIncrement payload.minBidValue args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress '111 b
    s1 s6 XCHG              	//  payload.timeIncrement payload.minBidIncrement '111 args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress payload.minBidValue b
    64 STU                  	//  payload.timeIncrement payload.minBidIncrement '111 args.commonArgs.code commissionFactor args.commonArgs.queryId args.domainAddress b
    s1 s6 XCHG              	//  payload.timeIncrement args.domainAddress '111 args.commonArgs.code commissionFactor args.commonArgs.queryId payload.minBidIncrement b
    12 STU                  	//  payload.timeIncrement args.domainAddress '111 args.commonArgs.code commissionFactor args.commonArgs.queryId b
    s1 s6 XCHG              	//  args.commonArgs.queryId args.domainAddress '111 args.commonArgs.code commissionFactor payload.timeIncrement b
    32 STU                  	//  args.commonArgs.queryId args.domainAddress '111 args.commonArgs.code commissionFactor b
    16 STU                  	//  args.commonArgs.queryId args.domainAddress '111 args.commonArgs.code b
    s1 s2 XCHG              	//  args.commonArgs.queryId args.domainAddress args.commonArgs.code '111 b
    STREF                   	//  args.commonArgs.queryId args.domainAddress args.commonArgs.code b
    ENDC                    	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2
    2DUP                    	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '144
    NEWC                    	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '144 '143
    b{10000000000} STSLICECONST	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '144 '143
    256 STU                 	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 auctionAddressBuilder
    30000000 PUSHINT        	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 auctionAddressBuilder '164=30000000
    b{00} PUSHSLICE         	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 auctionAddressBuilder '164=30000000 '175
    PUSHNULL                	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 auctionAddressBuilder '164=30000000 '175 '176
    x{41756374696f6e206f6e20776562646f6d2e6d61726b6574} PUSHSLICE	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 auctionAddressBuilder '164=30000000 '175 '176 '178
    NEWC                    	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 auctionAddressBuilder '164=30000000 '175 '176 '178 refb
    x{5fcc3d140000000000000000} STSLICECONST	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 auctionAddressBuilder '164=30000000 '175 '176 '178 refb
    s1 s5 XCHG              	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 '175 '176 auctionAddressBuilder refb
    STB                     	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 '175 '176 refb
    s1 s2 XCHG              	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 '176 '175 refb
    STSLICE                 	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 '176 refb
    STOPTREF                	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 refb
    x{0} STSLICECONST       	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 refb
    s2 PUSH                 	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 refb '178
    ISNULL                  	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 refb '195
    IF:<{                   	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 refb
      1 2 BLKDROP2          	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '164=30000000 refb
      b{0} STSLICECONST     	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '164=30000000 refb
    }>ELSE<{                	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 refb
      b{100000000000000000000000000000000} STSLICECONST	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '178 '164=30000000 b
      s1 s2 XCHG            	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '164=30000000 '178 b
      STSLICE               	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '164=30000000 refb
    }>
    ENDC                    	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '164=30000000 '205
    NEWC                    	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '164=30000000 '205 b
    b{010000} STSLICECONST  	//  args.commonArgs.queryId args.domainAddress auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '164=30000000 '205 b
    s1 s5 XCHG              	//  args.commonArgs.queryId '205 auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '164=30000000 args.domainAddress b
    STSLICE                 	//  args.commonArgs.queryId '205 auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 '164=30000000 b
    SWAP                    	//  args.commonArgs.queryId '205 auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 b '164=30000000
    STGRAMS                 	//  args.commonArgs.queryId '205 auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 b
    1 PUSHINT
    107 STUR                	//  args.commonArgs.queryId '205 auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2 b
    s1 s3 XCHG              	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 '205 b
    STREF                   	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 b
    ENDC                    	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 '242
    0 PUSHINT               	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 '242 '243=0
    SENDRAWMSG              	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1
    65000000 PUSHINT        	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 '252
    NEWC                    	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 '252 b
    b{01000010000000000} STSLICECONST	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 '252 b
    s2 s3 PUSH2             	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 '252 b auctionAddress.stateInit.USlot1 auctionAddress.stateInit.USlot2
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
        ONE HASHEXT_SHA256  	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 '252 b '277
    256 STUR                	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 '252 b
    SWAP                    	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 b '252
    STGRAMS                 	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 b
    140 PUSHINT
    113 STUR                	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 auctionAddress.stateInit.USlot1 b
    STREF                   	//  args.commonArgs.queryId auctionAddress.stateInit.USlot2 b
    STREF                   	//  args.commonArgs.queryId b
    x{0609e47b} STSLICECONST	//  args.commonArgs.queryId b
    64 STU                  	//  b
    ENDC                    	//  msg
    95000000 PUSHINT        	//  msg '316
    SWAP
    1 PUSHINT               	//  '316 msg '317=1
    SENDMSG                 	//  '316 '318
    ADD                     	//  '319
}>c PUSHREF""";
 

fun onInternalMessage(): void {
}

get fun getDeployFunctionCell(): cell {
    return deployFunctionCell();
}