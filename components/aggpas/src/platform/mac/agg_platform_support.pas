//----------------------------------------------------------------------------
// Anti-Grain Geometry - Version 2.4 (Public License)
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Copyright (C) 2003 Hansruedi Baer (MacOS support)
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
//          baer@karto.baug.eth.ch
//
//----------------------------------------------------------------------------
//
// Note:
// I tried to retain the original structure for the Win32 platform as far
// as possible. Currently, not all features are implemented but the examples
// should work properly.
// HB
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
// 26.03.2006-Milano: Finished & tested MacOS X port
// 20.03.2006-Milano: Unit port establishment
//
{ agg_platform_support.pas }
unit
 agg_platform_support ;

INTERFACE

{$I agg_mode.inc }

uses
 Carbon ,
 agg_basics ,
 agg_ctrl ,
 agg_rendering_buffer ,
 agg_trans_affine ,
 agg_trans_viewport ,
 agg_mac_pmap ,
 agg_color_conv ;

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
// would have no overhead for pixel format conversion.
// But eventually I came to a conclusion that having a possibility to
// convert pixel formats on demand is a good idea. First, it was X11 where
// there are lots of different formats and visuals and it would be great to
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

   m_flip_y  : boolean;
   m_bpp     ,
   m_sys_bpp : unsigned;
   m_window  : WindowRef;

   m_pmap_window : pixel_map;
   m_pmap_img    : array[0..max_images - 1 ] of pixel_map;

   m_keymap : array[0..255 ] of unsigned;

   m_last_translated_key : unsigned;

   m_cur_x ,
   m_cur_y : int;

   m_input_flags : unsigned;
   m_redraw_flag : boolean;

   m_sw_freq  ,
   m_sw_start : UnsignedWide;

   constructor Construct(format : pix_format_e; flip_y : boolean );
   destructor  Destruct;

   procedure create_pmap (width ,height : unsigned; wnd : rendering_buffer_ptr );
   procedure display_pmap(window : WindowRef; src : rendering_buffer_ptr );

   function  load_pmap(fn : shortstring; idx : unsigned; dst : rendering_buffer_ptr ) : boolean;
   function  save_pmap(fn : shortstring; idx : unsigned; src : rendering_buffer_ptr ) : boolean;

   function  translate(keycode : unsigned ) : unsigned;

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
 m_pmap_window.Construct;

 for i:=0 to max_images - 1 do
  m_pmap_img[i ].Construct;

 m_format    :=format;
 m_sys_format:=pix_format_undefined;

 m_flip_y :=flip_y;
 m_bpp    :=0;
 m_sys_bpp:=0;
 m_window :=NIL;

 m_last_translated_key:=0;

 m_cur_x:=0;
 m_cur_y:=0;

 m_input_flags:=0;
 m_redraw_flag:=true;

 fillchar(m_keymap[0 ] ,sizeof(m_keymap ) ,0 );

