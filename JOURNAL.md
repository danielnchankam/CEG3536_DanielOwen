# JOURNAL.md — Journal d'équipe, CEG 3536, laboratoire 1 (automne 2026)

Équipe : `Owen Ouoba` et `Daniel Nchankam` — Section : `A02` — Dépôt Git : `https://github.com/danielnchankam/CEG3536_DanielOwen`

Projet STM32CubeIDE : `CEG3536_Lab1_DanielOwen` (code de départ du cours cité comme source).

## Jalon J1 (au plus tard le vendredi 25 septembre 2026, validé dans Git)

### Exigences de l'équipe
| Id | Exigence (reformulée par l'équipe) | Critère d'acceptation | Hypothèses |
|---|---|---|---|
| E1 | Après NRST ou mise sous tension, le système démarre en ARRÊT : seule la DEL rouge (PA9) est allumée. | Rouge seule allumée en moins de 100 ms après le relâchement de uC Reset (T1); `etat = 0` dans le débogueur. | Horloge MSI 4 MHz après réinitialisation; `gpio_init` éteint toutes les DEL avant `fsm_init`. |
| E2 | Chaque appui validé sur User (PC13) fait défiler ARRÊT → MARCHE_AVANT → ARRÊT → MARCHE_ARRIÈRE → ARRÊT; le changement de sens passe toujours par ARRÊT. | 4 appuis donnent rouge → verte → rouge → bleue → rouge (T2); une seule DEL allumée à chaque pas (ODR). | Variable `prochain_sens` (.bss) alterne avant/arrière à partir d'ARRÊT; `compteur_transitions++` à chaque transition. |
| E3 | Anti-rebond logiciel et détection de front : un appui (même maintenu) = un seul événement. | Fenêtre de 30 ms (dans 20–50 ms); 20 appuis → `compteur_transitions` = 20; appui maintenu 2 s → 1 transition (T3). | `fsm_step` appelé toutes les 1 ms (`PERIODE_SCRUTATION_MS`); niveau stable 30 échantillons consécutifs avant validation. |
| E4 | E-Stop (PB2) déclenche EXTI2 de priorité maximale; l'ISR met les sorties en état sûr (verte/bleue éteintes, rouge allumée), lève `estop_flag`, efface la requête; la boucle principale passe en ARRÊT_URGENCE. | Point d'arrêt atteint dans `EXTI2_IRQHandler` même pendant `delay_ms`; verte/bleue éteintes en < 10 ms (T5); `estop_flag` consommé par `fsm_step`. | Priorité NVIC 0 (la plus élevée); front choisi selon `BTN_ESTOP_ACTIF_HAUT` (à confirmer en T4); EXTICR1 dans EXTI sur la L5. |
| E5 | En ARRÊT_URGENCE, la rouge clignote à 2 Hz (250 ms / 250 ms ± 10 %), verte et bleue éteintes, User ignoré. | Période mesurée 500 ms ± 50 ms (T6, DWT_CYCCNT); appuis User sans effet sur `etat` (T8). | Clignotement compté en pas de scrutation (250 pas de 1 ms); `button_pressed(USER)` appelé quand même pour entretenir l'anti-rebond. |
| E6 | Un appui validé sur Touch En (PB5) avec E-Stop relâché ramène en ARRÊT; refusé tant que E-Stop est maintenu; aucune reprise automatique. | Touch En + E-Stop relâché → `etat = 0`, rouge fixe; Touch En + E-Stop maintenu → reste en urgence (T7). | E-Stop relâché vérifié par `button_raw(BTN_ESTOP) == 0` au moment de l'acquittement. |
| E7 | Hors urgence, chaque appui validé sur Touch En inverse `touch_enabled` (0/1) et éteint brièvement (100 ms) la DEL active. | Deux appuis en ARRÊT : `touch_enabled` 0 → 1 → 0 (watch), extinction brève visible (T9). | Extinction gérée par `touch_signal_compteur` (100 pas) dans `fsm_maj_del`; `etat` inchangé. |
| E8 | Toutes les durées proviennent de `delay_ms` (boucle calibrée), dont la calibration est documentée. | `DELAY_BOUCLES_PAR_MS` calibré et rapporté (fréquence, cycles/itération); période de clignotement mesurée cohérente. | MSI 4 MHz, code en flash; SysTick prévu au laboratoire 2. |
| E9 | Le système reste cohérent en cas d'appuis simultanés ou d'E-Stop pendant un clignotement ou une transition. | Jamais deux DEL allumées; jamais de sortie d'ARRÊT_URGENCE sans acquittement (T10). | `led_set` éteint tout avant d'allumer une seule DEL; `fsm_maj_del` est le seul point d'appel de `led_set`. |

### Rôles et rotation
Règle : à chaque séance, un membre **réalise** et l'autre **valide** (essais, relecture, mesures); les rôles sont inversés à la séance suivante. Chaque membre valide ses propres modifications sous son nom dans Git.

| Séance | Réalise | Valide (essais, mesures, relecture) |
|---|---|---|
| Séance 0 (15 sept.) | Owen Ouoba | Daniel Nchankam |
| Séance 1 (22 sept.) | Daniel Nchankam | Owen Ouoba |
| Séance 2 (29 sept.) | Owen Ouoba | Daniel Nchankam |

Répartition des modules (responsable principal / relecteur) :

| Module | Responsable | Relecteur |
|---|---|---|
| `gpio.s` (gpio_init, led_set), `registres.inc` | Daniel | Owen |
| `buttons.s` (button_raw, button_pressed, delay_ms) | Owen | Daniel |
| `estop.s` (estop_init, EXTI2_IRQHandler) | Daniel | Owen |
| `fsm.s` (fsm_init, fsm_step, fsm_maj_del) | Owen | Daniel |
| Rapport, tableau des essais, fiche périphérique | Les deux (rédaction partagée) | Les deux |

### Échéancier des laboratoires 1 à 5
Dates des laboratoires 2 à 5 prévisionnelles; elles seront ajustées dès leur publication sur Brightspace.

| Laboratoire | Séances | Démonstration | Remise | Responsable du suivi |
|---|---|---|---|---|
| 1 — Panneau de commande (GPIO, boutons, E-Stop) | 15, 22, 29 sept. | 29 sept. (séance 2) | 9 octobre 2026 | Owen |
| 2 — Commande du moteur (SysTick, mêmes états) | ~6 oct. → ~27 oct. | Séance 2 du labo 2 | ~6 nov. (à confirmer) | Daniel |
| 3 — Appel des routines depuis le C (L3-A) | ~3 nov. → ~17 nov. | Séance 2 du labo 3 | ~20 nov. (à confirmer) | Owen |
| 4 — TouchPad (autorisation `touch_enabled`) | ~17 nov. → ~24 nov. | Séance 2 du labo 4 | ~27 nov. (à confirmer) | Daniel |
| 5 — Intégration / démonstration finale (L5-D) | ~1 déc. → ~8 déc. | Démonstration finale | ~9 déc. (fin du cours) | Les deux |

Jalons internes du laboratoire 1 :
- 25 sept. : J1 (exigences, rôles, échéancier) validé dans Git; E1, E2, E3 fonctionnels, niveaux IDR relevés (T4).
- 29 sept. : E4 à E9 démontrés devant l'assistant; fiche périphérique remplie.
- 6 oct. : tableau des essais T1–T10 avec preuves (dossier `preuves/`), brouillon du rapport.
- 9 oct., 23 h 59 : remise du rapport et de l'archive sur Brightspace.

## Journal des séances

### Séance 0 — 15 septembre 2026 — réalise : Owen Ouoba / valide : Daniel Nchankam
- Objectifs : prise en main de la plateforme Leafy et de la Nucleo; premier programme (DEL rouge); dépôt Git.
- Fait : création du projet, configuration de LD3 (PA9 en sortie), configuration du débogueur ST-LINK, création du dépôt GitHub.
- Décisions : dépôt GitHub partagé `CEG3536_DanielOwen`; rotation des rôles à chaque séance.
- Difficultés et solutions : —
- Essais et mesures : GPIOA MODER = 0xABF7FFFF après configuration (bits 19:18 = 01, PA9 en sortie); DEL rouge allumée.
- Validations Git (auteur, message) : danielnchankam — « gpio_init : configuration initiale de LD3 ».

### Séance 1 — 22 septembre 2026 — réalise : Daniel Nchankam / valide : Owen Ouoba
- Objectifs : gpio_init, led_set, button_raw, button_pressed (E3), delay_ms, machine à états E1 à E3; jalon J1.
- Fait : intégration du code de départ (structure `Core/Src`, projet `CEG3536_Lab1_DanielOwen`); `button_pressed` (anti-rebond par comptage de 30 échantillons de 1 ms, front d'appui); `fsm_step` (E2 avec `prochain_sens`, E5, E6, E7); `estop_init` et ISR (E4). Rédaction du J1.
- Décisions : fenêtre d'anti-rebond de 30 ms (milieu de 20–50 ms); `led_set` par BSRR (écriture atomique, sans lecture-modification-écriture); une seule mise à jour des DEL par pas (`fsm_maj_del`).
- Difficultés et solutions : sur la L5, EXTICR est dans EXTI (offset 0x60) et non dans SYSCFG; champ EXTI2 de 8 bits (masque 0xFF << 16).
- Essais et mesures : compilation sans avertissement; niveaux IDR de PC13, PB2, PB5 à relever (T4).
- Validations Git : OwenOuoba — « Intégration du code de départ (Core/Src) et routines E2 à E7 »; « Jalon J1 : exigences, rôles et échéancier ».

### Séance 2 — `<date>` — réalise : Owen Ouoba / valide : Daniel Nchankam
- Objectifs :
- Fait :
- Décisions :
- Difficultés et solutions :
- Essais et mesures :
- Validations Git :

## Tableau des essais (T1 à T10)
| Essai | Date | Résultat observé | Verdict | Preuve (fichier) |
|---|---|---|---|---|
| T1 Réinitialisation | | | | |
| T2 Cycle User | | | | |
| T3 Anti-rebond | | | | |
| T4 Niveaux logiques | | | | |
| T5 E-Stop | | | | |
| T6 Clignotement | | | | |
| T7 Acquittement | | | | |
| T8 User ignoré en urgence | | | | |
| T9 Touch En hors urgence | | | | |
| T10 Robustesse | | | | |

## Routine conservée pour L3-A
- Routine : `button_pressed`
- Interface : `uint32_t button_pressed(uint32_t id)` — R0 = identifiant (0 User, 1 E-Stop, 2 Touch En) → R0 = 1 si appui validé (front), 0 sinon; état conservé dans `btn_valide[3]` et `btn_compteur[3]` (.bss).
- Cas d'essai : appui franc (1 événement); rebonds < 30 ms (aucun événement parasite); appui maintenu 2 s (1 seul événement); relâchement (retourne 0); identifiant invalide (> 2 → 0).

## Déclaration des sources et de l'usage d'outils d'IA générative
- Sources : code de départ CEG3536_Lab1_Demarrage (Brightspace); RM0438 (STM32L552); PM0264 (Cortex-M33); manuel Zhu, 4e éd.; guide de la plateforme Leafy.
- Outils d'IA (outil, version, usage) ou « aucun usage » : à compléter dans le rapport.
