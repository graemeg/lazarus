{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Author: Mattias Gaertner

}
unit GLGtkGlxContext;

{$mode objfpc}{$H+}
{$LinkLib GL}
{$PACKRECORDS C}

interface

uses
  Classes, SysUtils, ctypes, LCLProc, LCLType, X, XUtil, XLib, gl,
  InterfaceBase,
  glx,
  WSLCLClasses,
  {$IFDEF LCLGTK2}
  LMessages, Gtk2Def, gdk2x, glib2, gdk2, gtk2, Gtk2Int,
  {$ENDIF}
  {$IFDEF LCLGTK}
  glib, gdk, gtk, GtkInt,
  {$ENDIF}
  Controls;

type
  TGLBool = longbool;
const
  GLXTrue:longbool = true;
  GLXFalse:longbool = false;

type
  TGdkGLContext = record end;
  PGdkGLContext = ^TGdkGLContext;

// GLX_EXT_visual_info extension

function gdk_gl_query: boolean;
function gdk_gl_choose_visual(attrlist: Plongint): PGdkVisual;
function gdk_gl_get_config(visual: PGdkVisual; attrib: longint): longint;
function gdk_gl_context_new(visual: PGdkVisual; attrlist: PlongInt): PGdkGLContext;
function gdk_gl_context_share_new(visual: PGdkVisual; sharelist: PGdkGLContext;
                                  direct: TGLBool; attrlist: plongint): PGdkGLContext;
function gdk_gl_context_attrlist_share_new(attrlist: Plongint;
               sharelist: PGdkGLContext; direct: TGLBool): PGdkGLContext;
function gdk_gl_context_ref(context: PGdkGLContext): PGdkGLContext;
function gdk_gl_context_unref(context:PGdkGLContext): PGdkGLContext;
function gdk_gl_make_current(drawable: PGdkDrawable;
                             context: PGdkGLContext): boolean;
procedure gdk_gl_swap_buffers(drawable: PGdkDrawable);
procedure gdk_gl_wait_gdk;
procedure gdk_gl_wait_gl;

{ glpixmap stuff  }

type
  TGdkGLPixmap = record end;
  PGdkGLPixmap = ^TGdkGLPixmap;
  TGLXContext = pointer;


// gtkglarea

type
  TGtkGlAreaMakeCurrentType = boolean;

  PGtkGLArea = ^TGtkGLArea;
  TGtkGLArea = record
    darea: TGtkDrawingArea;
    glcontext: PGdkGLContext;
  end;

  PGtkGLAreaClass = ^TGtkGLAreaClass;
  TGtkGLAreaClass = record
    parent_class: TGtkDrawingAreaClass;
  end;

  TContextAttribs = record
    AttributeList: PLongint;
    MajorVersion: Cardinal;
    MinorVersion: Cardinal;
    MultiSampling: Cardinal;
    ContextFlags: Cardinal;
  end;

function GTK_TYPE_GL_AREA: TGtkType;
function GTK_GL_AREA(obj: Pointer): PGtkGLArea;
function GTK_GL_AREA_CLASS(klass: Pointer): PGtkGLAreaClass;
function GTK_IS_GL_AREA(obj: Pointer): Boolean;
function GTK_IS_GL_AREA_CLASS(klass: Pointer): Boolean;

function gtk_gl_area_get_type: TGtkType;
function gtk_gl_area_new(Attribs: TContextAttribs): PGtkWidget;
function gtk_gl_area_share_new(Attribs: TContextAttribs; share: PGtkGLArea): PGtkWidget;
function gtk_gl_area_share_new_usefpglx(Attribs: TContextAttribs; share: PGtkGLArea): PGtkGLArea;
function gtk_gl_area_make_current(glarea: PGtkGLArea): boolean;
function gtk_gl_area_begingl(glarea: PGtkGLArea): boolean;
procedure gtk_gl_area_swap_buffers(gl_area: PGtkGLArea);

{$IFDEF lclgtk}
function gdk_x11_get_default_xdisplay:PDisplay;cdecl;external;
function gdk_x11_get_default_screen:gint;cdecl;external;
{$ENDIF}

procedure LOpenGLViewport({%H-}Handle: HWND; Left, Top, Width, Height: integer);
procedure LOpenGLSwapBuffers(Handle: HWND);
function LOpenGLMakeCurrent(Handle: HWND): boolean;
function LOpenGLReleaseContext({%H-}Handle: HWND): boolean;
function LOpenGLCreateContext(AWinControl: TWinControl;
             WSPrivate: TWSPrivateClass; SharedControl: TWinControl;
             DoubleBuffered, RGBA, DebugContext: boolean;
             const RedBits, GreenBits, BlueBits, MajorVersion, MinorVersion,
             MultiSampling, AlphaBits, DepthBits, StencilBits, AUXBuffers: Cardinal;
             const AParams: TCreateParams): HWND;
