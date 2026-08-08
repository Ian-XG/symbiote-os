# Vendored Wayland protocols

## wlr-foreign-toplevel-management-unstable-v1.xml

From <https://gitlab.freedesktop.org/wlroots/wlr-protocols>, MIT licensed
(© 2018 Ilia Bozhinov). sha256 begins `4ecc4588858e29fe`.

Vendored because Debian does not package `wlr-protocols`, and this is the only
way for the shell to learn what windows are open. The standardised successor,
`ext-foreign-toplevel-list-v1`, *is* packaged — but it is list-only: it can
report a window's title and never focus it. A taskbar that shows you a window
and cannot switch to it is a label, not a taskbar.

labwc 0.8.3 implements both.

Not hand-written. A protocol XML with a wrong opcode does not fail to build,
it fails at runtime by killing the client with a protocol error.
