extends Node2D

@onready var POSITION_LABEL : Label = $EditorUI/SettingUI/VFlowContainer/Label
@onready var MOUSE_POSITION_LABEL : Label = $EditorUI/SettingUI/VFlowContainer/Label2
@onready var FPS_LABEL : Label = $EditorUI/SettingUI/VFlowContainer/Label3

@onready var LIVECODE_SHOW_BUTTON : CheckBox = $EditorUI/SettingUI/VBoxContainer/LiveCode
@onready var SCHEMATIC_PANEL : PanelContainer = $EditorUI/SchematicPanel
@onready var LIVECODE_PANEL : PanelContainer = $EditorUI/LiveCodePanel 

@onready var SCHEMATIC_CONTAINER  = $EditorUI/SchematicPanel/VBoxContainer/PanelContainer

@onready var SETTING_UI = $EditorUI/SettingUI

var instruction_dic : Dictionary = {}
var instruction_ins : Array= []

func _process(_delta):
	POSITION_LABEL.text = "Postion:" + str($Camera2D.global_position)
	MOUSE_POSITION_LABEL.text =  "Mouse Position:" + str(get_global_mouse_position())
	FPS_LABEL.text = "  FPS:"  + str(Engine.get_frames_per_second()) 
	
func _draw():
	draw_line(Vector2(10000,0), Vector2(-10000,0), Color.GREEN)
	draw_line(Vector2(0,10000), Vector2(0,-10000), Color.GREEN)

func _ready():
	Config.on_content_change.connect(update_live_code.bind())
	get_viewport().size_changed.connect(resize.bind())
	resize()
	LIVECODE_SHOW_BUTTON.toggled.connect(show_live_code.bind())
	
	show_live_code(false)
	show_schematic(true)
	
	
	var directory = ["res://scene/instruction/BlockControl",
	"res://scene/instruction/FlowControl",
	"res://scene/instruction/InputOutput",
	"res://scene/instruction/Operation",
	"res://scene/instruction/UnitControl"]
	
	for path in directory:
		var dir =  DirAccess.open(path)
		dir.list_dir_begin()

		while true:
			var file = dir.get_next()
			if file == "":
				break
			elif not file.begins_with(".") and file.ends_with(".gd"):
				instruction_dic[file.replace(".gd", "").replace("Instruction", "")] = path + "/" + file
				
		dir.list_dir_end()
	
	
	var start = Vector2(Config.IO_CIRCLE_RADIUS * 2, 0)
	
	for ins_name in instruction_dic.keys():
		var ins : Instruction = load(instruction_dic[ins_name]).new(ins_name)
		instruction_ins.append(ins)
		ins.global_position = start
		ins.on_content_change.connect(update_live_code.bind())
		ins.add_to_group("SchematicPreview")
		ins.name = ins_name
		ins.instruction_name = ins_name
		ins.scale = Vector2(Config.EDITOR_SCHEMATIC_SCALE,Config.EDITOR_SCHEMATIC_SCALE)
		SCHEMATIC_CONTAINER.call_deferred("add_child", ins)
		await ins.on_ready
		ins.set_disable(true)
		start.y += (ins.get_size().y + Config.COMPONENT_SPACE_Y) * Config.EDITOR_SCHEMATIC_SCALE
		
func resize():
	var view : Rect2 = get_viewport_rect()
	SETTING_UI.position = Vector2.ZERO
	SETTING_UI.size = Vector2(view.size.x, Config.TOOL_BAR_HEIGHT)
	
	LIVECODE_PANEL.position = Vector2(view.size.x - LIVECODE_PANEL.size.x, 0)
	LIVECODE_PANEL.size.y = view.size.y
	
	SCHEMATIC_PANEL.position = Vector2(0, SETTING_UI.size.y)
	SCHEMATIC_PANEL.size.y =  view.size.y - SETTING_UI.size.y
	
	
func show_live_code(value : bool):
	LIVECODE_PANEL.visible = value
	
func show_schematic(value : bool):
	SCHEMATIC_PANEL.visible = value
	
func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				on_click(get_global_mouse_position())
			if event.button_index == MOUSE_BUTTON_RIGHT:
				on_delete(get_global_mouse_position())
		else:
			on_release(get_global_mouse_position())
			#Zoom
			
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			on_zoom(Config.zoom / Config.ZOOM_FACTOR)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			on_zoom(Config.zoom * Config.ZOOM_FACTOR)

	elif event is InputEventMouseMotion:
		on_drag(event.relative, get_global_mouse_position())

func on_delete(delete_position : Vector2) -> void:
	# Delete instruction
	var obj = Config.get_node_at_position("Instruction", delete_position)
	if obj:
		obj.delete()

func on_zoom(zoom_value : float) -> void:
	Config.current_camera = get_viewport().get_camera_2d()
	if Config.current_camera != null:
		Config.zoom = clamp(zoom_value, Config.MIN_ZOOM,  Config.MAX_ZOOM)
		Config.current_camera.zoom = Vector2(1/Config.zoom, 1/Config.zoom)
				

