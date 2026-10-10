# JOURNAL.md — Journal d'équipe, CEG 3536, laboratoire 1 (automne 2026)

- **Équipe :** Owen Ouoba et Daniel Nchankam · **Section :** A02
- **Dépôt Git :** https://github.com/danielnchankam/CEG3536_DanielOwen
- **Projet STM32CubeIDE :** CEG3536_Lab1_DanielOwen (code de départ du cours cité comme source)

---

## Jalon J1 — vendredi 25 septembre 2026

*Validé dans Git au plus tard le 25 septembre, avec une validation de chaque membre.*

### 1. Exigences de l'équipe

| Id | Exigence (reformulée par l'équipe) | Critère d'acceptation | Hypothèses |
|---|---|---|---|
| E1 | Après NRST ou mise sous tension, le système démarre en ARRÊT : seule la DEL rouge (PA9) est allumée. | Rouge seule allumée en moins de 100 ms après le relâchement de uC Reset (T1) ; `etat = 0` dans le débogueur. | Horloge MSI 4 MHz après réinitialisation ; `gpio_init` éteint toutes les DEL avant `fsm_init`. |
| E2 | Chaque appui validé sur User (PC13) fait défiler ARRÊT → MARCHE_AVANT → ARRÊT → MARCHE_ARRIÈRE → ARRÊT ; le changement de sens passe toujours par ARRÊT. | 4 appuis donnent rouge → verte → rouge → bleue → rouge (T2) ; une seule DEL allumée à chaque pas (ODR). | Variable `prochain_sens` (.bss) alterne avant/arrière à partir d'ARRÊT ; `compteur_transitions++` à chaque transition. |
| E3 | Anti-rebond logiciel et détection de front : un appui, même maintenu, ne produit qu'un seul événement. | Fenêtre de 30 ms (dans 20–50 ms) ; 20 appuis → `compteur_transitions = 20` ; appui maintenu 2 s → 1 transition (T3). | `fsm_step` appelé toutes les 1 ms (`PERIODE_SCRUTATION_MS`) ; niveau stable sur 30 échantillons consécutifs avant validation. |
| E4 | E-Stop (PB2) déclenche EXTI2 de priorité maximale ; l'ISR met les sorties en état sûr (verte et bleue éteintes, rouge allumée), lève `estop_flag`, efface la requête ; la boucle principale passe en ARRÊT_URGENCE. | Point d'arrêt atteint dans `EXTI2_IRQHandler` même pendant `delay_ms` ; verte ou bleue éteinte en moins de 10 ms (T5) ; `estop_flag` consommé par `fsm_step`. | Priorité NVIC 0 (la plus élevée) ; front choisi selon `BTN_ESTOP_ACTIF_HAUT`, à confirmer en T4 ; sur la L5, `EXTICR1` est dans EXTI (offset 0x60) et non dans SYSCFG. |
| E5 | En ARRÊT_URGENCE, la rouge clignote à 2 Hz (250 ms / 250 ms, ± 10 %), verte et bleue éteintes, appuis User ignorés. | Période mesurée de 500 ms ± 50 ms (T6, DWT_CYCCNT) ; appuis User sans effet sur `etat` (T8). | Clignotement compté en pas de scrutation (250 pas de 1 ms) ; `button_pressed(USER)` appelée malgré tout pour entretenir l'anti-rebond. |
| E6 | Un appui validé sur Touch En (PB5) avec E-Stop relâché ramène en ARRÊT ; refusé tant que E-Stop est maintenu ; aucune reprise automatique. | Touch En + E-Stop relâché → `etat = 0`, rouge fixe ; Touch En + E-Stop maintenu → reste en urgence (T7). | E-Stop relâché vérifié par `button_raw(BTN_ESTOP) == 0` au moment de l'acquittement. |
| E7 | Hors urgence, chaque appui validé sur Touch En inverse `touch_enabled` (0/1) et éteint brièvement (100 ms) la DEL active. | Deux appuis en ARRÊT : `touch_enabled` 0 → 1 → 0 (fenêtre Expressions) ; extinction brève visible (T9). | Extinction gérée par `touch_signal_compteur` (100 pas) dans `fsm_maj_del` ; `etat` inchangé. |
| E8 | Toutes les durées proviennent de `delay_ms` (boucle calibrée), dont la calibration est documentée. | `DELAY_BOUCLES_PAR_MS` calibrée et rapportée (fréquence d'horloge, cycles par itération) ; période de clignotement mesurée cohérente. | MSI 4 MHz, code en flash ; `SystemInit` vide ; SysTick prévu au laboratoire 2. |
| E9 | Le système reste cohérent en cas d'appuis simultanés ou d'E-Stop pendant un clignotement ou une transition. | Jamais deux DEL allumées ; jamais de sortie d'ARRÊT_URGENCE sans acquittement (T10). | `led_set` éteint tout avant d'allumer une seule DEL ; `fsm_maj_del` est le seul point d'appel de `led_set`. |

**Hypothèses communes, à confirmer par l'essai T4 (lecture de IDR au débogueur) :**
`BTN_USER_ACTIF_HAUT = 1`, `BTN_ESTOP_ACTIF_HAUT = 1`, `BTN_TOUCH_ACTIF_HAUT = 1` et `BTN_x_PUPDR = 0` (sans rappel interne). Ces valeurs proviennent de `registres.inc` : ce sont les hypothèses du code de départ, et non des mesures.

### 2. Rôles et rotation

À chaque séance, un membre réalise et l'autre valide (essais, mesures, relecture) ; les rôles sont inversés à la séance suivante. Chaque membre valide ses propres modifications sous son nom dans Git.

| Séance | Réalise | Valide |
|---|---|---|
| Séance 0 — 15 sept. | Owen Ouoba | Daniel Nchankam |
| Séance 1 — 22 sept. | Daniel Nchankam | Owen Ouoba |
| Séance 2 — 29 sept. | Owen Ouoba | Daniel Nchankam |

**Répartition des modules du laboratoire 1**

| Module | Responsable | Relecteur |
|---|---|---|
| `gpio.s` (`gpio_init`, `led_set`), `registres.inc` | Daniel | Owen |
| `buttons.s` (`button_raw`, `button_pressed`, `delay_ms`) | Owen | Daniel |
| `estop.s` (`estop_init`, `EXTI2_IRQHandler`) | Daniel | Owen |
| `fsm.s` (`fsm_init`, `fsm_step`, `fsm_maj_del`) | Owen | Daniel |
| Rapport, tableau des essais, fiche périphérique | Rédaction partagée | Rédaction partagée |

**Rotation prévue pour les laboratoires 2 à 5.** Le responsable du suivi alterne à chaque laboratoire (colonne « Suivi » de l'échéancier ci-dessous), et chaque membre rédige au moins une nouvelle routine assembleur par laboratoire, afin que les deux puissent expliquer n'importe quelle partie du code à la démonstration.

### 3. Échéancier des laboratoires 1 à 5

*Source : plan de cours v1.2, section « Échéancier des laboratoires ». Dates de la section A02. Remises à 23 h 59, communes aux deux sections.*

| Laboratoire | Séance 1 | Séance 2 | Remise | Jalon | Suivi |
|---|---|---|---|---|---|
| Séance 0 — prise en main | 15 sept. | — | — | — | — |
| 1 — Commandes et signalisation | 22 sept. | 29 sept. | ven. 9 oct. | J1 — 25 sept. | Owen |
| 2 — Propulsion et mesure de vitesse | 6 oct. | 13 oct. | **mer. 21 oct.** | — | Daniel |
| 3 — Accélérateur, acquisition, télémétrie | 20 oct. | 3 nov. | ven. 13 nov. | J2 — 6 nov. | Owen |
| 4 — Tableau de bord et perception simulée | 10 nov. | 17 nov. | ven. 27 nov. | J3 — 27 nov. | Daniel |
| 5 — Projet final : voiture autonome | 24 nov. | 1er déc. | **mer. 9 déc.** | — | Les deux |

Démonstration finale de la section A02 : mardi 8 décembre. Le dossier final du 9 décembre comprend les bilans individuels.

**Contenu des jalons du projet**

- **J1** (25 sept.) : exigences, rôles et échéancier de l'équipe — le présent document.
- **J2** (6 nov.) : module d'événements testé sur hôte.
- **J3** (27 nov.) : automate formel vérifié.

**Contraintes repérées dans le calendrier**

- Période d'étude du 25 au 31 octobre : aucune séance ni remise. Le laboratoire 3 est coupé en deux par cette semaine (séance 1 le 20 oct., séance 2 le 3 nov.) ; le travail de la première séance devra être consolidé avant la coupure.
- Examen de mi-session le vendredi 23 octobre, soit deux jours après la remise du laboratoire 2 : terminer le rapport du labo 2 avant le 19 octobre.
- Le laboratoire 2 est le plus serré : deux semaines seulement, et une remise un mercredi.
- Semaine du 23 novembre : la remise du laboratoire 4 et le jalon J3 tombent le même jour, le 27 novembre.
- Décembre : la démonstration finale (8 déc.) et le dossier final (9 déc.) se suivent à un jour d'intervalle.

**Objectifs internes du laboratoire 1**

- 25 sept. : J1 validé dans Git ; E1, E2 et E3 fonctionnels ; niveaux IDR relevés (T4).
- 29 sept. : E4 à E9 démontrés devant l'assistant ; fiche périphérique remplie.
- 6 oct. : tableau des essais T1 à T10 avec preuves (dossier `preuves/`) ; brouillon du rapport.
- 9 oct., 23 h 59 : remise du rapport et de l'archive sur Brightspace.

---

## Journal des séances

### Séance 0 — 15 septembre 2026
*Réalise : Owen Ouoba · Valide : Daniel Nchankam*

- **Objectifs :** prise en main de la plateforme Leafy et de la Nucleo ; premier programme (DEL rouge) ; dépôt Git.
- **Fait :** création du projet, configuration de LD3 (PA9 en sortie), configuration du débogueur ST-LINK, création du dépôt GitHub.
- **Décisions :** dépôt GitHub partagé `CEG3536_DanielOwen` ; rotation des rôles à chaque séance.
- **Difficultés et solutions :** —
- **Essais et mesures :** `GPIOA_MODER = 0xABF7FFFF` après configuration (bits 19:18 = 01, PA9 en sortie) ; DEL rouge allumée.
- **Validations Git :** danielnchankam — « gpio_init : configuration initiale de LD3 ».

### Séance 1 — 22 septembre 2026
*Réalise : Daniel Nchankam · Valide : Owen Ouoba*

- **Objectifs :** intégrer le code de départ ; `button_pressed` (E3) ; défilement User (E2) ; préparer le jalon J1.
- **Fait :** intégration du code de départ (structure `Core/Src`, projet `CEG3536_Lab1_DanielOwen`) ; écriture de `button_pressed` (anti-rebond par comptage de 30 échantillons de 1 ms, détection de front), de `fsm_step` (E2 avec `prochain_sens`, E5, E6, E7), de `estop_init` et de `EXTI2_IRQHandler` (E4) ; rédaction du jalon J1.
- **Reste à faire :** essais sur la carte (T1 à T10) ; le code est écrit et compile, mais n'a pas encore été vérifié sur la Nucleo.
- **Décisions :** fenêtre d'anti-rebond de 30 ms (milieu de l'intervalle 20–50 ms) ; `led_set` par BSRR (écriture atomique, sans lecture-modification-écriture) ; une seule mise à jour des DEL par pas, dans `fsm_maj_del`.
- **Difficultés et solutions :** sur la STM32L5, `EXTICR` est dans EXTI (offset 0x60) et non dans SYSCFG, contrairement aux exemples écrits pour la F4 ; le champ EXTI2 occupe 8 bits (masque `0xFF << 16`).
- **Essais et mesures :** compilation sans avertissement ; niveaux IDR de PC13, PB2 et PB5 à relever (T4).
- **Validations Git :** OwenOuoba — « Intégration du code de départ (Core/Src) et routines E2 à E7 » ; « Jalon J1 : exigences, rôles et échéancier ».

### Séance 2 — 29 septembre 2026
*Réalise : Owen Ouoba · Valide : Daniel Nchankam*

- **Objectifs :** vérifier E1 à E9 sur la carte (essais T1 à T10) ; mesurer le clignotement ; démonstration devant l'assistant.
- **Fait :** essais T1 à T10 dans STM32CubeIDE (Live Expressions sur les bits IDR/ODR, `etat`, `estop_flag`, `touch_enabled`, `compteur_transitions`, EXTI_RPR1) ; ajout de la mesure du clignotement par le compteur de cycles DWT (`blink_cycles`) ; calibration de `delay_ms` ; démonstration.
- **Décisions :** mesurer la période de clignotement avec DWT_CYCCNT plutôt qu'à l'oscilloscope (méthode de l'énoncé v1.2) ; `DELAY_BOUCLES_PAR_MS` passé de 1000 à 1254 (règle de trois sur la mesure) ; niveaux actifs et PUPDR de `registres.inc` conservés, confirmés par T4.
- **Difficultés et solutions :**
  - Erreur « Unknown MCU found on target » au lancement du débogueur : la sonde ST-LINK était détectée mais pas le processeur ; connexion rétablie avant les essais.
  - `blink_cycles` introuvable dans Live Expressions : une session de débogage de l'ancien projet (`CEG3536_Lab1_Demarrage`) était encore ouverte ; réglé en la fermant.
  - T6 hors tolérance au premier essai (199 ms au lieu de 250 ms) : corrigé par la calibration.
  - La pile d'appels de T5 affiche `estop_init()` à l'adresse 0x08000306, qui est en réalité celle de `EXTI2_IRQHandler` (nom erroné de GDB, l'assembleur ne fournit pas d'information de fonction).
- **Essais et mesures :** IDR relâché = 0 et appuyé = 1 pour PC13, PB2 et PB5 ; `blink_cycles` = 797 532 cycles (199 ms) avant calibration, 988 034 cycles (247 ms, −1,2 %) après ; 3,0 cycles par itération de `delay_ms`. Voir le tableau ci-dessous.
- **Validations Git :** OwenOuoba — « T6 : mesure du clignotement par DWT_CYCCNT et calibration de delay_ms » ; « JOURNAL : séance 2 et tableau des essais ».

---

## Tableau des essais (T1 à T10)

Preuves : captures de l'annexe A du rapport (fig. A.1 à A.13).

| Essai | Date | Résultat observé | Verdict | Preuve (fichier) |
|---|---|---|---|---|
| T1 — Réinitialisation | 29 sept. | Rouge seule allumée immédiatement après uC Reset ; `etat = 0`. | Conforme | Observation en séance (capture non conservée) |
| T2 — Cycle User | 29 sept. | Rouge → verte → rouge → bleue → rouge ; une seule DEL à la fois. | Conforme | Observation en séance (capture non conservée) |
| T3 — Anti-rebond | 29 sept. | `compteur_transitions = 20` après 20 appuis ; User maintenu : 1 seule transition. | Conforme | Fig. A.2, A.13 |
| T4 — Niveaux logiques | 29 sept. | Relâché = 0, appuyé = 1 pour PC13, PB2, PB5 : actif haut, PUPDR = 00 confirmés. | Conforme | Fig. A.1, A.7 |
| T5 — E-Stop | 29 sept. | Arrêt dans `EXTI2_IRQHandler`, appelée depuis `delay_ms` ; à l'entrée : verte = 1, RPR1 = 1 ; ensuite `etat = 3`. | Conforme | Fig. A.3 |
| T6 — Clignotement | 29 sept. | Avant calibration : 797 532 cycles = 199 ms (−20 %). Après : 988 034 cycles = 247 ms (−1,2 %). | Conforme après correction | Fig. A.4, A.5 |
| T7 — Acquittement | 29 sept. | E-Stop relâché : `etat` 3 → 0. E-Stop maintenu (PB2 = 1) : `etat` reste 3. | Conforme | Fig. A.6, A.7 |
| T8 — User ignoré en urgence | 29 sept. | `etat = 3` et `compteur_transitions` inchangés malgré les appuis sur User. | Conforme | Fig. A.8, A.9 |
| T9 — Touch En hors urgence | 29 sept. | `touch_enabled` 0 → 1 → 0 en ARRÊT ; extinction brève visible. | Conforme | Fig. A.10, A.11 |
| T10 — Robustesse | 29 sept. | E-Stop + Touch En maintenus : `etat = 3`. User + Touch En : une seule DEL allumée (somme ODR = 1). | Conforme | Fig. A.12, A.13 |

---

## Routine conservée pour L3-A

**Routine :** `button_pressed`

**Interface :** `uint32_t button_pressed(uint32_t id)` — R0 = identifiant (0 User, 1 E-Stop, 2 Touch En) → R0 = 1 si un appui vient d'être validé (front), 0 sinon. L'état est conservé dans `btn_valide[3]` et `btn_compteur[3]` (.bss).

**Cas d'essai :** appui franc (1 événement) ; rebonds de moins de 30 ms (aucun événement parasite) ; appui maintenu 2 s (1 seul événement) ; relâchement (retourne 0) ; identifiant invalide, supérieur à 2 (retourne 0).

---

## Sources

Code de départ `CEG3536_Lab1_Demarrage` (Brightspace) ; RM0438 (STM32L552) ; PM0264 (Cortex-M33) ; manuel de Yifeng Zhu, 4<sup>e</sup> édition ; guide de la plateforme Leafy ; plan de cours v1.2 ; énoncé du laboratoire 1, version 1.2.
