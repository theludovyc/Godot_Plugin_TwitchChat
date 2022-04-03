tool
extends EditorPlugin

var dock

func _enter_tree():
	add_custom_type("Gift", "Node", preload("res://addons/TwitchChat/gift_node.gd"), preload("res://addons/TwitchChat/icon.png"))

	# Initialization of the plugin goes here.
	# Load the dock scene and instance it.
	dock = preload("res://addons/TwitchChat/ChatDock/ChatDock.tscn").instance()

	# Add the loaded scene to the docks.
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	# Note that LEFT_UL means the left of the editor, upper-left dock.
	
	pass


func _exit_tree():
	# Clean-up of the plugin goes here.
	# Remove the dock.
	remove_control_from_docks(dock)
	# Erase the control from the memory.
	dock.free()
	
	remove_custom_type("Gift")
	
	pass
