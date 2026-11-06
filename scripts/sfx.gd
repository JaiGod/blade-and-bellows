extends Node
## Procedural audio: every sound effect and the tavern-style music loop are synthesized at startup.

const RATE := 22050
const MRATE := 11025
var sounds := {}
var players: Array = []
var idx := 0
var music: AudioStreamPlayer
var music_ready := false

func _ready() -> void:
	for i in 8:
		var pl := AudioStreamPlayer.new()
		pl.volume_db = -6.0
		add_child(pl)
		players.append(pl)
	music = AudioStreamPlayer.new()
	music.volume_db = -15.0
	add_child(music)
	sounds["clang"] = _clang(1.0, 0.7)
	sounds["clang_good"] = _clang(0.92, 0.5)
	sounds["thud"] = _mix(_noise(0.18, 0.15, 0.5), _tone([[95, 0.2]], "sin", 0.6))
	sounds["hiss"] = _noise(1.1, 0.55, 0.45)
	sounds["whoosh"] = _noise(0.3, 0.08, 0.35, true)
	sounds["coin"] = _tone([[1318, 0.07], [1760, 0.16]], "sq", 0.18)
	sounds["click"] = _tone([[880, 0.035]], "tri", 0.3)
	sounds["bad"] = _tone([[300, 0.12], [200, 0.22]], "sq", 0.2)
	sounds["bell"] = _mix(_tone([[1568, 0.5]], "sin", 0.3), _tone([[2093, 0.4]], "sin", 0.18))
	sounds["fanfare"] = _tone([[523, 0.12], [659, 0.12], [784, 0.12], [1047, 0.42]], "tri", 0.4)
	sounds["sad"] = _tone([[392, 0.2], [330, 0.2], [262, 0.5]], "tri", 0.4)
	sounds["sparkle"] = _tone([[1760, 0.05], [2349, 0.05], [2637, 0.05], [3136, 0.12]], "sin", 0.25)
	sounds["page"] = _noise(0.08, 0.3, 0.25)

func play(name: String, pitch: float = 1.0) -> void:
	if not Game.sound_on or not sounds.has(name) or DisplayServer.get_name() == "headless":
		return
	var pl: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	pl.stream = sounds[name]
	pl.pitch_scale = pitch
	pl.play()

func start_music() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not music_ready:
		music.stream = _music()
		music_ready = true
	if Game.music_on and not music.playing:
		music.play()
	elif not Game.music_on:
		music.stop()

func _wav(data: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w

func _osc(wave: String, ph: float) -> float:
	match wave:
		"sq": return 1.0 if ph < 0.5 else -1.0
		"saw": return ph * 2.0 - 1.0
		"tri": return 4.0 * absf(ph - 0.5) - 1.0
	return sin(ph * TAU)

func _tone_data(notes: Array, wave: String, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for n in notes:
		var f: float = n[0]
		var count := int(RATE * float(n[1]))
		for i in count:
			var tt := float(i) / RATE
			var env := minf(1.0, tt * 200.0) * pow(1.0 - float(i) / count, 1.5)
			out.append(_osc(wave, fmod(tt * f, 1.0)) * env * vol)
	return out

func _tone(notes: Array, wave: String, vol: float) -> AudioStreamWAV:
	return _wav(_tone_data(notes, wave, vol))

func _noise_data(dur: float, smooth: float, vol: float, swell: bool = false) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(RATE * dur)
	var y := 0.0
	for i in n:
		var k := float(i) / n
		var env := sin(k * PI) if swell else pow(1.0 - k, 2.0)
		y += (randf() * 2.0 - 1.0 - y) * (1.0 - smooth * 0.9)
		out.append(y * env * vol)
	return out

func _noise(dur: float, smooth: float, vol: float, swell: bool = false) -> AudioStreamWAV:
	return _wav(_noise_data(dur, smooth, vol, swell))

## Metallic anvil ring: inharmonic partials with fast decay, plus a noise transient.
func _clang(pitch: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * 0.7)
	var out := PackedFloat32Array()
	var parts := [[620.0, 1.0, 7.0], [1520.0, 0.6, 9.0], [2390.0, 0.45, 12.0], [3410.0, 0.3, 16.0], [4470.0, 0.2, 20.0]]
	for i in n:
		var tt := float(i) / RATE
		var s := 0.0
		for pp in parts:
			s += sin(tt * float(pp[0]) * pitch * TAU) * float(pp[1]) * exp(-tt * float(pp[2]))
		if tt < 0.02:
			s += (randf() * 2.0 - 1.0) * (1.0 - tt / 0.02) * 1.2
		out.append(s * vol * 0.4)
	return _wav(out)

func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var da := a.data
	var db := b.data
	var n := maxi(da.size(), db.size()) / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var x := 0.0
		if i * 2 < da.size():
			x += da.decode_s16(i * 2) / 32000.0
		if i * 2 < db.size():
			x += db.decode_s16(i * 2) / 32000.0
		out[i] = x
	return _wav(out)

## A gentle minor-key lute loop (16 beats) with a bass drone and soft hand-drum.
func _music() -> AudioStreamWAV:
	var bpm := 92.0
	var beat := 60.0 / bpm
	var beats := 32
	var n := int(MRATE * beat * beats)
	var out := PackedFloat32Array()
	out.resize(n)
	var mel := [69, 72, 74, 76, 74, 72, 69, 67, 69, 72, 76, 79, 76, 74, 72, 74,
		69, 72, 74, 76, 79, 76, 74, 72, 74, 72, 69, 67, 64, 67, 69, 69]
	var bass := [45, 45, 43, 43, 41, 41, 40, 40]
	for b in beats:
		var start := int(b * beat * MRATE)
		var f := 440.0 * pow(2.0, (mel[b] - 69) / 12.0)
		var bf := 440.0 * pow(2.0, (bass[(b / 4) % bass.size()] - 69) / 12.0)
		var ln := int(beat * MRATE)
		for i in ln:
			var j := start + i
			if j >= n:
				break
			var tt := float(i) / MRATE
			var pluck := exp(-tt * 5.0)
			var s := (sin(tt * f * TAU) + 0.35 * sin(tt * f * 2.0 * TAU) + 0.15 * sin(tt * f * 3.0 * TAU)) * pluck * 0.22
			if b % 2 == 0:
				s += sin(tt * bf * TAU) * exp(-tt * 1.6) * 0.2
			if b % 4 == 2 and tt < 0.08:
				s += (randf() * 2.0 - 1.0) * (1.0 - tt / 0.08) * 0.12
			out[j] += s
	return _wav(out, MRATE, true)
