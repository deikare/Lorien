extends Node2D
class_name TextStroke

# -------------------------------------------------------------------------------
const COLLIDER_NODE_NAME := "TextCollider"
const GROUP_ONSCREEN := "onscreen_stroke"

const MAX_VECTOR2 := Vector2(2147483647, 2147483647)
const MIN_VECTOR2 := -MAX_VECTOR2

# -------------------------------------------------------------------------------
@export var text: String = ""
@export var font: Font
@export var size: float = 24.0
@export var color: Color = Color.BLACK

var top_left_pos: Vector2 = Vector2.ZERO
var bottom_right_pos: Vector2 = Vector2.ZERO

@onready var _visibility_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var _label: Label = $Label

# -------------------------------------------------------------------------------
func _ready() -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", int(size))

	_visibility_notifier.screen_entered.connect(func(): add_to_group(GROUP_ONSCREEN))
	_visibility_notifier.screen_exited.connect(func(): remove_from_group(GROUP_ONSCREEN))

	refresh()

# -------------------------------------------------------------------------------
func set_text(t: String) -> void:
	text = t
	_label.text = text
	refresh()

func set_color(c: Color) -> void:
	color = c
	_label.add_theme_color_override("font_color", color)

# -------------------------------------------------------------------------------
func refresh() -> void:
	# Update Label overrides
	_label.text = text
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", int(size))
	_label.add_theme_color_override("font_color", color)
	_label.reset_size()

	# Compute bounding box
	var rect := _label.get_combined_minimum_size()

	top_left_pos = position
	bottom_right_pos = position + rect

	_visibility_notifier.rect = Rect2(Vector2.ZERO, rect)

# -------------------------------------------------------------------------------
func enable_collider(enable: bool) -> void:
	var body: StaticBody2D = get_node_or_null(COLLIDER_NODE_NAME)
	if body:
		remove_child(body)
		body.queue_free()

	if enable:
		body = StaticBody2D.new()
		body.name = COLLIDER_NODE_NAME
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = _label.get_combined_minimum_size()
		col.shape = shape
		body.add_child(col)
		add_child(body)

# -------------------------------------------------------------------------------
func clear() -> void:
	text = ""
	_label.text = ""
	refresh()
