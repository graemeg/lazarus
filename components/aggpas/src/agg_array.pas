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
// 23.06.2006-Milano: ptrcomp adjustments
// 18.02.2006-MIlano: pod_array_adaptor, quick_sort
// 16.02.2006-Milano: pod_allocator
// 19.12.2005-Milano: pod_deque
// 15.11.2005-Milano: Unit port establishment
//
{ agg_array.pas }
unit
 agg_array ;

INTERFACE

{$I agg_mode.inc }

uses
 agg_basics ;

{ TYPES DEFINITION }
type
 func_less  = function(e1 ,e2 : pointer ) : boolean;
 func_equal = function(e1 ,e2 : pointer ) : boolean;

 array_base_ptr = ^array_base;
 array_base = object
   function  size : unsigned; virtual; abstract;
   function  entry : unsigned; virtual; abstract;
   function  array_operator(i : unsigned ) : pointer; virtual; abstract;

   function  at(i : unsigned ) : pointer; virtual;

  end;

//----------------------------------------------------------range_adaptor
 range_adaptor = object(array_base )
  private
   m_array : array_base_ptr;
   m_start ,
   m_size  : unsigned;

  public
   constructor Construct(array_ : array_base_ptr; start ,size_ : unsigned );

   function  size : unsigned; virtual;
   function  entry : unsigned; virtual;
   function  array_operator(i : unsigned ) : pointer; virtual;

  end;

//-------------------------------------------------------pod_array_adaptor
 pod_array_adaptor_ptr = ^pod_array_adaptor;
 pod_array_adaptor = object(array_base )
   m_array : pointer;
   m_size  ,
   m_entry : unsigned;

   constructor Construct(array_ : pointer; size_ ,entry_ : unsigned );

   function  size : unsigned; virtual;
   function  entry : unsigned; virtual;
   function  array_operator(i : unsigned ) : pointer; virtual;
   
   function  at(i : unsigned ) : pointer; virtual;

  end;

//---------------------------------------------------------pod_auto_array
 pod_auto_array_ptr = ^pod_auto_array;
 pod_auto_array = object(array_base )
   m_size     ,
   m_entry_sz : unsigned;

   m_array : pointer;

   constructor Construct(size_ ,entry_sz : unsigned );
   destructor  Destruct;

   function  size : unsigned; virtual;
   function  entry : unsigned; virtual;
   function  array_operator(i : unsigned ) : pointer; virtual;

  end;

//---------------------------------------------------------------pod_array
// A simple class template to store Plain Old Data, a vector
// of a fixed size. The data is continous in memory
//------------------------------------------------------------------------
 pod_array = object(array_base )
   m_entry_sz ,
   m_size     ,
   m_capacity : unsigned;

   m_array : pointer;

   constructor Construct(entry_sz : unsigned ); overload;
   constructor Construct(entry_sz ,size_ : unsigned ); overload;
   constructor Create   (entry_sz ,size_ : unsigned );
   destructor  Destruct;

   procedure allocate(size_ : unsigned; extra_tail : unsigned = 0 );
   procedure resize  (new_size : unsigned );
   procedure capacity(cap ,extra_tail : unsigned );

   procedure zero;
   procedure add(v : pointer );
   function  data : pointer;

   function  size : unsigned; virtual;
   function  entry : unsigned; virtual;
   function  array_operator(i : unsigned ) : pointer; virtual;

  end;

 pod_vector = pod_array;

