local ADDON, ns = ...

-- API compatibility: Forever shares the Mainline API, but keep Classic fallbacks.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots

-- User settings; defaults match the values Guldbog used before they were settings.
local DEFAULTS = { minDeposit = 100, duration = 2, ahCut = 0.05, depositLost = true }
local function setting(key)
  local s = GuldbogDB and GuldbogDB.settings
  if s and s[key] ~= nil then return s[key] end
  return DEFAULTS[key]
end
ns.Setting = setting
local bankOpen = false

local function charKey()
  return UnitName("player") .. "-" .. GetRealmName()
end

-- Forever moves characters between shards, and the realm name follows the
-- shard. So the same character can show up under several keys. Fold any
-- older entry for this character into the current one: same GUID, or (for
-- entries saved before we stored GUIDs) same name. Data we haven't seen yet
-- under the new key (bank, mail, recipes ...) is kept from the old entry.
local function mergeDuplicates(key, c)
  local guid = UnitGUID and UnitGUID("player")
  local name = UnitName("player")
  for k, old in pairs(GuldbogDB.chars) do
    if k ~= key and ((guid and old.guid == guid)
        or (not old.guid and (k:match("^([^-]+)")) == name)) then
      for field, value in pairs(old) do
        local cur = c[field]
        if cur == nil or (type(cur) == "table" and next(cur) == nil) then
          c[field] = value
        elseif field == "seen" and type(value) == "table" then
          for what, t in pairs(value) do
            if not cur[what] or t > cur[what] then cur[what] = t end
          end
        end
      end
      local hidden = GuldbogDB.hidden
      if hidden and hidden[k] then hidden[key] = true; hidden[k] = nil end
      GuldbogDB.chars[k] = nil
    end
  end
  c.guid = guid or c.guid
end

-- The key can change while playing (zoning onto another shard), so merge
-- whenever it differs from the last one we used.
local lastKey
local function getChar()
  local key = charKey()
  local c = GuldbogDB.chars[key]
  if not c then
    c = { bags = {}, bank = {}, profs = {} }
    GuldbogDB.chars[key] = c
  end
  if key ~= lastKey then
    lastKey = key
    mergeDuplicates(key, c)
  end
  return c
end

