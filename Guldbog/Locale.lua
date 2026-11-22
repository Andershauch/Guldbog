local _, ns = ...

-- All user-facing text. English is the default; Danish via /guldbog sprog da.
-- WoW has no Danish client, so the language is a setting, not GetLocale().
ns.STRINGS = {
  en = {
    TAB_STOCK = "Inventory", TAB_CRAFT = "Crafting", TAB_FRIENDS = "Friends", REFRESH = "Refresh",

    COL_ITEM = "Item", COL_TOTAL = "Total", COL_HERE = "Here", COL_PRICE = "Price/ea",
    COL_VALUE = "Value", COL_PROFIT = "Profit", COL_SUGGESTION = "Suggestion",
    COL_MAKES = "Makes", COL_CANMAKE = "Can make", COL_MATERIALS = "Materials",
    COL_SALE = "Sale", COL_CRAFTER = "Skill", COL_USABLEBY = "Usable by",

    ADV_USE = "Use: %s", ADV_LEARN = "Learn: %s", ADV_SELL_AH = "Sell on AH",
    ADV_SELL_VENDOR = "Sell to vendor", ADV_KEEP_TOOL = "Keep (tool)",
    ADV_AT = "at %s", ADV_KEEP_CHOICE = "Keep (your choice)", ADV_ON_AH = "On the AH: %d",
    ADV_NO_PROFIT = "No profit – keep or destroy", ADV_NO_PRICE = "No price – scan the AH",

    DIFF_OPTIMAL = "orange", DIFF_MEDIUM = "yellow", DIFF_EASY = "green", DIFF_TRIVIAL = "grey",
    HOLDER_MAIL = "(mail)", HOLDER_AH = "(on AH)", ITEM_N = "Item #%d",
    MISSING = "missing", NO_PRICE = "no price", OFFLINE = "offline",
    AGE_NEVER = "never", AGE_NOW = "now", AGE_MIN = "%d min", AGE_H = "%d h", AGE_D = "%d d",

    TT_DEPOSIT = "Deposit", TT_ESTIMATED = " (estimated)", TT_MAKES = "Makes %d",
    TT_SOLD_VIA = "Sold via", TT_CLICK_AH = "Click at the AH: open in the Sell tab",
    TT_CLICK_VENDOR = "Click at a vendor: sell all from your bags",
    TT_ALT_KEEP = "Alt+click: keep / sell anyway", TT_CLICK_MAIL = "Click at a mailbox: prepare mail to %s",

    FOOT_SELLABLE = "Can be sold for about: %s",
    FOOT_NO_SOURCE = "Neither Auctionator nor TSM is active – no AH prices.",
    FOOT_PROFITABLE = "Profitable recipes: %d of %d",
    FOOT_NO_RECIPES = "No recipes yet – open your profession windows once.",
    FOOT_NO_FRIENDS = "No friends found. Battle.net friends show only while online.",
    FOOT_NO_MATCH = "None of your friends can use your gear right now.",
    FOOT_FRIENDS_HINT = "Click at a mailbox to prepare a mail.",
    STATUS_BANK = "Bank", STATUS_MAIL = "Mail", STATUS_PRICES = "AH prices", STATUS_NO_SOURCE = "no source",

    MSG_OPEN_AH = "Open the auction house first.", MSG_TALK_VENDOR = "Talk to a vendor first.",
    MSG_OPEN_MAIL = "Open a mailbox first.", MSG_NOT_IN_BAGS = "That item isn't in this character's bags.",
    MSG_AH_FAIL = "Couldn't open the item for sale. Drag it to the sell window yourself.",
    MSG_AH_FALLBACK = "Auctionator couldn't take the item, so it opened in the game's own Sell tab.",
    MSG_SOLD = "Sold %d. Undo it from the vendor's Buyback tab.",
    MSG_MAIL_READY = "%s is ready for %s. Check it and press Send.",
    MSG_MAIL_FAIL = "Couldn't prepare the mail. Attach the item yourself.",
    MSG_LANGUAGE = "Language: English", MSG_LANGUAGE_USAGE = "Use /guldbog language en or /guldbog language da",

    MM_CLICK = "Click: open or close", MM_DRAG = "Drag: move the button",
    MM_ICON = "/guldbog icon: hide or show the button", MM_LANGUAGE = "/guldbog language da: switch to Danish",
    GRP_USE = "Learn / Use", GRP_AH = "Sell on AH", GRP_VENDOR = "Sell to vendor",
    GRP_TOOL = "Keep / Tools", GRP_KEEP = "Keep / Your choice", GRP_ONAH = "On the AH",
    GRP_NONE = "No profit / No price", GRP_CRAFTER = "%s · %d recipes, %d profitable",
    SETTINGS = "Settings", BACK = "Back",
    SET_CHARACTERS = "Characters", SET_CHARACTERS_HELP = "Hidden characters are left out of every list and suggestion.",
    CHAR_SHOWN = "Shown", CHAR_HIDDEN = "Hidden",
    SET_LANGUAGE = "Language", LANG_EN = "English", LANG_DA = "Dansk",
    SET_MIN_DEPOSIT = "Minimum deposit", SET_MIN_DEPOSIT_HELP = "Used until Guldbog has asked the game at the AH.",
    SET_DURATION = "Auction duration", DUR_1 = "Short", DUR_2 = "Medium", DUR_3 = "Long",
    SET_DURATION_HELP = "Deposits are updated next time you open the AH.",
    SET_AH_CUT = "AH cut", CUT_FACTION = "5 % (faction AH)", CUT_NEUTRAL = "15 % (neutral AH)",
    SET_DEPOSIT_LOST = "Count deposit as lost", SET_DEPOSIT_LOST_HELP = "Careful: assumes the item doesn't sell, so the deposit isn't refunded.",
    SET_MINIMAP = "Show minimap button", YES = "Yes", NO = "No",
    FOOT_SETTINGS = "Click a button to change it. Applies to all characters.",
  },
  da = {
    TAB_STOCK = "Lager", TAB_CRAFT = "Crafting", TAB_FRIENDS = "Venner", REFRESH = "Opdatér",

    COL_ITEM = "Vare", COL_TOTAL = "Antal", COL_HERE = "Her", COL_PRICE = "Pris/stk",
    COL_VALUE = "Værdi", COL_PROFIT = "Gevinst", COL_SUGGESTION = "Forslag",
    COL_MAKES = "Laver", COL_CANMAKE = "Kan lave", COL_MATERIALS = "Materialer",
    COL_SALE = "Salg", COL_CRAFTER = "Skill", COL_USABLEBY = "Kan bruges af",

    ADV_USE = "Brug selv: %s", ADV_LEARN = "Lær selv: %s", ADV_SELL_AH = "Sælg på AH",
    ADV_SELL_VENDOR = "Sælg til vendor", ADV_KEEP_TOOL = "Behold (værktøj)",
    ADV_AT = "hos %s", ADV_KEEP_CHOICE = "Behold (dit valg)", ADV_ON_AH = "Til salg på AH: %d",
    ADV_NO_PROFIT = "Ingen gevinst – behold eller smid ud", ADV_NO_PRICE = "Ingen pris – scan AH i Auctionator",

    DIFF_OPTIMAL = "orange", DIFF_MEDIUM = "gul", DIFF_EASY = "grøn", DIFF_TRIVIAL = "grå",
    HOLDER_MAIL = "(post)", HOLDER_AH = "(på AH)", ITEM_N = "Vare #%d",
    MISSING = "mangler", NO_PRICE = "mangler pris", OFFLINE = "offline",
    AGE_NEVER = "aldrig", AGE_NOW = "nu", AGE_MIN = "%d min", AGE_H = "%d t", AGE_D = "%d d",

    TT_DEPOSIT = "Depositum", TT_ESTIMATED = " (anslået)", TT_MAKES = "Laver %d stk.",
    TT_SOLD_VIA = "Salg via", TT_CLICK_AH = "Klik ved AH: åbn i sælg-fanen",
    TT_CLICK_VENDOR = "Klik ved handler: sælg alle i tasken",
    TT_ALT_KEEP = "Alt+klik: behold / sælg alligevel", TT_CLICK_MAIL = "Klik ved postkassen: gør klar til %s",

    FOOT_SELLABLE = "Kan sælges for ca.: %s",
    FOOT_NO_SOURCE = "Hverken Auctionator eller TSM er aktivt – ingen AH-priser.",
    FOOT_PROFITABLE = "Opskrifter med gevinst: %d af %d",
    FOOT_NO_RECIPES = "Ingen opskrifter endnu – åbn dine fag-vinduer én gang.",
    FOOT_NO_FRIENDS = "Ingen venner fundet. Battle.net-venner vises kun online.",
    FOOT_NO_MATCH = "Ingen af dine venner kan bruge dit udstyr lige nu.",
    FOOT_FRIENDS_HINT = "Klik ved postkassen for at gøre klar til at sende.",
    STATUS_BANK = "Bank", STATUS_MAIL = "Post", STATUS_PRICES = "AH-priser", STATUS_NO_SOURCE = "ingen kilde",

    MSG_OPEN_AH = "Åbn auktionshuset først.", MSG_TALK_VENDOR = "Tal med en handler først.",
    MSG_OPEN_MAIL = "Åbn en postkasse først.", MSG_NOT_IN_BAGS = "Varen ligger ikke i tasken på denne karakter.",
    MSG_AH_FAIL = "Kunne ikke åbne varen til salg. Træk den selv over i salgsvinduet.",
    MSG_AH_FALLBACK = "Auctionator kunne ikke tage varen, så den er åbnet i spillets egen sælg-fane.",
    MSG_SOLD = "Solgt %d stk. Fortryd under handlerens Buyback.",
    MSG_MAIL_READY = "%s er klar til %s. Tjek og tryk Send.",
    MSG_MAIL_FAIL = "Kunne ikke gøre brevet klar. Vedhæft varen selv.",
    MSG_LANGUAGE = "Sprog: dansk", MSG_LANGUAGE_USAGE = "Brug /guldbog sprog da eller /guldbog sprog en",

    MM_CLICK = "Klik: åbn eller luk", MM_DRAG = "Træk: flyt knappen",
    MM_ICON = "/guldbog ikon: skjul eller vis knappen", MM_LANGUAGE = "/guldbog sprog en: skift til engelsk",
    GRP_USE = "Lær selv / Brug selv", GRP_AH = "Sælg på AH", GRP_VENDOR = "Sælg til vendor",
    GRP_TOOL = "Behold / Værktøj", GRP_KEEP = "Behold / Dit valg", GRP_ONAH = "Til salg på AH",
    GRP_NONE = "Ingen gevinst / Ingen pris", GRP_CRAFTER = "%s · %d opskrifter, %d med gevinst",
    SETTINGS = "Indstillinger", BACK = "Tilbage",
    SET_CHARACTERS = "Karakterer", SET_CHARACTERS_HELP = "Skjulte karakterer tælles ikke med i lister og forslag.",
    CHAR_SHOWN = "Vises", CHAR_HIDDEN = "Skjult",
    SET_LANGUAGE = "Sprog", LANG_EN = "English", LANG_DA = "Dansk",
    SET_MIN_DEPOSIT = "Minimum-depositum", SET_MIN_DEPOSIT_HELP = "Bruges, indtil Guldbog har spurgt spillet ved AH.",
    SET_DURATION = "Auktionsvarighed", DUR_1 = "Kort", DUR_2 = "Mellem", DUR_3 = "Lang",
    SET_DURATION_HELP = "Depositum opdateres, næste gang du åbner AH.",
    SET_AH_CUT = "AH-gebyr", CUT_FACTION = "5 % (faktionens AH)", CUT_NEUTRAL = "15 % (neutralt AH)",
    SET_DEPOSIT_LOST = "Regn depositum som tabt", SET_DEPOSIT_LOST_HELP = "Forsigtigt: antager at varen ikke bliver solgt, så depositum ikke kommer tilbage.",
    SET_MINIMAP = "Vis minimap-knap", YES = "Ja", NO = "Nej",
    FOOT_SETTINGS = "Klik på en knap for at ændre. Gælder alle karakterer.",
  },
}

-- Translate a key, formatting any extra arguments into it.
function ns.T(key, ...)
  local lang = GuldbogDB and GuldbogDB.lang or "en"
  local s = (ns.STRINGS[lang] and ns.STRINGS[lang][key]) or ns.STRINGS.en[key] or key
  if select("#", ...) > 0 then return s:format(...) end
  return s
end

-- Prints a message to chat with the Guldbog prefix.
function ns.Say(key, ...)
  print("|cffffd700Guldbog:|r " .. ns.T(key, ...))
end
