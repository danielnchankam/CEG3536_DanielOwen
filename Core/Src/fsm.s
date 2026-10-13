/* ---------------------------------------------------------------------------
 * fsm.s — machine à états du véhicule : panneau de commande (laboratoire 1)
 *         et propulsion, consigne, rampe, mesure de vitesse, buzzer
 *         (CEG 3536, laboratoire 2). Base : corrigé du laboratoire 1.
 *
 * Routines exportées : fsm_init, fsm_step
 * Routines locales   : fsm_entree_etat (entrée dans ARRÊT / AVANT / ARRIÈRE),
 *                      fsm_compte_transition,
 *                      fsm_maj_sorties (seul point d'appel de led_set,
 *                      motor_set_pwm et buzzer_step, critère B4)
 * Variables (.bss)   : etat, touch_enabled, compteur_transitions,
 *                      prochain_sens, clignote_compteur, clignote_phase,
 *                      consigne_pct, pwm_pct, rampe_compteur,
 *                      fenetre_compteur, blink_cycles (T6 du laboratoire 1)
 *
 * États : ETAT_ARRET (rouge fixe, PWM 0, STB = 0), ETAT_MARCHE_AVANT (verte,
 *         AI1 = 1), ETAT_MARCHE_ARRIERE (bleue, AI2 = 1),
 *         ETAT_ARRET_URGENCE (rouge 2 Hz, STB = 0, son continu)
 * Transitions :
 *   E3  ARRÊT --User--> AVANT --User--> ARRÊT --User--> ARRIÈRE --User--> ARRÊT
 *       (prochain_sens alterne ; le sens change toujours en passant par ARRÊT)
 *   E7  tout état --estop_flag--> ARRÊT_URGENCE (propulsion coupée dans l'ISR)
 *   E8  ARRÊT_URGENCE --Touch En validé ET E-Stop relâché--> ARRÊT
 *   E4  hors urgence : Touch En validé -> consigne suivante (25..100 %) + bip
 * fsm_step est appelée une fois par tick SysTick (1 ms) : tous les compteurs
 * (anti-rebond, clignotement, rampe, fenêtre de vitesse, bips) sont en ms.
 * ------------------------------------------------------------------------- */
#include "registres.inc"
#include "registres_lab2.inc"

    .syntax unified
    .cpu    cortex-m33
    .thumb

    .bss
    .align  2
    .global etat
etat:                   .space  4   /* état courant (ETAT_x)                     */
    .global touch_enabled
touch_enabled:          .space  4   /* E7 du lab. 1, retiré : reste à 0 (lab1.h) */
    .global compteur_transitions
compteur_transitions:   .space  4   /* nombre de changements d'état (watch)      */
prochain_sens:          .space  4   /* 0 : prochain départ en avant, 1 : en arrière */
clignote_compteur:      .space  4   /* ms écoulées dans la demi-période (E8)     */
clignote_phase:         .space  4   /* 0 rouge éteinte, 1 rouge allumée          */
    .global consigne_pct
consigne_pct:           .space  4   /* consigne 25, 50, 75 ou 100 % (E4)         */
    .global pwm_pct
pwm_pct:                .space  4   /* rapport cyclique appliqué, suit la rampe  */
rampe_compteur:         .space  4   /* ms écoulées depuis le dernier pas de rampe */
fenetre_compteur:       .space  4   /* ms écoulées dans la fenêtre de vitesse (E6) */
    .global blink_cycles
blink_cycles:           .space  4   /* cycles DWT entre deux basculements de la
                                       rouge en urgence (demi-période)           */
blink_cyccnt_prec:      .space  4   /* DWT_CYCCNT au basculement précédent       */

/* ---- Tables indexées par l'état (un octet par état) --------------------- */
    .section .rodata
etat_vers_del:
    .byte   LED_ROUGE       /* ETAT_ARRET          */
    .byte   LED_VERTE       /* ETAT_MARCHE_AVANT   */
    .byte   LED_BLEUE       /* ETAT_MARCHE_ARRIERE */
    .byte   LED_ROUGE       /* ETAT_ARRET_URGENCE (clignotante, voir fsm_maj_sorties) */
