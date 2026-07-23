extends Node

## Lightweight i18n. English source strings are keys; zh_TW maps to Traditional Chinese.

signal locale_changed(locale: String)

const LOCALE_EN := "en"
const LOCALE_ZH_TW := "zh_TW"

var _locale: String = LOCALE_EN

## msgid (English) → Traditional Chinese
const ZH_TW: Dictionary = {
	# --- Language / brand ---
	"Language": "語言",
	"English": "English",
	"繁體中文": "繁體中文",
	"Cozy Farm": "溫馨農場",
	"Build your island · grow your world": "打造你的島嶼 · 耕耘你的世界",

	# --- Main menu ---
	"New Game": "新遊戲",
	"Load Game": "讀取遊戲",
	"Exit": "離開",
	"Worlds": "世界",
	"Tap to select · Long-press to rename or delete": "點選世界 · 長按可重新命名或刪除",
	"No worlds yet — tap New Game to start.": "尚無世界 — 點「新遊戲」開始。",
	"No worlds yet — tap New Game": "尚無世界 — 請點「新遊戲」",
	"Play": "進入",
	"Rename World": "重新命名世界",
	"Rename": "重新命名",
	"World name": "世界名稱",
	"Delete World": "刪除世界",
	"Delete this world? This cannot be undone.": "確定刪除此世界？此操作無法復原。",
	"Delete \"%s\"? This cannot be undone.": "確定刪除「%s」？此操作無法復原。",
	"Delete": "刪除",
	"Cancel": "取消",
	"Renamed": "已重新命名",
	"Enter a valid name": "請輸入有效名稱",
	"World deleted": "世界已刪除",
	"Delete failed": "刪除失敗",
	"World not found": "找不到世界",
	"My Farm": "我的農場",
	"My Farm %d": "我的農場 %d",
	"Never played": "尚未遊玩",
	"Just now": "剛剛",
	"%d min ago": "%d 分鐘前",
	"%d hr ago": "%d 小時前",
	"%d days ago": "%d 天前",
	"Island · starter": "島嶼 · 初始",
	"Island · +%d expand": "島嶼 · 擴張 +%d",

	# --- In-game chrome ---
	"Leave World": "離開世界",
	"Save your farm before returning to Worlds?": "返回世界列表前要儲存農場嗎？",
	"Save": "儲存",
	"Don't Save": "不儲存",
	"Saved \"%s\"": "已儲存「%s」",
	"Save failed!": "儲存失敗！",
	"Ready": "就緒",
	"Select": "選取",
	"Multi": "多選",
	"Undo": "復原",
	"Mute all": "全部靜音",
	"Unmute all": "取消靜音",
	"Mute music only": "只靜音音樂",
	"Unmute music": "取消音樂靜音",
	"Hide / show menu": "隱藏／顯示選單",
	"Mute all sound": "全部靜音",
	"Mute / unmute background music": "靜音／取消靜音背景音樂",
	"Shrink island — toward original size": "縮小島嶼 — 靠近原始大小",
	"Expand island — grow playable floor": "擴大島嶼 — 增加可玩範圍",
	"Morning — jump to sunrise": "白天 — 跳到日出",
	"Night — jump to moonrise": "夜晚 — 跳到月出",
	"Jump to morning": "切到白天",
	"Jump to night": "切到夜晚",
	"Expand island": "擴大島嶼",
	"Shrink island": "縮小島嶼",
	"Dawn": "黎明",
	"Sunrise": "日出",
	"Daytime": "白天",
	"Sunset": "日落",
	"Dusk": "黃昏",
	"Night": "夜晚",
	"Before dawn": "破曉前",
	"%s — 5 min day / 5 min night cycle": "%s — 白天／夜晚各 5 分鐘",
	"Loaded \"%s\"": "已載入「%s」",
	"Could not load world — starting empty": "無法載入世界 — 以空白農場開始",
	"New world \"%s\" — tap Save to keep progress": "新世界「%s」— 點儲存以保留進度",
	"Back to build view": "返回建造視角",

	# --- Palette / tools ---
	"Terrain": "地形",
	"Building": "建築",
	"Animal": "動物",
	"Seed": "種子",
	"Decoration": "裝飾",
	"Hoe": "鋤頭",
	"Harvest": "收割",
	"Rod": "釣竿",
	"Sickle": "鐮刀",
	"Tool": "工具",
	"Hide palette": "隱藏選單",
	"Show palette": "顯示選單",

	# --- Inventory / walk ---
	"Backpack": "背包",
	"Close": "關閉",
	"Open backpack": "打開背包",
	"Walk on your island": "在島上散步",
	"Top row = walk hotbar (1–8) · Bottom-right = tools (∞)": "最上排＝散步快捷欄（1–8）· 右下＝工具（∞）",
	"Top row = walk hotbar (1–8) · Compost fertilizes plants · Bottom-right = tools (∞)": "最上排＝散步快捷欄（1–8）· 堆肥可施肥 · 右下＝工具（∞）",
	"Use": "使用",
	"Reel": "收線",
	"Wait…": "等待…",
	"Walk — drag yellow figure · tap again to drop in": "散步 — 拖曳黃色人偶 · 再點一次進入",
	"Can't stand here — try grass, path, bridge, or bench": "這裡站不住 — 試試草地、石徑、橋或長椅",
	"Select a hotbar item first (1–8)": "請先選快捷欄物品（1–8）",
	"Look at / face an animal to feed": "看著或面向動物來餵食",
	"Look at / face an animal to pet": "看著或面向動物來撫摸",
	"Tilled dirt": "已翻成泥土",
	"Can't hoe here": "這裡不能鋤",
	"Waved %s": "揮了揮 %s",
	"No %s left": "沒有 %s 了",
	"Feed (species diet) · Click animal / Walk Use": "餵食（依物種飲食）· 點動物／散步時使用",

	# --- Selection bar ---
	"Move": "移動",
	"Copy": "複製",
	"Rotate": "旋轉",
	"Confirm": "確認",

	# --- Animal card / needs ---
	"Affinity": "好感",
	"Satiety": "飽食",
	"Mood": "心情",
	"%s won't eat %s": "%s 不吃 %s",
	"%s loved the %s!": "%s 超愛這個 %s！",
	"%s ate the %s!": "%s 吃了 %s！",
	"%s needs a moment": "%s 需要休息一下",
	"Pet %s (+affinity)": "撫摸了 %s（好感＋）",
	"Can't feed that": "無法餵食",
	"Can't pet that": "無法撫摸",

	# --- Placeables / inventory names ---
	"Grass": "草地",
	"Dirt": "泥土",
	"Water": "水域",
	"Rock": "石頭",
	"Tree Seed": "樹苗",
	"Fence": "圍籬",
	"Crop Bed": "花圃",
	"Shed": "小屋",
	"Farmhouse": "農舍",
	"Green Farmhouse": "綠色農舍",
	"Barn": "穀倉",
	"Windmill": "風車",
	"Granary": "糧倉",
	"Bridge": "橋",
	"Lamp Post": "路燈",
	"Well": "水井",
	"Cow": "牛",
	"Chicken": "雞",
	"Sheep": "羊",
	"Pig": "豬",
	"Duck": "鴨",
	"Rabbit": "兔",
	"Butterfly": "蝴蝶",
	"Red Flower Seed": "紅花種子",
	"Yellow Flower Seed": "黃花種子",
	"Sunflower Seed": "向日葵種子",
	"Tulip Seed": "鬱金香種子",
	"Wheat Seed": "小麥種子",
	"Carrot Seed": "胡蘿蔔種子",
	"Stone Path": "石徑",
	"Greenhouse": "溫室",
	"Pond": "池塘",
	"Fountain": "噴泉",
	"Bench": "長椅",
	"Hay Bale": "乾草堆",
	"Wind Wheel": "風輪",
	"Lookout Tower": "瞭望塔",
	"Wheat": "小麥",
	"Carrot": "胡蘿蔔",
	"Sunflower": "向日葵",
	"Wood": "木材",
	"Fish": "魚",
	"Meat": "肉",
	"Compost": "堆肥",

	# --- Plant card / fertilize ---
	"Growth": "成長",
	"Stage %d / %d": "階段 %d／%d",
	"Ready to harvest": "可以收割",
	"Fertilized (faster)": "已施肥（加速）",
	"Not fertilized": "尚未施肥",
	"Fertilized — growing faster": "已施肥 — 成長加速",
	"Already fertilized": "已經施過肥了",
	"Already mature": "已經成熟了",
	"Aim at a growing plant to fertilize": "對準正在成長的植物來施肥",
	"Can't fertilize that": "無法施肥",
	"Harvested %s! (+compost)": "收穫了 %s！（＋堆肥）",
	"Pet": "撫摸",
	"Rest": "休息",
	"Stand": "起身",
	"Collect": "採集",
	"Milk": "牛奶",
	"Shear": "剪毛",
	"Sheep Milk": "羊奶",
	"Wool": "羊毛",
	"Friendly": "親人",
	"Shy": "害羞",
	"Gluttonous": "貪吃",
	"Sleepy": "愛睡",
	"Baby": "幼體",
	"Adult": "成年",
	"Ready to collect": "可採集",
	"A baby %s was born!": "生出一隻小%s了！",
	"Collected %s from %s": "取得了 %s（來自 %s）",
	"Too young to collect from": "還太小，還不能採集",
	"Nothing ready yet — wait a bit": "還沒準備好 — 再等一下",
	"Can't collect from that": "無法採集",
	"Look at / face an animal to collect": "對準動物才能採集",
	"Empty hands to collect": "請空手再採集",
	"Resting on the bench": "在長椅上休息",
	"Stood up": "已起身",
	"Fertilize": "施肥",
	"Fertilize — click a growing plant (uses 1 Compost)": "施肥 — 點尚未成熟的植物（消耗 1 堆肥）",
	"No Compost left — harvest crops to get more": "沒有堆肥了 — 收穫作物可再獲得",
	"Rename animal": "為動物更名",
	"Rename %s": "更名 %s",
	"Enter a name (leave blank to reset)": "輸入名字（空白則恢復物種名）",
	"Animal name": "動物名字",
	"Named %s": "已命名為 %s",
	"Name reset to %s": "已恢復為 %s",
	"Can't rename that": "無法更名",
	"Aim at an animal to rename": "對準動物才能更名",

	# --- Modes / status (placement) ---
	"Select — drag empty ground to box-select, then drag selection to move.": "選取 — 在空地上拖曳框選，再拖曳選取物移動。",
	"Multiselect — tap items to add/remove · use top Move / Rotate / Delete": "多選 — 點選加入／移除 · 用上方移動／旋轉／刪除",
	"Hoe — click grass to turn it into dirt paths.": "鋤頭 — 點草地翻成泥土。",
	"Harvest — hold and slide over mature plants": "收割 — 按住並滑過成熟作物",
	"Rod — click water to cast, wait for a bite, click again to reel in": "釣竿 — 點水域拋竿，等魚訊後再點收線",
	"No %s left to feed": "沒有 %s 可餵了",
	"Feed — click an animal with %s": "餵食 — 用 %s 點動物",
	"Place %s — tap a cell to place": "放置 %s — 點格子放置",
	"Place %s — hold/drag/release. R to rotate preview": "放置 %s — 按住拖曳放開。R 旋轉預覽",
	"Nothing to undo": "沒有可復原的操作",
	"Deselected": "已取消選取",
	"Patience — wait for the rod to shake": "再等一下 — 等釣竿晃動",
	"Cast only on water": "只能在水上拋竿",
	"Hoed grass at (%d, %d)": "已在 (%d, %d) 鋤草",
	"Hoe only works on grass": "鋤頭只能用在草地上",
	"Release to place at ghost cell": "放開以放置到預覽格",
	"Cancelled place": "已取消放置",
	"Cleared to grass floor at (%d, %d)": "已在 (%d, %d) 清成草地",
	"Placed %s at (%d, %d)": "已放置 %s 於 (%d, %d)",
	"Cannot place here": "這裡無法放置",
	"Selected 1 — hold-drag to move, or box-select more on empty ground": "已選 1 個 — 按住拖曳移動，或在空地框選更多",
	"Selected %d — tap more or use top actions": "已選 %d 個 — 再點選或用上方操作",
	"Box select — drag to cover items, release to select": "框選 — 拖曳覆蓋物品後放開",
	"Nothing selected": "尚未選取",
	"Selected %d — drag any selected item to move the group": "已選 %d 個 — 拖任一選取物移動整組",
	"Cannot move selection there": "無法將選取物移到那裡",
	"Moved %d items": "已移動 %d 個物品",
	"Nothing ready to harvest here": "這裡沒有可收割的作物",
	"Harvested %s!": "收穫了 %s！",
	"Harvested!": "收穫完成！",
	"Harvested %d": "收穫了 %d 個",
	"Harvested %d plants": "收穫了 %d 株作物",
	"Nothing ready along that path": "這條路上沒有成熟作物",
	"Line cast — wait for a bite…": "已拋竿 — 等待魚訊…",
	"Bite! Click again to reel in the fish!": "上鉤了！再點一次收線！",
	"Caught a fish!": "釣到魚了！",
	"Click an animal to feed": "點動物來餵食",
	"Move cancelled": "已取消移動",
	"Moved to (%d, %d)": "已移到 (%d, %d)",
	"Cannot move there": "無法移到那裡",
	"Rotated %s": "已旋轉 %s",
	"Rotated — red means blocked, move or rotate again": "已旋轉 — 紅色表示卡住，請再移動或旋轉",
	"Facing %d° — still placing %s": "朝向 %d° — 仍在放置 %s",
	"Rotated %d item(s)": "已旋轉 %d 個物品",
	"This item can't rotate": "此物品無法旋轉",
	"Rotated object": "已旋轉物件",
	"Deleted %d items": "已刪除 %d 個物品",
	"Deleted object": "已刪除物件",
	"Cancelled — selection cleared": "已取消 — 清除選取",
	"Move — drag to position · tap nearby to drop": "移動 — 拖到位置 · 點附近放下",
	"Copy — drag to extend · green ✓ to place · ✕ to cancel": "複製 — 拖曳延伸 · 綠 ✓ 放置 · ✕ 取消",
	"Can't place — clear obstacles or cancel": "無法放置 — 清開障礙或取消",
	"Copied %d item(s)": "已複製 %d 個物品",
	"Copy cancelled": "已取消複製",
	"Nothing to copy": "沒有可複製的內容",
	"Copy group — drag to place · green ✓ to confirm · ✕ to cancel": "複製整組 — 拖曳放置 · 綠 ✓ 確認 · ✕ 取消",
	"Can't place — drag to a free spot or cancel": "無法放置 — 拖到空位或取消",
	"Stay put": "維持原位",
	"Island expanded": "島嶼已擴大",
	"Island shrunk": "島嶼已縮小",
	"Can't expand further": "無法再擴大",
	"Can't shrink — objects are in the way": "無法縮小 — 邊緣還有物件",
	"Exploring — joystick to move · swipe to look · Exit to leave": "探索中 — 搖桿移動 · 滑動視角 · 離開返回",
	"Wait for a bite…": "等待魚訊…",
	"Drag figure · tap to enter": "拖曳人偶 · 點一下進入",
	"Island expanded %.1f → %.1f (+%.1f)": "島嶼已擴大 %.1f → %.1f（+%.1f）",
	"Island is already at max size.": "島嶼已達最大。",
	"Can't shrink — move or remove items near the edge first": "無法縮小 — 請先移開邊緣物件",
	"Island shrunk %.1f → %.1f (−%.1f)": "島嶼已縮小 %.1f → %.1f（−%.1f）",
	"Island is already at original size.": "島嶼已是原始大小。",
	"Seeds need dirt — use Hoe on grass first, then plant again": "種子需要泥土 — 先用鋤頭鋤草地，再種植",
	"Nothing ready to harvest": "這裡沒有可收割的作物",
	"Need water or a pond ahead": "前方需要水域或池塘",
	"Line cast — wait, then Use again": "已拋竿 — 等待後再按使用",
	"Bite! Press Use to reel in": "上鉤了！按使用收線",
	"Farm": "農場",
}


