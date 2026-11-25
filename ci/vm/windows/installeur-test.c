/* Faux installateur Windows (installateur Thomas OS, test en VM), comme un vrai : copie appli-test.exe (posé à côté de
   lui) dans « C:\Program Files\Thomas Test », puis crée son raccourci dans le menu Démarrer (IShellLink, comme les vrais
   installateurs). Compilé sur GitHub (mingw), jamais sur le PC de Thomas. */
#define COBJMACROS
#include <windows.h>
#include <objbase.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <wchar.h>

int main(void)
{
    wchar_t source[MAX_PATH], dossier[MAX_PATH], cible[MAX_PATH], menu[MAX_PATH], lien[MAX_PATH];
    if (!GetModuleFileNameW(NULL, source, MAX_PATH))
        return 1;
    wchar_t *fin = wcsrchr(source, L'\\');
    if (!fin)
        return 2;
    wcscpy(fin + 1, L"appli-test.exe");

    if (FAILED(SHGetFolderPathW(NULL, CSIDL_PROGRAM_FILES, NULL, 0, dossier)))
        return 3;
    wcscat(dossier, L"\\Thomas Test");
    CreateDirectoryW(dossier, NULL);
    wcscpy(cible, dossier);
    wcscat(cible, L"\\appli-test.exe");
    if (!CopyFileW(source, cible, FALSE))
        return 4;

    if (FAILED(SHGetFolderPathW(NULL, CSIDL_COMMON_PROGRAMS, NULL, 0, menu)))
        return 5;
    wcscpy(lien, menu);
    wcscat(lien, L"\\Thomas Test.lnk");

    IShellLinkW *raccourci = NULL;
    IPersistFile *fichier = NULL;
    CoInitialize(NULL);
    if (FAILED(CoCreateInstance(&CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, &IID_IShellLinkW, (void **)&raccourci)))
        return 6;
    IShellLinkW_SetPath(raccourci, cible);
    IShellLinkW_SetWorkingDirectory(raccourci, dossier);
    IShellLinkW_SetDescription(raccourci, L"Thomas Test");
    if (FAILED(IShellLinkW_QueryInterface(raccourci, &IID_IPersistFile, (void **)&fichier)))
        return 7;
    if (FAILED(IPersistFile_Save(fichier, lien, TRUE)))
        return 8;
    IPersistFile_Release(fichier);
    IShellLinkW_Release(raccourci);
    CoUninitialize();
    return 0;
}
