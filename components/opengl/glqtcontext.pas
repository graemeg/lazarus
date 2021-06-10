{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Author: Mattias Gaertner

}
unit GLQTContext;

{$mode objfpc}{$H+}
{$LinkLib GL}
{$PACKRECORDS C}
{$DEFINE ModernGL}
//{$DEFINE VerboseMultiSampling}
interface

uses
  //  Classes, SysUtils, ctypes, LCLProc, LCLType, X, XUtil, XLib, gl,
  //InterfaceBase,
  //glx,
  //WSLCLClasses,
  {$IFDEF ModernGL} ctypes,{$ENDIF}
  Classes, SysUtils, Types, Controls, LCLProc, LCLType, X, XUtil, XLib, gl,
  InterfaceBase,
  WSLCLClasses,glx,
  // Bindings
  {$IFDEF LCLQt}qt4,{$ENDIF}
  {$IFDEF LCLQt5}qt5, qlclopenglwidget,{$ENDIF}
  qtwidgets, qtobjects, qtproc, qtint,
  QtWSControls;

// gdkgl

const
// enum _QT_GL_CONFIGS
  QT_GL_NONE                           = 0;
  QT_GL_USE_GL                         = 1;
  QT_GL_BUFFER_SIZE                    = 2;
  QT_GL_LEVEL                          = 3;
  QT_GL_RGBA                           = 4;
  QT_GL_DOUBLEBUFFER                   = 5;
  QT_GL_STEREO                         = 6;
  QT_GL_AUX_BUFFERS                    = 7;
  QT_GL_RED_SIZE                       = 8;
  QT_GL_GREEN_SIZE                     = 9;
  QT_GL_BLUE_SIZE                      = 10;
  QT_GL_ALPHA_SIZE                     = 11;
  QT_GL_DEPTH_SIZE                     = 12;
  QT_GL_STENCIL_SIZE                   = 13;
  QT_GL_ACCUM_RED_SIZE                 = 14;
  QT_GL_ACCUM_GREEN_SIZE               = 15;
  QT_GL_ACCUM_BLUE_SIZE                = 16;
  QT_GL_ACCUM_ALPHA_SIZE               = 17;

  // GLX_EXT_visual_info extension
  QT_GL_X_VISUAL_TYPE_EXT              = $22;
  QT_GL_TRANSPARENT_TYPE_EXT           = $23;
  QT_GL_TRANSPARENT_INDEX_VALUE_EXT    = $24;
  QT_GL_TRANSPARENT_RED_VALUE_EXT      = $25;
  QT_GL_TRANSPARENT_GREEN_VALUE_EXT    = $26;
  QT_GL_TRANSPARENT_BLUE_VALUE_EXT     = $27;
  QT_GL_TRANSPARENT_ALPHA_VALUE_EXT    = $28;

type
  TGLXContext = pointer;


procedure LOpenGLViewport(Handle: HWND; Left, Top, Width, Height: integer);
procedure LOpenGLSwapBuffers(Handle: HWND);
function LOpenGLMakeCurrent(Handle: HWND): boolean;
function LOpenGLReleaseContext(Handle: HWND): boolean;
function LOpenGLCreateContext(AWinControl: TWinControl;
                          WSPrivate: TWSPrivateClass; SharedControl: TWinControl;
                          DoubleBuffered, RGBA: boolean;
                          const RedBits, GreenBits, BlueBits, MajorVersion, MinorVersion,
                          MultiSampling, AlphaBits, DepthBits, StencilBits, AUXBuffers: Cardinal;
                          const AParams: TCreateParams): HWND;

procedure LOpenGLDestroyContextInfo(AWinControl: TWinControl);
function CreateOpenGLContextAttrList(DoubleBuffered: boolean; RGBA: boolean;
             const RedBits, GreenBits, BlueBits, AlphaBits, DepthBits,
             StencilBits,  AUXBuffers, MultiSampling: Cardinal): PInteger;


implementation
uses LMessages, Forms;

