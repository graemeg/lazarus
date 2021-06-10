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
// [Pascal Port History] -----------------------------------------------------
//
// 30.01.2006-Milano: Unit port establishment
//
{ agg_gamma_ctrl.pas }
unit
 agg_gamma_ctrl ;

INTERFACE

{$I agg_mode.inc }

uses
 SysUtils ,
 agg_basics ,
 agg_gamma_spline ,
 agg_ellipse ,
 agg_conv_stroke ,
 agg_gsv_text ,
 agg_trans_affine ,
 agg_color ,
 agg_ctrl ,
 agg_math ,
 agg_math_stroke ;

{ TYPES DEFINITION }
type
 gamma_ctrl_impl = object(ctrl )
   m_gamma_spline : gamma_spline;

   m_border_width   ,
   m_border_extra   ,
   m_curve_width    ,
   m_grid_width     ,
   m_text_thickness ,
   m_point_size     ,
   m_text_height    ,
   m_text_width     ,

   m_xc1 ,
   m_yc1 ,
   m_xc2 ,
   m_yc2 ,
   m_xs1 ,
   m_ys1 ,
   m_xs2 ,
   m_ys2 ,
   m_xt1 ,
   m_yt1 ,
   m_xt2 ,
   m_yt2 : double;

   m_curve_poly : conv_stroke;
   m_ellipse    : ellipse;
   m_text       : gsv_text;
   m_text_poly  : conv_stroke;

   m_idx    ,
   m_vertex : unsigned;

   m_vx ,
   m_vy : array[0..31 ] of double;

   m_xp1 ,
   m_yp1 ,
   m_xp2 ,
   m_yp2 : double;

   m_p1_active   : boolean;
   m_mouse_point : unsigned;

   m_pdx ,
   m_pdy : double;

   constructor Construct(x1 ,y1 ,x2 ,y2 : double; flip_y : boolean = false );
   destructor  Destruct; virtual;

  // Set other parameters
   procedure border_width_  (t : double; extra : double = 0.0 );
   procedure curve_width_   (t : double );
   procedure grid_width_    (t : double );
   procedure text_thickness_(t : double );
   procedure text_size_     (h : double; w : double = 0.0 );
   procedure point_size_    (s : double );

  // Event handlers. Just call them if the respective events
  // in your system occur. The functions return true if redrawing
  // is required.
   function  in_rect(x ,y : double ) : boolean; virtual;

   function  on_mouse_button_down(x ,y : double ) : boolean; virtual;
   function  on_mouse_button_up  (x ,y : double ) : boolean; virtual;

   function  on_mouse_move(x ,y : double; button_flag : boolean ) : boolean; virtual;
   function  on_arrow_keys(left ,right ,down ,up : boolean ) : boolean; virtual;

   procedure change_active_point;

  // A copy of gamma_spline interface
   procedure values(kx1 ,ky1 ,kx2 ,ky2 : double ); overload;
   procedure values(kx1 ,ky1 ,kx2 ,ky2 : double_ptr ); overload;

   function  gamma : char_ptr;
   function  _y(x : double ) : double;

   function  func_operator_gamma(x : double ) : double; virtual;

  // Vertex soutce interface
   function  num_paths : unsigned; virtual;
   procedure rewind(path_id : unsigned ); virtual;
   function  vertex(x ,y : double_ptr ) : unsigned; virtual;

  // Private
   procedure calc_spline_box;
   procedure calc_points;
   procedure calc_values;

  end;

 gamma_ctrl = object(gamma_ctrl_impl )
   m_background_color   ,
   m_border_color       ,
   m_curve_color        ,
   m_grid_color         ,
   m_inactive_pnt_color ,
   m_active_pnt_color   ,
   m_text_color         : aggclr;

   m_colors : array[0..6 ] of aggclr_ptr;

   constructor Construct(x1 ,y1 ,x2 ,y2 : double; flip_y : boolean = false );

   procedure background_color_  (c : aggclr_ptr );
   procedure border_color_      (c : aggclr_ptr );
   procedure curve_color_       (c : aggclr_ptr );
   procedure grid_color_        (c : aggclr_ptr );
   procedure inactive_pnt_color_(c : aggclr_ptr );
   procedure active_pnt_color_  (c : aggclr_ptr );
   procedure text_color_        (c : aggclr_ptr );

   function  _color(i : unsigned ) : aggclr_ptr; virtual;

  end;