//---------------------------------------------------------------pod_deque
// A simple class template to store Plain Old Data, similar to std::deque
// It doesn't reallocate memory but instead, uses blocks of data of size
// of (1 << S), that is, power of two. The data is NOT contiguous in memory,
// so the only valid access method is operator [] or curr(), prev(), next()
//
// There reallocs occur only when the pool of pointers to blocks needs
// to be extended (it happens very rarely). You can control the value
// of increment to reallocate the pointer buffer. See the second constructor.
// By default, the incremeent value equals (1 << S), i.e., the block size.
//------------------------------------------------------------------------
 pod_deque_ptr = ^pod_deque;
 pod_deque = object(array_base )
   block_shift ,
   block_size  ,
   block_mask  : unsigned;

   m_size          ,
   m_num_blocks    ,
   m_max_blocks    ,
   m_block_ptr_inc : unsigned;

   m_blocks : pointer;

   m_entry_sz : unsigned;

   constructor Construct(entry_sz : unsigned; s_ : unsigned = 6 ); overload;
   constructor Construct(block_ptr_inc ,entry_sz : unsigned; s_ : unsigned ); overload;
   destructor  Destruct;

   procedure remove_all;
   procedure remove_last;

   procedure add        (val : pointer );
   procedure modify_last(val : pointer );

   procedure cut_at(size_ : unsigned );

   function  size : unsigned; virtual;
   function  entry : unsigned; virtual;

   function  array_operator (i : unsigned ) : pointer; virtual;
   procedure assign_operator(v : pod_deque_ptr );

   function  curr(idx : unsigned ) : pointer;
   function  prev(idx : unsigned ) : pointer;
   function  next(idx : unsigned ) : pointer;
   function  last : pointer;

   function  allocate_continuous_block(num_elements : unsigned ) : int;
   procedure allocate_block           (nb : unsigned );

   function  data_ptr : pointer;

  end;

 pod_bvector_ptr = ^pod_bvector; 
 pod_bvector = pod_deque; 

//-----------------------------------------------------------pod_allocator
// Allocator for arbitrary POD data. Most usable in different cache
// systems for efficient memory allocations.
// Memory is allocated with blocks of fixed size ("block_size" in
// the constructor). If required size exceeds the block size the allocator
// creates a new block of the required size. However, the most efficient
// use is when the average reqired size is much less than the block size.
//------------------------------------------------------------------------
 pod_alloc_ptr = ^pod_alloc;
 pod_alloc = record
   ptr : int8u_ptr;
   sz  : unsigned;

  end;

 pod_allocator = object
   m_block_size    ,
   m_block_ptr_inc ,
   m_num_blocks    ,
   m_max_blocks    : unsigned;

   m_blocks  : pod_alloc_ptr;
   m_buf_ptr : int8u_ptr;

   m_rest : unsigned;

   constructor Construct(block_size : unsigned; block_ptr_inc : unsigned = 256 - 8 );
   destructor  Destruct;

   procedure remove_all;

   function  allocate(size : unsigned; alignment : unsigned = 1 ) : int8u_ptr;

   procedure allocate_block(size : unsigned );

  end;

{ GLOBAL VARIABLES & CONSTANTS }
{ GLOBAL PROCEDURES }
 procedure quick_sort       (arr : array_base_ptr; less : func_less );
 function  remove_duplicates(arr : array_base_ptr; equal : func_equal ) : unsigned;

 function  int_less   (a ,b : pointer ) : boolean;
 function  int_greater(a ,b : pointer ) : boolean;

 function  unsigned_less   (a ,b : pointer ) : boolean;
 function  unsigned_greater(a ,b : pointer ) : boolean;

IMPLEMENTATION
{ LOCAL VARIABLES & CONSTANTS }
{ QUICK_SORT }
procedure quick_sort;
const
 quick_sort_threshold = 9;

type
 int80_ptr = ^int80;
 int80 = array[0..79 ] of int;

var
 temp ,e1 ,e2 : pointer;

 swap : unsigned;

 stack : int80;

 top : int80_ptr;

 limit ,base ,len ,i ,j ,pivot : int;

