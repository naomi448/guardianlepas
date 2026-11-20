# GuardianLepas — Deployment & Loop Evidence

Deployed and proven end-to-end on 2026-11-21 (WIB). All funds are testnet
(Base Sepolia ETH + Lasna lREACT) obtained for free: 0.05 Sepolia ETH from the
Google Cloud Web3 faucet (claimed by Yan to the project address), 0.02 ETH
swapped to lREACT via the Reactive faucet contract, 0.024 ETH bridged to
Base Sepolia via the official L1StandardBridge.

Deployer (testnet-only project wallet): 0xb590Ac270749fcaC8378Dc3555D559A1554BEfE7

## Contracts

| Contract | Chain | Address |
|---|---|---|
| MockOracle | Base Sepolia (84532) | 0x5340C4BDA164C71489287970093209d1DA195af1 |
| MockVault | Base Sepolia (84532) | 0x49E22eECDb61fDEaFf46895776B3064565BBEEba |
| GuardianRSC | Lasna (5318007) | 0x5340C4BDA164C71489287970093209d1DA195af1 |
| GuardianGuard | Base Sepolia (84532) | 0x516b1FcaD89660e861b928f1F1DcD6b6b28922FD |

(The oracle and the RSC share an address because both were the deployer's
nonce-0 CREATE on their respective chains — different chains, different code.)

Reactive system contract (Lasna): 0x8888888888888888888888888888888888888888
Base Sepolia callback proxy: 0x476F44b11F5C942c58f4c8E3d0300E5710743585
Danger event topic0: 0xeed475cd67220865c036e2577af838ce1faab963ea275212cf4f27b8359908af
Scenario parameters: initial price 3000, safety threshold 2000, position size 1000,
trigger price 1500 (health factor 75).

## Funding transactions

- Faucet claim (Google Cloud Web3, Sepolia): 0x7946a61a6e20e37b28681f59240504717365952b26785a454d2e41c89ea46f85
- Swap 0.02 ETH -> 2.1 lREACT (L1 faucet contract 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434): 0x9b495856b34e63cdecf171398e933864ab041343090c1d6e1b3120b12c24e7d6
- Bridge 0.024 ETH Sepolia -> Base Sepolia (L1StandardBridge 0xfd0Bf71F60660E2f608ed56e1659C450eB113120): 0xa7279ad677b6d882c5ebb304b2f0f9f720f413a04439040acd53bdf2798f702d

## Wiring & reserves

- RSC.setGuard(guard) on Lasna: 0xf8c2a20fd4223b4680f8d1d55f1904b39cffb0814256da6d2b7e17fc5b0fe576
- Vault.setGuard(guard): 0x1aa6cf4b55150833a315e77e114873ad99ae4c771d107a91c8ffa8dfbf1680bc
- Vault.openPosition(1000): 0xeb14dfec5d931f2d7cd86cedbe4f7082bf6ea63f3bd9957f3d89fefaa2c323f2
- SYSTEM.depositTo(RSC) 0.5 lREACT: 0x0938fd4f2501af9f7bf711bab327c36bc9bf224e85edd3f49d04856eef776795
- Proxy.depositTo(guard) 0.015 ETH: 0xff8c20c6ef273060e758143157d3251d39d5d6834b882f2be295b20836ad027d

## The loop (all on-chain, 2026-11-21 ~05:52 WIB)

1. Origin — oracle.setPrice(1500): 0xb4a86dbc72a701a8f8c4f6108fa272a4fc3360f61e28de0e90a5d5bfea95db90
2. Origin — vault.checkHealth() emits Danger(position, price=1500, health=75):
   0x7516937e574e8ba97fa496500386fe166d0b2e1d41bb1265c4506b75ac00352c
   (Base Sepolia block 61466374)
3. Reactive — GuardianRSC.react() executed on Lasna by the system contract
   (call tree: trigger -> SYSTEM -> react() -> requestCallbackV_1_0, with the
   CallbackRequest event naming this RSC as sender and the guard as recipient):
   0x38187cebca4eb30793741ff1126d6f90c64e25d10d9b79e49a6db47e12f0bf5d
   (Lasna block 8846495, 05:52:23 WIB per Reactscan)
4. Destination — callback delivered BY the callback proxy (tx.to = proxy),
   guard.rescue() -> vault.rescuePosition(), position closed:
   0xa3c78582932c99261a5e16ef649abcceaa4eec29ec6cd4507644b8c1f6bb9f10
   (Base Sepolia block 61466383 — 9 blocks after the trigger; Rescued +
   PositionRescued events in this tx.)

Reactscan cross-checks (https://lasna.reactscan.net/address/0x5340C4BDA164C71489287970093209d1DA195af1):
subscription status ACTIVE (Base Sepolia, vault, Danger topic0); callback
status CONFIRMED with destination tx matching #4 and no error; contract page
shows balance 0.5 REACT, reserves 0.4872 REACT, debt 0.

Post-loop accounting (proof both executions were billed and settled, no debt):
- RSC: debt 0, reserves 0.5 -> 0.487272 lREACT (react() charge ~0.0127 lREACT)
- Guard: debt 0, reserves 0.015 -> 0.0149993 ETH (callback charge ~0.0000007 ETH)
- Vault positionOpen: true -> false (only reachable via guard <- proxy <- RSC)

## Second run — the demo video run (2026-11-21 ~06:25 WIB)

The loop was fired a second time, live, as the recorded demo (demo.mp4 /
https://naomi448.github.io/guardianlepas/demo.mp4):

1. oracle.setPrice(3000): 0xe46f82b002c188d51b41de9ab76a7baf0b39707d13ca2414ffcecd3539e8217c
2. vault.openPosition(1000): 0x98ab9d5fb13a64f5dcb9e628c63d1d82271ae25355e62f3d5699e6b9cefbfc08
3. oracle.setPrice(1500): 0x350117bb00e8244e5ba8cef96771b548107b095c4b6f5186415653437e03c8ff
4. vault.checkHealth() emits Danger (price 1500, health 75):
   0xf4358b03bb3a0ff04a805fda218edfc777319e42ec7241ef6a7aa41a2f7c107b
   (Base Sepolia block 61476359)
5. Destination — callback delivered by the proxy, position rescued:
   0xd02524e5c6b9e0e7c19b575bc55e2c38b0e320635c5e41d4031125b71e5c14e9
   (Base Sepolia block 61476366 — 7 blocks after the trigger;
   PositionRescued event in this tx; vault positionOpen true -> false)
