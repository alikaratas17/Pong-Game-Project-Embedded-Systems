# Pong-Game-Project-Embedded-Systems

- This is a course project I did for Embedded Systems course.
- It is the well-known Pong Game implemented with an AVR Board using assembly.
- It contains usage of UART, GLCD, EEPROM, and Watchdog Timer.
- Below is my report on it with illustrations

- 
## Introduction
In the final project for the course Embedded Systems (COMP/ELEC 317) I made the well-known Pong Game in AVR. This game utilizes GLCD screen, EEPROM, Watchdog Timer, and UART communication. The code for this game was written in Assembly. Only the ‘ai’ (AI is used throughout this project to mean a computer program that user plays against, it does not refer to any learning function such as neural network) part utilizes python code run on the computer connected with UART, however that is only a simple program that reads current game information from UART and sends a decision Up or Down if needed to the main program via UART. Since the game completely runs on the AVR board, no UART connection is needed for two-player mode.