begin
 if arr.size < 2 then
  exit;

 agg_getmem(temp ,arr.entry );

 swap :=arr.entry;
 top  :=@stack;
 limit:=arr.size;
 base :=0;

 repeat
  len:=limit - base;

  if len > quick_sort_threshold then
   begin
   // we use base + len/2 as the pivot
    pivot:=base + len div 2;

   // swap_elements(arr[base], arr[pivot]);
    move(arr.at(base )^ ,temp^ ,swap );
    move(arr.at(pivot )^ ,arr.at(base )^ ,swap );
    move(temp^ ,arr.at(pivot )^ ,swap );

    i:=base + 1;
    j:=limit - 1;

   // now ensure that *i <= *base <= *j
    e1:=arr.at(j );
    e2:=arr.at(i );

    if less(e1 ,e2 ) then
     begin
     // swap_elements(*e1, *e2);
      move(e1^ ,temp^ ,swap );
      move(e2^ ,e1^ ,swap );
      move(temp^ ,e2^ ,swap );

     end;

    e1:=arr.at(base );
    e2:=arr.at(i );

    if less(e1 ,e2 ) then
     begin
     // swap_elements(*e1, *e2);
      move(e1^ ,temp^ ,swap );
      move(e2^ ,e1^ ,swap );
      move(temp^ ,e2^ ,swap );

     end;

    e1:=arr.at(j );
    e2:=arr.at(base );

    if less(e1 ,e2 ) then
     begin
     // swap_elements(*e1, *e2);
      move(e1^ ,temp^ ,swap );
      move(e2^ ,e1^ ,swap );
      move(temp^ ,e2^ ,swap );

     end;

    repeat
     repeat
      inc(i )

     until not less(arr.at(i ) ,arr.at(base ) );

     repeat
      dec(j );

     until not less(arr.at(base ) ,arr.at(j ) );

     if i > j then
      break;

    // swap_elements(arr[i], arr[j]);
     move(arr.at(i )^ ,temp^ ,swap );
     move(arr.at(j )^ ,arr.at(i )^ ,swap );
     move(temp^ ,arr.at(j )^ ,swap );

    until false;

   // swap_elements(arr[base], arr[j]);
    move(arr.at(base )^ ,temp^ ,swap );
    move(arr.at(j )^ ,arr.at(base )^ ,swap );
    move(temp^ ,arr.at(j )^ ,swap );

   // now, push the largest sub-array
    if j - base > limit - i then
     begin
      top^[0 ]:=base;
      top^[1 ]:=j;
      base    :=i;
      
     end
    else
     begin
      top^[0 ]:=i;
      top^[1 ]:=limit;
      limit   :=j;

     end;

    inc(ptrcomp(top ) ,2 * sizeof(int ) );

   end
  else
   begin
   // the sub-array is small, perform insertion sort
    j:=base;
    i:=j + 1;

    while i < limit do
     begin
      e1:=arr.at(j + 1 );
      e2:=arr.at(j );

      while less(e1 ,e2 ) do
       begin
       // swap_elements(*e1, *e2);
        move(e1^ ,temp^ ,swap );
        move(e2^ ,e1^ ,swap );
        move(temp^ ,e2^ ,swap );

        if j = base then
         break;

        dec(j );

        e1:=arr.at(j + 1 );
        e2:=arr.at(j );

       end;

      j:=i;

      inc(i );

     end;

    if ptrcomp(top ) > ptrcomp(@stack ) then
     begin
      dec(ptrcomp(top ) ,2 * sizeof(int ) );

      base :=top^[0 ];
      limit:=top^[1 ];

     end
    else
     break;

   end;

 until false;

 agg_freemem(temp ,arr.entry );

end;

{ REMOVE_DUPLICATES }
// Remove duplicates from a sorted array. It doesn't cut the
// tail of the array, it just returns the number of remaining elements.
function remove_duplicates(arr : array_base_ptr; equal : func_equal ) : unsigned;
var
 i ,j : unsigned;

 e : pointer;

begin
 if arr.size < 2 then
  begin
   result:=arr.size;

   exit;

  end;

 i:=1;
 j:=1;

 while i < arr.size do
  begin
   e:=arr.array_operator(i );

   if not equal(e ,arr.array_operator(i - 1 ) ) then
    begin
     move(e^ ,arr.array_operator(j )^ ,arr.entry );
     inc (j );

    end;

   inc(i );

  end;

 result:=j;

