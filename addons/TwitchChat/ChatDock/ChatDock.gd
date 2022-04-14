tool
extends Control

# The underlying websocket sucessfully connected to twitch.
signal twitch_connected
# The connection has been closed. Not emitted if twitch announced a reconnect.
signal twitch_disconnected
# The connection to twitch failed.
signal twitch_unavailable
# Twitch requested the client to reconnect. (Will be unavailable until next connect)
signal twitch_reconnect
# The client tried to login. Returns true if successful, else false.
signal login_attempt(success)
# User sent a message in chat.
signal chat_message(sender_data, message)
# User sent a whisper message.
signal whisper_message(sender_data, message)
# Unhandled data passed through
signal unhandled_message(message, tags)

signal join_message(user_name)

signal part_message()
# A command has been called with invalid arg count
signal cmd_invalid_argcount(cmd_name, sender_data, cmd_data, arg_ary)
# A command has been called with insufficient permissions
signal cmd_no_permission(cmd_name, sender_data, cmd_data, arg_ary)
# Twitch's ping is about to be answered with a pong.
signal pong
# Emote has been downloaded
signal emote_downloaded(emote_id)
# Badge has been downloaded
signal badge_downloaded(badge_name)

export(int) var chat_timeout_ms = 320

var base_name:String

var viewers := 0

var websocket := WebSocketClient.new()

var user_regex := RegEx.new()

var twitch_restarting:bool

# Mapping of channels to their channel info, like available badges.
var channels : Dictionary = {}

# Twitch disconnects connected clients if too many chat messages are being sent. (At about 100 messages/30s)
var chat_queue = []

var last_msg = OS.get_ticks_msec()

func _init():
	websocket.verify_ssl = true
	user_regex.compile("(?<=!)[\\w]*(?=@)")

func connect_to_twitch() -> void:
	if(websocket.connect_to_url("wss://irc-ws.chat.twitch.tv:443") != OK):
		print_debug("Could not connect to Twitch.")
		emit_signal("twitch_unavailable")

func handle_send(message : String):
	if message == "PONG :tmi.twitch.tv":
		return
	else:
		print("< " + message)

# Sends a String to Twitch.
func send(text : String, token : bool = false) -> void:
	websocket.get_peer(1).put_packet(text.to_utf8())
	if(OS.is_debug_build()):
		if(!token):
			handle_send(text.strip_edges(false))
		else:
			print("< PASS oauth:******************************")

func request_caps(caps : String = "twitch.tv/commands twitch.tv/tags twitch.tv/membership") -> void:
	send("CAP REQ :" + caps)

func authenticate_oauth(nick : String, token : String) -> void:
	websocket.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	send("PASS " + ("" if token.begins_with("oauth:") else "oauth:") + token, true)
	send("NICK " + nick.to_lower())
	request_caps()

onready var chat = $ChatContainer

func _ready():
	base_name = "TwitchChat"
	
	websocket.connect("data_received", self, "_on_websocket_data_received")
	websocket.connect("connection_established", self, "_on_websocket_connection_established")
	websocket.connect("connection_closed", self, "_on_websocket_connection_closed")
	websocket.connect("connection_error", self, "_on_websocket_connection_error")
	
	# I use a file in the working directory to store auth data
	# so that I don't accidentally push it to the repository.
	# Replace this or create a auth file with 3 lines in your
	# project directory:
	# <bot username>
	# <oauth token>
	# <initial channel>
	var authfile := File.new()
	authfile.open("res://addons/TwitchChat/auth.txt", File.READ)
	var botname := authfile.get_line()
	var token := authfile.get_line()
	var initial_channel = authfile.get_line()
	
	connect_to_twitch()
	yield(self, "twitch_connected")
	
	# Login using your username and an oauth token.
	# You will have to either get a oauth token yourself or use
	# https://twitchapps.com/tokengen/
	# to generate a token with custom scopes.
	authenticate_oauth(botname, token)
	if(yield(self, "login_attempt") == false):
	  print("Invalid username or token.")
	  return
	
	join_channel(initial_channel)

	connect("chat_message", self, "_on_chat_message")
	connect("whisper_message", self, "_on_chat_message")
	connect("join_message", self, "_on_join_message")
	connect("part_message", self, "_on_part_message")

