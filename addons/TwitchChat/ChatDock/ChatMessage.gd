tool
extends HBoxContainer

onready var rtl = $RichTextLabel

func set_msg(stamp : String, data : SenderData, msg : String, badges : String) -> void:
	rtl.bbcode_text = stamp + " " + badges + "[b][color="+ data.tags["color"] + "]" + data.tags["display-name"] +"[/color][/b]: " + msg

func set_join(time:String, user_name:String):
	rtl.bbcode_text = time + " join " + user_name