//Keyboard input is not yet fully supported nor tested
 //m_keymap[VK_PAUSE ]:=key_pause;
 m_keymap[kClearCharCode ]:=key_clear;

 //m_keymap[VK_NUMPAD0 ] :=key_kp0;
 //m_keymap[VK_NUMPAD1 ] :=key_kp1;
 //m_keymap[VK_NUMPAD2 ] :=key_kp2;
 //m_keymap[VK_NUMPAD3 ] :=key_kp3;
 //m_keymap[VK_NUMPAD4 ] :=key_kp4;
 //m_keymap[VK_NUMPAD5 ] :=key_kp5;
 //m_keymap[VK_NUMPAD6 ] :=key_kp6;
 //m_keymap[VK_NUMPAD7 ] :=key_kp7;
 //m_keymap[VK_NUMPAD8 ] :=key_kp8;
 //m_keymap[VK_NUMPAD9 ] :=key_kp9;
 //m_keymap[VK_DECIMAL ] :=key_kp_period;
 //m_keymap[VK_DIVIDE ]  :=key_kp_divide;
 //m_keymap[VK_MULTIPLY ]:=key_kp_multiply;
 //m_keymap[VK_SUBTRACT ]:=key_kp_minus;
 //m_keymap[VK_ADD ]     :=key_kp_plus;

 m_keymap[kUpArrowCharCode ]    :=key_up;
 m_keymap[kDownArrowCharCode ]  :=key_down;
 m_keymap[kRightArrowCharCode ] :=key_right;
 m_keymap[kLeftArrowCharCode ]  :=key_left;
 //m_keymap[VK_INSERT ]:=key_insert;
 m_keymap[kDeleteCharCode ]     :=key_delete;
 m_keymap[kHomeCharCode ]       :=key_home;
 m_keymap[kEndCharCode ]        :=key_end;
 m_keymap[kPageUpCharCode ]     :=key_page_up;
 m_keymap[kPageDownCharCode ]   :=key_page_down;

 //m_keymap[VK_F1 ] :=key_f1;
 //m_keymap[VK_F2 ] :=key_f2;
 //m_keymap[VK_F3 ] :=key_f3;
 //m_keymap[VK_F4 ] :=key_f4;
 //m_keymap[VK_F5 ] :=key_f5;
 //m_keymap[VK_F6 ] :=key_f6;
 //m_keymap[VK_F7 ] :=key_f7;
 //m_keymap[VK_F8 ] :=key_f8;
 //m_keymap[VK_F9 ] :=key_f9;
 //m_keymap[VK_F10 ]:=key_f10;
 //m_keymap[VK_F11 ]:=key_f11;
 //m_keymap[VK_F12 ]:=key_f12;
 //m_keymap[VK_F13 ]:=key_f13;
 //m_keymap[VK_F14 ]:=key_f14;
 //m_keymap[VK_F15 ]:=key_f15;

 //m_keymap[VK_NUMLOCK ]:=key_numlock;
 //m_keymap[VK_CAPITAL ]:=key_capslock;
 //m_keymap[VK_SCROLL ] :=key_scrollock;

 case m_format of
  pix_format_gray8 :
   begin
    m_sys_format:=pix_format_rgb24;
    m_bpp       :=8;
    m_sys_bpp   :=24;

   end;

  pix_format_rgb565 ,
  pix_format_rgb555 :
   begin
    m_sys_format:=pix_format_rgb555;
    m_bpp       :=16;
    m_sys_bpp   :=16;

   end;

  pix_format_rgb24 ,
  pix_format_bgr24 :
   begin
    m_sys_format:=pix_format_rgb24;
    m_bpp       :=24;
    m_sys_bpp   :=24;

   end;

  pix_format_bgra32 ,
  pix_format_abgr32 ,
  pix_format_argb32 ,
  pix_format_rgba32 :
   begin
    m_sys_format:=pix_format_argb32;
    m_bpp       :=32;
    m_sys_bpp   :=32;

   end;

 end;

 Microseconds(m_sw_freq );
 Microseconds(m_sw_start );

end;

{ DESTRUCT }
destructor platform_specific.Destruct;
var
 i : unsigned;

begin
 m_pmap_window.Destruct;

 for i:=0 to max_images - 1 do
  m_pmap_img[i ].Destruct;

end;

{ CREATE_PMAP }
procedure platform_specific.create_pmap;
begin
 m_pmap_window.create(width ,height ,m_bpp );

 if m_flip_y then
  wnd.attach(
   m_pmap_window._buf ,
   m_pmap_window._width ,
   m_pmap_window._height ,
   -m_pmap_window._row_bytes )

 else
  wnd.attach(
   m_pmap_window._buf ,
   m_pmap_window._width ,
   m_pmap_window._height ,
   m_pmap_window._row_bytes )

end;

{ convert_pmap }
procedure convert_pmap(dst ,src : rendering_buffer_ptr; format : pix_format_e );
begin
 case format of
  pix_format_gray8 :
   color_conv(dst ,src ,color_conv_gray8_to_rgb24 );
   
  pix_format_rgb565 :
   color_conv(dst ,src ,color_conv_rgb565_to_rgb555 );

  pix_format_bgr24 :
   color_conv(dst ,src ,color_conv_bgr24_to_rgb24 );

  pix_format_abgr32 :
   color_conv(dst ,src ,color_conv_abgr32_to_argb32 );

  pix_format_bgra32 :
   color_conv(dst ,src ,color_conv_bgra32_to_argb32 );

  pix_format_rgba32 :
   color_conv(dst ,src ,color_conv_rgba32_to_argb32 );

 end;

end;

{ DISPLAY_PMAP }
procedure platform_specific.display_pmap;
var
 pmap_tmp : pixel_map;
 rbuf_tmp : rendering_buffer;

begin
 if m_sys_format = m_format then
  m_pmap_window.draw(window )
  
 else
  begin
   pmap_tmp.Construct;
   pmap_tmp.create(m_pmap_window._width ,m_pmap_window._height ,m_sys_bpp );

   rbuf_tmp.Construct;

   if m_flip_y then
    rbuf_tmp.attach(pmap_tmp._buf ,pmap_tmp._width ,pmap_tmp._height ,-pmap_tmp._row_bytes )
   else
    rbuf_tmp.attach(pmap_tmp._buf ,pmap_tmp._width ,pmap_tmp._height ,pmap_tmp._row_bytes );

   convert_pmap (@rbuf_tmp ,src ,m_format );
   pmap_tmp.draw(window );

   rbuf_tmp.Destruct;
   pmap_tmp.Destruct;

  end;

end;

{ LOAD_PMAP }
function platform_specific.load_pmap;
var
 pmap_tmp : pixel_map;
 rbuf_tmp : rendering_buffer;

