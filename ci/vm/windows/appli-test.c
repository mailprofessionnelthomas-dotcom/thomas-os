/* Programme Windows de test (installateur Thomas OS, test en VM) : écrit « OK » dans thomas-test-ok.txt, à côté de
   lui-même. Compilé sur GitHub (mingw), jamais sur le PC de Thomas. */
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int main(void)
{
    wchar_t chemin[MAX_PATH];
    if (!GetModuleFileNameW(NULL, chemin, MAX_PATH))
        return 1;
    wchar_t *fin = wcsrchr(chemin, L'\\');
    if (!fin)
        return 2;
    wcscpy(fin + 1, L"thomas-test-ok.txt");
    FILE *f = _wfopen(chemin, L"w");
    if (!f)
        return 3;
    fputs("OK\n", f);
    fclose(f);
    return 0;
}
