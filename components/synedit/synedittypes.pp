{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: SynEditTypes.pas, released 2000-04-07.
The Original Code is based on parts of mwCustomEdit.pas by Martin Waldenburg,
part of the mwEdit component suite.
Portions created by Martin Waldenburg are Copyright (C) 1998 Martin Waldenburg.
All Rights Reserved.

Contributors to the SynEdit and mwEdit projects are listed in the
Contributors.txt file.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

$Id$

You may retrieve the latest version of this file at the SynEdit home page,
located at http://SynEdit.SourceForge.net

Known Issues:
-------------------------------------------------------------------------------}

unit SynEditTypes;

{$I synedit.inc}

interface
uses
  SysUtils, types;

const
  TSynSpecialChars = [#128..#255]; // MG: special chars. Meaning depends on system encoding/codepage.
  TSynValidStringChars = ['_', '0'..'9', 'A'..'Z', 'a'..'z'] + TSynSpecialChars;
  TSynWhiteChars = [' ', #9];
  TSynWordBreakChars = ['.', ',', ';', ':', '"', '''', '`', '!', '?', '[', ']',
     '(', ')', '{', '}', '@', '^', '-', '=', '+', '*', '/', '\', '|','<','>',
     '%', '&', '~'];

type
  ESynEditError = class(Exception);

  TSynIdentChars = set of char;

  TLinePos = type integer; // 1..high(Integer);
  TLineIdx = type integer; // 0..high(Integer);

  TSynCoordinateMappingFlag = (
    scmLimitToLines,
    scmIncludePartVisible,
    scmForceLeftSidePos   // do return the caret pos to the (logical) left of the char, even if the pixel is over the right half.
                          // TODO: RTL
  );
  TSynCoordinateMappingFlags = set of TSynCoordinateMappingFlag;

  PSynSelectionMode = ^TSynSelectionMode;
  // to be binary (clipboard) compatible with other (Delphi compiled) synedits
  // use {$PACKENUM 1}
{$PACKENUM 1}
  TSynSelectionMode = (smNormal, smLine, smColumn, smCurrent);
{$PACKENUM 4}

  TSynSearchOption =
    ( ssoMatchCase, ssoWholeWord,
      ssoBackwards,
      ssoEntireScope, ssoSelectedOnly,
      ssoReplace, ssoReplaceAll,
      ssoPrompt,
      ssoSearchInReplacement,    // continue search-replace in replacement (with ssoReplaceAll) // replace recursive
      ssoRegExpr, ssoRegExprMultiLine,
      ssoFindContinue      // Assume the current selection is the last match, and start search behind selection
                           // (before if ssoBackward) // Default is to start at caret (Only SearchReplace / SearchReplaceEx has start/end param)
    );
  TSynSearchOptions = set of TSynSearchOption;

  TSynEditRange = pointer;

  TSynStatusChange = (scCaretX, scCaretY,
    scLeftChar, scTopLine, scLinesInWindow, scCharsInWindow,
    scInsertMode, scModified, scSelection, scReadOnly,
    scFocus,     // received or lost focus
    scOptions    // some Options were changed (only triggered by some optinos)
   );
  TSynStatusChanges = set of TSynStatusChange;
  TStatusChangeEvent = procedure(Sender: TObject; Changes: TSynStatusChanges)
    of object;

  TSynPaintEvent = (peBeforePaint, peAfterPaint);
  TSynPaintEvents = set of TSynPaintEvent;
  TSynPaintEventProc = procedure(Sender: TObject; EventType: TSynPaintEvent;
    const rcClip: TRect
  ) of object;

  TSynScrollEvent = (peBeforeScroll, peAfterScroll, peAfterScrollFailed);
  TSynScrollEvents = set of TSynScrollEvent;
  TSynScrollEventProc = procedure(Sender: TObject; EventType: TSynScrollEvent;
    dx, dy: Integer; const rcScroll, rcClip: TRect
  ) of object;

  TSynVisibleSpecialChar = (vscSpace, vscTabAtFirst, vscTabAtLast);
  TSynVisibleSpecialChars = set of TSynVisibleSpecialChar;

  TSynLineStyle = (
    slsSolid,  // PS_SOLID pen
    slsDashed, // PS_DASH pen
    slsDotted, // PS_DOT
    slsWaved   // solid wave
  );

  TSynFrameEdges = (
    sfeNone,
    sfeAround,      // frame around
    sfeBottom,      // bottom part of the frame
    sfeLeft         // left part of the frame
  );

  TLazSynBorderSide = (
    bsLeft,
    bsTop,
    bsRight,
    bsBottom
  );
  TLazSynBorderSides = set of TLazSynBorderSide;

const
  SynFrameEdgeToSides: array [TSynFrameEdges] of TLazSynBorderSides =
  ( [],                                       // sfeNone
    [bsLeft, bsTop, bsRight, bsBottom],   // sfeAround
    [bsBottom],                              // sfeBottom
    [bsLeft]                                 // sfeLeft
  );

  SynFrameEdgePriorities: array [TSynFrameEdges] of integer =
  ( 0,    // sfeNone
    1,   // sfeAround
    2,   // sfeBottom
    2    // sfeLeft
  );

  scTextCleared = [scCaretX, scCaretY, scLeftChar, scTopLine, scModified, scSelection];


implementation

end.


