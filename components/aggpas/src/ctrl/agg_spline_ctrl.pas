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
// classes spline_ctrl_impl, spline_ctrl
//
// Class that can be used to create an interactive control to set up
// gamma arrays.
//
// [Pascal Port History] -----------------------------------------------------
//
// 23.02.2006-Milano: Unit port establishment
//
{ agg_spline_ctrl.pas }
unit
 agg_spline_ctrl ;

INTERFACE

{$I agg_mode.inc }

uses
 agg_basics ,
 agg_ellipse ,
 agg_bspline ,
 agg_conv_stroke ,
 agg_path_storage ,
 agg_trans_affine ,
 agg_color ,
 agg_ctrl ,
 agg_math ;

{ TYPES DEFINITION }
type
 spline_ctrl_impl = object(ctrl )
   m_num_pnt : unsigned;

   m_xp ,
   m_yp : array[0..31 ] of double;

   m_spline : bspline;

   m_spline_values  : array[0..255 ] of double;
   m_spline_values8 : array[0..255 ] of int8u;
   m_border_width   ,
   m_border_extra   ,
   m_curve_width    ,
   m_point_size     ,

   m_xs1 ,
   m_ys1 ,
   m_xs2 ,
   m_ys2 : double;

   m_curve_pnt  : path_storage;
   m_curve_poly : conv_stroke;
   m_ellipse    : ellipse;

   m_idx    ,
   m_vertex : unsigned;

   m_vx ,
   m_vy : array[0..31 ] of double;

   m_active_pnt ,
   m_move_pnt   : int;

   m_pdx ,
   m_pdy : double;

   constructor Construct(x1 ,y1 ,x2 ,y2 : double; num_pnt : unsigned; flip_y : boolean = false );
   destructor  Destruct; virtual;

  // Set other parameters
   procedure border_width_(t : double; extra : double = 0.0 );
   procedure curve_width_ (t : double );
   procedure point_size_  (s : double );

  // Event handlers. Just call them if the respective events
  // in your system occur. The functions return true if redrawing
  // is required.
   function  in_rect(x ,y : double ) : boolean; virtual;

   function  on_mouse_button_down(x ,y : double ) : boolean; virtual;
   function  on_mouse_button_up  (x ,y : double ) : boolean; virtual;

   function  on_mouse_move(x ,y : double; button_flag : boolean ) : boolean; virtual;
   function  on_arrow_keys(left ,right ,down ,up : boolean ) : boolean; virtual;

  // Spline
   procedure active_point_(i : int );

   function  _spline : double_ptr;
   function  _spline8 : int8u_ptr;

   function  _value(x : double ) : double;
   procedure value_(idx : unsigned; y : double );
   procedure point_(idx : unsigned; x ,y : double );

   procedure x_(idx : unsigned; x : double );
   procedure y_(idx : unsigned; y : double );
   function  _x(idx : unsigned ) : double;
   function  _y(idx : unsigned ) : double;

   procedure update_spline;

  // Vertex soutce interface
   function  num_paths : unsigned; virtual;
   procedure rewind(path_id : unsigned ); virtual;
   function  vertex(x ,y : double_ptr ) : unsigned; virtual;

  // Private
   procedure calc_spline_box;
   procedure calc_curve;
   function  calc_xp(idx : unsigned ) : double;
   function  calc_yp(idx : unsigned ) : double;
   procedure set_xp (idx : unsigned; val : double );
   procedure set_yp (idx : unsigned; val : double );

  end;

 spline_ctrl = object(spline_ctrl_impl )
   m_background_color   ,
   m_border_color       ,
   m_curve_color        ,
   m_inactive_pnt_color ,
   m_active_pnt_color   : aggclr;

   m_colors : array[0..4 ] of aggclr_ptr;

   constructor Construct(x1 ,y1 ,x2 ,y2 : double; num_pnt : unsigned; flip_y : boolean = false );

   procedure background_color_  (c : aggclr_ptr );
   procedure border_color_      (c : aggclr_ptr );
   procedure curve_color_       (c : aggclr_ptr );
   procedure inactive_pnt_color_(c : aggclr_ptr );
   procedure active_pnt_color_  (c : aggclr_ptr );

   function  _color(i : unsigned ) : aggclr_ptr; virtual;

  end;

{ GLOBAL PROCEDURES }


IMPLEMENTATION
{ LOCAL VARIABLES & CONSTANTS }
{ UNIT IMPLEMENTATION }
{ CONSTRUCT }
constructor spline_ctrl_impl.Construct;
var
 i : unsigned;