{ GLOBAL PROCEDURES }


IMPLEMENTATION
{ LOCAL VARIABLES & CONSTANTS }
{ UNIT IMPLEMENTATION }
{ CONSTRUCT }
constructor gamma_ctrl_impl.Construct;
begin
 inherited Construct(x1 ,y1 ,x2 ,y2 ,flip_y );

 m_border_width  :=2.0;
 m_border_extra  :=0.0;
 m_curve_width   :=2.0;
 m_grid_width    :=0.2;
 m_text_thickness:=1.5;
 m_point_size    :=5.0;
 m_text_height   :=9.0;
 m_text_width    :=0.0;

 m_xc1:=x1;
 m_yc1:=y1;
 m_xc2:=x2;
 m_yc2:=y2 - m_text_height * 2.0;
 m_xt1:=x1;
 m_yt1:=y2 - m_text_height * 2.0;
 m_xt2:=x2;
 m_yt2:=y2;

 m_gamma_spline.Construct;
 m_ellipse.Construct;
 m_curve_poly.Construct(@m_gamma_spline );
 m_text.Construct;
 m_text_poly.Construct (@m_text );

 m_idx   :=0;
 m_vertex:=0;

 m_p1_active  :=true;
 m_mouse_point:=0;

 m_pdx:=0.0;
 m_pdy:=0.0;

 calc_spline_box;

end;

{ DESTRUCT }
destructor gamma_ctrl_impl.Destruct;
begin
 m_gamma_spline.Destruct;
 m_curve_poly.Destruct;
 m_text.Destruct;
 m_text_poly.Destruct;

end;

{ BORDER_WIDTH_ }
procedure gamma_ctrl_impl.border_width_;
begin
 m_border_width:=t;
 m_border_extra:=extra;

 calc_spline_box;

end;

{ CURVE_WIDTH_ }
procedure gamma_ctrl_impl.curve_width_;
begin
 m_curve_width:=t;

end;

{ GRID_WIDTH_ }
procedure gamma_ctrl_impl.grid_width_;
begin
 m_grid_width:=t;

end;

{ TEXT_THICKNESS_ }
procedure gamma_ctrl_impl.text_thickness_;
begin
 m_text_thickness:=t;

end;

{ TEXT_SIZE_ }
procedure gamma_ctrl_impl.text_size_;
begin
 m_text_width :=w;
 m_text_height:=h;

 m_yc2:=m_y2 - m_text_height * 2.0;
 m_yt1:=m_y2 - m_text_height * 2.0;

 calc_spline_box;

end;

{ POINT_SIZE_ }
procedure gamma_ctrl_impl.point_size_;
begin
 m_point_size:=s;

end;

{ IN_RECT }
function gamma_ctrl_impl.in_rect;
begin
 inverse_transform_xy(@x ,@y );

 result:=
  (x >= m_x1 ) and
  (x <= m_x2 ) and
  (y >= m_y1 ) and
  (y <= m_y2 );

end;

{ ON_MOUSE_BUTTON_DOWN }
function gamma_ctrl_impl.on_mouse_button_down;
begin
 inverse_transform_xy(@x ,@y );
 calc_points;

 if calc_distance(x ,y ,m_xp1 ,m_yp1 ) <= m_point_size + 1 then
  begin
   m_mouse_point:=1;

   m_pdx:=m_xp1 - x;
   m_pdy:=m_yp1 - y;

   m_p1_active:=true;

   result:=true;

   exit;

  end;

 if calc_distance(x ,y ,m_xp2 ,m_yp2 ) <= m_point_size + 1 then
  begin
   m_mouse_point:=2;

   m_pdx:=m_xp2 - x;
   m_pdy:=m_yp2 - y;

   m_p1_active:=false;

   result:=true;

   exit;

  end;

 result:=false;