procedure LOpenGLDestroyContextInfo(AWinControl: TWinControl);

{ Create GLX attributes list suitable for glXChooseVisual or glXChooseFBConfig. }
function CreateOpenGLContextAttrList(DoubleBuffered: boolean;
  RGBA: boolean;
  const RedBits, GreenBits, BlueBits,
  AlphaBits, DepthBits, StencilBits, AUXBuffers: Cardinal): PInteger;

implementation


var
  gl_area_type: TGtkType = 0;
  parent_class: Pointer = nil;

type
  TGdkGLContextPrivate = record
    xdisplay: PDisplay;
    glxcontext: TGLXContext;
    ref_count: gint;
  end;
  PGdkGLContextPrivate = ^TGdkGLContextPrivate;

type
  //PGLXPixmap = ^GLXPixmap;
  GLXPixmap = {%H-}TXID;

  //PGLXDrawable = ^GLXDrawable;
  GLXDrawable = {%H-}TXID;

procedure g_return_if_fail(b: boolean; const Msg: string);
begin
  if not b then raise Exception.Create(Msg);
end;

procedure g_return_if_fail(b: boolean);
begin
  g_return_if_fail(b,'');
end;

function DefaultScreen(ADisplay: PDisplay): longint;
begin
  Result:=XDefaultScreen(ADisplay);
end;

function g_new(BaseSize, Count: integer): Pointer;
begin
  Result:=g_malloc(BaseSize*Count);
end;

function GetDefaultXDisplay: PDisplay;
begin
  Result:=GDK_DISPLAY;
end;

{$IFDEF LCLGtk2}
function GdkVisualAsString(Visual: PGdkVisual): string;
begin
  if Visual=nil then begin
    Result:='nil';
  end else begin
    with Visual^ do begin
      Result:=''
        //parent_instance : TGObject;
        +' TheType='+dbgs(ord(TheType))
        +' depth='+dbgs(depth)
        +' byte_order='+dbgs(ord(byte_order))
        +' colormap_size='+dbgs(colormap_size)
        +' bits_per_rgb='+dbgs(bits_per_rgb)
        +' red_mask='+hexstr(red_mask,8)
        +' red_shift='+dbgs(red_shift)
        +' red_prec='+dbgs(red_prec)
        +' green_mask='+hexstr(green_mask,8)
        +' green_shift='+dbgs(green_shift)
        +' green_prec='+dbgs(green_prec)
        +' blue_mask='+hexstr(blue_mask,8)
        +' blue_shift='+dbgs(blue_shift)
        +' blue_prec='+dbgs(blue_prec)
        //screen : PGdkScreen;
        +'';
    end;
  end;
end;

function XVisualAsString(AVisual: PVisual): string;
begin
  if AVisual=nil then begin
    Result:='nil';
  end else begin
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
  if ADisplay=nil then begin
    Result:='nil';
  end else begin
    Result:=''
        +'';
  end;
end;
{$ENDIF}

function get_xvisualinfo(visual: PGdkVisual): PXVisualInfo;
// IMPORTANT: remember to XFree returned XVisualInfo !!!
var
  vinfo_template: TXVisualInfo;
  dpy: PDisplay;
  nitems_return: integer;
  vi: PXVisualInfo;
begin
  dpy := GetDefaultXDisplay;
  {$IFDEF Lclgtk2}
  DebugLn('get_xvisualinfo dpy=',XDisplayAsString(dpy));
  DebugLn('get_xvisualinfo visual=',GdkVisualAsString(Visual));
  RaiseGDBException('not implemented for gtk2');
  {$ENDIF}

  // 'GLX uses VisualInfo records because they uniquely identify
  // a (VisualID,screen,depth) tuple.'
  vinfo_template.bits_per_rgb:=0;
  FillChar(vinfo_template,SizeOf(vinfo_template),0);
  vinfo_template.visual   := GDK_VISUAL_XVISUAL({$IFDEF LCLGTK}
                                                PGdkVisualPrivate(visual)
                                                {$ELSE}
                                                visual
                                                {$ENDIF});
  vinfo_template.visualid := XVisualIDFromVisual(vinfo_template.visual);
  vinfo_template.depth    := PGdkVisualPrivate(visual)^.visual.depth;
  vinfo_template.screen   := DefaultScreen(GetDefaultXDisplay);
  {$IFDEF LCLGTK2}
  DebugLn('get_xvisualinfo vinfo_template.visual=',dbgs(vinfo_template.visual));
  DebugLn('get_xvisualinfo vinfo_template.visual: ',XVisualAsString(vinfo_template.visual));
  DebugLn('get_xvisualinfo vinfo_template.visualid=',dbgs(vinfo_template.visualid));
  DebugLn('get_xvisualinfo vinfo_template.depth=',dbgs(vinfo_template.depth),' GetDefaultXDisplay=',dbgs(GetDefaultXDisplay));
  DebugLn('get_xvisualinfo vinfo_template.screen=',dbgs(vinfo_template.screen));
  {$ENDIF}
  vi := XGetVisualInfo(dpy, VisualIDMask or VisualDepthMask or VisualScreenMask,
                       @vinfo_template, @nitems_return);
  DebugLn('get_xvisualinfo nitems_return=',dbgs(nitems_return));
  // visualinfo needs to be unique
  if (vi=nil) then raise Exception.Create('get_xvisualinfo vi=nil');
  if (nitems_return<>1) then raise Exception.Create('get_xvisualinfo nitems_return='+dbgs(nitems_return));

  Result:=vi;
