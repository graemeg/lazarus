//----------------------------------------------------------------------------
// Anti-Grain Geometry - Version 2.4 (Public License)
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
//
// Anti-Grain Geometry - Version 2.4 Release Milano 3 (AggPas 2.4 RM3)
// Pascal Port By: Milan Marusinec alias Milano
//                 milan@marusinec.sk
//                 http://www.aggpas.org
// Copyright (c) 2005-2006
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.
//
//----------------------------------------------------------------------------
// Contact: mcseem@antigrain.com
//          mcseemagg@yahoo.com
//          http://www.antigrain.com
//
//----------------------------------------------------------------------------
//
// class platform_support
//
// It's not a part of the AGG library, it's just a helper class to create
// interactive demo examples. Since the examples should not be too complex
// this class is provided to support some very basic interactive graphical
// funtionality, such as putting the rendered image to the window, simple
// keyboard and mouse input, window resizing, setting the window title,
// and catching the "idle" events.
//
// The most popular platforms are:
//
// Windows-32 API
// X-Window API
// SDL library (see http://www.libsdl.org/)
// MacOS C/C++ API
//
// All the system dependent stuff sits in the platform_specific class.
// The platform_support class has just a pointer to it and it's
// the responsibility of the implementation to create/delete it.
// This class being defined in the implementation file can have
// any platform dependent stuff such as HWND, X11 Window and so on.
//
// [Pascal Port History] -----------------------------------------------------
//
// 23.06.2006-Milano: ptrcomp adjustments
// 29.03.2006-Milano: finished & tested OK
// 28.03.2006-Milano: platform_specific & platform_support
// 20.03.2006-Milano: Unit port establishment
//
{ agg_platform_support.pas }
unit
 agg_platform_support ;

INTERFACE

{$I agg_mode.inc }
{$I- }
uses
 X ,Xlib ,Xutil ,Xatom ,keysym ,CTypes ,SysUtils ,
 agg_linux_mini_libc ,
 agg_basics ,
 agg_ctrl ,
 agg_rendering_buffer ,
 agg_trans_affine ,
 agg_trans_viewport ,
 agg_color_conv ,
 file_utils_ ;

const
  xFalse = 0;
  xTrue = 1;

{ TYPES DEFINITION }
const
//----------------------------------------------------------window_flag_e
// These are flags used in method init(). Not all of them are
// applicable on different platforms, for example the win32_api
// cannot use a hardware buffer (window_hw_buffer).
// The implementation should simply ignore unsupported flags.
 window_resize            = 1;
 window_hw_buffer         = 2;
 window_keep_aspect_ratio = 4;
 window_process_all_keys  = 8;

type
//-----------------------------------------------------------pix_format_e
// Possible formats of the rendering buffer. Initially I thought that it's
// reasonable to create the buffer and the rendering functions in
// accordance with the native pixel format of the system because it
// would have no overhead for pixel format conersion.
// But eventually I came to a conclusion that having a possibility to
// convert pixel formats on demand is a good idea. First, it was X11 where
// there lots of different formats and visuals and it would be great to
// render everything in, say, RGB-24 and display it automatically without
// any additional efforts. The second reason is to have a possibility to
// debug renderers for different pixel formats and colorspaces having only
// one computer and one system.
//
// This stuff is not included into the basic AGG functionality because the
// number of supported pixel formats (and/or colorspaces) can be great and
// if one needs to add new format it would be good only to add new
// rendering files without having to modify any existing ones (a general
// principle of incapsulation and isolation).
//
// Using a particular pixel format doesn't obligatory mean the necessity
// of software conversion. For example, win32 API can natively display
// gray8, 15-bit RGB, 24-bit BGR, and 32-bit BGRA formats.
// This list can be (and will be!) extended in future.
 pix_format_e = (

  pix_format_undefined ,     // By default. No conversions are applied
  pix_format_bw,             // 1 bit per color B/W
  pix_format_gray8,          // Simple 256 level grayscale
  pix_format_gray16,         // Simple 65535 level grayscale
  pix_format_rgb555,         // 15 bit rgb. Depends on the byte ordering!
  pix_format_rgb565,         // 16 bit rgb. Depends on the byte ordering!
  pix_format_rgbAAA,         // 30 bit rgb. Depends on the byte ordering!
  pix_format_rgbBBA,         // 32 bit rgb. Depends on the byte ordering!
  pix_format_bgrAAA,         // 30 bit bgr. Depends on the byte ordering!
  pix_format_bgrABB,         // 32 bit bgr. Depends on the byte ordering!
  pix_format_rgb24,          // R-G-B, one byte per color component
  pix_format_bgr24,          // B-G-R, native win32 BMP format.
  pix_format_rgba32,         // R-G-B-A, one byte per color component
  pix_format_argb32,         // A-R-G-B, native MAC format
  pix_format_abgr32,         // A-B-G-R, one byte per color component
  pix_format_bgra32,         // B-G-R-A, native win32 BMP format
  pix_format_rgb48,          // R-G-B, 16 bits per color component
  pix_format_bgr48,          // B-G-R, native win32 BMP format.
  pix_format_rgba64,         // R-G-B-A, 16 bits byte per color component
  pix_format_argb64,         // A-R-G-B, native MAC format
  pix_format_abgr64,         // A-B-G-R, one byte per color component
  pix_format_bgra64,         // B-G-R-A, native win32 BMP format

  end_of_pix_formats );

const
//-------------------------------------------------------------input_flag_e
// Mouse and keyboard flags. They can be different on different platforms
// and the ways they are obtained are also different. But in any case
// the system dependent flags should be mapped into these ones. The meaning
// of that is as follows. For example, if kbd_ctrl is set it means that the
// ctrl key is pressed and being held at the moment. They are also used in
// the overridden methods such as on_mouse_move(), on_mouse_button_down(),
// on_mouse_button_dbl_click(), on_mouse_button_up(), on_key().
// In the method on_mouse_button_up() the mouse flags have different
// meaning. They mean that the respective button is being released, but
// the meaning of the keyboard flags remains the same.
// There's absolut minimal set of flags is used because they'll be most
// probably supported on different platforms. Even the mouse_right flag
// is restricted because Mac's mice have only one button, but AFAIK
// it can be simulated with holding a special key on the keydoard.
 mouse_left  = 1;
 mouse_right = 2;
 kbd_shift   = 4;
 kbd_ctrl    = 8;

//--------------------------------------------------------------key_code_e
// Keyboard codes. There's also a restricted set of codes that are most
// probably supported on different platforms. Any platform dependent codes
// should be converted into these ones. There're only those codes are
// defined that cannot be represented as printable ASCII-characters.
// All printable ASCII-set can be used in a regilar C/C++ manner:
// ' ', 'A', '0' '+' and so on.
// Since the clasas is used for creating very simple demo-applications
// we don't need very rich possibilities here, just basic ones.
// Actually the numeric key codes are taken from the SDL library, so,
// the implementation of the SDL support does not require any mapping.
// ASCII set. Should be supported everywhere
 key_backspace      = 8;
 key_tab            = 9;
 key_clear          = 12;
 key_return         = 13;
 key_pause          = 19;
 key_escape         = 27;

// Keypad
 key_delete         = 127;
 key_kp0            = 256;
 key_kp1            = 257;
 key_kp2            = 258;
 key_kp3            = 259;
 key_kp4            = 260;
 key_kp5            = 261;
 key_kp6            = 262;
 key_kp7            = 263;
 key_kp8            = 264;
 key_kp9            = 265;
 key_kp_period      = 266;
 key_kp_divide      = 267;
 key_kp_multiply    = 268;
 key_kp_minus       = 269;
 key_kp_plus        = 270;
 key_kp_enter       = 271;
 key_kp_equals      = 272;

// Arrow-keys and stuff
 key_up             = 273;
 key_down           = 274;
 key_right          = 275;
 key_left           = 276;
 key_insert         = 277;
 key_home           = 278;
 key_end            = 279;
 key_page_up        = 280;
 key_page_down      = 281;

// Functional keys. You'd better avoid using
// f11...f15 in your applications if you want
// the applications to be portable
 key_f1             = 282;
 key_f2             = 283;
 key_f3             = 284;
 key_f4             = 285;
 key_f5             = 286;
 key_f6             = 287;
 key_f7             = 288;
 key_f8             = 289;
 key_f9             = 290;
 key_f10            = 291;
 key_f11            = 292;
 key_f12            = 293;
 key_f13            = 294;
 key_f14            = 295;
 key_f15            = 296;

// The possibility of using these keys is
// very restricted. Actually it's guaranteed
// only in win32_api and win32_sdl implementations
 key_numlock        = 300;
 key_capslock       = 301;
 key_scrollock      = 302;

 max_ctrl = 128;

