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

const GOLD := Color("#f4b942")
const RED := Color("#e65b65")
const GREEN := Color("#66d19e")
const MUTED := Color("#9aa7bd")

var rng := RandomNumberGenerator.new()
var phase := Phase.SETUP
var players: Array[Dictionary] = []
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

@onready var pages: Control = %Pages
@onready var round_label: Label = %RoundLabel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel

@onready var setup_page: VBoxContainer = %SetupPage
@onready var player_inputs: VBoxContainer = %PlayerInputs
@onready var setup_error: Label = %SetupError

@onready var lot_intro_page: VBoxContainer = %LotIntroPage
@onready var lot_intro_category: Label = %LotIntroCategory

@onready var handoff_page: VBoxContainer = %HandoffPage
@onready var handoff_info: Label = %HandoffInfo
@onready var handoff_button: Button = %HandoffButton

@onready var secret_page: VBoxContainer = %SecretPage
@onready var secret_clue: Label = %SecretClue
@onready var secret_objective: Label = %SecretObjective

@onready var discussion_page: VBoxContainer = %DiscussionPage
@onready var discussion_category: Label = %DiscussionCategory
@onready var discussion_timer: Label = %DiscussionTimer

@onready var bid_page: VBoxContainer = %BidPage
@onready var bid_cash: Label = %BidCash
@onready var bid_clue: Label = %BidClue
@onready var bid_objective: Label = %BidObjective
@onready var bid_input: SpinBox = %BidInput

@onready var results_page: VBoxContainer = %ResultsPage
@onready var real_value_label: Label = %RealValueLabel
@onready var bid_rows: VBoxContainer = %BidRows
@onready var objective_rows: VBoxContainer = %ObjectiveRows
@onready var score_rows: VBoxContainer = %ScoreRows
@onready var results_continue_button: Button = %ResultsContinueButton

@onready var game_over_page: VBoxContainer = %GameOverPage
@onready var ranking_cards: VBoxContainer = %RankingCards


func _ready() -> void:
	rng.randomize()
	show_setup()


func _process(delta: float) -> void:
	if phase != Phase.DISCUSSION or not discussion_running:
		return
	discussion_time_left = maxf(0.0, discussion_time_left - delta)
	discussion_timer.text = format_time(discussion_time_left)
	discussion_timer.add_theme_color_override("font_color", RED if discussion_time_left <= 10.0 else GOLD)
	if discussion_time_left <= 0.0:
		discussion_running = false
		begin_bidding()


func show_page(page: Control) -> void:
	for child in pages.get_children():
		child.visible = child == page
	var scroll := page.get_node_or_null("Scroll") as ScrollContainer
	if scroll:
		scroll.scroll_vertical = 0


func show_setup() -> void:
	phase = Phase.SETUP
	discussion_running = false
	round_label.text = ""
	title_label.text = "Chi si rovinerà all'asta?"
	subtitle_label.text = "Inserisci da 2 a 6 giocatori. Servirà un solo dispositivo, da passare quando appare una schermata segreta."
	setup_error.visible = false
	show_page(setup_page)


func _on_start_button_pressed() -> void:
	players.clear()
	var used_names: Dictionary = {}
	for child in player_inputs.get_children():
		var input := child as LineEdit
		var clean_name := input.text.strip_edges()
		if clean_name.is_empty():
			continue
		if used_names.has(clean_name.to_lower()):
			show_setup_error("I nomi dei giocatori devono essere diversi.")
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
		show_setup_error("Inserisci almeno due giocatori.")
		return

	round_index = 0
	used_item_indices.clear()
	start_round()


func show_setup_error(message: String) -> void:
	setup_error.text = message
	setup_error.visible = true


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

	round_label.text = "LOTTO %02d / %02d" % [round_index + 1, GameData.ROUND_COUNT]
	title_label.text = String(current_lot["name"])
	subtitle_label.text = String(current_lot["description"])
	lot_intro_category.text = "Categoria: %s" % String(current_lot["category"]).capitalize()
	show_page(lot_intro_page)


