/* SPDX-License-Identifier: LGPL-2.1-or-later */
#include <assert.h>
#include <stdio.h>
#include "KeyRoute.h"
int main(void) {
    assert(cm_key_route(0, 'a', 0) == CM_TEXT);
    assert(cm_key_route(0, 'A', CM_MOD_SHIFT) == CM_TEXT);
    assert(cm_key_route(49, ' ', 0) == CM_SPACE);
    assert(cm_key_route(49, ' ', CM_MOD_SHIFT) == CM_SHIFT_SPACE);
    assert(cm_key_route(36, '\r', 0) == CM_ENTER);
    assert(cm_key_route(76, '\r', 0) == CM_ENTER);
    assert(cm_key_route(51, 8, 0) == CM_BACKSPACE);
    assert(cm_key_route(117, 127, 0) == CM_DELETE);
    assert(cm_key_route(53, 27, 0) == CM_ESCAPE);
    assert(cm_key_route(123, -1, 0) == CM_LEFT);
    assert(cm_key_route(124, -1, CM_MOD_SHIFT) == CM_SHIFT_RIGHT);
    assert(cm_key_route(123, -1, CM_MOD_SHIFT) == CM_SHIFT_LEFT);
    assert(cm_key_route(126, -1, 0) == CM_UP);
    assert(cm_key_route(125, -1, 0) == CM_DOWN);
    assert(cm_key_route(115, -1, 0) == CM_HOME);
    assert(cm_key_route(119, -1, 0) == CM_END);
    assert(cm_key_route(116, -1, 0) == CM_PAGE_UP);
    assert(cm_key_route(121, -1, 0) == CM_PAGE_DOWN);
    assert(cm_key_route(48, 9, 0) == CM_TAB);
    assert(cm_key_route(48, 9, CM_MOD_SHIFT) == CM_PASS);
    assert(cm_key_route(122, 0xf704, 0) == CM_PASS); /* F1 */
    assert(cm_key_route(0, 0x4e2d, 0) == CM_PASS);
    assert(cm_key_route(0, -1, 0) == CM_PASS);
    const unsigned modifiers[] = {CM_MOD_COMMAND, CM_MOD_CONTROL, CM_MOD_OPTION, CM_MOD_CAPS_LOCK};
    for (unsigned i = 0; i < sizeof modifiers / sizeof modifiers[0]; ++i) {
        for (unsigned key = 0; key <= 127; ++key) {
            assert(cm_key_route((unsigned short)key, 'a', modifiers[i]) == CM_PASS);
            assert(cm_key_route((unsigned short)key, 'a', modifiers[i] | CM_MOD_SHIFT) == CM_PASS);
        }
    }
    puts("Key routing: 1,047 assertions passed");
    return 0;
}
