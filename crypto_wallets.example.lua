-- crypto_wallets.lua — personal wallet config for :CryptoPortfolio
--
-- Copy this file to crypto_wallets.lua (gitignored) and fill in real addresses.
-- Every section is optional — omit any you don't use.
--
-- Supported networks:
--   btc        — Bitcoin (Blockstream API, no key needed)
--   eth        — Ether native balance (public Ethereum RPC, no key needed)
--   usdt_erc20 — USDT on Ethereum
--   usdt_trc20 — USDT on Tron (RECOMMENDED for most users — lower fees)
--   usdc_erc20 — USDC on Ethereum
--   usdc_arbitrum — USDC on Arbitrum
--   usdc_trc20 — USDC on Tron
--   dai_erc20  — DAI on Ethereum
--   aave_v3    — Aave V3 aTokens on Ethereum (e.g. aUSDC, aUSDT)
--
-- Each entry: { name = "label shown in table", address = "0x..." }

return {

  -- ── Bitcoin ────────────────────────────────────────────────────────────────
  btc = {
    { name = 'cold storage',  address = 'bc1qxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' },
    { name = 'trust wallet',  address = 'bc1qxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' },
    { name = 'localcoinswap', address = '1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' },
  },

  -- ── Ethereum (native ETH) ──────────────────────────────────────────────────
  eth = {
    { name = 'metamask',     address = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' },
    { name = 'cold storage', address = '0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB' },
  },

  -- ── USDT ───────────────────────────────────────────────────────────────────
  usdt_erc20 = {
    { name = 'cold storage',  address = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' },
    { name = 'localcoinswap', address = '0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB' },
  },

  usdt_trc20 = {
    -- Tron addresses start with T
    { name = 'tron wallet', address = 'Txxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' },
  },

  -- ── USDC ───────────────────────────────────────────────────────────────────
  usdc_erc20 = {
    { name = 'cold storage',  address = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' },
    { name = 'localcoinswap', address = '0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB' },
  },

  usdc_arbitrum = {
    { name = 'metamask', address = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' },
  },

  usdc_trc20 = {
    { name = 'tron wallet', address = 'Txxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' },
  },

  -- ── DAI ────────────────────────────────────────────────────────────────────
  dai_erc20 = {
    { name = 'metamask', address = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' },
  },

  -- ── Aave V3 lending positions ─────────────────────────────────────────────
  -- asset = underlying asset symbol used for pricing and summaries
  -- token = aToken contract address
  -- decimals = underlying token decimals
  aave_v3 = {
    { name = 'aUSDC', asset = 'USDC', token = '0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC', decimals = 6, address = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' },
  },

}