etat_vers_dir:
    .byte   MOTOR_ARRET     /* ETAT_ARRET          */
    .byte   MOTOR_AVANT     /* ETAT_MARCHE_AVANT   */
    .byte   MOTOR_ARRIERE   /* ETAT_MARCHE_ARRIERE */
    .byte   MOTOR_ARRET     /* ETAT_ARRET_URGENCE  */
etat_vers_bips:
    .byte   1               /* ARRÊT : bip court (E9)           */
    .byte   1               /* AVANT : bip court                */
    .byte   2               /* ARRIÈRE : double bip             */
    .byte   0               /* URGENCE : son continu (buzzer_continu) */

    .text
    .align  2

/* void fsm_init(void)
 * État initial ARRÊT, variables à zéro, consigne CONSIGNE_INITIALE (50 %),
 * DEL rouge seule, buzzer silencieux (E1). La propulsion est déjà en état
 * sûr (motor_init : CCR1 = 0, STB = 0, AI1 = AI2 = 0) : aucun bip ni
 * mouvement à la mise sous tension.
 * Active le compteur de cycles DWT (mesures au débogueur, blink_cycles).
 * Appelle fsm_maj_sorties : push {r4, lr} garde l'alignement 8.             */
    .global fsm_init
    .type   fsm_init, %function
fsm_init:
    push    {r4, lr}
    movs    r1, #0
    ldr     r0, =etat
    movs    r2, #ETAT_ARRET
    str     r2, [r0]
    ldr     r0, =touch_enabled
    str     r1, [r0]
    ldr     r0, =compteur_transitions
    str     r1, [r0]
    ldr     r0, =prochain_sens
    str     r1, [r0]
    ldr     r0, =clignote_compteur
    str     r1, [r0]
    ldr     r0, =clignote_phase
    str     r1, [r0]
    ldr     r0, =pwm_pct
    str     r1, [r0]
    ldr     r0, =rampe_compteur
    str     r1, [r0]
    ldr     r0, =fenetre_compteur
    str     r1, [r0]
    ldr     r0, =blink_cycles
    str     r1, [r0]
    ldr     r0, =blink_cyccnt_prec
    str     r1, [r0]
    ldr     r0, =consigne_pct
    movs    r2, #CONSIGNE_INITIALE
    str     r2, [r0]
    /* compteur de cycles DWT */
    ldr     r0, =DEMCR
    ldr     r2, [r0]
    orr     r2, r2, #DEMCR_TRCENA
    str     r2, [r0]
    ldr     r0, =DWT_CTRL
    ldr     r2, [r0]
    orr     r2, r2, #DWT_CTRL_CYCCNTENA
    str     r2, [r0]
    bl      fsm_maj_sorties
    pop     {r4, pc}
    .size   fsm_init, .-fsm_init

/* void fsm_step(void)
 * Un pas de la machine à états, appelé une fois par tick SysTick (1 ms).
 *   A. estop_flag -> ARRÊT_URGENCE (E7) : propulsion coupée (déjà faite dans
 *      l'ISR, refaite ici), son continu, clignotement initialisé
 *   B. événements validés User et Touch En (toujours lus, pour entretenir
 *      l'anti-rebond même quand ils sont ignorés)
 *   C. en urgence : User ignoré ; acquittement Touch En si E-Stop relâché (E8)
 *      hors urgence : défilement User (E3) ; consigne par Touch En (E4)
 *   D. fenêtre de vitesse : encoder_read toutes les FENETRE_VITESSE_MS (E6)
 *   E. sorties (fsm_maj_sorties) : rampe, DEL, buzzer
 * Invariants (E12) : une seule DEL allumée ; changement de sens uniquement
 * par ARRÊT (motor_set_dir le refuse sinon) ; aucune sortie d'ARRÊT_URGENCE
 * sans acquittement (seul le chemin E8 écrit ETAT_ARRET depuis l'urgence).
 * Un second E-Stop pendant l'urgence (ou les rebonds de son relâchement)
 * consomme le drapeau sans rien changer.
 * AAPCS : push {r4, r5, r6, lr}. r4 = événement User, r5 = événement Touch,
 * r6 = &etat.                                                                */
    .global fsm_step
    .type   fsm_step, %function
