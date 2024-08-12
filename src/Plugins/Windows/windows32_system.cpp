/******************************************************************************
* MODULE     : windows32_system.cpp
* DESCRIPTION: Windows system functions with UTF-8 input/output instead of ANSI
* COPYRIGHT  : (C) 2024 Liza Belos
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

/* We use nowide to keep the same behavior of TeXmacs on Windows 32 bits.    */

#include <windows.h>
#include <io.h>
#include <vector>
#include <string>

#include "windows32_system.hpp"
#include "nowide/iostream.hpp"
#include "win-utf8-compat.hpp"

FILE* texmacs_fopen(string filename, string mode, bool lock) {
  cout << "texmacs_fopen " << filename << " " << mode << "\r\n";
  mode = mode * "b";
  c_string c_filename = filename;
  c_string c_mode = mode;
  FILE *file = fopen(c_filename, c_mode);
  if (file == nullptr) {
    return nullptr;
  }
  return file;
}

int texmacs_fwrite(const char *string, size_t size, FILE *stream) {
  if (stream != stdout && stream != stderr) {
    return fwrite(string, size, 1, stream);
  }
  if (stream == stdout) {
    nowide::cout << string;
    nowide::cout.flush();
  }
  if (stream == stderr) {
    nowide::cerr << string;
    nowide::cerr.flush();
  }
  return size;
}


void texmacs_fclose(FILE *&file, bool unlock) {
  fclose(file);
  file = nullptr;
}

TEXMACS_DIR texmacs_opendir(string dirname) {
  cout << "texmacs_opendir " << dirname << "\r\n";
  c_string c_dirname = dirname;
  return (TEXMACS_DIR)opendir(c_dirname);
}

void texmacs_closedir(TEXMACS_DIR dir) {
  closedir((DIR*)dir);
  dir = nullptr;
}

texmacs_dirent texmacs_readdir(TEXMACS_DIR dirp) {
  std::string nextname;
  bool res = nowide::readir_entry(dirp, nextname);
  if (!res) {
    return {false, ""};
  }
  return {true, string(nextname.c_str(), nextname.size())};
}

int texmacs_stat(string filename, struct_stat* buf) {
  c_string c_filename = filename;
  return stat(c_filename, buf);
}

bool texmacs_mkdir(string dirname, int mode) {
  c_string c_dirname = dirname;
  return mkdir(c_dirname, mode) == 0;
}

bool texmacs_rmdir(string dirname) {
  c_string c_dirname = dirname;
  return rmdir(c_dirname) == 0;
}

bool texmacs_rename(string oldname, string newname) {
  c_string c_oldname = oldname;
  c_string c_newname = newname;
  return rename(c_oldname, c_newname) == 0;
}

bool texmacs_chmod(string filename, int mode) {
  c_string c_filename = filename;
  return chmod(c_filename, mode) == 0;
}

bool texmacs_remove(string filename) {
  c_string c_filename = filename;
  return remove(c_filename) == 0;
}

bool texmacs_getenv(string variable_name, string &variable_value) {
    c_string _variable_name = variable_name;
    char *value = getenv(_variable_name);
    if (value == nullptr) {
        return false;
    }
    variable_value = value;
    return true;
}

bool texmacs_setenv(string variable_name, string new_value) {
    c_string _variable_name = variable_name;
    c_string _new_value = new_value;
    return setenv(_variable_name, _new_value, 1) == 0;
}

bool IsWindowsDarkMode() {
  HKEY hKey;
  DWORD value;
  DWORD valueSize = sizeof(value);
  LONG result;

  result = RegOpenKeyExW(
              HKEY_CURRENT_USER,
              L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
              0, KEY_READ, &hKey
  );

  if (result != ERROR_SUCCESS) {
    return false;
  }

  // Query the value of the AppsUseLightTheme key
  result = RegQueryValueExW(hKey, L"AppsUseLightTheme", nullptr,
                            nullptr, (LPBYTE)&value, &valueSize);
  RegCloseKey(hKey);

  if (result != ERROR_SUCCESS) {
    return false;   // Probably windows 7 or below
  }

  return value == 0;  // If value is 0, dark mode is enabled
}

string get_default_theme() {
  if (IsWindowsDarkMode()) {
    return "dark";
  }
  return "light";
}
