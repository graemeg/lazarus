{ $Id$}

{
 /***************************************************************************
                                 buttons.pp
                                 ----------
                             Component Library Code


                   Initial Revision : Sun Mar 28 23:15:32 CST 1999
                   Revised: Sat Jul 3 1999

 ***************************************************************************/

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

unit Buttons;

{$mode objfpc}{$H+}

interface

{$ifdef Trace}
{$ASSERTIONS ON}
{$endif}

uses
  Types, Classes, SysUtils, Math,
  // LCL
  LCLType, LCLProc, LCLIntf, LCLStrConsts, LResources, Graphics, ImgList, ActnList,
  Controls, StdCtrls, LMessages, Forms, Themes, Menus, ImageListCache,
  // LazUtils
  GraphType, LazUtilities;

type
  TButtonLayout =
  (
    blGlyphLeft,
    blGlyphRight,
    blGlyphTop,
    blGlyphBottom
  );

  TButtonState =
  (
    bsUp,       // button is up
    bsDisabled, // button disabled (grayed)
    bsDown,     // button is down
    bsExclusive,// button is the only down in his group
    bsHot       // button is under mouse
  );

  {
   TNumGlyphs holds the number of glyphs in an image.
   If we change this the code in SetNumGlyphs for @link(TCustomSpeedButton)
   needs to be changed
  }
  TNumGlyphs = 1..5;

  { TButtonGlyph }
  TGlyphTransparencyMode = (
    gtmGlyph,       // transparency is defined by the glyph itself (bitbtn)
    gtmOpaque,      // transparent = false is defined by the owner (speedbutton)
    gtmTransparent  // transparent = true
  );

  TButtonGlyph = class(TObject, IUnknown, IImageCacheListener)
  private
    FIsDesigning: Boolean;
    FShowMode: TGlyphShowMode;
    FImageIndexes: array[TButtonState] of Integer;
    FImages: TCustomImageList;
    FExternalImages: TCustomImageList;
    FExternalImageIndex: Integer;
    FExternalImageWidth: Integer;
    FLCLGlyphResourceName: string;
    FOriginal: TBitmap;
    FNumGlyphs: TNumGlyphs;
    FOnChange: TNotifyEvent;
    FImagesCache: TImageListCache;
    FTransparentMode: TGlyphTransparencyMode;         // set by our owner to indicate that the glyphbitmap should be transparent
    FLCLGlyphName: string;
    function GetHeight: Integer;
    function GetNumGlyphs: TNumGlyphs;
    function GetWidth: Integer;
    procedure SetExternalImageIndex(const AExternalImageIndex: Integer);
    procedure SetExternalImages(const AExternalImages: TCustomImageList);
    procedure SetExternalImageWidth(const AExternalImageWidth: Integer);
    procedure SetGlyph(Value: TBitmap);
    procedure SetNumGlyphs(Value: TNumGlyphs);
    procedure SetShowMode(const AValue: TGlyphShowMode);
    procedure ClearImages;
    procedure ClearLCLGlyph;
    procedure SetLCLGlyphName(const ALCLGlyphName: string);
  public
    // IUnknown
    function QueryInterface(constref iid: TGuid; out obj): LongInt; {$IFDEF WINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    function _AddRef: LongInt; {$IFDEF WINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    function _Release: LongInt; {$IFDEF WINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    // IImageCacheListener
    procedure CacheSetImageList(AImageList: TCustomImageList);
    procedure CacheSetImageIndex(AIndex, AImageIndex: Integer);
  protected
    function CanShow: Boolean;
    function CanShowGlyph: Boolean;
    procedure DoChange; virtual;
    procedure GlyphChanged(Sender: TObject);
    procedure SetTransparentMode(AValue: TGlyphTransparencyMode);
    
    property TransparentMode: TGlyphTransparencyMode read FTransparentMode;
  public
    constructor Create;
    destructor Destroy; override;
    procedure GetImageIndexAndEffect(State: TButtonState;
      APPI: Integer; const ACanvasScaleFactor: Double;
      out AImageResolution: TScaledImageListResolution;
      out AIndex: Integer; out AEffect: TGraphicsDrawEffect);
    function Draw(Canvas: TCanvas; const Client: TRect; const Offset: TPoint;
                  State: TButtonState; Transparent: Boolean;
                  BiDiFlags: Longint): TRect;
    function Draw(Canvas: TCanvas; const Client: TRect; const Offset: TPoint;
                  State: TButtonState; Transparent: Boolean;
                  BiDiFlags, PPI: Longint; const ScaleFactor: Double): TRect;
    procedure Refresh;
    property Glyph: TBitmap read FOriginal write SetGlyph;
    property IsDesigning: Boolean read FIsDesigning write FIsDesigning;
    property NumGlyphs: TNumGlyphs read GetNumGlyphs write SetNumGlyphs;
    property Images: TCustomImageList read FImages;
    property LCLGlyphName: string read FLCLGlyphName write SetLCLGlyphName;
    property ExternalImages: TCustomImageList read FExternalImages write SetExternalImages;
    property ExternalImageIndex: Integer read FExternalImageIndex write SetExternalImageIndex;
    property ExternalImageWidth: Integer read FExternalImageWidth write SetExternalImageWidth;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
    property ShowMode: TGlyphShowMode read FShowMode write SetShowMode;
  public
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;


  { TCustomBitBtn }

  // when adding items here, also update TBitBtn.GetCaptionOfKind
  TBitBtnKind = (bkCustom, bkOK, bkCancel, bkHelp, bkYes, bkNo,
                 bkClose, bkAbort, bkRetry, bkIgnore, bkAll,
                 bkNoToAll, bkYesToAll);
  TBitBtnKinds = set of TBitBtnKind;

  TCustomBitBtn = class(TCustomButton)
  private
    FDefaultCaption: Boolean;
    FKind: TBitBtnKind;
    FLayout: TButtonLayout;
    FMargin: integer;
    FSpacing: Integer;
    FImageChangeLink: TChangeLink;
    function GetGlyph: TBitmap;
    function GetGlyphShowMode: TGlyphShowMode;
    function GetNumGlyphs: Integer;
    procedure ImageListChange(Sender: TObject);
    function IsGlyphStored: Boolean;
    procedure SetGlyph(AValue: TBitmap);
    procedure SetGlyphShowMode(const AValue: TGlyphShowMode);
    procedure SetKind(AValue: TBitBtnKind);
    procedure SetLayout(AValue: TButtonLayout);
    procedure SetMargin(const AValue: integer);
    procedure SetNumGlyphs(AValue: Integer);
    procedure SetSpacing(AValue: Integer);
    procedure RealizeKind(ForceDefaults: Boolean);
    procedure SetDefaultCaption(const AValue: Boolean);
    //Return the caption associated with the aKind value.
    function GetCaptionOfKind(AKind: TBitBtnKind): String;
    function GetImages: TCustomImageList;
    procedure SetImages(const aImages: TCustomImageList);
    function GetImageIndex: TImageIndex;
    procedure SetImageIndex(const aImageIndex: TImageIndex);
    function GetImageWidth: Integer;
    procedure SetImageWidth(const aImageWidth: Integer);
  protected
    FButtonGlyph: TButtonGlyph;
    class procedure WSRegisterClass; override;
    procedure ActionChange(Sender: TObject; CheckDefaults: Boolean); override;
    procedure GlyphChanged(Sender: TObject);
    procedure InitializeWnd; override;
    function IsCaptionStored: Boolean;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
    procedure TextChanged; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure CMAppShowBtnGlyphChanged(var Message: TLMessage); message CM_APPSHOWBTNGLYPHCHANGED;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Click; override;
    procedure LoadGlyphFromResourceName(Instance: THandle; const AName: String);
    procedure LoadGlyphFromLazarusResource(const AName: String);
    procedure LoadGlyphFromStock(idButton: Integer);
    function CanShowGlyph(const AWithShowMode: Boolean = False): Boolean;
  public
    property Caption stored IsCaptionStored;
    property DefaultCaption: Boolean read FDefaultCaption write SetDefaultCaption default False;
    property Glyph: TBitmap read GetGlyph write SetGlyph stored IsGlyphStored;
    property NumGlyphs: Integer read GetNumGlyphs write SetNumGlyphs default 1;
    property Images: TCustomImageList read GetImages write SetImages;
    property ImageIndex: TImageIndex read GetImageIndex write SetImageIndex default -1;
    property ImageWidth: Integer read GetImageWidth write SetImageWidth default 0;
    property Kind: TBitBtnKind read FKind write SetKind default bkCustom;
    property Layout: TButtonLayout read FLayout write SetLayout default blGlyphLeft;
    property Margin: integer read FMargin write SetMargin default -1;
    property Spacing: Integer read FSpacing write SetSpacing default 4;
    property GlyphShowMode: TGlyphShowMode read GetGlyphShowMode write SetGlyphShowMode default gsmApplication;
  end;

  { TBitBtn }
  { To set custom bitbtn glyphs for the whole application, see below for
    GetDefaultBitBtnGlyph }

  TBitBtn = class(TCustomBitBtn)
  published
    property Action;
    property Align;
    property Anchors;
    property AutoSize;
    property BidiMode;
    property BorderSpacing;
    property Cancel;
    property Caption;
    property Color;
    property Constraints;
    property Default;
    property DefaultCaption;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property Glyph;
    property GlyphShowMode;
    property Kind;
    property Layout;
    property Margin;
    property ModalResult;
    property NumGlyphs;
    property Images;
    property ImageIndex;
    property ImageWidth;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
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
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentBidiMode;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Spacing;
    property TabOrder;
    property TabStop;
    property Visible;
  end;


  { TSpeedButtonActionLink }

  TSpeedButtonActionLink = class(TControlActionLink)
  protected
    procedure AssignClient(AClient: TObject); override;
    procedure SetGroupIndex(Value: Integer); override;
    procedure SetChecked(Value: Boolean); override;
    procedure SetImageIndex(Value: Integer); override;
  public
    function IsCheckedLinked: Boolean; override;
    function IsGroupIndexLinked: Boolean; override;
    function IsImageIndexLinked: Boolean; override;
  end;

  { TCustomSpeedButton }

  TCustomSpeedButton = class(TGraphicControl)
  private
    FGlyph: TButtonGlyph;
    FGroupIndex: Integer;
    FImageChangeLink: TChangeLink;
    FLastDrawDetails: TThemedElementDetails;
    FLayout: TButtonLayout;
    FMargin: integer;
    FSpacing: integer;
    FShortcut: TShortCut;
    FShowAccelChar: boolean;
    FShowCaption: boolean;
    FAllowAllUp: Boolean;
    FDown: Boolean;
    FDownLoaded : Boolean;// value of Down set during loading
    FDragging: Boolean;
    FFlat: Boolean;
    FMouseInControl: Boolean;
    function GetGlyph: TBitmap;
    procedure ImageListChange(Sender: TObject);
    function IsGlyphStored: Boolean;
    procedure SetShowCaption(const AValue: boolean);
    procedure UpdateExclusive;
    function  GetTransparent: Boolean;
    procedure SetAllowAllUp(Value: Boolean);
    procedure SetGlyph(Value: TBitmap);
    procedure SetLayout(const Value: TButtonLayout);
    procedure SetShowAccelChar(Value: boolean);
    procedure SetTransparent(const AValue: boolean);
    procedure CMButtonPressed(var Message: TLMessage); message CM_BUTTONPRESSED;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
  private
    procedure DoMouseUp(var Message: TLMMouse; Button: TMouseButton);
    procedure WMLButtonDown(Var Message: TLMLButtonDown); message LM_LBUTTONDOWN;
    procedure WMLButtonUp(var Message: TLMLButtonUp); message LM_LBUTTONUP;
    procedure WMLButtonDBLCLK(Var Message: TLMLButtonDblClk); message LM_LBUTTONDBLCLK;
    function GetImages: TCustomImageList;
    procedure SetImages(const aImages: TCustomImageList);
    function GetImageIndex: TImageIndex;
    procedure SetImageIndex(const aImageIndex: TImageIndex);
    function GetImageWidth: Integer;
    procedure SetImageWidth(const aImageWidth: Integer);
  protected
    FState: TButtonState;
    class procedure WSRegisterClass; override;
    function ButtonGlyph: TButtonGlyph;
    function GetNumGlyphs: Integer;
    procedure GlyphChanged(Sender: TObject); virtual;
    function  DialogChar(var Message: TLMKey): boolean; override;
    procedure CalculatePreferredSize(var PreferredWidth,
      PreferredHeight: integer; WithThemeSpace: Boolean); override;
    procedure MeasureDraw(Draw: boolean; PaintRect: TRect;
                          out PreferredWidth, PreferredHeight: integer);
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
    procedure Paint; override;
    procedure PaintBackground(var PaintRect: TRect); virtual;
    procedure SetDown(Value: Boolean);
    procedure SetGroupIndex(const Value: Integer);
    procedure SetFlat(const Value: Boolean);
    procedure SetMargin(const Value: integer);
    procedure SetNumGlyphs(Value: integer);
    procedure SetSpacing(const Value: integer);
    procedure RealSetText(const Value: TCaption); override;
    procedure UpdateState(InvalidateOnChange: boolean); virtual;
    function GetDrawDetails: TThemedElementDetails; virtual;
    property MouseInControl: Boolean read FMouseInControl;
    procedure ActionChange(Sender: TObject; CheckDefaults: Boolean); override;
    function GetActionLinkClass: TControlActionLinkClass; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  protected
    function GetGlyphSize(Drawing: boolean; PaintRect: TRect): TSize; virtual;
    function GetTextSize(Drawing: boolean; PaintRect: TRect): TSize; virtual;
    function DrawGlyph(ACanvas: TCanvas; const AClient: TRect; const AOffset: TPoint;
      AState: TButtonState; ATransparent: Boolean; BiDiFlags: Longint): TRect; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function FindDownButton: TCustomSpeedButton;
    procedure Click; override; // make Click public
    procedure LoadGlyphFromResourceName(Instance: THandle; const AName: String);
    procedure LoadGlyphFromLazarusResource(const AName: String);
  public
    property AllowAllUp: Boolean read FAllowAllUp write SetAllowAllUp default false;
    property Color default clBtnFace;
    property Down: Boolean read FDown write SetDown default false;
    property Flat: Boolean read FFlat write SetFlat default false;
    property Glyph: TBitmap read GetGlyph write SetGlyph stored IsGlyphStored;
    property GroupIndex: Integer read FGroupIndex write SetGroupIndex default 0;
    property Images: TCustomImageList read GetImages write SetImages;
    property ImageIndex: TImageIndex read GetImageIndex write SetImageIndex default -1;
    property ImageWidth: Integer read GetImageWidth write SetImageWidth default 0;
    property Layout: TButtonLayout read FLayout write SetLayout default blGlyphLeft;
    property Margin: integer read FMargin write SetMargin default -1;
    property NumGlyphs: Integer read GetNumGlyphs write SetNumGlyphs default 1;
    property ShowAccelChar: boolean read FShowAccelChar write SetShowAccelChar default true;
    property ShowCaption: boolean read FShowCaption write SetShowCaption default true;
    property Spacing: integer read FSpacing write SetSpacing default 4;
    property Transparent: Boolean read GetTransparent write SetTransparent default true;
  end;


  { TSpeedButton }

  TSpeedButton = class(TCustomSpeedButton)
  published
    property Action;
    property Align;
    property AllowAllUp;
    property Anchors;
    property AutoSize;
    property BidiMode;
    property BorderSpacing;
    property Constraints;
    property Caption;
    property Color;
    property Down;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Flat;
    property Font;
    property Glyph;
    property GroupIndex;
    property Images;
    property ImageIndex;
    property ImageWidth;
    property Layout;
    property Margin;
    property NumGlyphs;
    property Spacing;
    property Transparent;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnPaint;
    property OnResize;
    property OnStartDrag;
    property OnChangeBounds;
    property ShowCaption;
    property ShowHint;
    property ParentBidiMode;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
  end;

  { To override the default TBitBtn glyphs set GetDefaultBitBtnGlyph below.
    Example:

    function GetBitBtnGlyph(Kind: TBitBtnKind): TBitmap;
    begin
      if Kind in [bkOK, bkCancel] then begin
        Result:=TBitmap.Create;
        case Kind of
          bkOk:      Result.Assign(MyOkGlyph);
          bkCancel:  Result.Assign(MyCancelGlyph);
        end;
      end else
        Result:=nil;
    end;
    }
type
  TGetDefaultBitBtnGlyph = function(Kind: TBitBtnKind; var Handled: Boolean): TBitmap;
var
  GetDefaultBitBtnGlyph: TGetDefaultBitBtnGlyph = nil;

function GetLCLDefaultBtnGlyph(Kind: TBitBtnKind): TGraphic;
procedure LoadGlyphFromResourceName(AGlyph: TButtonGlyph; Instance: THandle; const AName: String);
procedure LoadGlyphFromLazarusResource(AGlyph: TButtonGlyph; const AName: String);
procedure LoadGlyphFromStock(AGlyph: TButtonGlyph; idButton: Integer);

// helper functions (search LCLType for idButton)
function GetButtonCaption(idButton: Integer): String;
function GetDefaultButtonIcon(idButton: Integer; ScalePercent: Integer = 100): TCustomBitmap;
function GetButtonIcon(idButton: Integer): TCustomBitmap;
function BidiAdjustButtonLayout(IsRightToLeft: Boolean; Layout: TButtonLayout): TButtonLayout;

function dbgs(Kind: TBitBtnKind): string; overload;

procedure Register;

const
  BitBtnModalResults: array[TBitBtnKind] of TModalResult = (
    0, mrOK, mrCancel, 0, mrYes, mrNo,
    mrClose, mrAbort, mrRetry, mrIgnore, mrAll,
    mrNoToAll, mrYesToAll);

  BitBtnImages: array[TBitBtnKind] of Longint = (
    idButtonBase, idButtonOk, idButtonCancel, idButtonHelp, idButtonYes,
    idButtonNo, idButtonClose, idButtonAbort, idButtonRetry, idButtonIgnore,
    idButtonAll, idButtonNoToAll, idButtonYesToAll);

  BitBtnResNames: array[idButtonOk..idButtonNoToAll] of String =
  (
{idButtonOk      } 'btn_ok',
{idButtonCancel  } 'btn_cancel',
{idButtonHelp    } 'btn_help',
{idButtonYes     } 'btn_yes',
{idButtonNo      } 'btn_no',
{idButtonClose   } 'btn_close',
{idButtonAbort   } 'btn_abort',
{idButtonRetry   } 'btn_retry',
{idButtonIgnore  } 'btn_ignore',
{idButtonAll     } 'btn_all',
{idButtonYesToAll} 'btn_all',
{idButtonNoToAll } 'btn_no'
  );

implementation

{$R btn_icons.res}

uses
  WSButtons;

function GetLCLDefaultBtnGlyph(Kind: TBitBtnKind): TGraphic;
begin
  Result := GetDefaultButtonIcon(BitBtnImages[Kind]);
end;

function GetDefaultButtonIcon(idButton: Integer;
  ScalePercent: Integer): TCustomBitmap;
var
  ResName: string;
begin
  Result := nil;
  if (idButton < Low(BitBtnResNames)) or (idButton > High(BitBtnResNames)) then
    Exit;
  if BitBtnResNames[idButton] = '' then
    Exit;
  Result := GetDefaultGlyph(BitBtnResNames[idButton], ScalePercent);
end;

procedure LoadGlyphFromResourceName(AGlyph: TButtonGlyph; Instance: THandle; const AName: String);
var
  C: TCustomBitmap;
begin
  if AName = '' then
    C := nil
  else
    C := CreateBitmapFromResourceName(Instance, AName);

  try
    AGlyph.Glyph.Assign(C);
  finally
    C.Free;
  end;
end;

procedure LoadGlyphFromLazarusResource(AGlyph: TButtonGlyph; const AName: String);
var
  C: TCustomBitmap;
begin
  if AName = '' then
    C := nil
  else
    C := CreateBitmapFromLazarusResource(AName);

  try
    AGlyph.Glyph.Assign(C);
  finally
    C.Free;
  end;
end;

procedure LoadGlyphFromStock(AGlyph: TButtonGlyph; idButton: Integer);
var
  C: TCustomBitmap;
begin
  C := GetButtonIcon(idButton);
  try
    AGlyph.Glyph.Assign(C);
  finally
    C.Free;
  end;
end;

function GetButtonCaption(idButton: Integer): String;
begin
  case idButton of
    idButtonOk       : Result := rsmbOK;
    idButtonCancel   : Result := rsmbCancel;
    idButtonHelp     : Result := rsmbHelp;
    idButtonYes      : Result := rsmbYes;
    idButtonNo       : Result := rsmbNo;
    idButtonClose    : Result := rsmbClose;
    idButtonAbort    : Result := rsmbAbort;
    idButtonRetry    : Result := rsmbRetry;
    idButtonIgnore   : Result := rsmbIgnore;
    idButtonAll      : Result := rsmbAll;
    idButtonYesToAll : Result := rsmbYesToAll;
    idButtonNoToAll  : Result := rsmbNoToAll;
    idButtonOpen     : Result := rsmbOpen;
    idButtonSave     : Result := rsmbSave;
    idButtonShield   : Result := rsmbUnlock;
  else
    Result := '?';
  end;
end;

function GetButtonIcon(idButton: Integer): TCustomBitmap;
var
  BitmapHandle, MaskHandle: HBitmap;
begin
  if ThemeServices.GetStockImage(idButton, BitmapHandle, MaskHandle) then
  begin
    Result := TBitmap.Create;
    Result.Handle := BitmapHandle;
    if MaskHandle <> 0 then
      Result.MaskHandle := MaskHandle;
  end
  else
    Result := GetDefaultButtonIcon(idButton);
end;

const
  BtnBidiLayout: array[Boolean, TButtonLayout] of TButtonLayout =
  (
    (
      blGlyphLeft,
      blGlyphRight,
      blGlyphTop,
      blGlyphBottom
    ),
    (
      blGlyphRight,
      blGlyphLeft,
      blGlyphTop,
      blGlyphBottom
    )
  );

function BidiAdjustButtonLayout(IsRightToLeft: Boolean; Layout: TButtonLayout): TButtonLayout;
begin
  Result := BtnBidiLayout[IsRightToLeft, Layout];
end;

function dbgs(Kind: TBitBtnKind): string;
begin
  Result:='';
  writestr(Result,Kind);
end;

procedure Register;
begin
  RegisterComponents('Additional',[TBitBtn,TSpeedButton]);
end;

{$I bitbtn.inc}
{$I buttonglyph.inc}
{$I speedbutton.inc}

end.
