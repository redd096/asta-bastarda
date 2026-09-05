class_name GameData
extends RefCounted


const STARTING_CASH := 240
const ROUND_COUNT := 6
const DISCUSSION_SECONDS := 45

const ITEMS: Array[Dictionary] = [
	{
		"name": "Miniera abbandonata",
		"description": "Chiusa da vent'anni. Il precedente proprietario giura di aver lasciato dell'oro nei tunnel.",
		"base_value": 105,
		"variance": 45,
		"category": "impresa",
	},
	{
		"name": "Gallina apparentemente normale",
		"description": "Depone un solo uovo al giorno, ma lo fa con un'eleganza sospetta.",
		"base_value": 65,
		"variance": 45,
		"category": "animale",
	},
	{
		"name": "14 Bitcoin su un hard disk",
		"description": "L'hard disk fa un rumore inquietante. La password potrebbe essere 'password'.",
		"base_value": 155,
		"variance": 80,
		"category": "tecnologia",
	},
	{
		"name": "Castello con debiti inclusi",
		"description": "Quarantadue stanze, tre fantasmi e un tetto che considera la pioggia un'opinione.",
		"base_value": 125,
		"variance": 65,
		"category": "immobile",
	},
	{
		"name": "Brevetto per ombrelli bucati",
		"description": "Una rivoluzione nella ventilazione personale, secondo l'inventore.",
		"base_value": 55,
		"variance": 40,
		"category": "tecnologia",
	},
	{
		"name": "Mappa del tesoro già usata",
		"description": "La X è stata cancellata e ridisegnata quattro volte.",
		"base_value": 80,
		"variance": 60,
		"category": "mistero",
	},
	{
		"name": "Parcheggio sulla Luna",
		"description": "Posto coperto, vista Terra. Raggiungerlo resta responsabilità dell'acquirente.",
		"base_value": 90,
		"variance": 55,
		"category": "immobile",
	},
	{
		"name": "Meteorite quasi autentico",
		"description": "Il certificato dice 'probabilmente caduto dall'alto'.",
		"base_value": 100,
		"variance": 60,
		"category": "mistero",
	},
	{
		"name": "Dominio pizzza.com",
		"description": "Il venditore assicura che la terza z è il futuro del branding.",
		"base_value": 70,
		"variance": 55,
		"category": "tecnologia",
	},
	{
		"name": "Isola con alta marea",
		"description": "Due volte al giorno diventa un'esclusiva esperienza subacquea.",
		"base_value": 115,
		"variance": 70,
		"category": "immobile",
	},
	{
		"name": "Diritti cinematografici di un sogno",
		"description": "Trama confusa, protagonista carismatico, finale ancora da scrivere.",
		"base_value": 75,
		"variance": 55,
		"category": "arte",
	},
	{
		"name": "Ritratto attribuito a qualcuno",
		"description": "Gli esperti concordano che sia stato dipinto con della vernice.",
		"base_value": 95,
		"variance": 75,
		"category": "arte",
	},
	{
		"name": "Società senza dipendenti",
		"description": "Costi bassissimi. Anche i ricavi mostrano grande disciplina.",
		"base_value": 85,
		"variance": 60,
		"category": "impresa",
	},
	{
		"name": "Macchina del tempo in avanti",
		"description": "Viaggia nel futuro alla velocità esatta di un secondo al secondo.",
		"base_value": 60,
		"variance": 50,
		"category": "tecnologia",
	},
	{
		"name": "Bottiglia forse di Napoleone",
		"description": "È francese, è vecchia e ha un cappello piccolo disegnato sull'etichetta.",
		"base_value": 90,
		"variance": 70,
		"category": "arte",
	},
	{
		"name": "Capra con profilo social",
		"description": "Ottantamila follower. Quasi tutti interessati alle recinzioni.",
		"base_value": 110,
		"variance": 55,
		"category": "animale",
	},
]


