# JOURNAL.md — Journal d'équipe, CEG 3536, laboratoire 1 (automne 2026)

Équipe : `<NomA>` et `<NomB>` — Section : `A01 / A02` — Dépôt Git : `<adresse>`

## Jalon J1 (au plus tard le vendredi 25 septembre 2026, validé dans Git)

### Exigences de l'équipe
| Id | Exigence (reformulée par l'équipe) | Critère d'acceptation | Hypothèses |
|---|---|---|---|
| E1 | | | |
| E2 | | | |
| E3 | | | |
| E4 | | | |
| E5 | | | |
| E6 | | | |
| E7 | | | |
| E8 | | | |
| E9 | | | |

### Rôles et rotation
| Séance | Réalise | Valide (essais, mesures, relecture) |
|---|---|---|
| Séance 0 | | |
| Séance 1 | | |
| Séance 2 | | |

### Échéancier des laboratoires 1 à 5
| Laboratoire | Séances | Démonstration | Remise | Responsable du suivi |
|---|---|---|---|---|
| 1 | | | 9 octobre 2026 | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |

## Journal des séances

### Validation du corrigé sur carte — 2026-09-15
- Objectifs : exécuter le corrigé sur la plateforme Leafy, vérifier T1 à T10, calibrer `delay_ms` (E8).
- Matériel : NUCLEO-L552ZE-Q, ST-LINK/V2-1 intégré (firmware V2J47M34), cible STM32L552ZE rév. Z, 3,25 V. Option bytes : `TZEN` = 0, RDP niveau 0.
- Outils : STM32CubeCLT 1.21.0 (make, STM32CubeProgrammer 2.22.0), Git Bash.
- Méthode : programmation par `make flash`, puis lectures et écritures SWD en mode HOTPLUG sans arrêter le processeur. User et Touch En simulés en mettant PC13 et PB5 temporairement en sortie ; E-Stop par `EXTI_SWIER1` et par PB2 en sortie. Broches remises en entrée après chaque essai.
- Mesure E8 : compteur de cycles DWT (`DEMCR.TRCENA`, `DWT_CTRL.CYCCNTENA`) lu avec `clignote_compteur` pendant l'urgence.

| `DELAY_BOUCLES_PAR_MS` | Cycles par pas | Période de scrutation | Anti-rebond effectif | Clignotement |
|---|---|---|---|---|
| 1000 (valeur de départ) | 3192 | 0,798 ms | 24 ms | 2,5 Hz |
| 1270 (retenue) | 3998 | 0,999 ms | 30 ms | 2,0 Hz |

- Décision : `DELAY_BOUCLES_PAR_MS` = 1270 dans `registres.inc`. La boucle interne coûte environ 3 cycles par itération et `fsm_step` avec les appels environ 190 cycles (≈ 50 µs).
- Limites : horloge MSI supposée à 4,000 MHz, à confirmer à l'oscilloscope. Niveau des boutons appuyés, durée de rebond de PC13 et délai PB2 → sorties non mesurés (pas d'appui physique ni d'oscilloscope).

### Corrections et revalidation du corrigé — 2026-10-12
- Objectifs : revue du corrigé contre l'énoncé v1.2 ; corriger les écarts ; revalider sur carte.
- Matériel et outils : mêmes que le 15 septembre ; ST-LINK firmware V2J48M35 ; STM32CubeIDE 2.2.0 (ports GDB 61334/61335, voir `LISEZMOI.md`).
- Écarts trouvés : (1) course entre l'ISR E-Stop et `led_set` (deux DEL allumées possibles pendant au plus 1 ms, E9) ; (2) relance du clignotement à chaque E-Stop en urgence, donc par les rebonds du relâchement (T6) ; (3) absence de la variable `blink_cycles` attendue par T6 ; (4) commentaire erroné sur la largeur du champ EXTI2 de `EXTI_EXTICR1`.
- Décisions : `fsm_maj_del` relit `estop_flag` après `led_set` et réaffirme l'état sûr ; un E-Stop en urgence consomme le drapeau sans rien changer ; `blink_cycles` alimentée par `DWT_CYCCNT` à chaque basculement, DWT activé dans `fsm_init` ; `lab1.h` complété.
- Essais et mesures (boutons simulés par SWD, `essais/estop.sh`, `essais/user.sh`, `essais/vars.sh`) :

| Essai | Résultat observé | Verdict |
|---|---|---|
| T1 | Après réinitialisation : `etat` = 0, variables à 0, `blink_cycles` = 0, rouge seule | Réussi |
| T5 | E-Stop par `EXTI_SWIER1` : `etat` = 3, `compteur_transitions` = 1, `estop_flag` consommé, rouge seule | Réussi |
| T6 | `blink_cycles` lu trois fois pendant le clignotement : 1 001 018, 1 000 306, 1 001 070 cycles (demi-période 250,1 à 250,3 ms à 4 MHz, période 500 ms, 2,0 Hz) | Réussi |
| T10 | Second E-Stop en urgence : `compteur_transitions` inchangé (1), `blink_cycles` ensuite 1 000 268 (période non perturbée) | Réussi |
| T7 | PB2 maintenu à 1 puis Touch En : `etat` reste 3, compteur inchangé ; PB2 relâché puis Touch En : `etat` = 0, compteur = 2, rouge fixe | Réussi |
| T2 | Deux appuis User après acquittement : ARRÊT → AVANT (verte, compteur 3) → ARRÊT (rouge, compteur 4), `prochain_sens` = 1 | Réussi |

- Limites : la fenêtre de course corrigée (ISR entre les deux écritures de `led_set`) n'est pas reproductible par SWD ; la correction est justifiée par analyse (la dernière écriture sur les DEL est toujours l'état sûr). Les messages « Failed to download data » de STM32_Programmer_CLI lors des écritures dans `EXTI_SWIER1` ou `GPIOx_BSRR` sont des échecs de relecture de registres en écriture seule : les écritures ont pris effet.

