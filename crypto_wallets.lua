return {

  btc = {
    { name = 'metamask-btc01', address = 'bc1qagfnunxsanr5nx3qqqh524cjjps2gruaua3fjy' },
    { name = 'trezor-btc01', address = 'bc1qd2nmxk7j89e0fuyf8m4vralcmpeslwv4avf9sk' },
    { name = 'trezor-btc02', address = 'bc1qtxnfvs509gml4fdkyhepwfw22g9e0dq5ljgc9s' },
    { name = 'trezor-btc03', address = 'bc1qvmsk9r8vmqk85qy0gy8r9v95t9s6jj0q4g82h8' },
    { name = 'Trust Wallet', address = 'bc1qp02nfd9an5kxw8ea3elvqnw4zy4637r0azexvm' },
    { name = 'localcoinswap btc', address = '383AafyT58mDodnBNLfx7poXWZYhYNDLP5' },
  },

  doge = {
    { name = 'trust-doge-icloud', address = 'D5cSK2jeEa4H1nqQTcQw3L4w4DmmgvFpk9' },
  },

  eth = {
    { name = 'metamask-eth01', address = '0x8d862f3a30ab3af9f941e60abc8ac612540bacbe' },
    { name = 'metamask-eth02', address = '0xb2c4A7b2F6FC13AE6423038e90ec456Db358D6fe' },
  },

  eth_linea = {
    { name = 'linea-eth01', address = '0xb2c4a7b2f6fc13ae6423038e90ec456db358d6fe' },
  },

  usdt_erc20 = {
    { name = 'metamask-usdt01', address = '0x8d862f3a30ab3af9f941e60abc8ac612540bacbe' },
    { name = 'metamask-usdt02', address = '0xb2c4A7b2F6FC13AE6423038e90ec456Db358D6fe' },
  },

  usdt_bsc = {
    { name = 'binance-usdt01', address = '0xb2c4a7b2f6fc13ae6423038e90ec456db358d6fe' },
  },

  usdt_linea = {
    { name = 'linea-usdt01', address = '0x8d862f3a30ab3af9f941e60abc8ac612540bacbe' },
  },

  usdc_erc20 = {
    { name = 'metamask-usdc01', address = '0x8d862f3a30ab3af9f941e60abc8ac612540bacbe' },
    { name = 'metamask-usdc03', address = '0xb2c4A7b2F6FC13AE6423038e90ec456Db358D6fe' },
    { name = 'trezor-usdc01', address = '0xcd1332F1277B381ccb2cf994DeF4365c125F4385' },
  },

  usdc_arbitrum = {
    { name = 'metamask-usdc02', address = '0x8d862f3a30ab3af9f941e60abc8ac612540bacbe' },
    { name = 'metamask-usdc-arbitrum01', address = '0xb2c4A7b2F6FC13AE6423038e90ec456Db358D6fe' },
  },

  musd_erc20 = {
    { name = 'eth-musd', address = '0x8d862f3a30ab3af9f941e60abc8ac612540bacbe' },
  },

  musd_linea = {
    { name = 'linea-musd', address = '0x8d862f3a30ab3af9f941e60abc8ac612540bacbe' },
  },

  -- Aave V3 lending positions
  -- token = aToken contract (receipt token Aave issues when you lend)
  -- balance = principal + accrued interest, updates every block
  aave_v3 = {
    { name = 'metamask-usdclending01', asset = 'USDC', token = '0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c', decimals = 6, address = '0x8d862f3a30ab3af9f941e60abc8ac612540bacbe' },
  },

}
