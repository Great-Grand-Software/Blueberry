class_name TapGrid
extends RefCounted

## Pure hit-testing for a square grid of cells.
##
## Deliberately has no Node in it, so the maths can be unit-tested without
## instantiating a scene. Keep new gameplay logic testable the same way — a
## test that has to spin up a scene is slow and tends to get deleted.

## Cells per row and per column.
const COLUMNS: int = 5
const ROWS: int = 5

var _size: float


func _init(pixel_size: float) -> void:
	_size = maxf(pixel_size, 1.0)


## Width and height of one cell, in pixels.
func cell_size() -> float:
	return _size / float(COLUMNS)


## Index of the cell containing [param point], or -1 if it falls outside.
## Indices run left to right, then top to bottom, starting at 0.
func cell_at(point: Vector2) -> int:
	if point.x < 0.0 or point.y < 0.0 or point.x >= _size or point.y >= _size:
		return -1
	var column: int = int(point.x / cell_size())
	var row: int = int(point.y / cell_size())
	return row * COLUMNS + column


## Top-left corner of [param index], in pixels. Zero for an invalid index.
func cell_origin(index: int) -> Vector2:
	if index < 0 or index >= cell_count():
		return Vector2.ZERO
	var column: int = index % COLUMNS
	var row: int = index / COLUMNS
	return Vector2(float(column), float(row)) * cell_size()


## Total number of cells. Bounded by named constants, never by data length.
func cell_count() -> int:
	return COLUMNS * ROWS