end;

{ INT_LESS }
function int_less(a ,b : pointer ) : boolean;
begin
 result:=int_ptr(a )^ < int_ptr(b )^;

end;

{ INT_GREATER }
function int_greater(a ,b : pointer ) : boolean;
begin
 result:=int_ptr(a )^ > int_ptr(b )^;

end;

{ UNSIGNED_LESS }
function unsigned_less(a ,b : pointer ) : boolean;
begin
 result:=unsigned_ptr(a )^ < unsigned_ptr(b )^;

end;

{ UNSIGNED_GREATER }
function unsigned_greater(a ,b : pointer ) : boolean;
begin
 result:=unsigned_ptr(a )^ > unsigned_ptr(b )^;

end;

{ UNIT IMPLEMENTATION }
{ AT }
function array_base.at;
begin
 at:=array_operator(i );

end;

{ CONSTRUCT }
constructor range_adaptor.Construct(array_ : array_base_ptr; start ,size_ : unsigned );
begin
 m_array:=array_;
 m_start:=start;
 m_size :=size_;

end;

{ SIZE }
function range_adaptor.size : unsigned;
begin
 result:=m_size;

end;

{ ENTRY }
function range_adaptor.entry : unsigned;
begin
 result:=m_array.entry;

end;

{ ARRAY_OPERATOR }
function range_adaptor.array_operator(i : unsigned ) : pointer;
begin
 result:=m_array.array_operator(m_start + i );

end;

{ CONSTRUCT }
constructor pod_array_adaptor.Construct;
begin
 m_array:=array_;
 m_size :=size_;
 m_entry:=entry_;

end;

{ SIZE }
function pod_array_adaptor.size;
begin
 result:=m_size;

end;

{ ENTRY }
function pod_array_adaptor.entry;
begin
 result:=m_entry;

end;

{ ARRAY_OPERATOR }
function pod_array_adaptor.array_operator;
begin
 result:=pointer(ptrcomp(m_array ) + i * sizeof(m_entry ) );

end;

{ AT }
function pod_array_adaptor.at;
begin
 result:=pointer(ptrcomp(m_array ) + i * m_entry );

end;

{ CONSTRUCT }
constructor pod_auto_array.Construct;
begin
 m_size    :=size_;
 m_entry_sz:=entry_sz;

 agg_getmem(m_array ,m_size * m_entry_sz );

end;

{ DESTRUCT }
destructor pod_auto_array.Destruct;
begin
 agg_freemem(m_array ,m_size * m_entry_sz );

end;

{ SIZE }
function pod_auto_array.size;
begin
 result:=m_size;

end;

{ ENTRY }
function pod_auto_array.entry;
begin
 result:=m_entry_sz;

end;

{ ARRAY_OPERATOR }
function pod_auto_array.array_operator;
begin
 result:=pointer(ptrcomp(m_array ) + i * m_entry_sz );

end;

{ CONSTRUCT }
constructor pod_array.Construct(entry_sz : unsigned );
begin
 m_entry_sz:=entry_sz;
 m_size    :=0;
 m_capacity:=0;

 m_array:=NIL;

end;

{ CONSTRUCT }
constructor pod_array.Construct(entry_sz ,size_ : unsigned );
begin
 Construct(entry_sz );
 allocate (size_ );

end;

{ CREATE }
constructor pod_array.Create(entry_sz ,size_ : unsigned );
begin
 Construct(entry_sz );
 capacity (size_ ,0 );

end;

{ DESTRUCT }
destructor pod_array.Destruct;
begin
 if m_array <> NIL then
  agg_freemem(m_array ,m_capacity * m_entry_sz );

end;

