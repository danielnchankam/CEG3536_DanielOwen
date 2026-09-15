.syntax unified
.cpu cortex-m33
.thumb
.equ RCC_AHB2ENR, 0x4002104C @ RM0438 §9.8, alias NS
.equ GPIOA_BASE, 0x42020000 @ RM0438 §2.3
.equ MODER, 0x00 @ RM0438 §11.4.1
.equ BSRR, 0x18 @ RM0438 §11.4.7
.text
.global main
.type main, %function
main:
ldr r0, =RCC_AHB2ENR
ldr r1, [r0]
orr r1, r1, #1 @ GPIOAEN
str r1, [r0]
ldr r1, [r0] @ relecture
ldr r0, =GPIOA_BASE
ldr r1, [r0, #MODER]
bic r1, r1, #(3 << 18) @ efface bits 19:18
orr r1, r1, #(1 << 18) @ 01 = sortie
str r1, [r0, #MODER]
mov r1, #(1 << 9)
str r1, [r0, #BSRR] @ PA9 = 1 : LD3 rouge
stop: b stop
.size main, . - main