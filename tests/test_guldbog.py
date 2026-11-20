import sys
from lupa import lua51

ADDON_DIR = sys.argv[1]
L = lua51.LuaRuntime(unpack_returned_tuples=True)

STUB = r'''
-- Generic object: any method call returns another object, never fails.
local function obj()
  local o = {}
  setmetatable(o, { __index = function(t, k)
    if k == "TitleText" then return nil end
    if k == "IsShown" then return function(self) return self._shown end end
    if k == "Show" then return function(self) self._shown = true; if self._onshow then self._onshow(self) end end end
    if k == "Hide" then return function(self) self._shown = false end end
    if k == "SetScript" then return function(self, name, fn)
      if name == "OnEvent" then self._onevent = fn end
      if name == "OnShow" then self._onshow = fn end
      rawset(self, "_" .. name, fn)
    end end
    if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
    if k == "RegisterEvent" then return function(self, ev)
      if ev == "SKILL_LINES_CHANGED_BOGUS" then error("unknown event") end
    end end
    return function() return obj() end
  end })
  return o
end
FRAMES = {}
function CreateFrame(...) local f = obj(); FRAMES[#FRAMES+1] = f; return f end
UIParent = obj(); GameTooltip = obj(); UISpecialFrames = {}
Minimap = obj()
time = os.time
HOOKS = {}
function hooksecurefunc(name, fn) HOOKS[name] = fn end
function SendMail() end
function tinsert(t, v) table.insert(t, v) end

SlashCmdList = {}
-- Forever has no GetCoinTextureString, so the stub doesn't define it.

CURRENT = "Warrior"
function UnitName() return CURRENT end
function GetRealmName() return "Realm" end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
Enum = { BagIndex = { Backpack = 0, Bank = -1, BankBag_1 = 6, CharacterBankTab_1 = 12, AccountBankTab_1 = 13, Reagentbank = -3 } }

BAGS = {}
C_Container = {
  GetContainerNumSlots = function(bag) return BAGS[bag] and #BAGS[bag] or 0 end,
  GetContainerItemInfo = function(bag, slot)
    local s = BAGS[bag] and BAGS[bag][slot]
    if not s then return nil end
    return { itemID = s[1], stackCount = s[2], isBound = s[3] }
  end,
}
PROFS = {}
function GetProfessions() return PROFS[1], PROFS[2] end
function GetProfessionInfo(i) local p = PROFS_INFO[i]; return p.name, nil, p.rank, nil, nil, nil, p.line end

ITEMS = {
  [2770] = { "Copper Ore", 5 },  [2589] = { "Linen Cloth", 3 },
  [818]  = { "Tigerseye", 100 }, [2934] = { "Ruined Leather Scraps", 1 },
  [9999] = { "Junk", 7 }, [2771] = { "Tin Ore", 10 },
  [4000] = { "Pattern: Linen Bag", 50, 9, 2 },        [2901] = { "Mining Pick", 20 },        [5555] = { "Unknown", 0 },
}
C_Item = {
  GetItemInfo = function(id)
    if type(id) == "string" then id = tonumber(id:match("item:(%d+)")) end
    local it = ITEMS[id]; if not it then return nil end
    return it[1], "[" .. it[1] .. "]", nil, nil, it[5], nil, nil, nil, it[6], nil, it[2], it[3], it[4]
  end,
  GetItemIconByID = function() return 1 end,
  GetItemInfoInstant = function(id) if id == 7348 then return id, nil, nil, nil, nil, 4, 1 end return id, nil, nil, nil, nil, 7, 0 end,
}
AH = { [2901] = 100, [2770] = 20, [2589] = 10, [818] = 400, [9999] = 5 }
Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(caller, id) return AH[id] end } } }
'''
L.execute(STUB)

ns = L.table()
for f in ["Locale.lua", "Data.lua", "Guldbog.lua"]:
    src = open(f"{ADDON_DIR}/{f}", encoding="utf-8").read()
    chunk = L.execute("return function(src, name) return assert(loadstring(src, name)) end")(src, "@" + f)
    chunk("Guldbog", ns)

fire = L.eval('''function(ev, a) for _, f in ipairs(FRAMES) do if f._onevent then f._onevent(f, ev, a) end end end''')

fire("ADDON_LOADED", "Guldbog")