{ ALLOCATE }
// Allocate n elements. All data is lost,
// but elements can be accessed in range 0...size-1.
procedure pod_array.allocate;
begin
 capacity(size_ ,extra_tail );

 m_size:=size_;

end;

{ RESIZE }
// Resize keeping the content.
procedure pod_array.resize;
var
 buff : pointer;

begin
 if new_size > m_size then
  if new_size > m_capacity then
   begin
    agg_getmem(buff ,new_size * m_entry_sz );

    if m_array <> NIL then
     begin
      move(m_array^ ,buff^ ,m_size * m_entry_sz );

      agg_freemem(m_array ,m_capacity * m_entry_sz );

     end; 

    m_array   :=buff;
    m_capacity:=new_size;

   end
  else
 else
  m_size:=new_size;

end;

{ CAPACITY }
procedure pod_array.capacity;
begin
 m_size:=0;

 if cap > m_capacity then
  begin
   agg_freemem(m_array ,m_capacity * m_entry_sz );

   m_capacity:=cap + extra_tail;

   if m_capacity > 0 then
    agg_getmem(m_array ,m_capacity * m_entry_sz )
   else
    m_array:=0;

  end;

end;

{ ZERO }
procedure pod_array.zero;
begin
 fillchar(m_array^ ,m_entry_sz * m_size ,0 );

end;

{ ADD }
procedure pod_array.add(v : pointer );
begin
 move(v^ ,pointer(ptrcomp(m_array ) + m_size  * m_entry_sz )^ ,m_entry_sz );
 inc (m_size );

end;

{ DATA }
function pod_array.data;
begin
 result:=m_array;

end;

{ SIZE }
function pod_array.size;
begin
 result:=m_size;

end;

{ ENTRY }
function pod_array.entry;
begin
 result:=m_entry_sz;

end;

{ ARRAY_OPERATOR }
function pod_array.array_operator(i : unsigned ) : pointer;
begin
 result:=pointer(ptrcomp(m_array ) + i * m_entry_sz );

end;

{ CONSTRUCT }
constructor pod_deque.Construct(entry_sz : unsigned; s_ : unsigned = 6 );
begin
 block_shift:=s_;
 block_size :=1 shl block_shift;
 block_mask :=block_size - 1;

 m_size         :=0;
 m_num_blocks   :=0;
 m_max_blocks   :=0;
 m_blocks       :=0;
 m_block_ptr_inc:=block_size;

 m_entry_sz:=entry_sz;

end;

{ CONSTRUCT }
constructor pod_deque.Construct(block_ptr_inc ,entry_sz : unsigned; s_ : unsigned );
begin
 Construct(entry_sz ,s_ );

 m_block_ptr_inc:=block_ptr_inc;

end;

{ DESTRUCT }
destructor pod_deque.Destruct;
var
 blk : pointer;

begin
 if m_num_blocks <> 0 then
  begin
   blk:=pointer(ptrcomp(m_blocks ) + (m_num_blocks - 1 ) * sizeof(pointer ) );

   while m_num_blocks <> 0 do
    begin
     agg_freemem(p32(blk^ ).ptr ,block_size * m_entry_sz );

     dec(ptrcomp(blk ) ,sizeof(pointer ) );
     dec(m_num_blocks );

    end;

   agg_freemem(m_blocks ,m_max_blocks * sizeof(pointer ) );

  end;

end;

{ REMOVE_ALL }
procedure pod_deque.remove_all;
begin
 m_size:=0;

end;

{ REMOVE_LAST }
procedure pod_deque.remove_last;
begin
 if m_size <> 0 then
  dec(m_size );

end;

{ ADD }
procedure pod_deque.add;
var
 p : pointer;

begin
 p:=data_ptr;

 move(val^ ,p^ ,m_entry_sz );
 inc (m_size );

end;

{ MODIFY_LAST }
procedure pod_deque.modify_last;
begin
 remove_last;
 add(val );

end;

{ CUT_AT }
procedure pod_deque.cut_at(size_ : unsigned );
begin
 if size_ < m_size then
  m_size:=size_;