type
//----------------------------------------------------------ctrl_container
// A helper class that contains pointers to a number of controls.
// This class is used to ease the event handling with controls.
// The implementation should simply call the appropriate methods
// of this class when appropriate events occur.
 crtl_container_ptr = ^ctrl_container;
 ctrl_container = object
   m_ctrl : array[0..max_ctrl - 1 ] of ctrl_ptr;

   m_num_ctrl : unsigned;
   m_cur_ctrl : int;

   constructor Construct;
   destructor  Destruct;

   procedure add(c : ctrl_ptr );

   function  in_rect(x ,y : double ) : boolean;

   function  on_mouse_button_down(x ,y : double ) : boolean;
   function  on_mouse_button_up  (x ,y : double ) : boolean;

   function  on_mouse_move(x ,y : double; button_flag : boolean ) : boolean;
   function  on_arrow_keys(left ,right ,down ,up : boolean ) : boolean;

   function  set_cur(x ,y : double ) : boolean;

  end;

//---------------------------------------------------------platform_support
// This class is a base one to the apllication classes. It can be used
// as follows:
//
//  the_application = object(platform_support )
//
//      constructor Construct(bpp : unsigned; flip_y : boolean );
//      . . .
//
//      //override stuff . . .
//      procedure on_init; virtual;
//      procedure on_draw; virtual;
//      procedure on_resize(sx ,sy : int ); virtual;
//      // . . . and so on, see virtual functions
//
//      //any your own stuff . . .
//  };
//
//  VAR
//   app : the_application;
//
//  BEGIN
//   app.Construct(pix_format_rgb24 ,true );
//   app.caption  ("AGG Example. Lion" );
//
//   if app.init(500 ,400 ,window_resize ) then
//    app.run;
//
//   app.Destruct;
//
//  END.
//
const
 max_images = 16;

type
 platform_specific_ptr = ^platform_specific;
 platform_specific = object
   m_format     ,
   m_sys_format : pix_format_e;
   m_byte_order : int;

   m_flip_y  : boolean;
   m_bpp     ,
   m_sys_bpp : unsigned;
   m_display : PDisplay;
   m_screen  ,
   m_depth   : int;
   m_visual  : PVisual;
   m_window  : TWindow;
   m_gc      : TGC;

   m_window_attributes : TXSetWindowAttributes;

   m_ximg_window : PXImage;
   m_close_atom  : TAtom;
   m_buf_window  : pointer;
   m_buf_alloc   : unsigned;
   m_buf_img     : array[0..max_images - 1 ] of pointer;
   m_img_alloc   : array[0..max_images - 1 ] of unsigned;

   m_keymap : array[0..255 ] of unsigned;

   m_update_flag ,
   m_resize_flag ,
   m_initialized : boolean;

   //m_wait_mode : boolean;
   m_sw_start  : clock_t;

   constructor Construct(format : pix_format_e; flip_y : boolean );
   destructor  Destruct;

   procedure caption_ (capt : PChar );
   procedure put_image(src : rendering_buffer_ptr );

  end;

 platform_support_ptr = ^platform_support;
 platform_support = object
   m_specific : platform_specific_ptr;
   m_ctrls    : ctrl_container;

   m_format : pix_format_e;

   m_bpp : unsigned;

   m_rbuf_window : rendering_buffer;
   m_rbuf_img    : array[0..max_images - 1 ] of rendering_buffer;

   m_window_flags : unsigned;
   m_wait_mode    ,
   m_flip_y       : boolean;        // flip_y - true if you want to have the Y-axis flipped vertically
   m_caption      : shortstring;
   m_resize_mtx   : trans_affine;

   m_initial_width  ,
   m_initial_height : int;

   m_quit : boolean;

   constructor Construct(format_ : pix_format_e; flip_y_ : boolean );
   destructor  Destruct;

  // Setting the windows caption (title). Should be able
  // to be called at least before calling init().
  // It's perfect if they can be called anytime.
   procedure caption_(cap : shortstring );

  // These 3 menthods handle working with images. The image
  // formats are the simplest ones, such as .BMP in Windows or
  // .ppm in Linux. In the applications the names of the files
  // should not have any file extensions. Method load_img() can
  // be called before init(), so, the application could be able
  // to determine the initial size of the window depending on
  // the size of the loaded image.
  // The argument "idx" is the number of the image 0...max_images-1
   function  load_img  (idx : unsigned; file_ : shortstring ) : boolean;
   function  save_img  (idx : unsigned; file_ : shortstring ) : boolean;
   function  create_img(idx : unsigned; width_ : unsigned = 0; height_ : unsigned = 0 ) : boolean;

  // init() and run(). See description before the class for details.
  // The necessity of calling init() after creation is that it's
  // impossible to call the overridden virtual function (on_init())
  // from the constructor. On the other hand it's very useful to have
  // some on_init() event handler when the window is created but
  // not yet displayed. The rbuf_window() method (see below) is
  // accessible from on_init().
   function  init(width_ ,height_ ,flags : unsigned ) : boolean;
   function  run : int;
   procedure quit;

  // The very same parameters that were used in the constructor
   function  _format : pix_format_e;
   function  _flip_y : boolean;
   function  _bpp : unsigned;

  // The following provides a very simple mechanism of doing someting
  // in background. It's not multitheading. When whait_mode is true
  // the class waits for the events and it does not ever call on_idle().
  // When it's false it calls on_idle() when the event queue is empty.
  // The mode can be changed anytime. This mechanism is satisfactory
  // for creation very simple animations.
   function  _wait_mode : boolean;
   procedure wait_mode_(wait_mode : boolean );

  // These two functions control updating of the window.
  // force_redraw() is an analog of the Win32 InvalidateRect() function.
  // Being called it sets a flag (or sends a message) which results
  // in calling on_draw() and updating the content of the window
  // when the next event cycle comes.
  // update_window() results in just putting immediately the content
  // of the currently rendered buffer to the window without calling
  // on_draw().
   procedure force_redraw;
   procedure update_window;

  // So, finally, how to draw anythig with AGG? Very simple.
  // rbuf_window() returns a reference to the main rendering
  // buffer which can be attached to any rendering class.
  // rbuf_img() returns a reference to the previously created
  // or loaded image buffer (see load_img()). The image buffers
  // are not displayed directly, they should be copied to or
  // combined somehow with the rbuf_window(). rbuf_window() is
  // the only buffer that can be actually displayed.
   function  rbuf_window : rendering_buffer_ptr;
   function  rbuf_img(idx : unsigned ) : rendering_buffer_ptr;

  // Returns file extension used in the implemenation for the particular
  // system.
   function  _img_ext : shortstring;

  //
   procedure copy_img_to_window(idx : unsigned );
   procedure copy_window_to_img(idx : unsigned );
   procedure copy_img_to_img   (idx_to ,idx_from : unsigned );

  // Event handlers. They are not pure functions, so you don't have
  // to override them all.
  // In my demo applications these functions are defined inside
  // the the_application class
   procedure on_init; virtual;
   procedure on_resize(sx ,sy : int ); virtual;
   procedure on_idle; virtual;

   procedure on_mouse_move(x ,y : int; flags : unsigned ); virtual;

   procedure on_mouse_button_down(x ,y : int; flags : unsigned ); virtual;
   procedure on_mouse_button_up  (x ,y : int; flags : unsigned ); virtual;

   procedure on_key(x ,y : int; key ,flags : unsigned ); virtual;
   procedure on_ctrl_change; virtual;
   procedure on_draw; virtual;
   procedure on_post_draw(raw_handler : pointer ); virtual;

  // Adding control elements. A control element once added will be
  // working and reacting to the mouse and keyboard events. Still, you
  // will have to render them in the on_draw() using function
  // render_ctrl() because platform_support doesn't know anything about
  // renderers you use. The controls will be also scaled automatically
  // if they provide a proper scaling mechanism (all the controls
  // included into the basic AGG package do).
  // If you don't need a particular control to be scaled automatically
  // call ctrl::no_transform() after adding.
   procedure add_ctrl(c : ctrl_ptr );

  // Auxiliary functions. trans_affine_resizing() modifier sets up the resizing
  // matrix on the basis of the given width and height and the initial
  // width and height of the window. The implementation should simply
  // call this function every time when it catches the resizing event
  // passing in the new values of width and height of the window.
  // Nothing prevents you from "cheating" the scaling matrix if you
  // call this function from somewhere with wrong arguments.
  // trans_affine_resizing() accessor simply returns current resizing matrix
  // which can be used to apply additional scaling of any of your
  // stuff when the window is being resized.
  // width(), height(), initial_width(), and initial_height() must be
  // clear to understand with no comments :-)
   procedure trans_affine_resizing_(width_ ,height_ : int );
   function  _trans_affine_resizing : trans_affine_ptr;

   function  _width : double;
   function  _height : double;
   function  _initial_width : double;
   function  _initial_height : double;
   function  _window_flags : unsigned;

  // Get raw display handler depending on the system.
  // For win32 its an HDC, for other systems it can be a pointer to some
  // structure. See the implementation files for detals.
  // It's provided "as is", so, first you should check if it's not null.
  // If it's null the raw_display_handler is not supported. Also, there's
  // no guarantee that this function is implemented, so, in some
  // implementations you may have simply an unresolved symbol when linking.
   function  _raw_display_handler : pointer;

  // display message box or print the message to the console
  // (depending on implementation)
   procedure message_(msg : PChar );

  // Stopwatch functions. Function elapsed_time() returns time elapsed
  // since the latest start_timer() invocation in millisecods.
  // The resolutoin depends on the implementation.
  // In Win32 it uses QueryPerformanceFrequency() / QueryPerformanceCounter().
   procedure start_timer;
   function  elapsed_time : double;

  // Get the full file name. In most cases it simply returns
  // file_name. As it's appropriate in many systems if you open
  // a file by its name without specifying the path, it tries to
  // open it in the current directory. The demos usually expect
  // all the supplementary files to be placed in the current
  // directory, that is usually coincides with the directory where
  // the the executable is. However, in some systems (BeOS) it's not so.
  // For those kinds of systems full_file_name() can help access files
  // preserving commonly used policy.
  // So, it's a good idea to use in the demos the following:
  // FILE* fd = fopen(full_file_name("some.file"), "r");
  // instead of
  // FILE* fd = fopen("some.file", "r");
   function  full_file_name(file_name : shortstring ) : shortstring;
   function  file_source   (path ,fname : shortstring ) : shortstring;

  end;

