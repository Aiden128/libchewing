/* SPDX-License-Identifier: LGPL-2.1-or-later */
#ifndef CHEWING_MAC_KEY_ROUTE_H
#define CHEWING_MAC_KEY_ROUTE_H
#define CM_PASS 0
#define CM_TEXT 1
#define CM_SPACE 2
#define CM_ENTER 3
#define CM_ESCAPE 4
#define CM_BACKSPACE 5
#define CM_DELETE 6
#define CM_LEFT 7
#define CM_RIGHT 8
#define CM_UP 9
#define CM_DOWN 10
#define CM_HOME 11
#define CM_END 12
#define CM_PAGE_UP 13
#define CM_PAGE_DOWN 14
#define CM_TAB 15
#define CM_SHIFT_LEFT 16
#define CM_SHIFT_RIGHT 17
#define CM_SHIFT_SPACE 18
#define CM_MOD_SHIFT 1
#define CM_MOD_COMMAND 2
#define CM_MOD_CONTROL 4
#define CM_MOD_OPTION 8
#define CM_MOD_CAPS_LOCK 16
/* macOS virtual key code, Unicode scalar (or -1), modifier bitset. */
int cm_key_route(unsigned short key_code, int scalar, unsigned int modifiers);
#endif
