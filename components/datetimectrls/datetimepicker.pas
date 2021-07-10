{
TDateTimePicker control for Lazarus
- - - - - - - - - - - - - - - - - - -
Author: Zoran Vučenović, January and February 2010
        Зоран Вученовић, јануар и фебруар 2010.

   This unit is part of DateTimeCtrls package for Lazarus.

   Delphi's Visual Component Library (VCL) has a control named TDateTimePicker,
which I find very useful for editing dates. Lazarus Component Library (LCL),
however, does not have this control, because VCL wraps native Windows control
and it seems that such control does not exist on other platforms. Given that
LCL is designed to be platform independent, it could not use native Win control.
   Instead, for editing dates LCL has a control named TDateEdit, but I prefer
the VCL's TDateTimePicker.
   Therefore, I tried to create a custom control which would resemble VCL's
TDateTimePicker as much as possible, but not to rely on native Windows control.

   This TDateTimePicker control does not use native Win control. It has been
tested on Windows with win32/64 and qt widgetsets, as well as on Linux with
qt and gtk2 widgetsets.

-----------------------------------------------------------
LICENCE
- - - -
   Modified LGPL -- see the file COPYING.modifiedLGPL.

-----------------------------------------------------------
NO WARRANTY
- - - - - -
   There is no warranty whatsoever.

-----------------------------------------------------------
BEST REGARDS TO LAZARUS COMMUNITY!
- - - - - - - - - - - - - - - - - -
   I do hope this control will be useful.
}
unit DateTimePicker;

{$mode objfpc}{$H+}

interface

uses
  {$ifdef unix}
  clocale, // needed to initialize default locale settings on Linux.
  {$endif}
  Classes, SysUtils, Controls, LCLType, Graphics, Math, Buttons,
  ExtCtrls, Forms, ComCtrls, Types, LMessages, LazUTF8, LCLIntf,
  LCLProc, Themes, CalControlWrapper;

const
  { We will deal with the NullDate value the special way. It will be especially
    useful for dealing with null values from database. }
  NullDate = TDateTime(1.7e+308);

  { The biggest date a user can enter. }
  TheBiggestDate = TDateTime(2958465.0); // 31. dec. 9999.

  { The smallest date a user can enter.
    Note:
      TCalendar does not accept smaller dates then 14. sep. 1752 on Windows OS
      (see the implementation of TCustomCalendar.SetDateTime).
      In Delphi help it is documented that Windows controls act weird with dates
      older than 24. sep. 1752. Actually, TCalendar control has problems to show
      dates before 1. okt. 1752. (try putting one calendar on the form, run the
      application and see what september 1752. looks like).
      Let's behave uniformely as much as
      possible -- we won't allow dates before 1. okt. 1752. on any OS (who cares
      about those).
      So, this will be the down limit:  }
  TheSmallestDate = TDateTime(-53780.0); // 1. okt. 1752.

var
  DefaultCalendarWrapperClass: TCalendarControlWrapperClass = nil;

