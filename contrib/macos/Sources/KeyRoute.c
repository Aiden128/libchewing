/* SPDX-License-Identifier: LGPL-2.1-or-later */
#include "KeyRoute.h"
int cm_key_route(unsigned short key, int scalar, unsigned int mods) {
    /* Application shortcuts and Caps Lock English mode must pass through. */
    if (mods & (CM_MOD_COMMAND | CM_MOD_CONTROL | CM_MOD_OPTION | CM_MOD_CAPS_LOCK)) return CM_PASS;
    const int shift = !!(mods & CM_MOD_SHIFT);
    switch (key) {
    case 36: case 76: return CM_ENTER;
    case 53: return CM_ESCAPE;
    case 51: return CM_BACKSPACE;
    case 117: return CM_DELETE;
    case 123: return shift ? CM_SHIFT_LEFT : CM_LEFT;
    case 124: return shift ? CM_SHIFT_RIGHT : CM_RIGHT;
    case 126: return CM_UP;
    case 125: return CM_DOWN;
    case 115: return CM_HOME;
    case 119: return CM_END;
    case 116: return CM_PAGE_UP;
    case 121: return CM_PAGE_DOWN;
    case 48: return shift ? CM_PASS : CM_TAB;
    case 49: return shift ? CM_SHIFT_SPACE : CM_SPACE;
    default: return scalar >= 0x21 && scalar <= 0x7e ? CM_TEXT : CM_PASS;
    }
}