fsm_step:
    push    {r4, r5, r6, lr}
    ldr     r6, =etat

    /* ---- A. drapeau E-Stop (positionné par l'ISR) ---- */
    ldr     r0, =estop_flag
    ldr     r1, [r0]
    cmp     r1, #0
    beq     fsm_step_lecture
    movs    r1, #0
    str     r1, [r0]                    /* drapeau consommé */
    ldr     r0, [r6]
    cmp     r0, #ETAT_ARRET_URGENCE
    beq     fsm_step_lecture            /* déjà en urgence : rien d'autre */
    bl      motor_stop_now              /* redondant avec l'ISR : état sûr garanti */
    movs    r1, #0
    ldr     r0, =pwm_pct
    str     r1, [r0]
    ldr     r0, =rampe_compteur
    str     r1, [r0]
    ldr     r0, =buzzer_continu
    movs    r1, #1
    str     r1, [r0]                    /* son continu jusqu'à l'acquittement */
    movs    r0, #ETAT_ARRET_URGENCE
    str     r0, [r6]
    bl      fsm_compte_transition
    ldr     r0, =clignote_compteur      /* demi-période rouge allumée d'abord */
    movs    r1, #0
    str     r1, [r0]
    ldr     r0, =blink_cycles
    str     r1, [r0]
    ldr     r0, =DWT_CYCCNT
    ldr     r1, [r0]
    ldr     r0, =blink_cyccnt_prec
    str     r1, [r0]
    ldr     r0, =clignote_phase
    movs    r1, #1
    str     r1, [r0]

    /* ---- B. événements validés ---- */
fsm_step_lecture:
    movs    r0, #BTN_USER
    bl      button_pressed
    mov     r4, r0                      /* r4 = 1 si appui User validé */
    movs    r0, #BTN_TOUCH
    bl      button_pressed
    mov     r5, r0                      /* r5 = 1 si appui Touch En validé */

    /* ---- C. transitions ---- */
    ldr     r0, [r6]
    cmp     r0, #ETAT_ARRET_URGENCE
    bne     fsm_step_normal

    /* en urgence : User et consigne ignorés ; acquittement E8 */
    cmp     r5, #0
    beq     fsm_step_fenetre
    movs    r0, #BTN_ESTOP
    bl      button_raw
    cmp     r0, #0
    bne     fsm_step_fenetre            /* E-Stop maintenu : acquittement refusé */
    ldr     r0, =buzzer_continu
    movs    r1, #0
    str     r1, [r0]                    /* son continu coupé */
    movs    r0, #ETAT_ARRET
    bl      fsm_entree_etat             /* ARRÊT, bip court, STB reste 0 */
    b       fsm_step_fenetre

fsm_step_normal:
    /* E3 : défilement par User */
    cmp     r4, #0
    beq     fsm_step_touch
    ldr     r0, [r6]
    cmp     r0, #ETAT_ARRET
    bne     fsm_step_vers_arret
    ldr     r1, =prochain_sens
    ldr     r2, [r1]
    cmp     r2, #0
    bne     fsm_step_arriere
    movs    r0, #ETAT_MARCHE_AVANT      /* ARRÊT -> AVANT, prochain départ en arrière */
    movs    r2, #1
    b       fsm_step_depart
fsm_step_arriere:
    movs    r0, #ETAT_MARCHE_ARRIERE    /* ARRÊT -> ARRIÈRE, prochain départ en avant */
    movs    r2, #0
fsm_step_depart:
    str     r2, [r1]
    bl      fsm_entree_etat
    b       fsm_step_touch
fsm_step_vers_arret:
    movs    r0, #ETAT_ARRET             /* AVANT ou ARRIÈRE -> ARRÊT, CCR1 = 0 sans rampe */
    bl      fsm_entree_etat