end;

{ SIZE }
function pod_deque.size;
begin
 result:=m_size;

end;

{ ENTRY }
function pod_deque.entry;
begin
 result:=m_entry_sz;

end;

{ ARRAY_OPERATOR }
function pod_deque.array_operator;
begin
 result:=
  pointer(
   p32(pointer(ptrcomp(m_blocks ) + (i shr block_shift ) * sizeof(pointer ) )^ ).int
   + (i and block_mask ) * m_entry_sz );

end;

{ ASSIGN_OPERATOR }
procedure pod_deque.assign_operator;
var
 i   : unsigned;
 src ,
 dst : pointer;

begin
 Destruct;

 block_shift:=v.block_shift;
 block_size :=v.block_size;
 block_mask :=v.block_mask;

 m_size    :=v.m_size;
 m_entry_sz:=v.m_entry_sz;

 m_num_blocks:=v.m_num_blocks;
 m_max_blocks:=v.m_max_blocks;

 m_block_ptr_inc:=v.m_block_ptr_inc;

 if m_max_blocks <> 0 then
  agg_getmem(m_blocks ,m_max_blocks * sizeof(pointer ) )
 else
  m_blocks:=NIL;


 src:=v.m_blocks;
 dst:=m_blocks;
 i  :=0;

 while i < m_num_blocks do
  begin
   agg_getmem(p32(dst^ ).ptr ,block_size * m_entry_sz );

   move(
    p32(src^ ).ptr^ ,
    p32(dst^ ).ptr^ ,
    block_size * m_entry_sz );

   inc(ptrcomp(src ) ,sizeof(pointer ) );
   inc(ptrcomp(dst ) ,sizeof(pointer ) );
   inc(i );

  end;

end;

{ CURR }
function pod_deque.curr;
begin
 result:=array_operator(idx );

end;

{ PREV }
function pod_deque.prev;
begin
 result:=array_operator((idx + m_size - 1 ) mod m_size );

end;

{ NEXT }
function pod_deque.next;
begin
 result:=array_operator((idx + 1 ) mod m_size );

end;

{ LAST }
function pod_deque.last : pointer;
begin
 result:=array_operator(m_size - 1 );

end;

{ ALLOCATE_CONTINUOUS_BLOCK }
function pod_deque.allocate_continuous_block;
var
 rest ,index : unsigned;

begin
 if num_elements < block_size then
  begin
   data_ptr; // Allocate initial block if necessary

   rest:=block_size - (m_size and block_mask );

   if num_elements <= rest then
    begin
    // The rest of the block is good, we can use it
     index:=m_size;

     inc(m_size ,num_elements );

     result:=index;

     exit;

    end;

  // New block
   inc(m_size ,rest );

   data_ptr;

   index:=m_size;

   inc(m_size ,num_elements );

   result:=index;

   exit;

  end;

 result:=-1; // Impossible to allocate

end;

{ ALLOCATE_BLOCK }
procedure pod_deque.allocate_block;
var
 new_blocks : pointer;

begin
 if nb >= m_max_blocks then
  begin
   agg_getmem(new_blocks ,(m_max_blocks + m_block_ptr_inc ) * sizeof(pointer ) );

   if m_blocks <> NIL then
    begin
     move(
      m_blocks^ ,
      new_blocks^ ,
      m_num_blocks * sizeof(pointer ) );

     agg_freemem(m_blocks ,m_max_blocks * sizeof(pointer ) );

    end;

   m_blocks:=new_blocks;

   inc(m_max_blocks ,m_block_ptr_inc );

  end;

 agg_getmem(
  p32(pointer(ptrcomp(m_blocks ) + nb * sizeof(pointer ) )^ ).ptr ,
  block_size * m_entry_sz );

 inc(m_num_blocks );

end;

{ DATA_PTR }
function pod_deque.data_ptr;
var
 nb : unsigned;