func _on_distribute_button_pressed() -> void:
	show_secret_handoff()


func show_secret_handoff() -> void:
	phase = Phase.SECRET_HANDOFF
	round_label.text = "INFORMAZIONI PRIVATE"
	title_label.text = "Passa il dispositivo"
	subtitle_label.text = "Assicuratevi che gli altri non possano vedere lo schermo."
	var player_name := String(players[current_secret_player]["name"])
	handoff_info.text = "%s\n\nTocca il pulsante solo quando hai il dispositivo." % player_name
	handoff_button.text = "Sono %s" % player_name
	show_page(handoff_page)


func _on_handoff_button_pressed() -> void:
	if phase == Phase.SECRET_HANDOFF:
		show_secret_reveal()
	elif phase == Phase.BID_HANDOFF:
		show_bid_entry()


func show_secret_reveal() -> void:
	phase = Phase.SECRET_REVEAL
	round_label.text = "SOLO PER TE"
	title_label.text = "Memorizza e non farti leggere"
	subtitle_label.text = "Quando hai finito, nascondi la schermata prima di passare il dispositivo."
	secret_clue.text = current_clues[current_secret_player]
	secret_objective.text = "%s\n\nRicompensa: +%d punti" % [current_objectives[current_secret_player]["text"], current_objectives[current_secret_player]["bonus"]]
	show_page(secret_page)


func _on_secret_done_button_pressed() -> void:
	current_secret_player += 1
	if current_secret_player < players.size():
		show_secret_handoff()
	else:
		show_discussion()


func show_discussion() -> void:
	phase = Phase.DISCUSSION
	round_label.text = "TRATTATIVA"
	title_label.text = String(current_lot["name"])
	subtitle_label.text = "Condividete, nascondete o inventate informazioni. Quando il tempo scade iniziano le offerte."
	discussion_category.text = "Categoria: %s" % String(current_lot["category"]).capitalize()
	discussion_time_left = GameData.DISCUSSION_SECONDS
	discussion_timer.text = format_time(discussion_time_left)
	discussion_timer.add_theme_color_override("font_color", GOLD)
	discussion_running = true
	show_page(discussion_page)


func _on_skip_discussion_button_pressed() -> void:
	begin_bidding()


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
	round_label.text = "OFFERTA SEGRETA %d / %d" % [current_bid_player + 1, players.size()]
	title_label.text = "Passa il dispositivo"
	subtitle_label.text = "Gli altri giocatori non devono vedere l'offerta."
	var player := players[current_bid_player]
	handoff_info.text = "%s\n\nDisponibilità: %d crediti" % [player["name"], player["cash"]]
	handoff_button.text = "Sono %s" % player["name"]
	show_page(handoff_page)


func show_bid_entry() -> void:
	phase = Phase.BID_ENTRY
	round_label.text = "OFFERTA SEGRETA"
	title_label.text = "Quanto vuoi offrire?"
	subtitle_label.text = "Puoi offrire 0 per rinunciare. L'offerta più alta vince; in caso di parità il vincitore viene sorteggiato."
	var player := players[current_bid_player]
	bid_cash.text = "%s — disponibilità: %d crediti" % [player["name"], player["cash"]]
	bid_clue.text = current_clues[current_bid_player]
	bid_objective.text = current_objectives[current_bid_player]["text"]
	bid_input.max_value = int(player["cash"])
	bid_input.value = 0
	show_page(bid_page)