fsm_step_touch:
    /* E4 : Touch En hors urgence -> consigne suivante (100 -> 25) */
    cmp     r5, #0
    beq     fsm_step_fenetre
    ldr     r0, =consigne_pct
    ldr     r1, [r0]
    adds    r1, r1, #CONSIGNE_PAS
    cmp     r1, #CONSIGNE_MAX
    it      hi
    movhi   r1, #CONSIGNE_MIN
    str     r1, [r0]
    cmp     r4, #0
    bne     fsm_step_fenetre            /* transition dans le même pas : son bip est gardé */
    movs    r0, #1
    bl      buzzer_bip

    /* ---- D. fenêtre de vitesse (E6) ---- */
fsm_step_fenetre:
    ldr     r0, =fenetre_compteur
    ldr     r1, [r0]
    adds    r1, r1, #1
    cmp     r1, #FENETRE_VITESSE_MS
    blo     fsm_step_fenetre_attente
    movs    r1, #0
    str     r1, [r0]
    ldr     r0, =sens_mesure
    bl      encoder_read                /* vitesse_fronts et sens_mesure mis à jour */
    b       fsm_step_maj
fsm_step_fenetre_attente:
    str     r1, [r0]

    /* ---- E. sorties ---- */
fsm_step_maj:
    bl      fsm_maj_sorties
    pop     {r4, r5, r6, pc}
    .size   fsm_step, .-fsm_step

/* static void fsm_entree_etat(uint32_t nouvel_etat)
 * r0 = ETAT_ARRET, ETAT_MARCHE_AVANT ou ETAT_MARCHE_ARRIERE.
 * etat = r0 ; compteur_transitions++ ; pwm_pct = 0 et rampe_compteur = 0
 * (la rampe repart de 0) ; motor_set_dir(etat_vers_dir[r0]) ;
 * buzzer_bip(etat_vers_bips[r0]).
 * motor_set_dir accepte toujours ici : vers ARRÊT elle force CCR1 = 0
 * (arrêt immédiat, sans rampe) ; depuis ARRÊT, CCR1 est déjà nul.
 * AAPCS : appelle d'autres routines -> push {r4, lr}. r4 = nouvel état.     */
    .type   fsm_entree_etat, %function
fsm_entree_etat:
    push    {r4, lr}
    mov     r4, r0
    ldr     r1, =etat
    str     r4, [r1]
    bl      fsm_compte_transition
    movs    r1, #0
    ldr     r0, =pwm_pct
    str     r1, [r0]
    ldr     r0, =rampe_compteur
    str     r1, [r0]
    ldr     r1, =etat_vers_dir
    ldrb    r0, [r1, r4]
    bl      motor_set_dir
    ldr     r1, =etat_vers_bips
    ldrb    r0, [r1, r4]
    bl      buzzer_bip
    pop     {r4, pc}
    .size   fsm_entree_etat, .-fsm_entree_etat

/* static void fsm_compte_transition(void) — compteur_transitions++
 * Routine feuille locale ; registres modifiés : r0, r1.                     */
    .type   fsm_compte_transition, %function
fsm_compte_transition:
    ldr     r0, =compteur_transitions
    ldr     r1, [r0]
    adds    r1, r1, #1
    str     r1, [r0]
    bx      lr
    .size   fsm_compte_transition, .-fsm_compte_transition

/* static void fsm_maj_sorties(void) — seul point de mise à jour des sorties
 *   1. rampe (AVANT / ARRIÈRE) : tous les RAMPE_PAS_MS, pwm_pct se rapproche
 *      de consigne_pct d'un point, puis motor_set_pwm(pwm_pct) (E4) ;
 *   2. DEL : celle de l'état ; en urgence, rouge clignotante à 2 Hz —
 *      clignote_phase bascule toutes les CLIGNOTEMENT_DEMI_MS ; à chaque
 *      basculement, blink_cycles = écart de DWT_CYCCNT (demi-période) ;
 *   3. buzzer_step (bips, son continu) ;
 *   4. hors urgence, si estop_flag vaut 1 (ISR survenue pendant ce pas, par
 *      exemple entre la lecture du drapeau et l'écriture de CCR1 ou des DEL),
 *      l'état sûr est réaffirmé : motor_stop_now, rouge seule, son. La
 *      dernière écriture sur la propulsion, les DEL et le buzzer est alors
 *      toujours celle de l'état sûr (E7, E12).
 * AAPCS : appelle d'autres routines -> push {r4, lr}. r4 = état,
 * r12 = temporaire.                                                          */
    .type   fsm_maj_sorties, %function