end;

{ ON_MOUSE_BUTTON_UP }
function gamma_ctrl_impl.on_mouse_button_up;
begin
 if m_mouse_point <> 0 then
  begin
   m_mouse_point:=0;

   result:=true;

  end
 else
  result:=false;

end;

{ ON_MOUSE_MOVE }
function gamma_ctrl_impl.on_mouse_move;
begin
 inverse_transform_xy(@x ,@y );

 if not button_flag then
  result:=on_mouse_button_up(x ,y )
 else
  begin
   if m_mouse_point = 1 then
    begin
     m_xp1:=x + m_pdx;
     m_yp1:=y + m_pdy;

     calc_values;

     result:=true;

     exit;

    end;

   if m_mouse_point = 2 then
    begin
     m_xp2:=x + m_pdx;
     m_yp2:=y + m_pdy;

     calc_values;

     result:=true;

     exit;

    end;

   result:=false;

  end;

end;

{ ON_ARROW_KEYS }
function gamma_ctrl_impl.on_arrow_keys;
var
 kx1 ,ky1 ,kx2 ,ky2 : double;

 ret : boolean;

begin
 ret:=false;

 m_gamma_spline.values(@kx1 ,@ky1 ,@kx2 ,@ky2 );

 if m_p1_active then
  begin
   if left then
    begin
     kx1:=kx1 - 0.005;
     ret:=true;

    end;

   if right then
    begin
     kx1:=kx1 + 0.005;
     ret:=true;

    end;

   if down then
    begin
     ky1:=ky1 - 0.005;
     ret:=true;

    end;

   if up then
    begin
     ky1:=ky1 + 0.005;
     ret:=true;
     
    end;

  end
 else
  begin
   if left then
    begin
     kx2:=kx2 + 0.005;
     ret:=true;

    end;

   if right then
    begin
     kx2:=kx2 - 0.005;
     ret:=true;

    end;

   if down then
    begin
     ky2:=ky2 + 0.005;
     ret:=true;

    end;

   if up then
    begin
     ky2:=ky2 - 0.005;
     ret:= true;

    end;

  end;

 if ret then
  m_gamma_spline.values(kx1 ,ky1 ,kx2 ,ky2 );

 result:=ret;

end;

{ CHANGE_ACTIVE_POINT }
procedure gamma_ctrl_impl.change_active_point;
begin
 if m_p1_active then
  m_p1_active:=false
 else
  m_p1_active:=true;

end;

{ VALUES }
procedure gamma_ctrl_impl.values(kx1 ,ky1 ,kx2 ,ky2 : double );
begin
 m_gamma_spline.values(kx1 ,ky1 ,kx2 ,ky2 );

end;

{ VALUES }
procedure gamma_ctrl_impl.values(kx1 ,ky1 ,kx2 ,ky2 : double_ptr );
begin
 m_gamma_spline.values(kx1 ,ky1 ,kx2 ,ky2 );

end;

{ GAMMA }
function gamma_ctrl_impl.gamma;
begin
 result:=m_gamma_spline.gamma;

end;

{ _Y }
function gamma_ctrl_impl._y;
begin
 result:=m_gamma_spline._y(x );

end;

{ FUNC_OPERATOR_GAMMA }
function gamma_ctrl_impl.func_operator_gamma;
begin
 result:=m_gamma_spline._y(x );

end;

{ NUM_PATHS }
function gamma_ctrl_impl.num_paths;
begin
 result:=7;

end;

