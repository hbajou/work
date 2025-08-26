; AutoHotkey v2 script - Emacs-like keybinding
#Requires AutoHotkey v2.0

; --- Global variables ---
DEBUG_MODE := false

gIsCtrlXPressed := false

gIsMarkDown := false

gIsEscapePressed := false

gIsSearching := false

reset_pre_keys() {
    global gIsCtrlXPressed := false
    global gIsMarkDown := false
    global gIsEscapePressed := false
}

reset_all_status() {
    reset_pre_keys()
    global gIsSearching := false
}

delete_char() {
    Send("{Del}")
    reset_all_status()
}

delete_backward_char() {
    Send("{BS}")
    reset_all_status()
}

kill_line() {
    Send("{Shift down}{End}{Shift up}")
    Sleep(50)
    A_Clipboard := ""
    Send("^x")
    ClipWait(0.1)
    text := A_Clipboard
    if (text = "") {
        Send("{Shift down}{Right}{Shift up}")
        Sleep(50)
        Send("^x")
    }
    reset_all_status()
}

open_line() {
    Send("{End}{Enter}{Up}")
    reset_all_status()
}

quit() {
    Send("{ESC}")
    reset_all_status()
}

newline() {
    Send("{Enter}")
    reset_all_status()
}

indent_for_tab_command() {
    Send("{Tab}")
    reset_all_status()
}

newline_and_indent() {
    Send("{Enter}{Tab}")
    reset_all_status()
}

isearch_forward() {
    global gIsSearching
    if gIsSearching {
        Send("{F3}")
    } else {
        Send("^f")
        gIsSearching := true
    }
    reset_pre_keys()
}

isearch_backward() {
    global gIsSearching
    if gIsSearching {
        Send("+{F3}")
    } else {
        Send("^f")
        gIsSearching := true
    }
    reset_pre_keys()
}

kill_region() {
    Send("^x")
    reset_all_status()
}

kill_ring_save() {
    Send("^c")
    reset_all_status()
}

yank() {
    Send("^v")
    reset_all_status()
}

undo() {
    Send("^z")
    reset_all_status()
}

find_file() {
    Send("^o")
    reset_all_status()
}

save_buffer() {
    Send("^s")
    reset_all_status()
}

kill_window() {
    Send("!{F4}")
    reset_all_status()
}

kill_buffer() {
    Send("^w")
    reset_all_status()
}

move_beginning_of_line() {
    if gIsMarkDown {
        Send("+{Home}")
    } else {
        Send("{Home}")
        reset_all_status()
    }
}

move_end_of_line() {
    if gIsMarkDown {
        Send("+{End}")
    } else {
        Send("{End}")
        reset_all_status()
    }
}

previous_line() {
    if gIsMarkDown {
        Send("+{Up}")
    } else {
        Send("{Up}")
        reset_all_status()
    }
}

next_line() {
    if gIsMarkDown {
        Send("+{Down}")
    } else {
        Send("{Down}")
        reset_all_status()
    }
}

forward_char() {
    if gIsMarkDown {
        Send("+{Right}")
    } else {
        Send("{Right}")
        reset_all_status()
    }
}

backward_char() {
    if gIsMarkDown {
        Send("+{Left}")
    } else {
        Send("{Left}")
        reset_all_status()
    }
}

scroll_up() {
    if gIsMarkDown {
        Send("+{PgUp}")
    } else {
        Send("{PgUp}")
        reset_all_status()
    }
}

scroll_down() {
    if gIsMarkDown {
        Send("+{PgDn}")
    } else {
        Send("{PgDn}")
        reset_all_status()
    }
}

pageup_top() {
    if gIsMarkDown {
        Send("+^{Home}")
    } else {
        Send("^{Home}")
        reset_all_status()
    }
}

pagedown_bottom() {
    if gIsMarkDown {
        Send("+^{End}")
    } else {
        Send("^{End}")
        reset_all_status()
    }
}

set_ignore_targets() {
    GroupAdd("IgnoreTargets", "ahk_class ConsoleWindowClass")
    GroupAdd("IgnoreTargets", "ahk_class cygwin/x X rl-xterm-XTerm-0")
    GroupAdd("IgnoreTargets", "ahk_class VMwareUnityHostWndClass")
    GroupAdd("IgnoreTargets", "ahk_class Vim")
    GroupAdd("IgnoreTargets", "ahk_class Emacs")
    GroupAdd("IgnoreTargets", "ahk_class XEmacs")
    GroupAdd("IgnoreTargets", "ahk_exe vcxsrv.exe")
    GroupAdd("IgnoreTargets", "ahk_exe xyzzy.exe")
    GroupAdd("IgnoreTargets", "ahk_exe putty.exe")
    GroupAdd("IgnoreTargets", "ahk_exe ttermpro.exe")
    GroupAdd("IgnoreTargets", "ahk_exe TurboVNC.exe")
    GroupAdd("IgnoreTargets", "ahk_exe vncviewer.exe")
    GroupAdd("IgnoreTargets", "ahk_exe WindowsTerminal.exe")
    GroupAdd("IgnoreTargets", "ahk_exe Ubuntu.exe")
}

main() {
    if DEBUG_MODE {
        InstallKeybdHook()
    }
    ListLines(false)
    SetControlDelay(-1)
    SetKeyDelay(-1)
    SetWinDelay(-1)
    SendMode("Input")
    set_ignore_targets()
}

main()


#HotIf !WinActive("ahk_group IgnoreTargets")
global gIsCtrlXPressed := false

^x::
{
    global gIsCtrlXPressed
    gIsCtrlXPressed := true
    SetTimer(() => gIsCtrlXPressed := false, -800)  ; reset after 800ms
    return
}

^s::
{
    global gIsCtrlXPressed
    if gIsCtrlXPressed
    {
        gIsCtrlXPressed := false
        save_buffer()
    }
    else
    {
        isearch_forward()
    }
    return
}

^f:: gIsCtrlXPressed ? find_file() : forward_char()
^d:: delete_char()
^h:: delete_backward_char()
^k:: kill_line()
k:: gIsCtrlXPressed ? kill_buffer() : Send("k")
^j:: newline_and_indent()
^m:: newline()
^i:: indent_for_tab_command()
^r:: isearch_backward()
^w:: kill_region()
!w:: kill_ring_save()
w:: gIsEscapePressed ? kill_ring_save() : Send("w")
^y:: yank()
^/:: undo()
^vk20:: gIsMarkDown := !gIsMarkDown
^a:: move_beginning_of_line()
^e:: move_end_of_line()
^p:: previous_line()
^n:: next_line()
^b:: backward_char()
^v:: scroll_down()
!v:: scroll_up()
v:: gIsEscapePressed ? scroll_up() : Send("v")
!<:: pageup_top()
<:: gIsEscapePressed ? pageup_top() : Send("<")
!>:: pagedown_bottom()
>:: gIsEscapePressed ? pagedown_bottom() : Send(">")
#HotIf
