class_name LanHost
extends Node
## Nearby play (Timmy 19 Oct 00:43: "1 sounds like a pretty good soultion to me! I didnt know that worked" - phones on
## the same Wi-Fi or one phone's hotspot, no internet): this phone IS the lobby server. The same rules as the online
## one (LoopLobby - relay/src/index.js), over WebSockets on WS_PORT, the same URLs and messages - so a LobbyNet pointed
## at ws://<this phone>:WS_PORT can't tell the difference (this phone's own LobbyNet joins through 127.0.0.1). Found by
## the others with LanFinder: it answers "standoff?" on ASK_PORT and tells the network about itself every second on
## TELL_PORT.

const WS_PORT := 47270
const ASK_PORT := 47271
const TELL_PORT := 47272

static var active: LanHost        ## the lobby this phone is hosting, if it is
static var bind_to := "*"         ## where it listens (the tests: 127.0.0.1 - no firewall question on the PC)

var code := ""
var server := TCPServer.new()
var ask := PacketPeerUDP.new()    ## "standoff?" in, this lobby out
var tell := PacketPeerUDP.new()   ## this lobby, to everyone, every second
var peers: Array[LanPeer] = []
var _pending: Array = []          ## [WebSocketPeer, since ms] - not open yet
var _since := 1.0
var _ending := 0                  ## (stopping) when it started saying goodbye - the sockets close, then it's gone
var _closing: Array[LanPeer] = []


## A member over the network: what the lobby hands it goes down its socket.
class LanPeer:
	extends LobbyNet
	var sock: WebSocketPeer

	func deliver(d: Dictionary) -> void:
		if sock.get_ready_state() == WebSocketPeer.STATE_OPEN:
			sock.send_text(JSON.stringify(d, "", false, true))


## Start hosting lobby `c`. False = the port's taken (another Standoff hosting on this phone?).
func start(c: String) -> bool:
	code = c
	if server.listen(WS_PORT, bind_to) != OK:
		return false
	ask.bind(ASK_PORT, bind_to)   # (a second host on the same phone can't - it still hosts, just isn't found by asking)
	tell.set_broadcast_enabled(true)
	active = self
	return true


## Stop hosting: everyone's told why and their sockets close properly over the next moment; then this node frees
## itself (an abrupt close can lose the goodbye in flight).
func stop() -> void:
	if active == self:
		active = null
	server.stop()
	ask.close()
	tell.close()
	for p in peers:   # (the goodbye now, the close a moment later: a socket that closes drops what came with the close)
		p.deliver({"t": "bye", "msg": "The host closed the lobby"})
	_closing.append_array(peers)
	peers.clear()
	_pending.clear()
	LoopLobby.lobbies.erase(code)
	_ending = Time.get_ticks_msec()


func _exit_tree() -> void:
	if _ending == 0:
		stop()
	for p in _closing:
		p.free()
	_closing.clear()


## What the others see in their list.
func info() -> Dictionary:
	var l: LoopLobby = LoopLobby.lobbies.get(code)
	return {"standoff": "lan", "code": code, "name": str(l.meta["name"]) if l != null else "",
		"players": l.members.size() if l != null else 0, "max": int(l.meta["max"]) if l != null else 8,
		"version": str(l.meta["version"]) if l != null else Version.TAG, "port": WS_PORT}


func _process(delta: float) -> void:
	poll(delta)


func poll(delta := 0.0) -> void:
	if _ending > 0:   # (saying goodbye)
		var open := false
		var closing := Time.get_ticks_msec() - _ending > 400
		for p in _closing:
			p.sock.poll()
			if closing and p.sock.get_ready_state() == WebSocketPeer.STATE_OPEN:
				p.sock.close(1000, "host left")
			open = open or p.sock.get_ready_state() != WebSocketPeer.STATE_CLOSED
		if not open or Time.get_ticks_msec() - _ending > 2000:
			for p in _closing:
				p.free()
			_closing.clear()
			if is_inside_tree():
				queue_free()
		return
	while server.is_listening() and server.is_connection_available():
		var ws := WebSocketPeer.new()
		if ws.accept_stream(server.take_connection()) == OK:
			_pending.append([ws, Time.get_ticks_msec()])
	for p: Array in _pending.duplicate():
		var ws: WebSocketPeer = p[0]
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			_pending.erase(p)
			_admit(ws)
		elif st == WebSocketPeer.STATE_CLOSED or Time.get_ticks_msec() - int(p[1]) > 5000:
			_pending.erase(p)
	for peer: LanPeer in peers.duplicate():
		peer.sock.poll()
		var st := peer.sock.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while peer.sock.get_available_packet_count() > 0:
				var d: Variant = JSON.parse_string(peer.sock.get_packet().get_string_from_utf8())
				if d is Dictionary and peer.loop != null:
					peer.loop.receive(peer, d)
		elif st == WebSocketPeer.STATE_CLOSED:
			peers.erase(peer)
			if peer.loop != null:
				peer.loop.leave(peer)
			peer.free()
	while ask.is_bound() and ask.get_available_packet_count() > 0:
		var pkt := ask.get_packet().get_string_from_utf8()
		if pkt.begins_with("standoff?"):
			ask.set_dest_address(ask.get_packet_ip(), ask.get_packet_port())
			ask.put_packet(JSON.stringify(info()).to_utf8_buffer())
	_since += delta
	if _since >= 1.0:
		_since = 0.0
		var b := JSON.stringify(info()).to_utf8_buffer()
		for addr in broadcasts():
			tell.set_dest_address(addr, TELL_PORT)
			tell.put_packet(b)


## A socket that's open: into the lobby its URL names (/lobby/<code>?name=..&v=..[&create=1&lname=..&public=..&max=..]
## - the online server's URL).
func _admit(ws: WebSocketPeer) -> void:
	var u := ws.get_requested_url()
	var room := u.get_slice("?", 0).get_slice("/lobby/", 1)
	var q := {}
	for kv in u.get_slice("?", 1).split("&", false):
		q[kv.get_slice("=", 0)] = kv.get_slice("=", 1).uri_decode()
	var into := {"name": str(q.get("name", "Player")), "v": str(q.get("v", "?"))}
	if str(q.get("create", "")) == "1":
		into.merge({"create": true, "lname": str(q.get("lname", "")), "public": str(q.get("public", "1")) == "1",
			"max": int(q.get("max", 8))})
	var peer := LanPeer.new()
	peer.sock = ws
	peers.append(peer)
	if not LoopLobby.connect_net(peer, room, into):   # (refused - the error's gone down the socket; it closes)
		ws.close(1000, "refused")


## This phone's addresses on a local network (Wi-Fi, a hotspot) - where to tell the others it's here.
static func addresses() -> Array[String]:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		var p := a.split(".")
		var lan := p[0] == "10" or (p[0] == "192" and p[1] == "168") or (p[0] == "172" and int(p[1]) >= 16
				and int(p[1]) <= 31)
		if lan:
			out.append(a)
	out.sort_custom(func(x: String, y: String) -> bool: return x.begins_with("192.168.") and not y.begins_with("192.168."))
	return out   # (192.168.x first: a home Wi-Fi or a hotspot; 10.x is often the mobile network)


## Where "everyone on the network" is: each network's own broadcast address (a hotspot's isn't the phone's default
## route) and the general one.
static func broadcasts() -> Array[String]:
	if bind_to.begins_with("127."):   # (the tests: everyone is this PC)
		return ["127.0.0.1"]
	var out: Array[String] = ["255.255.255.255"]
	for a in addresses():
		var p := a.split(".")
		out.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	return out
