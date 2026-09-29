#ifndef SAMEBOY_BRIDGE_H
#define SAMEBOY_BRIDGE_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct SBEmulator SBEmulator;
typedef enum { SB_UP, SB_DOWN, SB_LEFT, SB_RIGHT, SB_A, SB_B, SB_SELECT, SB_START } SBButton;

SBEmulator *sb_create(void);
void sb_destroy(SBEmulator *emulator);
bool sb_load_rom(SBEmulator *emulator, const uint8_t *bytes, size_t length);
void sb_run_frame(SBEmulator *emulator);
void sb_copy_frame(SBEmulator *emulator, uint8_t *rgba, size_t capacity);
void sb_set_button(SBEmulator *emulator, SBButton button, bool pressed);
size_t sb_save_state_size(SBEmulator *emulator);
bool sb_save_state(SBEmulator *emulator, uint8_t *bytes, size_t length);
bool sb_load_state(SBEmulator *emulator, const uint8_t *bytes, size_t length);
size_t sb_battery_size(SBEmulator *emulator);
bool sb_save_battery(SBEmulator *emulator, uint8_t *bytes, size_t length);
void sb_load_battery(SBEmulator *emulator, const uint8_t *bytes, size_t length);
// Returns the number of interleaved stereo int16 samples copied.
size_t sb_read_audio(SBEmulator *emulator, int16_t *samples, size_t capacity);
#endif