end;

procedure gtk_gl_area_destroy(obj: PGtkObject); cdecl;
var
  gl_area: PGtkGLArea;
begin
  g_return_if_fail (obj <>nil,'');
  g_return_if_fail (GTK_IS_GL_AREA(obj),'');

  gl_area := GTK_GL_AREA(obj);
  if gl_area^.glcontext <> nil then // avoid double-free
    gl_area^.glcontext := gdk_gl_context_unref(gl_area^.glcontext);

  if Assigned(GTK_OBJECT_CLASS(parent_class)^.destroy) then
    GTK_OBJECT_CLASS(parent_class)^.destroy(obj);
end;

procedure gtk_gl_area_class_init(klass: Pointer); cdecl;
var
  object_class: PGtkObjectClass;
begin
  parent_class := gtk_type_class(gtk_drawing_area_get_type());
  g_return_if_fail(parent_class<>nil,'gtk_gl_area_class_init parent_class=nil');
  object_class := PGtkObjectClass(klass);
  g_return_if_fail(object_class<>nil,'gtk_gl_area_class_init object_class=nil');

  object_class^.destroy := @gtk_gl_area_destroy;
end;

function gdk_gl_query: boolean;
var
  errorb: Integer = 0;
  event: Integer = 0;
begin
  Result:=boolean(glXQueryExtension(GetDefaultXDisplay, errorb, event));
end;

function gdk_gl_choose_visual(attrlist: Plongint): PGdkVisual;
var
  dpy: PDisplay;
  vi: PXVisualInfo;
  visual: PGdkVisual;
begin
  {$IFDEF lclgtk2}
  DebugLn(['gdk_gl_choose_visual not implemented yet for gtk2']);
  RaiseGDBException('');
  {$ENDIF}

  if attrList=nil then begin
    Result:=nil;
    exit;
  end;

  dpy := GetDefaultXDisplay;
  vi := glXChooseVisual(dpy,DefaultScreen(dpy), attrlist);
  if (vi=nil) then begin
    Result:=nil;
    exit;
  end;

  visual := gdkx_visual_get(vi^.visualid);
  XFree(vi);
  Result:=visual;
end;

function gdk_gl_get_config(visual: PGdkVisual; attrib: longint): longint;
var
  dpy: PDisplay;
  vi: PXVisualInfo;
  value: integer;
begin
  Result:=-1;
  if visual=nil then exit;

  dpy := GetDefaultXDisplay;

  vi := get_xvisualinfo(visual);

  value:=0;
  if (glXGetConfig(dpy, vi, attrib, value) = 0) then begin
    XFree(vi);
    Result:=value;
  end else
    XFree(vi);
end;

function gdk_gl_context_new(visual: PGdkVisual; attrlist: PlongInt): PGdkGLContext;
begin
  Result := gdk_gl_context_share_new(visual, nil, GLXTrue, attrlist);
end;

function gdk_gl_context_share_new(visual: PGdkVisual; sharelist: PGdkGLContext;
  direct: TGLBool; attrlist: plongint): PGdkGLContext;
var
  dpy: PDisplay;
  vi: PXVisualInfo;
  PrivateShareList: PGdkGLContextPrivate;
  PrivateContext: PGdkGLContextPrivate;
  glxcontext: TGLXContext;

begin
  Result:=nil;
  dpy := GetDefaultXDisplay;

  {$IFDEF lclgtk2}
    if visual=nil then ;
    vi:=glXChooseVisual(dpy, DefaultScreen(dpy), @attrList[0]);
  {$ELSE}
    if visual=nil then exit;
    vi := get_xvisualinfo(visual);
  {$ENDIF}
  if vi=nil then
    raise Exception.Create('gdk_gl_context_share_new no visual found');

  PrivateShareList:=PGdkGLContextPrivate(sharelist);

  if (sharelist<>nil) then
    glxcontext := glXCreateContext(dpy, vi, PrivateShareList^.glxcontext,
                                   direct)
  else
    glxcontext := glXCreateContext(dpy, vi, nil, direct);

  XFree(vi);
  if (glxcontext = nil) then exit;

  PrivateContext := g_new(SizeOf(TGdkGLContextPrivate), 1);
  PrivateContext^.xdisplay := dpy;
  PrivateContext^.glxcontext := glxcontext;
  PrivateContext^.ref_count := 1;

  Result := PGdkGLContext(PrivateContext);
