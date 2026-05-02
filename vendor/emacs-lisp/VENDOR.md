# Vendored Emacs Lisp Source Tree

This directory contains the full `lisp/` tree from GNU Emacs, used as
the "Layer 2" elisp library for nelisp-emacs's NeLisp standalone path.

## Source

GNU Emacs 30.1, distributed under the GNU General Public License v3
or later.  Each file retains its original copyright header — see the
top of every `*.el` file for individual attribution.

Upstream repo: https://git.savannah.gnu.org/cgit/emacs.git
Bundle origin: `/usr/share/emacs/30.1/lisp/` (Debian / Ubuntu packaging
of the same upstream tarball).

## Why vendor

User directive (2026-05-02): "Emacs にある elisp の機能を再実装する
必要はまったくありません。emacs の elisp コードを全て vendor して
ください" (≈ "There is absolutely no need to reimplement Elisp
functionality that already exists in Emacs.  Please vendor all of
Emacs's elisp code.").

Practical implications for nelisp-emacs:

- `cl-lib` / `cl-macs` / `cl-seq` / etc. now ship as upstream Emacs
  versions, no nelisp-emacs reimplementation required.
- `subr.el` / `subr-x.el` / `seq.el` etc. ship verbatim — eliminates
  most of the L2 polyfill writing that Phase 1.6 / 2.1 began.
- nelisp-emacs's own `src/emacs-*.el` files become a *thin C-builtin
  shim layer* that fills the gap between NeLisp's bootstrap eval and
  the Emacs C primitives this elisp tree assumes.

## Modifications

None.  Files are byte-identical to upstream Emacs 30.1 after gunzip.
The decompression step was applied to every `*.el.gz` Debian ships;
the resulting `*.el` files are kept here so version control + diff
review is straightforward.

`*.elc` byte-compiled files were stripped (= they regenerate from
`*.el` via `byte-compile-file' / nelisp-emacs's own build pipeline).

## Layout

Mirrors upstream `lisp/` directory:

  emacs-lisp/         — cl-lib, eieio, ert, lisp-mode, ...
  international/      — coding system / character set files
  language/           — language-specific data
  textmodes/          — markup / writing modes
  progmodes/          — programming language modes
  net/                — network protocol implementations
  url/                — URL handling
  vc/                 — version control front-ends
  org/                — Org mode
  calc/               — symbolic calculator
  ...

## License

GPL-3.0-or-later, inherited from upstream Emacs.  See `COPYING` (= a
copy of GPL-3) at this directory's top, plus per-file headers.