func _ready() -> void:
	_locale = _read_saved_locale()
	TranslationServer.set_locale(_locale)


func get_locale() -> String:
	return _locale


func is_zh_tw() -> bool:
	return _locale == LOCALE_ZH_TW


func set_locale(locale: String) -> void:
	var next := LOCALE_EN
	if locale == LOCALE_ZH_TW or locale == "zh-TW" or locale == "zh_Hant":
		next = LOCALE_ZH_TW
	if next == _locale:
		return
	_locale = next
	TranslationServer.set_locale(_locale)
	_write_saved_locale(_locale)
	locale_changed.emit(_locale)


func t(key: String) -> String:
	if key.is_empty():
		return key
	if _locale == LOCALE_ZH_TW and ZH_TW.has(key):
		return str(ZH_TW[key])
	return key


func tf(key: String, args: Array = []) -> String:
	if args.is_empty():
		return t(key)
	return t(key) % args


func _read_saved_locale() -> String:
	SaveManager.ensure_ready()
	var settings := SaveManager.load_settings_dict()
	var raw := str(settings.get("locale", LOCALE_EN))
	if raw == LOCALE_ZH_TW or raw == "zh-TW" or raw == "zh_Hant":
		return LOCALE_ZH_TW
	return LOCALE_EN


func _write_saved_locale(locale: String) -> void:
	var settings := SaveManager.load_settings_dict()
	settings["locale"] = locale
	SaveManager.save_settings_dict(settings)