begin
 pmap_tmp.Construct;

 if not pmap_tmp.load_from_qt(fn ) then
  begin
   result:=false;

   pmap_tmp.Destruct;
   exit;

  end;

 rbuf_tmp.Construct;

 if m_flip_y then
  rbuf_tmp.attach(pmap_tmp._buf ,pmap_tmp._width ,pmap_tmp._height ,-pmap_tmp._row_bytes )
 else
  rbuf_tmp.attach(pmap_tmp._buf ,pmap_tmp._width ,pmap_tmp._height ,pmap_tmp._row_bytes );

 m_pmap_img[idx ].create(pmap_tmp._width ,pmap_tmp._height ,m_bpp ,0 );

 if m_flip_y then
  dst.attach(
   m_pmap_img[idx ]._buf ,
   m_pmap_img[idx ]._width ,
   m_pmap_img[idx ]._height ,
   -m_pmap_img[idx ]._row_bytes )
 else
  dst.attach(
   m_pmap_img[idx ]._buf ,
   m_pmap_img[idx ]._width ,
   m_pmap_img[idx ]._height ,
   m_pmap_img[idx ]._row_bytes );

 case m_format of
  pix_format_rgb555 :
   case pmap_tmp._bpp of
    16 : color_conv(dst ,@rbuf_tmp ,color_conv_rgb555_to_rgb555 );
    24 : color_conv(dst ,@rbuf_tmp ,color_conv_bgr24_to_rgb555 );
    32 : color_conv(dst ,@rbuf_tmp ,color_conv_bgra32_to_rgb555 );

   end;

  pix_format_rgb565 :
   case pmap_tmp._bpp of
    16 : color_conv(dst ,@rbuf_tmp ,color_conv_rgb555_to_rgb565 );
    24 : color_conv(dst ,@rbuf_tmp ,color_conv_bgr24_to_rgb565 );
    32 : color_conv(dst ,@rbuf_tmp ,color_conv_bgra32_to_rgb565 );

   end;

  pix_format_rgb24 :
   case pmap_tmp._bpp of
    16 : color_conv(dst ,@rbuf_tmp ,color_conv_rgb555_to_rgb24 );
    24 : color_conv(dst ,@rbuf_tmp ,color_conv_bgr24_to_rgb24 );
    32 : color_conv(dst ,@rbuf_tmp ,color_conv_bgra32_to_rgb24 );

   end;

  pix_format_bgr24 :
   case pmap_tmp._bpp of
    16 : color_conv(dst ,@rbuf_tmp ,color_conv_rgb555_to_bgr24 );
    24 : color_conv(dst ,@rbuf_tmp ,color_conv_bgr24_to_bgr24 );
    32 : color_conv(dst ,@rbuf_tmp ,color_conv_bgra32_to_bgr24 );

   end;

  pix_format_abgr32 :
   case pmap_tmp._bpp of
    16 : color_conv(dst ,@rbuf_tmp ,color_conv_rgb555_to_abgr32 );
    24 : color_conv(dst ,@rbuf_tmp ,color_conv_bgr24_to_abgr32 );
    32 : color_conv(dst ,@rbuf_tmp ,color_conv_bgra32_to_abgr32 );

   end;

  pix_format_argb32 :
   case pmap_tmp._bpp of
    16 : color_conv(dst ,@rbuf_tmp ,color_conv_rgb555_to_argb32 );
    24 : color_conv(dst ,@rbuf_tmp ,color_conv_bgr24_to_argb32 );
    32 : color_conv(dst ,@rbuf_tmp ,color_conv_bgra32_to_argb32 );

   end;

  pix_format_bgra32 :
   case pmap_tmp._bpp of
    16 : color_conv(dst ,@rbuf_tmp ,color_conv_rgb555_to_bgra32 );
    24 : color_conv(dst ,@rbuf_tmp ,color_conv_bgr24_to_bgra32 );
    32 : color_conv(dst ,@rbuf_tmp ,color_conv_bgra32_to_bgra32 );

   end;

  pix_format_rgba32 :
   case pmap_tmp._bpp of
    16 : color_conv(dst ,@rbuf_tmp ,color_conv_rgb555_to_rgba32 );
    24 : color_conv(dst ,@rbuf_tmp ,color_conv_bgr24_to_rgba32 );
    32 : color_conv(dst ,@rbuf_tmp ,color_conv_bgra32_to_rgba32 );

   end;

 end;

 pmap_tmp.Destruct;
 rbuf_tmp.Destruct;

 result:=true;

end;

{ SAVE_PMAP }
function platform_specific.save_pmap;
var
 pmap_tmp : pixel_map;
 rbuf_tmp : rendering_buffer;

