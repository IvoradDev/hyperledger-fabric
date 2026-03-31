const { Gateway, Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');

async function getContract(orgNum, channelNum) {
  const ccpPath = path.resolve(__dirname, '..', '..', 'network', 'organizations',
    'peerOrganizations', `org${orgNum}.example.com`, `connection-org${orgNum}.json`);
  const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

  const walletPath = path.resolve(__dirname, '..', 'wallet');
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  const identity = `admin-org${orgNum}`;
  if (!await wallet.get(identity)) {
    throw new Error(`Identity ${identity} not found. Run: node app.js enroll ${orgNum}`);
  }

  const gateway = new Gateway();
  await gateway.connect(ccp, {
    wallet,
    identity,
    discovery: { enabled: true, asLocalhost: true },
  });

  const network = await gateway.getNetwork(`channel${channelNum}`);
  const contract = network.getContract('trading');

  return { gateway, contract };
}

module.exports = { getContract };