func _process(delta : float) -> void:
	if(websocket.get_connection_status() != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED):
		websocket.poll()
		if (!chat_queue.empty() && (last_msg + chat_timeout_ms) <= OS.get_ticks_msec()):
			send(chat_queue.pop_front())
			last_msg = OS.get_ticks_msec()

func handle_message(message : String, tags : Dictionary) -> void:
	if(message == ":tmi.twitch.tv NOTICE * :Login authentication failed"):
		print_debug("Authentication failed.")
		emit_signal("login_attempt", false)
		return
		
	if(message == "PING :tmi.twitch.tv"):
		send("PONG :tmi.twitch.tv")
		emit_signal("pong")
		return
		
	var msg : PoolStringArray = message.split(" ", true, 3)
	
	match msg[1]:
		"001":
			print_debug("Authentication successful.")
			emit_signal("login_attempt", true)
		"PRIVMSG":
			var sender_data : SenderData = SenderData.new(user_regex.search(msg[0]).get_string(), msg[2], tags)
#			handle_command(sender_data, msg[3].split(" ", true, 1))
			emit_signal("chat_message", sender_data, msg[3].right(1))
		"WHISPER":
			print("> " + message)
			var sender_data : SenderData = SenderData.new(user_regex.search(msg[0]).get_string(), msg[2], tags)
#			handle_command(sender_data, msg[3].split(" ", true, 1), true)
			emit_signal("whisper_message", sender_data, msg[3].right(1))
		"RECONNECT":
			twitch_restarting = true
		"JOIN":
			emit_signal("join_message", msg[0].left(msg[0].find('!')).right(1))
		"PART":
			emit_signal("part_message")
		_:
			print("> " + message)
			emit_signal("unhandled_message", message, tags)

func _on_websocket_data_received() -> void:
	var messages : PoolStringArray = websocket.get_peer(1).get_packet().get_string_from_utf8().strip_edges(false).split("\r\n")
	var tags = {}
	for message in messages:
		if(message.begins_with("@")):
			var msg : PoolStringArray = message.split(" ", false, 1)
			message = msg[1]
			for tag in msg[0].split(";"):
				var pair = tag.split("=")
				tags[pair[0]] = pair[1]
		handle_message(message, tags)

func _on_websocket_connection_established(protocol : String) -> void:
	print_debug("Connected to Twitch.")
	emit_signal("twitch_connected")

func join_channel(channel : String) -> void:
	var lower_channel : String = channel.to_lower()
	send("JOIN #" + lower_channel)
	channels[lower_channel] = {}

func _on_websocket_connection_closed(was_clean_close : bool) -> void:
	if(twitch_restarting):
		print_debug("Reconnecting to Twitch")
		emit_signal("twitch_reconnect")
		connect_to_twitch()
		yield(self, "twitch_connected")
		for channel in channels.keys():
			join_channel(channel)
		twitch_restarting = false
	else:
		print_debug("Disconnected from Twitch.")
		emit_signal("twitch_disconnected")

func _on_websocket_connection_error() -> void:
	print_debug("Twitch is unavailable.")
	emit_signal("twitch_unavailable")

func _on_chat_message(data : SenderData, msg : String) -> void:
	chat.put_chat(data, msg)

func _on_join_message(user_name:String):
	viewers += 1
	
	name = base_name + "(" + str(viewers) + ")"
	
	chat.put_join(user_name)

func _on_part_message():
	viewers -= 1
	
	name = base_name + "(" + str(viewers) + ")"
