extends Node

const URL := "https://tanzil.net/pub/download/index.php?marks=true&sajdah=true&rub=true&tatweel=true&quranType=uthmani&outType=xml&agree=true"
const ENGLISH_URL := "https://tanzil.net/trans/?transID=en.itani&type=xml"
const TRANSLITERATION_URL := "https://tanzil.net/trans/?transID=en.transliteration&type=xml"
const DATA_PATH := "user://quran_save.dat"
const VERSE := preload("res://scenes/verse/verse.tscn")
const AUDIO_URL := "https://cdn.islamic.network/quran/audio/{bitrate}/{edition}/{number}.mp3"
const BITRATE = 128
const EDITION = "ar.alafasy"

@onready var verses_container := $GUI/VBoxContainer/Panel2/ScrollContainer/Verses
@onready var verse_selector := $GUI/VBoxContainer/Panel/VerseSelector
@onready var http_request := $HTTPRequest
@onready var http_request_english := $HTTPRequestEnglish
@onready var http_request_transliteration := $HTTPRequestTransliteration

const VERSION = 0

var quran := {
	chapters = [],
	english_chapters = [],
	transliteration_chapters = [],
}

var counter = 3

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	var file := FileAccess.open(DATA_PATH, FileAccess.READ);
	if file:
		var saved = file.get_var()
		if saved.has("version") and saved.version == VERSION:
			quran = saved
			counter = 1
			start()
		else:
			request()
	else:
		request()

func request():
	if http_request.request(URL) != OK:
		push_error("Failed to send HTTP request")
	if http_request_english.request(ENGLISH_URL) != OK:
		push_error("Failed to send English HTTP request")
	if http_request_transliteration.request(TRANSLITERATION_URL) != OK:
		push_error("Failed to send Transliteration HTTP request")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()

var offsets = [0]

func start() -> void:
	counter -= 1
	print(counter)
	if(counter != 0): return
	var offset = 0
	for chapter in quran.chapters:
		verse_selector.add_item(chapter.name)
		offset += len(chapter.verses)
		offsets.append(offset)
	print(offsets)
	_on_verse_selector_item_selected(0)

func save() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing")
	quran.version = VERSION
	file.store_var(quran)

func parse(body: PackedByteArray, list):
	var xml := XMLParser.new()
	if xml.open_buffer(body) != OK:
		push_error("Failed to open buffer for XML parsing")
	
	var verses := []
	
	while xml.read() == OK:
		match xml.get_node_name():
			"sura":
				if xml.get_node_type() == xml.NODE_ELEMENT:
					verses = []
					list.append({
						name = xml.get_named_attribute_value("name"),
						verses = verses,
					})
			"aya":
				verses.append(xml.get_named_attribute_value("text"))

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	parse(body, quran.chapters)
	print('ar')
	start()

func play_verse(global_number):
	var url = AUDIO_URL.format({
		bitrate = BITRATE,
		edition = EDITION,
		number = global_number + 1,
	})
	print(url)
	if $HTTPRequestAudio.request(url) != OK:
		push_error('Failed to send audio http request')

func _on_verse_selector_item_selected(index: int) -> void:
	verse_selector.disabled = true
	var verses = quran.chapters[index].verses
	var english_verses = quran.english_chapters[index].verses
	var transliteration_verses = quran.transliteration_chapters[index].verses
	var verses_count := len(verses)
	var current_verses_count := verses_container.get_child_count()
	
	# Reuse old verse instances
	for i in range(verses_count):
		if i < current_verses_count:
			var child = verses_container.get_child(i)
			child.set_text(verses[i])
			child.set_english_text(english_verses[i])
			child.set_transliteration_text(transliteration_verses[i])
			child.global_number = offsets[index] + i
			child.show()
		else:
			await get_tree().process_frame
			var child := VERSE.instantiate()
			child.clicked.connect(play_verse)
			child.set_text(verses[i])
			child.set_english_text(english_verses[i])
			child.set_transliteration_text(transliteration_verses[i])
			child.global_number = offsets[index] + i
			verses_container.add_child(child)
	
	# Hiding the extra verse instances
	for i in range(verses_count, current_verses_count):
		verses_container.get_child(i).hide()
	
	$GUI/VBoxContainer/Panel/VerseSelector.disabled = false


func _on_http_request_english_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	parse(body, quran.english_chapters)
	print('en')
	start()


func _on_http_request_audio_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	$AudioStreamPlayer.stream.data = body
	$AudioStreamPlayer.play()


func _on_http_request_transliteration_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	parse(body, quran.transliteration_chapters)
	print('tr', result)
	start()
