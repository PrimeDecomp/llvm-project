#pragma once

#include "types.h"

typedef VOID(_CC_CDECL *EntryProc)();
typedef BOOL(_CC_STDCALL *DllEntryProc)(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpReserved);
typedef VOID(_CC_STDCALL *PIMAGE_TLS_CALLBACK)(PVOID DllHandle, DWORD Reason, PVOID Reserved);

#ifdef WIBO_GUEST_64
extern "C" void callNativeEntryStack(EntryProc proc, void *stack);
extern "C" DWORD callNativeThreadStack(GUEST_PTR proc, void *stack, void *argument);
#endif

namespace entry {
#ifdef WIBO_GUEST_64
void callNativeEntry(EntryProc proc);
#endif

void CDECL stubBase(SIZE_T index);

} // namespace entry
