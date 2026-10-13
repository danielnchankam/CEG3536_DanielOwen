# CEG 3536 — Laboratoire 1 — CORRIGÉ (réservé aux assistants)

Ne pas distribuer aux étudiants. Ce projet est le projet de démarrage
`CEG3536_Lab1_Demarrage` avec les exigences E2 à E9 implémentées dans
`Core/Src/buttons.s`, `Core/Src/estop.s` et `Core/Src/fsm.s`. Les autres
fichiers sont identiques au projet de démarrage.

Le projet compile sans avertissement dans STM32CubeIDE 2.2.0 (Debug et Release)
et par le `Makefile` (STM32CubeCLT 1.21.0). **Il a été exécuté sur la plateforme
Leafy le 15 septembre 2026** : T1 à T10 réussis avec boutons simulés par SWD
(détails dans `JOURNAL.md` et `essais/`), **puis revalidé le 12 octobre 2026**
après les corrections de la version 1.2 (voir la section « Modifications »). Au repos, PC13, PB2 et PB5 lisent 0,
ce qui est cohérent avec « appuyé = 1 » et `BTN_x_PUPDR` = 0 ; le niveau appuyé
reste à confirmer par un appui physique (T4). `DELAY_BOUCLES_PAR_MS` a été
calibrée à 1270 au compteur de cycles DWT (période de scrutation 0,999 ms à
4 MHz, contre 0,798 ms avec la valeur de départ 1000) ; à confirmer à
l'oscilloscope (E8). Le projet de démarrage garde 1000 : la calibration est
exigée des étudiants.

## Note sur les ports du débogueur (CubeIDE)

Si le lancement du débogage échoue avec « ST-LINK GDB server failed to start
(exit code = 0) » ou « Error in initializing ST-LINK device. Reason: (0)
Unknown » alors que STM32CubeProgrammer se connecte à la carte, le message est
trompeur : c'est en général le port TCP du serveur GDB qui est inaccessible.
Windows (Hyper-V, WSL) réserve au démarrage des plages de ports dynamiques
visibles avec `netsh int ipv4 show excludedportrange protocol=tcp`, et le port
par défaut de CubeIDE (61234, SWO 61235) tombe parfois dedans. Ces plages
changent à chaque redémarrage, d'où un problème intermittent.

`CEG3536_Lab1_Corrige Debug.launch` utilise donc les ports 61334 (GDB) et
61335 (SWO), observés hors plage réservée le 12 octobre 2026. Si le problème
revient : Debug Configurations → onglet Debugger → « Port number », choisir un
port absent des plages affichées par `netsh`.

## Ce que réalise chaque routine

| Exigence | Routine | Réalisation |
|---|---|---|
| E1 | `fsm_init` | ARRÊT, variables à zéro, rouge seule par `fsm_maj_del` |
| E2 | `fsm_step` (partie C, hors urgence) | ARRÊT → AVANT ou ARRIÈRE selon `prochain_sens` (alterne), AVANT/ARRIÈRE → ARRÊT ; `compteur_transitions++` à chaque changement d'état |
| E3 | `button_pressed` | Compte les échantillons consécutifs différents du niveau validé ; validation après `ANTIREBOND_MS` (30) appels ; un appui maintenu = un seul événement ; le relâchement est validé de la même façon sans événement |
| E4 | `estop_init`, `EXTI2_IRQHandler` | EXTI_EXTICR1 (champ EXTI2 = port B), RTSR1 ou FTSR1 selon le niveau actif (`.if` sur `BTN_ESTOP_ACTIF_HAUT`), IMR1, priorité NVIC 0, ISER0 ; ISR : verte et bleue éteintes, rouge allumée par BSRR, `estop_flag = 1`, effacement RPR1/FPR1, `dsb` |
| E5 | `fsm_step` (partie A), `fsm_maj_del` | Entrée en urgence : phase = rouge allumée, compteur = 0 ; bascule toutes les 250 appels ; User lu mais ignoré ; à chaque bascule, `blink_cycles` = écart de `DWT_CYCCNT` depuis la bascule précédente (T6, demi-période ≈ 1 000 000 cycles à 4 MHz) |
| E6 | `fsm_step` (partie C, urgence) | Touch En validé ET `button_raw(BTN_ESTOP) == 0` → ARRÊT ; E-Stop maintenu → refus, clignotement continu ; aucune reprise automatique |
| E7 | `fsm_step` (partie C), `fsm_maj_del` | `touch_enabled ^= 1`, `touch_signal_compteur = 100` → `LED_AUCUNE` pendant 100 appels puis DEL de l'état |
| E8 | `delay_ms` | Boucle calibrée : 1270 itérations d'environ 3 cycles + `fsm_step` (≈ 190 cycles, 50 µs) = 3998 cycles, soit 0,999 ms à 4 MHz |
| E9 | `led_set`, `fsm_step`, `fsm_maj_del` | `led_set` éteint tout avant d'allumer une DEL ; après `led_set` hors urgence, `fsm_maj_del` relit `estop_flag` et réaffirme l'état sûr (`led_set(LED_ROUGE)`) si l'ISR est survenue pendant le pas, y compris entre les deux écritures BSRR de `led_set` : la dernière écriture sur les DEL est toujours l'état sûr ; seul le chemin E6 quitte l'urgence ; un second E-Stop en urgence (ou les rebonds du relâchement) consomme le drapeau sans transition ni relance du clignotement |

## Comportements à vérifier lors des démonstrations (T1 à T10)