func _on_confirm_bid_button_pressed() -> void:
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
	round_label.text = "AGGIUDICATO" if winner_index >= 0 else "INVENDUTO"
	title_label.text = String(current_lot["name"])
	if winner_index >= 0:
		var difference := int(current_lot["value"]) - winning_bid
		subtitle_label.text = "%s vince offrendo %d crediti. Affare da %+d." % [players[winner_index]["name"], winning_bid, difference]
	else:
		subtitle_label.text = "Nessuno ha avuto il coraggio di comprarlo."
	real_value_label.text = "%d crediti" % current_lot["value"]

	for index in bid_rows.get_child_count():
		var row := bid_rows.get_child(index) as HBoxContainer
		row.visible = index < players.size()
		if row.visible:
			(row.get_child(0) as Label).text = players[index]["name"]
			var amount := row.get_child(1) as Label
			amount.text = "%d crediti" % current_bids[index]
			amount.add_theme_color_override("font_color", GOLD if index == winner_index else Color.WHITE)

	for index in objective_rows.get_child_count():
		var line := objective_rows.get_child(index) as Label
		line.visible = index < players.size()
		if line.visible:
			var status := "COMPLETATO +%d PUNTI" % current_objectives[index]["bonus"] if completed[index] else "FALLITO"
			line.text = "%s — %s\n%s" % [players[index]["name"], status, current_objectives[index]["text"]]
			line.add_theme_color_override("font_color", GREEN if completed[index] else MUTED)

	update_score_rows()
	results_continue_button.text = "Classifica finale" if round_index + 1 >= GameData.ROUND_COUNT else "Prossimo lotto"
	show_page(results_page)


func update_score_rows() -> void:
	for index in score_rows.get_child_count():
		var row := score_rows.get_child(index) as HBoxContainer
		row.visible = index < players.size()
		if row.visible:
			(row.get_child(0) as Label).text = players[index]["name"]
			(row.get_child(1) as Label).text = "%d totali  •  %d disponibili" % [total_score(players[index]), players[index]["cash"]]


func _on_results_continue_button_pressed() -> void:
	round_index += 1
	if round_index >= GameData.ROUND_COUNT:
		show_game_over()
	else:
		start_round()


func show_game_over() -> void:
	phase = Phase.GAME_OVER
	round_label.text = "FINE PARTITA"
	var ranking: Array[Dictionary] = players.duplicate(true)
	ranking.sort_custom(sort_players_by_score)
	if ranking.size() > 1 and total_score(ranking[0]) == total_score(ranking[1]):
		title_label.text = "Il mercato non sa decidere: pareggio!"
	else:
		title_label.text = "%s domina il mercato!" % ranking[0]["name"]
	subtitle_label.text = "Il patrimonio finale include denaro, valore reale degli acquisti e bonus degli incarichi."

	for index in ranking_cards.get_child_count():
		var card := ranking_cards.get_child(index) as PanelContainer
		card.visible = index < ranking.size()
		if card.visible:
			var player := ranking[index]
			var lot_names := PackedStringArray()
			for lot_name in player["lots"]:
				lot_names.append(String(lot_name))
			var lots_text := ", ".join(lot_names) if not lot_names.is_empty() else "Nessun acquisto"
			var box := card.get_child(0) as VBoxContainer
			var heading := box.get_child(0) as Label
			heading.text = "%d° — %s" % [index + 1, player["name"]]
			heading.add_theme_color_override("font_color", GOLD if index == 0 else Color.WHITE)
			(box.get_child(1) as Label).text = "Patrimonio: %d\nDenaro: %d  •  Valore oggetti: %d  •  Bonus: %d\n%s" % [total_score(player), player["cash"], player["assets"], player["bonus"], lots_text]
	show_page(game_over_page)


func _on_restart_button_pressed() -> void:
	show_setup()


func total_score(player: Dictionary) -> int:
	return int(player["cash"]) + int(player["assets"]) + int(player["bonus"])


func sort_players_by_score(a: Dictionary, b: Dictionary) -> bool:
	return total_score(a) > total_score(b)


func format_time(seconds: float) -> String:
	var rounded := int(ceil(seconds))
	return "%02d:%02d" % [int(rounded / 60.0), rounded % 60]

