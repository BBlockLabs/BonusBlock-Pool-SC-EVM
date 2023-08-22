# Reward Pool distribution Smart Contract

This is [BonusBlock](https://www.bonusblock.io) reward pool distribution smart contract for EVM based networks

Java-way of deployment via org.web3j:core:4.9.8 using Maven build org.web3j:web3j-maven-plugin:4.9.8 plugin:

Example for Ethereum Sepolia testnet
```
Web3j web3j = Web3j.build(new HttpService("https://rpc.sepolia.org"));
Credentials cr = Credentials.create(<string_private_key>);
String adr = cr.getAddress();
long chainId = 11155111;
FastRawTransactionManager txMananger = new FastRawTransactionManager(web3j, cr, chainId);

BigInteger feeNative = BigInteger.valueOf(1000);
BigInteger initialClaimPercentage = BigInteger.valueOf(10);

// Ensure that the model is already built for the <soliditySourceFiles/> web3j-maven-plugin
contract = PoolTokenContract.deploy(
            web3j,
            txManager,
            new DefaultGasProvider(),
            feeNative,
            initialClaimPercentage
        ).send();

log.warn(contract.getContractAddress());
```
