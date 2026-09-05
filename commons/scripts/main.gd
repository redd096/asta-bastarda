extends Control


enum Phase {
	SETUP,
	LOT_INTRO,
	SECRET_HANDOFF,
	SECRET_REVEAL,
	DISCUSSION,
	BID_HANDOFF,
	BID_ENTRY,
	RESULTS,
	GAME_OVER,
}

const BG := Color("#090d17")
const PANEL := Color("#151c2b")
const PANEL_LIGHT := Color("#202a3d")
const GOLD := Color("#f4b942")
const RED := Color("#e65b65")
const GREEN := Color("#66d19e")
const MUTED := Color("#9aa7bd")
const WHITE := Color("#f4f6fb")

var rng := RandomNumberGenerator.new()
var phase := Phase.SETUP
var players: Array[Dictionary] = []
var player_name_inputs: Array[LineEdit] = []
var round_index := 0
var used_item_indices: Array[int] = []
var current_lot: Dictionary = {}
var current_clues: Array[String] = []
var current_objectives: Array[Dictionary] = []
var current_secret_player := 0
var current_bid_player := 0
var current_bids: Array[int] = []
var discussion_time_left := 0.0
var discussion_running := false

var page_margin: MarginContainer
var content: VBoxContainer
var round_label: Label
var title_label: Label
var subtitle_label: Label
var scroll: ScrollContainer
var body: VBoxContainer
var footer: HBoxContainer


func _ready() -> void:
	rng.randomize()
	build_shell()
	show_setup()


func _process(delta: float) -> void:
	if phase != Phase.DISCUSSION or not discussion_running:
		return
	discussion_time_left = maxf(0.0, discussion_time_left - delta)
	var timer_label := body.get_node_or_null("DiscussionTimer") as Label
	if timer_label:
		timer_label.text = format_time(discussion_time_left)
		if discussion_time_left <= 10.0:
			timer_label.add_theme_color_override("font_color", RED)
	if discussion_time_left <= 0.0:
		discussion_running = false
		begin_bidding()


func build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	page_margin = MarginContainer.new()
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_margin.add_theme_constant_override("margin_left", 28)
	page_margin.add_theme_constant_override("margin_right", 28)
	page_margin.add_theme_constant_override("margin_top", 22)
	page_margin.add_theme_constant_override("margin_bottom", 22)
	add_child(page_margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	page_margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)

	var brand := Label.new()
	brand.text = "ASTA BASTARDA"
	brand.add_theme_font_size_override("font_size", 22)
	brand.add_theme_color_override("font_color", GOLD)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)

	round_label = Label.new()
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	round_label.add_theme_font_size_override("font_size", 18)
	round_label.add_theme_color_override("font_color", MUTED)
	header.add_child(round_label)

	var separator := HSeparator.new()
	content.add_child(separator)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", WHITE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", MUTED)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle_label)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)


func clear_page() -> void:
	scroll.scroll_vertical = 0
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for child in footer.get_children():
		footer.remove_child(child)
		child.queue_free()
	round_label.text = ""


func show_setup() -> void:
	phase = Phase.SETUP
	clear_page()
	title_label.text = "Chi si rovinerà all'asta?"
	subtitle_label.text = "Inserisci da 2 a 6 giocatori. Servirà un solo dispositivo, da passare quando appare una schermata segreta."

	var setup_panel := make_panel()
	body.add_child(setup_panel)
	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 10)
	setup_panel.add_child(panel_content)

	var label := make_section_label("GIOCATORI")
	panel_content.add_child(label)
	player_name_inputs.clear()
	for index in 6:
		var input := LineEdit.new()
		input.placeholder_text = "Giocatore %d%s" % [index + 1, " (opzionale)" if index >= 2 else ""]
		input.text = ["Giocatore 1", "Giocatore 2", "", "", "", ""][index]
		input.custom_minimum_size.y = 48
		input.add_theme_font_size_override("font_size", 18)
		panel_content.add_child(input)
		player_name_inputs.append(input)

	var rules := make_info_box("COME SI VINCE", "Dopo %d aste, vince chi ha il patrimonio più alto: denaro rimasto + valore reale degli oggetti + bonus degli incarichi segreti." % GameData.ROUND_COUNT, GOLD)
	body.add_child(rules)

	var start_button := make_button("Inizia la partita", GOLD)
	start_button.pressed.connect(start_game)
	footer.add_child(start_button)


func start_game() -> void:
	players.clear()
	var used_names: Dictionary = {}
	for input in player_name_inputs:
		var clean_name := input.text.strip_edges()
		if clean_name.is_empty():
			continue
		if used_names.has(clean_name.to_lower()):
			show_inline_error("I nomi dei giocatori devono essere diversi.")
			return
		used_names[clean_name.to_lower()] = true
		players.append({
			"name": clean_name,
			"cash": GameData.STARTING_CASH,
			"assets": 0,
			"bonus": 0,
			"lots": [],
		})
	if players.size() < 2:
		show_inline_error("Inserisci almeno due giocatori.")
		return

	round_index = 0
	used_item_indices.clear()
	start_round()


