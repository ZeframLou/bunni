# Bunni

![](images/bunni-logo.png)

ERC-20 LP tokens for Uniswap V3.

## Problem

Uniswap V3 is awesome for boosting LP income, but it's also far more complex than Uniswap V2/Sushiswap, with ERC-721 NFT LP tokens instead of the ERC-20 LP tokens used by Uniswap V2/Sushiswap.

- Projects perfer to incentivize liquidity on Uniswap V2/Sushiswap, due to the simplicity of the Uniswap V2 contracts and the wide array of battle-proven smart contracts that can be easily forked.
- Individual liquidity providers prefer Uniswap V3 because they can earn much more fees from the same amount of liquidity.

Thus, projects usually have at least two separate pools of liquidity, one on Uniswap V3 and one on Uniswap V2/Sushiswap. This results in liquidity fragmentation.

- [Illuvium](https://staking.illuvium.io/staking/core) is incentivizing liquidity on Sushiswap, which has over $390M TVL seeing around $6M daily volume and earning 1.36% APY in trading fees.
  - Meanwhile, ILV has $0.5M TVL on Uniswap V3, but the LPs are seeing around $0.2M daily volume and earning over 800% APY in trading fees.

(Data from 12/29/2021)

## Solution

Bunni enables projects to create ERC-20 LP tokens on Uniswap V3 and plug them into existing liquidity incentivization contracts designed for Uniswap V2/Sushiswap.

1. Project creates Bunni LP token contract and staking contract for incentivizing LPs
2. LPs provide liquidity using Bunni and get LP tokens
3. Users stake LP tokens in staking contract and earn incentives

It's just like how liquidity mining works using good'ol Uniswap V2!

By using Bunni instead of Uniswap V2, projects can merge their liquidity into one Uniswap V3 pool instead of split it between Uniswap V2 and V3. This means:

- Traders experience less slippage, since the liquidity is no longer fractured
- LPs feel more comfortable providing liquidity & using more complex strategies on Uniswap V3, since they know the pool won't become a ghost town.

## Features

- ERC-20 LP token as fractional shares of a Uniswap V3 LP position
- `compound()` for compounding trading fees back into the liquidity pool
- Arbitrary price range (though we expect most projects to use full range due to its simplicity)
- Compatabile with OlympusDAO bonds 👀

## Get Started

Install [dapptools](https://github.com/dapphub/dapptools), then

```
make
make test
```

View the Makefile for more commands.