end;

function gdk_gl_context_attrlist_share_new(attrlist: Plongint;
  sharelist: PGdkGLContext; direct: TGLBool): PGdkGLContext;
var
  visual: PGdkVisual;
begin
  {$IFDEF lclgtk2}
  visual :=nil;
  Result := gdk_gl_context_share_new(visual, sharelist, direct, attrlist);
  {$ELSE}
  visual := gdk_gl_choose_visual(attrlist);
  if (visual <> nil) then
    Result := gdk_gl_context_share_new(visual, sharelist, direct, attrlist)
  else
    Result := nil;
  {$ENDIF}
end;

function gdk_gl_context_ref(context: PGdkGLContext): PGdkGLContext;
var
  PrivateContext: PGdkGLContextPrivate;
begin
  Result:=nil;
  if context=nil then exit;
  PrivateContext := PGdkGLContextPrivate(context);
  inc(PrivateContext^.ref_count);
  //DebugLn(['gdk_gl_context_ref ref_count=',PrivateContext^.ref_count]);
  Result:=context;
end;

function gdk_gl_context_unref(context: PGdkGLContext):PGdkGLContext;
var
  PrivateContext: PGdkGLContextPrivate;
begin
  Result:=context;
  g_return_if_fail(context<>nil,'');

  PrivateContext:=PGdkGLContextPrivate(context);

  dec(PrivateContext^.ref_count);
  if (PrivateContext^.ref_count = 0) then begin
    //DebugLn(['gdk_gl_context_unref START ref_count=',PrivateContext^.ref_count]);
    if (PrivateContext^.glxcontext = glXGetCurrentContext()) then
      glXMakeCurrent(PrivateContext^.xdisplay, None, nil);
    glXDestroyContext(PrivateContext^.xdisplay, PrivateContext^.glxcontext);
    PrivateContext^.glxcontext:=nil;
    g_free(PrivateContext);
    //DebugLn(['gdk_gl_context_unref END']);
    Result:=nil;
  end;
end;

function gdk_gl_make_current(drawable: PGdkDrawable;
  context: PGdkGLContext): boolean;
var
  PrivateContext: PGdkGLContextPrivate;
begin
  Result:=false;
  if  drawable=nil then exit;
  if context=nil then exit;
  PrivateContext := PGdkGLContextPrivate(context);

  Result:=boolean(glXMakeCurrent(PrivateContext^.xdisplay,
                                 {$IFDEF LCLGTK}
                                 GDK_WINDOW_XWINDOW(PGdkWindowPrivate(drawable)),
                                 {$ELSE}
                                 GDK_WINDOW_XWINDOW(drawable),
                                 {$ENDIF}
                                 PrivateContext^.glxcontext)
                                 );
end;

procedure gdk_gl_swap_buffers(drawable: PGdkDrawable);
begin
  g_return_if_fail(drawable <> nil);

  glXSwapBuffers({$IFDEF LCLGTK}
                 GDK_WINDOW_XDISPLAY(PGdkWindowPrivate(drawable)),
                 GDK_WINDOW_XWINDOW(PGdkWindowPrivate(drawable))
                 {$ELSE}
                 GDK_WINDOW_XDISPLAY(drawable),
                 GDK_WINDOW_XWINDOW(drawable)
                 {$ENDIF}
                 );
end;

procedure gdk_gl_wait_gdk;
begin
  glXWaitX;
end;

procedure gdk_gl_wait_gl;
begin
  glXWaitGL;
end;

procedure gtk_gl_area_init(
  {$IFDEF LCLGTK}
  gl_area, theClass: Pointer
  {$ELSE}
  gl_area: PGTypeInstance; theClass: gpointer
  {$ENDIF}
  ); cdecl;
begin
  if theClass=nil then ;
  //DebugLn(['gtk_gl_area_init START']);
  PGtkGLArea(gl_area)^.glcontext:=nil;
  {$IFDEF LclGtk2}
  gtk_widget_set_double_buffered(PGtkWidget(gl_area),gdkFALSE);
  GTK_WIDGET_UNSET_FLAGS(PGtkWidget(gl_area),GTK_NO_WINDOW);
  {$ENDIF}
  //DebugLn(['gtk_gl_area_init END']);
end;

function GTK_TYPE_GL_AREA: TGtkType;
const
  gl_area_type_name = 'GtkGLArea';
  gl_area_info: TGtkTypeInfo = (
    type_name: gl_area_type_name;
    object_size: SizeOf(TGtkGLArea);
    class_size:  SizeOf(TGtkGLAreaClass);
    class_init_func:  @gtk_gl_area_class_init;
    object_init_func: @gtk_gl_area_init;
    reserved_1: nil;
    reserved_2: nil;
    base_class_init_func: nil;
  );