func show_inline_error(message: String) -> void:
	var old_error := body.get_node_or_null("InlineError")
	if old_error:
		body.remove_child(old_error)
		old_error.queue_free()
	var error := Label.new()
	error.name = "InlineError"
	error.text = message
	error.add_theme_color_override("font_color", RED)
	error.add_theme_font_size_override("font_size", 17)
	error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(error)
	body.move_child(error, 0)


func start_round() -> void:
	phase = Phase.LOT_INTRO
	current_secret_player = 0
	current_bid_player = 0
	current_bids.clear()
	current_objectives.clear()

	var available: Array[int] = []
	for index in GameData.ITEMS.size():
		if index not in used_item_indices:
			available.append(index)
	var selected_index: int = available[rng.randi_range(0, available.size() - 1)]
	used_item_indices.append(selected_index)
	current_lot = GameData.make_lot(GameData.ITEMS[selected_index], rng)
	current_clues = GameData.make_clues(int(current_lot["value"]), players.size(), rng)
	for index in players.size():
		current_objectives.append(GameData.make_objective(index, players, current_lot, rng))

	clear_page()
	round_label.text = "LOTTO %02d / %02d" % [round_index + 1, GameData.ROUND_COUNT]
	title_label.text = String(current_lot["name"])
	subtitle_label.text = String(current_lot["description"])
	body.add_child(make_lot_card())
	body.add_child(make_info_box("ATTENZIONE", "Il valore reale resterà nascosto fino alla fine dell'asta. Ognuno riceverà un indizio e un incarico privato: potete dire la verità, mentire o tacere.", RED))

	var button := make_button("Distribuisci le informazioni segrete", GOLD)
	button.pressed.connect(show_secret_handoff)
	footer.add_child(button)


func show_secret_handoff() -> void:
	phase = Phase.SECRET_HANDOFF
	clear_page()
	round_label.text = "INFORMAZIONI PRIVATE"
	title_label.text = "Passa il dispositivo"
	subtitle_label.text = "Assicuratevi che gli altri non possano vedere lo schermo."

	var player_name := String(players[current_secret_player]["name"])
	var box := make_info_box("TOCCA A", player_name, GOLD)
	body.add_child(box)

	var button := make_button("Sono %s" % player_name, GOLD)
	button.pressed.connect(show_secret_reveal)
	footer.add_child(button)


func show_secret_reveal() -> void:
	phase = Phase.SECRET_REVEAL
	clear_page()
	round_label.text = "SOLO PER TE"
	title_label.text = "Memorizza e non farti leggere"
	subtitle_label.text = "Quando hai finito, nascondi la schermata prima di passare il dispositivo."

	body.add_child(make_info_box("IL TUO INDIZIO", current_clues[current_secret_player], GREEN))
	body.add_child(make_info_box("IL TUO INCARICO", "%s\n\nRicompensa: +%d punti" % [current_objectives[current_secret_player]["text"], current_objectives[current_secret_player]["bonus"]], RED))

	var button := make_button("Ho memorizzato — nascondi", GOLD)
	button.pressed.connect(finish_secret_reveal)
	footer.add_child(button)


func finish_secret_reveal() -> void:
	current_secret_player += 1
	if current_secret_player < players.size():
		show_secret_handoff()
	else:
		show_discussion()


func show_discussion() -> void:
	phase = Phase.DISCUSSION
	clear_page()
	round_label.text = "TRATTATIVA"
	title_label.text = String(current_lot["name"])
	subtitle_label.text = "Condividete, nascondete o inventate informazioni. Quando il tempo scade iniziano le offerte."
	body.add_child(make_lot_card())

	var timer_label := Label.new()
	timer_label.name = "DiscussionTimer"
	timer_label.text = format_time(GameData.DISCUSSION_SECONDS)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 64)
	timer_label.add_theme_color_override("font_color", GOLD)
	body.add_child(timer_label)

	discussion_time_left = GameData.DISCUSSION_SECONDS
	discussion_running = true

	var button := make_button("Passa subito alle offerte", GOLD)
	button.pressed.connect(begin_bidding)
	footer.add_child(button)


func begin_bidding() -> void:
	if phase != Phase.DISCUSSION:
		return
	discussion_running = false
	current_bid_player = 0
	current_bids.clear()
	for _index in players.size():
		current_bids.append(0)
	show_bid_handoff()