{ REWIND }
procedure gamma_ctrl_impl.rewind;
var
 kx1 ,ky1 ,kx2 ,ky2 : double;

 tbuf : array[0..31 ]  of char;

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

    m_vx[0  ]:=m_x1;
    m_vy[0  ]:=m_y1;
    m_vx[1  ]:=m_x2;
    m_vy[1  ]:=m_y1;
    m_vx[2  ]:=m_x2;
    m_vy[2  ]:=m_y2;
    m_vx[3  ]:=m_x1;
    m_vy[3  ]:=m_y2;
    m_vx[4  ]:=m_x1 + m_border_width;
    m_vy[4  ]:=m_y1 + m_border_width;
    m_vx[5  ]:=m_x1 + m_border_width;
    m_vy[5  ]:=m_y2 - m_border_width;
    m_vx[6  ]:=m_x2 - m_border_width;
    m_vy[6  ]:=m_y2 - m_border_width;
    m_vx[7  ]:=m_x2 - m_border_width;
    m_vy[7  ]:=m_y1 + m_border_width;
    m_vx[8  ]:=m_xc1 + m_border_width;
    m_vy[8  ]:=m_yc2 - m_border_width * 0.5;
    m_vx[9  ]:=m_xc2 - m_border_width;
    m_vy[9  ]:=m_yc2 - m_border_width * 0.5;
    m_vx[10 ]:=m_xc2 - m_border_width;
    m_vy[10 ]:=m_yc2 + m_border_width * 0.5;
    m_vx[11 ]:=m_xc1 + m_border_width;
    m_vy[11 ]:=m_yc2 + m_border_width * 0.5;

   end;

  2 : // Curve
   begin
    m_gamma_spline.box(m_xs1 ,m_ys1 ,m_xs2 ,m_ys2 );

    m_curve_poly.width_(m_curve_width );
    m_curve_poly.rewind(0 );

   end;

  3 : // Grid
   begin
    m_vertex:=0;

    m_vx[0 ]:=m_xs1;
    m_vy[0 ]:=(m_ys1 + m_ys2) * 0.5 - m_grid_width * 0.5;
    m_vx[1 ]:=m_xs2;
    m_vy[1 ]:=(m_ys1 + m_ys2) * 0.5 - m_grid_width * 0.5;
    m_vx[2 ]:=m_xs2;
    m_vy[2 ]:=(m_ys1 + m_ys2) * 0.5 + m_grid_width * 0.5;
    m_vx[3 ]:=m_xs1;
    m_vy[3 ]:=(m_ys1 + m_ys2) * 0.5 + m_grid_width * 0.5;
    m_vx[4 ]:=(m_xs1 + m_xs2) * 0.5 - m_grid_width * 0.5;
    m_vy[4 ]:=m_ys1;
    m_vx[5 ]:=(m_xs1 + m_xs2) * 0.5 - m_grid_width * 0.5;
    m_vy[5 ]:=m_ys2;
    m_vx[6 ]:=(m_xs1 + m_xs2) * 0.5 + m_grid_width * 0.5;
    m_vy[6 ]:=m_ys2;
    m_vx[7 ]:=(m_xs1 + m_xs2) * 0.5 + m_grid_width * 0.5;
    m_vy[7 ]:=m_ys1;

    calc_points;

    m_vx[8  ]:=m_xs1;
    m_vy[8  ]:=m_yp1 - m_grid_width * 0.5;
    m_vx[9  ]:=m_xp1 - m_grid_width * 0.5;
    m_vy[9  ]:=m_yp1 - m_grid_width * 0.5;
    m_vx[10 ]:=m_xp1 - m_grid_width * 0.5;
    m_vy[10 ]:=m_ys1;
    m_vx[11 ]:=m_xp1 + m_grid_width * 0.5;
    m_vy[11 ]:=m_ys1;
    m_vx[12 ]:=m_xp1 + m_grid_width * 0.5;
    m_vy[12 ]:=m_yp1 + m_grid_width * 0.5;
    m_vx[13 ]:=m_xs1;
    m_vy[13 ]:=m_yp1 + m_grid_width * 0.5;
    m_vx[14 ]:=m_xs2;
    m_vy[14 ]:=m_yp2 + m_grid_width * 0.5;
    m_vx[15 ]:=m_xp2 + m_grid_width * 0.5;
    m_vy[15 ]:=m_yp2 + m_grid_width * 0.5;
    m_vx[16 ]:=m_xp2 + m_grid_width * 0.5;
    m_vy[16 ]:=m_ys2;
    m_vx[17 ]:=m_xp2 - m_grid_width * 0.5;
    m_vy[17 ]:=m_ys2;
    m_vx[18 ]:=m_xp2 - m_grid_width * 0.5;
    m_vy[18 ]:=m_yp2 - m_grid_width * 0.5;
    m_vx[19 ]:=m_xs2;
    m_vy[19 ]:=m_yp2 - m_grid_width * 0.5;

   end;

  4 : // Point1
   begin
    calc_points;

    if m_p1_active then
     m_ellipse.init(m_xp2 ,m_yp2 ,m_point_size ,m_point_size ,32 )
    else
     m_ellipse.init(m_xp1 ,m_yp1 ,m_point_size ,m_point_size ,32 );

   end;

  5 : // Point2
   begin
    calc_points;

    if m_p1_active then
     m_ellipse.init(m_xp1 ,m_yp1 ,m_point_size ,m_point_size ,32 )
    else
     m_ellipse.init(m_xp2 ,m_yp2 ,m_point_size ,m_point_size ,32 );

   end;

  6 : // Text
   begin
    m_gamma_spline.values(@kx1 ,@ky1 ,@kx2 ,@ky2 );

    sprintf(@tbuf[0] , '%.3f '#0 ,kx1 );
    sprintf(@tbuf[StrLen(@tbuf[0 ] ) ] ,'%.3f '#0 ,ky1 );
    sprintf(@tbuf[StrLen(@tbuf[0 ] ) ] ,'%.3f '#0 ,kx2 );
    sprintf(@tbuf[StrLen(@tbuf[0 ] ) ] ,'%.3f'#0 ,ky2 );

    m_text.text_(@tbuf[0 ] );
    m_text.size_(m_text_height ,m_text_width );

    m_text.start_point_(m_xt1 + m_border_width * 2.0 ,(m_yt1 + m_yt2 ) * 0.5 - m_text_height * 0.5 );
    m_text_poly.width_(m_text_thickness );

    m_text_poly.line_join_(round_join );
    m_text_poly.line_cap_ (round_cap );

    m_text_poly.rewind(0);

   end;

 end;

end;

{ VERTEX }
function gamma_ctrl_impl.vertex;
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
       (m_vertex = 4 ) or
       (m_vertex = 8 ) then
     cmd:=path_cmd_move_to;

    if m_vertex >= 12 then
     cmd:=path_cmd_stop;

    x^:=m_vx[m_vertex ];
    y^:=m_vy[m_vertex ];

    inc(m_vertex );

   end;

  2 :
   cmd:=m_curve_poly.vertex(x ,y );

  3 :
   begin
    if (m_vertex = 0 ) or
       (m_vertex = 4 ) or
       (m_vertex = 8 ) or
       (m_vertex = 14 ) then
     cmd:=path_cmd_move_to;

    if m_vertex >= 20 then
     cmd:=path_cmd_stop;

    x^:=m_vx[m_vertex ];
    y^:=m_vy[m_vertex ];

    inc(m_vertex );

   end;

  4 ,5 :
   cmd:=m_ellipse.vertex(x ,y );

  6 :
   cmd:=m_text_poly.vertex(x ,y );

  else
   cmd:=path_cmd_stop;

 end;

 if not is_stop(cmd ) then
  transform_xy(x ,y );

 result:=cmd;

end;

{ CALC_SPLINE_BOX }
procedure gamma_ctrl_impl.calc_spline_box;
begin
 m_xs1:=m_xc1 + m_border_width;
 m_ys1:=m_yc1 + m_border_width;
 m_xs2:=m_xc2 - m_border_width;
 m_ys2:=m_yc2 - m_border_width * 0.5;

end;

{ CALC_POINTS }
procedure gamma_ctrl_impl.calc_points;
var
 kx1 ,ky1 ,kx2 ,ky2 : double;

begin
 m_gamma_spline.values(@kx1 ,@ky1 ,@kx2 ,@ky2 );

 m_xp1:=m_xs1 + (m_xs2 - m_xs1 ) * kx1 * 0.25;
 m_yp1:=m_ys1 + (m_ys2 - m_ys1 ) * ky1 * 0.25;
 m_xp2:=m_xs2 - (m_xs2 - m_xs1 ) * kx2 * 0.25;
 m_yp2:=m_ys2 - (m_ys2 - m_ys1 ) * ky2 * 0.25;

end;

{ CALC_VALUES }
procedure gamma_ctrl_impl.calc_values;
var
 kx1 ,ky1 ,kx2 ,ky2 : double;

begin
 kx1:=(m_xp1 - m_xs1 ) * 4.0 / (m_xs2 - m_xs1 );
 ky1:=(m_yp1 - m_ys1 ) * 4.0 / (m_ys2 - m_ys1 );
 kx2:=(m_xs2 - m_xp2 ) * 4.0 / (m_xs2 - m_xs1 );
 ky2:=(m_ys2 - m_yp2 ) * 4.0 / (m_ys2 - m_ys1 );

 m_gamma_spline.values(kx1 ,ky1 ,kx2 ,ky2 );

end;

{ CONSTRUCT }
constructor gamma_ctrl.Construct;
begin
 inherited Construct(x1 ,y1 ,x2 ,y2 ,flip_y );

 m_background_color.ConstrDbl  (1.0 ,1.0 ,0.9 );
 m_border_color.ConstrDbl      (0.0 ,0.0 ,0.0 );
 m_curve_color.ConstrDbl       (0.0 ,0.0 ,0.0 );
 m_grid_color.ConstrDbl        (0.2 ,0.2 ,0.0 );
 m_inactive_pnt_color.ConstrDbl(0.0 ,0.0 ,0.0 );
 m_active_pnt_color.ConstrDbl  (1.0 ,0.0 ,0.0 );
 m_text_color.ConstrDbl        (0.0 ,0.0 ,0.0 );

 m_colors[0 ]:=@m_background_color;
 m_colors[1 ]:=@m_border_color;
 m_colors[2 ]:=@m_curve_color;
 m_colors[3 ]:=@m_grid_color;
 m_colors[4 ]:=@m_inactive_pnt_color;
 m_colors[5 ]:=@m_active_pnt_color;
 m_colors[6 ]:=@m_text_color;

end;

{ BACKGROUND_COLOR_ }
procedure gamma_ctrl.background_color_;
begin
 m_background_color:=c^;

end;

{ BORDER_COLOR_ }
procedure gamma_ctrl.border_color_;
begin
 m_border_color:=c^;

end;

{ CURVE_COLOR_ }
procedure gamma_ctrl.curve_color_;
begin
 m_curve_color:=c^;

end;

{ GRID_COLOR_ }
procedure gamma_ctrl.grid_color_;
begin
 m_grid_color:=c^;

end;

{ INACTIVE_PNT_COLOR_ }
procedure gamma_ctrl.inactive_pnt_color_;
begin
 m_inactive_pnt_color:=c^;

end;

{ ACTIVE_PNT_COLOR_ }
procedure gamma_ctrl.active_pnt_color_;
begin
 m_active_pnt_color:=c^;

end;

{ TEXT_COLOR_ }
procedure gamma_ctrl.text_color_;
begin
 m_text_color:=c^;

end;

{ _COLOR }
function gamma_ctrl._color;
begin
 result:=m_colors[i ];

end;

END.