begin
 if m_sys_format = m_format then
  begin
   result:=m_pmap_img[idx ].save_as_qt(fn );

   exit;

  end;

 pmap_tmp.Construct;
 pmap_tmp.create(
  m_pmap_img[idx ]._width ,
  m_pmap_img[idx ]._height ,
  m_sys_bpp );

 rbuf_tmp.Construct;

 if m_flip_y then
  rbuf_tmp.attach(pmap_tmp._buf ,pmap_tmp._width ,pmap_tmp._height ,-pmap_tmp._row_bytes )
 else
  rbuf_tmp.attach(pmap_tmp._buf ,pmap_tmp._width ,pmap_tmp._height ,pmap_tmp._row_bytes );

 convert_pmap(@rbuf_tmp ,src ,m_format );

 result:=pmap_tmp.save_as_qt(fn );

 rbuf_tmp.Destruct;
 pmap_tmp.Destruct;

end;

{ TRANSLATE }
function platform_specific.translate;
begin
 if keycode > 255 then
  m_last_translated_key:=0
 else
  m_last_translated_key:=m_keymap[keycode ];

end;

{ CONSTRUCT }
constructor platform_support.Construct;
var
 i : unsigned;

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

 if m_specific.m_window <> NIL then
  SetWindowTitleWithCFString(
   m_specific.m_window ,
   CFStringCreateWithPascalStringNoCopy(
    NIL ,cap ,kCFStringEncodingASCII ,NIL ) );

end;

{ LOAD_IMG }
function platform_support.load_img;
begin
 if idx < max_images then
  begin
   file_ :=file_ + _img_ext;
   result:=m_specific.load_pmap(file_ ,idx ,@m_rbuf_img[idx ] );

  end
 else
  result:=true;

end;

{ SAVE_IMG }
function platform_support.save_img;
begin
 if idx < max_images then
  result:=m_specific.save_pmap(file_ ,idx ,@m_rbuf_img[idx ] )
 else
  result:=true;

end;

{ CREATE_IMG }
function platform_support.create_img;
begin
 if idx < max_images then
  begin
   if width_ = 0 then
    width_:=m_specific.m_pmap_window._width;

   if height_ = 0 then
    height_:=m_specific.m_pmap_window._height;

   m_specific.m_pmap_img[idx ].create(width_ ,height_ ,m_specific.m_bpp );

   if m_flip_y then
    m_rbuf_img[idx ].attach(
     m_specific.m_pmap_img[idx ]._buf ,
     m_specific.m_pmap_img[idx ]._width ,
     m_specific.m_pmap_img[idx ]._height ,
     -m_specific.m_pmap_img[idx ]._row_bytes )
   else
    m_rbuf_img[idx ].attach(
     m_specific.m_pmap_img[idx ]._buf ,
     m_specific.m_pmap_img[idx ]._width ,
     m_specific.m_pmap_img[idx ]._height ,
     m_specific.m_pmap_img[idx ]._row_bytes );

   result:=true;

  end
 else
  result:=false;

end;

{ get_key_flags }
function get_key_flags(wflags : int ) : unsigned;
var
 flags : unsigned;

begin
 flags:=0;

 if wflags and shiftKey <> 0 then
  flags:=flags or kbd_shift;
  
 if wflags and controlKey <> 0 then
  flags:=flags or kbd_ctrl;

 result:=flags;

end;

{ DOWINDOWCLOSE }
function DoWindowClose(nextHandler : EventHandlerCallRef; theEvent : EventRef; userData : pointer ) : OSStatus;
begin
 QuitApplicationEventLoop;

 result:=CallNextEventHandler(nextHandler ,theEvent );

end;

{ DOWINDOWDRAWCONTENT }
function DoWindowDrawContent(nextHandler : EventHandlerCallRef; theEvent : EventRef; userData : pointer ) : OSStatus;
var
 app : platform_support_ptr;
 
begin
 app:=platform_support_ptr(userData );
 
 if app <> NIL then
  begin
   if app.m_specific.m_redraw_flag then
    begin
     app.on_draw;

     app.m_specific.m_redraw_flag:=false;

    end;

   app.m_specific.display_pmap(app.m_specific.m_window ,app.rbuf_window );
   
  end;

 result:=CallNextEventHandler(nextHandler ,theEvent );

end;

{ DOWINDOWRESIZE }
function DoWindowResize(nextHandler : EventHandlerCallRef; theEvent : EventRef; userData : pointer ) : OSStatus;
var
 app  : platform_support_ptr;
 Rect : Carbon.Rect;
 
 width ,height : unsigned;
 
begin
 app:=platform_support_ptr(userData );

 GetWindowBounds(app.m_specific.m_window ,kWindowContentRgn ,Rect );

 width :=Rect.Right - Rect.Left;
 height:=Rect.Bottom - Rect.Top;

 if (width <> app.rbuf_window._width ) or
    (height <> app.rbuf_window._height ) then
  begin
   app.m_specific.create_pmap(width ,height ,app.rbuf_window );
   app.trans_affine_resizing_(width ,height );

   app.on_resize(width ,height );
 
  end;
  
 app.force_redraw;
 
 result:=CallNextEventHandler(nextHandler ,theEvent );