type
  TYMD = record
    Year, Month, Day: Word;
  end;

  THMSMs = record
    Hour, Minute, Second, MiliSec: Word;
  end;

  { Used by DateDisplayOrder property to determine the order to display date
    parts -- d-m-y, m-d-y or y-m-d.
    When ddoTryDefault is set, the actual order is determined from
    ShortDateFormat global variable -- see comments above
    AdjustEffectiveDateDisplayOrder procedure }
  TDateDisplayOrder = (ddoDMY, ddoMDY, ddoYMD, ddoTryDefault);

  TTimeDisplay = (tdHM,   // hour and minute
                  tdHMS,  // hour, minute and second
                  tdHMSMs // hour, minute, second and milisecond
                  );

  TTimeFormat = (tf12, // 12 hours format, with am/pm string
                 tf24  // 24 hours format
                 );

  { TDateTimeKind determines if we should display date, time or both: }
  TDateTimeKind = (dtkDate, dtkTime, dtkDateTime);

  TTextPart = 1..8;
  TDateTimePart = (dtpDay, dtpMonth, dtpYear, dtpHour, dtpMinute,
                                dtpSecond, dtpMiliSec, dtpAMPM);
  TDateTimeParts = set of dtpDay..dtpMiliSec; // without AMPM,
           // because this set type is used for HideDateTimeParts property,
           // where hiding of AMPM part is tied to hiding of hour (and, of
           // course, it makes a difference only when TimeFormat is set to tf12)

  TArrowShape = (asClassicSmaller, asClassicLarger, asModernSmaller,
    asModernLarger, asYetAnotherShape, asTheme);

  TDTDateMode = (dmComboBox, dmUpDown, dmNone);

  { calendar alignment - left or right,
    dtaDefault means it is determined by BiDiMode }
  TDTCalAlignment = (dtaLeft, dtaRight, dtaDefault);

  TDateTimePickerOption = (
    dtpoDoChangeOnSetDateTime, // The OnChange handler will be called also when
                               // date/time is programatically changed.
    dtpoEnabledIfUnchecked, // Enable the date time picker if the checkbox is unchecked.
    dtpoAutoCheck, // Auto-check an unchecked checkbox when DateTime is changed
                   // (makes sense only if dtpoEnabledIfUnchecked is set).
    dtpoFlatButton, // Use flat button for calender picker.
    dtpoResetSelection // When the control receives focus, the selection is always
       // in the first part (the control does not remember which part was previously selected).
    );

  TDateTimePickerOptions = set of TDateTimePickerOption;

  { TCustomDateTimePicker }

  TCustomDateTimePicker = class(TCustomControl)
  private const
    cDefOptions = [];
    cCheckBoxBorder = 3;
  private
    FAlignment: TAlignment;
    FAutoAdvance: Boolean;
    FAutoButtonSize: Boolean;
    FCalAlignment: TDTCalAlignment;
    FCalendarWrapperClass: TCalendarControlWrapperClass;
    FCascade: Boolean;
    FCenturyFrom, FEffectiveCenturyFrom: Word;
    FChecked: Boolean;
    FDateDisplayOrder: TDateDisplayOrder;
    FHideDateTimeParts: TDateTimeParts;
    FEffectiveHideDateTimeParts: set of TDateTimePart;
    FKind: TDateTimeKind;
    FLeadingZeros: Boolean;
    FMonthNames: String;
    FMonthNamesArray: TMonthNameArray;
    FNullInputAllowed: Boolean;
    FDateTime: TDateTime;
    FDateSeparator: String;
    FReadOnly: Boolean;
    FMaxDate, FMinDate: TDate;
    FShowMonthNames: Boolean;
    FTextForNullDate: TCaption;
    FTimeSeparator: String;
    FTimeDisplay: TTimeDisplay;
    FTimeFormat: TTimeFormat;
    FTrailingSeparator: Boolean;
    FUseDefaultSeparators: Boolean;
    FUserChangedText: Boolean;
    FYearPos, FDayPos, FMonthPos: 1..3;
    FTextPart: array[1..3] of String;
    FTimeText: array[dtpHour..dtpAMPM] of String;
    FUserChanging: Integer;
    FDigitWidth: Integer;
    FTextHeight: Integer;
    FSeparatorWidth: Integer;
    FSepNoSpaceWidth: Integer;
    FShowCheckBox: Boolean;
    FMouseInCheckBox: Boolean;
    FTimeSeparatorWidth: Integer;
    FMonthWidth: Integer;
    FNullMonthText: String;
    FSelectedTextPart: TTextPart;
    FRecalculatingTextSizesNeeded: Boolean;
    FJumpMinMax: Boolean;
    FAMPMWidth: Integer;
    FDateWidth: Integer;
    FTimeWidth: Integer;
    FTextWidth: Integer;
    FArrowShape: TArrowShape;
    FDateMode: TDTDateMode;
    FTextEnabled: Boolean;
    FUpDown: TCustomUpDown;
    FOnChange: TNotifyEvent;
    FOnCheckBoxChange: TNotifyEvent;
    FOnChangeHandlers: TMethodList;
    FOnCheckBoxChangeHandlers: TMethodList;
    FOnDropDown: TNotifyEvent;
    FOnCloseUp: TNotifyEvent;
    FEffectiveDateDisplayOrder: TDateDisplayOrder;

    FArrowButton: TCustomSpeedButton;
    FCalendarForm: TCustomForm;
    FDoNotArrangeControls: Boolean;
    FConfirmedDateTime: TDateTime;
    FNoEditingDone: Integer;
    FAllowDroppingCalendar: Boolean;
    FCorrectedDTP: TDateTimePart;
    FCorrectedValue: Word;
    FSkipChangeInUpdateDate: Integer;
    FOptions: TDateTimePickerOptions;

    function AreSeparatorsStored: Boolean;
    function GetChecked: Boolean;
    function GetDate: TDate;
    function GetDateTime: TDateTime;
    function GetDroppedDown: Boolean;
    function GetTime: TTime;
    procedure SetAlignment(AValue: TAlignment);
    procedure SetArrowShape(const AValue: TArrowShape);
    procedure SetAutoButtonSize(AValue: Boolean);
    procedure SetCalAlignment(AValue: TDTCalAlignment);
    procedure SetCalendarWrapperClass(AValue: TCalendarControlWrapperClass);
    procedure SetCenturyFrom(const AValue: Word);
    procedure SetChecked(const AValue: Boolean);
    procedure CheckTextEnabled;
    procedure SetDateDisplayOrder(const AValue: TDateDisplayOrder);
    procedure SetDateMode(const AValue: TDTDateMode);
    procedure SetHideDateTimeParts(AValue: TDateTimeParts);
    procedure SetKind(const AValue: TDateTimeKind);
    procedure SetLeadingZeros(const AValue: Boolean);
    procedure SetMonthNames(AValue: String);
    procedure SetNullInputAllowed(const AValue: Boolean);
    procedure SetDate(const AValue: TDate);
    procedure SetDateTime(const AValue: TDateTime);
    procedure SetDateSeparator(const AValue: String);
    procedure SetMaxDate(const AValue: TDate);
    procedure SetMinDate(const AValue: TDate);
    procedure SetReadOnly(const AValue: Boolean);
    procedure SetShowCheckBox(const AValue: Boolean);
    procedure SetShowMonthNames(AValue: Boolean);
    procedure SetTextForNullDate(const AValue: TCaption);
    procedure SetTime(const AValue: TTime);
    procedure SetTimeSeparator(const AValue: String);
    procedure SetTimeDisplay(const AValue: TTimeDisplay);
    procedure SetTimeFormat(const AValue: TTimeFormat);
    procedure SetTrailingSeparator(const AValue: Boolean);
    procedure SetUseDefaultSeparators(const AValue: Boolean);

    procedure RecalculateTextSizesIfNeeded;
    function GetHMSMs(const NowIfNull: Boolean = False): THMSMs;
    function GetYYYYMMDD(const TodayIfNull: Boolean = False;
                               const WithCorrection: Boolean = False): TYMD;
    procedure SetHour(const AValue: Word);
    procedure SetMiliSec(const AValue: Word);
    procedure SetMinute(const AValue: Word);
    procedure SetSecond(const AValue: Word);
    procedure SetSeparators(const DateSep, TimeSep: String);
    procedure SetDay(const AValue: Word);
    procedure SetMonth(const AValue: Word);
    procedure SetYear(const AValue: Word);
    procedure SetYYYYMMDD(const AValue: TYMD);
    procedure SetHMSMs(const AValue: THMSMs);
    procedure UpdateIfUserChangedText;
    function GetSelectedText: String;
    procedure AdjustSelection;
    procedure AdjustEffectiveCenturyFrom;
    procedure AdjustEffectiveDateDisplayOrder;
    procedure AdjustEffectiveHideDateTimeParts;
    procedure SelectDateTimePart(const DateTimePart: TDateTimePart);
    procedure MoveSelectionLR(const ToLeft: Boolean);
    procedure DestroyCalendarForm;
    procedure UpdateShowArrowButton;
    procedure DestroyUpDown;
    procedure DestroyArrowBtn;
    procedure ArrowMouseDown(Sender: TObject; {%H-}Button: TMouseButton;
                                            {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure UpDownClick(Sender: TObject; Button: TUDBtnType);
    procedure SetFocusIfPossible;
    procedure AutoResizeButton;
    procedure CheckAndApplyKey(const Key: Char);
    procedure CheckAndApplyKeyCode(var Key: Word; const ShState: TShiftState);
    procedure SetOptions(const aOptions: TDateTimePickerOptions);

  protected
    procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;
    procedure WMSize(var Message: TLMSize); message LM_SIZE;

    class function GetControlClassDefaultSize: TSize; override;

    procedure ConfirmChanges; virtual;
    procedure UndoChanges; virtual;

    procedure DropDownCalendarForm;

    function GetCheckBoxRect(IgnoreRightToLeft: Boolean = False): TRect;
    function GetDateTimePartFromTextPart(TextPart: TTextPart): TDateTimePart;
    function GetSelectedDateTimePart: TDateTimePart;
    procedure FontChanged(Sender: TObject); override;
    function GetTextOrigin(IgnoreRightToLeft: Boolean = False): TPoint;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: char); override;
    procedure SelectTextPartUnderMouse(XMouse: Integer);
    procedure MouseLeave; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel({%H-}Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure UpdateDate(const CallChangeFromSetDateTime: Boolean = False); virtual;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Click; override;
    procedure DblClick; override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure CalculatePreferredSize(var PreferredWidth,
                  PreferredHeight: integer; {%H-}WithThemeSpace: Boolean); override;
    procedure SetBiDiMode(AValue: TBiDiMode); override;

    procedure IncreaseCurrentTextPart;
    procedure DecreaseCurrentTextPart;
    procedure IncreaseMonth;
    procedure IncreaseYear;
    procedure IncreaseDay;
    procedure DecreaseMonth;
    procedure DecreaseYear;
    procedure DecreaseDay;
    procedure IncreaseHour;
    procedure IncreaseMinute;
    procedure IncreaseSecond;
    procedure IncreaseMiliSec;
    procedure DecreaseHour;
    procedure DecreaseMinute;
    procedure DecreaseSecond;
    procedure DecreaseMiliSec;
    procedure ChangeAMPM;

    procedure SelectDay;
    procedure SelectMonth;
    procedure SelectYear;
    procedure SelectHour;
    procedure SelectMinute;
    procedure SelectSecond;
    procedure SelectMiliSec;
    procedure SelectAMPM;

    procedure SetEnabled(Value: Boolean); override;
    procedure SetAutoSize(Value: Boolean); override;
    procedure CreateWnd; override;
    procedure SetDateTimeJumpMinMax(const AValue: TDateTime);
    procedure ArrangeCtrls; virtual;
    procedure Change; virtual;
    procedure CheckBoxChange; virtual;
    procedure DoDropDown; virtual;
    procedure DoCloseUp; virtual;
    procedure DoAutoCheck; virtual;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;

    procedure AddHandlerOnChange(const AOnChange: TNotifyEvent;
      AsFirst: Boolean = False); virtual;
    procedure AddHandlerOnCheckBoxChange(const AOnCheckBoxChange: TNotifyEvent;
      AsFirst: Boolean = False); virtual;
    procedure RemoveHandlerOnChange(AOnChange: TNotifyEvent); virtual;
    procedure RemoveHandlerOnCheckBoxChange(AOnCheckBoxChange: TNotifyEvent); virtual;

    property BorderStyle default bsSingle;
    property AutoSize default True;
    property TabStop default True;
    property ParentColor default False;
    property CenturyFrom: Word
             read FCenturyFrom write SetCenturyFrom;
    property DateDisplayOrder: TDateDisplayOrder
             read FDateDisplayOrder write SetDateDisplayOrder default ddoTryDefault;
    property MaxDate: TDate
             read FMaxDate write SetMaxDate;
    property MinDate: TDate
             read FMinDate write SetMinDate;
    property DateTime: TDateTime read GetDateTime write SetDateTime;
    property TrailingSeparator: Boolean
             read FTrailingSeparator write SetTrailingSeparator;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property LeadingZeros: Boolean read FLeadingZeros write SetLeadingZeros;
    property TextForNullDate: TCaption
             read FTextForNullDate write SetTextForNullDate nodefault;
    property NullInputAllowed: Boolean
             read FNullInputAllowed write SetNullInputAllowed default True;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnCheckBoxChange: TNotifyEvent
             read FOnCheckBoxChange write FOnCheckBoxChange;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
    property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
    property ShowCheckBox: Boolean
             read FShowCheckBox write SetShowCheckBox default False;
    property Checked: Boolean read GetChecked write SetChecked default True;
    property ArrowShape: TArrowShape
             read FArrowShape write SetArrowShape default asTheme;
    property Kind: TDateTimeKind
             read FKind write SetKind;
    property DateSeparator: String
             read FDateSeparator write SetDateSeparator stored AreSeparatorsStored;
    property TimeSeparator: String
             read FTimeSeparator write SetTimeSeparator stored AreSeparatorsStored;
    property UseDefaultSeparators: Boolean
             read FUseDefaultSeparators write SetUseDefaultSeparators;
    property TimeFormat: TTimeFormat read FTimeFormat write SetTimeFormat;
    property TimeDisplay: TTimeDisplay read FTimeDisplay write SetTimeDisplay;
    property Time: TTime read GetTime write SetTime;
    property Date: TDate read GetDate write SetDate;
    property DateMode: TDTDateMode read FDateMode write SetDateMode;
    property Cascade: Boolean read FCascade write FCascade default False;
    property AutoButtonSize: Boolean
             read FAutoButtonSize write SetAutoButtonSize default False;
    property AutoAdvance: Boolean
             read FAutoAdvance write FAutoAdvance default True;
    property HideDateTimeParts: TDateTimeParts
             read FHideDateTimeParts write SetHideDateTimeParts;
    property CalendarWrapperClass: TCalendarControlWrapperClass
             read FCalendarWrapperClass write SetCalendarWrapperClass;
    property MonthNames: String read FMonthNames write SetMonthNames;
    property ShowMonthNames: Boolean
             read FShowMonthNames write SetShowMonthNames default False;
    property DroppedDown: Boolean read GetDroppedDown;
    property CalAlignment: TDTCalAlignment read FCalAlignment write SetCalAlignment default dtaDefault;
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property Options: TDateTimePickerOptions read FOptions write SetOptions default cDefOptions;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DateIsNull: Boolean;
    procedure SelectDate;
    procedure SelectTime;
    procedure SendExternalKey(const aKey: Char);
    procedure SendExternalKeyCode(const Key: Word);
    procedure RemoveAllHandlersOfObject(AnObject: TObject); override;

    procedure Paint; override;
    procedure EditingDone; override;

  published
    //
  end;

  {TDateTimePicker}

  TDateTimePicker = class(TCustomDateTimePicker)
  public
    procedure AddHandlerOnChange(const AOnChange: TNotifyEvent; AsFirst: Boolean = False
      ); override;
    procedure AddHandlerOnCheckBoxChange(const AOnCheckBoxChange: TNotifyEvent;
      AsFirst: Boolean = False); override;
    procedure RemoveHandlerOnChange(AOnChange: TNotifyEvent); override;
    procedure RemoveHandlerOnCheckBoxChange(AOnCheckBoxChange: TNotifyEvent); override;
  public
    property DateTime;
    property CalendarWrapperClass;
    property DroppedDown;
  published
    property ArrowShape;
    property ShowCheckBox;
    property Checked;
    property CenturyFrom;
    property DateDisplayOrder;
    property MaxDate;
    property MinDate;
    property ReadOnly;
    property AutoSize;
    property Font;
    property ParentFont;
    property TabOrder;
    property TabStop;
    property BorderStyle;
    property BorderSpacing;
    property Enabled;
    property Color;
    property ParentColor;
    property DateSeparator;
    property TrailingSeparator;
    property TextForNullDate;
    property LeadingZeros;
    property ShowHint;
    property ParentShowHint;
    property Align;
    property Anchors;
    property Constraints;
    property Cursor;
    property PopupMenu;
    property Visible;
    property NullInputAllowed;
    property Kind;
    property TimeSeparator;
    property TimeFormat;
    property TimeDisplay;
    property DateMode;
    property Date;
    property Time;
    property UseDefaultSeparators;
    property Cascade;
    property AutoButtonSize;
    property AutoAdvance;
    property HideDateTimeParts;
    property BiDiMode;
    property ParentBiDiMode;
    property MonthNames;
    property ShowMonthNames;
    property CalAlignment;
    property Alignment;
    property Options;
// events:
    property OnChange;
    property OnCheckBoxChange;
    property OnDropDown;
    property OnCloseUp;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnEditingDone;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnShowHint;
    property OnUTF8KeyPress;
  end;

function EqualDateTime(const A, B: TDateTime): Boolean;
function IsNullDate(DT: TDateTime): Boolean;

implementation

uses
  DateUtils, LCLCalWrapper;

const
  DefaultUpDownWidth = 15;
  DefaultArrowButtonWidth = DefaultUpDownWidth + 2;

function NumberOfDaysInMonth(const Month, Year: Word): Word;
begin
  Result := 0;
  if Month in [1..12] then
    Result := MonthDays[IsLeapYear(Year), Month];
end;

{ EqualDateTime
  --------------
  Returns True when two dates are equal or both are null }
function EqualDateTime(const A, B: TDateTime): Boolean;
begin
  if IsNullDate(A) then
    Result := IsNullDate(B)
  else
    Result := (not IsNullDate(B)) and (A = B);
end;

function IsNullDate(DT: TDateTime): Boolean;
begin
  Result := IsNan(DT) or IsInfinite(DT) or
            (DT > SysUtils.MaxDateTime) or (DT < SysUtils.MinDateTime);
end;

type

  { TDTUpDown }

{ The two buttons contained by UpDown control are never disabled in original
  UpDown class. This class is defined here to override this behaviour. }
  TDTUpDown = class(TCustomUpDown)
  private
    DTPicker: TCustomDateTimePicker;
  protected
    procedure SetEnabled(Value: Boolean); override;
    procedure CalculatePreferredSize(var PreferredWidth,
                  PreferredHeight: integer; WithThemeSpace: Boolean); override;
    procedure WndProc(var Message: TLMessage); override;
  end;

  { TDTSpeedButton }

  TDTSpeedButton = class(TCustomSpeedButton)
  private
    DTPicker: TCustomDateTimePicker;
  protected
    procedure CalculatePreferredSize(var PreferredWidth,
                  PreferredHeight: integer; WithThemeSpace: Boolean); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
      override;
  public
    procedure Paint; override;
  end;

  { TDTCalendarForm }

  TDTCalendarForm = class(TForm)
  private
    DTPicker: TCustomDateTimePicker;
    Cal: TCalendarControlWrapper;
    Shape: TShape;
    RememberedCalendarFormOrigin: TPoint;
    FClosing: Boolean;
    DTPickersParentForm: TCustomForm;

    procedure SetClosingCalendarForm;
    procedure AdjustCalendarFormSize;
    procedure AdjustCalendarFormScreenPosition;
    procedure CloseCalendarForm(const AndSetTheDate: Boolean = False);

    procedure CalendarResize(Sender: TObject);
    procedure CalendarClick(Sender: TObject);
    procedure VisibleOfParentChanged(Sender: TObject);

  protected
    procedure Deactivate; override;
    procedure DoShow; override;
    procedure DoClose(var CloseAction: TCloseAction); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;

    procedure WMActivate(var Message: TLMActivate); message LM_ACTIVATE;
  public
    constructor CreateNewDTCalendarForm(AOwner: TComponent;
                  ADTPicker: TCustomDateTimePicker);
    destructor Destroy; override;
  published
  end;

{ TDateTimePicker }

procedure TDateTimePicker.AddHandlerOnChange(const AOnChange: TNotifyEvent;
  AsFirst: Boolean);
begin
  inherited AddHandlerOnChange(AOnChange, AsFirst);
end;

procedure TDateTimePicker.AddHandlerOnCheckBoxChange(
  const AOnCheckBoxChange: TNotifyEvent; AsFirst: Boolean);
begin
  inherited AddHandlerOnCheckBoxChange(AOnCheckBoxChange, AsFirst);
end;

procedure TDateTimePicker.RemoveHandlerOnChange(AOnChange: TNotifyEvent);
begin
  inherited RemoveHandlerOnChange(AOnChange);
end;

procedure TDateTimePicker.RemoveHandlerOnCheckBoxChange(
  AOnCheckBoxChange: TNotifyEvent);
begin
  inherited RemoveHandlerOnCheckBoxChange(AOnCheckBoxChange);
end;

procedure TDTCalendarForm.SetClosingCalendarForm;
begin
  if not FClosing then begin
    FClosing := True;

    if Assigned(DTPicker) and (DTPicker.FCalendarForm = Self) then
      DTPicker.FCalendarForm := nil;

  end;
end;

procedure TDTCalendarForm.AdjustCalendarFormSize;
begin
  if not FClosing then begin
    ClientWidth := Cal.GetCalendarControl.Width + 2;
    ClientHeight := Cal.GetCalendarControl.Height + 2;

    Shape.SetBounds(0, 0, ClientWidth, ClientHeight);

    AdjustCalendarFormScreenPosition;

  end;
end;

procedure TDTCalendarForm.AdjustCalendarFormScreenPosition;
var
  M: TMonitor;
  R: TRect;
  P: TPoint;
  H, W: Integer;
begin
  H := Height;
  W := Width;

  if (DTPicker.CalAlignment = dtaRight) or
        ((DTPicker.CalAlignment = dtaDefault) and IsRightToLeft) then
    P := DTPicker.ControlToScreen(Point(DTPicker.Width - W, DTPicker.Height))
  else
    P := DTPicker.ControlToScreen(Point(0, DTPicker.Height));

  M := Screen.MonitorFromWindow(DTPicker.Handle);

  R := M.WorkareaRect;
  // WorkareaRect sometimes is not implemented (gtk2?). Depends on widgetset
  // and window manager or something like that. Then it returns (0,0,0,0) and
  // the best we can do is use BoundsRect instead:
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then
    R := M.BoundsRect;

  if P.y > R.Bottom - H then
    P.y := P.y - H - DTPicker.Height;

  if P.y < R.Top then
    P.y := R.Top;

  if P.x > R.Right - W then
    P.x := R.Right - W;

  if P.x < R.Left then
    P.x := R.Left;

  if (P.x <> RememberedCalendarFormOrigin.x)
            or (P.y <> RememberedCalendarFormOrigin.y) then begin
    SetBounds(P.x, P.y, W, H);
    RememberedCalendarFormOrigin := P;
  end;

end;

procedure TDTCalendarForm.CloseCalendarForm(const AndSetTheDate: Boolean);
begin
  if not FClosing then
    try
      SetClosingCalendarForm;
      Visible := False;

      if Assigned(DTPicker) and DTPicker.IsVisible then begin

        if AndSetTheDate then begin
          Inc(DTPicker.FUserChanging);
          try
            DTPicker.SetDate(Cal.GetDate);
            DTPicker.DoAutoCheck;
          finally
            Dec(DTPicker.FUserChanging);
          end;
        end;

        if Screen.ActiveCustomForm = Self then
          DTPicker.SetFocusIfPossible;

        DTPicker.DoCloseUp;
      end;

    finally
      Release;
    end;

end;

procedure TDTCalendarForm.KeyDown(var Key: Word; Shift: TShiftState);
var
  ApplyTheDate: Boolean;

begin
  inherited KeyDown(Key, Shift);

  case Key of

    VK_ESCAPE, VK_RETURN, VK_SPACE, VK_TAB:
      if Cal.InMonthView then begin
        ApplyTheDate := Key in [VK_RETURN, VK_SPACE];
        Key := 0;
        CloseCalendarForm(ApplyTheDate);
      end;

    VK_UP:
      if Shift = [ssAlt] then begin
        Key := 0;
        CloseCalendarForm;
      end;

    // Suppress Alt (not doing so can produce SIGSEGV on Win widgetset ?!)
    VK_MENU, VK_LMENU, VK_RMENU:
      Key := 0;

  end;

end;

procedure TDTCalendarForm.CalendarResize(Sender: TObject);
begin
  AdjustCalendarFormSize;
end;

procedure TDTCalendarForm.CalendarClick(Sender: TObject);
var
  P: TPoint;
begin
  P := Cal.GetCalendarControl.ScreenToClient(Mouse.CursorPos);
  if Cal.AreCoordinatesOnDate(P.x, P.y) then
     CloseCalendarForm(True);

end;

{ This procedure is added to list of "visible change handlers" of DTPicker's
  parent form, so that hiding of DTPicker's parent form does not leave the
  calendar form visible. }
procedure TDTCalendarForm.VisibleOfParentChanged(Sender: TObject);
begin
  SetClosingCalendarForm;
  Release;
end;

procedure TDTCalendarForm.WMActivate(var Message: TLMActivate);
var
  PP: HWND;
begin
  inherited WMActivate(Message);

  PP := LCLIntf.GetParent(Handle);
  if PP <> 0 then
    SendMessage(PP, LM_NCACTIVATE, Ord(Message.Active <> WA_INACTIVE), 0);
end;

procedure TDTCalendarForm.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);

  if (AComponent = DTPickersParentForm) and (Operation = opRemove) then
    DTPickersParentForm := nil;

end;

procedure TDTCalendarForm.Deactivate;
begin
  inherited Deactivate;

  CloseCalendarForm;
end;

procedure TDTCalendarForm.DoShow;
begin
  if not FClosing then begin
    inherited DoShow;

    AdjustCalendarFormSize;
    DTPicker.DoDropDown; // calls OnDropDown event handler
  end;
end;

procedure TDTCalendarForm.DoClose(var CloseAction: TCloseAction);
begin
  SetClosingCalendarForm;
  CloseAction := caFree;

  inherited DoClose(CloseAction);
end;

constructor TDTCalendarForm.CreateNewDTCalendarForm(AOwner: TComponent;
  ADTPicker: TCustomDateTimePicker);
var
  P: TPoint;
  CalClass: TCalendarControlWrapperClass;
begin
  inherited CreateNew(AOwner);

  ADTPicker.FAllowDroppingCalendar := False;
  FClosing := False;

  DTPicker := ADTPicker;
  BiDiMode := DTPicker.BiDiMode;
  DTPickersParentForm := GetParentForm(DTPicker);
  if Assigned(DTPickersParentForm) then begin
    DTPickersParentForm.AddHandlerOnVisibleChanged(@VisibleOfParentChanged);
    DTPickersParentForm.FreeNotification(Self);
    PopupParent := DTPickersParentForm;
    PopupMode := pmExplicit;
  end else
    PopupMode := pmAuto;

  P := Point(0, 0);

  if ADTPicker.FCalendarWrapperClass = nil then begin
    if DefaultCalendarWrapperClass = nil then
      CalClass := TLCLCalendarWrapper
    else
      CalClass := DefaultCalendarWrapperClass;
  end else
    CalClass := ADTPicker.FCalendarWrapperClass;

  Cal := CalClass.Create;

  Cal.GetCalendarControl.ParentBiDiMode := True;
  Cal.GetCalendarControl.AutoSize := True;
  Cal.GetCalendarControl.GetPreferredSize(P.x, P.y);
  Cal.GetCalendarControl.Align := alNone;
  Cal.GetCalendarControl.SetBounds(1, 1, P.x, P.y);

  SetBounds(-8000, -8000, P.x + 2, P.y + 2);
  RememberedCalendarFormOrigin := Point(-8000, -8000);

  ShowInTaskBar := stNever;
  BorderStyle := bsNone;

  Shape := TShape.Create(nil);
  Shape.Brush.Style := bsClear;

  if DTPicker.DateIsNull then
    Cal.SetDate(Max(DTPicker.MinDate, Min(SysUtils.Date, DTPicker.MaxDate)))

  else if DTPicker.DateTime < DTPicker.MinDate then // These "out of bounds" values
    Cal.SetDate(DTPicker.MinDate)      // can happen when DateTime was set with
  else if DTPicker.DateTime > DTPicker.MaxDate then // "SetDateTimeJumpMinMax" protected
    Cal.SetDate(DTPicker.MaxDate)      // procedure (used in TDBDateTimePicker control).

  else
    Cal.SetDate(DTPicker.Date);

  Cal.GetCalendarControl.OnResize := @CalendarResize;
  Cal.GetCalendarControl.OnClick := @CalendarClick;
  if Cal.GetCalendarControl is TWinControl then begin
    TWinControl(Cal.GetCalendarControl).TabStop := True;
    TWinControl(Cal.GetCalendarControl).SetFocus;
  end;
  Self.KeyPreview := True;

  Shape.Parent := Self;
  Cal.GetCalendarControl.Parent := Self;
  Cal.GetCalendarControl.BringToFront;
end;

destructor TDTCalendarForm.Destroy;
begin
  SetClosingCalendarForm;

  if Assigned(DTPickersParentForm) then
    DTPickersParentForm.RemoveAllHandlersOfObject(Self);

  FreeAndNil(Cal);
  FreeAndNil(Shape);

  if Assigned(DTPicker) then begin
    if Screen.ActiveControl = DTPicker then
      DTPicker.Invalidate;

    if DTPicker.FCalendarForm = nil then
      DTPicker.FAllowDroppingCalendar := True;

  end;

  inherited Destroy;
end;

{ TCustomDateTimePicker }

procedure TCustomDateTimePicker.SetChecked(const AValue: Boolean);
begin
  if (FChecked = AValue) or not FShowCheckBox then
    Exit;
  FChecked := AValue;

  CheckBoxChange;
  CheckTextEnabled;
  Invalidate;
end;

procedure TCustomDateTimePicker.CheckTextEnabled;
begin
  FTextEnabled := Self.Enabled and ((dtpoEnabledIfUnchecked in Options) or GetChecked);

  if Assigned(FArrowButton) then
    FArrowButton.Enabled := FTextEnabled;

  if Assigned(FUpDown) then
    FUpDown.Enabled := FTextEnabled;
end;

procedure TCustomDateTimePicker.SetDateDisplayOrder(
  const AValue: TDateDisplayOrder);
var
  PreviousEffectiveDDO: TDateDisplayOrder;
begin
  if FDateDisplayOrder <> AValue then begin
    PreviousEffectiveDDO := FEffectiveDateDisplayOrder;
    FDateDisplayOrder := AValue;
    AdjustEffectiveDateDisplayOrder;
    if FEffectiveDateDisplayOrder <> PreviousEffectiveDDO then begin
      AdjustSelection;
      UpdateDate;
    end;
  end;
end;

procedure TCustomDateTimePicker.SetDateMode(const AValue: TDTDateMode);
begin
  FDateMode := AValue;
  UpdateShowArrowButton;
end;

procedure TCustomDateTimePicker.SetHideDateTimeParts(AValue: TDateTimeParts);
begin
  if FHideDateTimeParts <> AValue then begin
    FHideDateTimeParts := AValue;
    AdjustEffectiveHideDateTimeParts;
  end;
end;

procedure TCustomDateTimePicker.SetKind(const AValue: TDateTimeKind);
begin
  if FKind <> AValue then begin
    FKind := AValue;
    AdjustEffectiveHideDateTimeParts;
  end;
end;

procedure TCustomDateTimePicker.SetLeadingZeros(const AValue: Boolean);
begin
  if FLeadingZeros = AValue then Exit;

  FLeadingZeros := AValue;
  UpdateDate;
end;

procedure TCustomDateTimePicker.SetMonthNames(AValue: String);
var
  I, N, LenMNSep: Integer;
  MonthNamesSeparator: String;

begin
  if FMonthNames <> AValue then begin
    AValue := TrimRight(AValue);
    FMonthNames := AValue;

    if CompareText(AValue, 'SHORT') = 0 then
      for I := Low(TMonthNameArray) to High(TMonthNameArray) do
        FMonthNamesArray[I] := AnsiToUtf8(DefaultFormatSettings.ShortMonthNames[I])
    else begin
      N := 0;
      if Length(AValue) >= 24 then begin
        MonthNamesSeparator := UTF8Copy(AValue, 1, 1);
        LenMNSep := Length(MonthNamesSeparator);
        if LenMNSep > 0 then begin
          Delete(AValue, 1, LenMNSep);

          while N < 12 do begin
            I := Pos(MonthNamesSeparator, AValue);
            if I <= 1 then begin
              if (I = 0) and (N = 11) and (Length(AValue) > 0) then begin
                Inc(N);
                FMonthNamesArray[N] := AValue;
              end;

              Break;
            end;

            Inc(N);
            Dec(I);
            FMonthNamesArray[N] := Copy(AValue, 1, I);
            Delete(AValue, 1, I + LenMNSep);
          end;

        end;
      end;

      if N < 12 then
        for I := Low(TMonthNameArray) to High(TMonthNameArray) do
          FMonthNamesArray[I] := AnsiToUtf8(DefaultFormatSettings.LongMonthNames[I]);
    end;

    if FShowMonthNames and
              not (dtpMonth in FEffectiveHideDateTimeParts) then begin
      FRecalculatingTextSizesNeeded := True;
      UpdateDate;
    end;
  end;
end;

procedure TCustomDateTimePicker.SetNullInputAllowed(const AValue: Boolean);
begin
  FNullInputAllowed := AValue;
end;

procedure TCustomDateTimePicker.SetOptions(
  const aOptions: TDateTimePickerOptions);
begin
  if FOptions = aOptions then Exit;
  FOptions := aOptions;

  if FArrowButton <> nil then
    FArrowButton.Flat := dtpoFlatButton in Options;

  if FUpDown <> nil then
    TDTUpDown(FUpDown).Flat := dtpoFlatButton in Options;

  CheckTextEnabled;
  Invalidate;
end;

procedure TCustomDateTimePicker.SetDate(const AValue: TDate);
begin
  if IsNullDate(AValue) then
    DateTime := NullDate
  else if DateIsNull then
    DateTime := Int(AValue)
  else
    DateTime := ComposeDateTime(AValue, FDateTime);
end;

procedure TCustomDateTimePicker.SetDateTime(const AValue: TDateTime);
begin
  if not EqualDateTime(AValue, FDateTime) then begin
    if IsNullDate(AValue) then
      FDateTime := NullDate
    else
      FDateTime := AValue;

    UpdateDate(dtpoDoChangeOnSetDateTime in FOptions);
  end else
    UpdateDate;

end;

procedure TCustomDateTimePicker.SetDateSeparator(const AValue: String);
begin
  SetSeparators(AValue, FTimeSeparator);
end;

procedure TCustomDateTimePicker.SetMaxDate(const AValue: TDate);
begin
  if not IsNullDate(AValue) then begin

    if AValue > TheBiggestDate then
      FMaxDate := TheBiggestDate
    else if AValue <= FMinDate then
      FMaxDate := FMinDate
    else
      FMaxDate := Int(AValue);

    if not DateIsNull then
      if FMaxDate < GetDate then
        SetDate(FMaxDate);

    AdjustEffectiveCenturyFrom;
  end;
end;

procedure TCustomDateTimePicker.SetMinDate(const AValue: TDate);
begin
  if not IsNullDate(AValue) then begin

    if AValue < TheSmallestDate then
      FMinDate := TheSmallestDate
    else if AValue >= FMaxDate then
      FMinDate := FMaxDate
    else
      FMinDate := Int(AValue);

    if not DateIsNull then
      if FMinDate > GetDate then
        SetDate(FMinDate);

    AdjustEffectiveCenturyFrom;
  end;
end;

procedure TCustomDateTimePicker.SetReadOnly(const AValue: Boolean);
begin
  if FReadOnly <> AValue then begin
    if AValue then
      ConfirmChanges;

    FReadOnly := AValue;
  end;
end;

procedure TCustomDateTimePicker.SetShowCheckBox(const AValue: Boolean);
begin
  if FShowCheckBox = AValue then
    Exit;

  FShowCheckBox := AValue;
  ArrangeCtrls;
end;

procedure TCustomDateTimePicker.SetShowMonthNames(AValue: Boolean);
begin
  if FShowMonthNames <> AValue then begin
    FShowMonthNames := AValue;
    if not (dtpMonth in FEffectiveHideDateTimeParts) then begin
      FRecalculatingTextSizesNeeded := True;
      UpdateDate;
    end;
  end;
end;

procedure TCustomDateTimePicker.SetTextForNullDate(const AValue: TCaption);
begin
  if FTextForNullDate = AValue then
    Exit;

  FTextForNullDate := AValue;
  if DateIsNull then
    Invalidate;
end;

procedure TCustomDateTimePicker.SetTime(const AValue: TTime);
begin
  if IsNullDate(AValue) then
    DateTime := NullDate
  else if DateIsNull then
    DateTime := ComposeDateTime(Max(Min(SysUtils.Date, MaxDate), MinDate), AValue)
  else
    DateTime := ComposeDateTime(FDateTime, AValue);
end;

procedure TCustomDateTimePicker.SetTimeSeparator(const AValue: String);
begin
  SetSeparators(FDateSeparator, AValue);
end;

procedure TCustomDateTimePicker.SetTimeDisplay(const AValue: TTimeDisplay);
begin
  if FTimeDisplay <> AValue then begin
    FTimeDisplay:= AValue;
    AdjustEffectiveHideDateTimeParts;
  end;
end;

procedure TCustomDateTimePicker.SetTimeFormat(const AValue: TTimeFormat);
begin
  if FTimeFormat <> AValue then begin
    FTimeFormat := AValue;
    AdjustEffectiveHideDateTimeParts;
  end;
end;

procedure TCustomDateTimePicker.SetTrailingSeparator(const AValue: Boolean);
begin
  if FTrailingSeparator <> AValue then begin
    FTrailingSeparator := AValue;
    FRecalculatingTextSizesNeeded := True;
    UpdateIfUserChangedText;
    Invalidate;
  end;
end;

procedure TCustomDateTimePicker.SetUseDefaultSeparators(const AValue: Boolean);
begin
  if FUseDefaultSeparators <> AValue then begin
    if AValue then begin
      SetSeparators(DefaultFormatSettings.DateSeparator,
                      DefaultFormatSettings.TimeSeparator);
        // Note that here, in SetSeparators procedure,
        // the field FUseDefaultSeparators is set to False.
    end;
    // Therefore, the following line must NOT be moved above.
    FUseDefaultSeparators := AValue;
  end;
end;

{ RecalculateTextSizesIfNeeded
 --------------------------------
  In this procedure we measure text and store the values in the following
  fields: FDateWidth, FTimeWidth, FTextWidth, FTextHeigth, FDigitWidth,
  FSeparatorWidth, FTimeSeparatorWidth, FSepNoSpaceWidth. These fields are used
  in calculating our preffered size and when painting.
  The procedure is called internally when needed (when properties which
  influence the appearence change). }
procedure TCustomDateTimePicker.RecalculateTextSizesIfNeeded;
const
  NullMonthChar = 'x';
var
  C: Char;
  N, J: Integer;
  S: String;
  I: TDateTimePart;
  DateParts, TimeParts: Integer;
begin
  if HandleAllocated and FRecalculatingTextSizesNeeded then begin
    FRecalculatingTextSizesNeeded := False;

    FDigitWidth := 0;
    for C := '0' to '9' do begin
      N := Canvas.GetTextWidth(C);
      if N > FDigitWidth then
        FDigitWidth := N;
    end;

    DateParts := 0;
    FSepNoSpaceWidth := 0;
    FSeparatorWidth := 0;
    FMonthWidth := 0;
    FDateWidth := 0;
    FNullMonthText := '';
    S := '';
    if FKind in [dtkDate, dtkDateTime] then begin

      for I := dtpDay to dtpYear do
        if not (I in FEffectiveHideDateTimeParts) then begin
          Inc(DateParts);
          if I = dtpYear then begin
            FDateWidth := FDateWidth + 4 * FDigitWidth;
          end else if (I = dtpMonth) and FShowMonthNames then begin
            FMonthWidth := FDigitWidth; // Minimal MonthWidth is DigitWidth.
            for J := Low(TMonthNameArray) to High(TMonthNameArray) do begin
              N := Canvas.GetTextWidth(FMonthNamesArray[J]);
              if N > FMonthWidth then
                FMonthWidth := N;
            end;

            N := Canvas.GetTextWidth(NullMonthChar);
            if N > 0 then begin
              N := (FMonthWidth - 1) div N + 1;
              if N > 1 then begin
                FNullMonthText := StringOfChar(NullMonthChar, N);
                N := Canvas.TextFitInfo(FNullMonthText, FMonthWidth);
                if N > 1 then
                  SetLength(FNullMonthText, N);
              end;
            end;
            if N <= 1 then
              FNullMonthText := NullMonthChar;

            FDateWidth := FDateWidth + FMonthWidth;
          end else
            FDateWidth := FDateWidth + 2 * FDigitWidth;

        end;

      if DateParts > 0 then begin
        if FTrailingSeparator then begin
          FSepNoSpaceWidth := Canvas.GetTextWidth(TrimRight(FDateSeparator));
          Inc(FDateWidth, FSepNoSpaceWidth);
        end;

        if DateParts > 1 then begin
          FSeparatorWidth := Canvas.GetTextWidth(FDateSeparator);
          S := FDateSeparator;

          FDateWidth := FDateWidth + (DateParts - 1) * FSeparatorWidth;
        end;
      end;

    end;

    TimeParts := 0;
    FTimeWidth := 0;
    FAMPMWidth := 0;
    FTimeSeparatorWidth := 0;
    if FKind in [dtkTime, dtkDateTime] then begin

      for I := dtpHour to dtpMiliSec do
        if not (I in FEffectiveHideDateTimeParts) then begin
          Inc(TimeParts);

          if I = dtpMiliSec then
            FTimeWidth := FTimeWidth + 3 * FDigitWidth
          else
            FTimeWidth := FTimeWidth + 2 * FDigitWidth;

        end;

      if TimeParts > 1 then begin
        FTimeSeparatorWidth := Canvas.GetTextWidth(FTimeSeparator);
        S := S + FTimeSeparator;
        FTimeWidth := FTimeWidth + (TimeParts - 1) * FTimeSeparatorWidth;
      end;

      if not (dtpAMPM in FEffectiveHideDateTimeParts) then begin
        S := S + 'APM';
        FAMPMWidth := Max(Canvas.TextWidth('AM'), Canvas.TextWidth('PM'));
        FTimeWidth := FTimeWidth + FDigitWidth + FAMPMWidth;
      end;

    end;

    FTextWidth := FDateWidth + FTimeWidth;
    if (DateParts > 0) and (TimeParts > 0) then
      FTextWidth := FTextWidth + 2 * FDigitWidth;

    FTextHeight := Canvas.GetTextHeight('0123456789' + S);

  end;
end;

function TCustomDateTimePicker.GetHMSMs(const NowIfNull: Boolean): THMSMs;
begin
  if DateIsNull then begin
    if NowIfNull then
      DecodeTime(SysUtils.Time, Result.Hour, Result.Minute, Result.Second, Result.MiliSec)
    else
      Result := Default(THMSMs);
  end else
    DecodeTime(FDateTime, Result.Hour, Result.Minute, Result.Second, Result.MiliSec);
end;

function TCustomDateTimePicker.GetYYYYMMDD(const TodayIfNull: Boolean;
  const WithCorrection: Boolean): TYMD;
begin
  if DateIsNull then begin
    if TodayIfNull then
      DecodeDate(SysUtils.Date, Result.Year, Result.Month, Result.Day)
    else
      Result := Default(TYMD);
  end else begin
    DecodeDate(FDateTime, Result.Year, Result.Month, Result.Day);
    if WithCorrection and (FCorrectedValue > 0) then begin
      case FCorrectedDTP of
        dtpDay:
          Result.Day := FCorrectedValue;
        dtpMonth:
          Result.Month := FCorrectedValue;
        dtpYear:
          Result.Year := FCorrectedValue;
      otherwise
      end;
    end;
  end;
end;

procedure TCustomDateTimePicker.SetHour(const AValue: Word);
var
  HMSMs: THMSMs;
begin
  SelectHour;

  HMSMs := GetHMSMs(True);
  HMSMs.Hour := AValue;

  SetHMSMs(HMSMs);
end;

procedure TCustomDateTimePicker.SetMiliSec(const AValue: Word);
var
  HMSMs: THMSMs;
begin
  SelectMiliSec;

  HMSMs := GetHMSMs(True);
  HMSMs.MiliSec := AValue;

  SetHMSMs(HMSMs);
end;

procedure TCustomDateTimePicker.SetMinute(const AValue: Word);
var
  HMSMs: THMSMs;
begin
  SelectMinute;

  HMSMs := GetHMSMs(True);
  HMSMs.Minute := AValue;

  SetHMSMs(HMSMs);
end;

procedure TCustomDateTimePicker.SetSecond(const AValue: Word);
var
  HMSMs: THMSMs;
begin
  SelectSecond;

  HMSMs := GetHMSMs(True);
  HMSMs.Second := AValue;

  SetHMSMs(HMSMs);
end;

procedure TCustomDateTimePicker.SetSeparators(const DateSep, TimeSep: String);
var
  SeparatorsChanged: Boolean;
begin
  FUseDefaultSeparators := False;
  SeparatorsChanged := False;

  if FDateSeparator <> DateSep then begin
    FDateSeparator := DateSep;
    SeparatorsChanged := True;
  end;

  if FTimeSeparator <> TimeSep then begin
    FTimeSeparator := TimeSep;
    SeparatorsChanged := True;
  end;

  if SeparatorsChanged then begin
    FRecalculatingTextSizesNeeded := True;
    Invalidate;
  end;

end;

procedure TCustomDateTimePicker.SetDay(const AValue: Word);
var
  YMD: TYMD;
begin
  SelectDay;
  YMD := GetYYYYMMDD(True, True);

  YMD.Day := AValue;
  SetYYYYMMDD(YMD);
end;

procedure TCustomDateTimePicker.SetMonth(const AValue: Word);
var
  YMD: TYMD;
  N: Word;
begin
  SelectMonth;
  YMD := GetYYYYMMDD(True, True);

  YMD.Month := AValue;

  N := NumberOfDaysInMonth(YMD.Month, YMD.Year);
  if YMD.Day > N then
    YMD.Day := N;

  SetYYYYMMDD(YMD);
end;

procedure TCustomDateTimePicker.SetYear(const AValue: Word);
var
  YMD: TYMD;
begin
  SelectYear;

  YMD := GetYYYYMMDD(True, True);
  YMD.Year := AValue;
  if (YMD.Month = 2) and (YMD.Day > 28) and (not IsLeapYear(YMD.Year)) then
    YMD.Day := 28;

  SetYYYYMMDD(YMD);
end;

procedure TCustomDateTimePicker.SetYYYYMMDD(const AValue: TYMD);
var
  D: TDateTime;
begin
  if TryEncodeDate(AValue.Year, AValue.Month, AValue.Day, D) then
    SetDate(D)
  else
    UpdateDate;
end;

procedure TCustomDateTimePicker.SetHMSMs(const AValue: THMSMs);
var
  T: TDateTime;
begin
  if TryEncodeTime(AValue.Hour, AValue.Minute,
                                  AValue.Second, AValue.MiliSec, T) then
    SetTime(T)
  else
    UpdateDate;
end;

procedure TCustomDateTimePicker.UpdateIfUserChangedText;
var
  W: Word;
  S: String;
begin
  if FUserChangedText then begin
    Inc(FUserChanging);
    try
      FUserChangedText := False;
      S := Trim(GetSelectedText);

      if FSelectedTextPart = 8 then begin
        W := GetHMSMs().Hour;
        if upCase(S[1]) = 'A' then begin
          if W >= 12 then
            Dec(W, 12);
        end else begin
          if W < 12 then
            Inc(W, 12);
        end;
        SetHour(W);
        FSelectedTextPart := 8;

      end else begin
        W := StrToInt(S);
        case GetSelectedDateTimePart of
          dtpYear:
            begin
              if Length(S) <= 2 then begin
                // If user entered the year in two digit format (or even only
                // one digit), we will set the year according to the CenturyFrom
                // property (We actually use FEffectiveCenturyFrom field, which
                // is adjusted to take care of MinDate and MaxDate properties,
                // besides CenturyFrom).
                if W >= (FEffectiveCenturyFrom mod 100) then
                  W := W + 100 * (FEffectiveCenturyFrom div 100)
                else
                  W := W + 100 * (FEffectiveCenturyFrom div 100 + 1);

              end;
              SetYear(W);
            end;

          dtpDay:
            SetDay(W);

          dtpMonth:
            SetMonth(W);

          dtpHour:
            begin
              if FTimeFormat = tf12 then begin
                if GetHMSMs().Hour < 12 then begin
                  if W = 12 then
                    SetHour(0)
                  else
                    SetHour(W);
                end else begin
                  if W = 12 then
                    SetHour(W)
                  else
                    SetHour(W + 12);
                end;
              end else
                SetHour(W);
            end;

          dtpMinute:
            SetMinute(W);

          dtpSecond:
            SetSecond(W);

          dtpMiliSec:
            SetMiliSec(W);

        otherwise
        end;

      end;

    finally
      FCorrectedValue := 0;
      Dec(FUserChanging);
    end;
  end;
end;

function TCustomDateTimePicker.GetSelectedText: String;
begin
  if FSelectedTextPart <= 3 then
    Result := FTextPart[FSelectedTextPart]
  else
    Result := FTimeText[TDateTimePart(FSelectedTextPart - 1)];
end;

procedure TCustomDateTimePicker.AdjustSelection;
begin
  if GetSelectedDateTimePart in FEffectiveHideDateTimeParts then
    MoveSelectionLR(False);
end;

procedure TCustomDateTimePicker.AdjustEffectiveCenturyFrom;
var
  Y1, Y2, M, D: Word;
begin
  DecodeDate(FMinDate, Y1, M, D);

  if Y1 > FCenturyFrom then
    FEffectiveCenturyFrom := Y1 // If we use CenturyFrom which is set to value
         // below MinDate's year, then when user enters two digit year, the
         // DateTime would automatically be set to MinDate value, even though
         // we perhaps allow same two-digit year in following centuries. It
         // would be less user friendly.
         // This is therefore better.

  else begin
    DecodeDate(FMaxDate, Y2, M, D);

    if Y2 < 100 then
      Y2 := 0
    else
      Dec(Y2, 99); // -- We should not use CenturyFrom if it is set to value
       // greater then MaxDate's year minus 100 years.
       // For example:
       // if CenturyFrom = 1941 and MaxDate = 31.12.2025, then if user enters
       // Year 33, we could not set the year to 2033 anyway, because of MaxDate
       // limit. Note that if we just leave CenturyFrom to effectively remain as
       // is, then in case of our example the DateTime would be automatically
       // reduced to MaxDate value. Setting the year to 1933 is rather expected
       // behaviour, so our internal field FEffectiveCenturyFrom should be 1926.

    // Therefore:
    if Y2 < FCenturyFrom then
      FEffectiveCenturyFrom := Max(Y1, Y2)
    else
      FEffectiveCenturyFrom := FCenturyFrom; // -- FCenturyFrom has passed all
                   // our tests, so we'll really use it without any correction.
  end;
end;

{ AdjustEffectiveDateDisplayOrder procedure
 -------------------------------------------
  If date display order ddoTryDefault is set, then we will decide which
  display order to use according to ShortDateFormat global variable. This
  procedure tries to achieve that by searching through short date format string,
  to see which letter comes first -- d, m or y. When it finds any of these
  characters, it assumes that date order should be d-m-y, m-d-y, or y-m-d
  respectively. If the search through ShortDateFormat is unsuccessful by any
  chance, we try the same with LongDateFormat global variable. If we don't
  succeed again, we'll assume y-m-d order.  }
procedure TCustomDateTimePicker.AdjustEffectiveDateDisplayOrder;
var
  S: String;
  I, J, Le: Integer;
  InQuoteChar: Char;
begin
  if FDateDisplayOrder = ddoTryDefault then begin
    S := DefaultFormatSettings.ShortDateFormat;
    FEffectiveDateDisplayOrder := ddoTryDefault;

    repeat
      InQuoteChar := Chr(0);
      Le := Length(S);

      I := 0;
      while I < Le do begin
        Inc(I);
        if InQuoteChar = Chr(0) then begin
          case S[I] of
            '''', '"':
              InQuoteChar := S[I];
            'D', 'd':
              begin
                { If 3 or more "d"-s are standing together, then it's day
                  of week, but here we are interested in day of month.
                  So, we have to see what is following:  }
                J := I + 1;
                while (J <= Le) and (upCase(S[J]) = 'D') do
                  Inc(J);

                if J <= I + 2 then begin
                  FEffectiveDateDisplayOrder := ddoDMY;
                  Break;
                end;

                I := J - 1;
              end;
            'M', 'm':
              begin
                FEffectiveDateDisplayOrder := ddoMDY;
                Break;
              end;
            'Y', 'y':
              begin
                FEffectiveDateDisplayOrder := ddoYMD;
                Break;
              end;
          end;
        end else
          if S[I] = InQuoteChar then
            InQuoteChar := Chr(0);

      end;

      if FEffectiveDateDisplayOrder = ddoTryDefault then begin
        { We couldn't decide with ShortDateFormat, let's try with
          LongDateFormat now. }
        S := DefaultFormatSettings.LongDateFormat;
        { But now we must set something to be default. This ensures that the
          repeat loop breaks next time. If we don't find anything in
          LongDateFormat, we'll leave with y-m-d order. }
        FEffectiveDateDisplayOrder := ddoYMD;

      end else
        Break;

    until False;

  end else
    FEffectiveDateDisplayOrder := FDateDisplayOrder;

  case FEffectiveDateDisplayOrder of
    ddoDMY:
      begin
        FDayPos := 1;
        FMonthPos := 2;
        FYearPos := 3;
      end;
    ddoMDY:
      begin
        FDayPos := 2;
        FMonthPos := 1;
        FYearPos := 3;
      end;
  otherwise
    FDayPos := 3;
    FMonthPos := 2;
    FYearPos := 1;
  end;

end;

procedure TCustomDateTimePicker.AdjustEffectiveHideDateTimeParts;
var
  I: TDateTimePart;
  PreviousEffectiveHideDateTimeParts: set of TDateTimePart;
begin
  PreviousEffectiveHideDateTimeParts := FEffectiveHideDateTimeParts;
  FEffectiveHideDateTimeParts := [];

  for I := Low(TDateTimeParts) to High(TDateTimeParts) do
    if I in FHideDateTimeParts then
      Include(FEffectiveHideDateTimeParts, I);

  if FKind = dtkDate then
    FEffectiveHideDateTimeParts := FEffectiveHideDateTimeParts +
                       [dtpHour, dtpMinute, dtpSecond, dtpMiliSec, dtpAMPM]
  else begin
    if FKind = dtkTime then
      FEffectiveHideDateTimeParts := FEffectiveHideDateTimeParts +
                            [dtpDay, dtpMonth, dtpYear];

    case FTimeDisplay of
      tdHM:
        FEffectiveHideDateTimeParts := FEffectiveHideDateTimeParts +
                            [dtpSecond, dtpMiliSec];
      tdHMS:
        FEffectiveHideDateTimeParts := FEffectiveHideDateTimeParts +
                                        [dtpMiliSec];
    otherwise
    end;

    if (FTimeFormat = tf24) or (dtpHour in FEffectiveHideDateTimeParts) then
      Include(FEffectiveHideDateTimeParts, dtpAMPM);
  end;

  if FEffectiveHideDateTimeParts
                          <> PreviousEffectiveHideDateTimeParts then begin
    AdjustSelection;
    FRecalculatingTextSizesNeeded := True;
    UpdateShowArrowButton;
    UpdateDate;
  end;
end;

procedure TCustomDateTimePicker.SelectDateTimePart(
  const DateTimePart: TDateTimePart);
begin
  if not (DateTimePart in FEffectiveHideDateTimeParts) then begin
    case DateTimePart of
      dtpDay:
        FSelectedTextPart := FDayPos;
      dtpMonth:
        FSelectedTextPart := FMonthPos;
      dtpYear:
        FSelectedTextPart := FYearPos;
    else
      FSelectedTextPart := 1 + Ord(DateTimePart);
    end;

    Invalidate;
  end;
end;

procedure TCustomDateTimePicker.DestroyCalendarForm;
begin
  if Assigned(FCalendarForm) then begin
    TDTCalendarForm(FCalendarForm).FClosing := True;
    FCalendarForm.Release;
    FCalendarForm := nil;
  end;
end;

class function TCustomDateTimePicker.GetControlClassDefaultSize: TSize;
begin
  Result.cx := 102;
  Result.cy := 23;
end;

procedure TCustomDateTimePicker.ConfirmChanges;
begin
  UpdateIfUserChangedText;
  FConfirmedDateTime := FDateTime;
end;

procedure TCustomDateTimePicker.UndoChanges;
begin
  if FDateTime = FConfirmedDateTime then begin
    Inc(FSkipChangeInUpdateDate); // prevents calling Change in UpdateDate,
    try  // but UpdateDate should be called anyway, because user might have
         // changed text on screen and it should be updated to what it was.
      UpdateDate;
    finally
      Dec(FSkipChangeInUpdateDate);
    end;
  end else begin
    FDateTime := FConfirmedDateTime;
    UpdateDate;
  end;

end;

{ GetDateTimePartFromTextPart function
 -----------------------------------------------
  Returns part of date/time from the position (1-8). }
function TCustomDateTimePicker.GetDateTimePartFromTextPart(
  TextPart: TTextPart): TDateTimePart;
begin
  Result := TDateTimePart(TextPart - 1);

  case FEffectiveDateDisplayOrder of
    ddoMDY:
      if Result = dtpDay then
        Result := dtpMonth
      else if Result = dtpMonth then
        Result := dtpDay;
    ddoYMD:
      if Result = dtpDay then
        Result := dtpYear
      else if Result = dtpYear then
        Result := dtpDay;
  otherwise
  end;
end;

{ GetSelectedDateTimePart function
 ---------------------------------
  Returns part of date/time which is currently selected. }
function TCustomDateTimePicker.GetSelectedDateTimePart: TDateTimePart;
begin
  Result := GetDateTimePartFromTextPart(FSelectedTextPart);
end;

procedure TCustomDateTimePicker.FontChanged(Sender: TObject);
begin
  FRecalculatingTextSizesNeeded := True;
  inherited FontChanged(Sender);
end;

function TCustomDateTimePicker.GetCheckBoxRect(
  IgnoreRightToLeft: Boolean): TRect;
var
  Details: TThemedElementDetails;
  CSize: TSize;

begin
  Details := ThemeServices.GetElementDetails(tbCheckBoxCheckedNormal);
  CSize := ThemeServices.GetDetailSize(Details);
  CSize.cx := ScaleScreenToFont(CSize.cx);
  CSize.cy := ScaleScreenToFont(CSize.cy);

  if IsRightToLeft and not IgnoreRightToLeft then begin
    Result.Right := ClientWidth - (BorderSpacing.InnerBorder + BorderWidth);
    Result.Left := Result.Right - CSize.cx;
  end else begin
    Result.Left := BorderSpacing.InnerBorder + BorderWidth;
    Result.Right := Result.Left + CSize.cx;
  end;
  Result.Top := (ClientHeight - CSize.cy) div 2;
  Result.Bottom := Result.Top + CSize.cy;
end;

{ GetTextOrigin
 ---------------
  Returns upper left corner of the rectangle where the text is written.
  Also used in calculating our preffered size. }
function TCustomDateTimePicker.GetTextOrigin(IgnoreRightToLeft: Boolean
  ): TPoint;

var   
  Re: TRect;
  B: Integer;
  XL, XR: Integer;
  AuxAlignment: TAlignment;
begin
  B := BorderSpacing.InnerBorder + BorderWidth;
  Result.y := B;

  if IgnoreRightToLeft or AutoSize then
    AuxAlignment := taLeftJustify
  else begin
    AuxAlignment := FAlignment;
    if IsRightToLeft then begin
      case AuxAlignment of
        taRightJustify:
          AuxAlignment := taLeftJustify;
        taLeftJustify:
          AuxAlignment := taRightJustify;
      otherwise
      end;
    end;
  end;

  if FShowCheckBox then begin
    Re := GetCheckBoxRect(IgnoreRightToLeft);
    InflateRect(Re, Scale96ToFont(cCheckBoxBorder), 0);
    XL := Re.Right;
    XR := Re.Left;
  end else begin
    XL := B;
    XR := ClientWidth - B;
  end;

  if Assigned(FUpDown) then
    B := B + FUpDown.Width
  else if Assigned(FArrowButton) then
    B := B + FArrowButton.Width;

  if IgnoreRightToLeft or not IsRightToLeft then begin
    XR := ClientWidth - B;
  end else begin
    XL := B;
  end;

  case AuxAlignment of
    taRightJustify:
      Result.x := XR - FTextWidth;
    taCenter:
      Result.x := (XL + XR - FTextWidth) div 2;
    taLeftJustify:
      Result.x := XL;
  end;

end;

{ MoveSelectionLR
 -----------------
  Moves selection to left or to right. If parameter ToLeft is true, then the
  selection moves to left, otherwise to right. }
procedure TCustomDateTimePicker.MoveSelectionLR(const ToLeft: Boolean);
var
  I, SafetyTextPart: TTextPart;
begin
  UpdateIfUserChangedText;

  SafetyTextPart := Low(TTextPart);
  I := FSelectedTextPart;
  repeat
    if ToLeft then begin
      if I <= Low(TTextPart) then
        I := High(TTextPart)
      else
        Dec(I);
    end else begin
      if I >= High(TTextPart) then
        I := Low(TTextPart)
      else
        Inc(I);
    end;

    if not (GetDateTimePartFromTextPart(I) in FEffectiveHideDateTimeParts) then
      FSelectedTextPart := I;

    { Is it possible that all parts are hidden? Yes it is!
      So we need to ensure that this doesn't loop forever.
      When this insurance text part gets to high value, break }
    Inc(SafetyTextPart);
  until (I = FSelectedTextPart) or (SafetyTextPart >= High(TTextPart));
end;

procedure TCustomDateTimePicker.KeyDown(var Key: Word; Shift: TShiftState);
begin
  Inc(FUserChanging);
  try
    if FTextEnabled then
      inherited KeyDown(Key, Shift); // calls OnKeyDown event

    CheckAndApplyKeyCode(Key, Shift);
  finally
    Dec(FUserChanging);
  end;

end;

procedure TCustomDateTimePicker.KeyPress(var Key: char);
begin
  if FTextEnabled then begin
    Inc(FUserChanging);
    try
      inherited KeyPress(Key);

      CheckAndApplyKey(Key);
    finally
      Dec(FUserChanging);
    end;

  end;
end;

{ SelectTextPartUnderMouse
 --------------------------
  This procedure determines which text part (date or time part -- day, month,
  year, hour, minute...) should be selected in response to mouse message.
  Used in MouseDown and DoMouseWheel methods. }
procedure TCustomDateTimePicker.SelectTextPartUnderMouse(XMouse: Integer);
var
  I, M, NX: Integer;
  InTime: Boolean;

begin
  UpdateIfUserChangedText;
  SetFocusIfPossible;

  if Focused then begin
// Calculating mouse position inside text
//       in order to select date part under mouse cursor.
    NX := XMouse - GetTextOrigin.x;

    InTime := False;
    if FTimeWidth > 0 then begin
      if FDateWidth > 0 then begin
        if NX >= FDateWidth + FDigitWidth then begin
          InTime := True;
          NX := NX - FDateWidth - 2 * FDigitWidth;
        end;
      end else
        InTime := True;
    end;

    if InTime then begin
      FSelectedTextPart := 8;

      if (dtpAMPM in FEffectiveHideDateTimeParts) or
            (NX < FTimeWidth - FAMPMWidth - FDigitWidth div 2) then begin
        FSelectedTextPart := 7;
        I := 4;
        M := FTimeSeparatorWidth div 2;
        while I <= 6 do begin
          if not (GetDateTimePartFromTextPart(I)
                        in FEffectiveHideDateTimeParts) then begin
            Inc(M, 2 * FDigitWidth);
            if M > NX then begin
              FSelectedTextPart := I;
              Break;
            end;

            Inc(M, FTimeSeparatorWidth);
          end;
          Inc(I);
        end;
      end;

    end else if FDateWidth > 0 then begin

      FSelectedTextPart := 3;
      I := 1;
      M := FSeparatorWidth div 2;
      while I <= 2 do begin
        if not (GetDateTimePartFromTextPart(I)
                      in FEffectiveHideDateTimeParts) then begin
          if I = FYearPos then
            Inc(M, 4 * FDigitWidth)
          else if (I = FMonthPos) and FShowMonthNames then
            Inc(M, FMonthWidth)
          else
            Inc(M, 2 * FDigitWidth);

          if M > NX then begin
            FSelectedTextPart := I;
            Break;
          end;

          Inc(M, FSeparatorWidth);
        end;

        Inc(I);
      end;

    end;

    if GetSelectedDateTimePart in FEffectiveHideDateTimeParts then
      MoveSelectionLR(True);

    Invalidate;
//-------------------------------------------------------
  end;
end;

procedure TCustomDateTimePicker.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if ShowCheckBox and PtInRect(GetCheckBoxRect, Point(X, Y)) then
    Checked := not Checked
  else if FTextEnabled then
    SelectTextPartUnderMouse(X);

  SetFocusIfPossible;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCustomDateTimePicker.MouseLeave;
begin
  inherited MouseLeave;
  if FShowCheckBox and FMouseInCheckBox then
  begin
    FMouseInCheckBox := False;
    Invalidate;
  end;
end;

procedure TCustomDateTimePicker.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);

  if ShowCheckBox and (FMouseInCheckBox xor PtInRect(GetCheckBoxRect, Point(X, Y))) then begin
    FMouseInCheckBox := not FMouseInCheckBox;
    Invalidate;
  end;

end;

function TCustomDateTimePicker.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := False;
  if FTextEnabled then begin

    SelectTextPartUnderMouse(MousePos.x);
    if not FReadOnly then begin
      Inc(FUserChanging);
      try
        if WheelDelta < 0 then
          DecreaseCurrentTextPart
        else
          IncreaseCurrentTextPart;

        Result := True;
      finally
        Dec(FUserChanging);
      end;
    end;
  end;
end;

procedure TCustomDateTimePicker.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: integer; WithThemeSpace: Boolean);
var
  TextOrigin: TPoint;

begin
  RecalculateTextSizesIfNeeded;
  TextOrigin := GetTextOrigin(True);

  PreferredHeight := 2 * TextOrigin.y + FTextHeight + Height - ClientHeight;

  // We must use TextOrigin's x + y (x is, of course, left margin, but not right
  // margin if check box is shown. However, y, which is top margin, always
  // equals right margin).
  PreferredWidth := TextOrigin.x + TextOrigin.y
    + FTextWidth + Width - ClientWidth;

  if Assigned(FUpDown) then
    Inc(PreferredWidth, FUpDown.Width)
  else if Assigned(FArrowButton) then
    Inc(PreferredWidth, FArrowButton.Width);

end;

procedure TCustomDateTimePicker.SetBiDiMode(AValue: TBiDiMode);
begin
  inherited SetBiDiMode(AValue);
  ArrangeCtrls;
end;

procedure TCustomDateTimePicker.IncreaseCurrentTextPart;
begin
  if DateIsNull then begin
    if FSelectedTextPart <= 3 then
      SetDateTime(SysUtils.Date)
    else
      SetDateTime(SysUtils.Now);

  end else begin
    case GetSelectedDateTimePart of
      dtpDay: IncreaseDay;
      dtpMonth: IncreaseMonth;
      dtpYear: IncreaseYear;
      dtpHour: IncreaseHour;
      dtpMinute: IncreaseMinute;
      dtpSecond: IncreaseSecond;
      dtpMiliSec: IncreaseMiliSec;
      dtpAMPM: ChangeAMPM;
    end;
  end;
end;

procedure TCustomDateTimePicker.DecreaseCurrentTextPart;
begin
  if DateIsNull then begin
    if FSelectedTextPart <= 3 then
      SetDateTime(SysUtils.Date)
    else
      SetDateTime(SysUtils.Now);

  end else begin
    case GetSelectedDateTimePart of
      dtpDay: DecreaseDay;
      dtpMonth: DecreaseMonth;
      dtpYear: DecreaseYear;
      dtpHour: DecreaseHour;
      dtpMinute: DecreaseMinute;
      dtpSecond: DecreaseSecond;
      dtpMiliSec: DecreaseMiliSec;
      dtpAMPM: ChangeAMPM;
    end;
  end;
end;

procedure TCustomDateTimePicker.IncreaseMonth;
var
  YMD: TYMD;
  N: Word;
begin
  SelectMonth;

  YMD := GetYYYYMMDD(True);

  if YMD.Month >= 12 then begin
    YMD.Month := 1;
    if Cascade then
      Inc(YMD.Year);
  end else
    Inc(YMD.Month);

  N := NumberOfDaysInMonth(YMD.Month, YMD.Year);
  if YMD.Day > N then
    YMD.Day := N;

  SetYYYYMMDD(YMD);
end;

procedure TCustomDateTimePicker.IncreaseYear;
var
  YMD: TYMD;
begin
  SelectYear;
  YMD := GetYYYYMMDD(True);

  Inc(YMD.Year);
  if (YMD.Month = 2) and (YMD.Day > 28) and (not IsLeapYear(YMD.Year)) then
    YMD.Day := 28;

  SetYYYYMMDD(YMD);
end;

procedure TCustomDateTimePicker.IncreaseDay;
var
  YMD: TYMD;
begin
  SelectDay;
  if Cascade then begin
    if DateIsNull then
      SetDate(IncDay(SysUtils.Date))
    else
      SetDateTime(IncDay(FDateTime));
  end else begin
    YMD := GetYYYYMMDD(True);

    if YMD.Day >= NumberOfDaysInMonth(YMD.Month, YMD.Year) then
      YMD.Day := 1
    else
      Inc(YMD.Day);

    SetYYYYMMDD(YMD);
  end;
end;

procedure TCustomDateTimePicker.DecreaseMonth;
var
  YMD: TYMD;
  N: Word;
begin
  SelectMonth;

  YMD := GetYYYYMMDD(True);

  if YMD.Month <= 1 then begin
    YMD.Month := 12;
    if Cascade then
      Dec(YMD.Year);
  end else
    Dec(YMD.Month);

  N := NumberOfDaysInMonth(YMD.Month, YMD.Year);
  if YMD.Day > N then
    YMD.Day := N;

  SetYYYYMMDD(YMD);
end;

procedure TCustomDateTimePicker.DecreaseYear;
var
  YMD: TYMD;
begin
  SelectYear;
  YMD := GetYYYYMMDD(True);
  Dec(YMD.Year);
  if (YMD.Month = 2) and (YMD.Day > 28) and (not IsLeapYear(YMD.Year)) then
    YMD.Day := 28;
  SetYYYYMMDD(YMD);
end;

procedure TCustomDateTimePicker.DecreaseDay;
var
  YMD: TYMD;
begin
  SelectDay;
  if Cascade then begin
    if DateIsNull then
      SetDate(IncDay(SysUtils.Date, -1))
    else
      SetDateTime(IncDay(FDateTime, -1));
  end else begin
    YMD := GetYYYYMMDD(True);

    if YMD.Day <= 1 then
      YMD.Day := NumberOfDaysInMonth(YMD.Month, YMD.Year)
    else
      Dec(YMD.Day);

    SetYYYYMMDD(YMD);
  end;
end;

procedure TCustomDateTimePicker.IncreaseHour;
var
  HMSMs: THMSMs;
begin
  SelectHour;
  if Cascade then begin
    if DateIsNull then
      SetDateTime(IncHour(SysUtils.Now))
    else
      SetDateTime(IncHour(FDateTime));
  end else begin
    HMSMs := GetHMSMs(True);

    if HMSMs.Hour >= 23 then
      HMSMs.Hour := 0
    else
      Inc(HMSMs.Hour);

    SetHMSMs(HMSMs);
  end;
end;

procedure TCustomDateTimePicker.IncreaseMinute;
var
  HMSMs: THMSMs;
begin
  SelectMinute;
  if Cascade then begin
    if DateIsNull then
      SetDateTime(IncMinute(SysUtils.Now))
    else
      SetDateTime(IncMinute(FDateTime));
  end else begin
    HMSMs := GetHMSMs(True);

    if HMSMs.Minute >= 59 then
      HMSMs.Minute := 0
    else
      Inc(HMSMs.Minute);

    SetHMSMs(HMSMs);
  end;
end;

procedure TCustomDateTimePicker.IncreaseSecond;
var
  HMSMs: THMSMs;
begin
  SelectSecond;
  if Cascade then begin
    if DateIsNull then
      SetDateTime(IncSecond(SysUtils.Now))
    else
      SetDateTime(IncSecond(FDateTime));
  end else begin
    HMSMs := GetHMSMs(True);

    if HMSMs.Second >= 59 then
      HMSMs.Second := 0
    else
      Inc(HMSMs.Second);

    SetHMSMs(HMSMs);
  end;
end;

procedure TCustomDateTimePicker.IncreaseMiliSec;
var
  HMSMs: THMSMs;
begin
  SelectMiliSec;
  if Cascade then begin
    if DateIsNull then
      SetDateTime(IncMilliSecond(SysUtils.Now))
    else
      SetDateTime(IncMilliSecond(FDateTime));
  end else begin
    HMSMs := GetHMSMs(True);

    if HMSMs.MiliSec >= 999 then
      HMSMs.MiliSec := 0
    else
      Inc(HMSMs.MiliSec);

    SetHMSMs(HMSMs);
  end;
end;

procedure TCustomDateTimePicker.DecreaseHour;
var
  HMSMs: THMSMs;
begin
  SelectHour;
  if Cascade then begin
    if DateIsNull then
      SetDateTime(IncHour(SysUtils.Now, -1))
    else
      SetDateTime(IncHour(FDateTime, -1));
  end else begin
    HMSMs := GetHMSMs(True);

    if HMSMs.Hour <= 0 then
      HMSMS.Hour := 23
    else
      Dec(HMSMs.Hour);

    SetHMSMs(HMSMs);
  end;
end;

procedure TCustomDateTimePicker.DecreaseMinute;
var
  HMSMs: THMSMs;
begin
  SelectMinute;
  if Cascade then begin
    if DateIsNull then
      SetDateTime(IncMinute(SysUtils.Now, -1))
    else
      SetDateTime(IncMinute(FDateTime, -1));
  end else begin
    HMSMs := GetHMSMs(True);

    if HMSMs.Minute <= 0 then
      HMSMs.Minute := 59
    else
      Dec(HMSMs.Minute);

    SetHMSMs(HMSMs);
  end;
end;

procedure TCustomDateTimePicker.DecreaseSecond;
var
  HMSMs: THMSMs;
begin
  SelectSecond;
  if Cascade then begin
    if DateIsNull then
      SetDateTime(IncSecond(SysUtils.Now, -1))
    else
      SetDateTime(IncSecond(FDateTime, -1));
  end else begin
    HMSMs := GetHMSMs(True);

    if HMSMs.Second <= 0 then
      HMSMs.Second := 59
    else
      Dec(HMSMs.Second);

    SetHMSMs(HMSMs);
  end;
end;

procedure TCustomDateTimePicker.DecreaseMiliSec;
var
  HMSMs: THMSMs;
begin
  SelectMiliSec;
  if Cascade then begin
    if DateIsNull then
      SetDateTime(IncMilliSecond(SysUtils.Now, -1))
    else
      SetDateTime(IncMilliSecond(FDateTime, -1));
  end else begin
    HMSMs := GetHMSMs(True);

    if HMSMs.MiliSec <= 0 then
      HMSMs.MiliSec := 999
    else
      Dec(HMSMs.MiliSec);

    SetHMSMs(HMSMs);
  end;
end;

procedure TCustomDateTimePicker.ChangeAMPM;
var
  HMSMs: THMSMs;
begin
  SelectAMPM;
  HMSMs := GetHMSMs(True);

  if HMSMs.Hour >= 12 then
    Dec(HMSMS.Hour, 12)
  else
    Inc(HMSMS.Hour, 12);

  SetHMSMs(HMSMs);
end;

procedure TCustomDateTimePicker.UpdateDate(const CallChangeFromSetDateTime: Boolean);
var
  W: Array[1..3] of Word;
  WT: Array[dtpHour..dtpAMPM] of Word;
  DTP: TDateTimePart;
begin
  FCorrectedValue := 0;

  FUserChangedText := False;

  if not (DateIsNull or FJumpMinMax) then begin
    if Int(FDateTime) > FMaxDate then
      FDateTime := ComposeDateTime(FMaxDate, FDateTime);

    if FDateTime < FMinDate then
      FDateTime := ComposeDateTime(FMinDate, FDateTime);
  end;

  if (FSkipChangeInUpdateDate = 0) then begin
   // we'll skip the next part if called from UndoChanges
   // and in recursive calls which could be made through calling Change
    Inc(FSkipChangeInUpdateDate);
    try
      if (FUserChanging > 0) // the change is caused by user interaction
          or CallChangeFromSetDateTime // call from SetDateTime with option dtpoDoChangeOnSetDateTime
      then
        try
          Change;
        except
          UndoChanges;
          raise;
        end;

      if FUserChanging = 0 then
        FConfirmedDateTime := FDateTime;

    finally
      Dec(FSkipChangeInUpdateDate);
    end;
  end;

  if DateIsNull then begin
    if dtpYear in FEffectiveHideDateTimeParts then
      FTextPart[FYearPos] := ''
    else
      FTextPart[FYearPos] := '0000';

    if dtpMonth in FEffectiveHideDateTimeParts then
      FTextPart[FMonthPos] := ''
    else
      FTextPart[FMonthPos] := '00';

    if dtpDay in FEffectiveHideDateTimeParts then
      FTextPart[FDayPos] := ''
    else
      FTextPart[FDayPos] := '00';

    for DTP := dtpHour to dtpAMPM do begin
      if DTP in FEffectiveHideDateTimeParts then
        FTimeText[DTP] := ''
      else if DTP = dtpAMPM then
        FTimeText[DTP] := 'XX'
      else if DTP = dtpMiliSec then
        FTimeText[DTP] := '999'
      else
        FTimeText[DTP] := '99';
    end;

  end else begin
    DecodeDate(FDateTime, W[3], W[2], W[1]);

    if dtpYear in FEffectiveHideDateTimeParts then
      FTextPart[FYearPos] := ''
    else if FLeadingZeros then
      FTextPart[FYearPos] := RightStr('000' + IntToStr(W[3]), 4)
    else
      FTextPart[FYearPos] := IntToStr(W[3]);

    if dtpMonth in FEffectiveHideDateTimeParts then
      FTextPart[FMonthPos] := ''
    else if FShowMonthNames then
      FTextPart[FMonthPos] := FMonthNamesArray[W[2]]
    else if FLeadingZeros then
      FTextPart[FMonthPos] := RightStr('0' + IntToStr(W[2]), 2)
    else
      FTextPart[FMonthPos] := IntToStr(W[2]);

    if dtpDay in FEffectiveHideDateTimeParts then
      FTextPart[FDayPos] := ''
    else if FLeadingZeros then
      FTextPart[FDayPos] := RightStr('0' + IntToStr(W[1]), 2)
    else
      FTextPart[FDayPos] := IntToStr(W[1]);

    DecodeTime(FDateTime, WT[dtpHour], WT[dtpMinute], WT[dtpSecond], WT[dtpMiliSec]);

    if dtpAMPM in FEffectiveHideDateTimeParts then
      FTimeText[dtpAMPM] := ''
    else begin
      if WT[dtpHour] < 12 then begin
        FTimeText[dtpAMPM] := 'AM';
        if WT[dtpHour] = 0 then
          WT[dtpHour] := 12;
      end else begin
        FTimeText[dtpAMPM] := 'PM';
        if WT[dtpHour] > 12 then
          Dec(WT[dtpHour], 12);
      end;
    end;

    for DTP := dtpHour to dtpMiliSec do begin
      if DTP in FEffectiveHideDateTimeParts then
        FTimeText[DTP] := ''
      else if (DTP = dtpHour) and (not FLeadingZeros) then
        FTimeText[DTP] := IntToStr(WT[dtpHour])
      else if DTP = dtpMiliSec then
        FTimeText[DTP] := RightStr('00' + IntToStr(WT[DTP]), 3)
      else
        FTimeText[DTP] := RightStr('0' + IntToStr(WT[DTP]), 2);

    end;

  end;

  if HandleAllocated then
    Invalidate;
end;

procedure TCustomDateTimePicker.DoEnter;
begin
  if dtpoResetSelection in Options then begin
    FSelectedTextPart := High(TTextPart);
    MoveSelectionLR(False);
  end;

  inherited DoEnter;
  Invalidate;
end;

procedure TCustomDateTimePicker.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TCustomDateTimePicker.Click;
begin
  if FTextEnabled then
    inherited Click;
end;

procedure TCustomDateTimePicker.DblClick;
begin
  if FTextEnabled then
    inherited DblClick;
end;

procedure TCustomDateTimePicker.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if FTextEnabled then
    inherited MouseUp(Button, Shift, X, Y);
end;

procedure TCustomDateTimePicker.KeyUp(var Key: Word; Shift: TShiftState);
begin
  if FTextEnabled then
    inherited KeyUp(Key, Shift);
end;

procedure TCustomDateTimePicker.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  if FTextEnabled then
    inherited UTF8KeyPress(UTF8Key);
end;

procedure TCustomDateTimePicker.SelectDay;
begin
  SelectDateTimePart(dtpDay);
end;

procedure TCustomDateTimePicker.SelectMonth;
begin
  SelectDateTimePart(dtpMonth);
end;

procedure TCustomDateTimePicker.SelectYear;
begin
  SelectDateTimePart(dtpYear);
end;

procedure TCustomDateTimePicker.SendExternalKey(const aKey: Char);
var
  K: Word;
begin
  if FTextEnabled then begin
    if aKey in ['n', 'N'] then begin
      K := VK_N;
      CheckAndApplyKeyCode(K, []);
    end else
      CheckAndApplyKey(aKey);
  end;
end;

procedure TCustomDateTimePicker.SendExternalKeyCode(const Key: Word);
var
  Ch: Char;
  K: Word;
begin
  if Key in [Ord('0')..Ord('9'), Ord('a'), Ord('A'), Ord('p'), Ord('P')] then begin
    if FTextEnabled then begin
      Ch := Char(Key);
      CheckAndApplyKey(Ch);
    end;
  end else begin
    K := Key;
    CheckAndApplyKeyCode(K, []);
  end;

end;

procedure TCustomDateTimePicker.RemoveAllHandlersOfObject(AnObject: TObject);
begin
  inherited RemoveAllHandlersOfObject(AnObject);

  if Assigned(FOnChangeHandlers) then
    FOnChangeHandlers.RemoveAllMethodsOfObject(AnObject);

  if Assigned(FOnCheckBoxChangeHandlers) then
    FOnCheckBoxChangeHandlers.RemoveAllMethodsOfObject(AnObject);
end;

procedure TCustomDateTimePicker.SelectHour;
begin
  SelectDateTimePart(dtpHour);
end;

procedure TCustomDateTimePicker.SelectMinute;
begin
  SelectDateTimePart(dtpMinute);
end;

procedure TCustomDateTimePicker.SelectSecond;
begin
  SelectDateTimePart(dtpSecond);
end;

procedure TCustomDateTimePicker.SelectMiliSec;
begin
  SelectDateTimePart(dtpMiliSec);
end;

procedure TCustomDateTimePicker.SelectAMPM;
begin
  SelectDateTimePart(dtpAMPM);
end;

procedure TCustomDateTimePicker.SetEnabled(Value: Boolean);
begin
  if GetEnabled <> Value then begin
    inherited SetEnabled(Value);
    CheckTextEnabled;
    Invalidate;
  end;
end;

procedure TCustomDateTimePicker.SetAutoSize(Value: Boolean);
begin
  if AutoSize <> Value then begin
    if Value then
      InvalidatePreferredSize;

    inherited SetAutoSize(Value);
  end;
end;

// I had to override CreateWnd, because in design time on Linux Lazarus crashes
// if we try to do anchoring of child controls in constructor.
// Therefore, I needed to ensure that controls anchoring does not take place
// before CreateWnd has done. So, I moved all anchoring code to a procedure
// ArrangeCtrls and introduced a boolean field FDoNotArrangeControls which
// prevents that code from executing before CreateWnd.
//!!! Later, I simplified the arranging procedure, so maybe it can be done now
//    before window creation is done. It's better to leave this delay system,
//    anyway -- we might change anchoring code again for some reason.
procedure TCustomDateTimePicker.CreateWnd;
begin
  inherited CreateWnd;

  if FDoNotArrangeControls then begin { This field is set to True in constructor.
    Its purpose is to prevent control anchoring until this point. That's because
    on Linux Lazarus crashes when control is dropped on form in designer if
    particular anchoring code executes before CreateWnd has done its job. }
    FDoNotArrangeControls := False;
    ArrangeCtrls;
  end;
end;

procedure TCustomDateTimePicker.SetDateTimeJumpMinMax(const AValue: TDateTime);
begin
  FJumpMinMax := True;
  try
    SetDateTime(AValue);
  finally
    FJumpMinMax := False;
  end;
end;

procedure TCustomDateTimePicker.ArrangeCtrls;
var
  C: TControl;
begin
  if not FDoNotArrangeControls then begin //Read the note above CreateWnd procedure.
    DisableAlign;
    try
      if Assigned(FUpDown) then
        C := FUpDown
      else
        C := FArrowButton; // might be nil.

      if Assigned(C) then begin
        if IsRightToLeft then
          C.Align := alLeft
        else
          C.Align := alRight;

        C.BringToFront;
      end;

      CheckTextEnabled;
      InvalidatePreferredSize;
      AdjustSize;

      Invalidate;
    finally
      EnableAlign;
    end;
  end;
end;

procedure TCustomDateTimePicker.Change;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
  if FOnChangeHandlers <> nil then
    FOnChangeHandlers.CallNotifyEvents(Self);
end;

procedure TCustomDateTimePicker.SelectDate;
begin
  if (FSelectedTextPart > 3)
          or (GetSelectedDateTimePart in FEffectiveHideDateTimeParts) then
    FSelectedTextPart := 1;

  AdjustSelection;

  Invalidate;
end;

procedure TCustomDateTimePicker.SelectTime;
begin
  if (FSelectedTextPart < 4)
          or (GetSelectedDateTimePart in FEffectiveHideDateTimeParts) then
    FSelectedTextPart := 4;

  AdjustSelection;

  Invalidate;
end;

procedure TCustomDateTimePicker.Paint;
var
  I, M, N, K, L: Integer;
  DD: Array[1..8] of Integer;
  R: TRect;
  SelectStep: 0..8;
  TextStyle: TTextStyle;
  DTP: TDateTimePart;
  S: String;

const
  CheckStates: array[Boolean, Boolean, Boolean] of TThemedButton = (
    ((tbCheckBoxUncheckedDisabled, tbCheckBoxUncheckedDisabled),
     (tbCheckBoxCheckedDisabled, tbCheckBoxCheckedDisabled)),
    ((tbCheckBoxUncheckedNormal, tbCheckBoxUncheckedHot),
     (tbCheckBoxCheckedNormal, tbCheckBoxCheckedHot)));

begin
  if ClientRectNeedsInterfaceUpdate then // In Qt widgetset, this solves the
    DoAdjustClientRectChange;           // problem of dispositioned client rect.

  if FRecalculatingTextSizesNeeded then begin
    if AutoSize then begin
      InvalidatePreferredSize;
      AdjustSize;
    end;

    RecalculateTextSizesIfNeeded;
  end;

  TextStyle := Canvas.TextStyle;

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  R.TopLeft := GetTextOrigin;
  if not AutoSize then
    R.Top := (ClientHeight - FTextHeight) div 2;

  R.Bottom := R.Top + FTextHeight;

  TextStyle.Layout := tlCenter;
  TextStyle.Wordbreak := False;
  TextStyle.Opaque := False;
  TextStyle.RightToLeft := IsRightToLeft;

  if DateIsNull and (FTextForNullDate <> '')
                       and (not (FTextEnabled and Focused)) then begin

    if IsRightToLeft then begin
      TextStyle.Alignment := taRightJustify;
      R.Right := R.Left + FTextWidth;
      R.Left := 0;
    end else begin
      TextStyle.Alignment := taLeftJustify;
      R.Right := Width;
    end;

    if FTextEnabled then
      Canvas.Font.Color := Font.Color
    else
      Canvas.Font.Color := clGrayText;

    Canvas.TextRect(R, R.Left, R.Top, FTextForNullDate, TextStyle);

  end else begin
    TextStyle.Alignment := taRightJustify;

    SelectStep := 0;
    if FTextEnabled then begin
      Canvas.Font.Color := Font.Color;
      if Focused then
        SelectStep := FSelectedTextPart;
    end else begin
      Canvas.Font.Color := clGrayText;
    end;

    if dtpYear in FEffectiveHideDateTimeParts then begin
      DD[FYearPos] := 0;
      M := 4;
      L := 0;
    end else begin
      DD[FYearPos] := 4 * FDigitWidth;
      M := FYearPos;
      L := FYearPos;
    end;

    if dtpMonth in FEffectiveHideDateTimeParts then
      DD[FMonthPos] := 0
    else begin
      if FShowMonthNames then
        DD[FMonthPos] := FMonthWidth
      else
        DD[FMonthPos] := 2 * FDigitWidth;

      if FMonthPos < M then
        M := FMonthPos;

      if FMonthPos > L then
        L := FMonthPos;

    end;

    if dtpDay in FEffectiveHideDateTimeParts then
      DD[FDayPos] := 0
    else begin
      DD[FDayPos] := 2 * FDigitWidth;
      if FDayPos < M then
        M := FDayPos;
      if FDayPos > L then
        L := FDayPos;
    end;

    N := L;
    K := 0;
    for DTP := dtpHour to dtpAMPM do begin
      I := Ord(DTP) + 1;
      if DTP in FEffectiveHideDateTimeParts then
        DD[I] := 0
      else if DTP = dtpAMPM then begin
        DD[I] := FAMPMWidth;
        N := I;
      end else begin
        if DTP = dtpMiliSec then
          DD[I] := 3 * FDigitWidth
        else
          DD[I] := 2 * FDigitWidth;

        K := I;
      end;
    end;

    if N < K then
      N := K;

    for I := M to N do begin
      if DD[I] <> 0 then begin

        R.Right := R.Left + DD[I];
        if I <= 3 then begin
          if (I = FMonthPos) and FShowMonthNames then begin
            TextStyle.Alignment := taCenter;
            if DateIsNull then
              S := FNullMonthText
            else
              S := FTextPart[I];
          end else
            S := FTextPart[I];

        end else
          S := FTimeText[TDateTimePart(I - 1)];

        if I = SelectStep then begin
          TextStyle.Opaque := True;
          Canvas.Brush.Color := clHighlight;
          Canvas.Font.Color := clHighlightText;

          Canvas.TextRect(R, R.Left, R.Top, S, TextStyle);

          TextStyle.Opaque := False;
          Canvas.Brush.Color := Color;
          Canvas.Font.Color := Self.Font.Color;
        end else
          Canvas.TextRect(R, R.Left, R.Top, S, TextStyle);

        TextStyle.Alignment := taRightJustify;
        R.Left := R.Right;

        if I < L then begin
          R.Right := R.Left + FSeparatorWidth;
          if not ((I = FMonthPos) and FShowMonthNames) then
            Canvas.TextRect(R, R.Left, R.Top, FDateSeparator, TextStyle);
        end else if I > L then begin
          if I = K then begin
            R.Right := R.Left + FDigitWidth;
          end else if I < K then begin
            R.Right := R.Left + FTimeSeparatorWidth;
            Canvas.TextRect(R, R.Left, R.Top, FTimeSeparator, TextStyle);
          end;
        end else begin
          if FTrailingSeparator then begin
            R.Right := R.Left + FSepNoSpaceWidth;
            Canvas.TextRect(R, R.Left, R.Top,
                                      TrimRight(FDateSeparator), TextStyle);
          end;
          if FTimeWidth > 0 then
            R.Right := R.Right + 2 * FDigitWidth;

        end;
        R.Left := R.Right;
      end;
    end;

  end;

  if ShowCheckBox then
    ThemeServices.DrawElement(Canvas.Handle,
      ThemeServices.GetElementDetails(CheckStates[Enabled, Checked, FMouseInCheckBox]),
      GetCheckBoxRect);

  inherited Paint;
end;

procedure TCustomDateTimePicker.EditingDone;
begin
  if FNoEditingDone <= 0 then begin
    ConfirmChanges;

    inherited EditingDone;
  end;
end;

procedure TCustomDateTimePicker.ArrowMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  SetFocusIfPossible;

  if FAllowDroppingCalendar then
    DropDownCalendarForm
  else begin
    DestroyCalendarForm;
    FAllowDroppingCalendar := True;
  end;

end;

procedure TCustomDateTimePicker.UpDownClick(Sender: TObject;
  Button: TUDBtnType);
begin
  SetFocusIfPossible;

  if not FReadOnly then begin
    Inc(FUserChanging);
    try
      if Button = btNext then
        IncreaseCurrentTextPart
      else
        DecreaseCurrentTextPart;
    finally
      Dec(FUserChanging);
    end;
  end;
end;

procedure TCustomDateTimePicker.DoDropDown;
begin
  if Assigned(FOnDropDown) then
    FOnDropDown(Self);
end;

procedure TCustomDateTimePicker.DoCloseUp;
begin
  if Assigned(FOnCloseUp) then
    FOnCloseUp(Self);
end;

function TCustomDateTimePicker.GetChecked: Boolean;
begin
  Result := (not FShowCheckBox) or FChecked;
end;

function TCustomDateTimePicker.AreSeparatorsStored: Boolean;
begin
  Result := not FUseDefaultSeparators;
end;

function TCustomDateTimePicker.GetDate: TDate;
begin
  if DateIsNull then
    Result := NullDate
  else
    Result := Int(FDateTime);
end;

function TCustomDateTimePicker.GetDateTime: TDateTime;
begin
  if DateIsNull then
    Result := NullDate
  else
    Result := FDateTime;
end;

function TCustomDateTimePicker.GetDroppedDown: Boolean;
begin
  Result := Assigned(FCalendarForm);
end;

function TCustomDateTimePicker.GetTime: TTime;
begin
  if DateIsNull then
    Result := NullDate
  else
    Result := Abs(Frac(FDateTime));
end;

procedure TCustomDateTimePicker.SetAlignment(AValue: TAlignment);
begin
  if FAlignment <> AValue then begin
    FAlignment := AValue;
    Invalidate;
  end;
end;

procedure TCustomDateTimePicker.SetArrowShape(const AValue: TArrowShape);
begin
  if FArrowShape = AValue then Exit;

  FArrowShape := AValue;
  if FArrowButton <> nil then
    FArrowButton.Invalidate;
end;

procedure TCustomDateTimePicker.SetAutoButtonSize(AValue: Boolean);
begin
  if FAutoButtonSize <> AValue then begin
    FAutoButtonSize := AValue;

    if AValue then
      AutoResizeButton
    else begin
      if Assigned(FUpDown) then
        FUpDown.Width := Scale96ToFont(DefaultUpDownWidth)
      else if Assigned(FArrowButton) then
        FArrowButton.Width := Scale96ToFont(DefaultArrowButtonWidth);
    end;

  end;
end;

procedure TCustomDateTimePicker.SetCalAlignment(AValue: TDTCalAlignment);
begin
  if FCalAlignment = AValue then Exit;
  FCalAlignment := AValue;
end;

procedure TCustomDateTimePicker.SetCalendarWrapperClass(
  AValue: TCalendarControlWrapperClass);
begin
  if FCalendarWrapperClass = AValue then Exit;
  FCalendarWrapperClass := AValue;
end;

procedure TCustomDateTimePicker.SetCenturyFrom(const AValue: Word);
begin
  if FCenturyFrom = AValue then Exit;

  FCenturyFrom := AValue;
  AdjustEffectiveCenturyFrom;
end;

procedure TCustomDateTimePicker.CheckBoxChange;
begin
  if Assigned(FOnCheckBoxChange) then
    FOnCheckBoxChange(Self);

  if FOnCheckBoxChangeHandlers <> nil then
    FOnCheckBoxChangeHandlers.CallNotifyEvents(Self);
end;

procedure TCustomDateTimePicker.SetFocusIfPossible;
var
  F: TCustomForm;

begin
  Inc(FNoEditingDone);
  try
    F := GetParentForm(Self);

    if Assigned(F) and F.CanFocus and CanTab then
      SetFocus;

  finally
    Dec(FNoEditingDone);
  end;
end;

procedure TCustomDateTimePicker.AutoResizeButton;
begin
  if Assigned(FArrowButton) then
    FArrowButton.Width := MulDiv(ClientHeight, 9, 10)
  else if Assigned(FUpDown) then
    FUpDown.Width := MulDiv(ClientHeight, 79, 100);
end;

procedure TCustomDateTimePicker.CheckAndApplyKey(const Key: Char);
var
  S: String;
  DTP: TDateTimePart;
  N, L: Integer;
  YMD: TYMD;
  HMSMs: THMSMs;
  D, T: TDateTime;
  Finished, ForceChange: Boolean;

begin
  FCorrectedValue := 0;
  if not FReadOnly then begin
    Finished := False;
    ForceChange := False;

    if FSelectedTextPart = 8 then begin
      case upCase(Key) of
        'A': S := 'AM';
        'P': S := 'PM';
      else
        Finished := True;
      end;
      ForceChange := True;

    end else if Key in ['0'..'9'] then begin

      DTP := GetSelectedDateTimePart;

      if DTP = dtpYear then
        N := 4
      else if DTP = dtpMiliSec then
        N := 3
      else
        N := 2;

      S := Trim(GetSelectedText);
      if FUserChangedText and (Length(S) < N) then
        S := S + Key
      else
        S := Key;

      if Length(S) >= N then begin

        L := StrToInt(S);
        if DTP < dtpHour then begin
          YMD := GetYYYYMMDD(True);
          case DTP of
            dtpDay:
              YMD.Day := L;
            dtpMonth:
              YMD.Month := L;
          otherwise
            YMD.Year := L;
          end;

          if AutoAdvance and (YMD.Day <= 31) and
              (YMD.Day > NumberOfDaysInMonth(YMD.Month, YMD.Year)) then begin
            FCorrectedDTP := dtpAMPM;
            case DTP of
              dtpDay:
                case FEffectiveDateDisplayOrder of
                  ddoDMY:
                    FCorrectedDTP := dtpMonth;
                  ddoMDY:
                    FCorrectedDTP := dtpYear;
                otherwise
                end;

              dtpMonth:
                case FEffectiveDateDisplayOrder of
                  ddoDMY:
                    FCorrectedDTP := dtpYear;
                otherwise
                  FCorrectedDTP := dtpDay;
                  FCorrectedValue := NumberOfDaysInMonth(YMD.Month, YMD.Year);
                  YMD.Day := FCorrectedValue;
                end;

            otherwise
              if (FEffectiveDateDisplayOrder = ddoYMD) and (YMD.Month = 2)
                    and (YMD.Day = 29) and not IsLeapYear(YMD.Year) then
                FCorrectedDTP := dtpMonth;
            end;

            case FCorrectedDTP of
              dtpMonth:
                begin
                  FCorrectedValue := YMD.Month + 1;
                  YMD.Month := FCorrectedValue;
                end;
              dtpYear:
                if (YMD.Day = 29) and (YMD.Month = 2) then begin
                  FCorrectedValue := ((YMD.Year + 3) div 4) * 4;
                  if (FCorrectedValue mod 100 = 0) and (FCorrectedValue mod 400 <> 0) then
                    FCorrectedValue := FCorrectedValue + 4;
                  YMD.Year := FCorrectedValue;
                end;
            otherwise
            end;

          end;

          if TryEncodeDate(YMD.Year, YMD.Month, YMD.Day, D)
                    and (D >= MinDate) and (D <= MaxDate) then
            ForceChange := True
          else if N = 4 then begin
            UpdateDate;
            Finished := True;
          end else
            S := Key;

        end else begin
          if (DTP = dtpHour) and (FTimeFormat = tf12) then begin
            if not (L in [1..12]) then
              S := Key
            else
              ForceChange := True;

          end else begin

            HMSMs := GetHMSMs(True);
            case DTP of
              dtpHour: HMSMs.Hour := L;
              dtpMinute: HMSMs.Minute := L;
              dtpSecond: HMSMs.Second := L;
              dtpMiliSec: HMSMs.MiliSec := L;
            otherwise
            end;

            if not TryEncodeTime(HMSMs.Hour, HMSMs.Minute, HMSMs.Second,
                                         HMSMs.MiliSec, T) then
              S := Key
            else
              ForceChange := True;

          end;
        end;

      end;
    end else
      Finished := True;

    if (not Finished) and (GetSelectedText <> S) then begin
      if (not FUserChangedText) and DateIsNull then begin
        Inc(FSkipChangeInUpdateDate); // do not call Change here
        try
          if FSelectedTextPart <= 3 then
            DateTime := SysUtils.Date
          else
            DateTime := SysUtils.Now;
        finally
          Dec(FSkipChangeInUpdateDate);
        end;
      end;

      if (not FLeadingZeros) and (FSelectedTextPart <= 4) then
        while (Length(S) > 1) and (S[1] = '0') do
          Delete(S, 1, 1);

      if FSelectedTextPart <= 3 then
        FTextPart[FSelectedTextPart] := S
      else
        FTimeText[TDateTimePart(FSelectedTextPart - 1)] := S;

      FUserChangedText := True;

      if ForceChange then begin
        if FAutoAdvance then begin
          MoveSelectionLR(False);
          Invalidate;
        end else
          UpdateIfUserChangedText;
      end else
        Invalidate;

      DoAutoCheck;
    end;

    FCorrectedValue := 0;
  end;

end;

procedure TCustomDateTimePicker.CheckAndApplyKeyCode(var Key: Word;
  const ShState: TShiftState);
var
  K: Word;
begin
  if (Key = VK_SPACE) then begin
    if ShowCheckBox then
      Checked := not Checked;

  end else if FTextEnabled then begin

    case Key of
      VK_LEFT, VK_RIGHT, VK_OEM_COMMA, VK_OEM_PERIOD, VK_DIVIDE,
          VK_OEM_MINUS, VK_SEPARATOR, VK_DECIMAL, VK_SUBTRACT:
        begin
          K := Key;
          Key := 0;
          MoveSelectionLR(K = VK_LEFT);
          Invalidate;
        end;
      VK_UP:
        begin
          Key := 0;
          UpdateIfUserChangedText;
          if not FReadOnly then
          begin
            IncreaseCurrentTextPart;
            DoAutoCheck;
          end;
        end;
      VK_DOWN:
        begin                   
          Key := 0;
          if (ShState = [ssAlt]) and Assigned(FArrowButton) then
            DropDownCalendarForm
          else begin
            UpdateIfUserChangedText;
            if not FReadOnly then
            begin
              DecreaseCurrentTextPart;
              DoAutoCheck;
            end;
          end;
        end;
      VK_RETURN:
        if not FReadOnly then
          EditingDone;

      VK_ESCAPE:
        if not FReadOnly then begin
          UndoChanges;
          EditingDone;
        end;
      VK_N:
        if (not FReadOnly) and FNullInputAllowed then
          SetDateTime(NullDate);
    end;

  end;

end;

procedure TCustomDateTimePicker.WMKillFocus(var Message: TLMKillFocus);
begin
  // On Qt it seems that WMKillFocus happens even when focus jumps to some other
  // form. This behaviour differs from win and gtk 2 (where it happens only when
  // focus jumps to other control on the same form) and we should prevent it at
  // least for our calendar, because it triggers EditingDone.
  if Screen.ActiveCustomForm <> FCalendarForm then
    inherited WMKillFocus(Message);
end;

procedure TCustomDateTimePicker.WMSize(var Message: TLMSize);
begin
  inherited WMSize(Message);

  if FAutoButtonSize then
    AutoResizeButton;
end;

procedure TCustomDateTimePicker.DropDownCalendarForm;
begin
  if FAllowDroppingCalendar and FTextEnabled and Assigned(FArrowButton) then
    if not (FReadOnly or Assigned(FCalendarForm)
                      or (csDesigning in ComponentState))
    then begin
      FCalendarForm := TDTCalendarForm.CreateNewDTCalendarForm(nil, Self);
      FCalendarForm.Show;
    end;
end;

{ TDTUpDown }

{ When our UpDown control gets enabled/disabled, the two its buttons' Enabled
  property is set accordingly. }
procedure TDTUpDown.SetEnabled(Value: Boolean);

  procedure SetEnabledForAllChildren(AWinControl: TWinControl);
  var
    I: Integer;
    C: TControl;
  begin
    for I := 0 to AWinControl.ControlCount - 1 do begin
      C := AWinControl.Controls[I];
      C.Enabled := Value;

      if C is TWinControl then
        SetEnabledForAllChildren(TWinControl(C));

    end;
  end;

begin
  inherited SetEnabled(Value);

  SetEnabledForAllChildren(Self);
end;

{ Our UpDown control is always alligned, but setting its PreferredHeight
  uncoditionally to 1 prevents the UpDown to mess with our PreferredHeight.
  The problem is that if we didn't do this, when our Height is greater than
  really preffered, UpDown prevents it to be set correctly when we set AutoSize
  to True. }
procedure TDTUpDown.CalculatePreferredSize(var PreferredWidth, PreferredHeight:
  integer; WithThemeSpace: Boolean);
begin
  inherited CalculatePreferredSize(PreferredWidth, PreferredHeight,
    WithThemeSpace);

  PreferredHeight := 1;
end;

{ We don't want to let EditingDone event to fire each time up-down buttons get
  clicked. That is why WndProc is overriden. }
procedure TDTUpDown.WndProc(var Message: TLMessage);
begin
  if ((Message.msg >= LM_MOUSEFIRST) and (Message.msg <= LM_MOUSELAST))
      or ((Message.msg >= LM_MOUSEFIRST2) and (Message.msg <= LM_MOUSELAST2)) then begin

    Inc(DTPicker.FNoEditingDone);
    try
      inherited WndProc(Message);
    finally
      Dec(DTPicker.FNoEditingDone);
    end

  end else
    inherited WndProc(Message);

end;

{ TDTSpeedButton }

{ See the comment above TDTUpDown.CalculatePreferredSize }
procedure TDTSpeedButton.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  inherited CalculatePreferredSize(PreferredWidth, PreferredHeight,
    WithThemeSpace);

  PreferredHeight := 1;
end;

{ Prevent EditingDone to fire whenever the SpeedButton gets clicked }
procedure TDTSpeedButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  Inc(DTPicker.FNoEditingDone);
  try
    inherited MouseDown(Button, Shift, X, Y);
  finally
    Dec(DTPicker.FNoEditingDone);
  end;
end;

procedure TDTSpeedButton.Paint;

  procedure DrawThemedDropDownArrow;
  var
    Details: TThemedElementDetails;
    ArrowState: TThemedToolBar;
    ASize: TSize;
    ARect: TRect;
  begin
    if Enabled then
      ArrowState := ttbSplitButtonDropDownNormal
    else
      ArrowState := ttbSplitButtonDropDownDisabled;
    Details := ThemeServices.GetElementDetails(ArrowState);
    ASize := ThemeServices.GetDetailSize(Details);
    ARect := Rect(0, 0, Width, Height);
    InflateRect(ARect, -(ARect.Right - ARect.Left - ASize.cx) div 2, 0);
    ThemeServices.DrawElement(Canvas.Handle, Details, ARect);
  end;

const
  ArrowColor = TColor($8D665A);

var
  X, Y: Integer;

begin
  inherited Paint;

  if DTPicker.FArrowShape = asTheme then
    DrawThemedDropDownArrow
  else begin
  // First I ment to put arrow images in a lrs file. In my opinion, however, that
  // wouldn't be an elegant option for so simple shapes.

    Canvas.Brush.Style := bsSolid;
    Canvas.Pen.Color := ArrowColor;
    Canvas.Brush.Color := Canvas.Pen.Color;

    X := (Width - 9) div 2;
    Y := (Height - 6) div 2;

    { Let's draw shape of the arrow on the button: }
    case DTPicker.FArrowShape of
      asClassicLarger:
        { triangle: }
        Canvas.Polygon([Point(X + 0, Y + 1), Point(X + 8, Y + 1),
                                                        Point(X + 4, Y + 5)]);
      asClassicSmaller:
        { triangle -- smaller variant:  }
        Canvas.Polygon([Point(X + 1, Y + 2), Point(X + 7, Y + 2),
                                                        Point(X + 4, Y + 5)]);
      asModernLarger:
        { modern: }
        Canvas.Polygon([Point(X + 0, Y + 1), Point(X + 1, Y + 0),
                          Point(X + 4, Y + 3), Point(X + 7, Y + 0), Point(X + 8, Y + 1), Point(X + 4, Y + 5)]);
      asModernSmaller:
        { modern -- smaller variant:    }
        Canvas.Polygon([Point(X + 1, Y + 2), Point(X + 2, Y + 1),
                          Point(X + 4, Y + 3), Point(X + 6, Y + 1), Point(X + 7, Y + 2), Point(X + 4, Y + 5)]);
    otherwise // asYetAnotherShape:
      { something in between, not very pretty:  }
      Canvas.Polygon([Point(X + 0, Y + 1), Point(X + 1, Y + 0),
            Point(X + 2, Y + 1), Point(X + 6, Y + 1),Point(X + 7, Y + 0), Point(X + 8, Y + 1), Point(X + 4, Y + 5)]);
    end;

  end;
end;

procedure TCustomDateTimePicker.UpdateShowArrowButton;

  procedure CreateArrowBtn;
  begin
    if not Assigned(FArrowButton) then begin
      DestroyCalendarForm;
      DestroyUpDown;

      FArrowButton := TDTSpeedButton.Create(Self);
      FArrowButton.ControlStyle := FArrowButton.ControlStyle +
                                            [csNoFocus, csNoDesignSelectable];
      FArrowButton.Flat := dtpoFlatButton in Options;
      TDTSpeedButton(FArrowButton).DTPicker := Self;
      FArrowButton.SetBounds(0, 0, Scale96ToFont(DefaultArrowButtonWidth), 1);

      FArrowButton.Parent := Self;
      FAllowDroppingCalendar := True;

      TDTSpeedButton(FArrowButton).OnMouseDown := @ArrowMouseDown;

    end;
  end;

  procedure CreateUpDown;
  begin
    if not Assigned(FUpDown) then begin
      DestroyArrowBtn;

      FUpDown := TDTUpDown.Create(Self);
      FUpDown.ControlStyle := FUpDown.ControlStyle +
                                     [csNoFocus, csNoDesignSelectable];

      TDTUpDown(FUpDown).DTPicker := Self;
      TDTUpDown(FUpDown).Flat := dtpoFlatButton in Options;

      FUpDown.SetBounds(0, 0, Scale96ToFont(DefaultUpDownWidth), 1);

      FUpDown.Parent := Self;

      TDTUpDown(FUPDown).OnClick := @UpDownClick;

    end;
  end;

var
  ReallyShowArrowButton: Boolean;

begin
  if FDateMode = dmNone then begin
    DestroyArrowBtn;
    DestroyUpDown;

  end else begin
    ReallyShowArrowButton := (FDateMode = dmComboBox) and
                          not (dtpDay in FEffectiveHideDateTimeParts);

    if (ReallyShowArrowButton <> Assigned(FArrowButton)) or
                       (Assigned(FArrowButton) = Assigned(FUpDown)) then begin
      DisableAlign;
      try
        if ReallyShowArrowButton then
          CreateArrowBtn
        else
          CreateUpDown;

        ArrangeCtrls;

      finally
        EnableAlign;
      end;
    end;

  end;
end;

procedure TCustomDateTimePicker.DestroyUpDown;
begin
  if Assigned(FUpDown) then begin
    TDTUpDown(FUPDown).OnClick := nil;
    FreeAndNil(FUpDown);
  end;
end;

procedure TCustomDateTimePicker.DoAutoCheck;
begin
  if dtpoAutoCheck in Options then
    SetChecked(True);
end;

procedure TCustomDateTimePicker.DoAutoAdjustLayout(
  const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
begin
  inherited;
  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    if (not FAutoButtonSize) then begin
      if Assigned(FArrowButton) then
        FArrowButton.Width := Scale96ToFont(DefaultArrowButtonWidth);
      if Assigned(FUpDown) then
        FUpDown.Width := Scale96ToFont(DefaultUpdownWidth);
    end;
  end;
end;

procedure TCustomDateTimePicker.DestroyArrowBtn;
begin
  if Assigned(FArrowButton) then begin
    TDTSpeedButton(FArrowButton).OnMouseDown := nil;
    DestroyCalendarForm;
    FreeAndNil(FArrowButton);
  end;
end;

constructor TCustomDateTimePicker.Create(AOwner: TComponent);
var
  I: Integer;
  DTP: TDateTimePart;
begin
  inherited Create(AOwner);

  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, cx, cy);

  FAlignment := taLeftJustify;
  FCalAlignment := dtaDefault;
  FCorrectedDTP := dtpAMPM;
  FCorrectedValue := 0;
  FSkipChangeInUpdateDate := 0;
  FNoEditingDone := 0;
  FArrowShape := asTheme;
  FAllowDroppingCalendar := True;
  FChecked := True;

  FOnDropDown := nil;
  FOnCloseUp := nil;

  ParentColor := False;
  FArrowButton := nil;
  FUpDown := nil;

  FKind := dtkDate;
  FNullInputAllowed := True;
  FOptions := cDefOptions;

  { Thanks to Luiz Américo for this:
    Lazarus ignores empty string when saving to lrs. Therefore, the problem
    is, when TextForNullDate is set to an empty string and after the project
    is saved and opened again, then, this property gets default value NULL
    instead of empty string. The following condition seems to be a workaround
    for this. }
  {$if fpc_fullversion < 030200}
  // This hack is no more needed since FPC 3.2 (see bug report 31985)
  if (AOwner = nil) or not (csReading in Owner.ComponentState) then
  {$endif}
    FTextForNullDate := 'NULL';

  FCenturyFrom := 1941;
  FRecalculatingTextSizesNeeded := True;
  FOnChange := nil;
  FOnChangeHandlers := nil;
  FOnCheckBoxChange := nil;
  FOnCheckBoxChangeHandlers := nil;
  FSeparatorWidth := 0;
  FSepNoSpaceWidth := 0;
  FDigitWidth := 0;
  FTimeSeparatorWidth := 0;
  FAMPMWidth := 0;
  FDateWidth := 0;
  FTimeWidth := 0;
  FTextWidth := 0;
  FTextHeight := 0;
  FMonthWidth := 0;
  FHideDateTimeParts := [];
  FShowMonthNames := False;
  FNullMonthText := '';

  for I := Low(FTextPart) to High(FTextPart) do
    FTextPart[I] := '';

  for DTP := dtpHour to dtpAMPM do
    FTimeText[DTP] := '';

  FTimeDisplay := tdHMS;
  FTimeFormat := tf24;

  FLeadingZeros := True;
  FUserChanging := 0;
  FReadOnly := False;
  FDateTime := SysUtils.Now;
  FConfirmedDateTime := FDateTime;
  FMinDate := TheSmallestDate;
  FMaxDate := TheBiggestDate;
  FTrailingSeparator := False;
  FDateDisplayOrder := ddoTryDefault;
  FSelectedTextPart := 1;
  FUseDefaultSeparators := True;
  FDateSeparator := DefaultFormatSettings.DateSeparator;
  FTimeSeparator := DefaultFormatSettings.TimeSeparator;
  FEffectiveCenturyFrom := FCenturyFrom;
  FJumpMinMax := False;

  ParentColor := False;
  TabStop := True;
  BorderWidth := 2;
  BorderStyle := bsSingle;
  ParentFont := True;
  AutoSize := True;

  FTextEnabled := True;
  FCalendarForm := nil;
  FDoNotArrangeControls := True;
  FCascade := False;
  FAutoButtonSize := False;
  FAutoAdvance := True;
  FCalendarWrapperClass := nil;
  FEffectiveHideDateTimeParts := [];

  AdjustEffectiveDateDisplayOrder;
  AdjustEffectiveHideDateTimeParts;

  SetMonthNames('Long');
  SetDateMode(dmComboBox);
end;

procedure TCustomDateTimePicker.AddHandlerOnChange(
  const AOnChange: TNotifyEvent; AsFirst: Boolean);
begin
  if FOnChangeHandlers = nil then
    FOnChangeHandlers := TMethodList.Create;
  FOnChangeHandlers.Add(TMethod(AOnChange), not AsFirst);
end;

procedure TCustomDateTimePicker.AddHandlerOnCheckBoxChange(
  const AOnCheckBoxChange: TNotifyEvent; AsFirst: Boolean);
begin
  if FOnCheckBoxChangeHandlers = nil then
    FOnCheckBoxChangeHandlers := TMethodList.Create;
  FOnCheckBoxChangeHandlers.Add(TMethod(AOnCheckBoxChange), not AsFirst);
end;

procedure TCustomDateTimePicker.RemoveHandlerOnChange(AOnChange: TNotifyEvent);
begin
  if Assigned(FOnChangeHandlers) then
    FOnChangeHandlers.Remove(TMethod(AOnChange));
end;

procedure TCustomDateTimePicker.RemoveHandlerOnCheckBoxChange(
  AOnCheckBoxChange: TNotifyEvent);
begin
  if Assigned(FOnCheckBoxChangeHandlers) then
    FOnCheckBoxChangeHandlers.Remove(TMethod(AOnCheckBoxChange));
end;

destructor TCustomDateTimePicker.Destroy;
begin
  FDoNotArrangeControls := True;
  DestroyArrowBtn;
  DestroyUpDown;
  SetShowCheckBox(False);
  FOnChangeHandlers.Free;
  FOnCheckBoxChangeHandlers.Free;

  inherited Destroy;
end;

function TCustomDateTimePicker.DateIsNull: Boolean;
begin
  Result := IsNullDate(FDateTime);
end;

end.