fsm_maj_sorties:
    push    {r4, lr}
    ldr     r0, =etat
    ldr     r4, [r0]
    cmp     r4, #ETAT_ARRET_URGENCE
    bhi     fsm_maj_sorties_fin         /* état invalide : ne rien changer */
    beq     fsm_maj_sorties_urgence
    cmp     r4, #ETAT_ARRET
    beq     fsm_maj_sorties_del         /* ARRÊT : pas de rampe, CCR1 = 0 */

    /* 1. rampe : 1 point toutes les RAMPE_PAS_MS */
    ldr     r1, =rampe_compteur
    ldr     r2, [r1]
    adds    r2, r2, #1
    cmp     r2, #RAMPE_PAS_MS
    blo     fsm_maj_sorties_rampe_attente
    movs    r2, #0
    str     r2, [r1]
    ldr     r1, =pwm_pct
    ldr     r0, [r1]                    /* r0 = pwm_pct */
    ldr     r2, =consigne_pct
    ldr     r2, [r2]
    cmp     r0, r2
    beq     fsm_maj_sorties_pwm         /* consigne atteinte */
    ite     lo
    addlo   r0, r0, #1                  /* montée */
    subhs   r0, r0, #1                  /* descente */
    str     r0, [r1]
fsm_maj_sorties_pwm:
    bl      motor_set_pwm               /* CCR1 = pwm_pct * (ARR + 1) / 100 */
    b       fsm_maj_sorties_del
fsm_maj_sorties_rampe_attente:
    str     r2, [r1]

    /* 2. DEL de l'état (hors urgence) */
fsm_maj_sorties_del:
    ldr     r1, =etat_vers_del
    ldrb    r0, [r1, r4]
    bl      led_set
    b       fsm_maj_sorties_buzzer

    /* 2. urgence : clignotement à 2 Hz */
fsm_maj_sorties_urgence:
    ldr     r1, =clignote_compteur
    ldr     r2, [r1]
    adds    r2, r2, #1
    cmp     r2, #(CLIGNOTEMENT_DEMI_MS / PERIODE_SCRUTATION_MS)
    blo     fsm_maj_sorties_pas_bascule
    movs    r2, #0
    ldr     r3, =clignote_phase
    ldr     r0, [r3]
    eor     r0, r0, #1
    str     r0, [r3]
    ldr     r3, =DWT_CYCCNT             /* écart de cycles depuis la bascule précédente */
    ldr     r0, [r3]
    ldr     r3, =blink_cyccnt_prec
    ldr     r12, [r3]
    str     r0, [r3]
    sub     r12, r0, r12
    ldr     r3, =blink_cycles
    str     r12, [r3]
fsm_maj_sorties_pas_bascule:
    str     r2, [r1]
    ldr     r3, =clignote_phase
    ldr     r0, [r3]
    cmp     r0, #0
    ite     ne
    movne   r0, #LED_ROUGE
    moveq   r0, #LED_AUCUNE
    bl      led_set

    /* 3. buzzer */
fsm_maj_sorties_buzzer:
    bl      buzzer_step

    /* 4. E-Stop survenu pendant ce pas (hors urgence) : état sûr réaffirmé */
    cmp     r4, #ETAT_ARRET_URGENCE
    beq     fsm_maj_sorties_fin
    ldr     r1, =estop_flag
    ldr     r1, [r1]
    cmp     r1, #0
    beq     fsm_maj_sorties_fin
    bl      motor_stop_now
    movs    r0, #LED_ROUGE
    bl      led_set
    movs    r0, #1
    bl      buzzer_set
fsm_maj_sorties_fin:
    pop     {r4, pc}
    .size   fsm_maj_sorties, .-fsm_maj_sorties