{ GLOBAL PROCEDURES }


IMPLEMENTATION
{ LOCAL VARIABLES & CONSTANTS }
{ UNIT IMPLEMENTATION }
{ CONSTRUCT }
constructor ctrl_container.Construct;
begin
 m_num_ctrl:=0;
 m_cur_ctrl:=-1;

end;

{ DESTRUCT }
destructor ctrl_container.Destruct;
begin
end;

{ ADD }
procedure ctrl_container.add;
begin
 if m_num_ctrl < max_ctrl then
  begin
   m_ctrl[m_num_ctrl ]:=c;

   inc(m_num_ctrl );

  end;

end;

{ IN_RECT }
function ctrl_container.in_rect;
var
 i : unsigned;

begin
 result:=false;

 if m_num_ctrl > 0 then
  for i:=0 to m_num_ctrl - 1 do
   if m_ctrl[i ].in_rect(x ,y ) then
    begin
     result:=true;

     exit;

    end;

end;

{ ON_MOUSE_BUTTON_DOWN }
function ctrl_container.on_mouse_button_down;
var
 i : unsigned;

begin
 result:=false;

 if m_num_ctrl > 0 then
  for i:=0 to m_num_ctrl - 1 do
   if m_ctrl[i ].on_mouse_button_down(x ,y ) then
    begin
     result:=true;

     exit;

    end;

end;

{ ON_MOUSE_BUTTON_UP }
function ctrl_container.on_mouse_button_up;
var
 i : unsigned;

begin
 result:=false;

 if m_num_ctrl > 0 then
  for i:=0 to m_num_ctrl - 1 do
   if m_ctrl[i ].on_mouse_button_up(x ,y ) then
    begin
     result:=true;

     exit;

    end;

end;

{ ON_MOUSE_MOVE }
function ctrl_container.on_mouse_move;
var
 i : unsigned;

begin
 result:=false;

 if m_num_ctrl > 0 then
  for i:=0 to m_num_ctrl - 1 do
   if m_ctrl[i ].on_mouse_move(x ,y ,button_flag ) then
    begin
     result:=true;

     exit;

    end;

end;

{ ON_ARROW_KEYS }
function ctrl_container.on_arrow_keys;
begin
 result:=false;

 if m_cur_ctrl >= 0 then
  result:=m_ctrl[m_cur_ctrl ].on_arrow_keys(left ,right ,down ,up );

end;

{ SET_CUR }
function ctrl_container.set_cur;
var
 i : unsigned;

begin
 result:=false;

 if m_num_ctrl > 0 then
  for i:=0 to m_num_ctrl - 1 do
   if m_ctrl[i ].in_rect(x ,y ) then
    begin
     if m_cur_ctrl <> i then
      begin
       m_cur_ctrl:=i;

       result:=true;

      end;

     exit;

    end;

 if m_cur_ctrl <> -1 then
  begin
   m_cur_ctrl:=-1;

   result:=true;

  end;

end;

{ CONSTRUCT }
constructor platform_specific.Construct;
var
 i : unsigned;

begin
 m_format    :=format;
 m_sys_format:=pix_format_undefined;
 m_byte_order:=LSBFirst;
 m_flip_y    :=flip_y;

 m_bpp    :=0;
 m_sys_bpp:=0;
 m_display:=NIL;
 m_screen :=0;
 m_depth  :=0;
 m_visual :=NIL;
 m_window :=0;
 m_gc     :=NIL;

 m_ximg_window:=NIL;
 m_close_atom :=0;
 m_buf_window :=NIL;
 m_buf_alloc  :=0;

 m_update_flag:=true;
 m_resize_flag:=true;
 m_initialized:=false;
 //m_wait_mode:=true;

 fillchar(m_buf_img[0 ] ,sizeof(m_buf_img ) ,0 );

 for i:=0 to 255 do
  m_keymap[i ]:=i;

 m_keymap[XK_Pause and $FF ]:=key_pause;
 m_keymap[XK_Clear and $FF ]:=key_clear;

 m_keymap[XK_KP_0 and $FF ]:=key_kp0;
 m_keymap[XK_KP_1 and $FF ]:=key_kp1;
 m_keymap[XK_KP_2 and $FF ]:=key_kp2;
 m_keymap[XK_KP_3 and $FF ]:=key_kp3;
 m_keymap[XK_KP_4 and $FF ]:=key_kp4;
 m_keymap[XK_KP_5 and $FF ]:=key_kp5;
 m_keymap[XK_KP_6 and $FF ]:=key_kp6;
 m_keymap[XK_KP_7 and $FF ]:=key_kp7;
 m_keymap[XK_KP_8 and $FF ]:=key_kp8;
 m_keymap[XK_KP_9 and $FF ]:=key_kp9;

 m_keymap[XK_KP_Insert and $FF ]   :=key_kp0;
 m_keymap[XK_KP_End and $FF ]      :=key_kp1;
 m_keymap[XK_KP_Down and $FF ]     :=key_kp2;
 m_keymap[XK_KP_Page_Down and $FF ]:=key_kp3;
 m_keymap[XK_KP_Left and $FF ]     :=key_kp4;
 m_keymap[XK_KP_Begin and $FF ]    :=key_kp5;
 m_keymap[XK_KP_Right and $FF ]    :=key_kp6;
 m_keymap[XK_KP_Home and $FF ]     :=key_kp7;
 m_keymap[XK_KP_Up and $FF ]       :=key_kp8;
 m_keymap[XK_KP_Page_Up and $FF ]  :=key_kp9;
 m_keymap[XK_KP_Delete and $FF ]   :=key_kp_period;
 m_keymap[XK_KP_Decimal and $FF ]  :=key_kp_period;
 m_keymap[XK_KP_Divide and $FF ]   :=key_kp_divide;
 m_keymap[XK_KP_Multiply and $FF ] :=key_kp_multiply;
 m_keymap[XK_KP_Subtract and $FF ] :=key_kp_minus;
 m_keymap[XK_KP_Add and $FF ]      :=key_kp_plus;
 m_keymap[XK_KP_Enter and $FF ]    :=key_kp_enter;
 m_keymap[XK_KP_Equal and $FF ]    :=key_kp_equals;

 m_keymap[XK_Up and $FF ]       :=key_up;
 m_keymap[XK_Down and $FF ]     :=key_down;
 m_keymap[XK_Right and $FF ]    :=key_right;
 m_keymap[XK_Left and $FF ]     :=key_left;
 m_keymap[XK_Insert and $FF ]   :=key_insert;
 m_keymap[XK_Home and $FF ]     :=key_delete;
 m_keymap[XK_End and $FF ]      :=key_end;
 m_keymap[XK_Page_Up and $FF ]  :=key_page_up;
 m_keymap[XK_Page_Down and $FF ]:=key_page_down;

 m_keymap[XK_F1 and $FF ] :=key_f1;
 m_keymap[XK_F2 and $FF ] :=key_f2;
 m_keymap[XK_F3 and $FF ] :=key_f3;
 m_keymap[XK_F4 and $FF ] :=key_f4;
 m_keymap[XK_F5 and $FF ] :=key_f5;
 m_keymap[XK_F6 and $FF ] :=key_f6;
 m_keymap[XK_F7 and $FF ] :=key_f7;
 m_keymap[XK_F8 and $FF ] :=key_f8;
 m_keymap[XK_F9 and $FF ] :=key_f9;
 m_keymap[XK_F10 and $FF ]:=key_f10;
 m_keymap[XK_F11 and $FF ]:=key_f11;
 m_keymap[XK_F12 and $FF ]:=key_f12;
 m_keymap[XK_F13 and $FF ]:=key_f13;
 m_keymap[XK_F14 and $FF ]:=key_f14;
 m_keymap[XK_F15 and $FF ]:=key_f15;

 m_keymap[XK_Num_Lock and $FF ]   :=key_numlock;
 m_keymap[XK_Caps_Lock and $FF ]  :=key_capslock;
 m_keymap[XK_Scroll_Lock and $FF ]:=key_scrollock;

 case m_format of
  pix_format_gray8 :
   m_bpp:=8;

  pix_format_rgb565 ,
  pix_format_rgb555 :
   m_bpp:=16;

  pix_format_rgb24 ,
  pix_format_bgr24 :
   m_bpp:=24;

  pix_format_bgra32 ,
  pix_format_abgr32 ,
  pix_format_argb32 ,
  pix_format_rgba32 :
   m_bpp:=32;

 end;

 m_sw_start:=clock;