function XVisualAsString(AVisual: PVisual): string;
begin
  if AVisual=nil then
  begin
    Result:='nil';
  end else
  begin
    Result:=''
        +' bits_per_rgb='+dbgs(AVisual^.bits_per_rgb)
        +' red_mask='+hexstr(AVisual^.red_mask,8)
        +' green_mask='+hexstr(AVisual^.green_mask,8)
        +' blue_mask='+hexstr(AVisual^.blue_mask,8)
        +' map_entries='+dbgs(AVisual^.map_entries)
        +'';
  end;
end;

function XDisplayAsString(ADisplay: PDisplay): string;
begin
  if ADisplay=nil then
  begin
    Result:='nil';
  end else
  begin
    Result:=''
        +'';
  end;
end;

type
  { TQtGLWidget }

  TQtGLWidget = class({$IFDEF LCLQt5}TQtOpenGLWidget{$ELSE}TQtWidget{$ENDIF})
  protected
    function PaintGLControl(Sender: QObjectH; Event: QEventH): boolean; cdecl;
    {$IFDEF LCLQt5}
    procedure paintGL(); cdecl; override;
    {$ENDIF}
  public
    xdisplay: PDisplay;
    visual: PXVisualInfo;
    glxcontext: TGLXContext;
    ref_count: integer;
    function EventFilter(Sender: QObjectH; Event: QEventH): Boolean; cdecl; override;
    function GetGLXDrawable: GLXDrawable;
  end;

{ TQtGLWidget }

function TQtGLWidget.PaintGLControl(Sender: QObjectH; Event: QEventH): boolean;
  cdecl;
var
  Msg: TLMPaint;
  AStruct: PPaintStruct;
  B: Boolean;