# Warrior: mining + blacksmithing
L.execute('''
CURRENT = "Warrior"; PROFS = {1, 2}
PROFS_INFO = { {name="Mining", rank=75, line=186}, {name="Blacksmithing", rank=26, line=164} }
BAGS = { [0] = { {2770, 20}, {818, 2}, {6948, 1, true}, {2901, 1} } }
''')
fire("PLAYER_ENTERING_WORLD")
L.execute('BAGS = { [-1] = { {2589, 10} }, [6] = { {9999, 3} }, [12] = { {818, 1} }, [13] = { {5555, 99} }, [0] = { {2770, 20}, {818, 2} } }')
fire("BANKFRAME_OPENED")
fire("BANKFRAME_CLOSED")

# Mage: tailoring, has no enchanting yet
L.execute('''
CURRENT = "Mage"; PROFS = {nil, 1}
PROFS_INFO = { {name="Tailoring", rank=1, line=197} }
BAGS = { [0] = { {2589, 5}, {2934, 4}, {5555, 1} } }
''')
fire("PLAYER_ENTERING_WORLD")

# Open window via slash command and test rows
L.eval('SlashCmdList.GULDBOG')()
rows, total = ns.BuildRows()
out = []
for i in range(1, len(rows) + 1):
    r = rows[i]
    holders = {k: v for k, v in r.holders.items()}
    out.append((r.id, r.count, r.advice, r.value, holders))
for o in out:
    print(o)
print("sellTotal", total)

db = L.globals().GuldbogDB
w = db.chars["Warrior-Realm"]
print("warrior bank keys", sorted(w.bank.keys()))
print("account bank excluded:", 5555 not in list(w.bank.keys()))
print("bound excluded:", 6948 not in list(w.bags.keys()))

# Keep toggle: mark Tigerseye as keep and rebuild.
db.keep[818] = True
rows, total = ns.BuildRows()
for i in range(1, len(rows) + 1):
    r = rows[i]
    if r.id in (818, 2901):
        print("keep-check", r.id, r.advice, r.kind)
print("sellTotal after keep", total)

# --- Profession window scan (Mainline API) and recipes ---
L.execute("""
CURRENT = "Warrior"; PROFS = {1, 2}
PROFS_INFO = { {name="Mining", rank=75, line=186}, {name="Blacksmithing", rank=26, line=164} }
BAGS = { [0] = { {2770, 20}, {2771, 5} } }
RECIPES = {
  [1] = { name = "Smelt Copper", learned = true, relativeDifficulty = 3, mats = {2770} },
  [2] = { name = "Smelt Tin", learned = true, relativeDifficulty = 0, mats = {2771} },
}
TRADE_PROF = { professionID = 186, professionName = "Mining" }
C_TradeSkillUI = {
  GetBaseProfessionInfo = function() return TRADE_PROF end,
  GetAllRecipeIDs = function() local t = {} for id in pairs(RECIPES) do t[#t+1] = id end return t end,
  GetRecipeInfo = function(id) return RECIPES[id] end,
  GetRecipeSchematic = function(id)
    local r = {} for _, m in ipairs(RECIPES[id].mats) do r[#r+1] = { itemID = m } end
    return { reagentSlotSchematics = { { reagents = r } } }
  end,
}
""")
fire("PLAYER_ENTERING_WORLD")
fire("TRADE_SKILL_SHOW")

L.execute("""
CURRENT = "Mage"; PROFS = {nil, 1}
PROFS_INFO = { {name="Tailoring", rank=1, line=197} }
BAGS = { [0] = { {4000, 1} } }
""")
fire("PLAYER_ENTERING_WORLD")

def advice(ids):
    rows, _ = ns.BuildRows()
    res = {}
    for i in range(1, len(rows) + 1):
        if rows[i].id in ids: res[rows[i].id] = rows[i].advice
    return res

print("trade", advice({2770, 2771, 4000}))

# Mage opens tailoring and already knows Linen Bag.
L.execute("""
RECIPES = { [10] = { name = "Linen Bag", learned = true, relativeDifficulty = 1, mats = {2589} } }
TRADE_PROF = { professionID = 197, professionName = "Tailoring" }
""")
fire("TRADE_SKILL_SHOW")
print("after known", advice({4000, 2589}))