end;

{ DESTRUCT }
destructor platform_specific.Destruct;
begin
end;

{ CAPTION_ }
procedure platform_specific.caption_;
var
 tp : TXTextProperty;

begin
 tp.value   :=PCUChar(@capt[1 ] );
 tp.encoding:=XA_WM_NAME;
 tp.format  :=8;
 tp.nitems  :=strlen(capt );

 XSetWMName    (m_display ,m_window ,@tp );
 XStoreName    (m_display ,m_window ,capt );
 XSetIconName  (m_display ,m_window ,capt );
 XSetWMIconName(m_display ,m_window ,@tp );

end;

{ PUT_IMAGE }
procedure platform_specific.put_image;
var
 row_len : int;
 buf_tmp : pointer;

 rbuf_tmp : rendering_buffer;

begin
 if m_ximg_window = NIL then
  exit;

 m_ximg_window.data:=m_buf_window;

 if m_format = m_sys_format then
  XPutImage(
   m_display ,
   m_window ,
   m_gc ,
   m_ximg_window ,
   0 ,0 ,0 ,0 ,
   src._width ,
   src._height )

 else
  begin
   row_len:=src._width * m_sys_bpp div 8;

   agg_getmem(buf_tmp ,row_len * src._height );

   rbuf_tmp.Construct;

   if m_flip_y then
    rbuf_tmp.attach(
     buf_tmp ,
     src._width,
     src._height ,
     -row_len )
   else
    rbuf_tmp.attach(
     buf_tmp ,
     src._width,
     src._height ,
     row_len );

   case m_sys_format of
    pix_format_rgb555 :
     case m_format of
      pix_format_rgb555 : color_conv(@rbuf_tmp ,src ,color_conv_rgb555_to_rgb555 );
      pix_format_rgb565 : color_conv(@rbuf_tmp ,src ,color_conv_rgb565_to_rgb555 );
      //pix_format_rgb24  : color_conv(@rbuf_tmp ,src ,color_conv_rgb24_to_rgb555 );
      pix_format_bgr24  : color_conv(@rbuf_tmp ,src ,color_conv_bgr24_to_rgb555 );
      //pix_format_rgba32 : color_conv(@rbuf_tmp ,src ,color_conv_rgba32_to_rgb555 );
      //pix_format_argb32 : color_conv(@rbuf_tmp ,src ,color_conv_argb32_to_rgb555 );
      pix_format_bgra32 : color_conv(@rbuf_tmp ,src ,color_conv_bgra32_to_rgb555 );
      //pix_format_abgr32 : color_conv(@rbuf_tmp ,src ,color_conv_abgr32_to_rgb555 );

     end;

    pix_format_rgb565 :
     case m_format of
      pix_format_rgb555 : color_conv(@rbuf_tmp ,src ,color_conv_rgb555_to_rgb565 );
      //pix_format_rgb565 : color_conv(@rbuf_tmp ,src ,color_conv_rgb565_to_rgb565 );
      //pix_format_rgb24  : color_conv(@rbuf_tmp ,src ,color_conv_rgb24_to_rgb565 );
      pix_format_bgr24  : color_conv(@rbuf_tmp ,src ,color_conv_bgr24_to_rgb565 );
      //pix_format_rgba32 : color_conv(@rbuf_tmp ,src ,color_conv_rgba32_to_rgb565 );
      //pix_format_argb32 : color_conv(@rbuf_tmp ,src ,color_conv_argb32_to_rgb565 );
      pix_format_bgra32 : color_conv(@rbuf_tmp ,src ,color_conv_bgra32_to_rgb565 );
      //pix_format_abgr32 : color_conv(@rbuf_tmp ,src ,color_conv_abgr32_to_rgb565 );

     end;

    pix_format_rgba32 :
     case m_format of
      pix_format_rgb555 : color_conv(@rbuf_tmp ,src ,color_conv_rgb555_to_rgba32 );
      //pix_format_rgb565 : color_conv(@rbuf_tmp ,src ,color_conv_rgb565_to_rgba32 );
      //pix_format_rgb24  : color_conv(@rbuf_tmp ,src ,color_conv_rgb24_to_rgba32 );
      pix_format_bgr24  : color_conv(@rbuf_tmp ,src ,color_conv_bgr24_to_rgba32 );
      //pix_format_rgba32 : color_conv(@rbuf_tmp ,src ,color_conv_rgba32_to_rgba32 );
      //pix_format_argb32 : color_conv(@rbuf_tmp ,src ,color_conv_argb32_to_rgba32 );
      pix_format_bgra32 : color_conv(@rbuf_tmp ,src ,color_conv_bgra32_to_rgba32 );
      //pix_format_abgr32 : color_conv(@rbuf_tmp ,src ,color_conv_abgr32_to_rgba32 );

     end;

    pix_format_abgr32 :
     case m_format of
      pix_format_rgb555 : color_conv(@rbuf_tmp ,src ,color_conv_rgb555_to_abgr32 );
      //pix_format_rgb565 : color_conv(@rbuf_tmp ,src ,color_conv_rgb565_to_abgr32 );
      //pix_format_rgb24  : color_conv(@rbuf_tmp ,src ,color_conv_rgb24_to_abgr32 );
      pix_format_bgr24  : color_conv(@rbuf_tmp ,src ,color_conv_bgr24_to_abgr32 );
      //pix_format_abgr32 : color_conv(@rbuf_tmp ,src ,color_conv_abgr32_to_abgr32 );
      //pix_format_rgba32 : color_conv(@rbuf_tmp ,src ,color_conv_rgba32_to_abgr32 );
      //pix_format_argb32 : color_conv(@rbuf_tmp ,src ,color_conv_argb32_to_abgr32 );
      pix_format_bgra32 : color_conv(@rbuf_tmp ,src ,color_conv_bgra32_to_abgr32 );

     end;

    pix_format_argb32 :
     case m_format of
      pix_format_rgb555 : color_conv(@rbuf_tmp ,src ,color_conv_rgb555_to_argb32 );
      //pix_format_rgb565 : color_conv(@rbuf_tmp ,src ,color_conv_rgb565_to_argb32 );
      //pix_format_rgb24  : color_conv(@rbuf_tmp ,src ,color_conv_rgb24_to_argb32 );
      pix_format_bgr24  : color_conv(@rbuf_tmp ,src ,color_conv_bgr24_to_argb32 );
      pix_format_rgba32 : color_conv(@rbuf_tmp ,src ,color_conv_rgba32_to_argb32 );
      //pix_format_argb32 : color_conv(@rbuf_tmp ,src ,color_conv_argb32_to_argb32 );
      pix_format_abgr32 : color_conv(@rbuf_tmp ,src ,color_conv_abgr32_to_argb32 );
      pix_format_bgra32 : color_conv(@rbuf_tmp ,src ,color_conv_bgra32_to_argb32 );

     end;

    pix_format_bgra32 :
     case m_format of
      pix_format_rgb555 : color_conv(@rbuf_tmp ,src ,color_conv_rgb555_to_bgra32 );
      //pix_format_rgb565 : color_conv(@rbuf_tmp ,src ,color_conv_rgb565_to_bgra32 );
      //pix_format_rgb24  : color_conv(@rbuf_tmp ,src ,color_conv_rgb24_to_bgra32 );
      pix_format_bgr24  : color_conv(@rbuf_tmp ,src ,color_conv_bgr24_to_bgra32 );
      pix_format_rgba32 : color_conv(@rbuf_tmp ,src ,color_conv_rgba32_to_bgra32 );
      pix_format_argb32 : color_conv(@rbuf_tmp ,src ,color_conv_argb32_to_bgra32 );
      pix_format_abgr32 : color_conv(@rbuf_tmp ,src ,color_conv_abgr32_to_bgra32 );
      pix_format_bgra32 : color_conv(@rbuf_tmp ,src ,color_conv_bgra32_to_bgra32 );

     end;

   end;

   m_ximg_window.data:=buf_tmp;

   XPutImage(
    m_display ,
    m_window ,
    m_gc ,
    m_ximg_window ,
    0 ,0 ,0 ,0 ,
    src._width ,
    src._height );

   agg_freemem(buf_tmp ,row_len * src._height );

   rbuf_tmp.Destruct;

  end;

end;

{ CONSTRUCT }
constructor platform_support.Construct;
var
 i : unsigned;

 p ,n ,x : shortstring;

