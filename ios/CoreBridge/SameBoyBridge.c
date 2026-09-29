#include "SameBoyBridge.h"
#include "gb.h"
#include "apu.h"
#include "display.h"
#include "joypad.h"
#include "save_state.h"
#include "PocketBootROM.h"
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#define SB_AUDIO_CAPACITY 32768
struct SBEmulator {
    GB_gameboy_t *gb;
    uint32_t pixels[160 * 144];
    int16_t audio[SB_AUDIO_CAPACITY];
    size_t audioRead, audioWrite;
    pthread_mutex_t audioLock;
};

static uint32_t encode_rgb(GB_gameboy_t *gb, uint8_t r, uint8_t g, uint8_t b)
{
    (void)gb;
    return 0xFF000000u | ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
}

static void receive_sample(GB_gameboy_t *gb, GB_sample_t *sample)
{
    SBEmulator *e = (SBEmulator *)GB_get_user_data(gb);
    if (!e) return;
    pthread_mutex_lock(&e->audioLock);
    size_t next = (e->audioWrite + 2) % SB_AUDIO_CAPACITY;
    if (next == e->audioRead) { pthread_mutex_unlock(&e->audioLock); return; }
    e->audio[e->audioWrite] = sample->left;
    e->audio[(e->audioWrite + 1) % SB_AUDIO_CAPACITY] = sample->right;
    e->audioWrite = next;
    pthread_mutex_unlock(&e->audioLock);
}

static void load_pocket_boot_rom(GB_gameboy_t *gb, GB_boot_rom_t type)
{
    if (type == GB_BOOT_ROM_MGB) {
        GB_load_boot_rom_from_buffer(gb, pocket_mgb_boot, sizeof(pocket_mgb_boot));
    }
}

SBEmulator *sb_create(void)
{
    SBEmulator *e = calloc(1, sizeof(*e));
    if (!e) return NULL;
    pthread_mutex_init(&e->audioLock, NULL);
    e->gb = GB_init(GB_alloc(), GB_MODEL_MGB);
    if (!e->gb) { pthread_mutex_destroy(&e->audioLock); free(e); return NULL; }
    GB_set_user_data(e->gb, e);
    GB_set_boot_rom_load_callback(e->gb, load_pocket_boot_rom);
    GB_set_rgb_encode_callback(e->gb, encode_rgb);
    GB_set_pixels_output(e->gb, e->pixels);
    GB_set_sample_rate(e->gb, 44100);
    GB_apu_set_sample_callback(e->gb, receive_sample);
    return e;
}

void sb_destroy(SBEmulator *e)
{
    if (!e) return;
    if (e->gb) { GB_free(e->gb); GB_dealloc(e->gb); }
    pthread_mutex_destroy(&e->audioLock);
    free(e);
}

bool sb_load_rom(SBEmulator *e, const uint8_t *bytes, size_t length)
{
    // The public buffer loader is intentionally void-returning. Reject data too
    // short to contain the cartridge header before handing it to SameBoy.
    if (!e || !bytes || length < 0x150) return false;
    GB_load_rom_from_buffer(e->gb, bytes, length);
    GB_reset(e->gb);
    return true;
}
void sb_run_frame(SBEmulator *e) { if (e) GB_run_frame(e->gb); }
void sb_copy_frame(SBEmulator *e, uint8_t *rgba, size_t capacity)
{
    if (!e || !rgba || capacity < sizeof(e->pixels)) return;
    // SameBoy pixel words are ARGB; this produces RGBA byte order on little-endian iOS.
    for (size_t i = 0; i < 160 * 144; i++) {
        uint32_t p = e->pixels[i];
        rgba[i * 4] = (uint8_t)(p >> 16);
        rgba[i * 4 + 1] = (uint8_t)(p >> 8);
        rgba[i * 4 + 2] = (uint8_t)p;
        rgba[i * 4 + 3] = 255;
    }
}
void sb_set_button(SBEmulator *e, SBButton b, bool pressed)
{
    if (!e) return;
    static const GB_key_t keys[] = {GB_KEY_UP, GB_KEY_DOWN, GB_KEY_LEFT, GB_KEY_RIGHT, GB_KEY_A, GB_KEY_B, GB_KEY_SELECT, GB_KEY_START};
    if ((unsigned)b < sizeof(keys) / sizeof(keys[0])) GB_set_key_state(e->gb, keys[b], pressed);
}
size_t sb_save_state_size(SBEmulator *e) { return e ? GB_get_save_state_size(e->gb) : 0; }
bool sb_save_state(SBEmulator *e, uint8_t *b, size_t n) { return e && b && n >= sb_save_state_size(e) && (GB_save_state_to_buffer(e->gb, b), true); }
bool sb_load_state(SBEmulator *e, const uint8_t *b, size_t n) { return e && b && GB_load_state_from_buffer(e->gb, b, n) == 0; }
size_t sb_battery_size(SBEmulator *e) { return e ? (size_t)GB_save_battery_size(e->gb) : 0; }
bool sb_save_battery(SBEmulator *e, uint8_t *b, size_t n) { return e && b && n >= sb_battery_size(e) && GB_save_battery_to_buffer(e->gb, b, n) == 0; }
void sb_load_battery(SBEmulator *e, const uint8_t *b, size_t n) { if (e && b && n) GB_load_battery_from_buffer(e->gb, b, n); }
size_t sb_read_audio(SBEmulator *e, int16_t *out, size_t cap)
{
    if (!e || !out) return 0;
    pthread_mutex_lock(&e->audioLock);
    size_t count = 0;
    while (count < cap && e->audioRead != e->audioWrite) {
        out[count++] = e->audio[e->audioRead];
        e->audioRead = (e->audioRead + 1) % SB_AUDIO_CAPACITY;
    }
    pthread_mutex_unlock(&e->audioLock);
    return count;
}