# --- Click to sell via Auctionator (stubbed internals) ---
L.execute("""
CURRENT = "Warrior"
BAGS = { [0] = { {818, 2} } }
PRINTS = {}
print = function(m) PRINTS[#PRINTS+1] = m end
FIRED = nil
ItemLocation = { CreateFromBagAndSlot = function(_, b, s) return { bag = b, slot = s } end }
C_AuctionHouse = { IsSellItemValid = function() return true end, GetAvailablePostCount = function() return 2 end }
C_Item.GetItemLink = function(loc) return "link818" end
local sellFrame = { SetItem = function() end }
AuctionHouseFrame = { IsShown = function() return false end, ItemSellFrame = sellFrame, CommoditiesSellFrame = sellFrame }
AuctionatorTabs_Selling = { Click = function() end }
AuctionatorBagCacheFrame = { CacheLinkInfo = function(_, l, cb) cb() end, GetByLinkInstant = function() return {} end }
Auctionator.Groups = { Utilities = { ToPostingItem = function(i) return i end } }
Auctionator.Selling = { Events = { BagItemClicked = "BagItemClicked" } }
Auctionator.EventBus = { RegisterSource = function() end, Fire = function(_, src, ev, info) FIRED = { ev = ev, info = info } end }
""")
sell = ns.SellInAuctionator
sell(818)
print("AH closed ->", L.eval("PRINTS[1]"))
L.execute("AuctionHouseFrame.IsShown = function() return true end")
sell(818)
print("fired:", L.eval("FIRED and FIRED.ev"), "bag/slot:", L.eval("FIRED and FIRED.info.location.bag"), L.eval("FIRED and FIRED.info.location.slot"), "count:", L.eval("FIRED and FIRED.info.count"))
sell(2770)
print("not in bags ->", L.eval("PRINTS[#PRINTS]"))

# --- Gain and deposits ---
L.execute("""
CURRENT = "Warrior"
ITEMS[7000] = { "Cheap Thing", 0 }      -- no vendor price
ITEMS[7001] = { "Good Thing", 10 }
AH[7000] = 55
AH[7001] = 500
BAGS = { [0] = { {7000, 1}, {7001, 4} } }
""")
fire("BAG_UPDATE_DELAYED")
def rowinfo(ids):
    rows, _ = ns.BuildRows()
    out = {}
    for i in range(1, len(rows) + 1):
        r = rows[i]
        if r.id in ids: out[r.id] = (r.advice, r.gain, r.deposit, r.depositKnown, r.here)
    return out
print("estimated", rowinfo({7000, 7001}))

# AH opens: game reports real deposits (commodity, 4 units cost 40c in total).
L.execute("""
Enum.ItemCommodityStatus = { Unknown = 0, Item = 1, Commodity = 2 }
C_AuctionHouse.GetItemCommodityStatus = function() return 2 end
C_AuctionHouse.CalculateCommodityDeposit = function(id, dur, qty) return 10 * qty end
C_AuctionHouse.CalculateItemDeposit = function() return 0 end
""")
fire("AUCTION_HOUSE_SHOW")
print("from game", rowinfo({7000, 7001}))
print("deposit db", {k: dict(v) for k, v in L.globals().GuldbogDB.deposit.items()})

# --- Crafting profit list ---
L.execute("""
CURRENT = "Warrior"; PROFS = {1, 2}
PROFS_INFO = { {name="Mining", rank=81, line=186}, {name="Blacksmithing", rank=66, line=164} }
ITEMS[3576] = { "Tin Bar", 25 }
ITEMS[9100] = { "Camp Thing", 0 }
ITEMS[2880] = { "Weak Flux", 10 }
ITEMS[2851] = { "Copper Chain Belt", 60 }
AH[2771] = 20; AH[3576] = 80; AH[2840] = 30; AH[2851] = 500
VENDOR_BUY = { [2880] = 40 }
Auctionator.API.v1.GetVendorPriceByItemID = function(_, id) return VENDOR_BUY[id] end
BAGS = { [0] = { {2771, 7}, {2840, 9} } }
RECIPES = {
  [1] = { name = "Smelt Tin", learned = true, relativeDifficulty = 1, out = 3576, qty = 1, mats = { {2771, 1} } },
  [2] = { name = "Copper Chain Belt", learned = true, relativeDifficulty = 0, out = 2851, qty = 1, mats = { {2840, 3}, {2880, 1} } },
  [3] = { name = "Mystery", learned = true, relativeDifficulty = 2, out = 2851, qty = 1, mats = { {123456, 1} } },
  [4] = { name = "Camp Thing", learned = true, relativeDifficulty = 0, out = 9100, qty = 1, mats = { {2840, 1} } },
}
TRADE_PROF = { professionID = 164, professionName = "Blacksmithing" }
C_TradeSkillUI.GetRecipeSchematic = function(id)
  local r = RECIPES[id]
  local slots = {}
  for _, m in ipairs(r.mats) do slots[#slots+1] = { reagents = { { itemID = m[1] } }, quantityRequired = m[2] } end
  return { outputItemID = r.out, quantityMin = r.qty, reagentSlotSchematics = slots }
end
""")
fire("PLAYER_ENTERING_WORLD")
fire("TRADE_SKILL_SHOW")
rows, profitable = ns.BuildCraftRows()
for i in range(1, len(rows) + 1):
    r = rows[i]
    if r.crafter == "Warrior" and r.skill == 164:
        print("craft", r.id, r.diff, "cost", r.cost, "missing", r.missing, "sale", r.sale, r.via, "gain", r.gain, "canMake", r.canMake)