end;

{ DOAPPQUIT }
function DoAppQuit(nextHandler : EventHandlerCallRef; theEvent : EventRef; userData : pointer ) : OSStatus;
begin
 result:=CallNextEventHandler(nextHandler ,theEvent );
 
end;

{ DOMOUSEDOWN }
function DoMouseDown(nextHandler : EventHandlerCallRef; theEvent : EventRef; userData : pointer ) : OSStatus;
var
 wheresMyMouse : Carbon.Point;
 
 modifier : UInt32;
 button   : EventMouseButton; 

 sz  : UInt32; 
 app : platform_support_ptr;
 ept : EventParamType;

begin
 ept:=0;

 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamMouseLocation[1 ] )^ ) ,
  LongWord(int32_ptr(@typeQDPoint[1 ] )^ ) ,
  ept ,
  sizeof(Carbon.Point ) ,
  sz ,
  @wheresMyMouse );

 GlobalToLocal(wheresMyMouse );
 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamKeyModifiers[1 ] )^ ) ,
  LongWord(int32_ptr(@typeUInt32[1 ] )^ ) ,
  ept ,
  sizeof(UInt32 ) ,
  sz ,
  @modifier );

 app:=platform_support_ptr(userData );
 
 app.m_specific.m_cur_x:=wheresMyMouse.h;
 
 if app._flip_y then
  app.m_specific.m_cur_y:=app.rbuf_window._height - wheresMyMouse.v
 else
  app.m_specific.m_cur_y:=wheresMyMouse.v;

 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamMouseButton[1 ] )^ ) ,
  LongWord(int32_ptr(@typeMouseButton[1 ] )^ ) ,
  ept ,
  sizeof(EventMouseButton ) ,
  sz ,
  @button );
  
 case button of
  kEventMouseButtonSecondary :
   app.m_specific.m_input_flags:=mouse_right or get_key_flags(modifier );
   
  else
   app.m_specific.m_input_flags:=mouse_left or get_key_flags(modifier );

 end;
    
 app.m_ctrls.set_cur(
  app.m_specific.m_cur_x , 
  app.m_specific.m_cur_y );
  
 if app.m_ctrls.on_mouse_button_down(
     app.m_specific.m_cur_x , 
     app.m_specific.m_cur_y ) then
  begin
   app.on_ctrl_change;
   app.force_redraw;
   
  end
 else
  if app.m_ctrls.in_rect(
      app.m_specific.m_cur_x , 
      app.m_specific.m_cur_y ) then
   if app.m_ctrls.set_cur(
       app.m_specific.m_cur_x , 
       app.m_specific.m_cur_y ) then
    begin
     app.on_ctrl_change;
     app.force_redraw;
 
    end
   else
  else
   app.on_mouse_button_down(
    app.m_specific.m_cur_x , 
    app.m_specific.m_cur_y , 
    app.m_specific.m_input_flags );
 
 result:=CallNextEventHandler(nextHandler ,theEvent );

end;

{ DOMOUSEUP }
function DoMouseUp(nextHandler : EventHandlerCallRef; theEvent : EventRef; userData : pointer ) : OSStatus;
var
 wheresMyMouse : Carbon.Point;
 
 modifier : UInt32;
 button   : EventMouseButton;

 sz  : UInt32; 
 app : platform_support_ptr;
 ept : EventParamType;

begin
 ept:=0;

 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamMouseLocation[1 ] )^ ) ,
  LongWord(int32_ptr(@typeQDPoint[1 ] )^ ) ,
  ept ,
  sizeof(Carbon.Point ) ,
  sz ,
  @wheresMyMouse );

 GlobalToLocal(wheresMyMouse );
  
 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamKeyModifiers[1 ] )^ ) ,
  LongWord(int32_ptr(@typeUInt32[1 ] )^ ) ,
  ept ,
  sizeof(UInt32 ) ,
  sz ,
  @modifier );

 app:=platform_support_ptr(userData );
 
 app.m_specific.m_cur_x:=wheresMyMouse.h;
 
 if app._flip_y then
  app.m_specific.m_cur_y:=app.rbuf_window._height - wheresMyMouse.v
 else
  app.m_specific.m_cur_y:=wheresMyMouse.v;

 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamMouseButton[1 ] )^ ) ,
  LongWord(int32_ptr(@typeMouseButton[1 ] )^ ) ,
  ept ,
  sizeof(EventMouseButton ) ,
  sz ,
  @button );
  
 case button of
  kEventMouseButtonSecondary :
   app.m_specific.m_input_flags:=mouse_right or get_key_flags(modifier );
   
  else
   app.m_specific.m_input_flags:=mouse_left or get_key_flags(modifier );

 end;

 if app.m_ctrls.on_mouse_button_up(
     app.m_specific.m_cur_x , 
     app.m_specific.m_cur_y ) then
  begin
   app.on_ctrl_change;
   app.force_redraw;
   
  end;

 app.on_mouse_button_up(
  app.m_specific.m_cur_x , 
  app.m_specific.m_cur_y , 
  app.m_specific.m_input_flags );

 result:=CallNextEventHandler(nextHandler ,theEvent );

