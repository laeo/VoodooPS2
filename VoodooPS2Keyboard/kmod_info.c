/*
 * kmod_info.c - manual (non-Xcode) kernel module metadata for the
 * VoodooPS2Keyboard plugin kext.
 *
 * See VoodooPS2Controller/kmod_info.c for the rationale.
 */

#include <mach/kmod.h>

extern kern_return_t _start(kmod_info_t *ki, void *data);
extern kern_return_t _stop(kmod_info_t *ki, void *data);

__attribute__((visibility("hidden"))) void *_realmain;
__attribute__((visibility("hidden"))) void *_antimain;

KMOD_EXPLICIT_DECL(as.acidanthera.voodoo.driver.PS2Keyboard, "2.3.8", _start, _stop)