print("profitable", profitable)
print("unsellable hidden:", all(rows[i].id != 9100 for i in range(1, len(rows) + 1)))

# Toggle to the Crafting view and back (exercises the UI code).
tabs = {f._text: f for f in L.eval("FRAMES").values() if f._text in ("Inventory", "Crafting", "Friends")}
tabs["Crafting"]._OnClick(tabs["Crafting"])
tabs["Inventory"]._OnClick(tabs["Inventory"])
print("tabs:", sorted(tabs.keys()))

# --- Minimap button ---
isMM = L.eval("function(f) return rawget(f, '_OnDragStart') ~= nil and rawget(f, '_OnClick') ~= nil end")
mm = [f for f in L.eval("FRAMES").values() if isMM(f)]
print("minimap button created:", len(mm) == 1, "angle", L.globals().GuldbogDB.minimap.angle)
L.eval('SlashCmdList.GULDBOG')("ikon")
print("hidden after /guldbog ikon:", L.globals().GuldbogDB.minimap.hide)
L.eval('SlashCmdList.GULDBOG')(" IKON ")
print("shown again:", L.globals().GuldbogDB.minimap.hide)

# --- Mail and own auctions ---
L.execute("""
CURRENT = "Warrior"
BAGS = { [0] = { {2770, 5}, {818, 1} } }
SEND = { [1] = {2770, 5} }
function GetSendMailItem(i) local m = SEND[i]; if m then return "x", m[1], nil, m[2] end end
INBOX = { { {2589, 20} } }
function GetInboxNumItems() return #INBOX end
function GetInboxItem(i, a) local m = INBOX[i] and INBOX[i][a]; if m then return "x", m[1], nil, m[2] end end
OWNED = { { itemKey = { itemID = 818 }, quantity = 2, status = 0 }, { itemKey = { itemID = 2589 }, quantity = 5, status = 1 } }
C_AuctionHouse.GetNumOwnedAuctions = function() return #OWNED end
C_AuctionHouse.GetOwnedAuctionInfo = function(i) return OWNED[i] end
""")
fire("BAG_UPDATE_DELAYED")
L.execute("""
SendMailNameEditBox = { GetText = function() return RECIPIENT end }
SendMailMailButton = { HookScript = function(self, ev, fn) self.onClick = fn end }
""")
fire("MAIL_SHOW")                           # Warrior's own inbox: 20 linen; hooks Send
L.execute("RECIPIENT = 'Mage'")
L.eval("SendMailMailButton.onClick")()      # click Send: 5 copper ore to Mage
fire("MAIL_FAILED")                         # first attempt fails -> nothing credited
print("after failed send", L.globals().GuldbogDB.chars["Mage-Realm"].mail)
L.eval("SendMailMailButton.onClick")()
fire("MAIL_SEND_SUCCESS")
fire("OWNED_AUCTIONS_UPDATED")              # 2 Tigerseye on AH (sold one ignored)
db = L.globals().GuldbogDB
print("mage mail", dict(db.chars["Mage-Realm"].mail))
print("warrior mail", dict(db.chars["Warrior-Realm"].mail), "auctions", dict(db.chars["Warrior-Realm"].auctions))
L.execute("BAGS = { [0] = { {2770, 5} } }")  # Tigerseye now only on AH
fire("BAG_UPDATE_DELAYED")
rows, _ = ns.BuildRows()
for i in range(1, len(rows) + 1):
    r = rows[i]
    if r.id in (818, 2770):
        print("row", r.id, r.count, r.onAH, r.advice, dict(r.holders))