end;

{ DOMOUSEDRAGGED }
function DoMouseDragged(nextHandler : EventHandlerCallRef; theEvent : EventRef; userData : pointer ) : OSStatus;
var
 wheresMyMouse : Carbon.Point;
 
 modifier : UInt32;
 button   : EventMouseButton; 

 sz  : UInt32; 
 app : platform_support_ptr;
 ept : EventParamType;

begin
 ept:=0;

 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamMouseLocation[1 ] )^ ) ,
  LongWord(int32_ptr(@typeQDPoint[1 ] )^ ) ,
  ept ,
  sizeof(Carbon.Point ) ,
  sz ,
  @wheresMyMouse );

 GlobalToLocal(wheresMyMouse );
 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamKeyModifiers[1 ] )^ ) ,
  LongWord(int32_ptr(@typeUInt32[1 ] )^ ) ,
  ept ,
  sizeof(UInt32 ) ,
  sz ,
  @modifier );

 app:=platform_support_ptr(userData );
 
 app.m_specific.m_cur_x:=wheresMyMouse.h;
 
 if app._flip_y then
  app.m_specific.m_cur_y:=app.rbuf_window._height - wheresMyMouse.v
 else
  app.m_specific.m_cur_y:=wheresMyMouse.v;

 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamMouseButton[1 ] )^ ) ,
  LongWord(int32_ptr(@typeMouseButton[1 ] )^ ) ,
  ept ,
  sizeof(EventMouseButton ) ,
  sz ,
  @button );
  
 case button of
  kEventMouseButtonSecondary :
   app.m_specific.m_input_flags:=mouse_right or get_key_flags(modifier );
   
  else
   app.m_specific.m_input_flags:=mouse_left or get_key_flags(modifier );

 end;

 if app.m_ctrls.on_mouse_move(
     app.m_specific.m_cur_x , 
     app.m_specific.m_cur_y ,
     app.m_specific.m_input_flags and mouse_left <> 0 ) then
  begin
   app.on_ctrl_change;
   app.force_redraw;
   
  end
 else
  app.on_mouse_move(
   app.m_specific.m_cur_x , 
   app.m_specific.m_cur_y , 
   app.m_specific.m_input_flags );

 result:=CallNextEventHandler(nextHandler ,theEvent );

end;

{ DOKEYDOWN }
function DoKeyDown(nextHandler : EventHandlerCallRef; theEvent : EventRef; userData : pointer ) : OSStatus;
var
 key_char : byte;
 key_code ,
 modifier : UInt32;

 sz  : UInt32; 
 app : platform_support_ptr;
 ept : EventParamType;
 
 left ,up ,right ,down : boolean;

begin
 ept:=0;

 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamKeyMacCharCodes[1 ] )^ ) ,
  LongWord(int32_ptr(@typeChar[1 ] )^ ) ,
  ept ,
  sizeof(byte ) ,
  sz ,
  @key_char );
  
 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamKeyCode[1 ] )^ ) ,
  LongWord(int32_ptr(@typeUInt32[1 ] )^ ) ,
  ept ,
  sizeof(UInt32 ) ,
  sz ,
  @key_code );
    
 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamKeyModifiers[1 ] )^ ) ,
  LongWord(int32_ptr(@typeUInt32[1 ] )^ ) ,
  ept ,
  sizeof(UInt32 ) ,
  sz ,
  @modifier );

 app:=platform_support_ptr(userData );

 app.m_specific.m_last_translated_key:=0;
 
 case modifier of
  controlKey :
   app.m_specific.m_input_flags:=
    app.m_specific.m_input_flags or kbd_ctrl;

  shiftKey :
   app.m_specific.m_input_flags:=
    app.m_specific.m_input_flags or kbd_shift;

  else
   app.m_specific.translate(key_char );

 end;
 
 case key_char of
  kFunctionKeyCharCode :
   case key_code of
    122 : app.m_specific.m_last_translated_key:=key_f1;
    120 : app.m_specific.m_last_translated_key:=key_f2;
    99  : app.m_specific.m_last_translated_key:=key_f3;
    118 : app.m_specific.m_last_translated_key:=key_f4;
    96  : app.m_specific.m_last_translated_key:=key_f5;
    97  : app.m_specific.m_last_translated_key:=key_f6;
    98  : app.m_specific.m_last_translated_key:=key_f7;
    100 : app.m_specific.m_last_translated_key:=key_f8;
   
   end;
 
 end;
 
 if (app.m_specific.m_last_translated_key = 0 ) and
    (key_char > 31 ) then
  app.m_specific.m_last_translated_key:=key_char;

 if app.m_specific.m_last_translated_key <> 0 then
  begin
   left :=false;
   up   :=false;
   right:=false;
   down :=false;

   case app.m_specific.m_last_translated_key of
    key_left  : left :=true;
    key_up    : up   :=true;
    key_right : right:=true;
    key_down  : down :=true;

   //On a Mac, screenshots are handled by the system.
    key_f2 :
     begin
      app.copy_window_to_img(max_images - 1 );
      app.save_img          (max_images - 1 ,'screenshot.png' );

     end;
 
    key_f4 :
     if modifier = optionKey then
      app.quit;

   end;

   if app.m_ctrls.on_arrow_keys(left ,right ,down ,up ) then
    begin
     app.on_ctrl_change;
     app.force_redraw;

    end
   else
    app.on_key(
     app.m_specific.m_cur_x ,
     app.m_specific.m_cur_y ,
     app.m_specific.m_last_translated_key ,
     app.m_specific.m_input_flags );

  end;

 result:=CallNextEventHandler(nextHandler ,theEvent );