static func make_lot(source: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var lot := source.duplicate(true)
	lot["value"] = maxi(20, int(source["base_value"]) + rng.randi_range(-int(source["variance"]), int(source["variance"])))
	return lot


static func make_clues(value: int, player_count: int, rng: RandomNumberGenerator) -> Array[String]:
	var clues: Array[String] = []
	var clue_types := [0, 1, 2, 3, 4, 5]
	clue_types.shuffle()

	for index in player_count:
		var clue_type: int = clue_types[index % clue_types.size()]
		match clue_type:
			0:
				var spread := rng.randi_range(25, 45)
				clues.append("Una perizia colloca il valore tra %d e %d crediti." % [maxi(0, value - spread), value + spread])
			1:
				var margin := rng.randi_range(10, 28)
				clues.append("Una fonte affidabile sostiene che valga almeno %d crediti." % maxi(0, value - margin))
			2:
				var margin := rng.randi_range(10, 28)
				clues.append("Secondo i registri, non dovrebbe valere più di %d crediti." % (value + margin))
			3:
				var estimate := value + rng.randi_range(-18, 18)
				clues.append("Un collezionista lo comprerebbe per circa %d crediti." % maxi(0, estimate))
			4:
				var threshold := maxi(10, int(round(value / 20.0)) * 20)
				if value >= threshold:
					clues.append("Un esperto conferma che il valore è almeno %d crediti." % threshold)
				else:
					clues.append("Un esperto esclude che il valore raggiunga %d crediti." % threshold)
			_:
				var refused_offer := maxi(5, value - rng.randi_range(15, 35))
				clues.append("Il proprietario ha già rifiutato un'offerta da %d crediti." % refused_offer)

	return clues


static func make_objective(player_index: int, players: Array[Dictionary], lot: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var available_types: Array[String] = []
	if int(players[player_index]["cash"]) >= 5:
		available_types.append_array(["buy_profit", "win_lot", "bold_bid"])
	var funded_rivals: Array[int] = []
	var overpay_rivals: Array[int] = []
	for index in players.size():
		if index == player_index:
			continue
		if int(players[index]["cash"]) >= 5:
			funded_rivals.append(index)
			available_types.append("make_rival_buy")
		if int(players[index]["cash"]) > int(lot["value"]):
			overpay_rivals.append(index)
			available_types.append("make_rival_overpay")
	if available_types.is_empty():
		available_types.append("abstain")
	var objective_type: String = available_types[rng.randi_range(0, available_types.size() - 1)]

	match objective_type:
		"buy_profit":
			return {
				"type": objective_type,
				"bonus": 24,
				"text": "Compra il lotto senza pagarlo più del suo valore reale.",
			}
		"make_rival_buy":
			var buy_target: int = funded_rivals[rng.randi_range(0, funded_rivals.size() - 1)]
			return {
				"type": objective_type,
				"target": buy_target,
				"bonus": 18,
				"text": "Fai aggiudicare il lotto a %s." % players[buy_target]["name"],
			}
		"make_rival_overpay":
			var overpay_target: int = overpay_rivals[rng.randi_range(0, overpay_rivals.size() - 1)]
			return {
				"type": objective_type,
				"target": overpay_target,
				"bonus": 30,
				"text": "Fai spendere a %s più del valore reale del lotto." % players[overpay_target]["name"],
			}
		"win_lot":
			return {
				"type": objective_type,
				"bonus": 14,
				"text": "Aggiudicati questo lotto, a qualsiasi prezzo.",
			}
		"bold_bid":
			var raw_threshold := mini(int(players[player_index]["cash"]), maxi(35, int(lot["value"] * 0.65)))
			var threshold := maxi(5, int(floor(raw_threshold / 5.0)) * 5)
			return {
				"type": objective_type,
				"threshold": threshold,
				"bonus": 16,
				"text": "Fai un'offerta di almeno %d crediti, anche senza vincere." % threshold,
			}
		_:
			return {
				"type": "abstain",
				"bonus": 8,
				"text": "Non aggiudicarti questo lotto.",
			}


static func objective_completed(objective: Dictionary, player_index: int, winner_index: int, winning_bid: int, bids: Array[int], value: int) -> bool:
	match String(objective["type"]):
		"buy_profit":
			return winner_index == player_index and winning_bid <= value
		"make_rival_buy":
			return winner_index == int(objective["target"])
		"make_rival_overpay":
			return winner_index == int(objective["target"]) and winning_bid > value
		"win_lot":
			return winner_index == player_index
		"bold_bid":
			return bids[player_index] >= int(objective["threshold"])
		"abstain":
			return winner_index != player_index
	return false