begin
 nb:=m_size shr block_shift;

 if nb >= m_num_blocks then
  allocate_block(nb );

 result:=
  pointer(
   p32(pointer(ptrcomp(m_blocks ) + nb * sizeof(pointer ) )^ ).int
   + (m_size and block_mask ) * m_entry_sz );

end;

{ CONSTRUCT }
constructor pod_allocator.Construct;
begin
 m_block_size   :=block_size;
 m_block_ptr_inc:=block_ptr_inc;

 m_num_blocks:=0;
 m_max_blocks:=0;

 m_blocks :=NIL;
 m_buf_ptr:=NIL;
 m_rest   :=0;

end;

{ DESTRUCT }
destructor pod_allocator.Destruct;
begin
 remove_all;

end;

{ REMOVE_ALL }
procedure pod_allocator.remove_all;
var
 blk : pod_alloc_ptr;

begin
 if m_num_blocks <> 0 then
  begin
   blk:=pod_alloc_ptr(ptrcomp(m_blocks ) + (m_num_blocks - 1 ) * sizeof(pod_alloc ) );

   while m_num_blocks <> 0 do
    begin
     agg_freemem(pointer(blk.ptr ) ,blk.sz );

     dec(ptrcomp(blk ) ,sizeof(pod_alloc ) );
     dec(m_num_blocks );

    end;

   agg_freemem(pointer(m_blocks ) ,m_max_blocks * sizeof(pod_alloc ) );

  end;

 m_num_blocks:=0;
 m_max_blocks:=0;

 m_blocks :=NIL;
 m_buf_ptr:=NIL;
 m_rest   :=0;

end;

{ ALLOCATE }
function pod_allocator.allocate;
var
 ptr   : int8u_ptr;
 align : unsigned;

begin
 if size = 0 then
  begin
   result:=0;

   exit;

  end;

 if size <= m_rest then
  begin
   ptr:=m_buf_ptr;

   if alignment > 1 then
    begin
     align:=(alignment - unsigned(int32u(ptr ) ) mod alignment ) mod alignment;

     inc(size ,align );
     inc(ptrcomp(ptr ) ,align );

     if size <= m_rest then
      begin
       dec(m_rest ,size );
       inc(ptrcomp(m_buf_ptr ) ,size );

       result:=ptr;

       exit;

      end;

     allocate_block(size );

     result:=allocate(size - align ,alignment );

     exit;

    end;

   dec(m_rest ,size );
   inc(ptrcomp(m_buf_ptr ) ,size );

   result:=ptr;

   exit;

  end;

 allocate_block(size + alignment - 1 );

 result:=allocate(size ,alignment );

end;

{ ALLOCATE_BLOCK }
procedure pod_allocator.allocate_block;
var
 new_blocks : pod_alloc_ptr;

begin
 if size < m_block_size then
  size:=m_block_size;

 if m_num_blocks >= m_max_blocks then
  begin
   agg_getmem(pointer(new_blocks ) ,(m_max_blocks + m_block_ptr_inc ) * sizeof(pod_alloc ) );

   if m_blocks <> NIL then
    begin
     move(m_blocks^ ,new_blocks^ ,m_num_blocks * sizeof(pod_alloc ) );

     agg_freemem(pointer(m_blocks ) ,m_max_blocks * sizeof(pod_alloc ) );

    end;

   m_blocks:=new_blocks;

   inc(m_max_blocks ,m_block_ptr_inc );

  end;

 agg_getmem(pointer(m_buf_ptr ) ,size * sizeof(int8u ) );

 pod_alloc_ptr(ptrcomp(m_blocks ) + m_num_blocks * sizeof(pod_alloc ) ).ptr:=m_buf_ptr;
 pod_alloc_ptr(ptrcomp(m_blocks ) + m_num_blocks * sizeof(pod_alloc ) ).sz :=size;

 inc(m_num_blocks );

 m_rest:=size;

end;

END.