begin
  if (gl_area_type=0) then begin
    gl_area_type:=gtk_type_unique(gtk_drawing_area_get_type(),@gl_area_info);
  end;
  Result:=gl_area_type;
end;

function GTK_GL_AREA(obj: Pointer): PGtkGLArea;
begin
  g_return_if_fail(GTK_IS_GL_AREA(obj),'');
  Result:=PGtkGLArea(obj);
end;

function GTK_GL_AREA_CLASS(klass: Pointer): PGtkGLAreaClass;
begin
  g_return_if_fail(GTK_IS_GL_AREA_CLASS(klass),'');
  Result:=PGtkGLAreaClass(klass);
end;

function GTK_IS_GL_AREA(obj: Pointer): Boolean;
begin
  {$IFDEF LCLGTK}
  Result := Assigned(obj) and GTK_IS_GL_AREA_CLASS(PGtkTypeObject(obj)^.klass);
  {$ELSE}
  GTK_IS_GL_AREA:=GTK_CHECK_TYPE(obj,GTK_TYPE_GL_AREA);
  {$ENDIF}
end;

function GTK_IS_GL_AREA_CLASS(klass: Pointer): Boolean;
begin
  {$IFDEF LCLGTK}
  Result := Assigned(klass) and (PGtkTypeClass(klass)^.thetype = GTK_TYPE_GL_AREA);
  {$ELSE}
  GTK_IS_GL_AREA_CLASS:=GTK_CHECK_CLASS_TYPE(klass,GTK_TYPE_GL_AREA);
  {$ENDIF}
end;

function gtk_gl_area_get_type: TGtkType;
begin
  Result:=GTK_TYPE_GL_AREA;
end;

function gtk_gl_area_new(Attribs: TContextAttribs): PGtkWidget;
begin
  Result:=gtk_gl_area_share_new(Attribs, nil);
end;

{$IFDEF VerboseMultiSampling}
procedure WriteFBConfigID(const Prefix: string; PrivateContext: PGdkGLContextPrivate);
var
  ctxValue: longint;
begin
  ctxValue:=0;
  debugln([Prefix,' ContextAttrib: ',
    glXQueryContext(PrivateContext^.xdisplay, PrivateContext^.glxcontext, GLX_FBCONFIG_ID, ctxValue),
    '-',ctxValue]);
end;
{$ENDIF}

function gtk_gl_area_share_new(Attribs: TContextAttribs; share: PGtkGLArea): PGtkWidget;
var
  gl_area: PGtkGLArea;
begin
  Result := nil;
  //DebugLn(['gtk_gl_area_share_new START']);
  if (share <> nil) and (not GTK_IS_GL_AREA(share)) then
    exit;
  gl_area:=gtk_gl_area_share_new_usefpglx(Attribs, share);
  Result:=PGtkWidget(gl_area);
end;

function CustomXErrorHandler({%H-}para1:PDisplay; para2:PXErrorEvent):cint;cdecl;
begin
  if para2^.error_code=8 then begin
    raise Exception.Create('A BadMatch X error occurred. Most likely the requested OpenGL version is invalid.');
  end;
  Result:=0;
end;

function gtk_gl_area_share_new_usefpglx(Attribs: TContextAttribs; share: PGtkGLArea): PGtkGLArea;
var
  GLArea: PGtkGLArea;
  ShareList: PGdkGLContext;
  PrivateShareList: PGdkGLContextPrivate;
  ColorMap: PGdkColormap;
  Visual: PGdkVisual;
  PrivateContext: PGdkGLContextPrivate;
  XDisplay: PDisplay;
  XVInfo: PXVisualInfo;
  ScreenNum: gint;
  FBConfig: TGLXFBConfig;
  FBConfigs: PGLXFBConfig;
  FBConfigsCount: Integer;
  Samples: cint;
  BestSamples: Integer;
  BestFBConfig: Integer;
  GLXContext: TGLXContext;
  i: Integer;
  { Used with glXCreateContextAttribsARB to select 3.X and above context }
  Context3X: array [0..6] of Integer;