begin
 inherited Construct(x1 ,y1 ,x2 ,y2 ,flip_y );

 m_num_pnt:=num_pnt;

 m_border_width:=1.0;
 m_border_extra:=0.0;
 m_curve_width :=1.0;
 m_point_size  :=3.0;

 m_spline.Construct;
 m_curve_pnt.Construct;
 m_curve_poly.Construct(@m_curve_pnt );
 m_ellipse.Construct;

 m_idx       :=0;
 m_vertex    :=0;
 m_active_pnt:=-1;
 m_move_pnt  :=-1;

 m_pdx:=0.0;
 m_pdy:=0.0;

 if m_num_pnt < 4 then
  m_num_pnt:=4;

 if m_num_pnt > 32 then
  m_num_pnt:=32;

 for i:=0 to m_num_pnt - 1 do
  begin
   m_xp[i ]:=i / (m_num_pnt - 1 );
   m_yp[i ]:=0.5;

  end;

 calc_spline_box;
 update_spline;

end;

{ DESTRUCT }
destructor spline_ctrl_impl.Destruct;
begin
 m_spline.Destruct;
 m_curve_pnt.Destruct;
 m_curve_poly.Destruct;

end;

{ BORDER_WIDTH_ }
procedure spline_ctrl_impl.border_width_;
begin
 m_border_width:=t;
 m_border_extra:=extra;

 calc_spline_box;

end;

{ CURVE_WIDTH_ }
procedure spline_ctrl_impl.curve_width_;
begin
 m_curve_width:=t;

end;

{ POINT_SIZE_ }
procedure spline_ctrl_impl.point_size_;
begin
 m_point_size:=s;

end;

{ IN_RECT }
function spline_ctrl_impl.in_rect;
begin
 inverse_transform_xy(@x ,@y );

 result:=
  (x >= m_x1 ) and
  (x <= m_x2 ) and
  (y >= m_y1 ) and
  (y <= m_y2 );

end;

{ ON_MOUSE_BUTTON_DOWN }
function spline_ctrl_impl.on_mouse_button_down;
var
 i : unsigned;

 xp ,yp : double;

begin
 inverse_transform_xy(@x ,@y );

 for i:=0 to m_num_pnt - 1 do
  begin
   xp:=calc_xp(i );
   yp:=calc_yp(i );

   if calc_distance(x ,y ,xp ,yp ) <= m_point_size + 1 then
    begin
     m_pdx:=xp - x;
     m_pdy:=yp - y;

     m_active_pnt:=i;
     m_move_pnt  :=i;

     result:=true;

     exit;

    end;

  end;

 result:=false;

end;

{ ON_MOUSE_BUTTON_UP }
function spline_ctrl_impl.on_mouse_button_up;
begin
 if m_move_pnt >= 0 then
  begin
   m_move_pnt:=-1;

   result:=true;

  end
 else
  result:=false;

end;

{ ON_MOUSE_MOVE }
function spline_ctrl_impl.on_mouse_move;
var
 xp ,yp : double;

begin
 inverse_transform_xy(@x ,@y );

 if not button_flag then
  begin
   result:=on_mouse_button_up(x ,y );

   exit;

  end;

 if m_move_pnt >= 0 then
  begin
   xp:=x + m_pdx;
   yp:=y + m_pdy;

   set_xp(m_move_pnt ,(xp - m_xs1 ) / (m_xs2 - m_xs1 ) );
   set_yp(m_move_pnt ,(yp - m_ys1 ) / (m_ys2 - m_ys1 ) );

   update_spline;

   result:=true;

  end
 else
  result:=false;

end;

{ ON_ARROW_KEYS }
function spline_ctrl_impl.on_arrow_keys;
var
 kx ,ky : double;

 ret : boolean;

begin
 kx :=0.0;
 ky :=0.0;
 ret:=false;

 if m_active_pnt >= 0 then
  begin
   kx:=m_xp[m_active_pnt ];
   ky:=m_yp[m_active_pnt ];

   if left then
    begin
     kx :=kx - 0.001;
     ret:=true;

    end;

   if right then
    begin
     kx :=kx + 0.001;
     ret:=true;

    end;

   if down then
    begin
     ky :=ky - 0.001;
     ret:=true;

    end;

   if up then
    begin
     ky :=ky + 0.001;
     ret:=true;

    end;

  end;

 if ret then
  begin
   set_xp(m_active_pnt ,kx );
   set_yp(m_active_pnt ,ky );

   update_spline;

  end;

 result:=ret;

end;

{ ACTIVE_POINT_ }
procedure spline_ctrl_impl.active_point_;
begin
 m_active_pnt:=i;

end;

{ _SPLINE }
function spline_ctrl_impl._spline;
begin
 result:=@m_spline_values;

end;

{ _SPLINE8 }
function spline_ctrl_impl._spline8;
begin
 result:=@m_spline_values8;

end;