begin
  Result := False;
  QEvent_accept(Event);
  if CanSendLCLMessage and (LCLObject is TWinControl) then
  begin
    FillChar(Msg{%H-}, SizeOf(Msg), #0);

    Msg.Msg := LM_PAINT;
    New(AStruct);
    try
      try
        FillChar(AStruct^, SizeOf(TPaintStruct), 0);
        // QWidget_geometry(Widget, @AStruct^.rcPaint);
        QPaintEvent_rect(QPaintEventH(Event), @AStruct^.rcPaint);
        AStruct^.hdc := PtrUInt(Self.glxcontext); // HDC(QOpenGLWidget_context(QOpenGLWidgetH(Sender)));
        Msg.PaintStruct := AStruct;

        Msg.DC := AStruct^.hdc;
        LCLObject.WindowProc(TLMessage(Msg));

        QEvent_ignore(Event);
        Result := True; {let Qt finish}
      finally
        Dispose(AStruct);
      end;
    except
      // prevent recursive repainting !
      B := (Sender <> nil) and QtWidgetSet.IsValidHandle(HWND(Self));
      if B then
        QWidget_setUpdatesEnabled(QWidgetH(Sender), False);
      try
        Application.HandleException(nil);
      finally
        if B and Assigned(Application) and not Application.Terminated then
          QWidget_setUpdatesEnabled(QWidgetH(Sender), True);
      end;
    end;

  end else
  begin
    DebugLn('TQtGLWidget.PaintGLControl error CanSendLCLMessage=',dbgs(CanSendLCLMessage),' LCLObject=',dbgsName(LCLObject));
  end;
end;

{$IFDEF LCLQt5}
procedure TQtGLWidget.paintGL(); cdecl;
var
  AEvent: QPaintEventH;
  ARect: TRect;
begin
  QWidget_rect(Widget, @ARect);
  AEvent := QPaintEvent_Create(PRect(@ARect));
  PaintGLControl(Widget, AEvent);
  QPaintEvent_Destroy(AEvent);
end;
{$ENDIF}


function TQtGLWidget.EventFilter(Sender: QObjectH; Event: QEventH): Boolean;
  cdecl;
begin
  Result := False;
  if QEvent_type(Event) = QEventPaint then
  begin
    {$IFDEF LCLQt}
    PaintGLControl(Sender, Event);
    {$ENDIF}
  end else
    Result := inherited EventFilter(Sender, Event);
end;

function TQtGLWidget.GetGLXDrawable: GLXDrawable;
begin
  result := QWidget_winID(Widget);
end;

procedure LOpenGLViewport(Handle: HWND; Left, Top, Width, Height: integer);
begin
  glViewport(Left,Top,Width,Height);
end;

procedure LOpenGLSwapBuffers(Handle: HWND);
var
  Widget: TQtGLWidget;
begin
  if Handle=0 then
    RaiseGDBException('LOpenGLSwapBuffers Handle=0');

  Widget:=TQtGLWidget(Handle);
  glXSwapBuffers(Widget.xdisplay,
                 Widget.GetGLXDrawable
                 );
end;

function LOpenGLMakeCurrent(Handle: HWND): boolean;
var
  Widget: TQtGLWidget;
begin
  if Handle=0 then
    RaiseGDBException('LOpenGLSwapBuffers Handle=0');
  Result:=false;

  Widget:=TQtGLWidget(Handle);
  Result:=glXMakeCurrent(Widget.xdisplay,
                                 Widget.GetGLXDrawable,
                                 Widget.glxcontext);
end;

function LOpenGLReleaseContext(Handle: HWND): boolean;
var
  Widget: TQtGLWidget;
begin
  Result := false;
  if Handle=0 then
    RaiseGDBException('LOpenGLSwapBuffers Handle=0');

  Widget:=TQtGLWidget(Handle);
  Result := glXMakeCurrent(Widget.xdisplay, 0, nil);
end;

{$IFDEF ModernGL}
function CustomXErrorHandler({%H-}para1:PDisplay; para2:PXErrorEvent):cint;cdecl;
begin
  if para2^.error_code=8 then begin
    raise Exception.Create('A BadMatch X error occurred. Most likely the requested OpenGL version is invalid.');
  end;
  Result:=0;
end;
{$ENDIF}

type
  TContextAttribs = record
    AttributeList: PLongint;
    MajorVersion: Cardinal;
    MinorVersion: Cardinal;
    MultiSampling: Cardinal;
    ContextFlags: Cardinal;
  end;

{function LOpenGLCreateContext(AWinControl: TWinControl;
  WSPrivate: TWSPrivateClass; SharedControl: TWinControl;
  DoubleBuffered, RGBA: boolean;
  const MultiSampling, AlphaBits, DepthBits, StencilBits: Cardinal;
  const AParams: TCreateParams): HWND;}
function LOpenGLCreateContext(AWinControl: TWinControl;
                          WSPrivate: TWSPrivateClass; SharedControl: TWinControl;
                          DoubleBuffered, RGBA: boolean;
                          const RedBits, GreenBits, BlueBits, MajorVersion, MinorVersion,
                          MultiSampling, AlphaBits, DepthBits, StencilBits, AUXBuffers: Cardinal;
                          const AParams: TCreateParams): HWND;
var
  {$IFDEF ModernGL} { Used with glXCreateContextAttribsARB to select 3.X and above context }
  Context3X: array [0..6] of Integer;
  ScreenNum: cint;
  FBConfig: TGLXFBConfig;
  FBConfigs: PGLXFBConfig;
  FBConfigsCount: Integer;
  i: Integer;
  Samples: cint;
  BestSamples: Integer;
  BestFBConfig: Integer;
  XVInfo: PXVisualInfo;
  XDisplay: PDisplay;
  {$ENDIF}
  AttrList: TContextAttribs;
  NewQtWidget: TQtGLWidget;
  direct: boolean;
  {$IFDEF LCLQt5}
  AWinFormat: QSurfaceFormatH;
  {$ENDIF}
  {$IFDEF VerboseMultiSampling}
  samp_buf, visual_id, red_size, blue_size, green_size, alpha_size: integer;
  {$ENDIF}
begin
  if WSPrivate=nil then ;
  AttrList.AttributeList := CreateOpenGLContextAttrList(DoubleBuffered,RGBA,RedBits,GreenBits,BlueBits,AlphaBits,DepthBits,StencilBits,AUXBuffers, MultiSampling);
  try
    NewQtWidget:=TQtGLWidget.Create(AWinControl,AParams);
    {$ifdef LCLQt}
    NewQtWidget.setAttribute(QtWA_PaintOnScreen);
    NewQtWidget.setAttribute(QtWA_NoSystemBackground);
    NewQtWidget.setAttribute(QtWA_OpaquePaintEvent);
    {$endif}
    NewQtWidget.HasPaint := false;
    NewQtWidget.xdisplay := QX11Info_display;
    NewQtWidget.visual := glXChooseVisual(NewQtWidget.xdisplay,
      DefaultScreen(NewQtWidget.xdisplay), @attrList.AttributeList[0]);
    direct := false;
    {$IFDEF LCLQt5}
    QWindow_setSurfaceType(QWidget_windowHandle(NewQtWidget.Widget), QSurfaceSurfaceTypeOpenGLSurface);

    AWinFormat := QSurfaceFormat_Create();

    if MajorVersion > 0 then
    begin
      QSurfaceFormat_setMajorVersion(AWinFormat, MajorVersion);
      QSurfaceFormat_setMinorVersion(AWinFormat, MinorVersion);
    end;

    if DoubleBuffered then
      QSurfaceFormat_setSwapBehavior(AWinFormat, QSurfaceSwapBehaviorDoubleBuffer);
    QSurfaceFormat_setSamples(AWinFormat, Integer(MultiSampling));
    QSurfaceFormat_setDepthBufferSize(AWinFormat, DepthBits);
    QSurfaceFormat_setStencilBufferSize(AWinFormat, Integer(StencilBits));
    QSurfaceFormat_setRenderableType(AWinFormat, QSurfaceFormatRenderableTypeOpenGL);
    QSurfaceFormat_setAlphaBufferSize(AWinFormat, AlphaBits);
    QWindow_destroyPlatformResources(QWidget_windowHandle(NewQtWidget.Widget));
    QWindow_setFormat(QWidget_windowHandle(NewQtWidget.Widget), AWinFormat);
    QWindow_createPlatformResources(QWidget_windowHandle(NewQtWidget.Widget));
    QSurfaceFormat_destroy(AWinFormat);

    NewQtWidget.GetGLXDrawable;

    {$ENDIF}
    {$IFDEF ModernGL}
    if GLX_version_1_3(NewQtWidget.xdisplay) then
    begin
      //use approach recommended since glX 1.3
      direct := true;
      XDisplay := NewQtWidget.xdisplay;
      ScreenNum := DefaultScreen (XDisplay);
      AttrList.MajorVersion:=MajorVersion;
      AttrList.MinorVersion:=MinorVersion;
      // fill in context flags
      AttrList.ContextFlags:=0;
      //if DebugContext then
      // AttrList.ContextFlags:=Attribs.ContextFlags or GLX_CONTEXT_DEBUG_BIT_ARB;
      if (MultiSampling > 1) and GLX_ARB_multisample(XDisplay,ScreenNum) then begin
         AttrList.MultiSampling := MultiSampling;
      end else
      begin
        AttrList.MultiSampling:=0;
        if MultiSampling > 1 then
          {$IFDEF UNIX}writeln('Multi-sampling not supported');{$ENDIF}
      end;
      FBConfigsCount:=0;
      FBConfigs:=glXChooseFBConfig(XDisplay, ScreenNum, @AttrList.AttributeList[0], FBConfigsCount);
      if FBConfigsCount = 0 then begin
         {$IFDEF UNIX}writeln('Could not find FB config: will try without multi-sampling');{$ENDIF}
         FreeMem(AttrList.AttributeList);
         AttrList.AttributeList := CreateOpenGLContextAttrList(DoubleBuffered,RGBA,RedBits,GreenBits,BlueBits,AlphaBits,DepthBits,StencilBits,AUXBuffers, 0);
         AttrList.MajorVersion:=MajorVersion;
         AttrList.MinorVersion:=MinorVersion;
         // fill in context flags
         AttrList.ContextFlags:=0;
         FBConfigs:=glXChooseFBConfig(XDisplay, ScreenNum, @AttrList.AttributeList[0], FBConfigsCount);
      end;
      if FBConfigsCount = 0 then begin
      	raise Exception.Create('Could not find FB config');
        //{$IFDEF UNIX}writeln('Could not find FB config: this may end poorly.');{$ENDIF}
        //NewQtWidget.glxcontext := glXCreateContext(NewQtWidget.xdisplay,NewQtWidget.visual, nil, direct);
        //goto 123;
     end;
        // if multisampling is requested try to get a number of sample buffers as
        // close to the specified number as possible
      if AttrList.MultiSampling > 0 then
      begin
    	  BestSamples:=0;
	      for i := 0 to FBConfigsCount-1 do
        begin
	        Samples:=0;
	        glXGetFBConfigAttrib(NewQtWidget.xdisplay, FBConfigs[i], GLX_SAMPLES_ARB, Samples);
	        if Samples = AttrList.MultiSampling then
          begin
            BestSamples := Samples;
		        BestFBConfig := i;
      		  break;
	        end else
          begin
      		  if (Samples>BestSamples) and (Samples<AttrList.MultiSampling) then
            begin
		          BestSamples := Samples;
		          BestFBConfig := i;
            end;
    		  end;
        end;
          //raise Exception.Create('BestFBConfig '+inttostr(BestFBConfig));
	      FBConfig := FBConfigs[BestFBConfig];
	      {$IFDEF VerboseMultiSampling}
	      //HTTPS://WWW.OPENGL.ORG/DISCUSSION_BOARDS/SHOWTHREAD.PHP/168359-OPENGL-3-X-AND-QT-FRAMEWORK?STYLEID=12
	      GLXGETFBCONFIGATTRIB(XDISPLAY, FBCONFIG, GLX_SAMPLE_BUFFERS, SAMP_BUF);
	      GLXGETFBCONFIGATTRIB(XDISPLAY, FBCONFIG, GLX_SAMPLES, SAMPLES);
	      GLXGETFBCONFIGATTRIB(XDISPLAY, FBCONFIG, GLX_VISUAL_ID, VISUAL_ID);
	      GLXGETFBCONFIGATTRIB(XDISPLAY, FBCONFIG, GLX_RED_SIZE, RED_SIZE);
	      GLXGETFBCONFIGATTRIB(XDISPLAY, FBCONFIG, GLX_BLUE_SIZE, BLUE_SIZE);
	      GLXGETFBCONFIGATTRIB(XDISPLAY, FBCONFIG, GLX_GREEN_SIZE, GREEN_SIZE);
	      GLXGETFBCONFIGATTRIB(XDISPLAY, FBCONFIG, GLX_ALPHA_SIZE, ALPHA_SIZE);
	      DEBUGLN(FORMAT('OPENGL FBCONFIG %D, ID 0X%X, SAMPLE_BUFFERS %D, SAMPLES %D, R%D G%D B%D A%D',
              [BESTFBCONFIG, VISUAL_ID, SAMP_BUF, SAMPLES, RED_SIZE, BLUE_SIZE, GREEN_SIZE, ALPHA_SIZE]));
        {$ENDIF}
      end else
      begin
  	    { just choose the first FB config from the FBConfigs list.
  	        More involved selection possible. }
  	    FBConfig := FBConfigs^;
      end;
      XVInfo:=glXGetVisualFromFBConfig(NewQtWidget.xdisplay, FBConfig);
      if XVInfo=nil then
        raise Exception.Create('QT no visual found');
      if (GLX_ARB_create_context(NewQtWidget.xdisplay, DefaultScreen(NewQtWidget.xdisplay))) then
      begin
		    // install custom X error handler
		    XSetErrorHandler(@CustomXErrorHandler);
		    Context3X[0] := GLX_CONTEXT_MAJOR_VERSION_ARB;
        if AttrList.MajorVersion = 0 then
  		    Context3X[1] := 1
        else
  		    Context3X[1] := AttrList.MajorVersion;
		    Context3X[2] := GLX_CONTEXT_MINOR_VERSION_ARB;
		    Context3X[3] := AttrList.MinorVersion;
		    Context3X[4] := GLX_CONTEXT_FLAGS_ARB;
		    Context3X[5] := AttrList.ContextFlags;
		    Context3X[6] := None;
		    //if (ShareList<>nil) then begin
		    //	NewQtWidget.glxcontext:=glXCreateContextAttribsARB(NewQtWidget.xdisplay, FBConfig,PrivateShareList^.glxcontext, direct, Context3X);
	      //end else begin
		    NewQtWidget.glxcontext := glXCreateContextAttribsARB(NewQtWidget.xdisplay, FBConfig, Nil, direct, Context3X);
		    //end;
        //raise Exception.Create('key '+inttostr(BestFBConfig));
		    // restore default error handler
		    XSetErrorHandler(nil);
      end else
      begin
		    //if (ShareList<>nil) then begin
		    //	NewQtWidget.glxcontext:=glXCreateNewContext(NewQtWidget.xdisplay, FBConfig, GLX_RGBA_TYPE,PrivateShareList^.glxcontext, direct)
		    //end else begin
        NewQtWidget.glxcontext := glXCreateNewContext(NewQtWidget.xdisplay, FBConfig, GLX_RGBA_TYPE, Nil, direct);
		    //end;
	    end;
	    if FBConfigs<>nil then
		    XFree(FBConfigs);

    end else
    {$ENDIF}
      NewQtWidget.glxcontext := glXCreateContext(NewQtWidget.xdisplay,
        NewQtWidget.visual, nil, direct);
    //123:
    NewQtWidget.ref_count := 1;

    NewQtWidget.AttachEvents;

    Result:=HWND(NewQtWidget);
  finally
    FreeMem(AttrList.AttributeList);
  end;
end;

procedure LOpenGLDestroyContextInfo(AWinControl: TWinControl);
begin
  if not AWinControl.HandleAllocated then exit;
  // nothing to do
end;

function CreateOpenGLContextAttrList(DoubleBuffered: boolean; RGBA: boolean;
  const RedBits, GreenBits, BlueBits, AlphaBits, DepthBits, StencilBits,
  AUXBuffers, MultiSampling: Cardinal): PInteger;
var
  p: integer;
  UseFBConfig: boolean;

  procedure Add(i: integer);
  begin
    if Result<>nil then
      Result[p]:=i;
    inc(p);
  end;

  procedure CreateList;
  begin
    p:=0;
    //UseFBConfig := false;
    if UseFBConfig then
    begin
      Add(GLX_X_RENDERABLE); Add(1);
      Add(GLX_X_VISUAL_TYPE);
      Add(GLX_TRUE_COLOR);
    end;
    if DoubleBuffered then
    begin
      if UseFBConfig then
        begin Add(GLX_DOUBLEBUFFER); Add(1); end else
        Add(GLX_DOUBLEBUFFER);
    end;
    if RGBA then
    begin
      if not UseFBConfig then Add(GLX_RGBA);
      { For UseFBConfig, glXChooseFBConfig already defaults to RGBA }
    end;
    Add(GLX_RED_SIZE);  Add(RedBits);
    Add(GLX_GREEN_SIZE);  Add(GreenBits);
    Add(GLX_BLUE_SIZE);  Add(BlueBits);
    if AlphaBits>0 then
    begin
      Add(GLX_ALPHA_SIZE);  Add(AlphaBits);
    end;
    if DepthBits>0 then
    begin
      Add(GLX_DEPTH_SIZE);  Add(DepthBits);
    end;
    if StencilBits>0 then
    begin
      Add(GLX_STENCIL_SIZE);  Add(StencilBits);
    end;
    if AUXBuffers>0 then
    begin
      Add(GLX_AUX_BUFFERS);  Add(AUXBuffers);
    end;
    {$IFDEF ModernGL}
	  if MultiSampling>1 then
    begin
      Add(GLX_SAMPLE_BUFFERS);  Add(1);
      Add(GLX_SAMPLES);  Add(MultiSampling);
	  end;
    {$ENDIF}
    Add(0); { 0 = X.None (be careful: GLX_NONE is something different) }
  end;

begin
  {$IFDEF VerboseMultiSampling}
  debugln(['CreateOpenGLContextAttrList MultiSampling=',MultiSampling]);
  {$ENDIF}
   {$IFDEF ModernGL}
  UseFBConfig := GLX_version_1_3(QX11Info_display());
  {$ELSE}
  UseFBConfig := false;
  {$ENDIF}
  Result:=nil;
  CreateList;
  GetMem(Result,SizeOf(integer)*p);
  CreateList;
end;


end.