# --- Gear with random suffix: full link and price by link ---
L.execute("""
ITEMS[7348] = { "Disciple's Pants", 149 }
Auctionator.API.v1.GetAuctionPriceByItemLink = function(_, link) if link:find("Arcane") then return 2000 end end
C_Container.GetContainerItemInfo = function(bag, slot)
  local s = BAGS[bag] and BAGS[bag][slot]
  if not s then return nil end
  return { itemID = s[1], stackCount = s[2], isBound = s[3], hyperlink = s[4] }
end
BAGS = { [0] = { {7348, 1, false, "|Hitem:7348::::::77|h[Disciple's Pants of Arcane Protection]|h"} } }
""")
fire("BAG_UPDATE_DELAYED")
rows, _ = ns.BuildRows()
for i in range(1, len(rows) + 1):
    if rows[i].id == 7348: print("gear", rows[i].link, rows[i].ah, rows[i].advice)

# --- Sorting ---
db = L.globals().GuldbogDB
db.sort.stock.col = 6; db.sort.stock.asc = False
rows, _ = ns.BuildRows(); ns.SortRows(rows)
gains = [rows[i].gain for i in range(1, len(rows) + 1)]
known = [g for g in gains if g is not None]
print("gain desc:", known == sorted(known, reverse=True), "nils last:", all(g is None for g in gains[len(known):]))
db.sort.stock.asc = True
rows, _ = ns.BuildRows(); ns.SortRows(rows)
known = [rows[i].gain for i in range(1, len(rows) + 1) if rows[i].gain is not None]
print("gain asc:", known == sorted(known))
db.sort.stock.col = 1; db.sort.stock.asc = True
rows, _ = ns.BuildRows(); ns.SortRows(rows)
names = [rows[i].sortName for i in range(1, len(rows) + 1)]
print("name asc:", names == sorted(names))
# header click through the UI: click header 6 twice, then Forslag
hdr = [f for f in L.eval("FRAMES").values() if L.eval("function(f) return rawget(f, '_OnClick') ~= nil and rawget(f, '_OnDragStart') == nil end")(f)]
print("clickable buttons:", len(hdr))
db.sort.stock.col = None
for f in hdr:
    f._OnClick(f); f._OnClick(f)   # every header/button twice, in both views: must not error
print("header clicks ok, sort state:", dict(db.sort.stock), dict(db.sort.craft))
db.sort.stock.col = None; db.sort.craft.col = None

# --- Sell to vendor ---
L.execute("""
CURRENT = "Warrior"
BAGS = { [0] = { {9999, 2}, {2770, 5}, {9999, 1} } }
USED = {}
C_Container.UseContainerItem = function(b, s) USED[#USED+1] = b .. ":" .. s end
PRINTS = {}
MerchantFrame = { IsShown = function() return false end }
""")
ns.SellToVendor(9999)
print("no merchant ->", L.eval("PRINTS[#PRINTS]"))
L.execute("MerchantFrame.IsShown = function() return true end")
ns.SellToVendor(9999)
print("sold slots:", list(L.eval("USED").values()), "->", L.eval("PRINTS[#PRINTS]"))

# --- Status line ---
L.execute("Auctionator.SavedState = { TimeOfLastReplicateScan = os.time() - 3 * 3600 }")
print("status:", ns.StatusLine())

# --- TSM as fallback price source ---
L.execute("""
SAVED_AUCTIONATOR = Auctionator
Auctionator = nil
TSM_API = {
  GetCustomPriceValue = function(source, itemString)
    if source == TSM_API then error("colon") end
    local id = tonumber(itemString:match("^i:(%d+)"))
    if source == "DBMinBuyout" and id == 7001 then return 450 end
    if source == "DBMarket" and id == 2770 then return 18 end
    if source == "VendorBuy" and id == 2880 then return 50 end
  end,
  ToItemString = function(link) return "i:7348::77" end,
}
""")
print("source:", ns.PriceSource())
print("tsm DBMinBuyout for 7001:", ns.MaterialCost(7001))
rows, _ = ns.BuildRows()
got = {rows[i].id: rows[i].ah for i in range(1, len(rows) + 1) if rows[i].id in (7001, 2770)}
print("prices via TSM:", got)
print("vendor buy via TSM:", ns.MaterialCost(2880))
print("status:", ns.StatusLine().split("    ")[-1])
L.execute("TSM_API = nil")
print("no source:", ns.PriceSource(), "|", ns.StatusLine().split("    ")[-1])
L.execute("Auctionator = SAVED_AUCTIONATOR; TSM_API = nil")

