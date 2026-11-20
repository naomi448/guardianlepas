# GuardianLepas

**Set it and forget it: a Reactive Smart Contract that rescues your vault position before liquidation — while you sleep.**

GuardianLepas is an autonomous position guardian built on the
[Reactive Network](https://reactive.network) (Omni). A Reactive Smart Contract
(RSC) on the Lasna testnet watches a vault on Base Sepolia. The moment the
vault's health drops into the danger zone, the RSC fires a cross-chain callback
that closes the position to safety — no keeper bot, no server, no human
clicking anything. The position owner literally sets it and forgets it.

Built for the **Reactive Omni Buildathon** (DoraHacks), track
**Set It and Forget It**.

## The problem

Anyone who has held a leveraged or collateralized position knows the routine:
watch the price, set phone alarms, wake up at 3 a.m. "just to check". Existing
automation means trusting a centralized keeper service or running your own bot
24/7 — infrastructure that can go down exactly when volatility spikes.

GuardianLepas replaces all of that with one on-chain subscription. The
protection lives on-chain, is paid per execution from the contract's own
reserves, and cannot forget, sleep, or go offline.

## How it works

```
 Base Sepolia (origin + destination)            Lasna (Reactive)
 ───────────────────────────────────            ─────────────────────────────
 MockOracle ──price──▶ MockVault
                          │  price < threshold
                          │  checkHealth() emits Danger(position, price, health)
                          └──────────────┬───────────────────────────────────▶
                                         │  GuardianRSC.react()  (subscribed
                                         │  to Danger in its constructor)
                                         │        │
                                         │        ▼
                                         │  SYSTEM.requestCallbackV_1_0(...)
                                         │        │
                          ┌──────────────┴───────────────────────────────────◀
                          │  Callback proxy calls GuardianGuard.rescue()
                          ▼
                   MockVault.rescuePosition() — position closed, funds safe
```

1. **MockOracle / MockVault** (Base Sepolia) model a price-sensitive position.
   `checkHealth()` emits `Danger` when the oracle price falls below the safety
   threshold.
2. **GuardianRSC** (Lasna) subscribed to that exact event in its constructor
   via the Reactive system contract (`0x8888…8888`). Its `react()` runs only
   when the system contract calls it (`onlySystem`), and requests a callback
   with `requestCallbackV_1_0`. The payload's first argument is the reserved
   `address(0)` slot that the network overwrites with this contract's address.
3. **GuardianGuard** (Base Sepolia) accepts the call only from the chain's
   callback proxy (`onlyServiceProvider`) and only when the injected sender is
   our RSC (`onlyCallbackSender`) — then it closes the vault position.

Both paid sides use Reactive's pay-per-execution model: the RSC holds lREACT
reserves for `react()` executions, the guard holds ETH reserves for delivered
callbacks, and both report **zero debt** after the run (a contract in debt
silently stops being served — the accounting is part of the demo evidence).

## Proven on-chain (the full loop, live)

One complete rescue, executed autonomously on 2026-11-21:

| Step | Evidence |
|---|---|
| Price dropped to 1500 (health 75) | [setPrice tx](https://sepolia.basescan.org/tx/0xb4a86dbc72a701a8f8c4f6108fa272a4fc3360f61e28de0e90a5d5bfea95db90) |
| Vault emits `Danger` | [checkHealth tx](https://sepolia.basescan.org/tx/0x7516937e574e8ba97fa496500386fe166d0b2e1d41bb1265c4506b75ac00352c) |
| RSC `react()` executes on Lasna | [reactive execution](https://lasna.reactscan.net/tx/0x38187cebca4eb30793741ff1126d6f90c64e25d10d9b79e49a6db47e12f0bf5d) |
| Callback delivered by the proxy, position rescued | [destination tx](https://sepolia.basescan.org/tx/0xa3c78582932c99261a5e16ef649abcceaa4eec29ec6cd4507644b8c1f6bb9f10) |

Reactscan records the subscription as **ACTIVE** and the callback as
**CONFIRMED** (no error). Trigger → rescued took 9 Base Sepolia blocks.
Full addresses, funding trail and post-loop accounting: [DEPLOYMENT.md](DEPLOYMENT.md).

## Contracts

| Contract | Chain | Address |
|---|---|---|
| MockOracle | Base Sepolia (84532) | `0x5340C4BDA164C71489287970093209d1DA195af1` |
| MockVault | Base Sepolia (84532) | `0x49E22eECDb61fDEaFf46895776B3064565BBEEba` |
| GuardianRSC | Lasna (5318007) | `0x5340C4BDA164C71489287970093209d1DA195af1` |
| GuardianGuard | Base Sepolia (84532) | `0x516b1FcaD89660e861b928f1F1DcD6b6b28922FD` |

## Build & reproduce

```bash
forge build            # Solidity ^0.8.29, lib: Reactive-Network/reactive-lib-omni
```

Deployment order is forced by the guard's immutable callback sender:
origin contracts → RSC (subscribes in constructor) → guard → `setGuard()`
wiring on both the RSC and the vault → fund reserves via `depositTo()` on the
system contract (Lasna) and the callback proxy (Base Sepolia) → open a
position, drop the price, call `checkHealth()`, and watch the rescue land.
Step-by-step values used for the live run are in [DEPLOYMENT.md](DEPLOYMENT.md).

## Why this matters beyond the demo

Swap the mock vault for any real position contract that can emit a health
event — a lending position nearing liquidation, a perps margin account, an
LP range drifting out of bounds — and the same three-contract pattern guards
it: subscribe, react, rescue. No servers to babysit the babysitter.

## License

MIT — see [LICENSE](LICENSE). Contracts use
[reactive-lib-omni](https://github.com/Reactive-Network/reactive-lib-omni)
(UNLICENSED upstream; used as a dependency).