{ _VALUE }
function spline_ctrl_impl._value;
begin
 x:=m_spline.get(x );

 if x < 0.0 then
  x:=0.0;

 if x > 1.0 then
  x:=1.0;

 result:=x;

end;

{ VALUE_ }
procedure spline_ctrl_impl.value_;
begin
 if idx < m_num_pnt then
  set_yp(idx ,y );

end;

{ POINT_ }
procedure spline_ctrl_impl.point_;
begin
 if idx < m_num_pnt then
  begin
   set_xp(idx ,x );
   set_yp(idx ,y );

  end;

end;

{ X_ }
procedure spline_ctrl_impl.x_;
begin
 m_xp[idx ]:=x;

end;

{ Y_ }
procedure spline_ctrl_impl.y_;
begin
 m_yp[idx ]:=y;

end;

{ _X }
function spline_ctrl_impl._x;
begin
 result:=m_xp[idx ];

end;

{ _Y }
function spline_ctrl_impl._y;
begin
 result:=m_yp[idx ];

end;

{ UPDATE_SPLINE }
procedure spline_ctrl_impl.update_spline;
var
 i : int;

begin
 m_spline.init(m_num_pnt ,@m_xp ,@m_yp );

 for i:=0 to 255 do
  begin
   m_spline_values[i ]:=m_spline.get(i / 255.0 );

   if m_spline_values[i ] < 0.0 then
    m_spline_values[i ]:=0.0;

   if m_spline_values[i ] > 1.0 then
    m_spline_values[i ]:=1.0;

   m_spline_values8[i ]:=int8u(trunc(m_spline_values[i ] * 255.0 ) );

  end;

end;

{ NUM_PATHS }
function spline_ctrl_impl.num_paths;
begin
 result:=5;

end;

{ REWIND }
procedure spline_ctrl_impl.rewind;
var
 i : unsigned;

begin
 m_idx:=path_id;

 case path_id of
  0 : // Background
   begin
    m_vertex:=0;

    m_vx[0 ]:=m_x1 - m_border_extra;
    m_vy[0 ]:=m_y1 - m_border_extra;
    m_vx[1 ]:=m_x2 + m_border_extra;
    m_vy[1 ]:=m_y1 - m_border_extra;
    m_vx[2 ]:=m_x2 + m_border_extra;
    m_vy[2 ]:=m_y2 + m_border_extra;
    m_vx[3 ]:=m_x1 - m_border_extra;
    m_vy[3 ]:=m_y2 + m_border_extra;

   end;

  1 : // Border
   begin
    m_vertex:=0;

    m_vx[0 ]:=m_x1;
    m_vy[0 ]:=m_y1;
    m_vx[1 ]:=m_x2;
    m_vy[1 ]:=m_y1;
    m_vx[2 ]:=m_x2;
    m_vy[2 ]:=m_y2;
    m_vx[3 ]:=m_x1;
    m_vy[3 ]:=m_y2;
    m_vx[4 ]:=m_x1 + m_border_width;
    m_vy[4 ]:=m_y1 + m_border_width;
    m_vx[5 ]:=m_x1 + m_border_width;
    m_vy[5 ]:=m_y2 - m_border_width;
    m_vx[6 ]:=m_x2 - m_border_width;
    m_vy[6 ]:=m_y2 - m_border_width;
    m_vx[7 ]:=m_x2 - m_border_width;
    m_vy[7 ]:=m_y1 + m_border_width;

   end;

  2 : // Curve
   begin
    calc_curve;

    m_curve_poly.width_(m_curve_width );
    m_curve_poly.rewind(0 );

   end;

  3 : // Inactive points
   begin
    m_curve_pnt.remove_all;

    for i:=0 to m_num_pnt - 1 do
     if i <> m_active_pnt then
      begin
       m_ellipse.init(
        calc_xp(i ) ,calc_yp(i ) ,
        m_point_size ,m_point_size ,32 );

       m_curve_pnt.add_path(@m_ellipse ,0 ,false );

      end;

    m_curve_poly.rewind(0 );

   end;

  4 : // Active point
   begin
    m_curve_pnt.remove_all;

    if m_active_pnt >= 0 then
     begin
      m_ellipse.init(
       calc_xp(m_active_pnt ) ,calc_yp(m_active_pnt ) ,
       m_point_size ,m_point_size ,32 );

      m_curve_pnt.add_path(@m_ellipse );

     end;

    m_curve_poly.rewind(0 );

   end;

 end;

end;

{ VERTEX }
function spline_ctrl_impl.vertex;
var
 cmd : unsigned;

