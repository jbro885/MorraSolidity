const web3js = require('web3');

const key = '';
const web3 = new web3js('http://1.1.1.1:8543');
const account = web3.eth.accounts.privateKeyToAccount(key);
const addedAccount = web3.eth.accounts.wallet.add(account);
const myAddress = web3.eth.accounts.wallet[0].address;

const contractAddress = '0x95f225e951f5204F553715C30CFa89AEeaEAD181';
const abiC = [
    {
        "constant": true,
        "inputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "name": "feedings",
        "outputs": [
            {
                "internalType": "address",
                "name": "zookeeper",
                "type": "address"
            },
            {
                "internalType": "string",
                "name": "message",
                "type": "string"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [],
        "name": "lastFed",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [],
        "name": "getMessageNumber",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [],
        "name": "zookeeper",
        "outputs": [
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [],
        "name": "cookiePrice",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [],
        "name": "timeLimit",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": false,
        "inputs": [],
        "name": "collect",
        "outputs": [],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "constant": false,
        "inputs": [
            {
                "internalType": "string",
                "name": "message",
                "type": "string"
            }
        ],
        "name": "feed",
        "outputs": [],
        "payable": true,
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "price",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "limit",
                "type": "uint256"
            }
        ],
        "payable": true,
        "stateMutability": "payable",
        "type": "constructor"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": false,
                "internalType": "address",
                "name": "newZookeeper",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "message",
                "type": "string"
            }
        ],
        "name": "Fed",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": false,
                "internalType": "address",
                "name": "newZookeeper",
                "type": "address"
            }
        ],
        "name": "Collected",
        "type": "event"
    }
];
const contract = new web3.eth.Contract(abiC, contractAddress);

function sleep(s) {
    return new Promise(resolve => setTimeout(resolve, s*1000));
}

function getBalance(address) {
    return web3.eth.getBalance(address);
}

function getRemainingTimeTillCollect() {
    return Promise.all([
        contract.methods.lastFed().call().then(lastFed => Math.floor(Date.now()/1000) - lastFed),
        contract.methods.timeLimit().call()
    ]).then(values => values[1] - values[0])
}

function collect() {
    return contract.methods.collect().send({from: myAddress, gas: 300000})
}

function feed(text, value) {
    if (!value) {
        return getCookiePrice().then(price => contract.methods.feed(text).send({from: myAddress, gas: 300000, value: price}))
    } else {
        return contract.methods.feed(text).send({from: myAddress, gas: 300000, value: value})
    }
}

function becomeZookeeper(shouldFeed = false) {
    return getZooKeeper().then(address => {
        if (address === myAddress) {
            console.log('Zookeeper is ME MUAHAAH');
        }
        else {
            console.log('Someone else is the zookeeper. Feeding the monsta');
            if (shouldFeed) return feed("let me collect pls, the deadline is over, go away").then(f => {console.log(f); return f;})
                .then(getZooKeeper()).then(address => address === myAddress);
        }
        return getZooKeeper().then(address => address === myAddress);
    });
}

function getZooKeeper() {
    return contract.methods.zookeeper().call();
}

function getCookiePrice() {
    return contract.methods.cookiePrice().call()
}

function play() {
    getBalance(myAddress).then(balance => {
        console.log('My balance is ', balance);
        // if (balance<500000000000000000000) process.exit(1);
        return true;
    }).then(() => getBalance(contractAddress)).then(b=>{
        console.log('Contract has',b/1000000000000000000,'ether');
        return b;
    }).then(becomeZookeeper(true)).then(ami => {
        if (!ami) throw "Didn't manage to become zookeeper:(";
    }).then(getRemainingTimeTillCollect).then(t => {
        console.log((new Date).toISOString(), 'Seconds/minutes/hours/days till collect:', t, (t/60).toFixed(2),
            (t/3600).toFixed(2), (t/(3600*24)).toFixed(2));

        if (t > 5 * 60 * 60) {
            //too long remaining, go to sleep
            console.log('More than an hour remaining, go to sleep for ', t/(2*60 * 60));
            sleep(t/2).then(play);
        } else if (t > 0) {
            console.log('Less than an hour remaining, sleep exactly', t, 'time');
            sleep(t).then(play);
        } else {
            console.log('Time to collect hihihihAhAHAHMUAHAHA');
            collect().then(r => {console.log(r); return r;});
        }
    });
}

async function getTransactionsByAccount(myaccount, startBlockNumber, endBlockNumber) {
    console.log("Searching for transactions to/from account \"" + myaccount + "\" within blocks "  + startBlockNumber + " and " + endBlockNumber);

    for (let i = endBlockNumber; i >= startBlockNumber; i--) {
        await web3.eth.getBlock(i, true).then(block => {
            if (block != null && block.transactions != null) {
                block.transactions.forEach( function(e) {
                    if (myaccount == "*" || myaccount == e.from || myaccount == e.to) {
                        console.log(block);
                        console.log("  tx hash          : " + e.hash + "\n"
                            + "   nonce           : " + e.nonce + "\n"
                            + "   blockHash       : " + e.blockHash + "\n"
                            + "   blockNumber     : " + e.blockNumber + "\n"
                            + "   transactionIndex: " + e.transactionIndex + "\n"
                            + "   from            : " + e.from + "\n"
                            + "   to              : " + e.to + "\n"
                            + "   value           : " + e.value + "\n"
                            + "   time            : " + block.timestamp + " " + new Date(block.timestamp * 1000).toGMTString() + "\n"
                            + "   gasPrice        : " + e.gasPrice + "\n"
                            + "   gas             : " + e.gas + "\n"
                            + "   input           : " + e.input);
                    }
                })
            }
        });
    }
}
// web3.eth.getBlockNumber().then(n =>getTransactionsByAccount(myAddress, 0, n));
//  play();
// contract.getPastEvents({fromBlock: 0, toBlock: 'latest'}, function(error, events){ console.log(events); })
getBalance(contractAddress).then(x=>console.log(x/1000000000000000000));
// getRemainingTimeTillCollect().then(x=>console.log(x/3600));

