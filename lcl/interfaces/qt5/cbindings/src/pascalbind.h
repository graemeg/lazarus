//******************************************************************************
//  Copyright (c) 2005-2013 by Jan Van hijfte
//
//  See the included file COPYING.TXT for details about the copyright.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//******************************************************************************



#ifndef PASCALBIND_H
#define PASCALBIND_H

#include <QtCore>
#include <QtGui>
#include <qapplication.h>

#include <qstring.h>
#include <qrect.h>
#include <qpoint.h>
#include <qsize.h>
#include <qlist.h>
#include <qvector.h>

#include "chandles.h"


#if defined(__WIN32__)
#define C_EXPORT extern "C" __declspec( dllexport )
#else
#define C_EXPORT extern "C"
#endif

#ifdef __WIN32__
#include <windows.h>
#endif

typedef bool (*EventFilter)(void *message, long *result);
typedef bool (*EventFilter2)(void *message);

#if defined(_LP64) || defined(__amd64__)
typedef long long int PTRINT;
typedef unsigned long long int PTRUINT;
#else
typedef int PTRINT;
typedef unsigned int PTRUINT;
#endif


typedef uint WFlags;
typedef int QCOORDH;

typedef struct {
  void *func;
  void *data;
} QHook;
typedef QHook QHookH;
typedef QHook QOverrideHook;
typedef QOverrideHook QOverrideHookH;

typedef struct {
  int x_or_y;
  int y_or_x;
} TQtPoint;
typedef TQtPoint *PQtPoint;

typedef struct {
  qreal x;
  qreal y;
} TQtPointF;
typedef TQtPointF *PQtPointF;

typedef struct {
  int cx;
  int cy;
} TSize;
typedef TSize *PSize;

typedef struct {
  unsigned short data;
} TQSizePolicy;
typedef TQSizePolicy *PQSizePolicy;

typedef struct {
    uint spec;
    ushort alpha;
    ushort red;
    ushort green;
    ushort blue;
    ushort pad;
} TQColor;
typedef TQColor *PQColor;


typedef struct {
  int start;
  int length;
} TTextRange;
typedef TTextRange *PTextRange;

#if defined DARWIN
typedef struct CGImage *CGImageRef;
#endif


//======================  
// WideString 
//======================  

typedef void *PWideString;
typedef void *PAnsiString;
typedef char *PAnsiChar;
typedef unsigned short *PWideChar;

typedef void (*CopyUnicodeToPWideString)(const QChar *unicode, PWideString ps, int len);
typedef PWideChar (*UnicodeOfPWideString)(PWideString ps);
typedef int (*LengthOfPWideString)(PWideString ps);
typedef void (*InitializePWideString)(PWideString &ps);
typedef void (*FinalizePWideString)(PWideString &ps);

extern CopyUnicodeToPWideString copyUnicodeToPWideString;
extern UnicodeOfPWideString unicodeOfPWideString;
extern LengthOfPWideString lengthOfPWideString;
extern InitializePWideString initPWideString;
extern FinalizePWideString finalPWideString;

inline void copyQStringToPWideString(const QString &qs, PWideString ps)
{
if (qs!=0 && ps) copyUnicodeToPWideString(qs.unicode(), ps, qs.length());
}


inline void copyPWideStringToQString(PWideString ps, QString &qs)
{
  qs.setUtf16((ushort *)unicodeOfPWideString(ps),
    lengthOfPWideString(ps));
}

inline void initializePWideString(PAnsiString &pws)
{
  initPWideString(pws);
}

inline void finalizePWideString(PWideString &pws)
{
  finalPWideString(pws);
}

C_EXPORT void initPWideStrings(CopyUnicodeToPWideString cutps,
  UnicodeOfPWideString uops, LengthOfPWideString lops,
  InitializePWideString ip, FinalizePWideString fp);


  
//=======================================================
// QRect
// Pascal  : left,top,right,bottom
// Qt        : left,top,right,bottom aka x1,y1,x2,y2
// Qt MAC: top,left,bottom,right aka y1,x1,y2,x2 
//=======================================================

typedef void *PRect;

inline void copyQRectToPRect(const QRect &qr, PRect pr)
{
#if defined OLDDARWIN
  ((QRect *)pr)->setLeft(qr.top());
  ((QRect *)pr)->setTop(qr.left());
  ((QRect *)pr)->setRight(qr.bottom()+1);
  ((QRect *)pr)->setBottom(qr.right()+1);
#else
  ((QRect *)pr)->setLeft(qr.left());
  ((QRect *)pr)->setTop(qr.top());
  ((QRect *)pr)->setRight(qr.right()+1);
  ((QRect *)pr)->setBottom(qr.bottom()+1);
#endif  
}