### Séance 0 — `<date>` — réalise : `<nom>` / valide : `<nom>`
- Objectifs :
- Fait :
- Décisions :
- Difficultés et solutions :
- Essais et mesures :
- Validations Git (auteur, message) :

### Séance 1 — `<date>` — réalise : `<nom>` / valide : `<nom>`
- Objectifs :
- Fait :
- Décisions :
- Difficultés et solutions :
- Essais et mesures :
- Validations Git :

### Séance 2 — `<date>` — réalise : `<nom>` / valide : `<nom>`
- Objectifs :
- Fait :
- Décisions :
- Difficultés et solutions :
- Essais et mesures :
- Validations Git :

## Tableau des essais (T1 à T10)

Essais du corrigé sur NUCLEO-L552ZE-Q + Leafy, le 15 septembre 2026. Boutons
simulés par SWD (voir la section de validation ci-dessus et `essais/`).
Tous les essais ont été faits avec `DELAY_BOUCLES_PAR_MS` = 1000. Après
calibration à 1270, le déclenchement E-Stop, la mesure du clignotement (E8) et
un acquittement ont été refaits avec le même résultat.

| Essai | Date | Résultat observé | Verdict | Preuve (fichier) |
|---|---|---|---|---|
| T1 Réinitialisation | 2026-09-15 | `RCC_AHB2ENR` = 0x7 ; PA9, PC7, PB7 en sortie push-pull ; PC13, PB2, PB5 en entrée ; `etat` = ARRÊT, variables à 0 ; ODR : PA9 = 1, PC7 = 0, PB7 = 0 (rouge seule) | Réussi | Lecture SWD, `essais/vars.sh` |
| T2 Cycle User | 2026-09-15 | 4 appuis : ARRÊT → AVANT (verte) → ARRÊT (rouge) → ARRIÈRE (bleue) → ARRÊT ; `compteur_transitions` +4 ; `prochain_sens` alterne ; une seule DEL allumée à chaque lecture | Réussi | `essais/user.sh press/release` |
| T3 Anti-rebond | 2026-09-15 | Impulsion PC13 plus courte que la fenêtre (deux écritures SWD consécutives, durée non mesurée, < 30 ms) : aucune transition, compteur inchangé. Appui maintenu : un seul événement | Réussi | `essais/user.sh pulse` |
| T4 Niveaux logiques | 2026-09-15 | Relâché : PC13 = 0, PB2 = 0, PB5 = 0 dans IDR. Tirage haut interne sur PB5 : IDR reste à 0, donc tirage bas externe. Cohérent avec « appuyé = 1 » et `BTN_x_PUPDR` = 0. **Niveau appuyé non mesuré** (aucun appui physique) | Partiel | Lecture `GPIOx_IDR` par SWD |
| T5 E-Stop | 2026-09-15 | `EXTI_EXTICR1` = 0x00010000 (ligne 2 = port B), `RTSR1` bit 2, `IMR1` bit 2, `NVIC_ISER0` bit 13, priorité IRQ 13 = 0. Déclenché par `EXTI_SWIER1` puis par un front montant réel sur PB2 : verte et bleue éteintes, rouge allumée, `estop_flag` consommé, `etat` = URGENCE, compteur +1. Délai PB2 → sorties non mesuré | Réussi | Lecture SWD registres EXTI/NVIC |
| T6 Clignotement | 2026-09-15 | PA9 alterne avec `clignote_phase`. Après calibration : bascule tous les 250 pas de 0,999 ms, soit une période de 500 ms (2,0 Hz). Avant calibration : 399 ms (2,5 Hz). Depuis le 2026-10-12, `blink_cycles` (watch) donne directement la demi-période en cycles DWT : 1 000 300 ± 500 cycles | Réussi | `essais/dwt_apres_1270.txt`, section du 2026-10-12 |
| T7 Acquittement | 2026-09-15 | Touch En validé avec PB2 maintenu à 1 : refusé, reste en URGENCE. PB2 relâché puis Touch En : `etat` = ARRÊT, rouge fixe, compteur +1 | Réussi | `essais/vars.sh` |
| T8 User ignoré en urgence | 2026-09-15 | Appui User en URGENCE : `etat` = 3 et `compteur_transitions` inchangés, clignotement continu | Réussi | `essais/user.sh press/release` |
| T9 Touch En hors urgence | 2026-09-15 | `touch_enabled` 0 → 1 au 1er appui, 1 → 0 au 2e ; `touch_signal_compteur` observé de 97 à 0 avec PA9 éteinte, puis rouge rallumée ; `etat` inchangé | Réussi | Lectures SWD rapprochées |
| T10 Robustesse | 2026-09-15 | Second E-Stop en URGENCE : phase relancée sans transition comptée (comportement remplacé le 2026-10-12 : drapeau consommé sans relance). Bilan de la séquence complète : 12 transitions = 8 User + 2 E-Stop + 2 acquittements. Jamais deux DEL allumées dans les lectures. Appuis simultanés User + Touch En non essayés | Réussi (partiel) | `essais/vars.sh` |

## Routine conservée pour L3-A
- Routine : `button_pressed` ou `led_set`
- Interface :
- Cas d'essai :

## Déclaration des sources et de l'usage d'outils d'IA générative
- Sources :
- Outils d'IA (outil, version, usage) ou « aucun usage » :
