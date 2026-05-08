local M = {}
local NS = vim.api.nvim_create_namespace('custom.crypto_portfolio')

-- ─────────────────────────────────────────────────────────────────────────────
-- Config loading
-- ─────────────────────────────────────────────────────────────────────────────

local function load_config()
  local path = vim.fn.stdpath('config') .. '/crypto_wallets.lua'
  if vim.fn.filereadable(path) == 0 then
    return nil, table.concat({
      'Wallet config not found: ' .. path,
      'Copy crypto_wallets.example.lua → crypto_wallets.lua and fill in your addresses.',
    }, '\n')
  end
  local ok, cfg = pcall(dofile, path)
  if not ok then
    return nil, 'Error loading crypto_wallets.lua: ' .. tostring(cfg)
  end
  return cfg, nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HTTP helpers (curl-based, async via vim.system)
-- ─────────────────────────────────────────────────────────────────────────────

local function curl_get(url, cb)
  vim.system(
    { 'curl', '-s', '--fail', '--max-time', '15', '-L', url },
    { text = true },
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          cb(nil, 'curl error (exit ' .. obj.code .. '): ' .. (obj.stderr or ''))
          return
        end
        local ok, data = pcall(vim.json.decode, obj.stdout)
        if not ok then
          cb(nil, 'JSON parse error: ' .. obj.stdout:sub(1, 120))
          return
        end
        cb(data, nil)
      end)
    end
  )
end

local function curl_post(url, body, cb)
  vim.system(
    {
      'curl', '-s', '--fail', '--max-time', '15',
      '-X', 'POST',
      '-H', 'Content-Type: application/json',
      '-d', vim.json.encode(body),
      url,
    },
    { text = true },
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          cb(nil, 'curl error (exit ' .. obj.code .. '): ' .. (obj.stderr or ''))
          return
        end
        local ok, data = pcall(vim.json.decode, obj.stdout)
        if not ok then
          cb(nil, 'JSON parse error: ' .. obj.stdout:sub(1, 120))
          return
        end
        cb(data, nil)
      end)
    end
  )
end

