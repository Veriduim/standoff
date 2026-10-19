class_name LanFinder
extends Node
## Nearby lobbies (LanHost): it hears hosts telling the network about themselves, and asks "standoff?" out to everyone
## every couple of seconds - the hosts answer it directly, for when their telling doesn't get through.

const FORGET_MS := 5000

var found := {}                   ## code -> {code, name, players, max, version, ip, port, seen}
var hear := PacketPeerUDP.new()   ## hosts telling (LanHost.TELL_PORT)
var ask := PacketPeerUDP.new()    ## our questions out, their answers back
var _t := 0.0


func start() -> void:
	if not hear.is_bound():
		hear.bind(LanHost.TELL_PORT, LanHost.bind_to)   # (taken on this phone? then answers to asking still find them)
	if not ask.is_bound():
		ask.set_broadcast_enabled(true)
		ask.bind(0, LanHost.bind_to)
	_t = 0.0


func stop() -> void:
	hear.close()
	ask.close()
	found.clear()


func _ask(ip: String) -> void:
	if ask.is_bound():
		ask.set_dest_address(ip, LanHost.ASK_PORT)
		ask.put_packet("standoff?".to_utf8_buffer())


func _process(delta: float) -> void:
	poll(delta)


func poll(delta := 0.0) -> void:
	if not ask.is_bound():
		return
	_t -= delta
	if _t <= 0.0:
		_t = 1.5
		for a in LanHost.broadcasts():
			_ask(a)
	for s: PacketPeerUDP in [hear, ask]:
		while s.is_bound() and s.get_available_packet_count() > 0:
			var pkt := s.get_packet().get_string_from_utf8()
			_note(pkt, s.get_packet_ip())
	var now := Time.get_ticks_msec()
	for k: String in found.keys():
		if now - int(found[k]["seen"]) > FORGET_MS:
			found.erase(k)


func _note(pkt: String, ip: String) -> void:
	var d: Variant = JSON.parse_string(pkt)
	if not d is Dictionary or str(d.get("standoff", "")) != "lan" or str(d.get("code", "")) == "":
		return
	d["ip"] = ip
	d["seen"] = Time.get_ticks_msec()
	found[str(d["code"])] = d   # (one row a lobby, however many ways it was heard)


## The lobbies nearby, in the online list's shape (+ ip, port), the busiest first.
func list() -> Array:
	var out: Array = found.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["players"]) > int(b["players"]))
	return out