inline void copyPRectToQRect(PRect pr, QRect &qr)
{
#if defined OLDDARWIN
  qr.setLeft(((QRect *)pr)->top());
  qr.setTop(((QRect *)pr)->left());
  qr.setRight(((QRect *)pr)->bottom()-1);
  qr.setBottom(((QRect *)pr)->right()-1);
#else
  qr.setLeft(((QRect *)pr)->left());
  qr.setTop(((QRect *)pr)->top());
  qr.setRight(((QRect *)pr)->right()-1);
  qr.setBottom(((QRect *)pr)->bottom()-1);
#endif  
}

//=========================
// QList<T> vs PtrIntArray
//=========================  

typedef void *PPtrIntArray;
typedef void *(*GetPtrIntArrayAddr)(PPtrIntArray parr);
typedef int (*GetPtrIntArrayLength)(PPtrIntArray parr);
typedef void (*SetPtrIntArrayLength)(PPtrIntArray parr, int len);

extern GetPtrIntArrayAddr getPtrIntArrayAddr;
extern GetPtrIntArrayLength getPtrIntArrayLength;
extern SetPtrIntArrayLength setPtrIntArrayLength;


template <typename T>
Q_OUTOFLINE_TEMPLATE void copyQListTemplateToPtrIntArray(QList<T> &qlist, PPtrIntArray parr)
{
  int len = qlist.count();
  setPtrIntArrayLength(parr, len);
  if (len>0) {
    PTRINT *array = (PTRINT *)getPtrIntArrayAddr(parr);
    for (int i = 0; i < len; i++)
      array[i] = (PTRINT)qlist[i];
  }  
}



template <typename T>
Q_OUTOFLINE_TEMPLATE void copyPtrIntArrayToQListTemplate(PPtrIntArray parr,QList<T> &qlist)
{
  int len = getPtrIntArrayLength(parr);
  qlist.clear();
  if (len>0) {
    PTRINT *array = (PTRINT *)getPtrIntArrayAddr(parr);
    for (int i = 0; i < len; i++)
      qlist.append((T)array[i]);
  }  
}


//===============================================================================
// Only valid for T not castable to PtrInt 
// will allocate new T to get *T which is castable to PtrInt
//===============================================================================

template <typename T>
Q_OUTOFLINE_TEMPLATE void copyQListTemplateToPtrIntArrayWithNew(QList<T> &qlist, PPtrIntArray parr)
{
  int len = qlist.count();
  setPtrIntArrayLength(parr, len);
  if (len>0) {
    PTRINT *array = (PTRINT *)getPtrIntArrayAddr(parr);
    for (int i = 0; i < len; i++)
      array[i] = (PTRINT)(new T(qlist[i]));
 }   
}



C_EXPORT void initializePPtrIntArray(GetPtrIntArrayAddr gaa, GetPtrIntArrayLength gal, SetPtrIntArrayLength sal);



//===============================
// QVector<qreal> vs TQRealArray
//===============================  

typedef qreal *PQRealArray;
typedef qreal *(*GetQRealArrayAddr)(PQRealArray parr);
typedef int (*GetQRealArrayLength)(PQRealArray parr);
typedef void (*SetQRealArrayLength)(PQRealArray parr, int len);

extern GetQRealArrayAddr getQRealArrayAddr;
extern GetQRealArrayLength getQRealArrayLength;
extern SetQRealArrayLength setQRealArrayLength;


inline void copyQVectorQRealToQRealArray(QVector<qreal> &qvector, PQRealArray parr)
{
  int len = qvector.size();
  setQRealArrayLength(parr, len);
  if (len>0) {
    qreal *array = getQRealArrayAddr(parr);
    for (int i = 0; i < len; i++)
      array[i] = qvector.at(i);
  }   
}


inline void copyQRealArrayToQVectorQReal(PQRealArray parr,QVector<qreal> &qvector)
{
  int len = getQRealArrayLength(parr);
  qvector.resize(len);
  if (len>0) {
    qreal *array = getQRealArrayAddr(parr);
    for (int i = 0; i < len; i++)
      qvector[i] = array[i];
  }  
}

C_EXPORT void initializeQRealArray(GetQRealArrayAddr gaa, GetQRealArrayLength gal, SetQRealArrayLength sal);

#endif
