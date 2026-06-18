/**************************************************************************/
/*  download_dialog.c                                                     */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#include "download_dialog.h"

#include "build.h"

#include <windows.h>

#include <commctrl.h>
#include <shellapi.h>

#ifdef _MSC_VER
#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "shell32.lib")
#endif

#define BASE_URL L"https://www.hardwoodgames.com/downloads/"

void show_download_older_version_dialog(
		const wchar_t *p_main_instruction,
		const wchar_t *p_content,
		const wchar_t *p_query_params) {
	TASKDIALOG_BUTTON td_buttons[2];
	TASKDIALOGCONFIG td_config;
	int nButtonPressed = 0;

	td_buttons[0].nButtonID = 100;
	td_buttons[0].pszButtonText = L"Download Older Version";
	td_buttons[1].nButtonID = 101;
	td_buttons[1].pszButtonText = L"Exit";

	ZeroMemory(&td_config, sizeof(td_config));
	td_config.cbSize = sizeof(TASKDIALOGCONFIG);
	td_config.pszWindowTitle = L"Hardwood Games";
	td_config.pszMainIcon = TD_WARNING_ICON;
	td_config.pszMainInstruction = p_main_instruction;
	td_config.pszContent = p_content;
	td_config.pButtons = td_buttons;
	td_config.cButtons = 2;
	td_config.nDefaultButton = 100;
	td_config.dwFlags = TDF_ALLOW_DIALOG_CANCELLATION;

	TaskDialogIndirect(&td_config, &nButtonPressed, NULL, NULL);
	if (nButtonPressed == 100) {
		// Get Windows version via RtlGetVersion (works regardless of manifest).
		DWORD major = 0, minor = 0, build_num = 0;
		HMODULE hNtdll = GetModuleHandleW(L"ntdll.dll");
		if (hNtdll) {
			typedef LONG(WINAPI * RtlGetVersionFn)(OSVERSIONINFOW *);
			RtlGetVersionFn pRtlGetVersion = (RtlGetVersionFn)GetProcAddress(hNtdll, "RtlGetVersion");
			if (pRtlGetVersion) {
				OSVERSIONINFOW osvi;
				ZeroMemory(&osvi, sizeof(osvi));
				osvi.dwOSVersionInfoSize = sizeof(osvi);
				if (pRtlGetVersion(&osvi) == 0) {
					major = osvi.dwMajorVersion;
					minor = osvi.dwMinorVersion;
					build_num = osvi.dwBuildNumber;
				}
			}
		}

		wchar_t url[1024];
		_snwprintf_s(url, 1024, _TRUNCATE,
				BASE_URL L"?win_version=%lu.%lu.%lu&build=%d",
				major, minor, build_num, ROGUE_ENGINE_BUILD);
		if (p_query_params && p_query_params[0] != L'\0') {
			wcsncat_s(url, 1024, L"&", _TRUNCATE);
			wcsncat_s(url, 1024, p_query_params, _TRUNCATE);
		}
		ShellExecuteW(NULL, L"open", url, NULL, NULL, SW_SHOWNORMAL);
		Sleep(1000);
		ExitProcess(1);
	}
}
