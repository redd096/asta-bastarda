# Asta Bastarda

Prototipo pass-and-play per Godot 4, giocabile da 2 a 6 persone su un solo dispositivo.

## Come avviarlo

1. Installa Godot 4.2 o successivo.
2. Apri Godot e scegli **Importa**.
3. Seleziona il file `project.godot` di questa cartella.
4. Premi **F6/F5** oppure il pulsante ▶.

Non servono plugin, asset esterni o font aggiuntivi.

## Regole

- Tutti partono con 240 crediti.
- La partita dura 6 aste.
- Prima di ogni asta ciascuno legge in segreto un indizio e un incarico.
- Durante i 45 secondi di trattativa si può dire la verità, mentire o tacere.
- Ognuno inserisce poi un'offerta segreta passando il dispositivo.
- L'offerta più alta vince. In caso di parità il vincitore viene sorteggiato.
- Alla fine vince il patrimonio maggiore: **denaro + valore degli oggetti + bonus**.

## Struttura

- `project.godot`: configurazione del progetto.
- `main.tscn`: tutta la UI del gioco, organizzata in schermate `Control` modificabili dall'editor.
- `scripts/main.gd`: stato della partita e collegamento tra logica e nodi della scena.
- `scripts/game_data.gd`: oggetti, indizi, incarichi e bilanciamento.

## Modifiche rapide

In `scripts/game_data.gd` puoi cambiare:

- `STARTING_CASH`: denaro iniziale;
- `ROUND_COUNT`: numero di aste;
- `DISCUSSION_SECONDS`: durata della trattativa;
- `ITEMS`: elenco e valori dei lotti;
- gli incarichi e le relative ricompense.

L'interfaccia è costruita interamente con nodi `Control` dentro `main.tscn`: colori, margini, pannelli, campi e pulsanti possono essere modificati dall'Inspector. Lo script non crea elementi grafici a runtime e si limita ad aggiornare testi, visibilità e risultati. La UI è responsive e usa uno `ScrollContainer` per adattarsi anche allo schermo di un telefono.

### Modificare le schermate

Dentro `main.tscn`, il nodo `Pages` contiene:

- `SetupPage`
- `LotIntroPage`
- `HandoffPage`
- `SecretPage`
- `DiscussionPage`
- `BidPage`
- `ResultsPage`
- `GameOverPage`

Sono tutte presenti nella scena; durante la partita lo script mostra soltanto quella relativa alla fase corrente. Per lavorare su una schermata nell'editor basta renderla temporaneamente visibile dall'Inspector.

## Idee per una seconda versione

- modalità con un solo incarico valido per tutta la partita;
- eventi pubblici tra un'asta e l'altra;
- indizi falsi dichiarati come potenzialmente inaffidabili;
- oggetti che si combinano in collezioni;
- modalità PC con gamepad multipli;
- suoni e vibrazione durante la rivelazione.

## UI reponsive

La UI supporta automaticamente portrait e landscape.

- Il progetto usa una risoluzione base quadrata `540×540`, così la scala rimane coerente ruotando il dispositivo.
- Su telefono l'orientamento è impostato su `Sensor`: basta ruotare il dispositivo.
- Su desktop la finestra iniziale è portrait (`540×960`) ma rimane ridimensionabile.
- In portrait i pulsanti occupano tutta la larghezza; in landscape il contenuto viene centrato e limitato a 900 unità.