local function get_json_fallback(urls, cb, idx, errors)
  idx = idx or 1
  errors = errors or {}

  if idx > #urls then
    cb(nil, table.concat(errors, ' | '))
    return
  end

  curl_get(urls[idx], function(data, err)
    if err then
      errors[#errors + 1] = err
      get_json_fallback(urls, cb, idx + 1, errors)
      return
    end
    cb(data, nil)
  end)
end

local function post_json_fallback(urls, body, cb, idx, errors)
  idx = idx or 1
  errors = errors or {}

  if idx > #urls then
    cb(nil, table.concat(errors, ' | '))
    return
  end

  curl_post(urls[idx], body, function(data, err)
    if err or data == nil or data.error then
      errors[#errors + 1] = err or (data.error and data.error.message) or 'unknown RPC error'
      post_json_fallback(urls, body, cb, idx + 1, errors)
      return
    end
    cb(data, nil)
  end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Balance fetchers
-- ─────────────────────────────────────────────────────────────────────────────

local BTC_API_URLS = {
  'https://blockstream.info/api/address/',
  'https://mempool.space/api/address/',
}

-- BTC via public explorers — no API key needed
local function fetch_btc(address, cb)
  local urls = {}
  for _, base in ipairs(BTC_API_URLS) do
    urls[#urls + 1] = base .. address
  end

  get_json_fallback(urls, function(data, err)
    if err then cb(nil, err) return end
    local funded = (data.chain_stats and data.chain_stats.funded_txo_sum) or 0
    local spent  = (data.chain_stats and data.chain_stats.spent_txo_sum)  or 0
    funded = funded + ((data.mempool_stats and data.mempool_stats.funded_txo_sum) or 0)
    spent = spent + ((data.mempool_stats and data.mempool_stats.spent_txo_sum) or 0)
    cb((funded - spent) / 1e8, nil)
  end)
end

-- Safe hex → number (handles Ethereum returned values)
local function hex2num(hex)
  if not hex then return 0 end
  hex = hex:gsub('^0x', ''):lower()
  if hex == '' then return 0 end
  return tonumber('0x' .. hex) or 0
end

local ETH_RPCS = {
  'https://eth.llamarpc.com',
  'https://ethereum-rpc.publicnode.com',
  'https://1rpc.io/eth',
}

local CHAIN_RPCS = {
  ethereum = ETH_RPCS,
  arbitrum = {
    'https://arb1.arbitrum.io/rpc',
    'https://arbitrum-one-rpc.publicnode.com',
    'https://1rpc.io/arb',
  },
}

-- ETH native balance via public JSON-RPC — no API key needed
local function fetch_eth(address, cb)
  post_json_fallback(ETH_RPCS, {
    jsonrpc = '2.0', method = 'eth_getBalance',
    params = { address, 'latest' }, id = 1,
  }, function(data, err)
    if err then cb(nil, err) return end
    cb(hex2num(data.result) / 1e18, nil)
  end)
end

-- ERC-20 token registry
local ERC20 = {
  usdt = {
    decimals = 6,
    contracts = {
      ethereum = '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    },
  },
  usdc = {
    decimals = 6,
    contracts = {
      ethereum = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      arbitrum = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
    },
  },
  dai = {
    decimals = 18,
    contracts = {
      ethereum = '0x6B175474E89094C44Da98b954EedeAC495271d0F',
    },
  },
}

-- Generic ERC-20 balanceOf for any contract (DeFi positions, aTokens, etc.)
local function fetch_erc20_at_chain(rpcs, contract, decimals, address, cb)
  local addr_hex = address:lower():gsub('^0x', '')
  local calldata = '0x70a08231' .. string.rep('0', 64 - #addr_hex) .. addr_hex
  post_json_fallback(rpcs, {
    jsonrpc = '2.0', method = 'eth_call',
    params = { { to = contract, data = calldata }, 'latest' }, id = 1,
  }, function(data, err)
    if err then cb(nil, err) return end
    local raw = hex2num(data.result or '0x0')
    cb(raw / (10 ^ decimals), nil)
  end)
end

local function fetch_erc20_at(contract, decimals, address, cb)
  fetch_erc20_at_chain(CHAIN_RPCS.ethereum, contract, decimals, address, cb)
end

-- ERC-20 balance via public JSON-RPC — no API key needed
local function fetch_erc20_on_chain(chain, token_key, address, cb)
  local tok = ERC20[token_key]
  if not tok then cb(nil, 'Unknown ERC-20 token: ' .. token_key) return end
  local rpcs = CHAIN_RPCS[chain]
  if not rpcs then cb(nil, 'Unknown EVM chain: ' .. tostring(chain)) return end
  local contract = tok.contracts and tok.contracts[chain]
  if not contract then
    cb(nil, 'Token ' .. token_key .. ' unsupported on chain ' .. tostring(chain))
    return
  end
  -- balanceOf(address) selector = 0x70a08231; address padded to 32 bytes
  local addr_hex = address:lower():gsub('^0x', '')
  local calldata = '0x70a08231' .. string.rep('0', 64 - #addr_hex) .. addr_hex
  post_json_fallback(rpcs, {
    jsonrpc = '2.0', method = 'eth_call',
    params = { { to = contract, data = calldata }, 'latest' }, id = 1,
  }, function(data, err)
    if err then cb(nil, err) return end
    local raw = hex2num(data.result or '0x0')
    cb(raw / (10 ^ tok.decimals), nil)
  end)
end

local function fetch_erc20(token_key, address, cb)
  fetch_erc20_on_chain('ethereum', token_key, address, cb)
end

-- TRC-20 USDT via TronScan — no API key needed
local TRON_USDT_CONTRACT = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'

local function fetch_trc20_usdt(address, cb)
  local url = 'https://apilist.tronscanapi.com/api/account/tokens?address='
    .. address .. '&start=0&limit=50'
  curl_get(url, function(data, err)
    if err then cb(nil, err) return end
    for _, t in ipairs(data.data or {}) do
      if t.tokenId == TRON_USDT_CONTRACT
        or (t.tokenAbbr == 'USDT' and t.tokenType == 'trc20') then
        cb(tonumber(t.quantity) or 0, nil)
        return
      end
    end
    cb(0, nil)
  end)
end

-- TRC-20 USDC via TronScan — no API key needed
local TRON_USDC_CONTRACT = 'TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8'

local function fetch_trc20_usdc(address, cb)
  local url = 'https://apilist.tronscanapi.com/api/account/tokens?address='
    .. address .. '&start=0&limit=50'
  curl_get(url, function(data, err)
    if err then cb(nil, err) return end
    for _, t in ipairs(data.data or {}) do
      if t.tokenId == TRON_USDC_CONTRACT
        or (t.tokenAbbr == 'USDC' and t.tokenType == 'trc20') then
        cb(tonumber(t.quantity) or 0, nil)
        return
      end
    end
    cb(0, nil)
  end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Table rendering
-- ─────────────────────────────────────────────────────────────────────────────

local ASSET_META = {
  BTC = { price_id = 'bitcoin', decimals = 8, kind = 'crypto' },
  ETH = { price_id = 'ethereum', decimals = 6, kind = 'crypto' },
  USDT = { price_id = 'tether', decimals = 2, kind = 'stablecoin' },
  USDC = { price_id = 'usd-coin', decimals = 2, kind = 'stablecoin' },
  DAI = { price_id = 'dai', decimals = 2, kind = 'stablecoin' },
}

local function fmt_num(n, decimals)
  if n == nil then return 'ERR' end
  return string.format('%.' .. decimals .. 'f', n)
end

local function fmt_usd(n)
  if n == nil then return 'N/A' end
  return string.format('$%.2f', n)
end

local function fmt_usd_raw(n)
  if n == nil then return '' end
  return string.format('%.2f', n)
end

local function fmt_pct(n)
  if n == nil then return 'N/A' end
  return string.format('%.2f%%', n)
end

local function pad(s, w)
  return s .. string.rep(' ', w - #s)
end

local function build_markdown_table(headers, rows)
  local widths = {}
  for i, h in ipairs(headers) do
    widths[i] = #h
  end

  for _, row in ipairs(rows) do
    for i, cell in ipairs(row) do
      widths[i] = math.max(widths[i], #tostring(cell))
    end
  end

  local lines = {}
  local header_cells = {}
  local sep_cells = {}

  for i, h in ipairs(headers) do
    header_cells[i] = ' ' .. pad(h, widths[i]) .. ' '
    sep_cells[i] = string.rep('-', widths[i] + 2)
  end

  table.insert(lines, '|' .. table.concat(header_cells, '|') .. '|')
  table.insert(lines, '|' .. table.concat(sep_cells, '|') .. '|')

  for _, row in ipairs(rows) do
    local cells = {}
    for i, cell in ipairs(row) do
      cells[i] = ' ' .. pad(tostring(cell), widths[i]) .. ' '
    end
    table.insert(lines, '|' .. table.concat(cells, '|') .. '|')
  end

  return lines
end

local function formula_comment_prefix()
  local cstring = vim.bo.commentstring or ''
  if cstring == '' or not cstring:find('%%s', 1, true) then
    return '%%'
  end

  local start = cstring:match('^(.*)%%s') or ''
  start = start:gsub('%s+$', '')
  if start == '' then
    return '%%'
  end
  return start
end

local function address_tail(address)
  if address == nil or address == '' then
    return ''
  end
  if #address <= 8 then
    return address
  end
  return address:sub(-8)
end

local function build_table_mode_block(title, headers, rows, total_row, total_col)
  local lines = {}
  table.insert(lines, '### ' .. title)
  local table_rows = vim.deepcopy(rows)

  if total_row then
    table_rows[#table_rows + 1] = total_row
  end

  vim.list_extend(lines, build_markdown_table(headers, table_rows))

  if total_row and total_col then
    table.insert(lines, formula_comment_prefix() .. ' tmf: $-1,' .. total_col .. '=Sum(1:-1)')
  end

  table.insert(lines, '')
  return lines
end

local function infer_aave_asset(entry)
  if entry.asset and entry.asset ~= '' then
    return entry.asset:upper()
  end

  local upper = entry.name:upper()
  for asset, _ in pairs(ASSET_META) do
    if upper:find(asset, 1, true) then
      return asset
    end
  end

  return 'USDC'
end

local function fetch_market_prices(cb)
  local ids = { 'bitcoin', 'ethereum', 'tether', 'usd-coin', 'dai' }
  local url = 'https://api.coingecko.com/api/v3/simple/price?ids=' .. table.concat(ids, ',') .. '&vs_currencies=usd'
  curl_get(url, function(data, err)
    if err then
      cb({}, err)
      return
    end

    local prices = {}
    for symbol, meta in pairs(ASSET_META) do
      local price = data[meta.price_id] and data[meta.price_id].usd
      if price then
        prices[symbol] = price
      end
    end
    cb(prices, nil)
  end)
end

local function summarize_holdings(entries, prices)
  local holdings_rows = {}
  local by_asset = {}
  local by_wallet = {}
  local total_usd = 0
  local lending_usd = 0
  local stablecoin_usd = 0

  for _, entry in ipairs(entries) do
    local meta = ASSET_META[entry.asset] or { decimals = 2, kind = 'crypto' }
    local quantity = entry.balance
    local price = prices[entry.asset]
    local usd_value = (quantity and price) and (quantity * price) or nil

    if usd_value then
      total_usd = total_usd + usd_value
      if entry.protocol == 'Aave V3' then
        lending_usd = lending_usd + usd_value
      end
      if meta.kind == 'stablecoin' then
        stablecoin_usd = stablecoin_usd + usd_value
      end
    end

    holdings_rows[#holdings_rows + 1] = {
      asset = entry.asset,
      protocol = entry.protocol,
      network = entry.network,
      wallet = entry.name,
      quantity = quantity,
      price = price,
      usd_value = usd_value,
      quantity_str = fmt_num(quantity, meta.decimals),
    }

    local asset_row = by_asset[entry.asset] or { quantity = 0, usd_value = 0 }
    asset_row.quantity = asset_row.quantity + (quantity or 0)
    asset_row.usd_value = asset_row.usd_value + (usd_value or 0)
    by_asset[entry.asset] = asset_row

    local wallet_key = entry.name
    local wallet_row = by_wallet[wallet_key] or {
      wallet = entry.name,
      address_tail = address_tail(entry.address),
      usd_value = 0,
    }
    wallet_row.usd_value = wallet_row.usd_value + (usd_value or 0)
    by_wallet[wallet_key] = wallet_row
  end

  table.sort(holdings_rows, function(a, b)
    return (a.usd_value or -1) > (b.usd_value or -1)
  end)

  local asset_rows = {}
  for asset, row in pairs(by_asset) do
    asset_rows[#asset_rows + 1] = {
      asset = asset,
      quantity = row.quantity,
      usd_value = row.usd_value,
      allocation = total_usd > 0 and (row.usd_value / total_usd * 100) or nil,
    }
  end
  table.sort(asset_rows, function(a, b)
    return (a.usd_value or -1) > (b.usd_value or -1)
  end)

  local wallet_rows = {}
  for _, row in pairs(by_wallet) do
    wallet_rows[#wallet_rows + 1] = row
  end
  table.sort(wallet_rows, function(a, b)
    return (a.usd_value or -1) > (b.usd_value or -1)
  end)

  local overview_rows = {
    { 'total portfolio', fmt_usd_raw(total_usd) },
    { 'stablecoins', fmt_usd_raw(stablecoin_usd) },
    { 'lending (aave)', fmt_usd_raw(lending_usd) },
    { 'non-stable assets', fmt_usd_raw(total_usd - stablecoin_usd) },
  }

  local holdings_table_rows = {}
  for _, row in ipairs(holdings_rows) do
    holdings_table_rows[#holdings_table_rows + 1] = {
      row.wallet,
      row.asset,
      row.protocol,
      row.network,
      row.quantity_str,
      fmt_usd_raw(row.price),
      fmt_usd_raw(row.usd_value),
      fmt_pct(total_usd > 0 and row.usd_value and (row.usd_value / total_usd * 100) or nil),
    }
  end

  return overview_rows, holdings_table_rows, asset_rows, wallet_rows, total_usd
end

local function build_portfolio_lines(entries, prices)
  local lines = {}

  if #entries == 0 then
    return nil
  end

  table.insert(lines, '-- script runned ' .. os.date('%d/%m/%Y at %H:%M') .. ' --')
  table.insert(lines, '')

  local overview_rows, holdings_rows, asset_rows, wallet_rows, total_usd = summarize_holdings(entries, prices)

  vim.list_extend(lines, build_table_mode_block(
    'Portfolio Overview',
    { 'metric', 'value_usd' },
    overview_rows
  ))

  vim.list_extend(lines, build_table_mode_block(
    'Holdings',
    { 'wallet', 'asset', 'protocol', 'network', 'quantity', 'price_usd', 'value_usd', 'allocation' },
    holdings_rows,
    { 'total', '', '', '', '', '', fmt_usd_raw(total_usd), '100.00%' },
    7
  ))

  local by_asset_rows = {}
  for _, row in ipairs(asset_rows) do
    by_asset_rows[#by_asset_rows + 1] = {
      row.asset:lower(),
      fmt_num(row.quantity, (ASSET_META[row.asset] and ASSET_META[row.asset].decimals) or 2),
      fmt_usd_raw(row.usd_value),
      fmt_pct(row.allocation),
    }
  end
  vim.list_extend(lines, build_table_mode_block(
    'By Asset',
    { 'asset', 'quantity', 'value_usd', 'allocation' },
    by_asset_rows,
    { 'total', '', fmt_usd_raw(total_usd), '100.00%' },
    3
  ))

  local by_wallet_rows = {}
  for _, row in ipairs(wallet_rows) do
    by_wallet_rows[#by_wallet_rows + 1] = {
      row.wallet,
      row.address_tail,
      fmt_usd_raw(row.usd_value),
    }
  end
  vim.list_extend(lines, build_table_mode_block(
    'By Wallet',
    { 'wallet', 'address_tail', 'value_usd' },
    by_wallet_rows,
    { 'total', '', fmt_usd_raw(total_usd) },
    3
  ))

  return lines
end

local function insert_tables(bufnr, cursor_row, entries, prices)
  local lines = build_portfolio_lines(entries, prices)
  if not lines then
    vim.notify('No wallet data to display.', vim.log.levels.WARN, { title = 'CryptoPortfolio' })
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, cursor_row, cursor_row, false, lines)
  vim.notify(
    'Portfolio inserted (' .. #lines .. ' lines).',
    vim.log.levels.INFO,
    { title = 'CryptoPortfolio' }
  )
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Main entry point
-- ─────────────────────────────────────────────────────────────────────────────

function M.generate_lines(cb)
  local cfg, err = load_config()
  if err then
    vim.notify(err, vim.log.levels.ERROR, { title = 'CryptoPortfolio' })
    return
  end

  local entries = {}
  local pending = 0

  local function finalize()
    fetch_market_prices(function(prices, perr)
      if perr then
        vim.notify(
          'Price feed unavailable: ' .. perr,
          vim.log.levels.WARN,
          { title = 'CryptoPortfolio' }
        )
      end
      cb(build_portfolio_lines(entries, prices or {}))
    end)
  end

  local function dec()
    pending = pending - 1
    if pending == 0 then
      finalize()
    end
  end

  -- Allocates a slot (preserves config order even with async responses),
  -- then dispatches the fetcher.  Extra args are passed before the callback.
  local function queue(entry, fetcher, ...)
    local idx = #entries + 1
    entries[idx] = vim.tbl_extend('force', entry, { balance = nil })
    pending = pending + 1

    local extra = { ... }
    extra[#extra + 1] = function(bal, ferr)
      if ferr then
        vim.notify(
          entry.asset .. ' "' .. entry.name .. '": ' .. ferr,
          vim.log.levels.WARN,
          { title = 'CryptoPortfolio' }
        )
      end
      entries[idx].balance = bal
      dec()
    end

    fetcher(unpack(extra))
  end

  -- BTC wallets
  for _, w in ipairs(cfg.btc or {}) do
    queue({
      name = w.name,
      asset = 'BTC',
      protocol = 'Wallet',
      network = 'Bitcoin',
      address = w.address,
    }, fetch_btc, w.address)
  end

  -- ETH wallets
  for _, w in ipairs(cfg.eth or {}) do
    queue({
      name = w.name,
      asset = 'ETH',
      protocol = 'Wallet',
      network = 'Ethereum',
      address = w.address,
    }, fetch_eth, w.address)
  end

  -- USDT — ERC-20 (Ethereum)
  for _, w in ipairs(cfg.usdt_erc20 or {}) do
    queue({
      name = w.name,
      asset = 'USDT',
      protocol = 'Wallet',
      network = 'Ethereum',
      address = w.address,
    }, fetch_erc20, 'usdt', w.address)
  end

  -- USDT — TRC-20 (Tron)
  for _, w in ipairs(cfg.usdt_trc20 or {}) do
    queue({
      name = w.name,
      asset = 'USDT',
      protocol = 'Wallet',
      network = 'Tron',
      address = w.address,
    }, fetch_trc20_usdt, w.address)
  end

  -- USDC — ERC-20 (Ethereum)
  for _, w in ipairs(cfg.usdc_erc20 or {}) do
    queue({
      name = w.name,
      asset = 'USDC',
      protocol = 'Wallet',
      network = 'Ethereum',
      address = w.address,
    }, fetch_erc20, 'usdc', w.address)
  end

  -- USDC — Arbitrum
  for _, w in ipairs(cfg.usdc_arbitrum or {}) do
    queue({
      name = w.name,
      asset = 'USDC',
      protocol = 'Wallet',
      network = 'Arbitrum',
      address = w.address,
    }, fetch_erc20_on_chain, 'arbitrum', 'usdc', w.address)
  end

  -- USDC — TRC-20 (Tron)
  for _, w in ipairs(cfg.usdc_trc20 or {}) do
    queue({
      name = w.name,
      asset = 'USDC',
      protocol = 'Wallet',
      network = 'Tron',
      address = w.address,
    }, fetch_trc20_usdc, w.address)
  end

  -- DAI — ERC-20
  for _, w in ipairs(cfg.dai_erc20 or {}) do
    queue({
      name = w.name,
      asset = 'DAI',
      protocol = 'Wallet',
      network = 'Ethereum',
      address = w.address,
    }, fetch_erc20, 'dai', w.address)
  end

  -- Aave V3 lending positions (aToken balanceOf = principal + accrued interest)
  for _, w in ipairs(cfg.aave_v3 or {}) do
    queue({
      name = w.name,
      asset = infer_aave_asset(w),
      protocol = 'Aave V3',
      network = 'Ethereum',
      address = w.address,
    }, fetch_erc20_at, w.token, w.decimals or 6, w.address)
  end

  if pending == 0 then
    vim.notify(
      'No wallets configured in crypto_wallets.lua',
      vim.log.levels.WARN,
      { title = 'CryptoPortfolio' }
    )
    return
  end

  vim.notify(
    'Fetching ' .. pending .. ' wallet balance(s)…',
    vim.log.levels.INFO,
    { title = 'CryptoPortfolio' }
  )
end

function M.generate()
  local bufnr      = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

  M.generate_lines(function(lines)
    if not lines then
      vim.notify('No wallet data to display.', vim.log.levels.WARN, { title = 'CryptoPortfolio' })
      return
    end

    vim.api.nvim_buf_set_lines(bufnr, cursor_row, cursor_row, false, lines)
    vim.notify(
      'Portfolio inserted (' .. #lines .. ' lines).',
      vim.log.levels.INFO,
      { title = 'CryptoPortfolio' }
    )
  end)
end

function M.append_at_extmark(bufnr, extmark_id)
  M.generate_lines(function(lines)
    if not lines then
      vim.notify('No wallet data to display.', vim.log.levels.WARN, { title = 'CryptoPortfolio' })
      return
    end

    local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, NS, extmark_id, {})
    if not pos or #pos == 0 then
      vim.notify('Monthly template anchor not found.', vim.log.levels.WARN, { title = 'CryptoPortfolio' })
      return
    end

    local insert_row = pos[1]
    local monthly_block = {
      '',
      '================================================================================ ',
      'WALLETS',
      '',
    }
    vim.list_extend(monthly_block, lines)
    vim.api.nvim_buf_set_lines(bufnr, insert_row, insert_row, false, monthly_block)
    vim.api.nvim_buf_del_extmark(bufnr, NS, extmark_id)
    vim.notify(
      'Portfolio appended to monthly template (' .. #lines .. ' lines).',
      vim.log.levels.INFO,
      { title = 'CryptoPortfolio' }
    )
  end)
end

function M.namespace()
  return NS
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Setup
-- ─────────────────────────────────────────────────────────────────────────────

function M.setup()
  vim.api.nvim_create_user_command('CryptoPortfolio', function()
    M.generate()
  end, { desc = 'Fetch live crypto balances and insert portfolio tables at cursor' })
end

return M