# --- Secondary professions ---
L.execute("""
CURRENT = "Warrior"; PROFS = {1, 2, nil, nil, 3}
PROFS_INFO = { {name="Mining", rank=81, line=186}, {name="Blacksmithing", rank=66, line=164}, {name="Cooking", rank=40, line=185} }
ITEMS[5400] = { "Recipe: Pincer Bites", 10, 9, 5 }
ITEMS[2672] = { "Stringy Wolf Meat", 3 }
ITEMS[2681] = { "Roasted Wolf Meat", 6 }
ITEMS[1251] = { "Linen Bandage", 5 }
BAGS = { [0] = { {5400, 1}, {2672, 4}, {2589, 6} } }
""")
fire("PLAYER_ENTERING_WORLD")
# First Aid only becomes known by opening its window.
L.execute("""
RECIPES = { [20] = { name = "Linen Bandage", learned = true, relativeDifficulty = 0, out = 1251, qty = 1, mats = { {2589, 1} } } }
TRADE_PROF = { professionID = 129, professionName = "First Aid" }
""")
fire("TRADE_SKILL_SHOW")
L.execute("""
RECIPES = { [21] = { name = "Roasted Wolf Meat", learned = true, relativeDifficulty = 1, out = 2681, qty = 1, mats = { {2672, 1} } } }
TRADE_PROF = { professionID = 185, professionName = "Cooking" }
""")
fire("TRADE_SKILL_SHOW")
fire("SKILL_LINES_CHANGED")   # re-scan professions must keep First Aid
profs = dict(L.globals().GuldbogDB.chars["Warrior-Realm"].profs)
print("warrior profs:", sorted(profs.keys()))
rows, _ = ns.BuildRows()
for i in range(1, len(rows) + 1):
    r = rows[i]
    if r.id in (5400, 2672, 2589): print("secondary", r.id, r.advice)

# --- Friends tab ---
L.execute("""
CURRENT = "Warrior"
ITEMS[7348] = { "Disciple's Pants", 149, 4, 1, 7, "INVTYPE_LEGS" }          -- cloth, level 7
ITEMS[8000] = { "Chain Hauberk", 300, 4, 3, 20, "INVTYPE_CHEST" }          -- mail, level 20
ITEMS[8001] = { "Gnarled Staff", 200, 2, 10, 5, "INVTYPE_2HWEAPON" }        -- staff
ITEMS[5956] = { "Blacksmith Hammer", 10, 2, 4, 1, "INVTYPE_WEAPON" }  -- a tool, must not be offered
BAGS = { [0] = { {7348, 1, false, "|Hitem:7348::::::77|h[Disciple's Pants of Arcane Protection]|h"}, {8000, 1}, {8001, 1}, {5956, 1} } }
LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", HUNTER = "Hunter", WARRIOR = "Warrior" }
FRIENDS = {
  { name = "Ven", className = "Mage", level = 10, connected = true },
  { name = "Bue", className = "Hunter", level = 25, connected = false },
  { name = "Bjørn", className = "Warrior", level = 22, connected = true },
}
C_FriendList = { GetNumFriends = function() return #FRIENDS end,
                 GetFriendInfoByIndex = function(i) return FRIENDS[i] end, ShowFriends = function() end }
""")

fire("BAG_UPDATE_DELAYED")
rows, n = ns.BuildFriendRows()
print("friends:", n)
for i in range(1, len(rows) + 1):
    r = rows[i]
    print("friend row", r.friend.name, r.friend.online, r.sortName)
# Hunter 25 can't wear mail yet (mail at 40), warrior can; mage takes cloth + staff.
print("mage gets staff+pants:", sorted(rows[i].sortName for i in range(1, len(rows)+1) if rows[i].friend.name == "Ven"))
print("hunter gets mail:", any(rows[i].sortName == "Chain Hauberk" and rows[i].friend.name == "Bue" for i in range(1, len(rows)+1)))
print("warrior gets mail:", any(rows[i].sortName == "Chain Hauberk" and rows[i].friend.name == "Bjørn" for i in range(1, len(rows)+1)))

# Prepare mail at mailbox
L.execute("""
PRINTS = {}
MailFrame = { IsShown = function() return false end }
""")
first = [rows[i] for i in range(1, len(rows)+1) if rows[i].friend.name == "Ven" and rows[i].sortName == "Disciple's Pants"][0]
ns.PrepareMailTo(first)
print("no mailbox ->", L.eval("PRINTS[#PRINTS]"))
L.execute("""
MailFrame.IsShown = function() return true end
MailFrameTab2 = { Click = function() TAB = 2 end }
SendMailNameEditBox.SetText = function(_, t) MAILTO = t end
ClearCursor = function() end
C_Container.PickupContainerItem = function(b, s) CURSOR = b .. ":" .. s end
ClickSendMailItemButton = function() ATTACHED = CURSOR end
""")
ns.PrepareMailTo(first)
print("prepared:", L.eval("TAB"), L.eval("MAILTO"), L.eval("ATTACHED"), "->", L.eval("PRINTS[#PRINTS]"))
tabs["Friends"]._OnClick(tabs["Friends"])
print("friends view rendered ok")
tabs["Inventory"]._OnClick(tabs["Inventory"])