func on_drag(drag_relative : Vector2, drag_position : Vector2) -> void:
	if LIVECODE_PANEL.on_drag():
		return
	if SCHEMATIC_PANEL.on_drag():
		return
	
	if Config.is_scrolling:
		var front = instruction_ins.front()
		var back = instruction_ins.back()
		var screen_size = get_viewport_rect().size
		if front == null or back == null:
			return 
		if front.global_position.y + drag_relative.y + Config.COMPONENT_SPACE_Y < 0:
			if drag_relative.y > 0:
				for i in instruction_ins:
					i.position.y += drag_relative.y
				
		if back.global_position.y + back.get_size().y + Config.COMPONENT_SPACE_Y + drag_relative.y > screen_size.y:
			if drag_relative.y < 0:
				for i in instruction_ins:
					i.position.y += drag_relative.y

	# Drag instruction
	if Config.drag_focus != null:
		# Drag ouput
		if Config.drag_focus is InstructionOutput:
			Config.drag_focus.on_drag(drag_position)
		else:
			# Drag instruction
			Config.drag_focus.drag(drag_position - Config.drag_offset)
	#Pan move
	else:
		Config.current_camera = get_viewport().get_camera_2d()
		if Config.current_camera != null:
			if Config.is_panning:
				Config.current_camera.position -= drag_relative * Config.zoom
				Config.current_camera.update()

func on_click(click_position : Vector2) -> void:
	
	if LIVECODE_PANEL.on_click():
		return
	if SCHEMATIC_PANEL.on_click():
		return
	#If click on nothing, unfocus keyboard
	if SCHEMATIC_CONTAINER.get_global_rect().has_point(SCHEMATIC_CONTAINER.get_global_mouse_position()):
		Config.drag_focus = get_schematic(click_position)
		if Config.drag_focus:
			var ins : Instruction = load(instruction_dic[Config.drag_focus.instruction_name]).new(Config.drag_focus.instruction_name)
			ins.global_position = get_global_mouse_position()
			ins.on_content_change.connect(update_live_code.bind())
			ins.add_to_group("Instruction")
			ins.add_to_group("Drag")
			call_deferred("add_child", ins)
			Config.drag_focus = ins
			return
			
	if SCHEMATIC_PANEL.get_global_rect().has_point(SCHEMATIC_PANEL.get_global_mouse_position()):
		Config.is_scrolling = true
		return
	
	Config.drag_focus = Config.get_node_at_position("Drag", click_position)
	if Config.drag_focus == null:
		if Config.keyboard_focus != null:
			Config.keyboard_focus.unfocus()
		else:
			Config.is_panning = true
	else:
		Config.drag_offset = click_position - Config.drag_focus.get_global_position()
		return
	
func on_release(release_position : Vector2):
	LIVECODE_PANEL.on_release()
	SCHEMATIC_PANEL.on_release()
	
	if Config.drag_focus is InstructionOutput:
		var target = Config.get_node_at_position("Input", release_position)
			
		if target == null:
			Config.drag_focus.disconnect_instruction()
			Config.drag_focus.reset()
		else:
			Config.drag_focus.connect_instruction(target)
	
	if not Config.drag_focus == null:
		if Config.drag_focus.has_method("drop"):
			Config.drag_focus.drop()
		Config.drag_focus = null
	Config.is_panning = false
	Config.is_scrolling = false


func update_live_code() -> void:
	var start = get_start_instruction()

	if start != null:
		for i in get_tree().get_nodes_in_group("Instruction"):
			i.line = -1
		Config.current_line = -1
		start.set_line()
		var text = ""
		text += "L   Instruction\n"
		var ins_output = start.get_code()
		for i in range(0, ins_output.size()):
			text += str(i) + "   " + ins_output[i] + "\n"
		$EditorUI/LiveCodePanel/Croll/LiveCode.text = text

func get_code() -> void:
	var start : FlowStartInstruction = get_start_instruction()
	
	if start != null:
		for i in get_tree().get_nodes_in_group("Instruction"):
			i.line = -1
		Config.current_line = -1
		start.set_line()
		var text = ""
		var ins_output = start.get_code()
		for i in range(0, ins_output.size()):
			text += ins_output[i] + "\n"
		DisplayServer.clipboard_set(text)

func get_start_instruction() -> FlowStartInstruction:
	var start = get_tree().get_nodes_in_group("Start")
	for s in start:
		if not s.is_in_group("SchematicPreview"):
			return s
	return null

func _on_get_code_button_down() -> void:
	get_code()

func get_schematic(click_position : Vector2) -> Instruction:
	if not SCHEMATIC_PANEL.get_global_rect().has_point(SCHEMATIC_PANEL.get_global_mouse_position()):
		return null
	return Config.get_node_at_position("SchematicPreview", get_viewport_transform() * click_position)
	


func _on_search_box_text_changed(new_text: String) -> void:
	new_text = new_text.to_lower()
	var result : Array = []
	var instruction : Array = get_tree().get_nodes_in_group("SchematicPreview")
	for i in instruction:
		i.hide()
		i.global_position.x = -1000
		if i.instruction_name.to_lower().begins_with(new_text):
			result.append(i)

	if result.size() <= 10:
		for i in instruction:
			if not i.instruction_name.to_lower().contains(new_text):
				continue
			if result.has(i):
				continue
			result.append(i)
	
	instruction_ins = result
	var start = Vector2(Config.IO_CIRCLE_RADIUS * 2, 0)
	for i in instruction_ins:
		i.global_position = start
		i.show()
		start.y += (i.get_size().y + Config.COMPONENT_SPACE_Y) * Config.EDITOR_SCHEMATIC_SCALE 
	