begin
  Result:=nil;
  ShareList:=nil;
  if share<>nil then ShareList:=share^.glcontext;
  PrivateShareList:=PGdkGLContextPrivate(ShareList);
  XDisplay:=gdk_x11_get_default_xdisplay;
  ScreenNum:=gdk_x11_get_default_screen;
  if GLX_version_1_3(XDisplay) then begin
    { use approach recommended since glX 1.3 }
    FBConfigsCount:=0;
    FBConfigs:=glXChooseFBConfig(XDisplay, ScreenNum, @Attribs.AttributeList[0], FBConfigsCount);
    if FBConfigsCount = 0 then
      raise Exception.Create('Could not find FB config');

    // if multisampling is requested try to get a number of sample buffers as
    // close to the specified number as possible
    if Attribs.MultiSampling>0 then begin
      BestSamples:=0;
      for i:=0 to FBConfigsCount-1 do begin
        Samples:=0;
        glXGetFBConfigAttrib(XDisplay, FBConfigs[i], GLX_SAMPLES_ARB, Samples);
        if Samples=Attribs.MultiSampling then begin
          BestFBConfig:=i;
          break;
        end else begin
          if (Samples>BestSamples) and (Samples<Attribs.MultiSampling) then begin
            BestSamples:=Samples;
            BestFBConfig:=i;
          end;
        end;
      end;
      FBConfig := FBConfigs[BestFBConfig];
    end else begin
      { just choose the first FB config from the FBConfigs list.
        More involved selection possible. }
      FBConfig := FBConfigs^;
    end;
    XVInfo:=glXGetVisualFromFBConfig(XDisplay, FBConfig);
  end else begin
    XVInfo:=glXChooseVisual(XDisplay, ScreenNum, @Attribs.AttributeList[0]);
  end;

  if XVInfo=nil then
    raise Exception.Create('gdk_gl_context_share_new_usefpglx no visual found');

  if GLX_version_1_3(XDisplay) then begin
    if (GLX_ARB_create_context(XDisplay, DefaultScreen(XDisplay))) and
       (Attribs.MajorVersion>0) then begin
      // install custom X error handler
      XSetErrorHandler(@CustomXErrorHandler);
      Context3X[0]:=GLX_CONTEXT_MAJOR_VERSION_ARB;
      Context3X[1]:=Attribs.MajorVersion;
      Context3X[2]:=GLX_CONTEXT_MINOR_VERSION_ARB;
      Context3X[3]:=Attribs.MinorVersion;
      Context3X[4]:=GLX_CONTEXT_FLAGS_ARB;
      Context3X[5]:=Attribs.ContextFlags;
      Context3X[6]:=None;
      if (ShareList<>nil) then begin
        GLXContext:=glXCreateContextAttribsARB(XDisplay, FBConfig,
                                              PrivateShareList^.glxcontext, true,
                                               Context3X);
      end else begin
        GLXContext:=glXCreateContextAttribsARB(XDisplay, FBConfig, Nil, true,
                                               Context3X);
      end;
      // restore default error handler
      XSetErrorHandler(nil);
    end else begin
      if (ShareList<>nil) then begin
        GLXContext:=glXCreateNewContext(XDisplay, FBConfig, GLX_RGBA_TYPE,
                                        PrivateShareList^.glxcontext, True)
      end else begin
        GLXContext:=glXCreateNewContext(XDisplay, FBConfig, GLX_RGBA_TYPE, Nil,
                                        True);
      end;
    end;
    if FBConfigs<>nil then
      XFree(FBConfigs);
  end else begin
    if (ShareList<>nil) then
      GLXContext:=glXCreateContext(XDisplay, XVInfo, PrivateShareList^.glxcontext,
                                   GLXTrue)
    else
      GLXContext:=glXCreateContext(XDisplay, XVInfo, Nil, GLXTrue);
  end;

  if GLXContext=nil then
    raise Exception.Create('gdk_gl_context_share_new_usefpglx context creation failed');

  ColorMap:=gdk_colormap_get_system;
  Visual:=gdk_colormap_get_visual(ColorMap);
  if XVisualIDFromVisual(
    GDK_VISUAL_XVISUAL({$IFDEF LCLGTK}PGdkVisualPrivate(visual)
                       {$ELSE}visual
                       {$ENDIF}))
    <>XVInfo^.visualid
  then begin
    Visual:=gdkx_visual_get(XVInfo^.visualid);
    ColorMap:=gdk_colormap_new(Visual, {$IFDEF LCLGTK2}gFALSE{$ELSE}0{$ENDIF});
  end;

  GLArea:=gtk_type_new(gtk_gl_area_get_type);
  gtk_widget_set_colormap(PGtkWidget(@GLArea^.darea), ColorMap);

  PrivateContext:=g_new(SizeOf(TGdkGLContextPrivate), 1);
  PrivateContext^.xdisplay:=XDisplay;
  PrivateContext^.glxcontext:=GLXContext;
  PrivateContext^.ref_count:=1;

  GLArea^.glcontext:=PGdkGLContext(PrivateContext);
  Result:=GLArea;
end;

function gtk_gl_area_make_current(glarea: PGtkGLArea): boolean;
begin
  Result:=false;
  if glarea=nil then exit;
  if not GTK_IS_GL_AREA(glarea) then exit;
  if not GTK_WIDGET_REALIZED(PGtkWidget(glarea)) then exit;

  //DebugLn(['gtk_gl_area_make_current START']);
  Result:=gdk_gl_make_current(PGtkWidget(glarea)^.window, glarea^.glcontext);
  //DebugLn(['gtk_gl_area_make_current END']);
  {$IFDEF VerboseMultiSampling}
  //WriteFBConfigID('gtk_gl_area_make_current',PGdkGLContextPrivate(glarea^.glcontext));
  {$ENDIF}
