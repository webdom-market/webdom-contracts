import { Address } from '@ton/core';
import { compile, NetworkProvider, sleep } from '@ton/blueprint';
import { Marketplace } from '../../wrappers/Marketplace';
import { buildDnsRecordsDict, createTextRecordCell } from '../../wrappers/Domain';

// Picture text-record auto-applied to webdom-listed domains (matches webdom-front Domain.ts).
const LISTING_PICTURE_URL = 'https://webdom.market/images/logo-256.png';

export async function run(provider: NetworkProvider) {
    const marketplace = provider.open(
        Marketplace.createFromAddress(Address.parse('EQD7-a6WPtb7w5VgoUfHJmMvakNFgitXPk3sEM8Gf_WEBDOM'))
    );

    // The DNS-records feature adds the OP_CHANGE_DNS_RECORDS handler and a new `dnsRecordsDict` field
    // at the END of the ds2 storage. We can't resend the whole data (deployInfos holds every deal code
    // — far over one external message), so we upgrade CODE ONLY (data unchanged) and then set the
    // records in a second message.
    //
    // This is safe because ds2 is loaded lazily: handlers that don't read dnsRecordsDict ignore the
    // missing trailing field, and handleChangeDnsRecords only *writes* it (so it works on the old ds2
    // cell and adds the field). Set the records in the SAME run, right after the code upgrade, so no
    // listing happens in the window where the (reading) listing path would still see the old ds2.
    const code = await compile('Marketplace');

    // Only domain-agnostic records belong here — the marketplace applies the SAME dict to every domain
    // when it is listed (handleNftOwnershipAssigned). The per-domain `links` record
    // (https://webdom.market/domain/<name>) is built and sent by the contract itself, so it is NOT set here.
    const dnsRecordsDict = buildDnsRecordsDict({
        picture: createTextRecordCell(LISTING_PICTURE_URL),
        description: createTextRecordCell('this domain is listed on webdom.market'),
    });

    // 1) Upgrade code only (data = null keeps the existing storage).
    // console.log('1/2 upgrading marketplace code (data unchanged)…');
    await marketplace.sendChangeCode(provider.sender(), code, null);

    // await sleep(1000);
    // 2) Set the DNS records — writes the new dnsRecordsDict field into ds2.
    // console.log('2/2 setting %d DNS record(s)…', dnsRecordsDict.size);
    // await marketplace.sendChangeDnsRecords(provider.sender(), dnsRecordsDict);
}
