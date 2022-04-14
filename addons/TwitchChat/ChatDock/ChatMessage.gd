tool
extends HBoxContainer

onready var rtl = $RichTextLabel

func set_msg(stamp : String, user, channel, tags, msg : String, badges : String) -> void:
	rtl.bbcode_text = stamp + " " + badges + "[b][color="+ tags["color"] + "]" + tags["display-name"] +"[/color][/b]: " + msg

func set_join(time:String, user_name:String):
	rtl.bbcode_text = time + " join " + user_name
