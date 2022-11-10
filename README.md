# Hundred Finance PoC of March 2022 exploit
This PoC is heavily inspired on [Hephyrius.eth's article written on Immunefi's blog](https://medium.com/immunefi/a-poc-of-the-hundred-finance-heist-4121f23a098). 

## Brief description
The Hundred Finance protocol is a Compound fork that was also deployed on Gnosis Chain. Due to Gnosis's Omnibridge functionality, all bridged ERC20s are ERC677 - an extension to ERC20 that adds a callback to the `transfer` method. Because of that, the `borrow` function on the `CToken` will allow for a reentrance into the protocol, to allow borrowing on another market with the same collateral and no registered debt.

This PoC uses UniswapV2 contracts (Sushiswap flashloan), Compound contracts (Hundred Finance) and the CurveFinance protocol (curve 3 pool swap).

## Test command
```bash
forge test --fork-url FORK_URL --fork-block-number 21120000
```

## RPC provider
You can create a Gnosis Chain endpoint in [Quicknode](https://www.quicknode.com/) and have access to archival node states.