local function getSlot(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.itemID, info.stackCount, info.isBound, info.hyperlink end
  elseif GetContainerItemInfo then
    local _, count, _, _, _, _, link, _, _, itemID, isBound = GetContainerItemInfo(bag, slot)
    return itemID, count, isBound, link
  end
end

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

-- Weapons and armor can have random suffixes ("of Arcane Protection") that share
-- the base item ID, so remember the full link to show the right name and price.
local function isGear(itemID)
  if not GetItemInfoInstant then return false end
  local classID = select(6, GetItemInfoInstant(itemID))
  return classID == 2 or classID == 4
end

local function scanContainers(list)
  local items = {}
  for _, bag in ipairs(list) do
    local ok, n = pcall(GetNumSlots, bag)
    if ok and n then
      for slot = 1, n do
        local id, count, bound, link = getSlot(bag, slot)
        if id and not bound then
          items[id] = (items[id] or 0) + (count or 1)
          if link and isGear(id) then GuldbogDB.links[id] = link end
        end
      end
    end
  end
  return items
end

local function bagList()
  local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
  local list = {}
  for i = 0, last do list[#list + 1] = i end
  return list
end

local function bankList()
  local list, seen = { -1 }, { [-1] = true }
  if Enum and Enum.BagIndex then
    for name, value in pairs(Enum.BagIndex) do
      if type(value) == "number" and not seen[value]
         and (name:find("Bank") or name:find("bank"))
         and not name:find("Account") then
        list[#list + 1] = value
        seen[value] = true
      end
    end
  else
    for i = 5, 11 do list[#list + 1] = i end
  end
  return list
end

local function scanProfessions()
  local profs = {}
  if GetProfessions then
    -- prof1, prof2, archaeology, fishing, cooking (first aid isn't always listed)
    local idx = { GetProfessions() }
    for i = 1, 5 do
      if idx[i] then
        local _, _, rank, _, _, _, skillLine = GetProfessionInfo(idx[i])
        if skillLine and ns.PROF_NAMES[skillLine] then profs[skillLine] = rank end
      end
    end
  end
  if next(profs) == nil and GetNumSkillLines then
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank = GetSkillLineInfo(i)
      if not isHeader then
        for id, n in pairs(ns.PROF_NAMES) do
          if n == name then profs[id] = rank end
        end
      end
    end
  end
  if next(profs) == nil then return end
  -- Keep secondary professions we only know about from their window (e.g. First Aid).
  local c = getChar()
  for skill in pairs(c.trade or {}) do
    if ns.SECONDARY[skill] and not profs[skill] then
      profs[skill] = (c.profs and c.profs[skill]) or 1
    end
  end
  c.profs = profs
end

local function profByName(name)
  for id, n in pairs(ns.PROF_NAMES) do
    if n == name then return id end
  end
end

local DIFFICULTY = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }

local function difficultyOf(r)
  return r.difficulty or DIFFICULTY[r.relativeDifficulty] or "optimal"
end

local function isBasicSlot(slot)
  local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
  return basic == nil or slot.reagentType == nil or slot.reagentType == basic
end

-- Reads the open profession window: known recipes, what each one makes and
-- needs, and which materials are used by recipes that still give skill.
local function scanTradeSkill()
  local skill, known, mats, recipes, found = nil, {}, {}, {}, false

  local function add(name, diff, out, qty, need)
    found = true
    known[name] = true
    if diff ~= "trivial" then
      for id in pairs(need) do mats[id] = true end
    end
    if out then
      recipes[#recipes + 1] = { name = name, diff = diff, out = out, qty = qty or 1, mats = need }
    end
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
    local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if ok and info then
      skill = ns.PROF_NAMES[info.professionID] and info.professionID
              or profByName(info.professionName)
    end
    if not skill then return end
    for _, rid in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
      local r = C_TradeSkillUI.GetRecipeInfo(rid)
      if r and r.learned then
        local need, out, qty = {}, nil, 1
        local okS, sch = pcall(C_TradeSkillUI.GetRecipeSchematic, rid, false)
        if okS and sch then
          out, qty = sch.outputItemID, sch.quantityMin
          for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
            local reagent = slot.reagents and slot.reagents[1]
            if reagent and reagent.itemID and isBasicSlot(slot) then
              need[reagent.itemID] = (need[reagent.itemID] or 0) + (slot.quantityRequired or 1)
            end
          end
        end
        add(r.name, difficultyOf(r), out, qty, need)
      end
    end
  elseif GetNumTradeSkills and GetTradeSkillLine then
    skill = profByName((GetTradeSkillLine()))
    if not skill then return end
    for i = 1, GetNumTradeSkills() do
      local name, kind = GetTradeSkillInfo(i)
      if name and kind ~= "header" then
        local need = {}
        for j = 1, GetTradeSkillNumReagents(i) do
          local _, _, n = GetTradeSkillReagentInfo(i, j)
          local link = GetTradeSkillReagentItemLink(i, j)
          local id = link and tonumber(link:match("item:(%d+)"))
          if id then need[id] = (need[id] or 0) + (n or 1) end
        end
        local outLink = GetTradeSkillItemLink(i)
        local out = outLink and tonumber(outLink:match("item:(%d+)"))
        add(name, kind, out, (GetTradeSkillNumMade(i)), need)
      end
    end
  end

  -- Never overwrite good data with an empty read.
  if skill and found then
    local c = getChar()
    c.trade = c.trade or {}
    c.trade[skill] = { known = known, mats = mats, recipes = recipes }
    c.profs = c.profs or {}
    c.profs[skill] = c.profs[skill] or 1
  end
end

local function scanMail()
  if not GetInboxNumItems then return end
  local items = {}
  for i = 1, GetInboxNumItems() do
    for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
      local _, itemID, _, count = GetInboxItem(i, a)
      if itemID then items[itemID] = (items[itemID] or 0) + (count or 1) end
    end
  end
  getChar().mail = items
  local c = getChar()
  c.seen = c.seen or {}
  c.seen.mail = time()
end

-- Mail to our own characters: snapshot recipient and attachments when Send is
-- clicked, and credit them to the recipient once the game confirms the send.
local pendingMail

local function charKeyByName(name)
  local who = name and name:match("^%s*([^-%s]+)")
  if not who then return end
  who = who:lower()
  for key in pairs(GuldbogDB.chars) do
    if (key:match("^([^-]+)") or ""):lower() == who then return key end
  end
end

local function snapshotOutgoingMail()
  pendingMail = nil
  local recipient = SendMailNameEditBox and SendMailNameEditBox:GetText()
  local key = charKeyByName(recipient)
  if not key or not GetSendMailItem then return end
  local items = {}
  for i = 1, (ATTACHMENTS_MAX_SEND or 12) do
    local _, itemID, _, count = GetSendMailItem(i)
    if itemID then items[itemID] = (items[itemID] or 0) + (count or 1) end
  end
  if next(items) then pendingMail = { key = key, items = items } end
end

local function creditPendingMail()
  if not pendingMail then return end
  local c = GuldbogDB.chars[pendingMail.key]
  c.mail = c.mail or {}
  for id, n in pairs(pendingMail.items) do c.mail[id] = (c.mail[id] or 0) + n end
  pendingMail = nil
end

local sendHooked = false
local function hookSendButton()
  if sendHooked or not SendMailMailButton then return end
  SendMailMailButton:HookScript("OnClick", snapshotOutgoingMail)
  sendHooked = true
end

local function queryOwnedAuctions()
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() and C_AuctionHouse
     and C_AuctionHouse.QueryOwnedAuctions then
    pcall(C_AuctionHouse.QueryOwnedAuctions, {})
  end
end

local function scanOwnedAuctions()
  if not (C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions) then return end
  local sold = Enum and Enum.AuctionStatus and Enum.AuctionStatus.Sold or 1
  local items = {}
  for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
    local a = C_AuctionHouse.GetOwnedAuctionInfo(i)
    if a and a.status ~= sold and a.itemKey and a.itemKey.itemID then
      local id = a.itemKey.itemID
      items[id] = (items[id] or 0) + (a.quantity or 1)
    end
  end
  getChar().auctions = items
end

local function scanBags()
  getChar().bags = scanContainers(bagList())
end

local function markSeen(what)
  local c = getChar()
  c.seen = c.seen or {}
  c.seen[what] = time()
end

local function scanBank()
  if bankOpen then
    getChar().bank = scanContainers(bankList())
    markSeen("bank")
  end
end

-- Price sources: Auctionator first, TSM as fallback. Whatever is installed.
local function hasAuctionator()
  return Auctionator and Auctionator.API and Auctionator.API.v1
         and Auctionator.API.v1.GetAuctionPriceByItemID and true or false
end

local function hasTSM()
  return TSM_API and TSM_API.GetCustomPriceValue and true or false
end

function ns.PriceSource()
  if hasAuctionator() then return "Auctionator" end
  if hasTSM() then return "TSM" end
end

local function tsmPrice(source, itemID)
  if not hasTSM() then return nil end
  local link = GuldbogDB.links and GuldbogDB.links[itemID]
  local itemString = "i:" .. itemID
  if link and TSM_API.ToItemString then
    local ok, str = pcall(TSM_API.ToItemString, link)
    if ok and str then itemString = str end
  end
  local ok, price = pcall(TSM_API.GetCustomPriceValue, source, itemString)
  if ok and price and price > 0 then return price end
end

local function ahPrice(itemID)
  if hasAuctionator() then
    local link = GuldbogDB.links and GuldbogDB.links[itemID]
    if link and Auctionator.API.v1.GetAuctionPriceByItemLink then
      local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemLink, ADDON, link)
      if ok and price then return price end
    end
    local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON, itemID)
    if ok and price then return price end
  end
  return tsmPrice("DBMinBuyout", itemID) or tsmPrice("DBMarket", itemID)
end

-- Finds the item in this character's bags.
local function findInBags(itemID)
  for _, bag in ipairs(bagList()) do
    local ok, n = pcall(GetNumSlots, bag)
    if ok and n then
      for slot = 1, n do
        local id, _, bound = getSlot(bag, slot)
        if id == itemID and not bound then return bag, slot end
      end
    end
  end
end

-- Opens the item in the game's own Sell tab on the AH. Used without Auctionator,
-- or when Auctionator's internals have changed. Returns true on success.
local function sellInBlizzardUI(loc)
  return pcall(function()
    local commodity = C_AuctionHouse.GetItemCommodityStatus(loc) == Enum.ItemCommodityStatus.Commodity
    AuctionHouseFrame:SetDisplayMode(commodity and AuctionHouseFrameDisplayMode.CommoditiesSell
                                     or AuctionHouseFrameDisplayMode.ItemSell)
    local sellFrame = commodity and AuctionHouseFrame.CommoditiesSellFrame or AuctionHouseFrame.ItemSellFrame
    sellFrame:SetItem(loc)
  end)
end

-- Auctionator has no public API for selecting an item to sell, so we mirror its
-- own bag-click hook (Source_ModernAH/Selling/Hooks.lua). Check every piece first,
-- so an Auctionator update makes us fall back instead of breaking.
local function auctionatorSellReady()
  return Auctionator and Auctionator.EventBus and Auctionator.Selling and Auctionator.Selling.Events
     and Auctionator.Selling.Events.BagItemClicked and Auctionator.Groups and Auctionator.Groups.Utilities
     and Auctionator.Groups.Utilities.ToPostingItem and AuctionatorTabs_Selling
     and AuctionatorBagCacheFrame and AuctionatorBagCacheFrame.CacheLinkInfo
     and AuctionatorBagCacheFrame.GetByLinkInstant and true or false
end

local function sellInAuctionator(loc, onFail)
  return pcall(function()
    AuctionHouseFrame.ItemSellFrame:SetItem(nil, nil, false)
    AuctionHouseFrame.CommoditiesSellFrame:SetItem(nil, nil, false)
    AuctionatorTabs_Selling:Click()
    local link = C_Item.GetItemLink(loc)
    AuctionatorBagCacheFrame:CacheLinkInfo(link, function()
      -- Runs later, so it needs its own safety net.
      local ok = pcall(function()
        local info = Auctionator.Groups.Utilities.ToPostingItem(
          AuctionatorBagCacheFrame:GetByLinkInstant(link, true))
        info.itemLink = link
        info.location = loc
        info.count = C_AuctionHouse.GetAvailablePostCount(loc)
        Auctionator.EventBus:RegisterSource(sellInAuctionator, "GuldbogSell")
        Auctionator.EventBus:Fire(sellInAuctionator, Auctionator.Selling.Events.BagItemClicked, info)
      end)
      if not ok then onFail() end
    end)
  end)
end

-- Click on a "Sell on AH" row: Auctionator's Sell tab if possible, otherwise the
-- game's own. The player always presses Post themselves.
local function sellOnAH(itemID)
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
    ns.Say("MSG_OPEN_AH")
    return
  end
  local bag, slot = findInBags(itemID)
  if not bag then
    ns.Say("MSG_NOT_IN_BAGS")
    return
  end
  local okLoc, loc = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
  if not okLoc or not loc or not C_AuctionHouse.IsSellItemValid(loc) then
    ns.Say("MSG_AH_FAIL")
    return
  end
  local function fallback()
    if sellInBlizzardUI(loc) then ns.Say("MSG_AH_FALLBACK") else ns.Say("MSG_AH_FAIL") end
  end
  if auctionatorSellReady() then
    if not sellInAuctionator(loc, fallback) then fallback() end
  elseif not sellInBlizzardUI(loc) then
    ns.Say("MSG_AH_FAIL")
  end
end

ns.SellOnAH = sellOnAH
ns.SellInAuctionator = sellOnAH

-- Sells every stack of the item in this character's bags to the open merchant.
-- The merchant's buyback tab can undo it.
local function sellToVendor(itemID)
  if not (MerchantFrame and MerchantFrame:IsShown()) then
    ns.Say("MSG_TALK_VENDOR")
    return
  end
  local use = (C_Container and C_Container.UseContainerItem) or UseContainerItem
  local sold = 0
  for _, bag in ipairs(bagList()) do
    local ok, n = pcall(GetNumSlots, bag)
    if ok and n then
      for slot = 1, n do
        local id, count, bound = getSlot(bag, slot)
        if id == itemID and not bound then
          use(bag, slot)
          sold = sold + (count or 1)
        end
      end
    end
  end
  if sold == 0 then
    ns.Say("MSG_NOT_IN_BAGS")
  else
    ns.Say("MSG_SOLD", sold)
  end
end
ns.SellToVendor = sellToVendor


-- While the AH is open, ask the game what posting each bag item would cost.
local function updateDeposits()
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown() and C_AuctionHouse
          and C_AuctionHouse.CalculateCommodityDeposit and Enum and Enum.ItemCommodityStatus) then
    return
  end
  local bags, seen = getChar().bags or {}, {}
  for _, bag in ipairs(bagList()) do
    local ok, n = pcall(GetNumSlots, bag)
    if ok and n then
      for slot = 1, n do
        local id, _, bound = getSlot(bag, slot)
        if id and not bound and not seen[id] then
          seen[id] = true
          pcall(function()
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if not C_AuctionHouse.IsSellItemValid(loc, false) then return end
            local status = C_AuctionHouse.GetItemCommodityStatus(loc)
            if status == Enum.ItemCommodityStatus.Commodity then
              local qty = bags[id] or 1
              local dep = C_AuctionHouse.CalculateCommodityDeposit(id, setting("duration"), qty)
              if dep then GuldbogDB.deposit[id] = { total = dep, qty = qty } end
            elseif status == Enum.ItemCommodityStatus.Item then
              local dep = C_AuctionHouse.CalculateItemDeposit(loc, setting("duration"), 1)
              if dep then GuldbogDB.deposit[id] = { total = dep, qty = 1, perAuction = true } end
            end
          end)
        end
      end
    end
  end
end

-- Estimated deposit for posting `count` of an item, and whether it came from the game.
local function depositFor(id, count)
  local d = GuldbogDB.deposit[id]
  if not d or not d.qty or d.qty <= 0 then return setting("minDeposit"), false end
  if d.perAuction then
    -- Non-stackable items: one auction each.
    return math.max(d.total, setting("minDeposit")) * count, true
  end
  return math.max(d.total * count / d.qty, setting("minDeposit")), true
end

local function shortName(key)
  return (key:match("^([^-]+)")) or key
end

-- Characters the player hasn't hidden in Settings. Hidden ones keep their data
-- but are left out of every list and suggestion.
local function activeChars()
  local hidden = GuldbogDB.hidden or {}
  local key, c
  return function()
    repeat
      key, c = next(GuldbogDB.chars, key)
    until key == nil or not hidden[key]
    return key, c
  end
end
ns.ActiveChars = activeChars

-- "Name (Profession)" for every character that still needs this material.
-- Uses the scanned profession window when available, else the fixed list.
local function whoUses(itemID)
  local out = {}
  for key, c in activeChars() do
    for skill in pairs(c.profs or {}) do
      local t = c.trade and c.trade[skill]
      local uses
      if t then uses = t.mats[itemID] else uses = ns.USED_BY[itemID] == skill end
      if uses then
        out[#out + 1] = shortName(key) .. " (" .. ns.PROF_NAMES[skill] .. ")"
      end
    end
  end
  table.sort(out)
  return out
end

-- Characters that have the recipe's profession and don't know it yet.
local function whoCanLearn(skill, teaches)
  local out = {}
  for key, c in activeChars() do
    if c.profs and c.profs[skill] then
      local t = c.trade and c.trade[skill]
      if not (t and teaches and t.known[teaches]) then
        out[#out + 1] = shortName(key) .. " (" .. ns.PROF_NAMES[skill] .. ")"
      end
    end
  end
  table.sort(out)
  return out
end

-- Item counts across all characters (bags and bank), and who holds what.
-- Auctions are kept apart: they're not available until they come back.
local function holdings()
  local totals, holders, onAH = {}, {}, {}
  local function add(store, label, target)
    for id, count in pairs(store or {}) do
      if count > 0 then
        target[id] = (target[id] or 0) + count
        holders[id] = holders[id] or {}
        holders[id][label] = (holders[id][label] or 0) + count
      end
    end
  end
  for key, c in activeChars() do
    local name = shortName(key)
    add(c.bags, name, totals)
    add(c.bank, name, totals)
    add(c.mail, name .. " " .. ns.T("HOLDER_MAIL"), totals)
    add(c.auctions, name .. " " .. ns.T("HOLDER_AH"), onAH)
  end
  return totals, holders, onAH
end

local function vendorBuyPrice(itemID)
  if hasAuctionator() and Auctionator.API.v1.GetVendorPriceByItemID then
    local ok, price = pcall(Auctionator.API.v1.GetVendorPriceByItemID, ADDON, itemID)
    if ok and price then return price end
  end
  return tsmPrice("VendorBuy", itemID)
end

-- Cheapest known way to get one unit of a material: AH or a vendor.
local function materialCost(itemID)
  local ah, vendor = ahPrice(itemID), vendorBuyPrice(itemID)
  if ah and vendor then return math.min(ah, vendor) end
  return ah or vendor
end

-- One row per known recipe that makes an item, with cost, sale and gain.
function ns.BuildCraftRows()
  local totals = holdings()
  local rows, profitable = {}, 0
  for key, c in activeChars() do
    for skill, t in pairs(c.trade or {}) do
      if c.profs and c.profs[skill] then
        for _, rec in ipairs(t.recipes or {}) do
          local cost, missing, canMake = 0, false, nil
          for id, n in pairs(rec.mats) do
            local p = materialCost(id)
            if p then cost = cost + p * n else missing = true end
            local possible = math.floor((totals[id] or 0) / n)
            canMake = canMake and math.min(canMake, possible) or possible
          end
          local name, link, _, _, _, _, _, _, _, _, vendor = GetItemInfo(rec.out)
          if not name and C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(rec.out)
          end
          local ah = ahPrice(rec.out)
          local sale, via
          if ah then
            sale = ah * rec.qty * (1 - setting("ahCut"))
            if setting("depositLost") then sale = sale - (depositFor(rec.out, rec.qty)) end
            via = "AH"
          end
          if vendor and vendor > 0 and (not sale or vendor * rec.qty > sale) then
            sale, via = vendor * rec.qty, "vendor"
          end
          -- Skip things that can't be sold at all (e.g. camp objects).
          if sale then
            local row = {
              id = rec.out, link = link or name or rec.name, crafter = shortName(key),
            sortName = name or rec.name,
              skill = skill, diff = rec.diff, qty = rec.qty, mats = rec.mats,
              cost = cost, missing = missing, sale = sale, via = via,
              canMake = canMake or 0,
            }
            if sale and not missing then
              row.gain = sale - cost
              if row.gain > 0 then profitable = profitable + 1 end
            end
            rows[#rows + 1] = row
          end
        end
      end
    end
  end
  table.sort(rows, function(a, b)
    if (a.gain ~= nil) ~= (b.gain ~= nil) then return a.gain ~= nil end
    if a.gain and a.gain ~= b.gain then return a.gain > b.gain end
    return tostring(a.link) < tostring(b.link)
  end)
  return rows, profitable
end
ns.MaterialCost = materialCost

-- Friends -------------------------------------------------------------------

local function classToken(localized)
  if not localized then return nil end
  for _, t in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
    for token, name in pairs(t) do
      if name == localized then return token end
    end
  end
  local up = localized:upper():gsub("%s", "")
  if ns.WEAPONS[up] then return up end
end

-- Name, class, level and online state for everyone on the friends list.
local function readFriends()
  local out = {}
  if C_FriendList and C_FriendList.GetNumFriends then
    for i = 1, C_FriendList.GetNumFriends() or 0 do
      local f = C_FriendList.GetFriendInfoByIndex(i)
      if f and f.name then
        out[#out + 1] = { name = f.name, level = f.level, class = f.className,
                          token = classToken(f.className), online = f.connected }
      end
    end
  elseif GetNumFriends then
    for i = 1, GetNumFriends() do
      local name, level, class, _, connected = GetFriendInfo(i)
      if name then
        out[#out + 1] = { name = name, level = level, class = class,
                          token = classToken(class), online = connected }
      end
    end
  end

  -- Battle.net friends: only visible while they're logged into a WoW character.
  -- Keep those in this game version and on our faction, so mail can reach them.
  if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
    local seen = {}
    for _, f in ipairs(out) do seen[f.name] = true end
    local myFaction = UnitFactionGroup and UnitFactionGroup("player")
    for i = 1, BNGetNumFriends() or 0 do
      local okA, acc = pcall(C_BattleNet.GetFriendAccountInfo, i)
      local g = okA and acc and acc.gameAccountInfo
      if g and g.isOnline and g.characterName and g.characterName ~= ""
         and (g.clientProgram == nil or g.clientProgram == (BNET_CLIENT_WOW or "WoW"))
         and (g.wowProjectID == nil or WOW_PROJECT_ID == nil or g.wowProjectID == WOW_PROJECT_ID)
         and (g.factionName == nil or myFaction == nil or g.factionName == myFaction) then
        -- Forever: full name incl. surname ("Tegaman Tmanic"). The realm is only
        -- a shard (EU4, EU5 ...), not part of the address, so leave it out.
        local name = g.characterName
        if not seen[name] then
          seen[name] = true
          out[#out + 1] = { name = name, level = g.characterLevel, class = g.className,
                            token = classToken(g.className), online = true }
        end
      end
    end
  end
  return out
end

-- One row per (friend, item) where the friend can use gear we own.
function ns.BuildFriendRows()
  local totals, holders = holdings()
  local friends = readFriends()
  local rows = {}
  for id, count in pairs(totals) do
    local item = GuldbogDB.links[id] or id
    local name, link, _, _, minLevel, _, _, _, equipLoc, _, vendor, classID, subclassID = GetItemInfo(item)
    if name and (classID == 2 or classID == 4) and equipLoc and equipLoc ~= ""
       and not ns.TOOLS[id] and not GuldbogDB.keep[id] then
      local ah = ahPrice(id)
      for _, f in ipairs(friends) do
        if ns.CanUse(f.token, f.level, classID, subclassID, minLevel) then
          rows[#rows + 1] = {
            id = id, link = link or name, count = count, holders = holders[id],
            here = holders[id][UnitName("player")] or 0,
            ah = ah, vendor = vendor, value = (ah or vendor or 0) * count,
            friend = f, sortName = name,
          }
        end
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.friend.online ~= b.friend.online then return a.friend.online and true or false end
    if a.friend.name ~= b.friend.name then return a.friend.name < b.friend.name end
    return a.value > b.value
  end)
  return rows, #friends
end

-- At an open mailbox: switch to Send, fill in the friend and attach the item.
-- The player presses Send themselves.
local function prepareMailTo(row)
  if not (MailFrame and MailFrame:IsShown()) then
    ns.Say("MSG_OPEN_MAIL")
    return
  end
  local bag, slot = findInBags(row.id)
  if not bag then
    ns.Say("MSG_NOT_IN_BAGS")
    return
  end
  local ok = pcall(function()
    if MailFrameTab2 then MailFrameTab2:Click() end
    SendMailNameEditBox:SetText(row.friend.name)
    local pickup = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
    ClearCursor()
    pickup(bag, slot)
    ClickSendMailItemButton()
  end)
  if ok then
    ns.Say("MSG_MAIL_READY", tostring(row.link), row.friend.name)
  else
    ClearCursor()
    ns.Say("MSG_MAIL_FAIL")
  end
end
ns.PrepareMailTo = prepareMailTo

-- Builds one row per item across all characters, with advice.
function ns.BuildRows()
  local totals, holders, onAH = holdings()
  for id in pairs(onAH) do totals[id] = totals[id] or 0 end

  local rows, sellTotal = {}, 0
  for id, count in pairs(totals) do
    local name, link, _, _, _, _, _, _, _, _, vendor, classID, subclassID = GetItemInfo(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
      -- Not cached yet; the server answers with GET_ITEM_INFO_RECEIVED.
      C_Item.RequestLoadItemDataByID(id)
    end
    local ah = ahPrice(id)
    local row = {
      id = id, count = count, holders = holders[id],
      here = holders[id][UnitName("player")] or 0,
      sortName = name or "",
      link = GuldbogDB.links[id] or link or name or ns.T("ITEM_N", id),
      ah = ah, vendor = vendor, onAH = onAH[id] or 0,
    }
    if ah and count > 0 then
      -- Extra copper from selling on the AH instead of to a vendor,
      -- after the AH cut and the deposit (counted as lost to be safe).
      row.deposit, row.depositKnown = depositFor(id, count)
      row.gain = (ah * (1 - setting("ahCut")) - (vendor or 0)) * count
      if setting("depositLost") then row.gain = row.gain - row.deposit end
    end

    local users = whoUses(id)
    local learners = {}
    local recipeSkill = classID == ns.RECIPE_CLASS and ns.RECIPE_SUBCLASS[subclassID]
    if recipeSkill and name then
      learners = whoCanLearn(recipeSkill, name:match(":%s*(.+)$"))
    end
    if count == 0 then
      row.advice = ns.T("ADV_ON_AH", row.onAH)
      row.kind = 6
      row.group = "onah"
    elseif ns.TOOLS[id] then
      row.advice = ns.T("ADV_KEEP_TOOL")
      row.kind = 5
      row.group = "tool"
    elseif GuldbogDB.keep[id] then
      row.advice = ns.T("ADV_KEEP_CHOICE")
      row.kind = 5
      row.group = "keep"
    elseif #learners > 0 then
      row.advice = ns.T("ADV_LEARN", table.concat(learners, ", "))
      row.kind = 1
      row.group = "use"
    elseif #users > 0 then
      row.advice = ns.T("ADV_USE", table.concat(users, ", "))
      row.kind = 1
      row.group = "use"
    elseif row.gain and row.gain > 0 then
      row.advice = ns.T("ADV_SELL_AH")
      row.kind = 2
      row.group = "ah"
      row.saleValue = ah * (1 - setting("ahCut")) * count
      sellTotal = sellTotal + row.saleValue
    elseif vendor and vendor > 0 then
      row.advice = ns.T("ADV_SELL_VENDOR")
      row.kind = 3
      row.group = "vendor"
      row.saleValue = vendor * count
      sellTotal = sellTotal + row.saleValue
    elseif ah then
      row.advice = ns.T("ADV_NO_PROFIT")
      row.kind = 4
      row.group = "none"
    else
      row.advice = ns.T("ADV_NO_PRICE")
      row.kind = 4
      row.group = "none"
    end
    if row.kind == 6 then
      row.value = (ah or vendor or 0) * row.onAH
    elseif row.kind == 3 then
      row.value = vendor * count
    else
      row.value = (ah or vendor or 0) * count
    end
    rows[#rows + 1] = row
  end

  table.sort(rows, function(a, b)
    if a.kind ~= b.kind then return a.kind < b.kind end
    return a.value > b.value
  end)
  return rows, sellTotal
end

-- UI -------------------------------------------------------------------------

local ROW_H = 20
local frame, content, totalText, statusText
local uiRows = {}
local headerFS = {}
local mode = "stock" -- "stock" (Lager) or "craft" (Crafting)

local HEADERS = {
  stock = { "COL_ITEM", "COL_TOTAL", "COL_HERE", "COL_PRICE", "COL_VALUE", "COL_PROFIT", "COL_SUGGESTION" },
  craft = { "COL_MAKES", "COL_CANMAKE", "", "COL_MATERIALS", "COL_SALE", "COL_PROFIT", "COL_CRAFTER" },
  friends = { "COL_ITEM", "COL_TOTAL", "COL_HERE", "COL_PRICE", "COL_VALUE", "", "COL_USABLEBY" },
}

local DIFF_TEXT = {
  optimal = { "ff8040", "DIFF_OPTIMAL" }, medium = { "ffff00", "DIFF_MEDIUM" },
  easy = { "40c040", "DIFF_EASY" }, trivial = { "808080", "DIFF_TRIVIAL" },
}

-- Own formatting: Forever has no GetCoinTextureString.
local function money(copper)
  if not copper or copper <= 0 then return "–" end
  copper = math.floor(copper)
  local g = math.floor(copper / 10000)
  local s = math.floor(copper / 100) % 100
  local c = copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = "|cffffd700" .. g .. "g|r" end
  if s > 0 then parts[#parts + 1] = "|cffc7c7cf" .. s .. "s|r" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = "|cffeda55f" .. c .. "c|r" end
  return table.concat(parts, " ")
end

local function getRow(i)
  if uiRows[i] then return uiRows[i] end
  local r = CreateFrame("Frame", nil, content)
  r:SetSize(790, ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  r:EnableMouse(true)

  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", 2, 0)

  local function col(x, w, justify)
    local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", x, 0)
    fs:SetWidth(w)
    fs:SetJustifyH(justify)
    fs:SetWordWrap(false)
    return fs
  end
  r.name   = col(22, 175, "LEFT")
  r.count  = col(200, 40, "RIGHT")
  r.here   = col(244, 35, "RIGHT")
  r.price  = col(283, 80, "RIGHT")
  r.value  = col(367, 80, "RIGHT")
  r.gain   = col(451, 80, "RIGHT")
  r.advice = col(540, 245, "LEFT")
  r.header = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.header:SetPoint("LEFT", 22, 0)
  r.header:SetWidth(760)
  r.header:SetJustifyH("LEFT")
  r.header:SetWordWrap(false)

  r:SetScript("OnEnter", function(self)
    if not self.data or self.data.isHeader then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local gearLink = mode == "stock" and GuldbogDB.links[self.data.id]
    if gearLink then GameTooltip:SetHyperlink(gearLink) else GameTooltip:SetItemByID(self.data.id) end
    GameTooltip:AddLine(" ")
    if mode == "friends" then
      GameTooltip:AddLine(ns.T("TT_CLICK_MAIL", self.data.friend.name), 0.6, 0.6, 0.6)
      GameTooltip:Show()
      return
    end
    if mode == "craft" then
      if self.data.qty > 1 then GameTooltip:AddLine(ns.T("TT_MAKES", self.data.qty), 1, 1, 1) end
      for id, n in pairs(self.data.mats) do
        local mname = GetItemInfo(id) or ns.T("ITEM_N", id)
        local p = ns.MaterialCost(id)
        GameTooltip:AddDoubleLine(n .. " x " .. mname, p and money(p * n) or ns.T("NO_PRICE"),
          0.8, 0.8, 0.8, 1, 1, 1)
      end
      if self.data.via then
        GameTooltip:AddDoubleLine(ns.T("TT_SOLD_VIA"), self.data.via, 0.8, 0.8, 0.8, 1, 1, 1)
      end
      GameTooltip:Show()
      return
    end
    for who, n in pairs(self.data.holders) do
      GameTooltip:AddDoubleLine(who, n, 1, 1, 1, 1, 1, 1)
    end
    if self.data.deposit then
      local note = self.data.depositKnown and "" or ns.T("TT_ESTIMATED")
      GameTooltip:AddDoubleLine(ns.T("TT_DEPOSIT") .. note, money(self.data.deposit), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    if self.data.kind == 3 then
      GameTooltip:AddLine(ns.T("TT_CLICK_VENDOR"), 0.6, 0.6, 0.6)
    end
    if self.data.kind == 2 then
      GameTooltip:AddLine(ns.T("TT_CLICK_AH"), 0.6, 0.6, 0.6)
    end
    if not ns.TOOLS[self.data.id] then
      GameTooltip:AddLine(ns.T("TT_ALT_KEEP"), 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Alt+click toggles "keep" for this item on all characters.
  r:SetScript("OnMouseUp", function(self, button)
    if not self.data or button ~= "LeftButton" then return end
    if self.data.isHeader then
      local k = mode .. ":" .. self.data.key
      GuldbogDB.open[k] = not ns.IsOpen(self.data.key)
      ns.Refresh()
      return
    end
    if mode == "friends" then prepareMailTo(self.data); return end
    if mode ~= "stock" then return end
    if not IsAltKeyDown() then
      if self.data.kind == 3 and MerchantFrame and MerchantFrame:IsShown() then
        sellToVendor(self.data.id)
      elseif self.data.kind == 2 then
        sellOnAH(self.data.id)
      end
      return
    end
    if ns.TOOLS[self.data.id] then return end
    local id = self.data.id
    GuldbogDB.keep[id] = not GuldbogDB.keep[id] or nil
    ns.Refresh()
  end)

  uiRows[i] = r
  return r
end

local function signedMoney(v)
  if not v then return "–" end
  if v > 0 then return "|cff40ff40+|r" .. money(v) end
  return "|cffff6060-|r" .. money(-v)
end

local function age(t)
  if not t then return "|cffff6060" .. ns.T("AGE_NEVER") .. "|r" end
  local d = time() - t
  if d < 120 then return ns.T("AGE_NOW") end
  if d < 3600 then return ns.T("AGE_MIN", math.floor(d / 60)) end
  if d < 86400 then return ns.T("AGE_H", math.floor(d / 3600)) end
  return ns.T("AGE_D", math.floor(d / 86400))
end

-- e.g. "Bank: Name 2 t, Other aldrig   Post: ...   AH-priser: 3 t"
local function statusLine()
  local names = {}
  for key in activeChars() do names[#names + 1] = key end
  table.sort(names)
  local function part(label, what)
    local bits = {}
    for _, key in ipairs(names) do
      local seen = GuldbogDB.chars[key].seen
      bits[#bits + 1] = shortName(key) .. " " .. age(seen and seen[what])
    end
    return label .. ": " .. table.concat(bits, ", ")
  end
  local prices
  local source = ns.PriceSource()
  if source == "Auctionator" then
    local scan
    local st = Auctionator.SavedState
    if st then
      -- Replicate (full) scan, summary/browse scan, or legacy GetAll scan.
      scan = math.max(st.TimeOfLastReplicateScan or 0, st.TimeOfLastBrowseScan or 0,
                      st.TimeOfLastGetAllScan or 0)
      if scan == 0 then scan = nil end
    end
    prices = ns.T("STATUS_PRICES") .. " (Auctionator): " .. age(scan)
  elseif source == "TSM" then
    prices = ns.T("STATUS_PRICES") .. ": TSM"
  else
    prices = ns.T("STATUS_PRICES") .. ": |cffff6060" .. ns.T("STATUS_NO_SOURCE") .. "|r"
  end
  return part(ns.T("STATUS_BANK"), "bank") .. "    " .. part(ns.T("STATUS_MAIL"), "mail") .. "    " .. prices
end
ns.StatusLine = statusLine

-- Column sorting. Index matches the header; 7 (Forslag/Hvem) = default order.
local SORT_KEYS = {
  stock = {
    function(r) return r.sortName end, function(r) return r.count end,
    function(r) return r.here end, function(r) return r.ah or r.vendor end,
    function(r) return r.value end, function(r) return r.gain end,
  },
  craft = {
    function(r) return r.sortName end, function(r) return r.canMake end, nil,
    function(r) if not r.missing then return r.cost end end,
    function(r) return r.sale end, function(r) return r.gain end,
  },
  friends = {
    function(r) return r.sortName end, function(r) return r.count end,
    function(r) return r.here end, function(r) return r.ah or r.vendor end,
    function(r) return r.value end,
  },
}

local function applySort(rows)
  local st = GuldbogDB.sort[mode]
  local key = st.col and SORT_KEYS[mode][st.col]
  if not key then return end
  table.sort(rows, function(a, b)
    local x, y = key(a), key(b)
    if x == y or (x == nil and y == nil) then
      return tostring(a.sortName) < tostring(b.sortName)
    end
    if x == nil then return false end
    if y == nil then return true end
    if st.asc then return x < y end
    return x > y
  end)
end

ns.SortRows = applySort

local function onHeaderClick(i)
  local st = GuldbogDB.sort[mode]
  if not SORT_KEYS[mode][i] then
    st.col = nil
  elseif st.col == i then
    st.asc = not st.asc
  else
    st.col, st.asc = i, (i == 1) -- names A-Z, numbers highest first
  end
  ns.Refresh()
end

-- Collapsible groups ---------------------------------------------------------

-- Open by default: the groups you act on. Everything else starts folded.
local DEFAULT_OPEN = { ["stock:ah"] = true, ["stock:vendor"] = true }

function ns.IsOpen(key)
  local v = GuldbogDB.open[mode .. ":" .. key]
  if v ~= nil then return v end
  if mode == "craft" then return key == shortName(charKey()) end
  if mode == "friends" then return true end
  return DEFAULT_OPEN[mode .. ":" .. key] or false
end

-- Turns sorted rows into a list of group headers and (if open) their rows.
-- groups: ordered list of { key = ..., label = ... }; groupOf(row) returns a key.
local function groupEntries(rows, groups, groupOf)
  local byKey = {}
  for _, g in ipairs(groups) do byKey[g.key] = { info = g, rows = {}, sum = 0 } end
  for _, row in ipairs(rows) do
    local b = byKey[groupOf(row)]
    if b then
      b.rows[#b.rows + 1] = row
      b.sum = b.sum + (row.saleValue or 0)
    end
  end
  local out = {}
  for _, g in ipairs(groups) do
    local b = byKey[g.key]
    if #b.rows > 0 then
      local open = ns.IsOpen(g.key)
      local label = g.label or ""
      if not g.noCount then label = label .. " (" .. #b.rows .. ")" end
      if b.sum > 0 then label = label .. "  ·  " .. money(b.sum) end
      out[#out + 1] = { isHeader = true, key = g.key, label = label, open = open }
      if open then
        for _, row in ipairs(b.rows) do out[#out + 1] = row end
      end
    end
  end
  return out
end

local function showEntries(entries, fill)
  for i, data in ipairs(entries) do
    local r = getRow(i)
    r.data = data
    local cols = { r.name, r.count, r.here, r.price, r.value, r.gain, r.advice }
    if data.isHeader then
      r.icon:SetTexture(data.open and "Interface\\Buttons\\UI-MinusButton-Up"
                                    or "Interface\\Buttons\\UI-PlusButton-Up")
      for _, c in ipairs(cols) do c:SetText("") end
      r.header:SetText(data.label)
      r:SetAlpha(1)
    else
      r.header:SetText("")
      fill(r, data)
    end
    r:Show()
  end
  for i = #entries + 1, #uiRows do uiRows[i]:Hide() end
  content:SetHeight(math.max(1, #entries * ROW_H))
end

local STOCK_GROUPS = {
  { key = "use", label = "GRP_USE" }, { key = "ah", label = "GRP_AH" },
  { key = "vendor", label = "GRP_VENDOR" }, { key = "tool", label = "GRP_TOOL" },
  { key = "keep", label = "GRP_KEEP" }, { key = "onah", label = "GRP_ONAH" },
  { key = "none", label = "GRP_NONE" },
}

local function refreshCraft()
  local rows, profitable = ns.BuildCraftRows()
  applySort(rows)
  -- One group per character: the one you're playing first, then A-Z.
  local stats, names = {}, {}
  for _, row in ipairs(rows) do
    local st = stats[row.crafter]
    if not st then
      st = { n = 0, p = 0 }; stats[row.crafter] = st; names[#names + 1] = row.crafter
    end
    st.n = st.n + 1
    if row.gain and row.gain > 0 then st.p = st.p + 1 end
  end
  local me = shortName(charKey())
  table.sort(names, function(a, b)
    if (a == me) ~= (b == me) then return a == me end
    return a < b
  end)
  local groups = {}
  for _, n in ipairs(names) do
    groups[#groups + 1] = { key = n, noCount = true,
                            label = ns.T("GRP_CRAFTER", n, stats[n].n, stats[n].p) }
  end
  showEntries(groupEntries(rows, groups, function(row) return row.crafter end), function(r, data)
    r.icon:SetTexture(GetItemIcon(data.id))
    r.name:SetText(data.link)
    r.count:SetText(data.canMake > 0 and data.canMake or "–")
    r.here:SetText("")
    r.price:SetText(data.missing and ("|cffff6060" .. ns.T("MISSING") .. "|r") or money(data.cost))
    r.value:SetText(money(data.sale))
    r.gain:SetText(signedMoney(data.gain))
    local d = DIFF_TEXT[data.diff]
    r.advice:SetText(d and ("|cff" .. d[1] .. ns.T(d[2]) .. "|r") or data.diff)
    r:SetAlpha(1)
  end)
  if #rows == 0 then
    totalText:SetText(ns.T("FOOT_NO_RECIPES"))
  else
    totalText:SetText(ns.T("FOOT_PROFITABLE", profitable, #rows))
  end
end

local function refreshFriends()
  local rows, numFriends = ns.BuildFriendRows()
  applySort(rows)
  -- One group per friend: online first, then A-Z.
  local seen, friends = {}, {}
  for _, row in ipairs(rows) do
    if not seen[row.friend.name] then seen[row.friend.name] = true; friends[#friends + 1] = row.friend end
  end
  table.sort(friends, function(a, b)
    if (a.online and true or false) ~= (b.online and true or false) then return a.online and true or false end
    return a.name < b.name
  end)
  local groups = {}
  for _, f in ipairs(friends) do
    groups[#groups + 1] = { key = f.name, label = f.name .. " (" .. (f.class or "?") .. " " .. (f.level or "?") .. ")" ..
                            (f.online and "" or (" |cff808080" .. ns.T("OFFLINE") .. "|r")) }
  end
  showEntries(groupEntries(rows, groups, function(row) return row.friend.name end), function(r, data)
    r.icon:SetTexture(GetItemIcon(data.id))
    r.name:SetText(data.link)
    r.count:SetText(data.count)
    r.here:SetText(data.here > 0 and data.here or "–")
    r.price:SetText(money(data.ah or data.vendor))
    r.value:SetText(money(data.value))
    r.gain:SetText("")
    local f = data.friend
    r.advice:SetText(f.name .. " (" .. (f.class or "?") .. " " .. (f.level or "?") .. ")" ..
                     (f.online and "" or (" |cff808080" .. ns.T("OFFLINE") .. "|r")))
    r:SetAlpha(data.here > 0 and 1 or 0.45)
  end)
  if numFriends == 0 then
    totalText:SetText(ns.T("FOOT_NO_FRIENDS"))
  elseif #rows == 0 then
    totalText:SetText(ns.T("FOOT_NO_MATCH"))
  else
    totalText:SetText(ns.T("FOOT_FRIENDS_HINT"))
  end
end

local tabButtons = {}
local refreshButton, settingsButton, settingsPanel, scrollFrame
local headerButtons = {}
local previousMode = "stock"

-- Each setting: label, help text, values to cycle through, and how to show a value.
local SETTING_ROWS = {
  { key = "lang", label = "SET_LANGUAGE", values = { "en", "da" },
    show = function(v) return ns.T(v == "da" and "LANG_DA" or "LANG_EN") end,
    get = function() return GuldbogDB.lang end, set = function(v) GuldbogDB.lang = v end },
  { key = "minDeposit", label = "SET_MIN_DEPOSIT", help = "SET_MIN_DEPOSIT_HELP",
    values = { 0, 50, 100, 200, 500 }, show = function(v) return v == 0 and "0" or money(v) end },
  { key = "duration", label = "SET_DURATION", help = "SET_DURATION_HELP",
    values = { 1, 2, 3 }, show = function(v) return ns.T("DUR_" .. v) end },
  { key = "ahCut", label = "SET_AH_CUT", values = { 0.05, 0.15 },
    show = function(v) return ns.T(v > 0.1 and "CUT_NEUTRAL" or "CUT_FACTION") end },
  { key = "depositLost", label = "SET_DEPOSIT_LOST", help = "SET_DEPOSIT_LOST_HELP",
    values = { true, false }, show = function(v) return ns.T(v and "YES" or "NO") end },
  { key = "minimap", label = "SET_MINIMAP", values = { true, false },
    show = function(v) return ns.T(v and "YES" or "NO") end,
    get = function() return not GuldbogDB.minimap.hide end,
    set = function(v) GuldbogDB.minimap.hide = not v; if ns.ApplyMinimap then ns.ApplyMinimap() end end },
}

local function settingValue(row)
  if row.get then return row.get() end
  return setting(row.key)
end

local function cycleSetting(row)
  local cur, nextIndex = settingValue(row), 1
  for i, v in ipairs(row.values) do
    if v == cur then nextIndex = i % #row.values + 1 end
  end
  local v = row.values[nextIndex]
  if row.set then row.set(v) else GuldbogDB.settings[row.key] = v end
  ns.Refresh()
end

local function createSettingsPanel()
  settingsPanel = CreateFrame("Frame", nil, frame)
  settingsPanel:SetPoint("TOPLEFT", 24, -40)
  settingsPanel:SetPoint("BOTTOMRIGHT", -24, 60)
  settingsPanel.rows = {}
  for i, row in ipairs(SETTING_ROWS) do
    local y = -(i - 1) * 46
    local label = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y - 4)
    label:SetWidth(240)
    label:SetJustifyH("LEFT")
    local b = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    b:SetSize(200, 22)
    b:SetPoint("TOPLEFT", 250, y)
    b:SetScript("OnClick", function() cycleSetting(row) end)
    local help = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", 0, y - 24)
    help:SetWidth(460)
    help:SetJustifyH("LEFT")
    settingsPanel.rows[i] = { label = label, button = b, help = help }
  end

  -- Right column: show or hide each character. Rows are made on demand,
  -- because new characters can appear while the game is running.
  local head = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  head:SetPoint("TOPLEFT", 500, -4)
  head:SetWidth(260)
  head:SetJustifyH("LEFT")
  local help = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", 500, -24)
  help:SetWidth(260)
  help:SetJustifyH("LEFT")
  settingsPanel.charHead, settingsPanel.charHelp, settingsPanel.charRows = head, help, {}
  settingsPanel:Hide()
end

local function charRow(i)
  local rows = settingsPanel.charRows
  if rows[i] then return rows[i] end
  local y = -50 - (i - 1) * 28
  local label = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", 500, y - 4)
  label:SetWidth(130)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  local b = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
  b:SetSize(110, 22)
  b:SetPoint("TOPLEFT", 640, y)
  b:SetScript("OnClick", function(self)
    GuldbogDB.hidden[self.charKey] = not GuldbogDB.hidden[self.charKey] or nil
    ns.Refresh()
  end)
  rows[i] = { label = label, button = b }
  return rows[i]
end

local function refreshSettings()
  for i, row in ipairs(SETTING_ROWS) do
    local ui = settingsPanel.rows[i]
    ui.label:SetText(ns.T(row.label))
    ui.button:SetText(row.show(settingValue(row)))
    ui.help:SetText(row.help and ns.T(row.help) or "")
  end
  settingsPanel.charHead:SetText(ns.T("SET_CHARACTERS"))
  settingsPanel.charHelp:SetText(ns.T("SET_CHARACTERS_HELP"))
  local keys = {}
  for key in pairs(GuldbogDB.chars) do keys[#keys + 1] = key end
  table.sort(keys)
  for i, key in ipairs(keys) do
    local ui = charRow(i)
    local hidden = GuldbogDB.hidden[key]
    ui.label:SetText(shortName(key))
    ui.label:SetAlpha(hidden and 0.5 or 1)
    ui.button.charKey = key
    ui.button:SetText(ns.T(hidden and "CHAR_HIDDEN" or "CHAR_SHOWN"))
    ui.label:Show(); ui.button:Show()
  end
  for i = #keys + 1, #settingsPanel.charRows do
    settingsPanel.charRows[i].label:Hide(); settingsPanel.charRows[i].button:Hide()
  end
  totalText:SetText(ns.T("FOOT_SETTINGS"))
end

local function refresh()
  if not frame or not frame:IsShown() then return end
  for m, b in pairs(tabButtons) do
    b:SetText(ns.T(b.labelKey))
    if m == mode then b:Disable() else b:Enable() end
  end
  if refreshButton then refreshButton:SetText(ns.T("REFRESH")) end
  if settingsButton then settingsButton:SetText(ns.T(mode == "settings" and "BACK" or "SETTINGS")) end
  statusText:SetText(statusLine())
  local inSettings = mode == "settings"
  settingsPanel:SetShown(inSettings)
  scrollFrame:SetShown(not inSettings)
  for i, fs in ipairs(headerFS) do
    fs:SetShown(not inSettings)
    headerButtons[i]:SetShown(not inSettings)
  end
  if inSettings then refreshSettings(); return end
  local st = GuldbogDB.sort[mode]
  for i, fs in ipairs(headerFS) do
    local text = HEADERS[mode][i] ~= "" and ns.T(HEADERS[mode][i]) or ""
    if st.col == i and text ~= "" then
      text = "|cffffffff" .. text .. (st.asc and " ^" or " v") .. "|r"
    end
    fs:SetText(text)
  end
  if mode == "craft" then refreshCraft(); return end
  if mode == "friends" then refreshFriends(); return end
  local rows, sellTotal = ns.BuildRows()
  applySort(rows)
  local groups = {}
  for i, g in ipairs(STOCK_GROUPS) do groups[i] = { key = g.key, label = ns.T(g.label) } end
  showEntries(groupEntries(rows, groups, function(row) return row.group end), function(r, data)
    r.icon:SetTexture(GetItemIcon(data.id))
    r.name:SetText(data.link)
    r.count:SetText(data.count)
    r.here:SetText(data.here > 0 and data.here or "–")
    r.price:SetText(money(data.ah or data.vendor))
    r.value:SetText(money(data.value))
    if not data.gain then
      r.gain:SetText("–")
    elseif data.gain > 0 then
      r.gain:SetText("|cff40ff40+|r" .. money(data.gain))
    else
      r.gain:SetText("|cffff6060-|r" .. money(-data.gain))
    end
    r.advice:SetText(data.advice)
    -- Dim items this character doesn't have.
    r:SetAlpha(data.here > 0 and 1 or 0.45)
  end)

  local note = ""
  if not ns.PriceSource() then
    note = "  |cffff6060" .. ns.T("FOOT_NO_SOURCE") .. "|r"
  end
  totalText:SetText(ns.T("FOOT_SELLABLE", money(sellTotal)) .. note)
end

ns.Refresh = refresh

local function createFrame()
  frame = CreateFrame("Frame", "GuldbogFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(830, 480)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnShow", refresh)
  tinsert(UISpecialFrames, "GuldbogFrame")

  local title = frame.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if not frame.TitleText then title:SetPoint("TOP", 0, -5) end
  title:SetText("Guldbog")

  settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  settingsButton:SetSize(110, 18)
  settingsButton:SetPoint("TOPRIGHT", -28, -3)
  settingsButton:SetText(ns.T("SETTINGS"))
  settingsButton:SetScript("OnClick", function()
    if mode == "settings" then
      mode = previousMode
    else
      previousMode, mode = mode, "settings"
    end
    refresh()
  end)

  local headers = {
    { 34, 175, "LEFT" }, { 192, 60, "RIGHT" }, { 256, 35, "RIGHT" },
    { 295, 80, "RIGHT" }, { 379, 80, "RIGHT" }, { 463, 80, "RIGHT" },
    { 552, 245, "LEFT" },
  }
  for i, h in ipairs(headers) do
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", h[1], -34)
    fs:SetWidth(h[2])
    fs:SetJustifyH(h[3])
    fs:SetWordWrap(false)
    fs:SetText(ns.T(HEADERS.stock[i]))
    headerFS[i] = fs
    local hb = CreateFrame("Button", nil, frame)
    hb:SetPoint("TOPLEFT", h[1], -30)
    hb:SetSize(h[2], 18)
    hb:SetScript("OnClick", function() onHeaderClick(i) end)
    headerButtons[i] = hb
  end

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame = scroll
  scroll:SetPoint("TOPLEFT", 12, -52)
  scroll:SetPoint("BOTTOMRIGHT", -32, 60)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(790, 1)
  scroll:SetScrollChild(content)

  statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  statusText:SetPoint("BOTTOMLEFT", 16, 40)
  statusText:SetWidth(790)
  statusText:SetJustifyH("LEFT")
  statusText:SetWordWrap(false)

  totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  totalText:SetPoint("BOTTOMLEFT", 16, 16)
  -- Stop before the tab buttons; long text ends in "..." instead of running under them.
  totalText:SetWidth(470)
  totalText:SetJustifyH("LEFT")
  totalText:SetWordWrap(false)

  local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  btn:SetSize(100, 22)
  btn:SetPoint("BOTTOMRIGHT", -14, 12)
  btn:SetText(ns.T("REFRESH"))
  refreshButton = btn
  btn:SetScript("OnClick", function()
    scanBags(); scanBank(); scanProfessions(); refresh()
  end)

  -- View tabs, right to left before "Opdatér". The active one is greyed out.
  local anchor = btn
  for _, t in ipairs({ { "friends", "TAB_FRIENDS" }, { "craft", "TAB_CRAFT" }, { "stock", "TAB_STOCK" } }) do
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(84, 22)
    b:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
    b:SetText(ns.T(t[2]))
    b.labelKey = t[2]
    b:SetScript("OnClick", function()
      mode = t[1]
      if mode == "friends" and C_FriendList and C_FriendList.ShowFriends then
        pcall(C_FriendList.ShowFriends)
      end
      refresh()
    end)
    tabButtons[t[1]] = b
    anchor = b
  end

  createSettingsPanel()

  -- New frames start shown; hide so the slash command's toggle opens it.
  frame:Hide()
end

-- Events ---------------------------------------------------------------------

local events = CreateFrame("Frame")
local function safeRegister(ev) pcall(events.RegisterEvent, events, ev) end
for _, ev in ipairs({
  "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED",
  "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
  "SKILL_LINES_CHANGED", "GET_ITEM_INFO_RECEIVED",
  "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "AUCTION_HOUSE_SHOW",
  "MAIL_SHOW", "MAIL_INBOX_UPDATE", "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_AUCTION_CREATED",
  "MAIL_SEND_SUCCESS", "MAIL_FAILED", "FRIENDLIST_UPDATE",
  "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
  "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED",
}) do safeRegister(ev) end

-- Item data arrives one item at a time; redraw once after a short pause.
local redrawPending = false
local function scheduleRedraw()
  if redrawPending then return end
  if not (C_Timer and C_Timer.After) then refresh(); return end
  redrawPending = true
  C_Timer.After(0.3, function() redrawPending = false; refresh() end)
end

events:SetScript("OnEvent", function(_, event, arg1, arg2)
  -- Diagnostics: remember which protected function the game stopped us from calling.
  if event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
    if arg1 == ADDON and GuldbogDB then
      GuldbogDB.blocked = GuldbogDB.blocked or {}
      table.insert(GuldbogDB.blocked, 1, { fn = tostring(arg2), event = event, at = time(),
        mode = mode, merchant = MerchantFrame and MerchantFrame:IsShown() or false,
        ah = AuctionHouseFrame and AuctionHouseFrame:IsShown() or false,
        mail = MailFrame and MailFrame:IsShown() or false,
        trace = debugstack and debugstack(2, 12, 0) or nil })
      while #GuldbogDB.blocked > 10 do table.remove(GuldbogDB.blocked) end
      print("|cffffd700Guldbog:|r blocked: " .. tostring(arg2))
    end
    return
  end
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then
      local existing = GuldbogDB ~= nil and GuldbogDB.chars ~= nil and next(GuldbogDB.chars) ~= nil
      GuldbogDB = GuldbogDB or {}
      if not GuldbogDB.lang then GuldbogDB.lang = existing and "da" or "en" end
      GuldbogDB.chars = GuldbogDB.chars or {}
      GuldbogDB.keep = GuldbogDB.keep or {}
      GuldbogDB.deposit = GuldbogDB.deposit or {}
      GuldbogDB.links = GuldbogDB.links or {}
      GuldbogDB.settings = GuldbogDB.settings or {}
      GuldbogDB.open = GuldbogDB.open or {}
      GuldbogDB.hidden = GuldbogDB.hidden or {}
      GuldbogDB.sort = GuldbogDB.sort or {}
      GuldbogDB.sort.stock = GuldbogDB.sort.stock or {}
      GuldbogDB.sort.craft = GuldbogDB.sort.craft or {}
      GuldbogDB.sort.friends = GuldbogDB.sort.friends or {}
      GuldbogDB.minimap = GuldbogDB.minimap or { angle = 225 }
      ns.CreateMinimapButton()
    end
    return
  end
  if not GuldbogDB then return end
  if event == "GET_ITEM_INFO_RECEIVED" or event == "FRIENDLIST_UPDATE"
     or event:match("^BN_FRIEND") then
    scheduleRedraw(); return
  end
  if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
    pcall(scanTradeSkill); scheduleRedraw(); return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    scanBags(); scanProfessions()
  elseif event == "BAG_UPDATE_DELAYED" then
    scanBags(); scanBank(); pcall(updateDeposits)
  elseif event == "AUCTION_HOUSE_SHOW" then
    pcall(updateDeposits); queryOwnedAuctions()
  elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
    queryOwnedAuctions()
  elseif event == "OWNED_AUCTIONS_UPDATED" then
    pcall(scanOwnedAuctions)
  elseif event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then
    hookSendButton(); pcall(scanMail)
  elseif event == "MAIL_SEND_SUCCESS" then
    creditPendingMail()
  elseif event == "MAIL_FAILED" then
    pendingMail = nil
  elseif event == "BANKFRAME_OPENED" then
    bankOpen = true; scanBank()
  elseif event == "BANKFRAME_CLOSED" then
    bankOpen = false
  elseif event == "PLAYERBANKSLOTS_CHANGED" then
    scanBank()
  elseif event == "SKILL_LINES_CHANGED" then
    scanProfessions()
  end
  refresh()
end)

local function toggleFrame()
  if not frame then createFrame() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Minimap button ---------------------------------------------------------------

local minimapButton

local function placeMinimapButton()
  local a = math.rad(GuldbogDB.minimap.angle)
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end

function ns.CreateMinimapButton()
  if minimapButton or not Minimap then return end
  local b = CreateFrame("Button", "GuldbogMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetTexture("Interface\\AddOns\\Guldbog\\Media\\Guldbog")
  icon:SetPoint("TOPLEFT", 7, -5)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  b:SetScript("OnClick", toggleFrame)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Guldbog")
    GameTooltip:AddLine(ns.T("MM_CLICK"), 1, 1, 1)
    GameTooltip:AddLine(ns.T("MM_DRAG"), 1, 1, 1)
    GameTooltip:AddLine(ns.T("MM_ICON"), 0.6, 0.6, 0.6)
    GameTooltip:AddLine(ns.T("MM_LANGUAGE"), 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Drag around the minimap edge; the angle is saved.
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      GuldbogDB.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
      placeMinimapButton()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

  minimapButton = b
  placeMinimapButton()
  if GuldbogDB.minimap.hide then b:Hide() end
end

function ns.ApplyMinimap()
  if minimapButton then
    if GuldbogDB.minimap.hide then minimapButton:Hide() else minimapButton:Show() end
  end
end

SLASH_GULDBOG1 = "/guldbog"
SlashCmdList.GULDBOG = function(msg)
  msg = (msg or ""):lower()
  local cmd, arg = msg:match("^%s*(%S+)%s*(%S*)")
  if cmd == "sprog" or cmd == "language" or cmd == "lang" then
    if arg == "da" or arg == "en" then
      GuldbogDB.lang = arg
      ns.Say("MSG_LANGUAGE")
      ns.Refresh()
    else
      ns.Say("MSG_LANGUAGE_USAGE")
    end
    return
  end
  if cmd == "ikon" or cmd == "icon" then
    GuldbogDB.minimap.hide = not GuldbogDB.minimap.hide
    if minimapButton then
      if GuldbogDB.minimap.hide then minimapButton:Hide() else minimapButton:Show() end
    end
    return
  end
  toggleFrame()
end