end;

function gtk_gl_area_begingl(glarea: PGtkGLArea): boolean;
begin
  Result:=gtk_gl_area_make_current(glarea);
end;

procedure gtk_gl_area_swap_buffers(gl_area: PGtkGLArea);
begin
  g_return_if_fail(gl_area <> nil);
  g_return_if_fail(GTK_IS_GL_AREA(gl_area));
  g_return_if_fail(GTK_WIDGET_REALIZED(PGtkWidget(gl_area)));

  gdk_gl_swap_buffers(GTK_WIDGET(gl_area)^.window);
end;

procedure LOpenGLViewport(Handle: HWND; Left, Top, Width, Height: integer);
begin
  glViewport(Left,Top,Width,Height);
end;

procedure LOpenGLSwapBuffers(Handle: HWND);
begin
  gtk_gl_area_swap_buffers({%H-}PGtkGLArea(Handle));
end;

function LOpenGLMakeCurrent(Handle: HWND): boolean;
var
  Widget: PGtkWidget;
  glarea: PGtkGLArea;
begin
  if Handle=0 then
    RaiseGDBException('LOpenGLSwapBuffers Handle=0');
  Result:=false;

  Widget:={%H-}PGtkWidget(PtrUInt(Handle));
  glarea:=PGtkGLArea(Widget);
  if not GTK_IS_GL_AREA(glarea) then
    RaiseGDBException('LOpenGLSwapBuffers not a PGtkGLArea');

  // make sure the widget is realized
  gtk_widget_realize(Widget);
  if not GTK_WIDGET_REALIZED(Widget) then exit;

  // make current
  Result:=gtk_gl_area_make_current(glarea);
end;

function LOpenGLReleaseContext(Handle: HWND): boolean;
var pd:PDIsplay;
begin
  Result := false;
  pd := glXGetCurrentDisplay();
  if Assigned(pd) then
  Result := glXMakeCurrent(pd, 0, nil);
end;

{$IFDEF LCLGtk2}
function gtkglarea_size_allocateCB(Widget: PGtkWidget; Size: pGtkAllocation;
  Data: gPointer): GBoolean; cdecl;
const
  CallBackDefaultReturn = {$IFDEF GTK2}false{$ELSE}true{$ENDIF};
var
  SizeMsg: TLMSize;
  GtkWidth, GtkHeight: integer;
  LCLControl: TWinControl;
begin
  Result := CallBackDefaultReturn;
  if not GTK_WIDGET_REALIZED(Widget) then begin
    // the widget is not yet realized, so this GTK resize was not a user change.
    // => ignore
    exit;
  end;
  if Size=nil then ;
  LCLControl:=TWinControl(Data);
  if LCLControl=nil then exit;
  //DebugLn(['gtkglarea_size_allocateCB ',DbgSName(LCLControl)]);

  gtk_widget_get_size_request(Widget, @GtkWidth, @GtkHeight);

  SizeMsg.Msg:=0;
  FillChar(SizeMsg,SizeOf(SizeMsg),0);
  with SizeMsg do
  begin
    Result := 0;
    Msg := LM_SIZE;
    SizeType := Size_SourceIsInterface;
    Width := SmallInt(GtkWidth);
    Height := SmallInt(GtkHeight);
  end;
  //DebugLn(['gtkglarea_size_allocateCB ',GtkWidth,',',GtkHeight]);
  LCLControl.WindowProc(TLMessage(SizeMsg));
end;
{$ENDIF}

function LOpenGLCreateContextCore(AWinControl: TWinControl;
  WSPrivate: TWSPrivateClass; SharedControl: TWinControl;
  DoubleBuffered, RGBA, DebugContext: boolean;
  const RedBits, GreenBits, BlueBits, MajorVersion, MinorVersion,
  MultiSampling, AlphaBits, DepthBits, StencilBits, AUXBuffers: Cardinal;
  const AParams: TCreateParams): HWND;
var
  NewWidget: PGtkWidget;
  SharedArea: PGtkGLArea;
  Attribs: TContextAttribs;