# --- Battle.net friends ---
L.execute("""
FRIENDS = {}
UnitFactionGroup = function() return "Alliance" end
WOW_PROJECT_ID = 99; BNET_CLIENT_WOW = "WoW"
BNET = {
  { gameAccountInfo = { isOnline = true, characterName = "Kammerat", className = "Mage", characterLevel = 12, realmName = "Realm", clientProgram = "WoW", wowProjectID = 99, factionName = "Alliance" } },
  { gameAccountInfo = { isOnline = true, characterName = "Horde", className = "Mage", characterLevel = 12, realmName = "Realm", clientProgram = "WoW", wowProjectID = 99, factionName = "Horde" } },
  { gameAccountInfo = { isOnline = true, characterName = "Retail", className = "Mage", characterLevel = 80, realmName = "Other", clientProgram = "WoW", wowProjectID = 1, factionName = "Alliance" } },
  { gameAccountInfo = { isOnline = false } },
  { gameAccountInfo = { isOnline = true, characterName = "Tegaman Tmanic", className = "Mage", characterLevel = 12, realmName = "CAMWOW EU5 Realm 7 PvE", clientProgram = "WoW", wowProjectID = 99, factionName = "Alliance" } },
}
BNGetNumFriends = function() return #BNET end
C_BattleNet = { GetFriendAccountInfo = function(i) return BNET[i] end }
""")
rows, n = ns.BuildFriendRows()
print("bnet friends:", n, sorted({rows[i].friend.name for i in range(1, len(rows)+1)}))

L.execute("Auctionator.SavedState = { TimeOfLastBrowseScan = os.time() - 2 * 3600 }")
print("browse scan status:", ns.StatusLine().split("    ")[-1])

# --- Language switch ---
slash = L.eval('SlashCmdList.GULDBOG')
print("default lang:", L.globals().GuldbogDB.lang)
slash("sprog da")
rows, total = ns.BuildRows()
print("da advice:", sorted({rows[i].advice for i in range(1, len(rows)+1)})[:4])
print("da tabs:", sorted(f._text for f in L.eval("FRAMES").values() if L.eval("function(f) return rawget(f,'labelKey') ~= nil end")(f)))
print("da status:", ns.StatusLine())
slash("language en")
print("en status:", ns.StatusLine())
slash("language xx")
print("bad arg ->", L.eval("PRINTS[#PRINTS]"))

# --- Settings ---
db = L.globals().GuldbogDB
L.execute("GuldbogDB.settings = {}; GuldbogDB.deposit = {}; AuctionHouseFrame.IsShown = function() return false end")
L.execute("""
CURRENT = "Warrior"
ITEMS[7100] = { "Settings Test", 0 }
AH[7100] = 1000
BAGS = { [0] = { {7100, 1} } }
""")
fire("BAG_UPDATE_DELAYED")
def gain(id):
    rows, _ = ns.BuildRows()
    for i in range(1, len(rows)+1):
        if rows[i].id == id: return rows[i].gain, rows[i].advice
print("defaults:", ns.Setting("minDeposit"), ns.Setting("duration"), ns.Setting("ahCut"), ns.Setting("depositLost"))
print("gain default (1000*0.95 - 100):", gain(7100))
db.settings.ahCut = 0.15
print("neutral AH (1000*0.85 - 100):", gain(7100))
db.settings.depositLost = False
print("deposit not lost (850):", gain(7100))
db.settings.minDeposit = 0; db.settings.ahCut = None; db.settings.depositLost = None
print("min deposit 0 (950):", gain(7100))
db.settings.minDeposit = None
# Settings view through the UI: open, cycle every setting button, go back.
sb = [f for f in L.eval("FRAMES").values() if f._text in ("Settings", "Indstillinger")]
print("settings button:", len(sb))
sb[0]._OnClick(sb[0])
print("button label in settings:", sb[0]._text)
def click_text(*texts):
    for f in list(L.eval("FRAMES").values()):
        if f._text in texts and f._OnClick is not None:
            f._OnClick(f); return True
    return False