end;

{ DOKEYUP }
function DoKeyUp(nextHandler : EventHandlerCallRef; theEvent : EventRef; userData : pointer ) : OSStatus;
var
 key_code : byte;
 modifier : UInt32;

 sz  : UInt32; 
 app : platform_support_ptr;
 ept : EventParamType;

begin
 ept:=0;

 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamKeyMacCharCodes[1 ] )^ ) ,
  LongWord(int32_ptr(@typeChar[1 ] )^ ) ,
  ept ,
  sizeof(byte ) ,
  sz ,
  @key_code );
  
 GetEventParameter(
  theEvent ,
  LongWord(int32_ptr(@kEventParamKeyModifiers[1 ] )^ ) ,
  LongWord(int32_ptr(@typeUInt32[1 ] )^ ) ,
  ept ,
  sizeof(UInt32 ) ,
  sz ,
  @modifier );

 app:=platform_support_ptr(userData );
 
 app.m_specific.m_last_translated_key:=0;

 case modifier of
  controlKey :
   app.m_specific.m_input_flags:=
    app.m_specific.m_input_flags and not kbd_ctrl;

  shiftKey :
   app.m_specific.m_input_flags:=
    app.m_specific.m_input_flags and not kbd_shift;
   
 end;
    
 result:=CallNextEventHandler(nextHandler ,theEvent );

end;

{ DOPERIODICTASK }
procedure DoPeriodicTask(theTimer : EventLoopTimerRef; userData : pointer );
var
 app : platform_support_ptr;
 
begin
 app:=platform_support_ptr(userData );
 
 if not app._wait_mode then
  app.on_idle;
  
end;

{ INIT }
function platform_support.init;
var
 eventType   : EventTypeSpec;
 handlerUPP  : EventHandlerUPP;
 theTarget   : CFStringRef;
 windowAttrs : WindowAttributes;
 bounds      : Carbon.Rect;
 mainLoop    : EventLoopRef;
 timerUPP    : EventLoopTimerUPP;
 theTimer    : EventLoopTimerRef;
 
begin
 if m_specific.m_sys_format = pix_format_undefined then
  begin
   result:=false;

   exit;

  end;

 m_window_flags:=flags; 
 
// application
 theTarget:=GetApplicationEventTarget;

 eventType.eventClass:=LongWord(int32_ptr(@kEventClassApplication[1 ] )^ );
 eventType.eventKind :=kEventAppQuit;

 handlerUPP:=NewEventHandlerUPP(@DoAppQuit );

 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,NIL ,NIL ); 


 eventType.eventClass:=LongWord(int32_ptr(@kEventClassMouse[1 ] )^ );
 eventType.eventKind :=kEventMouseDown;
 
 handlerUPP:=NewEventHandlerUPP(@DoMouseDown );

 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,@self ,NIL );


 eventType.eventKind:=kEventMouseUp;
 
 handlerUPP:=NewEventHandlerUPP(@DoMouseUp );
 
 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,@self ,NIL );


 eventType.eventKind:=kEventMouseDragged;
 
 handlerUPP:=NewEventHandlerUPP(@DoMouseDragged );

 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,@self ,NIL );


 eventType.eventClass:=LongWord(int32_ptr(@kEventClassKeyboard[1 ] )^ );
 eventType.eventKind :=kEventRawKeyDown;

 handlerUPP:=NewEventHandlerUPP(@DoKeyDown );

 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,@self ,NIL );


 eventType.eventKind:=kEventRawKeyUp;
 
 handlerUPP:=NewEventHandlerUPP(@DoKeyUp );
 
 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,@self ,NIL );


 eventType.eventKind:=kEventRawKeyRepeat;

 handlerUPP:=NewEventHandlerUPP(@DoKeyDown ); // 'key repeat' is translated to 'key down'

 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,@self ,NIL );

