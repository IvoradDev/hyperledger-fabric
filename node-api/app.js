const { enroll } = require('./fabric/enroll');
const { getContract } = require('./fabric/contract');

const [,, command, ...args] = process.argv;

async function main() {
  if (command === 'enroll') {
    const orgNum = parseInt(args[0]);
    await enroll(orgNum);
    return;
  }

  if (command === 'invoke' || command === 'query') {
    const orgNum = parseInt(args[0]);
    const channelNum = parseInt(args[1]);
    const fn = args[2];
    const fnArgs = args.slice(3);

    const { gateway, contract } = await getContract(orgNum, channelNum);

    try {
      let result;
      if (command === 'query') {
        result = await contract.evaluateTransaction(fn, ...fnArgs);
      } else {
        result = await contract.submitTransaction(fn, ...fnArgs);
      }

      if (result && result.length > 0) {
        console.log(JSON.stringify(JSON.parse(result.toString()), null, 2));
      } else {
        console.log('Transaction submitted successfully');
      }
    } finally {
      gateway.disconnect();
    }
    return;
  }

  console.log(`
Usage:
  node app.js enroll <org>
  node app.js query  <org> <channel> <function> [args...]
  node app.js invoke <org> <channel> <function> [args...]

Examples:
  node app.js enroll 1
  node app.js enroll 2
  node app.js invoke 1 1 InitLedger
  node app.js query  1 1 GetAllMerchants
  node app.js query  2 2 GetAllProducts
  node app.js invoke 1 1 PurchaseProduct R1 U1 M1 P3
  node app.js query  2 1 SearchProductsByName Milk
  node app.js invoke 2 2 DepositToUser U3 500
  node app.js query  1 2 GetUsersWithBalanceAbove 300
  `);
}

main().catch(err => {
  console.error(err.message);
  process.exit(1);
});
