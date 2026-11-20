local _, ns = ...

-- Profession skill line IDs (same as Classic/Mainline).
ns.SKILL = {
  MINING = 186,
  BLACKSMITHING = 164,
  TAILORING = 197,
  ENCHANTING = 333,
  SKINNING = 393,
  LEATHERWORKING = 165,
  COOKING = 185,
  FIRST_AID = 129,
  FISHING = 356,
}

-- Secondary professions every character can have on top of the two primary ones.
ns.SECONDARY = { [185] = true, [129] = true, [356] = true }

-- English client names, used only as a fallback when skill line IDs are unavailable.
ns.PROF_NAMES = {
  [186] = "Mining",
  [164] = "Blacksmithing",
  [197] = "Tailoring",
  [333] = "Enchanting",
  [393] = "Skinning",
  [165] = "Leatherworking",
  [185] = "Cooking",
  [129] = "First Aid",
  [356] = "Fishing",
}

local S = ns.SKILL

-- Materials one of our crafting professions uses: itemID -> skill line.
-- Classic item IDs. Forever may differ for new items; extend as needed.
ns.USED_BY = {
  -- Mining (smelting): ore
  [2770] = S.MINING, -- Copper Ore
  [2771] = S.MINING, -- Tin Ore
  [2775] = S.MINING, -- Silver Ore
  [2772] = S.MINING, -- Iron Ore

  -- Blacksmithing: bars, stone
  [2840] = S.BLACKSMITHING, -- Copper Bar
  [3576] = S.BLACKSMITHING, -- Tin Bar
  [2841] = S.BLACKSMITHING, -- Bronze Bar
  [2842] = S.BLACKSMITHING, -- Silver Bar
  [3575] = S.BLACKSMITHING, -- Iron Bar
  [2835] = S.BLACKSMITHING, -- Rough Stone
  [2836] = S.BLACKSMITHING, -- Coarse Stone
  [2838] = S.BLACKSMITHING, -- Heavy Stone

  -- Tailoring: cloth
  [2320] = S.TAILORING, -- Coarse Thread
  [2321] = S.TAILORING, -- Fine Thread
  [2589] = S.TAILORING, -- Linen Cloth
  [2996] = S.TAILORING, -- Bolt of Linen Cloth
  [2592] = S.TAILORING, -- Wool Cloth
  [2997] = S.TAILORING, -- Bolt of Woolen Cloth
  [4306] = S.TAILORING, -- Silk Cloth
  [4305] = S.TAILORING, -- Bolt of Silk Cloth

  -- Enchanting: dust, essences, shards
  [10940] = S.ENCHANTING, -- Strange Dust
  [11083] = S.ENCHANTING, -- Soul Dust
  [10938] = S.ENCHANTING, -- Lesser Magic Essence
  [10939] = S.ENCHANTING, -- Greater Magic Essence
  [10998] = S.ENCHANTING, -- Lesser Astral Essence
  [10978] = S.ENCHANTING, -- Small Glimmering Shard

  -- Leatherworking: leather and hides
  [2934] = S.LEATHERWORKING, -- Ruined Leather Scraps
  [2318] = S.LEATHERWORKING, -- Light Leather
  [783]  = S.LEATHERWORKING, -- Light Hide
  [2319] = S.LEATHERWORKING, -- Medium Leather
  [4232] = S.LEATHERWORKING, -- Medium Hide
}

-- Profession tools: always kept, never suggested for sale.
ns.TOOLS = {
  [2901] = true, -- Mining Pick
  [5956] = true, -- Blacksmith Hammer
  [7005] = true, -- Skinning Knife
  [6256] = true, -- Fishing Pole
  [6365] = true, -- Strong Fishing Pole
  [4471] = true, -- Flint and Tinder
}

-- Recipe items: item class 9, subclass -> profession skill line.
ns.RECIPE_CLASS = 9
ns.RECIPE_SUBCLASS = {
  [1] = S.LEATHERWORKING,
  [2] = S.TAILORING,
  [4] = S.BLACKSMITHING,
  [5] = S.COOKING,
  [7] = S.FIRST_AID,
  [8] = S.ENCHANTING,
  [9] = S.FISHING,
}

-- Who can wear and wield what. Based on Classic rules; Forever may differ.
-- Item class 4 = armor (subclass), item class 2 = weapon (subclass).
-- A number means "from this level"; true means always.
ns.ARMOR = {
  [0] = { ALL = true },                                     -- misc: rings, necks, trinkets, off-hands
  [1] = { ALL = true },                                     -- cloth (incl. cloaks)
  [2] = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, SHAMAN = true, DRUID = true },
  [3] = { WARRIOR = true, PALADIN = true, HUNTER = 40, SHAMAN = 40 },
  [4] = { WARRIOR = 40, PALADIN = 40 },
  [6] = { WARRIOR = true, PALADIN = true, SHAMAN = true }, -- shields
}

ns.WEAPONS = {
  WARRIOR = { [0]=1,[1]=1,[2]=1,[3]=1,[4]=1,[5]=1,[6]=1,[7]=1,[8]=1,[10]=1,[13]=1,[15]=1,[16]=1,[18]=1 },
  PALADIN = { [0]=1,[1]=1,[4]=1,[5]=1,[6]=1,[7]=1,[8]=1 },
  HUNTER  = { [0]=1,[1]=1,[2]=1,[3]=1,[6]=1,[7]=1,[8]=1,[10]=1,[13]=1,[15]=1,[16]=1,[18]=1 },
  ROGUE   = { [2]=1,[3]=1,[4]=1,[7]=1,[13]=1,[15]=1,[16]=1,[18]=1 },
  PRIEST  = { [4]=1,[10]=1,[15]=1,[19]=1 },
  SHAMAN  = { [0]=1,[1]=1,[4]=1,[5]=1,[10]=1,[13]=1,[15]=1 },
  MAGE    = { [7]=1,[10]=1,[15]=1,[19]=1 },
  WARLOCK = { [7]=1,[10]=1,[15]=1,[19]=1 },
  DRUID   = { [4]=1,[5]=1,[10]=1,[13]=1,[15]=1 },
}

-- Can a character of this class token and level use the item right now?
function ns.CanUse(classToken, level, itemClass, subclass, minLevel)
  if not classToken or not level then return false end
  if minLevel and level < minLevel then return false end
  if itemClass == 4 then
    local rule = ns.ARMOR[subclass]
    if not rule then return false end
    local r = rule.ALL or rule[classToken]
    if r == true then return true end
    return type(r) == "number" and level >= r
  elseif itemClass == 2 then
    local w = ns.WEAPONS[classToken]
    return w ~= nil and w[subclass] ~= nil
  end
  return false
end
