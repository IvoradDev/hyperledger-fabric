const { Wallets } = require('fabric-network');
const FabricCAServices = require('fabric-ca-client');
const fs = require('fs');
const path = require('path');

const ORG_CONFIG = {
  1: { port: 7054, mspId: 'Org1MSP' },
  2: { port: 8054, mspId: 'Org2MSP' },
  3: { port: 9054, mspId: 'Org3MSP' },
};

async function enroll(orgNum) {
  const org = ORG_CONFIG[orgNum];
  if (!org) throw new Error(`Unknown org: ${orgNum}`);

  const ccpPath = path.resolve(__dirname, '..', '..', 'network', 'organizations',
    'peerOrganizations', `org${orgNum}.example.com`, `connection-org${orgNum}.json`);
  const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

  const caInfo = ccp.certificateAuthorities[`ca.org${orgNum}.example.com`];
  const ca = new FabricCAServices(caInfo.url, {
    trustedRoots: caInfo.tlsCACerts.pem,
    verify: false,
  }, caInfo.caName);

  const walletPath = path.resolve(__dirname, '..', 'wallet');
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  const identity = `admin-org${orgNum}`;
  if (await wallet.get(identity)) {
    console.log(`Identity ${identity} already exists in wallet`);
    return;
  }

  const enrollment = await ca.enroll({ enrollmentID: 'admin', enrollmentSecret: 'adminpw' });
  const x509Identity = {
    credentials: {
      certificate: enrollment.certificate,
      privateKey: enrollment.key.toBytes(),
    },
    mspId: org.mspId,
    type: 'X.509',
  };

  await wallet.put(identity, x509Identity);
  console.log(`Enrolled admin for org${orgNum} and saved to wallet as '${identity}'`);
}

module.exports = { enroll };
