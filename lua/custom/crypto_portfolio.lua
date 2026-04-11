local M = {}

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
    { 'curl', '-s', '--max-time', '15', '-L', url },
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
      'curl', '-s', '--max-time', '15',
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Balance fetchers
-- ─────────────────────────────────────────────────────────────────────────────

-- BTC via Blockstream.info — no API key needed
local function fetch_btc(address, cb)
  curl_get('https://blockstream.info/api/address/' .. address, function(data, err)
    if err then cb(nil, err) return end
    local funded = (data.chain_stats and data.chain_stats.funded_txo_sum) or 0
    local spent  = (data.chain_stats and data.chain_stats.spent_txo_sum)  or 0
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

local ETH_RPC = 'https://eth.llamarpc.com'

-- ETH native balance via public JSON-RPC — no API key needed
local function fetch_eth(address, cb)
  curl_post(ETH_RPC, {
    jsonrpc = '2.0', method = 'eth_getBalance',
    params = { address, 'latest' }, id = 1,
  }, function(data, err)
    if err then cb(nil, err) return end
    if data.error then cb(nil, data.error.message) return end
    cb(hex2num(data.result) / 1e18, nil)
  end)
end

-- ERC-20 token registry
local ERC20 = {
  usdt = { contract = '0xdAC17F958D2ee523a2206206994597C13D831ec7', decimals = 6  },
  usdc = { contract = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', decimals = 6  },
  dai  = { contract = '0x6B175474E89094C44Da98b954EedeAC495271d0F', decimals = 18 },
}

-- Generic ERC-20 balanceOf for any contract (DeFi positions, aTokens, etc.)
local function fetch_erc20_at(contract, decimals, address, cb)
  local addr_hex = address:lower():gsub('^0x', '')
  local calldata = '0x70a08231' .. string.rep('0', 64 - #addr_hex) .. addr_hex
  curl_post(ETH_RPC, {
    jsonrpc = '2.0', method = 'eth_call',
    params = { { to = contract, data = calldata }, 'latest' }, id = 1,
  }, function(data, err)
    if err then cb(nil, err) return end
    if data.error then cb(nil, data.error.message) return end
    local raw = hex2num(data.result or '0x0')
    cb(raw / (10 ^ decimals), nil)
  end)
end

-- ERC-20 balance via public JSON-RPC — no API key needed
local function fetch_erc20(token_key, address, cb)
  local tok = ERC20[token_key]
  if not tok then cb(nil, 'Unknown ERC-20 token: ' .. token_key) return end
  -- balanceOf(address) selector = 0x70a08231; address padded to 32 bytes
  local addr_hex = address:lower():gsub('^0x', '')
  local calldata = '0x70a08231' .. string.rep('0', 64 - #addr_hex) .. addr_hex
  curl_post(ETH_RPC, {
    jsonrpc = '2.0', method = 'eth_call',
    params = { { to = tok.contract, data = calldata }, 'latest' }, id = 1,
  }, function(data, err)
    if err then cb(nil, err) return end
    if data.error then cb(nil, data.error.message) return end
    local raw = hex2num(data.result or '0x0')
    cb(raw / (10 ^ tok.decimals), nil)
  end)
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

local function fmt_num(n, decimals)
  if n == nil then return 'ERR' end
  return string.format('%.' .. decimals .. 'f', n)
end

local function pad(s, w)
  return s .. string.rep(' ', w - #s)
end

-- Build a vim-table-mode compatible markdown table.
-- Returns: list of lines, running total (number)
local function build_table(token_name, entries, decimals)
  -- Column width pass
  local w1 = math.max(#token_name, #'Total')
  local w2 = #'Balance'
  local total = 0
  for _, e in ipairs(entries) do
    w1 = math.max(w1, #e.name)
    w2 = math.max(w2, #fmt_num(e.balance, decimals))
    total = total + (e.balance or 0)
  end
  local total_str = fmt_num(total, decimals)
  w2 = math.max(w2, #total_str)

  local lines = {}
  -- Header
  table.insert(lines, '| ' .. pad(token_name, w1) .. ' | ' .. pad('Balance', w2) .. ' |')
  -- Separator (vim-table-mode uses plain dashes, no spaces)
  table.insert(lines, '|' .. string.rep('-', w1 + 2) .. '|' .. string.rep('-', w2 + 2) .. '|')
  -- Data rows
  for _, e in ipairs(entries) do
    local val = fmt_num(e.balance, decimals)
    table.insert(lines, '| ' .. pad(e.name, w1) .. ' | ' .. pad(val, w2) .. ' |')
  end
  -- Total row
  table.insert(lines, '| ' .. pad('Total', w1) .. ' | ' .. pad(total_str, w2) .. ' |')
  -- vim-table-mode formula: row counting is header=1, data rows=2..N+1, total=N+2
  -- Sum(1:-1) = sum all rows in col before the current total row
  local total_row_idx = #entries + 2
  table.insert(lines, '%% tmf: $' .. total_row_idx .. ',2=Sum(1:-1)')

  return lines, total
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Assemble all tables and insert into buffer
-- ─────────────────────────────────────────────────────────────────────────────

local function insert_tables(bufnr, cursor_row, results)
  local lines = {}
  local stablecoins = {}

  local function add_block(name, entries, decimals)
    if #entries == 0 then return nil end
    local tbl, total = build_table(name, entries, decimals)
    vim.list_extend(lines, tbl)
    table.insert(lines, '')
    return total
  end

  add_block('BTC', results.btc, 8)
  add_block('ETH', results.eth, 6)
  add_block('Aave V3', results.aave, 2)

  local usdt_total = add_block('USDT', results.usdt, 2)
  if usdt_total then
    table.insert(stablecoins, { name = 'USDT', balance = usdt_total })
  end

  local usdc_total = add_block('USDC', results.usdc, 2)
  if usdc_total then
    table.insert(stablecoins, { name = 'USDC', balance = usdc_total })
  end

  local dai_total = add_block('DAI', results.dai, 2)
  if dai_total then
    table.insert(stablecoins, { name = 'DAI', balance = dai_total })
  end

  -- Stablecoins summary only when there are 2+ stable assets
  if #stablecoins >= 2 then
    add_block('Stablecoins', stablecoins, 2)
  end

  if #lines == 0 then
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

function M.generate()
  local cfg, err = load_config()
  if err then
    vim.notify(err, vim.log.levels.ERROR, { title = 'CryptoPortfolio' })
    return
  end

  local bufnr      = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

  local results = { btc = {}, eth = {}, usdt = {}, usdc = {}, dai = {}, aave = {} }
  local pending = 0

  local function dec()
    pending = pending - 1
    if pending == 0 then
      insert_tables(bufnr, cursor_row, results)
    end
  end

  -- Allocates a slot (preserves config order even with async responses),
  -- then dispatches the fetcher.  Extra args are passed before the callback.
  local function queue(bucket, name, fetcher, ...)
    local idx = #results[bucket] + 1
    results[bucket][idx] = { name = name, balance = nil }
    pending = pending + 1

    local extra = { ... }
    extra[#extra + 1] = function(bal, ferr)
      if ferr then
        vim.notify(
          bucket:upper() .. ' "' .. name .. '": ' .. ferr,
          vim.log.levels.WARN,
          { title = 'CryptoPortfolio' }
        )
      end
      results[bucket][idx].balance = bal
      dec()
    end

    fetcher(unpack(extra))
  end

  -- BTC wallets
  for _, w in ipairs(cfg.btc or {}) do
    queue('btc', w.name, fetch_btc, w.address)
  end

  -- ETH wallets
  for _, w in ipairs(cfg.eth or {}) do
    queue('eth', w.name, fetch_eth, w.address)
  end

  -- USDT — ERC-20 (Ethereum)
  for _, w in ipairs(cfg.usdt_erc20 or {}) do
    queue('usdt', w.name, fetch_erc20, 'usdt', w.address)
  end

  -- USDT — TRC-20 (Tron)
  for _, w in ipairs(cfg.usdt_trc20 or {}) do
    queue('usdt', w.name, fetch_trc20_usdt, w.address)
  end

  -- USDC — ERC-20 (Ethereum)
  for _, w in ipairs(cfg.usdc_erc20 or {}) do
    queue('usdc', w.name, fetch_erc20, 'usdc', w.address)
  end

  -- USDC — TRC-20 (Tron)
  for _, w in ipairs(cfg.usdc_trc20 or {}) do
    queue('usdc', w.name, fetch_trc20_usdc, w.address)
  end

  -- DAI — ERC-20
  for _, w in ipairs(cfg.dai_erc20 or {}) do
    queue('dai', w.name, fetch_erc20, 'dai', w.address)
  end

  -- Aave V3 lending positions (aToken balanceOf = principal + accrued interest)
  for _, w in ipairs(cfg.aave_v3 or {}) do
    queue('aave', w.name, fetch_erc20_at, w.token, w.decimals or 6, w.address)
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Setup
-- ─────────────────────────────────────────────────────────────────────────────

function M.setup()
  vim.api.nvim_create_user_command('CryptoPortfolio', function()
    M.generate()
  end, { desc = 'Fetch live crypto balances and insert portfolio tables at cursor' })
end

return M
