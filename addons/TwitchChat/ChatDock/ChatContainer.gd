tool
extends VBoxContainer

onready var scroll_container = $Chat/ScrollContainer

var MsgNode = preload("res://addons/TwitchChat/ChatDock/ChatMessage.tscn")

var to_bottom := false

var i := 0

func _ready():
	var scrollbar = scroll_container.get_v_scrollbar()
	
	scrollbar.connect("changed", self, "scroll_reset")

func on_value_changed(value):
	prints("ChatContainer", "on_value_changed", value)

func get_time() -> String:
	var time = OS.get_time()
	
	return str(time["hour"]) + ":" + ("0" + str(time["minute"]) if time["minute"] < 10 else str(time["minute"]))

func put_chat(senderdata : SenderData, msg : String):
	var msgnode : Control = MsgNode.instance()
	var badges : String = ""
#	if ($"../Gift".image_cache):
#		for badge in senderdata.tags["badges"].split(",", false):
#			badges += "[img=center]" + $"../Gift".image_cache.get_badge(badge, senderdata.tags["room-id"]).resource_path + "[/img] "
#		var locations : Array = []
#		for emote in senderdata.tags["emotes"].split("/", false):
#			var data : Array = emote.split(":")
#			for d in data[1].split(","):
#				var start_end = d.split("-")
#				locations.append(EmoteLocation.new(data[0], int(start_end[0]), int(start_end[1])))
#		locations.sort_custom(EmoteLocation, "smaller")
#		var offset = 0
#		for loc in locations:
#			var emote_string = "[img=center]" + $"../Gift".image_cache.get_emote(loc.id).resource_path +"[/img]"
#			msg = msg.substr(0, loc.start + offset) + emote_string + msg.substr(loc.end + offset + 1)
#			offset += emote_string.length() + loc.start - loc.end - 1
	
	var scrollbar = scroll_container.get_v_scrollbar()
	
	to_bottom = scrollbar.value + scrollbar.page >= scrollbar.max_value
	
	$Chat/ScrollContainer/ChatMessagesContainer.add_child(msgnode)
	
	msgnode.set_msg(get_time(), senderdata, msg, badges)

func scroll_reset():
	if to_bottom:
		scroll_container.scroll_vertical = scroll_container.get_v_scrollbar().max_value
		to_bottom = false

func put_join(user_name:String):
	var msgnode : Control = MsgNode.instance()
	
	var scrollbar = scroll_container.get_v_scrollbar()
	
	to_bottom = scrollbar.value + scrollbar.page >= scrollbar.max_value
	
	$Chat/ScrollContainer/ChatMessagesContainer.add_child(msgnode)
	
	msgnode.set_join(get_time(), user_name)
	
class EmoteLocation extends Reference:
	var id : String
	var start : int
	var end : int

	func _init(emote_id, start_idx, end_idx):
		self.id = emote_id
		self.start = start_idx
		self.end = end_idx

	static func smaller(a : EmoteLocation, b : EmoteLocation):
		return a.start < b.start