// window
 windowAttrs:=kWindowCloseBoxAttribute or kWindowCollapseBoxAttribute or kWindowStandardHandlerAttribute;

 if flags and window_resize <> 0 then
  windowAttrs:=
   windowAttrs or 
   kWindowResizableAttribute or 
   kWindowFullZoomAttribute or
   kWindowLiveResizeAttribute;

 SetRect   (bounds ,0 ,0 ,width_ ,height_ );
 OffsetRect(bounds ,100 ,100 );

 CreateNewWindow(
  kDocumentWindowClass ,
  windowAttrs ,
  bounds ,
  m_specific.m_window );

 if m_specific.m_window = NIL then
  begin 
   result:=false;

   exit;

  end;
  
// I assume the text is ASCII.
// Change to kCFStringEncodingMacRoman, kCFStringEncodingISOLatin1, kCFStringEncodingUTF8 or what else you need.  
 SetWindowTitleWithCFString(
  m_specific.m_window ,
  CFStringCreateWithPascalStringNoCopy(
   NIL ,m_caption ,kCFStringEncodingASCII ,NIL ) );

 theTarget:=GetWindowEventTarget(m_specific.m_window );		

 eventType.eventClass:=LongWord(int32_ptr(@kEventClassWindow[1 ] )^ );
 eventType.eventKind :=kEventWindowClose;

 handlerUPP:=NewEventHandlerUPP(@DoWindowClose );

 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,@self ,NIL );


 eventType.eventKind:=kEventWindowDrawContent;
 
 handlerUPP:=NewEventHandlerUPP(@DoWindowDrawContent );
 
 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,@self ,NIL ); 


 eventType.eventKind:=kEventWindowBoundsChanged;
 
 handlerUPP:=NewEventHandlerUPP(@DoWindowResize );
 
 InstallEventHandler(theTarget ,handlerUPP ,1 ,eventType ,@self ,NIL ); 
 
// Periodic task
// Instead of an idle function I use the Carbon event timer.
// You may decide to change the wait value which is currently 50 milliseconds.
 mainLoop:=GetMainEventLoop;
 timerUPP:=NewEventLoopTimerUPP(@DoPeriodicTask );

 InstallEventLoopTimer(mainLoop ,0 ,50 * kEventDurationMillisecond ,timerUPP ,@self ,theTimer );

 m_specific.create_pmap(width_ ,height_ ,@m_rbuf_window );

 m_initial_width :=width_;
 m_initial_height:=height_;
 
 on_init;
 on_resize(width_ ,height_ );

 m_specific.m_redraw_flag:=true;

 ShowWindow       (m_specific.m_window );
 SetPortWindowPort(m_specific.m_window );

 result:=true; 

end;

{ RUN }
function platform_support.run;
begin
 RunApplicationEventLoop;

 result:=1; 

end;

{ QUIT }
procedure platform_support.quit;
begin
 QuitApplicationEventLoop;

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
var
 bounds : Carbon.Rect;
 
begin
 m_specific.m_redraw_flag:=true;

// on_ctrl_change
 on_draw;

 SetRect        (bounds ,0 ,0 ,m_rbuf_window._width ,m_rbuf_window._height );
 InvalWindowRect(m_specific.m_window ,bounds );

end;

{ UPDATE_WINDOW }
procedure platform_support.update_window;
begin
 m_specific.display_pmap(m_specific.m_window ,@m_rbuf_window );
 
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
 result:='.bmp';

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
   //double sx = double(width) / double(m_initial_width);
   //double sy = double(height) / double(m_initial_height);
   //if(sy < sx) sx = sy;
   //m_resize_mtx = trans_affine_scaling(sx, sx);

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
var
 dlg : DialogRef;
 itm : DialogItemIndex;

begin
 CreateStandardAlert(
  kAlertPlainAlert ,
  CFStringCreateWithCStringNoCopy(
   NIL ,'AGG Message' ,kCFStringEncodingASCII ,NIL ) ,  
  CFStringCreateWithCStringNoCopy(
   NIL ,msg ,kCFStringEncodingASCII ,NIL ) ,
  NIL ,
  dlg );
  
 RunStandardAlert(dlg ,NIL ,itm );

end;

{ START_TIMER }
procedure platform_support.start_timer;
begin
 Microseconds(m_specific.m_sw_start );

end;

{ ELAPSED_TIME }
function platform_support.elapsed_time;
var
 stop : UnsignedWide;
 
begin
 Microseconds(stop );
 
 result:=
  (stop.lo - m_specific.m_sw_start.lo) * 1e6 / 
  m_specific.m_sw_freq.lo;

end;

{ FULL_FILE_NAME }
function platform_support.full_file_name;
begin
 result:=file_name;

end;

{ FILE_SOURCE }
function platform_support.file_source;
begin
 result:=fname;

end;

END.