begin
 new(m_specific ,Construct(format_ ,flip_y_ ) );

 m_ctrls.Construct;
 m_rbuf_window.Construct;

 for i:=0 to max_images - 1 do
  m_rbuf_img[i ].Construct;

 m_resize_mtx.Construct;

 m_format:=format_;

 m_bpp:=m_specific.m_bpp;

 m_window_flags:=0;
 m_wait_mode   :=true;
 m_flip_y      :=flip_y_;

 m_initial_width :=10;
 m_initial_height:=10;

 m_caption:='Anti-Grain Geometry Application'#0;

// Change working dir to the application one
 spread_name(ParamStr(0 ) ,p ,n ,x );

 p:=p + #0;

 SetCurrentDir(p);
 // libc.__chdir(PChar(@p[1 ] ) );

end;

{ DESTRUCT }
destructor platform_support.Destruct;
var
 i : unsigned;

begin
 dispose(m_specific ,Destruct );

 m_ctrls.Destruct;
 m_rbuf_window.Destruct;

 for i:=0 to max_images - 1 do
  m_rbuf_img[i ].Destruct;

end;

{ CAPTION_ }
procedure platform_support.caption_;
begin
 m_caption:=cap + #0;

 dec(byte(m_caption[0 ] ) );

 if m_specific.m_initialized then
  m_specific.caption_(PChar(@m_caption[1 ] ) );

end;

{ isdigit }
function isdigit(c : char ) : boolean;
begin
 case c of
  '0'..'9' :
   result:=true;

  else
   result:=false;

 end;

end;

{ atoi }
function atoi(c : char_ptr ) : int;
var
 s : shortstring;
 e : int;

begin
 s:='';

 repeat
  case c^ of
   '0'..'9' :
    s:=s + c^;

   else
    break;

  end;

  inc(ptrcomp(c ) );

 until false;

 val(s ,result ,e );

end;

{ LOAD_IMG }
function platform_support.load_img;
var
 fd  : file;
 buf : array[0..1023 ] of char;
 len : int;
 ptr : char_ptr;
 ret : boolean;

 width ,height : unsigned;

 buf_img   : pointer;
 rbuf_img_ : rendering_buffer;

