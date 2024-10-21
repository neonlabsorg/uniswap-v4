Neon-EVM

Deploy contract
```
forge create --rpc-url http://10.211.55.4:9090/solana --private-key 0x3b2c445449050b34e6d448190f889723c1a5b3cbace32412e135d6a9054f73c3 test/UnorderedNonce.t.sol:UnorderedNonceTest --legacy
```

Response:
```
[⠢] Compiling...
No files changed, compilation skipped
2024-09-10T11:13:46.502034Z ERROR alloy_rpc_client::poller: failed to poll err=server returned an error response: error code -32700: Invalid JSON was received by the server, data: {"errors":["The parameter 'JsonRpcRequest.params': Input should be a valid array.","The parameter 'list[JsonRpcRequest]': Input should be a valid array."]}
Deployer: 0x59C8FeC66f80f2B598E5102fBC66f448784E93B6
Deployed to: 0xE514CdAfad97431d25e35C42AdC816ac77ad11B1
Transaction hash: 0xfcb21e962d022f58ae6e5408058db23bdf34ce86c7bc75570fcd4c91383cbf06
```

Call method (contract address may vary because these examples for several attemps)
```
cast call 0x935394A0a127e147A87B75745f740d26626c6Ca7 "setUp()" --rpc-url http://10.211.55.4:9090/solana
```
Response:
```
server returned an error response: error code -32602: Invalid params, data: {"errors":["The parameter 'tx.input': Extra inputs are not permitted."]}
```
Raw communication:
```
POST /solana HTTP/1.1
content-type: application/json
accept: */*
host: 10.211.55.4:9090
content-length: 47

{"method":"eth_chainId","id":0,"jsonrpc":"2.0"}HTTP/1.1 200 OK
content-length: 40
allow: POST, GET
content-type: application/json; charset=utf-8
x-process-time: 1.942699
date: Tue, 10 Sep 2024 11:09:33 GMT

{"jsonrpc":"2.0","id":0,"result":"0x6f"}POST /solana HTTP/1.1
content-type: application/json
accept: */*
host: 10.211.55.4:9090
content-length: 226

{"method":"eth_call","params":[{"from":"0x0000000000000000000000000000000000000000","to":"0x935394a0a127e147a87b75745f740d26626c6ca7","input":"0x0a9254e4","data":"0x0a9254e4","chainId":"0x6f"},"latest"],"id":1,"jsonrpc":"2.0"}HTTP/1.1 200 OK
content-length: 155
allow: POST, GET
content-type: application/json; charset=utf-8
x-process-time: 3.507192
date: Tue, 10 Sep 2024 11:09:33 GMT

{"jsonrpc":"2.0","id":1,"error":{"code":-32602,"message":"Invalid params","data":{"errors":["The parameter 'tx.input': Extra inputs are not permitted."]}}}
```

Send (with transaction creation)
```
cast send 0xe2Ff9C3b17b07B1983EfCD12680a2e64b272A803 "setUp()" --rpc-url http://10.211.55.4:9090/solana --private-key 0x54c773d44823cfc56fcc58716ee3100ad0c6b432b14058681e81041fe351f61f
```
Response:
```
server returned an error response: error code -32601: the method eth_feeHistory does not exist/is not available
```

Anvil

Deploy contract
```
forge create --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 test/UnorderedNonce.t.sol:UnorderedNonceTest --legacy
```
Call method
```
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "setUp()" --rpc-url http://127.0.0.1:8545
```
Response:
```
0x
```
Raw communication
```
POST / HTTP/1.1
content-type: application/json
accept: */*
host: 127.0.0.1:8545
content-length: 47

{"method":"eth_chainId","id":0,"jsonrpc":"2.0"}HTTP/1.1 200 OK
content-type: application/json
content-length: 42
vary: origin, access-control-request-method, access-control-request-headers
access-control-allow-origin: *
date: Tue, 10 Sep 2024 11:07:41 GMT

{"jsonrpc":"2.0","id":0,"result":"0x7a69"}POST / HTTP/1.1
content-type: application/json
accept: */*
host: 127.0.0.1:8545
content-length: 228

{"method":"eth_call","params":[{"from":"0x0000000000000000000000000000000000000000","to":"0x5fbdb2315678afecb367f032d93f642f64180aa3","input":"0x0a9254e4","data":"0x0a9254e4","chainId":"0x7a69"},"latest"],"id":1,"jsonrpc":"2.0"}HTTP/1.1 200 OK
content-type: application/json
content-length: 38
vary: origin, access-control-request-method, access-control-request-headers
access-control-allow-origin: *
date: Tue, 10 Sep 2024 11:07:41 GMT

{"jsonrpc":"2.0","id":1,"result":"0x"}
```

Send (with transaction creation)
```
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "setUp()" --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```
Response:

```
blockHash               0x7001cc5d55d9452d85c62d7c5dfbdbef29b3f03667fb91df71dac66e61dee2d2
blockNumber             2
contractAddress         
cumulativeGasUsed       157354
effectiveGasPrice       1898069742
from                    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
gasUsed                 157354
logs                    []
logsBloom               0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
root                    0xff0187c4b5d716e7acf7b0e561b93727c1cdeffc5c4c658013adb1c3c9d3b2ad
status                  1 (success)
transactionHash         0xa26a2a0ac06d619809e878241e42603da9e151a4d15a004a497a99171db89d43
transactionIndex        0
type                    2
blobGasPrice            1
blobGasUsed             
authorizationList       
to                      0x5FbDB2315678afecb367f032d93F642f64180aa3
```


```
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "testLowNonces()" --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

```
server returned an error response: error code 3: execution reverted, data: "0x"
```