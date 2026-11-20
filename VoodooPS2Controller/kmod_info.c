/*
 * kmod_info.c - manual (non-Xcode) kernel module metadata for the
 * VoodooPS2Controller kext bundle.
 *
 * Xcode's kernel-extension product type synthesizes this from Info.plist.
 * A hand-built kext must provide _kmod_info, _realmain and _antimain or
 * kmutil refuses to link it into a kernel collection with
 * "kexts must have a _kmod_info symbol".
 *
 * Keep _realmain/_antimain zero-initialized: XNU runs __mod_init_func
 * constructors itself before calling kmod_info->start, and a non-NULL
 * trampoline would run OSMetaClass constructors twice.
 */

#include <mach/kmod.h>

extern kern_return_t _start(kmod_info_t *ki, void *data);
extern kern_return_t _stop(kmod_info_t *ki, void *data);

__attribute__((visibility("hidden"))) void *_realmain;
__attribute__((visibility("hidden"))) void *_antimain;

KMOD_EXPLICIT_DECL(as.acidanthera.voodoo.driver.PS2Controller, "2.3.8", _start, _stop)
