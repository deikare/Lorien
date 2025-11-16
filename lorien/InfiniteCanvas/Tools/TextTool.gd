class_name TextTool
extends CanvasTool


@export var font: Font
@export var default_size: float = 24.0

var _editor: TextEdit = null
var _start_pos: Vector2 = Vector2.ZERO
var _editing_stroke: TextStroke = null

func _ready() -> void:
	# parent is InfiniteCanvas in your scene organization
	_canvas = get_parent()

	# Create an overlay TextEdit; parent it under the tool so it appears in scene
	_editor = TextEdit.new()
	_editor.name = "TextToolEditor"
	_editor.visible = false
	_editor.custom_minimum_size = Vector2(300, 120)
	_editor.placeholder_text = "Type text. Ctrl/Cmd+Enter to commit, Esc to cancel."
	_editor.wrap_mode = 1
	#_editor.vertical = true
	_editor.set_meta("is_text_tool_editor", true)
	add_child(_editor)

	# catch keys inside editor
	_editor.connect("gui_input", Callable(self, "_on_editor_gui_input"))
	# optional: commit on focus lost
	_editor.connect("focus_exited", Callable(self, "_on_editor_focus_exited"))

func tool_event(event: InputEvent) -> void:
	# Start new text on left click press
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# world / canvas position for stroke storage
		_start_pos = _canvas._camera.to_local(_canvas._viewport.get_mouse_position()) if _canvas else get_viewport().get_mouse_position()

		# If double click, attempt to edit existing text stroke
		if event.doubleclick:
			var hit := _find_text_stroke_at_global(_canvas._viewport.get_mouse_position())
			if hit:
				_edit_existing_text(hit)
				return

		# otherwise open editor to create new
		_open_editor_at(_canvas._viewport.get_mouse_position())
		return

	# allow Escape while tool active to close editor
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_editor(true)

func _open_editor_at(global_pos: Vector2) -> void:
	if not _canvas:
		return

	_close_editor(true) # close existing editor if any

	_editor.visible = true
	_editor.text = ""
	_editor.resize(_editor.rect_min_size)

	# Place editor in global coordinates on top of viewport
	# For SubViewportContainer, global coordinates of viewport mouse should work
	_editor.global_position = global_pos
	_editor.grab_focus()
	_editing_stroke = null

func _edit_existing_text(stroke: TextStroke) -> void:
	# Open editor prefilled with stroke text
	_editing_stroke = stroke
	_editor.visible = true
	_editor.text = stroke.text
	_editor.resize(_editor.rect_min_size)
	# place near stroke (use stroke global position)
	_editor.global_position = stroke.get_global_transform().origin
	_editor.grab_focus()

func _close_editor(cancel: bool = false) -> void:
	if _editor and _editor.visible:
		_editor.visible = false
		_editor.text = ""
		_editing_stroke = null

func _on_editor_gui_input(ev: InputEvent) -> void:
	# Ctrl/Cmd  Enter to commit
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ENTER and (ev.control or ev.meta):
		_commit_editor()
	# Esc handled in tool_event as well

func _on_editor_focus_exited() -> void:
	# commit on focus lost
	_commit_editor()

func _commit_editor() -> void:
	if not _editor or not _editor.visible:
		return
	var t := _editor.text.strip_edges(true, true)
	if t == "":
		_close_editor(true)
		return

	# If editing existing stroke, create undo action to change text
	if _editing_stroke != null and is_instance_valid(_editing_stroke):
		var old_text := _editing_stroke.text
		_canvas._current_project.undo_redo.create_action("Edit Text")
		_canvas._current_project.undo_redo.add_do_method(_editing_stroke.set_text.bind(t))
		_canvas._current_project.undo_redo.add_undo_method(_editing_stroke.set_text.bind(old_text))
		_canvas._current_project.undo_redo.add_undo_reference(_editing_stroke)
		_canvas._current_project.undo_redo.commit_action()
		_editing_stroke.set_text(t)
		_close_editor(false)
		return

	# Create new TextStroke node
	var stroke := preload("res://TextStroke/TextStroke.tscn").instantiate()
	if stroke:
		stroke.text = t
		if font:
			stroke.font = font
		stroke.size = default_size
		stroke.color = _canvas._brush_color if _canvas != null else Color.BLACK
		# position in canvas local coords: convert viewport mouse to camera world
		var world_pos := _canvas._camera.get_global_transform().affine_inverse().basis_xform(_canvas._viewport.get_mouse_position())
		# Alternatively use to_local of canvas node
		stroke.position = world_pos

		# Add via undo-redo similar to add_strokes/add_stroke pattern
		_canvas._current_project.undo_redo.create_action("Text")
		_canvas._current_project.undo_redo.add_undo_method(_canvas.undo_last_stroke)
		_canvas._current_project.undo_redo.add_undo_reference(stroke)
		_canvas._current_project.undo_redo.add_do_method(_canvas._strokes_parent.add_child.bind(stroke))
		_canvas._current_project.undo_redo.add_do_property(_canvas.info, "stroke_count", _canvas.info.stroke_count + 1)
		_canvas._current_project.undo_redo.add_do_property(_canvas.info, "point_count", _canvas.info.point_count + 1)
		_canvas._current_project.undo_redo.add_do_method(_canvas._current_project.add_stroke.bind(stroke))
		_canvas._current_project.undo_redo.commit_action()

	_close_editor(false)

func _find_text_stroke_at_global(global_pos: Vector2) -> TextStroke:
	# iterate strokes child nodes and return first text stroke that contains the point
	if not _canvas:
		return null
	for child in _canvas._strokes_parent.get_children():
		if child is TextStroke:
			if child.contains_global_point(global_pos):
				return child
	return null