lang_before = db.lang
click_text("English", "Dansk")
print("language cycled:", lang_before, "->", db.lang)
click_text("English", "Dansk")
click_text("Medium", "Mellem")
print("duration cycled to:", ns.Setting("duration"))
click_text("Nej", "No") or None
print("db.settings after open:", dict(db.settings) if db.settings else {})
sb[0]._OnClick(sb[0])
print("button label after back:", sb[0]._text)

# --- Sell on AH: Auctionator, fallback to the game's own Sell tab ---
L.execute("""
CURRENT = "Warrior"
BAGS = { [0] = { {818, 2} } }
AuctionHouseFrame.IsShown = function() return true end
AuctionHouseFrameDisplayMode = { ItemSell = "ItemSell", CommoditiesSell = "CommoditiesSell" }
Enum.ItemCommodityStatus = { Unknown = 0, Item = 1, Commodity = 2 }
C_AuctionHouse.GetItemCommodityStatus = function() return 2 end
C_AuctionHouse.IsSellItemValid = function() return true end
AuctionHouseFrame.SetDisplayMode = function(_, m) DISPLAY = m end
AuctionHouseFrame.CommoditiesSellFrame = { SetItem = function(_, loc) if loc then BLIZZ = loc.slot end end }
AuctionHouseFrame.ItemSellFrame = { SetItem = function() end }
FIRED = nil; BLIZZ = nil; PRINTS = {}
""")
ns.SellOnAH(818)
print("auctionator path:", L.eval("FIRED and FIRED.ev"), "blizz:", L.eval("BLIZZ"))
L.execute("SAVED_TAB = AuctionatorTabs_Selling; AuctionatorTabs_Selling = nil; FIRED = nil")
ns.SellOnAH(818)
print("auctionator changed -> blizzard:", L.eval("DISPLAY"), L.eval("BLIZZ"), "fired:", L.eval("FIRED"))
L.execute("AuctionatorTabs_Selling = SAVED_TAB; BLIZZ = nil; Auctionator.Groups.Utilities.ToPostingItem = function() error('changed') end")
ns.SellOnAH(818)
print("callback fails -> fallback:", L.eval("BLIZZ"), "|", L.eval("PRINTS[#PRINTS]"))
L.execute("AuctionHouseFrame.SetDisplayMode = nil")
ns.SellOnAH(818)
print("both fail ->", L.eval("PRINTS[#PRINTS]"))

# --- Collapsible groups ---
L.execute("""
CURRENT = "Warrior"
AuctionHouseFrame.IsShown = function() return false end
GuldbogDB.settings = {}; GuldbogDB.open = {}; GuldbogDB.sort.stock = {}; GuldbogDB.lang = "da"
BAGS = { [0] = { {7001, 4}, {9999, 3}, {2901, 1}, {2770, 5} } }
""")
fire("BAG_UPDATE_DELAYED")
visible = L.eval("""function()
  local out = {}
  for _, f in ipairs(FRAMES) do
    local d = rawget(f, "data")
    if d and rawget(f, "_shown") ~= false and rawget(f, "header") then
      out[#out + 1] = { y = select(5, unpack(rawget(f, "_point") or {})) or 0, d = d, h = f.header._text }
    end
  end
  return out
end""")
def view():
    lines = []
    for e in visible().values():
        lines.append(("[" + e.h + "]") if e.d.isHeader else ("   " + str(e.d.sortName)))
    return lines
tabs["Inventory"]._OnClick(tabs["Inventory"]) if "Inventory" in tabs else None
L.execute("for _, f in ipairs(FRAMES) do if rawget(f, 'labelKey') == 'TAB_STOCK' then f._OnClick(f) end end")
for line in view(): print("stock:", line)
clickHeader = L.eval("""function(prefix)
  for _, f in ipairs(FRAMES) do
    local d = rawget(f, "data")
    if d and d.isHeader and rawget(f, "_shown") ~= false and f.header._text:find(prefix, 1, true) == 1 then
      f._OnMouseUp(f, "LeftButton"); return true
    end
  end
end""")
clickHeader("Behold / Værktøj"); clickHeader("Sælg på AH")
for line in view(): print("toggled:", line)
print("open state:", dict(L.globals().GuldbogDB.open))
L.execute("for _, f in ipairs(FRAMES) do if rawget(f, 'labelKey') == 'TAB_CRAFT' then f._OnClick(f) end end")
for line in view(): print("craft:", line)
L.execute("for _, f in ipairs(FRAMES) do if rawget(f, 'labelKey') == 'TAB_STOCK' then f._OnClick(f) end end")
