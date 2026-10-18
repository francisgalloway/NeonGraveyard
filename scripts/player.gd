class_name Player
extends Node2D
## Placeholder player (Leo): a simple figure drawn in code, walks along a list of points.

signal arrived

const SPEED := 200.0

var path: Array[Vector2] = []


func walk(points: Array[Vector2]) -> void:
	path = points


func stop() -> void:
	path.clear()


func is_walking() -> bool:
	return not path.is_empty()


func _process(delta: float) -> void:
	if path.is_empty():
		return
	position = position.move_toward(path[0], SPEED * delta)
	if position.is_equal_approx(path[0]):
		path.remove_at(0)
		if path.is_empty():
			arrived.emit()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-9, -46, 18, 38), Color("#d8d2b8"))
	draw_circle(Vector2(0, -56), 10.0, Color("#d8d2b8"))
	draw_rect(Rect2(-9, -34, 18, 4), Color("#ff4fa3"))