begin
 result:=false;

 if idx < max_images then
  begin
   file_:=file_ + _img_ext;

   if not file_exists(file_ ) then
    file_:='ppm/' + file_;

   AssignFile(fd ,file_ );
   reset     (fd ,1 );

   if IOResult <> 0 then
    exit;

   blockread(fd ,buf ,1022 ,len );

   if len = 0 then
    begin
     close(fd );
     exit;

    end;

   buf[len ]:=#0;

   if (buf[0 ] <> 'P' ) and
      (buf[1 ] <> '6' ) then
    begin
     close(fd );
     exit;

    end;

   ptr:=@buf[2 ];

   while (ptr^ <> #0 ) and
         not isdigit(ptr^ ) do
    inc(ptrcomp(ptr ) );

   if ptr^ = #0 then
    begin
     close(fd );
     exit;

    end;

   width:=atoi(ptr );

   if (width = 0 ) or
      (width > 4096 ) then
    begin
     close(fd );
     exit;

    end;

   while (ptr^ <> #0 ) and
         isdigit(ptr^ ) do
    inc(ptrcomp(ptr ) );

   while (ptr^ <> #0 ) and
         not isdigit(ptr^ ) do
    inc(ptrcomp(ptr ) );

   if ptr^ = #0 then
    begin
     close(fd );
     exit;

    end;

   height:=atoi(ptr );

   if (height = 0 ) or
      (height > 4096 ) then
    begin
     close(fd );
     exit;

    end;

   while (ptr^ <> #0 ) and
         isdigit(ptr^ ) do
    inc(ptrcomp(ptr ) );

   while (ptr^ <> #0 ) and
         not isdigit(ptr^ ) do
    inc(ptrcomp(ptr ) );

   if atoi(ptr ) <> 255 then
    begin
     close(fd );
     exit;

    end;

   while (ptr^ <> #0 ) and
         isdigit(ptr^ ) do
    inc(ptrcomp(ptr ) );

   if ptr^ = #0 then
    begin
     close(fd );
     exit;

    end;

   inc       (ptrcomp(ptr ) );
   seek      (fd ,ptrcomp(ptr ) - ptrcomp(@buf ) );
   create_img(idx ,width ,height );

   ret:=true;

   if m_format = pix_format_rgb24 then
    blockread(fd ,m_specific.m_buf_img[idx ]^ ,width * height * 3 )
   else
    begin
     agg_getmem(buf_img ,width * height * 3 );

     rbuf_img_.Construct;

     if m_flip_y then
      rbuf_img_.attach(buf_img ,width ,height ,-width * 3 )
     else
      rbuf_img_.attach(buf_img ,width ,height ,width * 3 );

     blockread(fd ,buf_img^ ,width * height * 3 );

     case m_format of
      //pix_format_rgb555 : color_conv(@m_rbuf_img[idx ] ,@rbuf_img_ ,color_conv_rgb24_to_rgb555 );
      //pix_format_rgb565 : color_conv(@m_rbuf_img[idx ] ,@rbuf_img_ ,color_conv_rgb24_to_rgb565 );
      pix_format_bgr24  : color_conv(@m_rbuf_img[idx ] ,@rbuf_img_ ,color_conv_rgb24_to_bgr24 );
      //pix_format_rgba32 : color_conv(@m_rbuf_img[idx ] ,@rbuf_img_ ,color_conv_rgb24_to_rgba32 );
      //pix_format_argb32 : color_conv(@m_rbuf_img[idx ] ,@rbuf_img_ ,color_conv_rgb24_to_argb32 );
      pix_format_bgra32 : color_conv(@m_rbuf_img[idx ] ,@rbuf_img_ ,color_conv_rgb24_to_bgra32 );
      //pix_format_abgr32 : color_conv(@m_rbuf_img[idx ] ,@rbuf_img_ ,color_conv_rgb24_to_abgr32 );
      else
       ret:=false;

     end;

     agg_freemem(buf_img ,width * height * 3 );

     rbuf_img_.Destruct;

    end;

   close(fd );

   result:=ret;

  end;

end;

{ SAVE_IMG }
function platform_support.save_img;
var
 fd : file;

 s ,c : shortstring;

 w ,h ,y : unsigned;

 tmp_buf ,src : pointer;

begin
 result:=false; 

 if (idx < max_images ) and
    (rbuf_img(idx )._buf <> NIL ) then
  begin
   AssignFile(fd ,file_ );
   rewrite   (fd ,1 );

   if IOResult <> 0 then
    exit;

   w:=rbuf_img(idx )._width;
   h:=rbuf_img(idx )._height;

   str(w ,c );

   s:='P6'#13 + c + ' ';

   str(h ,c );

   s:=s + c + #13'255'#13;

   blockwrite(fd ,s[1 ] ,length(s ) );

   agg_getmem(tmp_buf ,w * 3 );

   y:=0;

   while y < rbuf_img(idx )._height do
    begin
     if m_flip_y then
      src:=rbuf_img(idx ).row(h - 1 - y )
     else
      src:=rbuf_img(idx ).row(y );

     case m_format of
      pix_format_rgb555 : color_conv_rgb555_to_rgb24(tmp_buf ,src ,w );
      //pix_format_rgb565 : color_conv_rgb565_to_rgb24(tmp_buf ,src ,w );
      pix_format_bgr24  : color_conv_bgr24_to_rgb24 (tmp_buf ,src ,w );
      //pix_format_rgb24  : color_conv_rgb24_to_rgb24 (tmp_buf ,src ,w );
      //pix_format_rgba32 : color_conv_rgba32_to_rgb24(tmp_buf ,src ,w );
      //pix_format_argb32 : color_conv_argb32_to_rgb24(tmp_buf ,src ,w );
      pix_format_bgra32 : color_conv_bgra32_to_rgb24(tmp_buf ,src ,w );
      //pix_format_abgr32 : color_conv_abgr32_to_rgb24(tmp_buf ,src ,w );

     end;

     blockwrite(fd ,tmp_buf^ ,w * 3 );
     inc       (y );

    end;

   agg_getmem(tmp_buf ,w * 3 );
   close     (fd );

   result:=true;

  end;

end;

{ CREATE_IMG }
function platform_support.create_img;
begin
 result:=false;

 if idx < max_images then
  begin
   if width_ = 0 then
    width_:=trunc(rbuf_window._width );

   if height_ = 0 then
    height_:=trunc(rbuf_window._height );

   agg_freemem(m_specific.m_buf_img[idx ] ,m_specific.m_img_alloc[idx ] );

   m_specific.m_img_alloc[idx ]:=width_ * height_ * (m_bpp div 8 );

   agg_getmem(m_specific.m_buf_img[idx ] ,m_specific.m_img_alloc[idx ] );

   if m_flip_y then
    m_rbuf_img[idx ].attach(
     m_specific.m_buf_img[idx ] ,
     width_ ,height_ ,
     -width_ * (m_bpp div 8 ) )
   else
    m_rbuf_img[idx ].attach(
     m_specific.m_buf_img[idx ] ,
     width_ ,height_ ,
     width_ * (m_bpp div 8 ) );

   result:=true;

  end;

end;

{ INIT }
function platform_support.init;
const
 xevent_mask =
  PointerMotionMask or
  ButtonPressMask or
  ButtonReleaseMask or
  ExposureMask or
  KeyPressMask or
  StructureNotifyMask;

var
 r_mask ,g_mask ,b_mask ,window_mask : unsigned;

 t ,hw_byte_order : int;

 hints : PXSizeHints;

begin
 m_window_flags:=flags;

 m_specific.m_display:=XOpenDisplay(NIL );

 if m_specific.m_display = NIL then 
  begin
   writeln(stderr ,'Unable to open DISPLAY!' );

   result:=false;

   exit;

  end;

 m_specific.m_screen:=XDefaultScreen(m_specific.m_display );
 m_specific.m_depth :=XDefaultDepth (m_specific.m_display ,m_specific.m_screen );
 m_specific.m_visual:=XDefaultVisual(m_specific.m_display ,m_specific.m_screen );

 r_mask:=m_specific.m_visual.red_mask;
 g_mask:=m_specific.m_visual.green_mask;
 b_mask:=m_specific.m_visual.blue_mask;

 if (m_specific.m_depth < 15 ) or
    (r_mask = 0 ) or
    (g_mask = 0 ) or
    (b_mask = 0 ) then
  begin
   writeln(stderr ,'There''s no Visual compatible with minimal AGG requirements:' );
   writeln(stderr ,'At least 15-bit color depth and True- or DirectColor class.' );
   writeln(stderr );

   XCloseDisplay(m_specific.m_display );

   result:=false;

   exit;

  end;

 t:=1;

 hw_byte_order:=LSBFirst;

 if byte(pointer(@t )^ ) = 0 then
  hw_byte_order:=MSBFirst;

// Perceive SYS-format by mask
 case m_specific.m_depth of
  15 :
   begin
    m_specific.m_sys_bpp:=16;

    if (r_mask = $7C00 ) and
       (g_mask = $3E0 ) and
       (b_mask = $1F ) then
     begin
      m_specific.m_sys_format:=pix_format_rgb555;
      m_specific.m_byte_order:=hw_byte_order;

     end;

   end;

  16 :
   begin
    m_specific.m_sys_bpp:=16;

    if (r_mask = $F800 ) and
       (g_mask = $7E0 ) and
       (b_mask = $1F ) then
     begin
      m_specific.m_sys_format:=pix_format_rgb565;
      m_specific.m_byte_order:=hw_byte_order;

     end;

   end;

  24 ,32 :
   begin
    m_specific.m_sys_bpp:=32;

    if g_mask = $FF00 then
     begin
      if (r_mask = $FF ) and
         (b_mask = $FF0000 ) then
       case m_specific.m_format of
        pix_format_rgba32 :
         begin
          m_specific.m_sys_format:=pix_format_rgba32;
          m_specific.m_byte_order:=LSBFirst;

         end;

        pix_format_abgr32 :
         begin
          m_specific.m_sys_format:=pix_format_abgr32;
          m_specific.m_byte_order:=MSBFirst;

         end;

        else
         begin
          m_specific.m_byte_order:=hw_byte_order;

          if hw_byte_order = LSBFirst then
           m_specific.m_sys_format:=pix_format_rgba32
          else
           m_specific.m_sys_format:=pix_format_abgr32;

         end;

       end;

      if (r_mask = $FF0000 ) and
         (b_mask = $FF ) then
       case m_specific.m_format of
        pix_format_argb32 :
         begin
          m_specific.m_sys_format:=pix_format_argb32;
          m_specific.m_byte_order:=MSBFirst;

         end;

        pix_format_bgra32 :
         begin
          m_specific.m_sys_format:=pix_format_bgra32;
          m_specific.m_byte_order:=LSBFirst;

         end;

        else
         begin
          m_specific.m_byte_order:=hw_byte_order;

          if hw_byte_order = MSBFirst then
           m_specific.m_sys_format:=pix_format_argb32
          else
           m_specific.m_sys_format:=pix_format_bgra32;

         end;

       end;

     end;

   end;

 end;

 if m_specific.m_sys_format = pix_format_undefined then
  begin 
   writeln(stderr ,'RGB masks are not compatible with AGG pixel formats:' );
   write  (stderr ,'R=' ,r_mask ,'G=' ,g_mask ,'B=' ,b_mask );

   XCloseDisplay(m_specific.m_display );

   result:=false;

   exit;

  end;

 fillchar(
  m_specific.m_window_attributes ,
  sizeof(m_specific.m_window_attributes ) ,0 );

 m_specific.m_window_attributes.border_pixel:=
  XBlackPixel(m_specific.m_display ,m_specific.m_screen );

 m_specific.m_window_attributes.background_pixel:=
  XWhitePixel(m_specific.m_display ,m_specific.m_screen );

 m_specific.m_window_attributes.override_redirect:=xfalse;

 window_mask:=CWBackPixel or CWBorderPixel;

 m_specific.m_window:=
  XCreateWindow(
   m_specific.m_display ,
   XDefaultRootWindow(m_specific.m_display ) ,
   0 ,0 ,
   width_ ,height_ ,
   0 ,
   m_specific.m_depth ,
   InputOutput ,
   CopyFromParent ,
   window_mask ,
   @m_specific.m_window_attributes );

 m_specific.m_gc:=XCreateGC(m_specific.m_display ,m_specific.m_window ,0 ,0 ); 

 m_specific.m_buf_alloc:=width_ * height_ * (m_bpp div 8 );

 agg_getmem(m_specific.m_buf_window ,m_specific.m_buf_alloc );
 fillchar  (m_specific.m_buf_window^ ,m_specific.m_buf_alloc ,255 );

 if m_flip_y then
  m_rbuf_window.attach(
   m_specific.m_buf_window ,
   width_ ,height_ ,
   -width_ * (m_bpp div 8 ) )
 else
  m_rbuf_window.attach(
   m_specific.m_buf_window ,
   width_ ,height_ ,
   width_ * (m_bpp div 8 ) );

 m_specific.m_ximg_window:=
  XCreateImage(
   m_specific.m_display ,
   m_specific.m_visual , //CopyFromParent, 
   m_specific.m_depth ,
   ZPixmap ,
   0 ,
   m_specific.m_buf_window ,
   width_ ,height_ ,
   m_specific.m_sys_bpp ,
   width_ * (m_specific.m_sys_bpp div 8 ) );

 m_specific.m_ximg_window.byte_order:=m_specific.m_byte_order;

 m_specific.caption_(PChar(@m_caption[1 ] ) ); 

 m_initial_width :=width_;
 m_initial_height:=height_;

 if not m_specific.m_initialized then
  begin
   on_init;

   m_specific.m_initialized:=true;

  end;

 trans_affine_resizing_(width_ ,height_ );

 on_resize(width_ ,height_ );

 m_specific.m_update_flag:=true;

 hints:=XAllocSizeHints;

 if hints <> NIL then
  begin
   if flags and window_resize <> 0 then
    begin
     hints.min_width :=32;
     hints.min_height:=32;
     hints.max_width :=4096;
     hints.max_height:=4096;

    end
   else
    begin
     hints.min_width :=width_;
     hints.min_height:=height_;
     hints.max_width :=width_;
     hints.max_height:=height_;

    end;

   hints.flags:=PMaxSize or PMinSize;

   XSetWMNormalHints(m_specific.m_display ,m_specific.m_window ,hints );
   XFree            (hints );

  end;

 XMapWindow  (m_specific.m_display ,m_specific.m_window );
 XSelectInput(m_specific.m_display ,m_specific.m_window ,xevent_mask );

 m_specific.m_close_atom:=
  XInternAtom(m_specific.m_display ,'WM_DELETE_WINDOW' ,false );

 XSetWMProtocols(
  m_specific.m_display ,
  m_specific.m_window ,
  @m_specific.m_close_atom ,1 );

 result:=true;

end;

{ RUN }
function platform_support.run;
var
 flags ,i : unsigned;

 cur_x ,cur_y ,width ,height : int;

 x_event ,te : TXEvent;

 key : TKeySym;

 left ,up ,right ,down : boolean;

begin
 XFlush(m_specific.m_display );

 m_quit:=false;

 while not m_quit do
  begin
   if m_specific.m_update_flag then
    begin
     on_draw;
     update_window;

     m_specific.m_update_flag:=false;

    end;

   if not m_wait_mode then
    if XPending(m_specific.m_display ) = 0 then
     begin
      on_idle;
      continue;

     end;

   XNextEvent(m_specific.m_display ,@x_event );

  // In the Idle mode discard all intermediate MotionNotify events
   if not m_wait_mode and
      (x_event._type = MotionNotify ) then
    begin
     te:=x_event;

     repeat
      if XPending(m_specific.m_display ) = 0 then
       break;

      XNextEvent(m_specific.m_display ,@te );

      if te._type <> MotionNotify then
       break;

     until false;

     x_event:=te;

    end;

   case x_event._type of
    ConfigureNotify :
     if (x_event.xconfigure.width <> trunc(m_rbuf_window._width ) ) or
        (x_event.xconfigure.height <> trunc(m_rbuf_window._height ) ) then
      begin
       width :=x_event.xconfigure.width;
       height:=x_event.xconfigure.height;

       agg_freemem(m_specific.m_buf_window ,m_specific.m_buf_alloc );

       m_specific.m_ximg_window.data:=0;

       XDestroyImage(m_specific.m_ximg_window );

       m_specific.m_buf_alloc:=width * height * (m_bpp div 8 );

       agg_getmem(m_specific.m_buf_window ,m_specific.m_buf_alloc );

       if m_flip_y then
        m_rbuf_window.attach(
         m_specific.m_buf_window ,
         width ,height ,
         -width * (m_bpp div 8 ) )
       else
        m_rbuf_window.attach(
         m_specific.m_buf_window ,
         width ,height ,
         width * (m_bpp div 8 ) );

       m_specific.m_ximg_window:=
        XCreateImage(m_specific.m_display ,
        m_specific.m_visual , //CopyFromParent, 
        m_specific.m_depth ,
        ZPixmap ,
        0 ,
        m_specific.m_buf_window ,
        width ,height ,
        m_specific.m_sys_bpp ,
        width * (m_specific.m_sys_bpp div 8 ) );

       m_specific.m_ximg_window.byte_order:=m_specific.m_byte_order;

       trans_affine_resizing_(width ,height );

       on_resize(width ,height );
       on_draw;
       update_window;

      end;

    Expose :
     begin
      m_specific.put_image(@m_rbuf_window );

      XFlush(m_specific.m_display );
      XSync (m_specific.m_display ,false );

     end;

    KeyPress :
     begin
      key  :=XLookupKeysym(@x_event.xkey ,0 );
      flags:=0;

      if x_event.xkey.state and Button1Mask <> 0 then
       flags:=flags or mouse_left;

      if x_event.xkey.state and Button3Mask <> 0 then
       flags:=flags or mouse_right;

      if x_event.xkey.state and ShiftMask <> 0 then
       flags:=flags or kbd_shift;

      if x_event.xkey.state and ControlMask <> 0 then
       flags:=flags or kbd_ctrl;

      left :=false;
      up   :=false;
      right:=false;
      down :=false;

      case m_specific.m_keymap[key and $FF ] of
       key_left  : left :=true;
       key_up    : up   :=true;
       key_right : right:=true;
       key_down  : down :=true;

       key_f2 :
        begin
         copy_window_to_img(max_images - 1 );
         save_img          (max_images - 1 ,'screenshot.ppm' );

        end;

      end;

      if m_ctrls.on_arrow_keys(left ,right ,down ,up ) then
       begin
        on_ctrl_change;
        force_redraw;

       end
      else
       if m_flip_y then
        on_key(
         x_event.xkey.x ,
         trunc(m_rbuf_window._height ) - x_event.xkey.y ,
         m_specific.m_keymap[key and $FF ] ,flags )
       else
        on_key(
         x_event.xkey.x ,
         x_event.xkey.y ,
         m_specific.m_keymap[key and $FF ] ,flags )

     end;

    ButtonPress :
     begin
      flags:=0;

      if x_event.xbutton.state and ShiftMask <> 0 then
       flags:=flags or kbd_shift;

      if x_event.xbutton.state and ControlMask <> 0 then
       flags:=flags or kbd_ctrl;

      if x_event.xbutton.button = Button1 then
       flags:=flags or mouse_left;

      if x_event.xbutton.button = Button3 then
       flags:=flags or mouse_right;

      cur_x:=x_event.xbutton.x;

      if m_flip_y then
       cur_y:=trunc(m_rbuf_window._height ) - x_event.xbutton.y 
      else
       cur_y:=x_event.xbutton.y;

      if flags and mouse_left <> 0 then
       if m_ctrls.on_mouse_button_down(cur_x ,cur_y ) then
        begin
         m_ctrls.set_cur(cur_x ,cur_y );
         on_ctrl_change;
         force_redraw;

        end
       else
        if m_ctrls.in_rect(cur_x ,cur_y ) then
         if m_ctrls.set_cur(cur_x ,cur_y ) then
          begin
           on_ctrl_change;
           force_redraw;

          end
         else
        else
         on_mouse_button_down(cur_x ,cur_y ,flags );

      if flags and mouse_right <> 0 then
       on_mouse_button_down(cur_x ,cur_y ,flags );

      //m_specific.m_wait_mode:=m_wait_mode;
      //m_wait_mode           :=true;

     end;

    MotionNotify :
     begin
      flags:=0;

      if x_event.xmotion.state and Button1Mask <> 0 then
       flags:=flags or mouse_left;

      if x_event.xmotion.state and Button3Mask <> 0 then
       flags:=flags or mouse_right;

      if x_event.xmotion.state and ShiftMask <> 0 then
       flags:=flags or kbd_shift;

      if x_event.xmotion.state and ControlMask <> 0 then
       flags:=flags or kbd_ctrl;

      cur_x:=x_event.xbutton.x;

      if m_flip_y then
       cur_y:=trunc(m_rbuf_window._height ) - x_event.xbutton.y
      else
       cur_y:=x_event.xbutton.y;

      if m_ctrls.on_mouse_move(cur_x ,cur_y ,flags and mouse_left <> 0 ) then
       begin
        on_ctrl_change;
        force_redraw;

       end
      else
       if not m_ctrls.in_rect(cur_x ,cur_y ) then
        on_mouse_move(cur_x ,cur_y ,flags );

     end;

    ButtonRelease :
     begin
      flags:=0;

      if x_event.xbutton.state and ShiftMask <> 0 then
       flags:=flags or kbd_shift;

      if x_event.xbutton.state and ControlMask <> 0 then
       flags:=flags or kbd_ctrl;

      if x_event.xbutton.button = Button1 then
       flags:=flags or mouse_left;

      if x_event.xbutton.button = Button3 then
       flags:=flags or mouse_right;

      cur_x:=x_event.xbutton.x;

      if m_flip_y then
       cur_y:=trunc(m_rbuf_window._height ) - x_event.xbutton.y
      else
       cur_y:=x_event.xbutton.y;

      if flags and mouse_left <> 0 then
       if m_ctrls.on_mouse_button_up(cur_x ,cur_y ) then
        begin
         on_ctrl_change;
         force_redraw;

        end;

      if flags and (mouse_left or mouse_right ) <> 0 then
       on_mouse_button_up(cur_x ,cur_y ,flags );

      //m_wait_mode:=m_specific.m_wait_mode;

     end;

    ClientMessage :
     if (x_event.xclient.format = 32 ) and
        (x_event.xclient.data.l[0 ] = int(m_specific.m_close_atom ) ) then
      m_quit:=true;

   end;

  end;

 i:=max_images;

 while i <> 0 do
  begin
   dec(i );

   if m_specific.m_buf_img[i ] <> NIL then
    agg_freemem(m_specific.m_buf_img[i ] ,m_specific.m_img_alloc[i ] );

  end;

 agg_freemem(m_specific.m_buf_window ,m_specific.m_buf_alloc );

 m_specific.m_ximg_window.data:=NIL;

 XDestroyImage (m_specific.m_ximg_window );
 XFreeGC       (m_specific.m_display ,m_specific.m_gc );
 XDestroyWindow(m_specific.m_display ,m_specific.m_window );
 XCloseDisplay (m_specific.m_display );

 result:=0;

end;

{ QUIT }
procedure platform_support.quit;
begin
 m_quit:=true;

end;

{ _FORMAT }
function platform_support._format;
begin
 result:=m_format;

end;

{ _FLIP_Y }
function platform_support._flip_y;
begin
 result:=m_flip_y;

end;

{ _BPP }
function platform_support._bpp;
begin
 result:=m_bpp;

end;

{ _WAIT_MODE }
function platform_support._wait_mode;
begin
 result:=m_wait_mode;

end;

{ WAIT_MODE_ }
procedure platform_support.wait_mode_;
begin
 m_wait_mode:=wait_mode;

end;

{ FORCE_REDRAW }
procedure platform_support.force_redraw;
begin
 m_specific.m_update_flag:=true;

end;

{ UPDATE_WINDOW }
procedure platform_support.update_window;
begin
 m_specific.put_image(@m_rbuf_window );

// When m_wait_mode is true we can discard all the events 
// came while the image is being drawn. In this case 
// the X server does not accumulate mouse motion events.
// When m_wait_mode is false, i.e. we have some idle drawing
// we cannot afford to miss any events
 XSync(m_specific.m_display ,m_wait_mode );

end;

{ RBUF_WINDOW }
function platform_support.rbuf_window;
begin
 result:=@m_rbuf_window;

end;

{ RBUF_IMG }
function platform_support.rbuf_img;
begin
 result:=@m_rbuf_img[idx ];

end;

{ _IMG_EXT }
function platform_support._img_ext;
begin
 result:='.ppm';

end;

{ COPY_IMG_TO_WINDOW }
procedure platform_support.copy_img_to_window;
begin
 if (idx < max_images ) and
    (rbuf_img(idx )._buf <> NIL ) then
  rbuf_window.copy_from(rbuf_img(idx ) );

end;

{ COPY_WINDOW_TO_IMG }
procedure platform_support.copy_window_to_img;
begin
 if idx < max_images then
  begin
   create_img(idx ,rbuf_window._width ,rbuf_window._height );
   rbuf_img  (idx ).copy_from(rbuf_window );

  end;

end;

{ COPY_IMG_TO_IMG }
procedure platform_support.copy_img_to_img;
begin
 if (idx_from < max_images ) and
    (idx_to < max_images ) and
    (rbuf_img(idx_from )._buf <> NIL ) then
  begin
   create_img(
    idx_to ,
    rbuf_img(idx_from )._width ,
    rbuf_img(idx_from )._height );

   rbuf_img(idx_to ).copy_from(rbuf_img(idx_from ) );

  end;

end;

{ ON_INIT }
procedure platform_support.on_init;
begin
end;

{ ON_RESIZE }
procedure platform_support.on_resize;
begin
end;

{ ON_IDLE }
procedure platform_support.on_idle;
begin
end;

{ ON_MOUSE_MOVE }
procedure platform_support.on_mouse_move;
begin
end;

{ ON_MOUSE_BUTTON_DOWN }
procedure platform_support.on_mouse_button_down;
begin
end;

{ ON_MOUSE_BUTTON_UP }
procedure platform_support.on_mouse_button_up;
begin
end;

{ ON_KEY }
procedure platform_support.on_key;
begin
end;

{ ON_CTRL_CHANGE }
procedure platform_support.on_ctrl_change;
begin
end;

{ ON_DRAW }
procedure platform_support.on_draw;
begin
end;

{ ON_POST_DRAW }
procedure platform_support.on_post_draw;
begin
end;

{ ADD_CTRL }
procedure platform_support.add_ctrl;
begin
 m_ctrls.add(c );

 c.transform(@m_resize_mtx );

end;

{ TRANS_AFFINE_RESIZING_ }
procedure platform_support.trans_affine_resizing_;
var
 vp : trans_viewport;
 ts : trans_affine_scaling;

begin
 if m_window_flags and window_keep_aspect_ratio <> 0 then
  begin
   vp.Construct;
   vp.preserve_aspect_ratio(0.5 ,0.5 ,aspect_ratio_meet );

   vp.device_viewport(0 ,0 ,width_ ,height_ );
   vp.world_viewport (0 ,0 ,m_initial_width ,m_initial_height );

   vp.to_affine(@m_resize_mtx );

  end
 else
  begin
   ts.Construct(
    width_ / m_initial_width ,
    height_ / m_initial_height );

   m_resize_mtx.assign(@ts );

  end;

end;

{ _TRANS_AFFINE_RESIZING }
function platform_support._trans_affine_resizing;
begin
 result:=@m_resize_mtx;

end;

{ _WIDTH }
function platform_support._width;
begin
 result:=m_rbuf_window._width;

end;

{ _HEIGHT }
function platform_support._height;
begin
 result:=m_rbuf_window._height;

end;

{ _INITIAL_WIDTH }
function platform_support._initial_width;
begin
 result:=m_initial_width;

end;

{ _INITIAL_HEIGHT }
function platform_support._initial_height;
begin
 result:=m_initial_height;

end;

{ _WINDOW_FLAGS }
function platform_support._window_flags;
begin
 result:=m_window_flags;

end;

{ _RAW_DISPLAY_HANDLER }
function platform_support._raw_display_handler;
begin
end;

{ MESSAGE_ }
procedure platform_support.message_;
const
 x_event_mask =
  ExposureMask or
  KeyPressMask;

 capt = '  PRESS ANY KEY TO CONTINUE THE AGGPAS DEMO ...';
 plus = 4;

var
 x_display : PDisplay;
 x_window  : TWindow;
 x_event   : TXEvent;
 x_close   : TAtom;
 x_changes : TXWindowChanges;
 x_hints   : PXSizeHints;

 x_gc : TGC;
 x_tp : TXTextProperty;
 x_tx : TXTextItem;

 str ,cur : char_ptr;

 y ,len ,cnt ,max ,x_dx ,x_dy : unsigned;

 font_dir ,font_ascent ,font_descent : int;

 font_str : TXCharStruct;

procedure draw_text;
begin
 x_dx:=0;
 x_dy:=0;

 y  :=20;
 cur:=PChar(@msg[0 ] );
 max:=strlen(msg );
 len:=0;
 cnt:=0;

 while cnt < max do
  begin
   if len = 0 then
    str:=cur;

   case cur^ of
    #13 :
     begin
      XDrawString      (x_display ,x_window ,x_gc ,10 ,y ,str ,len );
      XQueryTextExtents(
       x_display ,XGContextFromGC(x_gc) ,
       str ,len ,
       @font_dir ,
       @font_ascent ,
       @font_descent ,
       @font_str );

      inc(y ,font_str.ascent + font_str.descent + plus );
      inc(x_dy ,font_str.ascent + font_str.descent + plus );

      if font_str.width > x_dx then
       x_dx:=font_str.width;

      len:=0;

     end;

    else
     inc(len );

   end;

   inc(ptrcomp(cur ) );
   inc(cnt );

  end;

 if len > 0 then
  begin
   XDrawString      (x_display ,x_window ,x_gc ,10 ,y ,str ,len );
   XQueryTextExtents(
    x_display ,XGContextFromGC(x_gc) ,
    str ,len ,
    @font_dir ,
    @font_ascent ,
    @font_descent ,
    @font_str );

   inc(x_dy ,font_str.ascent + font_str.descent + plus );

   if font_str.width > x_dx then
    x_dx:=font_str.width;

  end;

end;

begin
 x_display:=XOpenDisplay(NIL );

 if x_display <> NIL then
  begin
   x_window :=
    XCreateSimpleWindow(
     x_display ,
     XDefaultRootWindow(x_display ) ,
     50 ,50 ,
     550 ,300 ,
     0 ,0 ,
     255 + (255 shl 8 ) + (255 shl 16 ) );

   x_gc:=XCreateGC(x_display ,x_window ,0 ,0 ); 

   draw_text;
   XResizeWindow(x_display ,x_window ,x_dx + 20 ,x_dy + 40 );

   x_hints:=XAllocSizeHints;

   if x_hints <> NIL then
    begin
     x_hints.min_width :=x_dx + 20;
     x_hints.min_height:=x_dy + 40;
     x_hints.max_width :=x_dx + 20;
     x_hints.max_height:=x_dy + 40;

     x_hints.flags:=PMaxSize or PMinSize;

     XSetWMNormalHints(x_display ,x_window ,x_hints );
     XFree            (x_hints );

    end;

   x_tp.value   :=PCUChar(@capt[1 ] );
   x_tp.encoding:=XA_WM_NAME;
   x_tp.format  :=8;
   x_tp.nitems  :=strlen(capt );

   XSetWMName    (x_display ,x_window ,@x_tp );
   XStoreName    (x_display ,x_window ,capt );
   XSetIconName  (x_display ,x_window ,capt );
   XSetWMIconName(x_display ,x_window ,@x_tp );

   XMapWindow  (x_display ,x_window );
   XSelectInput(x_display ,x_window ,x_event_mask );

   x_close:=
    XInternAtom(x_display ,'WM_DELETE_WINDOW' ,false );

   XSetWMProtocols(
    x_display ,
    x_window ,
    @x_close ,1 );

   XFlush(x_display );

   repeat
    XNextEvent(x_display ,@x_event );

    XFlush(x_display );
    XSync (x_display ,true );

    case x_event._type of
     Expose :
      draw_text;

     KeyPress :
      break;

     ClientMessage :
      if (x_event.xclient.format = 32 ) and
         (x_event.xclient.data.l[0 ] = int(x_close ) ) then
       break;

    end;


   until false;

   while XPending(x_display ) > 0 do
    begin
     XNextEvent(x_display ,@x_event );

     XFlush(x_display );
     XSync (x_display ,true );

    end;

   XFreeGC       (x_display ,x_gc );
   XDestroyWindow(x_display ,x_window );
   XCloseDisplay (x_display );

  end
 else
  writeln(stderr ,msg );

end;

{ START_TIMER }
procedure platform_support.start_timer;
begin
 m_specific.m_sw_start:=clock;

end;

{ ELAPSED_TIME }
function platform_support.elapsed_time;
var
 stop : clock_t;

begin
 stop:=clock;

 result:=(stop - m_specific.m_sw_start ) * 1000.0 / CLOCKS_PER_SEC;

end;

{ FULL_FILE_NAME }
function platform_support.full_file_name;
begin
 result:=file_name;

end;

{ FILE_SOURCE }
function platform_support.file_source;
var
 f : file;
 e : integer;

begin
 result:=fname;

 e:=ioresult;

 AssignFile(f ,result );
 reset     (f ,1 );

 if ioresult <> 0 then
  result:=path + '/' + fname;

 close(f );

 e:=ioresult;

end;

END.

