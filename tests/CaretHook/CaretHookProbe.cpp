/*
Compile as a COFF object and flatten the object into shellcode:

cl /O2 /Ob1 /c /GS- /std:c++20 /d1reportSingleClassLayoutCaretPosHookData CaretHookProbe.cpp

This is deliberately a hook-only probe.  The callback writes a fixed marker
to the shared data block; it does not call TSF, MSAA, UIA, or any caret API.
*/
#include <Windows.h>

enum CARET_HOOK_PROBE_ERROR : DWORD {
    CPH_E_SUCCEEDED,
    CPH_E_NOT_CALLED,
    CPH_E_NONEXIST_FUNC,
    CPH_E_SETWINDOWSHOOK,
    CPH_E_SENDMESSAGE,
};

typedef LRESULT(CALLBACK *PCALLWNDPROC)(int nCode, WPARAM wParam, LPARAM lParam);
typedef HHOOK(WINAPI *PSETWINDOWSHOOKEX)(int idHook, HOOKPROC lpfn, HINSTANCE hmod, DWORD dwThreadId);
typedef BOOL(WINAPI *PUNHOOKWINDOWSHOOKEX)(HHOOK hhk);
typedef LRESULT(WINAPI *PCALLNEXTHOOKEX)(HHOOK hhk, int nCode, WPARAM wParam, LPARAM lParam);
typedef LRESULT(WINAPI *PSENDMESSAGETIMEOUTW)(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam, UINT fuFlags, UINT uTimeout, PDWORD_PTR lpdwResult);

struct CaretPosHookData {
    LPVOID user32Base;
    LPVOID combaseBase;
    HWND hwnd;
    DWORD tid;
    UINT msg;
    DWORD exitCode;
#ifdef _WIN64
    char reserved[20];
#else
    char reserved[8];
#endif // _WIN64
    RECT rect;
    char sSetWindowsHookExW[20];
    char sUnhookWindowsHookEx[20];
    char sCallNextHookEx[20];
    char sSendMessageTimeoutW[20];
};

DWORD WINAPI ThreadProc(CaretPosHookData *pData);
LRESULT CALLBACK CallWndProc(int nCode, WPARAM wParam, LPARAM lParam);
FARPROC MyGetProcAddress(LPVOID moduleBase, const char *pProcName);
#ifndef _WIN64
CaretPosHookData *GetDataAddress();
#endif // _WIN64

CaretPosHookData gData = {
    .exitCode = CPH_E_NOT_CALLED,
    .sSetWindowsHookExW = "SetWindowsHookExW",
    .sUnhookWindowsHookEx = "UnhookWindowsHookEx",
    .sCallNextHookEx = "CallNextHookEx",
    .sSendMessageTimeoutW = "SendMessageTimeoutW",
};

DWORD WINAPI ThreadProc(CaretPosHookData *pData) {
    PSETWINDOWSHOOKEX pSetWindowsHookEx = (PSETWINDOWSHOOKEX)MyGetProcAddress(pData->user32Base, pData->sSetWindowsHookExW);
    PSENDMESSAGETIMEOUTW pSendMessageTimeoutW = (PSENDMESSAGETIMEOUTW)MyGetProcAddress(pData->user32Base, pData->sSendMessageTimeoutW);
    PUNHOOKWINDOWSHOOKEX pUnhookWindowsHookEx = (PUNHOOKWINDOWSHOOKEX)MyGetProcAddress(pData->user32Base, pData->sUnhookWindowsHookEx);
    if (!pSetWindowsHookEx || !pSendMessageTimeoutW || !pUnhookWindowsHookEx)
        return CPH_E_NONEXIST_FUNC;
#ifdef _WIN64
    HHOOK hook = pSetWindowsHookEx(WH_CALLWNDPROC, CallWndProc, 0, pData->tid);
#else
    *(LPVOID *)((DWORD)pData + (DWORD)GetDataAddress + 1) = pData;
    HHOOK hook = pSetWindowsHookEx(WH_CALLWNDPROC, (PCALLWNDPROC)((DWORD)pData + (DWORD)CallWndProc), 0, pData->tid);
#endif // _WIN64
    if (!hook)
        return CPH_E_SETWINDOWSHOOK;
    LRESULT sent = pSendMessageTimeoutW(pData->hwnd, pData->msg, 0, 0, 0, 200, NULL);
    pUnhookWindowsHookEx(hook);
    if (!sent)
        return CPH_E_SENDMESSAGE;
    return pData->exitCode;
}

LRESULT CALLBACK CallWndProc(int nCode, WPARAM wParam, LPARAM lParam) {
#ifdef _WIN64
    CaretPosHookData *pData = &gData;
#else
    CaretPosHookData *pData = GetDataAddress();
#endif // _WIN64
    if (nCode >= 0 && lParam) {
        PCWPSTRUCT pcwps = (PCWPSTRUCT)lParam;
        if (pcwps->message == pData->msg) {
            pData->rect = {0x13579BDF, 0x2468ACE0, 0x0BADF00D, 0x00C0FFEE};
            pData->exitCode = CPH_E_SUCCEEDED;
        }
    }
    PCALLNEXTHOOKEX pCallNextHookEx = (PCALLNEXTHOOKEX)MyGetProcAddress(pData->user32Base, pData->sCallNextHookEx);
    if (!pCallNextHookEx)
        return 0;
    return pCallNextHookEx(NULL, nCode, wParam, lParam);
}

FARPROC MyGetProcAddress(LPVOID moduleBase, const char *pProcName) {
    if (!moduleBase || !pProcName)
        return NULL;
    PIMAGE_DOS_HEADER lpDosHeader = (PIMAGE_DOS_HEADER)moduleBase;
    PIMAGE_NT_HEADERS lpNtHeader = (PIMAGE_NT_HEADERS)((DWORD_PTR)moduleBase + lpDosHeader->e_lfanew);
    if (!lpNtHeader->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].Size ||
        !lpNtHeader->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress)
        return NULL;
    PIMAGE_EXPORT_DIRECTORY lpExports = (PIMAGE_EXPORT_DIRECTORY)((DWORD_PTR)moduleBase + lpNtHeader->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
    PDWORD lpdwFunName = (PDWORD)((DWORD_PTR)moduleBase + lpExports->AddressOfNames);
    PWORD lpword = (PWORD)((DWORD_PTR)moduleBase + lpExports->AddressOfNameOrdinals);
    PDWORD lpdwFunAddr = (PDWORD)((DWORD_PTR)moduleBase + lpExports->AddressOfFunctions);
    for (DWORD i = 0; i < lpExports->NumberOfNames; i++) {
        char *pProcName_ = (char *)((DWORD_PTR)moduleBase + lpdwFunName[i]);
        for (int j = 0; pProcName[j] == pProcName_[j]; j++) {
            if (!pProcName[j])
                return (FARPROC)((DWORD_PTR)moduleBase + lpdwFunAddr[lpword[i]]);
        }
    }
    return NULL;
}

#ifndef _WIN64
__declspec(naked) CaretPosHookData *GetDataAddress() {
    __asm {
        mov eax, dword ptr 0
        ret
    }
}
#endif // _WIN64