begin
 cmd:=path_cmd_line_to;

 case m_idx of
  0 :
   begin
    if m_vertex = 0 then
     cmd:=path_cmd_move_to;

    if m_vertex >= 4 then
     cmd:=path_cmd_stop;

    x^:=m_vx[m_vertex ];
    y^:=m_vy[m_vertex ];

    inc(m_vertex );

   end;

  1 :
   begin
    if (m_vertex = 0 ) or
       (m_vertex = 4 ) then
     cmd:=path_cmd_move_to;

    if m_vertex >= 8 then
     cmd:=path_cmd_stop;

    x^:=m_vx[m_vertex ];
    y^:=m_vy[m_vertex ];

    inc(m_vertex );

   end;

  2 :
   cmd:=m_curve_poly.vertex(x ,y );

  3 ,4 :
   cmd:=m_curve_pnt.vertex(x ,y );

  else
   cmd:=path_cmd_stop;

 end;

 if not is_stop(cmd ) then
  transform_xy(x ,y );

 result:=cmd;

end;

{ CALC_SPLINE_BOX }
procedure spline_ctrl_impl.calc_spline_box;
begin
 m_xs1:=m_x1 + m_border_width;
 m_ys1:=m_y1 + m_border_width;
 m_xs2:=m_x2 - m_border_width;
 m_ys2:=m_y2 - m_border_width;

end;

{ CALC_CURVE }
procedure spline_ctrl_impl.calc_curve;
var
 i : int;

begin
 m_curve_pnt.remove_all;
 m_curve_pnt.move_to(m_xs1 ,m_ys1 + (m_ys2 - m_ys1 ) * m_spline_values[0 ] );

 for i:=1 to 255 do
  m_curve_pnt.line_to(
   m_xs1 + (m_xs2 - m_xs1 ) * i / 255.0 ,
   m_ys1 + (m_ys2 - m_ys1 ) * m_spline_values[i ] );

end;

{ CALC_XP }
function spline_ctrl_impl.calc_xp;
begin
 result:=m_xs1 + (m_xs2 - m_xs1 ) * m_xp[idx ];

end;

{ CALC_YP }
function spline_ctrl_impl.calc_yp;
begin
 result:=m_ys1 + (m_ys2 - m_ys1 ) * m_yp[idx ];

end;

{ SET_XP }
procedure spline_ctrl_impl.set_xp;
begin
 if val < 0.0 then
  val:=0.0;

 if val > 1.0 then
  val:=1.0;

 if idx = 0 then
  val:=0.0
 else
  if idx = m_num_pnt - 1 then
   val:=1.0
  else
   begin
    if val < m_xp[idx - 1 ] + 0.001 then
     val:=m_xp[idx - 1 ] + 0.001;

    if val > m_xp[idx + 1 ] - 0.001 then
     val:=m_xp[idx + 1 ] - 0.001;

   end;

 m_xp[idx ]:=val;

end;

{ SET_YP }
procedure spline_ctrl_impl.set_yp;
begin
 if val < 0.0 then
  val:=0.0;

 if val > 1.0 then
  val:=1.0;

 m_yp[idx ]:=val;

end;

{ CONSTRUCT }
constructor spline_ctrl.Construct;
begin
 inherited Construct(x1 ,y1 ,x2 ,y2 ,num_pnt ,flip_y );

 m_background_color.ConstrDbl  (1.0 ,1.0 ,0.9 );
 m_border_color.ConstrDbl      (0.0 ,0.0 ,0.0 );
 m_curve_color.ConstrDbl       (0.0 ,0.0 ,0.0 );
 m_inactive_pnt_color.ConstrDbl(0.0 ,0.0 ,0.0 );
 m_active_pnt_color.ConstrDbl  (1.0 ,0.0 ,0.0 );

 m_colors[0 ]:=@m_background_color;
 m_colors[1 ]:=@m_border_color;
 m_colors[2 ]:=@m_curve_color;
 m_colors[3 ]:=@m_inactive_pnt_color;
 m_colors[4 ]:=@m_active_pnt_color;

end;

{ BACKGROUND_COLOR_ }
procedure spline_ctrl.background_color_;
begin
 m_background_color:=c^;

end;

{ BORDER_COLOR_ }
procedure spline_ctrl.border_color_;
begin
 m_border_color:=c^;

end;

{ CURVE_COLOR_ }
procedure spline_ctrl.curve_color_;
begin
 m_curve_color:=c^;

end;

{ INACTIVE_PNT_COLOR_ }
procedure spline_ctrl.inactive_pnt_color_;
begin
 m_inactive_pnt_color:=c^;

end;

{ ACTIVE_PNT_COLOR_ }
procedure spline_ctrl.active_pnt_color_;
begin
 m_active_pnt_color:=c^;

end;

{ _COLOR }
function spline_ctrl._color;
begin
 result:=m_colors[i ];

end;

END.

