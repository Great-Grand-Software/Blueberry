class_name StoreView
extends Control
## The store: one calendar for sale at a time, the next one up.
##
## The panel around the offer is drawn, but the buy control is a real `Button`
## in pale blue — the one accent in an otherwise greyscale game, on the one
## action that spends something. It handles its own contact through the normal
## GUI path; `swallows_contact` tells the pager to keep its hands off, so the
## button can never fire because a swipe happened to start on it. The cost of
## that trade is that a swipe cannot begin on the button itself, which is how
## buttons behave everywhere else too.

signal purchased(tier_index: int)

const MARGIN: float = 64.0
const TITLE_BASELINE: float = 96.0
const CARD_RECT: Rect2 = Rect2(64.0, 168.0, 592.0, 372.0)
## Baseline of the running total, repeated under whatever the store is showing:
## under the buy button when there is one, under the card when there is not.
const BALANCE_BASELINE: float = 754.0
const SOLD_OUT_BALANCE_BASELINE: float = 618.0

@onready var _buy_button: Button = %BuyButton


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_button_pressed)
	refresh()


## Repaints the store and puts the buy button in the right state. Cheap enough
## to call on every rip.
func refresh() -> void:
	if _buy_button == null:
		return
	var for_sale: bool = CalendarTier.has_upgrade(GameState.tier_index)
	_buy_button.visible = for_sale
	if for_sale:
		var affordable: bool = GameState.can_afford_upgrade()
		var shortfall: int = GameState.next_tier_cost() - GameState.points
		_buy_button.disabled = not affordable
		if affordable:
			_buy_button.text = "BUY IT"
		else:
			_buy_button.text = (
				"%d MORE POINT%s NEEDED" % [shortfall, "" if shortfall == 1 else "S"]
			)
	queue_redraw()


## True when `local_point` is on the buy button and the button can take it.
## The pager asks before claiming a contact; a disabled button claims nothing,
## so the store can still be swiped away from when there is nothing to buy.
func swallows_contact(local_point: Vector2) -> bool:
	if _buy_button == null or not _buy_button.visible or _buy_button.disabled:
		return false
	return _buy_button.get_rect().has_point(local_point)


func _on_buy_button_pressed() -> void:
	if not GameState.buy_upgrade():
		return
	purchased.emit(GameState.tier_index)
	refresh()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Palette.WALL, true)
	draw_string(
		font,
		Vector2(MARGIN, TITLE_BASELINE),
		"STORE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		34,
		Palette.INK
	)
	draw_line(
		Vector2(MARGIN, TITLE_BASELINE + 22.0),
		Vector2(size.x - MARGIN, TITLE_BASELINE + 22.0),
		Palette.INK,
		2.0
	)

	if not CalendarTier.has_upgrade(GameState.tier_index):
		_draw_sold_out(font)
		return
	_draw_offer(font)
	_draw_balance(font, BALANCE_BASELINE)


## What the store looks like once the yearly calendar is on the wall. There is
## nothing above it, and saying so is better than an empty panel.
func _draw_sold_out(font: Font) -> void:
	_draw_card(CARD_RECT)
	_centred(font, "THE YEARLY CALENDAR", CARD_RECT.position.y + 150.0, 26, Palette.INK)
	_centred(font, "IS ALREADY ON THE WALL", CARD_RECT.position.y + 186.0, 26, Palette.INK)
	_centred(font, "one rip, one whole year", CARD_RECT.position.y + 236.0, 16, Palette.MUTED)
	_draw_balance(font, SOLD_OUT_BALANCE_BASELINE)


## The next calendar up, and what it costs.
func _draw_offer(font: Font) -> void:
	var next_tier: int = GameState.tier_index + 1
	_draw_card(CARD_RECT)

	_centred(font, "NEXT CALENDAR", CARD_RECT.position.y + 44.0, 14, Palette.MUTED)
	Lettering.draw_centred(
		self,
		font,
		0.0,
		size.x,
		CARD_RECT.position.y + 96.0,
		CalendarTier.tier_name(next_tier).to_upper(),
		40,
		Palette.INK,
		Lettering.WEIGHT_BOLD
	)
	_centred(
		font,
		"one rip = one %s" % CalendarTier.unit_name(next_tier).to_lower(),
		CARD_RECT.position.y + 138.0,
		17,
		Palette.MUTED
	)
	draw_line(
		Vector2(CARD_RECT.position.x + 40.0, CARD_RECT.position.y + 178.0),
		Vector2(CARD_RECT.end.x - 40.0, CARD_RECT.position.y + 178.0),
		Palette.RULE,
		1.0
	)
	_centred(
		font,
		(
			"%d RIPS PER YEAR, DOWN FROM %d"
			% [
				CalendarTier.taps_per_year(next_tier),
				CalendarTier.taps_per_year(GameState.tier_index),
			]
		),
		CARD_RECT.position.y + 208.0,
		15,
		Palette.INK
	)
	_centred(
		font,
		"about %s years of ripping away" % DayCounter.with_separators(_years_to_afford()),
		CARD_RECT.position.y + 238.0,
		14,
		Palette.MUTED
	)
	_centred(font, "COST", CARD_RECT.position.y + 278.0, 14, Palette.MUTED)
	# The price is points, so it wears the points colour. At 34 with weight
	# behind it the accent carries on paper, which it would not at body size.
	(
		Lettering
		. draw_centred(
			self,
			font,
			0.0,
			size.x,
			CARD_RECT.position.y + 326.0,
			(
				"%s POINT%s"
				% [
					DayCounter.with_separators(GameState.next_tier_cost()),
					"" if GameState.next_tier_cost() == 1 else "S",
				]
			),
			34,
			Palette.ACCENT,
			Lettering.WEIGHT_HEAVY
		)
	)


## How many in-game years the price is worth, since a year is eight points on
## every calendar. It is the honest unit for the cost — the store is really
## selling time.
func _years_to_afford() -> int:
	return GameState.next_tier_cost() / HolidayData.HOLIDAY_COUNT


## The running total, repeated where the price is, so the gate and the balance
## it is checked against read in one glance.
func _draw_balance(font: Font, baseline: float) -> void:
	Lettering.draw_centred(
		self,
		font,
		0.0,
		size.x,
		baseline,
		(
			"YOU HAVE %s POINT%s"
			% [DayCounter.with_separators(GameState.points), "" if GameState.points == 1 else "S"]
		),
		19,
		Palette.MUTED,
		Lettering.WEIGHT_BOLD
	)


func _draw_card(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(5.0, 5.0), rect.size), Palette.SHADOW, true)
	draw_rect(rect, Palette.PAPER, true)
	draw_rect(rect, Palette.INK, false, 2.0)


func _centred(font: Font, text: String, baseline: float, font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(
		font,
		Vector2((size.x - width) * 0.5, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)
