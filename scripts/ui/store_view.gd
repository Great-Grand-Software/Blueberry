class_name StoreView
extends Control
## The store: one calendar for sale at a time, the next one up.
##
## The buy control is drawn and hit-tested here rather than being a `Button`,
## because every contact in this half of the screen has to pass through the
## pager first so it can tell a tap from a swipe. One owner for the finger
## means a swipe that starts on the buy panel scrolls instead of buying.

signal purchased(tier_index: int)

const WALL: Color = Color(0.929, 0.925, 0.914)
const INK: Color = Color(0.106, 0.106, 0.106)
const PAPER: Color = Color(0.965, 0.961, 0.949)
const MUTED: Color = Color(0.545, 0.541, 0.529)
const RULE: Color = Color(0.788, 0.784, 0.773)
const SHADOW: Color = Color(0, 0, 0, 0.16)

const MARGIN: float = 64.0
const TITLE_BASELINE: float = 96.0
const CARD_RECT: Rect2 = Rect2(64.0, 168.0, 592.0, 372.0)
const BUY_RECT: Rect2 = Rect2(112.0, 596.0, 496.0, 92.0)
## Baseline of the running total, repeated under whatever the store is showing:
## under the buy panel when there is one, under the card when there is not.
const BALANCE_BASELINE: float = 754.0
const SOLD_OUT_BALANCE_BASELINE: float = 618.0


## Repaints from GameState. Cheap enough to call on every rip.
func refresh() -> void:
	queue_redraw()


## Routes one tap from the pager. Buys only if the tap lands on the buy panel
## and the points are already in hand; the affordability check is GameState's.
func handle_tap(local_point: Vector2) -> void:
	if not BUY_RECT.has_point(local_point):
		return
	if not GameState.can_afford_upgrade():
		return
	if GameState.buy_upgrade():
		purchased.emit(GameState.tier_index)
		queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), WALL, true)
	draw_string(
		font, Vector2(MARGIN, TITLE_BASELINE), "STORE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, INK
	)
	draw_line(
		Vector2(MARGIN, TITLE_BASELINE + 22.0),
		Vector2(size.x - MARGIN, TITLE_BASELINE + 22.0),
		INK,
		2.0
	)

	if not CalendarTier.has_upgrade(GameState.tier_index):
		_draw_sold_out(font)
		return
	_draw_offer(font)
	_draw_buy_panel(font)


## What the store looks like once the yearly calendar is on the wall. There is
## nothing above it, and saying so is better than an empty panel.
func _draw_sold_out(font: Font) -> void:
	_draw_card(CARD_RECT)
	_centred(font, "THE YEARLY CALENDAR", CARD_RECT.position.y + 150.0, 26, INK)
	_centred(font, "IS ALREADY ON THE WALL", CARD_RECT.position.y + 186.0, 26, INK)
	_centred(font, "one rip, one whole year", CARD_RECT.position.y + 236.0, 16, MUTED)
	_draw_balance(font, SOLD_OUT_BALANCE_BASELINE)


## The next calendar up, and what it costs.
func _draw_offer(font: Font) -> void:
	var next_tier: int = GameState.tier_index + 1
	var cost: int = GameState.next_tier_cost()
	_draw_card(CARD_RECT)

	_centred(font, "NEXT CALENDAR", CARD_RECT.position.y + 44.0, 14, MUTED)
	_centred(
		font, CalendarTier.tier_name(next_tier).to_upper(), CARD_RECT.position.y + 96.0, 40, INK
	)
	_centred(
		font,
		"one rip = one %s" % CalendarTier.unit_name(next_tier).to_lower(),
		CARD_RECT.position.y + 138.0,
		17,
		MUTED
	)
	draw_line(
		Vector2(CARD_RECT.position.x + 40.0, CARD_RECT.position.y + 178.0),
		Vector2(CARD_RECT.end.x - 40.0, CARD_RECT.position.y + 178.0),
		RULE,
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
		CARD_RECT.position.y + 214.0,
		15,
		INK
	)
	_centred(font, "COST", CARD_RECT.position.y + 278.0, 14, MUTED)
	_centred(font, "%d POINTS" % cost, CARD_RECT.position.y + 324.0, 32, INK)


## The buy panel. Filled when it can be bought, outlined when it cannot, with
## the shortfall spelled out so the gate never looks like a broken button.
func _draw_buy_panel(font: Font) -> void:
	var affordable: bool = GameState.can_afford_upgrade()
	var shortfall: int = GameState.next_tier_cost() - GameState.points

	if affordable:
		draw_rect(Rect2(BUY_RECT.position + Vector2(4.0, 4.0), BUY_RECT.size), SHADOW, true)
		draw_rect(BUY_RECT, INK, true)
		_centred(font, "BUY IT", BUY_RECT.position.y + 58.0, 28, PAPER)
	else:
		draw_rect(BUY_RECT, RULE, false, 2.0)
		_centred(
			font,
			"%d MORE POINT%s NEEDED" % [shortfall, "" if shortfall == 1 else "S"],
			BUY_RECT.position.y + 56.0,
			20,
			MUTED
		)
	_draw_balance(font, BALANCE_BASELINE)


## The running total, repeated where the price is, so the gate and the balance
## it is checked against read in one glance.
func _draw_balance(font: Font, baseline: float) -> void:
	_centred(
		font,
		"YOU HAVE %d POINT%s" % [GameState.points, "" if GameState.points == 1 else "S"],
		baseline,
		18,
		MUTED
	)


func _draw_card(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(5.0, 5.0), rect.size), SHADOW, true)
	draw_rect(rect, PAPER, true)
	draw_rect(rect, INK, false, 2.0)


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