func show_bid_handoff() -> void:
	phase = Phase.BID_HANDOFF
	clear_page()
	round_label.text = "OFFERTA SEGRETA %d / %d" % [current_bid_player + 1, players.size()]
	title_label.text = "Passa il dispositivo"
	subtitle_label.text = "Gli altri giocatori non devono vedere l'offerta."

	var player := players[current_bid_player]
	body.add_child(make_info_box("TOCCA A", "%s\nDisponibilità: %d crediti" % [player["name"], player["cash"]], GOLD))

	var button := make_button("Sono %s" % player["name"], GOLD)
	button.pressed.connect(show_bid_entry)
	footer.add_child(button)


func show_bid_entry() -> void:
	phase = Phase.BID_ENTRY
	clear_page()
	round_label.text = "OFFERTA SEGRETA"
	title_label.text = "Quanto vuoi offrire?"
	subtitle_label.text = "Puoi offrire 0 per rinunciare. L'offerta più alta vince; in caso di parità il vincitore viene sorteggiato."

	var player := players[current_bid_player]
	body.add_child(make_info_box("PROMEMORIA", "%s\n\n%s" % [current_clues[current_bid_player], current_objectives[current_bid_player]["text"]], GREEN))

	var bid_box := make_panel()
	body.add_child(bid_box)
	var bid_content := VBoxContainer.new()
	bid_content.add_theme_constant_override("separation", 8)
	bid_box.add_child(bid_content)
	var amount_label := make_section_label("LA TUA OFFERTA")
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_content.add_child(amount_label)
	var bid_input := SpinBox.new()
	bid_input.name = "BidInput"
	bid_input.min_value = 0
	bid_input.max_value = int(player["cash"])
	bid_input.step = 5
	bid_input.value = 0
	bid_input.custom_minimum_size.y = 60
	bid_input.add_theme_font_size_override("font_size", 28)
	bid_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_content.add_child(bid_input)

	var button := make_button("Conferma e nascondi", GOLD)
	button.pressed.connect(confirm_bid)
	footer.add_child(button)


func confirm_bid() -> void:
	var bid_input := body.get_node_or_null("PanelContainer/VBoxContainer/BidInput") as SpinBox
	if bid_input == null:
		bid_input = find_child("BidInput", true, false) as SpinBox
	current_bids[current_bid_player] = int(bid_input.value)
	current_bid_player += 1
	if current_bid_player < players.size():
		show_bid_handoff()
	else:
		resolve_auction()


func resolve_auction() -> void:
	phase = Phase.RESULTS
	var winning_bid := 0
	for bid in current_bids:
		winning_bid = maxi(winning_bid, bid)
	var winner_index := -1
	if winning_bid > 0:
		var tied: Array[int] = []
		for index in current_bids.size():
			if current_bids[index] == winning_bid:
				tied.append(index)
		winner_index = tied[rng.randi_range(0, tied.size() - 1)]

	if winner_index >= 0:
		players[winner_index]["cash"] -= winning_bid
		players[winner_index]["assets"] += int(current_lot["value"])
		players[winner_index]["lots"].append(String(current_lot["name"]))

	var completed: Array[bool] = []
	for index in players.size():
		var did_complete := GameData.objective_completed(current_objectives[index], index, winner_index, winning_bid, current_bids, int(current_lot["value"]))
		completed.append(did_complete)
		if did_complete:
			players[index]["bonus"] += int(current_objectives[index]["bonus"])

	show_results(winner_index, winning_bid, completed)


func show_results(winner_index: int, winning_bid: int, completed: Array[bool]) -> void:
	clear_page()
	round_label.text = "AGGIUDICATO" if winner_index >= 0 else "INVENDUTO"
	title_label.text = String(current_lot["name"])
	if winner_index >= 0:
		var difference := int(current_lot["value"]) - winning_bid
		subtitle_label.text = "%s vince offrendo %d crediti. Affare da %+d." % [players[winner_index]["name"], winning_bid, difference]
	else:
		subtitle_label.text = "Nessuno ha avuto il coraggio di comprarlo."

	body.add_child(make_info_box("VALORE REALE", "%d crediti" % current_lot["value"], GOLD))

	var bid_panel := make_panel()
	body.add_child(bid_panel)
	var bid_content := VBoxContainer.new()
	bid_content.add_theme_constant_override("separation", 8)
	bid_panel.add_child(bid_content)
	bid_content.add_child(make_section_label("TUTTE LE OFFERTE"))
	for index in players.size():
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(players[index]["name"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 18)
		row.add_child(name_label)
		var bid_label := Label.new()
		bid_label.text = "%d crediti" % current_bids[index]
		bid_label.add_theme_font_size_override("font_size", 18)
		bid_label.add_theme_color_override("font_color", GOLD if index == winner_index else WHITE)
		row.add_child(bid_label)
		bid_content.add_child(row)

	var objective_panel := make_panel()
	body.add_child(objective_panel)
	var objective_content := VBoxContainer.new()
	objective_content.add_theme_constant_override("separation", 10)
	objective_panel.add_child(objective_content)
	objective_content.add_child(make_section_label("INCARICHI RIVELATI"))
	for index in players.size():
		var status := "COMPLETATO +%d PUNTI" % current_objectives[index]["bonus"] if completed[index] else "FALLITO"
		var line := Label.new()
		line.text = "%s — %s\n%s" % [players[index]["name"], status, current_objectives[index]["text"]]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 16)
		line.add_theme_color_override("font_color", GREEN if completed[index] else MUTED)
		objective_content.add_child(line)

	var score_panel := make_scoreboard()
	body.add_child(score_panel)

	var button_text := "Classifica finale" if round_index + 1 >= GameData.ROUND_COUNT else "Prossimo lotto"
	var button := make_button(button_text, GOLD)
	button.pressed.connect(continue_after_results)
	footer.add_child(button)


