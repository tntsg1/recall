class_name Grip
extends RefCounted
# What a leech hands the bullets: where its stolen rounds circle, and whether
# it still holds them.

var e
var alive := true


func _init(owner) -> void:
	e = owner


func holds() -> bool:
	return alive and e.state != Enemies.DEAD


func hold_center() -> Vector2:
	return e.pos


func hold_radius() -> float:
	return e.r + 11.0