begin
  if WSPrivate=nil then ;
  {$IFDEF VerboseMultiSampling}
  debugln(['LOpenGLCreateContextCore MultiSampling=',MultiSampling]);
  {$ENDIF}
  Attribs.AttributeList:=CreateOpenGLContextAttrList(DoubleBuffered,RGBA,RedBits,GreenBits,
    BlueBits,AlphaBits,DepthBits,StencilBits,AUXBuffers);
  Attribs.MajorVersion:=MajorVersion;
  Attribs.MinorVersion:=MinorVersion;

  // fill in context flags
  Attribs.ContextFlags:=0;
  if DebugContext then
     Attribs.ContextFlags:=Attribs.ContextFlags or GLX_CONTEXT_DEBUG_BIT_ARB;

  if MultiSampling>1 then begin
    Attribs.MultiSampling:=MultiSampling;
  end else begin
    Attribs.MultiSampling:=0;
  end;
  try
    if SharedControl<>nil then begin
      SharedArea:={%H-}PGtkGLArea(PtrUInt(SharedControl.Handle));
      if not GTK_IS_GL_AREA(SharedArea) then
        RaiseGDBException('LOpenGLCreateContext');
      NewWidget:=gtk_gl_area_share_new(Attribs,SharedArea);
    end else begin
      NewWidget:=gtk_gl_area_new(Attribs);
    end;
    Result:=HWND({%H-}PtrUInt(Pointer(NewWidget)));
    PGtkobject(NewWidget)^.flags:=PGtkobject(NewWidget)^.flags or GTK_CAN_FOCUS;
    {$IFDEF LCLGtk}
    TGTKWidgetSet(WidgetSet).FinishCreateHandle(AWinControl,NewWidget,AParams);
    {$ELSE}
    TGTK2WidgetSet(WidgetSet).FinishCreateHandle(AWinControl,NewWidget,AParams);
    g_signal_connect_after(PGtkObject(NewWidget), 'size-allocate',
                       TGTKSignalFunc(@gtkglarea_size_allocateCB), AWinControl);
    {$ENDIF}
  finally
    FreeMem(Attribs.AttributeList);
  end;
end;

function LOpenGLCreateContext(AWinControl: TWinControl;
  WSPrivate: TWSPrivateClass; SharedControl: TWinControl;
  DoubleBuffered, RGBA, DebugContext: boolean;
  const RedBits, GreenBits, BlueBits, MajorVersion, MinorVersion,
  MultiSampling, AlphaBits, DepthBits, StencilBits, AUXBuffers: Cardinal;
  const AParams: TCreateParams): HWND;
begin
  {$IFDEF VerboseMultiSampling}
  debugln(['LOpenGLCreateContext MultiSampling=',MultiSampling]);
  {$ENDIF}
  if (MultiSampling > 1) and
     GLX_ARB_multisample(GetDefaultXDisplay, DefaultScreen(GetDefaultXDisplay))
  then begin
    {$IFDEF VerboseMultiSampling}
    debugln(['LOpenGLCreateContext GLX_ARB_multisample succeeded']);
    {$ENDIF}
    try
      Result := LOpenGLCreateContextCore(AWinControl, WSPrivate, SharedControl,
        DoubleBuffered, RGBA, DebugContext, RedBits, GreenBits, BlueBits, MajorVersion,
        MinorVersion, MultiSampling, AlphaBits, DepthBits, StencilBits,
        AUXBuffers, AParams);
    except
      {$IFDEF VerboseMultiSampling}
      debugln(['LOpenGLCreateContext LOpenGLCreateContextCore failed, trying without multisampling']);
      {$ENDIF}
      { retry without MultiSampling }
      Result := LOpenGLCreateContextCore(AWinControl, WSPrivate, SharedControl,
        DoubleBuffered, RGBA, DebugContext, RedBits, GreenBits, BlueBits, MajorVersion,
        MinorVersion, 1, AlphaBits, DepthBits, StencilBits, AUXBuffers, AParams);
    end;
  end else begin
    { no multi-sampling requested (or GLX_ARB_multisample not available),
      just pass to LOpenGLCreateContextCore }
    Result := LOpenGLCreateContextCore(AWinControl, WSPrivate, SharedControl, 
      DoubleBuffered, RGBA, DebugContext, RedBits, GreenBits, BlueBits, MajorVersion,
      MinorVersion, MultiSampling, AlphaBits, DepthBits, StencilBits,
      AUXBuffers, AParams);
  end;
end;

procedure LOpenGLDestroyContextInfo(AWinControl: TWinControl);
begin
  if not AWinControl.HandleAllocated then exit;
  // nothing to do
end;

function CreateOpenGLContextAttrList(DoubleBuffered: boolean; RGBA: boolean;
  const RedBits, GreenBits, BlueBits, AlphaBits, DepthBits, StencilBits,
  AUXBuffers: Cardinal): PInteger;
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
    if UseFBConfig then begin
      Add(GLX_X_RENDERABLE); Add(1);
      Add(GLX_X_VISUAL_TYPE); Add(GLX_TRUE_COLOR);
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

    Add(0); { 0 = X.None (be careful: GLX_NONE is something different) }
  end;
  
begin
  {$IFDEF VerboseMultiSampling}
  debugln(['CreateOpenGLContextAttrList MultiSampling=',MultiSampling]);
  {$ENDIF}
  UseFBConfig := GLX_version_1_3(GetDefaultXDisplay);
  Result:=nil;
  CreateList;
  GetMem(Result,SizeOf(integer)*p);
  CreateList;
end;

end.