func continue_after_results() -> void:
	round_index += 1
	if round_index >= GameData.ROUND_COUNT:
		show_game_over()
	else:
		start_round()


func show_game_over() -> void:
	phase = Phase.GAME_OVER
	clear_page()
	round_label.text = "FINE PARTITA"

	var ranking: Array[Dictionary] = players.duplicate(true)
	ranking.sort_custom(sort_players_by_score)
	if ranking.size() > 1 and total_score(ranking[0]) == total_score(ranking[1]):
		title_label.text = "Il mercato non sa decidere: pareggio!"
	else:
		title_label.text = "%s domina il mercato!" % ranking[0]["name"]
	subtitle_label.text = "Il patrimonio finale include denaro, valore reale degli acquisti e bonus degli incarichi."

	for index in ranking.size():
		var player := ranking[index]
		var lots: Array = player["lots"]
		var lot_names := PackedStringArray()
		for lot_name in lots:
			lot_names.append(String(lot_name))
		var lots_text := ", ".join(lot_names) if not lot_names.is_empty() else "Nessun acquisto"
		var color := GOLD if index == 0 else WHITE
		var panel := make_info_box("%d° — %s" % [index + 1, player["name"]], "Patrimonio: %d\nDenaro: %d  •  Valore oggetti: %d  •  Bonus: %d\n%s" % [total_score(player), player["cash"], player["assets"], player["bonus"], lots_text], color)
		body.add_child(panel)

	var restart := make_button("Nuova partita", GOLD)
	restart.pressed.connect(show_setup)
	footer.add_child(restart)


func make_lot_card() -> PanelContainer:
	var panel := make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(make_section_label("LOTTO DEL GIORNO"))
	var category := Label.new()
	category.text = "Categoria: %s" % String(current_lot["category"]).capitalize()
	category.add_theme_color_override("font_color", MUTED)
	category.add_theme_font_size_override("font_size", 17)
	box.add_child(category)
	var mystery := Label.new()
	mystery.text = "VALORE REALE: ???"
	mystery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mystery.add_theme_font_size_override("font_size", 30)
	mystery.add_theme_color_override("font_color", GOLD)
	box.add_child(mystery)
	return panel


func make_scoreboard() -> PanelContainer:
	var panel := make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(make_section_label("SITUAZIONE ATTUALE"))
	for player in players:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(player["name"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 17)
		row.add_child(name_label)
		var score_label := Label.new()
		score_label.text = "%d totali  •  %d disponibili" % [total_score(player), player["cash"]]
		score_label.add_theme_color_override("font_color", GOLD)
		score_label.add_theme_font_size_override("font_size", 17)
		row.add_child(score_label)
		box.add_child(row)
	return panel


func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = PANEL_LIGHT
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel


func make_info_box(heading: String, text: String, accent: Color) -> PanelContainer:
	var panel := make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading_label := make_section_label(heading)
	heading_label.add_theme_color_override("font_color", accent)
	box.add_child(heading_label)
	var text_label := Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 19)
	text_label.add_theme_color_override("font_color", WHITE)
	box.add_child(text_label)
	return panel


func make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", MUTED)
	return label


func make_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250, 54)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", BG)
	button.add_theme_color_override("font_hover_color", BG)
	button.add_theme_color_override("font_pressed_color", BG)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 9
	normal.corner_radius_top_right = 9
	normal.corner_radius_bottom_left = 9
	normal.corner_radius_bottom_right = 9
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.12)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func total_score(player: Dictionary) -> int:
	return int(player["cash"]) + int(player["assets"]) + int(player["bonus"])


func sort_players_by_score(a: Dictionary, b: Dictionary) -> bool:
	return total_score(a) > total_score(b)


func format_time(seconds: float) -> String:
	var rounded := int(ceil(seconds))
	return "%02d:%02d" % [int(rounded / 60.0), rounded % 60]