- **T3** : `compteur_transitions` (watch) augmente exactement de 1 par appui validé ; un appui maintenu 2 s n'ajoute que 1. Un rebond plus court que 30 ms ne crée pas d'événement.
- **T5** : la mise en état sûr est faite dans l'ISR, donc le délai PB2 → PC7/PB7 est de quelques microseconde même si la boucle est dans `delay_ms`. Une équipe qui met la DEL en sécurité seulement dans `fsm_step` aura un délai jusqu'à 1 ms plus la durée de la boucle : acceptable (< 10 ms) mais niveau « satisfaisant » au critère A4.
- **T6** : période 500 ms ± 10 % dépend de la calibration de `delay_ms` ; la mesure doit être rapportée (E8, C4). Le corrigé expose `blink_cycles` (watch), écart de `DWT_CYCCNT` entre deux basculements de la rouge : c'est une **demi-période**, la période vaut 2 × `blink_cycles` / 4 000 000 s. Valeurs relevées le 12 octobre 2026 : 1 000 268 à 1 001 114 cycles, soit 250,1 à 250,3 ms (2,0 Hz). Une équipe qui mesure à l'oscilloscope ou par SWD sans variable reste acceptable si la méthode est décrite.
- **T7** : Touch En avec E-Stop maintenu doit être refusé : vérifier que `button_raw` et non `button_pressed` est utilisé pour tester l'état d'E-Stop.
- **T8** : User pendant l'urgence ne change ni `etat` ni `compteur_transitions`.
- **T10** : appuis simultanés User et Touch En hors urgence : les deux événements sont traités dans le même pas (transition puis bascule de `touch_enabled` avec extinction brève) ; jamais deux DEL allumées. E-Stop pendant une transition : l'ISR force l'état sûr, et `fsm_maj_del` le réaffirme en fin de pas si `estop_flag` est levé, ce qui ferme la fenêtre où `led_set` rallumerait la DEL de l'ancien état (voir « Erreurs fréquentes »). Un second E-Stop en urgence ne compte pas de transition et ne perturbe pas la période.

## Erreurs fréquentes attendues chez les étudiants

- Chercher `SYSCFG_EXTICR` : sur la STM32L5, le registre est `EXTI_EXTICR1` (offset 0x60 de 0x4002F400).
- Effacer la requête dans le mauvais registre : `RPR1` pour un front montant, `FPR1` pour un front descendant ; le corrigé efface les deux.
- Priorité NVIC écrite sur 32 bits à `0xE000E400 + 13` au lieu d'un octet (`strb`) : écrase les priorités des IRQ 13 à 16.
- `push {r4, lr}` puis appel d'une routine : correct ; `push {r4, r5, lr}` (12 octets) puis appel : pile non alignée sur 8 aux interfaces publiques (B2).
- Anti-rebond par simple attente de 20 ms dans `button_pressed` : bloque la boucle et fausse le clignotement ; la version par échantillons ne bloque jamais.
- `cbz`/`cbnz` vers une étiquette trop éloignée : erreur d'assemblage ; utiliser `cmp` + `beq`.
- Mise à jour des DEL dispersée dans `fsm_step` au lieu d'un seul point (`fsm_maj_del`) : critère B3.
- Course entre l'ISR et `led_set` : `led_set` éteint tout puis allume ; si l'ISR E-Stop survient entre les deux écritures (ou après la lecture du drapeau dans `fsm_step`), la boucle rallume la DEL de l'ancien état par-dessus l'état sûr jusqu'au pas suivant (deux DEL allumées pendant au plus 1 ms, fenêtre rare). Le corrigé relit `estop_flag` après `led_set` et réaffirme l'état sûr. Une équipe qui ne traite pas ce cas reste dans les 10 ms de E4 ; à signaler au critère A4/B4 sans pénalité majeure.
- Relance du clignotement à chaque E-Stop en urgence : les rebonds du relâchement d'E-Stop (fronts montants) relancent alors la phase et faussent la mesure T6 ; le corrigé consomme le drapeau sans rien changer quand l'état est déjà URGENCE.
- Mesurer T6 sans variable : l'énoncé attend `blink_cycles` (écart de `DWT_CYCCNT` à chaque basculement) en watch ; DWT exige `DEMCR.TRCENA` puis `DWT_CTRL.CYCCNTENA`.

## Modifications de la version 1.2 (12 octobre 2026)

Revue du corrigé contre l'énoncé v1.2 (CEG3536_Lab1_Automne_2026_v1.2.docx) :

- `fsm.s`, `fsm_maj_del` : après `led_set` hors urgence, relecture de `estop_flag` et réaffirmation de l'état sûr (E4, E9 : jamais deux DEL allumées, quel que soit l'instant de l'ISR).
- `fsm.s`, `fsm_step` partie A : un E-Stop reçu alors que l'état est déjà URGENCE consomme le drapeau sans relancer la phase du clignotement (période T6 stable malgré les rebonds du relâchement).
- `fsm.s`, `fsm_init`, `fsm_maj_del` : variable globale `blink_cycles` (T6) alimentée par `DWT_CYCCNT` à chaque basculement de la rouge ; DWT activé dans `fsm_init`. Constantes `DEMCR`, `DWT_CTRL`, `DWT_CYCCNT` ajoutées à `registres.inc`.
- `registres.inc` : commentaire de `EXTICR1_EXTI2_POS` corrigé (champ de 8 bits, bits 23:16).
- `estop.s` : commentaire de l'ISR précisant pourquoi la cause n'est pas relue (vecteur dédié à la ligne 2).
- `lab1.h` : `blink_cycles`, `btn_valide` et `btn_compteur` déclarés.
- `essais/` : `vars.sh` lit `blink_cycles` ; `estop.sh` simule E-Stop (SWIER1 ou PB2) et Touch En (PB5).

Revalidé sur carte le 12 octobre 2026 (voir `JOURNAL.md`) : T1, T2, T5, T6, T7, T10 (second E-Stop) réussis ; compilation sans avertissement (Makefile).
