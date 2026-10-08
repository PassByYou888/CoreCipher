{
  Z.Core.pas - The foundational infrastructure library for the Z-framework.

  This unit provides a unified, high-performance, cross-platform foundation
  for multi-threaded and concurrent applications. It abstracts away compiler
  (Delphi / FPC) and operating system differences, offering:

    - Type aliases and compatibility layers for Delphi and FPC.
    - Memory management utilities (object disposal, pointer manipulation).
    - Concurrency primitives: atomic operations, critical sections (both
      OS-backed and spin-lock), and “soft” (user-space) synchronization.
    - High-performance data structures: lock-free and thread-safe lists,
      hash maps with LRU-like access, object pools, and FIFO queues.
    - A self-scaling thread pool (TCompute) that supports task scheduling,
      soft synchronization, and both blocking and non-blocking execution.
    - Mersenne Twister (MT19937) random number generation with per-thread
      instances for lock-free random streams.
    - Calls-per-second (CPS) profiling tools.
    - Utility functions for memory operations, endianness conversion, and
      geometric vector/matrix types (2D/3D).

  Design philosophy:
    - Performance first: uses object pooling, spin-locks, custom memory
      operations, and lock-free techniques to minimize overhead.
    - Cross-compiler and cross-platform: unifies Delphi and FPC, and supports
      Windows, Linux, macOS, iOS, Android, and BSD.
    - Self-contained: minimal external dependencies; implements its own
      synchronization, threading, and data structures.
    - “Soft” synchronization: provides a user-space alternative to OS-level
      thread synchronization for scenarios where context-switch overhead
      is unacceptable (e.g., high-frequency UI updates).

  Reference technologies:
    - Mersenne Twister (MT19937) for high-quality random numbers.
    - Spin-locks and critical sections (TCriticalSection) for mutual exclusion.
    - Object pooling (TBigList recycle pool) to reduce allocation pressure.
    - Thread-local storage (TLS) for per-thread MT19937 instances.
    - Cooperative threading model with TCompute and TThreadPost.
    - Fast memory copying and comparison using block operations (MOV/REP).
    - Quicksort with adaptive pivot selection for list and hash map sorting.
}
unit Z.Core;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  SysUtils, Classes, Types, Variants,
  {$IFDEF FPC}
    Z.FPC.GenericList, fgl,
    {$IFDEF MSWINDOWS}
    Windows,
    {$ENDIF MSWINDOWS}
    {$IFDEF POSIX}
    BaseUnix,
    {$ENDIF POSIX}
  {$ELSE FPC}
    System.Generics.Collections,
    {$IFDEF MSWINDOWS}
    Winapi.Windows,
    {$ENDIF MSWINDOWS}
    {$IFDEF POSIX}
    Posix.SysTime, Posix.Time,
    {$ENDIF POSIX}
  {$ENDIF FPC}
  SyncObjs, Math;

const
  C_Z_Core_Edition = '18.1';

{$Region 'core defines + class'}

{
  Type aliases to unify Delphi and FPC types, and to provide convenient
  names for commonly used structures.

  These aliases enable the rest of the library to be written without
  conditional compilation for basic types.
}
type
  // Hash and checksum types
  THash = Cardinal;                       ///< 32-bit hash value
  THash64 = UInt64;                       ///< 64-bit hash value
  PMD5 = ^TMD5;                           ///< Pointer to MD5 digest
  TMD5 = array [0 .. 15] of Byte;         ///< 16-byte MD5 digest
  TInt32_Array = array of Integer;
  TUInt32_Array = array of Cardinal;
  TBytes = SysUtils.TBytes;
  TPoint = Types.TPoint;
  TTimeTick = UInt64;                     ///< Used for high‑resolution timing (milliseconds)
  PTimeTick = ^TTimeTick;
  TSeekOrigin = Classes.TSeekOrigin;
  TNotify = Classes.TNotifyEvent;
  TArrayBool = Array of Boolean;
  TArrayInt64 = Array of Int64;
  TArrayUInt64 = Array of UInt64;
  TInt64Buffer = Array [0 .. MaxInt div SizeOf(Int64) - 1] of Int64;
  PInt64Buffer = ^TInt64Buffer;
  TUInt64Buffer = Array [0 .. MaxInt div SizeOf(UInt64) - 1] of UInt64;
  PUInt64Buffer = ^TUInt64Buffer;

  // Unified class names for core RTL classes – makes cross‑compiler code cleaner
  TCore_Object = TObject;                 ///< Base object class
  TCore_Persistent = TPersistent;         ///< Persistent object class
  TCore_Stream = TStream;                 ///< Stream class
  TStream_Array = array of TCore_Stream;  ///< Array of streams
  TCore_FileStream = TFileStream;         ///< File stream
  TCore_StringStream = TStringStream;     ///< String stream (in-memory)
  TCore_ResourceStream = TResourceStream; ///< Resource stream
  TCore_Thread = TThread;                 ///< Thread class
  TCore_MemoryStream = TMemoryStream;     ///< Memory stream
  TCore_Strings = TStrings;               ///< String list interface
  TCore_StringList = TStringList;         ///< String list implementation
  TCore_Reader = TReader;                 ///< Binary reader (for Delphi persistence)
  TCore_Writer = TWriter;                 ///< Binary writer
  TCore_Component = TComponent;           ///< Component class
  Core_Exception = Exception;             ///< Base exception class

  TExecutePlatform = (epWin32, epWin64, epOSX32, epOSX64, epIOS, epIOSSIM,
                      epANDROID32, epANDROID64, epLinux64, epLinux32, epBSD,
                      epUnknow);

  { Delphi/FPC compatibility classes for interfaced objects and lists }
  {$IFDEF FPC}
    PUInt64 = ^UInt64;

    TCore_InterfacedObject = class(TInterfacedObject)
    protected
      function _AddRef: longint; {$IFNDEF WINDOWS} cdecl {$ELSE WINDOWS} stdcall {$ENDIF WINDOWS};
      function _Release: longint; {$IFNDEF WINDOWS} cdecl {$ELSE WINDOWS} stdcall {$ENDIF WINDOWS};
    public
      procedure AfterConstruction; override;
      procedure BeforeDestruction; override;
    end;

    PCore_PointerList = Classes.PPointerList;
    TCore_PointerList = Classes.TPointerList;
    TCore_ListSortCompare = Classes.TListSortCompare;
    TCore_ListNotification = Classes.TListNotification;

    TCore_List = class(TList)
      property ListData: PPointerList read GetList;
    end;

    TCore_ListForObj = TGenericsList<TCore_Object>;
    TCore_ForObjectList = array of TCore_Object;
    PCore_ForObjectList = ^TCore_ForObjectList;
  {$ELSE FPC}
    TCore_InterfacedObject = class(TInterfacedObject)
    protected
      function _AddRef: Integer; stdcall;
      function _Release: Integer; stdcall;
    public
      procedure AfterConstruction; override;
      procedure BeforeDestruction; override;
    end;

    TGenericsList<t> = class(System.Generics.Collections.TList<t>)
    public type
      TGArry = array of t;
      PGArry = ^TGArry;
    public var Arry: TGArry;
      constructor Create;
      destructor Destroy; override;
      function ListData: PGArry;
    end;

    TGenericsObjectList<t: class> = class(System.Generics.Collections.TList<t>)
    public type
      TGArry = array of t;
      PGArry = ^TGArry;
    public var Arry: TGArry;
      constructor Create;
      destructor Destroy; override;
      function ListData: PGArry;
    end;

    TCore_PointerList = array of Pointer;
    PCore_PointerList = ^TCore_PointerList;

    TCore_List = class(TGenericsList<Pointer>)
    public
      constructor Create;
      destructor Destroy; override;
      function ListData: PCore_PointerList;
    end;

    TCore_ForObjectList = array of TCore_Object;
    PCore_ForObjectList = ^TCore_ForObjectList;

    TCore_ListForObj = class(TGenericsList<TCore_Object>)
    public
      constructor Create;
      destructor Destroy; override;
      function ListData: PCore_ForObjectList;
    end;
  {$ENDIF FPC}

  TCore_ObjectList = class(TCore_ListForObj)
  public
    AutoFreeObj: Boolean;
    constructor Create; overload;
    constructor Create(AutoFreeObj_: Boolean); overload;
    destructor Destroy; override;
    procedure Remove(obj: TCore_Object);
    procedure Delete(index: Integer);
    procedure Clear;
  end;
{$EndRegion 'core defines + class'}
{$Region 'Intermediate-tool-layer'}
{
  Intermediate object classes that support instance tracking when the
  compiler define 'Intermediate_Instance_Tool' is enabled.

  These classes increment/decrement a global counter on creation/destruction,
  which is useful for debugging memory leaks and analyzing object lifetime
  patterns. The counters are maintained by the global functions
  Inc_Instance_Num and Dec_Instance_Num, which can be hooked for custom
  monitoring.
}
  TCore_Object_Intermediate = class(TCore_Object)
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TCore_InterfacedObject_Intermediate = class(TCore_InterfacedObject)
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TCore_Persistent_Intermediate = class(TCore_Persistent)
  public
    constructor Create;
    destructor Destroy; override;
  end;
{$EndRegion 'Intermediate-tool-layer'}
{$Region 'CPS-Tool'}
{
  TCPS_Tool – a simple profiler that measures the number of calls per second
  and the CPU time spent during those calls.

  This tool is used internally to monitor the performance of the thread
  synchronisation loops (CPS_Check_Soft_Thread and CPS_Check_System_Thread).
  It can also be used by applications for custom instrumentation.

  Usage:
    Call Begin_Caller() before the code to measure, and End_Caller() after.
    The CPS (calls per second) is updated periodically (every second) and
    CPU_Time holds the maximum elapsed time of a single call.

  This is a lightweight record, not a class, to avoid heap allocation.
}
  TCPS_Tool = record
  private
    First_Caller_Time: TTimeTick;
    Last_Begin_Caller_Time: TTimeTick;
    Last_End_Caller_Time: TTimeTick;
    Last_Analysis_Time: TTimeTick;
    Caller_Num: Int64;
  public
    CPS: Double;          // computed calls per second
    CPU_Time: TTimeTick;  // maximum elapsed time of a single call (milliseconds)
    procedure Reset;
    procedure Begin_Caller;
    procedure End_Caller;
  end;
{$EndRegion 'CPS-Tool'}
{$Region 'Critical'}

  TSystem_Critical = TCriticalSection;

  TCritical = class;

{
  TAtomVar<T> – a thread‑safe wrapper for any type, providing atomic read/write
  operations via an internal TCritical.

  This class is useful for sharing simple variables across threads without
  having to manage explicit locks. It offers:
    - V / Value property for atomic get/set.
    - Lock / UnLock methods for performing multi‑step operations atomically.
    - Pointer access (P) for direct memory access while locked.

  For primitive numeric types, the specializations TAtomInteger, TAtomInt64,
  etc., are provided.

  Note: This implementation uses a critical section, not hardware atomics,
  so it is safe for all types but may be slower than true atomic operations
  for simple reads/writes. For primitive types, consider using the
  standalone AtomInc/AtomDec functions which use CPU intrinsics when available.
}
  TAtomVar<T_> = class
  public type
    PT_ = ^T_;
  private
    FValue__: T_;
    FCritical: TCritical;
    function GetValue: T_;
    procedure SetValue(const Value_: T_);
    function GetValueP: PT_;
  public
    constructor Create(Value_: T_);
    destructor Destroy; override;
    property Critical: TCritical read FCritical;
    function Lock: T_;
    function LockP: PT_;
    property P: PT_ read GetValueP;
    property Pointer_: PT_ read GetValueP;
    procedure UnLock(const Value_: T_); overload;
    procedure UnLock(const Value_: PT_); overload;
    procedure UnLock(); overload;
    property V: T_ read GetValue write SetValue;
    property Value: T_ read GetValue write SetValue;
  end;

  // Predefined atomic types for common data types
  TAtomBoolean = TAtomVar<Boolean>;
  TAtomBool = TAtomBoolean;
  TAtomSmallInt = TAtomVar<SmallInt>;
  TAtomShortInt = TAtomVar<ShortInt>;
  TAtomInteger = TAtomVar<Integer>;
  TAtomInt8 = TAtomSmallInt;
  TAtomInt16 = TAtomShortInt;
  TAtomInt32 = TAtomInteger;
  TAtomInt = TAtomInteger;
  TAtomInt64 = TAtomVar<Int64>;
  TAtomByte = TAtomVar<Byte>;
  TAtomWord = TAtomVar<Word>;
  TAtomCardinal = TAtomVar<Cardinal>;
  TAtomUInt8 = TAtomByte;
  TAtomUInt16 = TAtomWord;
  TAtomUInt32 = TAtomCardinal;
  TAtomDWord = TAtomCardinal;
  TAtomUInt64 = TAtomVar<UInt64>;
  TAtomTimeTick = TAtomVar<TTimeTick>;
  TAtomSingle = TAtomVar<Single>;
  TAtomFloat = TAtomSingle;
  TAtomDouble = TAtomVar<Double>;
  TAtomExtended = TAtomVar<Extended>;
  TAtomString = TAtomVar<string>;

{
  TCritical – a wrapper around TSystem_Critical that adds:
    - Reference counting (LNum) to track recursive acquisition depth.
    - A pool of underlying critical section objects to reduce creation overhead.

  The pool (System_Critical_Recycle_Pool__) reuses TSystem_Critical instances
  after they are freed, so that repeated create/destroy cycles are cheap.
  This is especially useful for objects that create many short‑lived locks.

  TCritical also provides convenience methods like Inc_ and Dec_ to atomically
  read‑modify‑write a variable while holding the lock.
}
  TCritical = class sealed(TCore_Object)
  private
    FName: string;
    Instance__: TSystem_Critical;
    LNum: Integer;  // number of times the lock has been acquired (recursion count)
  public
    property Name: string read FName;
    constructor Create(); overload;
    constructor Create(const Name_: string); overload;
    destructor Destroy; override;
    procedure Acquire; inline;
    procedure Release; inline;
    procedure Enter; inline;
    procedure Leave; inline;
    procedure Lock; inline;
    procedure UnLock; inline;
    function IsBusy: Boolean;
    property IsLock: Boolean read IsBusy;
    property Busy: Boolean read IsBusy;

    { Convenience methods to atomically read/modify a variable while holding the lock }
    function Get(var x: Int64): Int64; overload;
    function Get(var x: UInt64): UInt64; overload;
    function Get(var x: Integer): Integer; overload;
    function Get(var x: Cardinal): Cardinal; overload;
    function Inc_(var x: Int64): Int64; overload;
    function Inc_(var x: Int64; const v: Int64): Int64; overload;
    function Dec_(var x: Int64): Int64; overload;
    function Dec_(var x: Int64; const v: Int64): Int64; overload;
    function Inc_(var x: UInt64): UInt64; overload;
    function Inc_(var x: UInt64; const v: UInt64): UInt64; overload;
    function Dec_(var x: UInt64): UInt64; overload;
    function Dec_(var x: UInt64; const v: UInt64): UInt64; overload;
    function Inc_(var x: Integer): Integer; overload;
    function Inc_(var x: Integer; const v: Integer): Integer; overload;
    function Dec_(var x: Integer): Integer; overload;
    function Dec_(var x: Integer; const v: Integer): Integer; overload;
    function Inc_(var x: Cardinal): Cardinal; overload;
    function Inc_(var x: Cardinal; const v: Cardinal): Cardinal; overload;
    function Dec_(var x: Cardinal): Cardinal; overload;
    function Dec_(var x: Cardinal; const v: Cardinal): Cardinal; overload;
  end;
{$EndRegion 'Critical'}
{$Region 'Swap'}
{
  TSwap<T> – a simple utility class to exchange two variables of the same type.

  This is used extensively in sorting algorithms (e.g., quicksort) and
  anywhere two values need to be swapped in a type‑safe manner.
}
  TSwap<T_> = class
  public
    class procedure Do_(var v1, v2: T_); static;
  end;
{$EndRegion 'Swap'}
{$Region 'IF'}
{
  TIF<T> – a ternary operator replacement, returning one of two values
  based on a Boolean condition.

  This is useful for inline conditional expressions where a function call
  is not desired. It is similar to the `if_` global functions but for
  any type via generics.
}
  TIF<T_> = class
  public
    class function Do_(Bool_: Boolean; Yes_, No_: T_): T_; static;
  end;
{$EndRegion 'IF'}
{$Region 'OrderStruct'}
{
  TOrderStruct<T> – a singly linked list (FIFO queue) with push/pop operations.

  This is a simple, non‑thread‑safe queue used as a building block for
  object pools and task queues. It supports:
    - Push: add an element to the end.
    - Next: remove the first element.
    - Clear: remove all elements.

  It also provides an OnFree event for custom cleanup of the stored data.

  The critical version (TCriticalOrderStruct) adds a lock for thread‑safe
  operations.

  Note: This is a linked list, so operations are O(1) but memory locality
  is poor compared to array‑based queues. It is best for scenarios where
  the queue size is moderate and elements are frequently inserted/removed.
}

  TOrderStruct<T_> = class(TCore_Object_Intermediate)
  public type
    POrderStruct = ^TOrderStruct_;
    TOrderStruct_ = record
      Data: T_;
      Next: POrderStruct;
    end;
    TOnFreeOrderStruct = procedure(var p: T_) of object;
  private
    FFirst: POrderStruct;
    FLast: POrderStruct;
    FNum: NativeInt;
    FOnFreeOrderStruct: TOnFreeOrderStruct;
    procedure DoInternalFree(const p: POrderStruct);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure DoFree(var Data: T_); virtual;
    procedure SwapInstance(source: TOrderStruct<T_>); // only reserved FOnFreeOrderStruct
    procedure Clear;
    property Current: POrderStruct read FFirst;
    property First: POrderStruct read FFirst;
    property Last: POrderStruct read FLast;
    procedure Next;
    function Push(const Data: T_): POrderStruct;
    function Push_Null: POrderStruct;
    property Num: NativeInt read FNum;
    property OnFree: TOnFreeOrderStruct read FOnFreeOrderStruct write FOnFreeOrderStruct;
  end;

  TOrderPtrStruct<T_> = class(TCore_Object_Intermediate)
  public type
    PT_ = ^T_;
    POrderPtrStruct = ^TOrderPtrStruct_;
    TOrderPtrStruct_ = record
      Data: PT_;
      Next: POrderPtrStruct;
    end;
    TOnFreeOrderPtrStruct = procedure(p: PT_) of object;
  private
    FFirst: POrderPtrStruct;
    FLast: POrderPtrStruct;
    FNum: NativeInt;
    FOnFreeOrderStruct: TOnFreeOrderPtrStruct;
    procedure DoInternalFree(const p: POrderPtrStruct);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure DoFree(Data: PT_); virtual;
    procedure SwapInstance(source: TOrderPtrStruct<T_>); // only reserved FOnFreeOrderStruct
    procedure Clear;
    property Current: POrderPtrStruct read FFirst;
    property First: POrderPtrStruct read FFirst;
    property Last: POrderPtrStruct read FLast;
    procedure Next;
    function Push(const Data: T_): POrderPtrStruct;
    function PushPtr(Data: PT_): POrderPtrStruct;
    property Num: NativeInt read FNum;
    property OnFree: TOnFreeOrderPtrStruct read FOnFreeOrderStruct write FOnFreeOrderStruct;
  end;

  TCriticalOrderStruct<T_> = class(TCore_Object_Intermediate)
  public type
    POrderStruct = ^TOrderStruct_;
    TOrderStruct_ = record
      Data: T_;
      Next: POrderStruct;
    end;
    TOnFreeCriticalOrderStruct = procedure(var p: T_) of object;
  private
    FCritical__: TCritical;
    FFirst: POrderStruct;
    FLast: POrderStruct;
    FNum: NativeInt;
    FOnFreeCriticalOrderStruct: TOnFreeCriticalOrderStruct;
    procedure DoInternalFree(const p: POrderStruct);
  public
    property Critical__: TCritical read FCritical__;
    constructor Create; virtual;
    destructor Destroy; override;
    procedure DoFree(var Data: T_); virtual;
    procedure SwapInstance(source: TCriticalOrderStruct<T_>); // only reserved FCritical__ + FOnFreeOrderStruct
    procedure Clear;
    function GetCurrent: POrderStruct;
    property Current: POrderStruct read GetCurrent;
    property First: POrderStruct read GetCurrent;
    procedure Next;
    function Push(const Data: T_): POrderStruct;
    function Push_Null: POrderStruct;
    function GetNum: NativeInt;
    property Num: NativeInt read GetNum;
    property OnFree: TOnFreeCriticalOrderStruct read FOnFreeCriticalOrderStruct write FOnFreeCriticalOrderStruct;
  end;

  TCriticalOrderPtrStruct<T_> = class(TCore_Object_Intermediate)
  public type
    PT_ = ^T_;
    POrderPtrStruct = ^TOrderPtrStruct_;
    TOrderPtrStruct_ = record
      Data: PT_;
      Next: POrderPtrStruct;
    end;
    TOnFreeCriticalOrderPtrStruct = procedure(p: PT_) of object;
  private
    FCritical__: TCritical;
    FFirst: POrderPtrStruct;
    FLast: POrderPtrStruct;
    FNum: NativeInt;
    FOnFreeCriticalOrderStruct: TOnFreeCriticalOrderPtrStruct;
    procedure DoInternalFree(const p: POrderPtrStruct);
  public
    property Critical__: TCritical read FCritical__;
    constructor Create; virtual;
    destructor Destroy; override;
    procedure DoFree(Data: PT_); virtual;
    procedure SwapInstance(source: TCriticalOrderPtrStruct<T_>); // only reserved FCritical__ + FOnFreeOrderStruct
    procedure Clear;
    function GetCurrent: POrderPtrStruct;
    property Current: POrderPtrStruct read GetCurrent;
    property First: POrderPtrStruct read GetCurrent;
    procedure Next;
    function Push(const Data: T_): POrderPtrStruct;
    function PushPtr(Data: PT_): POrderPtrStruct;
    function GetNum: NativeInt;
    property Num: NativeInt read GetNum;
    property OnFree: TOnFreeCriticalOrderPtrStruct read FOnFreeCriticalOrderStruct write FOnFreeCriticalOrderStruct;
  end;
{$EndRegion 'OrderStruct'}
{$REGION 'BigList'}
{
  TBigList<T> – a doubly linked circular list with a built‑in object pool
  (recycle pool) and optional sorting / indexing.
  Key features:
    - Fast insertion/removal at any position (O(1)).
    - Iterators (TRepeat___, TInvert_Repeat___) that allow safe removal
      during iteration (via Discard).
    - Recycle pool: when elements are removed, they are kept in a pool
      and reused to reduce memory allocations.
    - Sorting: supports three callback styles (C, M, P) using quicksort.
    - Indexed access: maintains a cached array of pointers for O(1) random
      access, automatically rebuilt when the list changes.
    - Thread‑safe version (TCritical_BigList) adds a lock around every
      public operation.
  This is the core data structure used throughout the framework for
  collections that are frequently modified (e.g., task queues, object pools).
  Design notes:
    - The circular structure (with Prev/Next pointers) allows O(1)
      insertion before or after any known node.
    - The recycle pool (FRecycle_Pool__) holds nodes that have been removed
      but whose data may be reused. This reduces memory fragmentation and
      allocation overhead.
    - The sorting implementation uses quicksort on a snapshot of the list
      (built via BuildArrayMemory) to avoid modifying the list during sort.
    - The index cache (FList) is invalidated when the list changes and
      rebuilt on demand, providing O(1) access by index.
  Usage:
    - Use Add/Insert to add elements.
    - Use Remove_P/Remove_Data to remove elements.
    - Use Repeat_ / Invert_Repeat_ to iterate forward/backward.
    - Use Sort_* to sort the list.
  The class is generic over any type T; for object types, the specialized
  TBig_Object_List handles automatic freeing.
}
  TBigList<T_> = class(TCore_Object_Intermediate)
  public type
    P_ = ^T_;                                                      // Pointer to the element type
    PQueueStruct = ^TQueueStruct;                                  // Pointer to a list node
    PPQueueStruct = ^PQueueStruct;                                 // Pointer to a node pointer (used for index buffers)
    T___ = TBigList<T_>;                                           // Self-reference for nested types
    TQueueStruct = record
      Data: T_;                                                    // User data stored in the node
      Next: PQueueStruct;                                          // Pointer to the next node in the circular list
      Prev: PQueueStruct;                                          // Pointer to the previous node
      Instance___: T___;                                           // Back-reference to the owning list
      Recycle___: Boolean;                                         // True if this node is currently in the recycle pool
    end;
    TRepeat___ = record                                            // Forward iterator over a range of nodes
    private
      BI___: NativeInt;                                            // Starting index (inclusive)
      EI___: NativeInt;                                            // Ending index (inclusive)
      I___: NativeInt;                                             // Current position index
      Instance___: T___;                                           // The list being iterated
      p___: PQueueStruct;                                          // Current node pointer
      Is_Discard___: Boolean;                                      // True if the current node should be removed on next move
      procedure Init_(Instance_: T___); overload;                  // Initialize to iterate the whole list
      procedure Init_(Instance_: T___; BI_, EI_: NativeInt); overload; // Initialize for a specific index range
    public
      property Work: T___ read Instance___;                        // The list being iterated
      property BI: NativeInt read BI___;                           // Start index
      property EI: NativeInt read EI___;                           // End index
      property I__: NativeInt read I___;                           // Current index
      property Queue: PQueueStruct read p___;                      // Current node
      procedure Discard;                                           // Mark current node for removal on the next call to Next
      function Next: Boolean;                                      // Advance to the next node; returns False when iteration ends
      property Right: Boolean read Next;                           // Alias for Next
      property Instance: T___ read Instance___;
    end;
    TInvert_Repeat___ = record                                     // Reverse iterator over a range
    private
      BI___: NativeInt;                                            // Start index (in forward order, inclusive)
      EI___: NativeInt;                                            // End index (in forward order, inclusive)
      I___: NativeInt;                                             // Current position (in reverse order)
      Instance___: T___;                                           // The list being iterated
      p___: PQueueStruct;                                          // Current node pointer
      Is_Discard___: Boolean;                                      // True if current node should be removed on next move
      procedure Init_(Instance_: T___); overload;                  // Initialize to iterate the whole list in reverse
      procedure Init_(Instance_: T___; BI_, EI_: NativeInt); overload; // Initialize for a specific index range (reverse)
    public
      property Work: T___ read Instance___;
      property BI: NativeInt read BI___;
      property EI: NativeInt read EI___;
      property I__: NativeInt read I___;
      property Queue: PQueueStruct read p___;
      procedure Discard;
      function Prev: Boolean;                                      // Move to the previous node; returns False when done
      property Left: Boolean read Prev;
      property Instance: T___ read Instance___;
    end;
    TArray_T_ = array of T_;                                       // Dynamic array of elements
    TOrder_Data_Pool = TOrderStruct<T_>;                           // FIFO queue of elements
    TRecycle_Pool__ = TOrderStruct<PQueueStruct>;                  // Recycle pool storing node pointers for later reuse
    TQueueArrayStruct = array [0 .. (MaxInt div SizeOf(Pointer) - 1)] of PQueueStruct; // Static array type for index cache
    PQueueArrayStruct = ^TQueueArrayStruct;                        // Pointer to the index cache array
    TOnStruct_Event = procedure(var p: T_) of object;              // Event handler for add/free operations
    TSort_C = function(var L, R: T_): Integer;                     // Sort comparator (C-style plain function)
    TQueneStructFor_C = procedure(Index_: NativeInt; p: PQueueStruct; var Aborted: Boolean); // For-each callback (C)
    TSort_M = function(var L, R: T_): Integer of object;           // Sort comparator (M-style method)
    TQueneStructFor_M = procedure(Index_: NativeInt; p: PQueueStruct; var Aborted: Boolean) of object; // For-each (M)
{$IFDEF FPC}
    TQueneStructFor_P = procedure(Index_: NativeInt; p: PQueueStruct; var Aborted: Boolean) is nested; // For-each (P – nested)
    TSort_P = function(var L, R: T_): Integer is nested;           // Sort comparator (P – nested)
{$ELSE FPC}
    TQueneStructFor_P = reference to procedure(Index_: NativeInt; p: PQueueStruct; var Aborted: Boolean); // For-each (P – anonymous)
    TSort_P = reference to function(var L, R: T_): Integer;        // Sort comparator (P – anonymous)
{$ENDIF FPC}
  private
    FCritical__: TCritical;                                        // Lock for thread safety (created on first use)
    FRecycle_Pool__: TRecycle_Pool__;                              // Pool of nodes that have been removed but not yet freed
    FFirst: PQueueStruct;                                          // Head of the circular list (first element)
    FLast: PQueueStruct;                                           // Tail of the circular list (last element)
    FNum: NativeInt;                                               // Number of elements currently in the list
    FOnAdd: TOnStruct_Event;                                       // Event triggered after an element is added
    FOnFree: TOnStruct_Event;                                      // Event triggered before an element is freed
    FOnFree_For_Pair_Tool: TOnStruct_Event;                        // Internal event used by pair tools for cleanup
    FEnabled_Sort: Boolean;                                        // Master switch for sorting operations (default True)
    FChanged: Boolean;                                             // Set to True whenever the list structure changes; invalidates index cache
    FList: Pointer;                                                // Cached index array (PQueueArrayStruct), rebuilt on demand
    procedure DoInternalFree(p: PQueueStruct);                     // Actually frees a node: calls DoFree and Dispose
  public
    function Get_Critical__: TCritical;                            // Returns the lock, creating it if it does not exist
    property Critical__: TCritical read Get_Critical__;            // Provides external access to the internal lock
    constructor Create;                                            // Default constructor
    destructor Destroy; override;                                  // Destructor: clears all nodes and frees the lock
    procedure DoFree(var Data: T_); virtual;                       // Virtual method to free a single data element (invokes OnFree)
    procedure DoAdd(var Data: T_); virtual;                        // Virtual method to notify when an element is added (invokes OnAdd)
    function CompareData(const Data_1, Data_2: T_): Boolean; virtual; // Compares two elements; default uses memory compare
    procedure Lock;                                                // Acquires the internal lock
    procedure UnLock;                                              // Releases the internal lock
    function Get_Recycle_Pool_Num: NativeInt;                      // Returns the number of nodes currently in the recycle pool
    procedure Push_To_Recycle_Pool(p: PQueueStruct);               // Moves a node to the recycle pool (marks it as recycled)
    procedure Free_Recycle_Pool;                                   // Frees all nodes currently in the recycle pool
    procedure Clear;                                               // Removes all elements from the list and empties the recycle pool
    property First: PQueueStruct read FFirst;                      // Direct access to the first node (nil if list is empty)
    property Last: PQueueStruct read FLast;                        // Direct access to the last node (nil if list is empty)
    procedure Next;                                                // Removes and frees the first node (queue-style pop)
    function Add(const Data: T_): PQueueStruct;                    // Appends a new element to the end; returns the new node
    procedure AddL(L_: T___);                                      // Appends all elements from another list into this list
    function Add_Null(): PQueueStruct;                             // Appends a node with uninitialized data; returns the new node
    function Insert(const Data: T_; To_: PQueueStruct): PQueueStruct; // Inserts a new element before the given node; returns new node
    function CopyFrom(Source_: T___): NativeInt;                   // Copies all elements from Source_ into this list; returns count
    procedure Remove_P(p: PQueueStruct);                           // Removes and frees the given node immediately
    procedure Remove_T(const Data: T_);                            // Removes the first occurrence of Data (alias for Remove_Data)
    procedure Move_Before(p, To_: PQueueStruct);                   // Moves node p so that it is placed immediately before node To_
    procedure MoveToFirst(p: PQueueStruct);                        // Moves node p to the front of the list
    procedure MoveToLast(p: PQueueStruct);                         // Moves node p to the back of the list
    procedure Exchange(p1, p2: PQueueStruct);                      // Swaps the data of two nodes
    function Found(p1: PQueueStruct): NativeInt;                   // Returns the index of the given node, or -1 if not found
    function Find_Data(const Data: T_): PQueueStruct;              // Finds the first node whose data matches; returns nil if none
    function Find_Data_Ptr(const Data_Ptr: P_): PQueueStruct;      // Finds a node by comparing the address of its data field
    function Search_Data_As_Array(const Data: T_): TArray_T_;      // Finds all matching elements and returns them as a dynamic array
    function Search_Data_As_Order(const Data: T_): TOrder_Data_Pool; // Finds all matching elements and returns them as a FIFO queue
    function Remove_Data(const Data: T_): Integer;                 // Removes all occurrences of Data; returns the number removed
    function Repeat_(): TRepeat___; overload;                      // Returns a forward iterator over the entire list
    function Repeat_(BI_, EI_: NativeInt): TRepeat___; overload;   // Returns a forward iterator for a specific index range
    function Invert_Repeat_(): TInvert_Repeat___; overload;        // Returns a reverse iterator over the entire list
    function Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___; overload; // Returns a reverse iterator for a specific index range
    procedure For_C(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_C); overload; // Iterates a node range with C-style callback
    procedure For_M(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_M); overload; // Iterates a node range with M-style callback
    procedure For_P(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_P); overload; // Iterates a node range with P-style callback
    procedure For_C(OnFor: TQueneStructFor_C); overload;           // Iterates the entire list with C-style callback
    procedure For_M(OnFor: TQueneStructFor_M); overload;           // Iterates the entire list with M-style callback
    procedure For_P(OnFor: TQueneStructFor_P); overload;           // Iterates the entire list with P-style callback
    function ToArray(): TArray_T_;                                 // Copies all elements into a dynamic array (order = forward)
    function ToOrder(): TOrder_Data_Pool;                          // Copies all elements into a FIFO queue (order = forward)
    property Enabled_Sort: Boolean read FEnabled_Sort write FEnabled_Sort; // Enables or disables sorting operations
    procedure Sort_C(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_C); overload; // Quicksort on an index range (C comparator)
    procedure Sort_C(OnSort: TSort_C); overload;                   // Quicksort the entire list (C comparator)
    procedure Sort_M(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_M); overload; // Quicksort on a range (M comparator)
    procedure Sort_M(OnSort: TSort_M); overload;                   // Quicksort the entire list (M comparator)
    procedure Sort_P(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_P); overload; // Quicksort on a range (P comparator)
    procedure Sort_P(OnSort: TSort_P); overload;                   // Quicksort the entire list (P comparator)
    function BuildArrayMemory: PQueueArrayStruct;                  // Allocates and builds an index cache array; caller must free with FreeMemory
    function CheckList: PQueueArrayStruct;                         // Returns the index cache, rebuilding it if the list has changed
    function GetList(const Index: NativeInt): PQueueStruct;        // Returns the node at the given index (O(1) using cache)
    procedure SetList(const Index: NativeInt; const Value: PQueueStruct); // Replaces the node pointer in the index cache (for internal use)
    property List[const Index: NativeInt]: PQueueStruct read GetList write SetList; // Indexed node access (by pointer)
    function GetItems(const Index: NativeInt): T_;                 // Returns the data element at the given index
    procedure SetItems(const Index: NativeInt; const Value: T_);   // Sets the data element at the given index
    property Items[const Index: NativeInt]: T_ read GetItems write SetItems; default; // Indexed element access
    property Num: NativeInt read FNum;                             // Number of elements in the list
    property Count: NativeInt read FNum;                           // Alias for Num
    property OnFree: TOnStruct_Event read FOnFree write FOnFree;   // Event fired before an element is freed
    property OnAdd: TOnStruct_Event read FOnAdd write FOnAdd;      // Event fired after an element is added
    class function Null_Data: T_;                                  // Returns a zero-initialized instance of T_
  end;
  // ==========================================================================
  // Thread-safe version – all public methods are guarded by FCritical__.
  // ==========================================================================
  TCritical_BigList<T_> = class(TCore_Object_Intermediate)
  public type
    P_ = ^T_;
    PQueueStruct = ^TQueueStruct;
    PPQueueStruct = ^PQueueStruct;
    T___ = TCritical_BigList<T_>;
    TQueueStruct = record
      Data: T_;
      Next: PQueueStruct;
      Prev: PQueueStruct;
      Instance___: T___;
      Recycle___: Boolean;
    end;
    TRepeat___ = record
    private
      BI___: NativeInt;
      EI___: NativeInt;
      I___: NativeInt;
      Instance___: T___;
      p___: PQueueStruct;
      Is_Discard___: Boolean;
      procedure Init_(Instance_: T___); overload;
      procedure Init_(Instance_: T___; BI_, EI_: NativeInt); overload;
    public
      property Work: T___ read Instance___;
      property BI: NativeInt read BI___;
      property EI: NativeInt read EI___;
      property I__: NativeInt read I___;
      property Queue: PQueueStruct read p___;
      procedure Discard;
      function Next: Boolean;
      property Right: Boolean read Next;
      property Instance: T___ read Instance___;
    end;
    TInvert_Repeat___ = record
    private
      BI___: NativeInt;
      EI___: NativeInt;
      I___: NativeInt;
      Instance___: T___;
      p___: PQueueStruct;
      Is_Discard___: Boolean;
      procedure Init_(Instance_: T___); overload;
      procedure Init_(Instance_: T___; BI_, EI_: NativeInt); overload;
    public
      property Work: T___ read Instance___;
      property BI: NativeInt read BI___;
      property EI: NativeInt read EI___;
      property I__: NativeInt read I___;
      property Queue: PQueueStruct read p___;
      procedure Discard;
      function Prev: Boolean;
      property Left: Boolean read Prev;
      property Instance: T___ read Instance___;
    end;
    TArray_T_ = array of T_;
    TOrder_Data_Pool = TOrderStruct<T_>;
    TRecycle_Pool__ = TOrderStruct<PQueueStruct>;
    TQueueArrayStruct = array [0 .. (MaxInt div SizeOf(Pointer) - 1)] of PQueueStruct;
    PQueueArrayStruct = ^TQueueArrayStruct;
    TOnStruct_Event = procedure(var p: T_) of object;
    TSort_C = function(var L, R: T_): Integer;
    TQueneStructFor_C = procedure(Index_: NativeInt; p: PQueueStruct; var Aborted: Boolean);
    TSort_M = function(var L, R: T_): Integer of object;
    TQueneStructFor_M = procedure(Index_: NativeInt; p: PQueueStruct; var Aborted: Boolean) of object;
{$IFDEF FPC}
    TQueneStructFor_P = procedure(Index_: NativeInt; p: PQueueStruct; var Aborted: Boolean) is nested;
    TSort_P = function(var L, R: T_): Integer is nested;
{$ELSE FPC}
    TQueneStructFor_P = reference to procedure(Index_: NativeInt; p: PQueueStruct; var Aborted: Boolean);
    TSort_P = reference to function(var L, R: T_): Integer;
{$ENDIF FPC}
  private
    FCritical__: TCritical;                                        // Lock – created in the constructor (always available)
    FRecycle_Pool__: TRecycle_Pool__;                              // Recycle pool for removed nodes
    FFirst: PQueueStruct;                                          // Head of the list (first element)
    FLast: PQueueStruct;                                           // Tail of the list (last element)
    FNum: NativeInt;                                               // Current element count
    FOnAdd: TOnStruct_Event;                                       // Add event handler
    FOnFree: TOnStruct_Event;                                      // Free event handler
    FOnFree_For_Pair_Tool: TOnStruct_Event;                        // Internal free event
    FEnabled_Sort: Boolean;                                        // Sorting enabled flag
    FChanged: Boolean;                                             // Invalidation flag for index cache
    FList: Pointer;                                                // Cached index array
    procedure DoInternalFree(p: PQueueStruct);                     // Internal free of a node (calls DoFree and Dispose)
  public
    function Get_Critical__: TCritical;                            // Returns the lock (always non-nil)
    property Critical__: TCritical read Get_Critical__;            // Exposes the internal lock
    constructor Create;                                            // Creates the list and initializes the lock
    destructor Destroy; override;                                  // Cleans up all resources
    procedure DoFree(var Data: T_); virtual;                       // Virtual free method (triggers OnFree)
    procedure DoAdd(var Data: T_); virtual;                        // Virtual add method (triggers OnAdd)
    function CompareData(const Data_1, Data_2: T_): Boolean; virtual; // Element comparison (default memory compare)
    procedure Lock;                                                // Acquires the lock
    procedure UnLock;                                              // Releases the lock
    function Get_Recycle_Pool_Num: NativeInt;                      // Returns number of nodes in recycle pool
    procedure Push_To_Recycle_Pool(p: PQueueStruct);               // Moves a node to recycle pool
    procedure Free_Recycle_Pool(Lock_: Boolean); overload;         // Frees recycle pool, optionally acquiring the lock
    procedure Free_Recycle_Pool; overload;                         // Frees recycle pool (no extra lock)
    procedure Clear;                                               // Clears all elements and recycle pool
    property First: PQueueStruct read FFirst;                      // First node (nil if empty)
    property Last: PQueueStruct read FLast;                        // Last node (nil if empty)
    procedure Next(Lock_: Boolean); overload;                     // Removes first node, optionally with lock
    procedure Next; overload;                                     // Removes first node (acquires lock)
    function Add(const Data: T_): PQueueStruct;                    // Appends an element; returns new node
    procedure AddL(L_: T___);                                      // Appends all elements from another list
    function Add_Null(Lock_: Boolean): PQueueStruct; overload;    // Appends an uninitialized node, optionally with lock
    function Add_Null(): PQueueStruct; overload;                  // Appends an uninitialized node (acquires lock)
    function Insert(const Data: T_; To_: PQueueStruct): PQueueStruct; // Inserts before a given node; returns new node
    function CopyFrom(Source_: T___): NativeInt;                   // Copies all elements from another list; returns count
    procedure Remove_P(p: PQueueStruct; Lock_: Boolean); overload; // Removes node, optionally with lock
    procedure Remove_P(p: PQueueStruct); overload;                // Removes node (acquires lock)
    procedure Remove_T(const Data: T_);                            // Removes first matching data (alias for Remove_Data)
    procedure Move_Before(p, To_: PQueueStruct);                   // Moves node p before node To_
    procedure MoveToFirst(p: PQueueStruct);                        // Moves node to front
    procedure MoveToLast(p: PQueueStruct);                         // Moves node to back
    procedure Exchange(p1, p2: PQueueStruct);                      // Swaps data of two nodes
    function Found(p1: PQueueStruct): NativeInt;                   // Returns index of node, or -1
    function Find_Data(const Data: T_): PQueueStruct;              // Finds first matching node by data
    function Find_Data_Ptr(const Data_Ptr: P_): PQueueStruct;      // Finds node by data address
    function Search_Data_As_Array(const Data: T_): TArray_T_;      // Finds all matches as dynamic array
    function Search_Data_As_Order(const Data: T_): TOrder_Data_Pool; // Finds all matches as FIFO queue
    function Remove_Data(const Data: T_): Integer;                 // Removes all occurrences of Data; returns count
    function Repeat_(): TRepeat___; overload;                      // Forward iterator over entire list
    function Repeat_(BI_, EI_: NativeInt): TRepeat___; overload;   // Forward iterator over index range
    function Invert_Repeat_(): TInvert_Repeat___; overload;        // Reverse iterator over entire list
    function Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___; overload; // Reverse iterator over range
    procedure For_C(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_C); overload; // Iterate range with C callback
    procedure For_M(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_M); overload; // Iterate range with M callback
    procedure For_P(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_P); overload; // Iterate range with P callback
    procedure For_C(OnFor: TQueneStructFor_C); overload;           // Iterate whole list with C callback
    procedure For_M(OnFor: TQueneStructFor_M); overload;           // Iterate whole list with M callback
    procedure For_P(OnFor: TQueneStructFor_P); overload;           // Iterate whole list with P callback
    function ToArray(): TArray_T_;                                 // Copy all elements to a dynamic array
    function ToOrder(): TOrder_Data_Pool;                          // Copy all elements to a FIFO queue
    property Enabled_Sort: Boolean read FEnabled_Sort write FEnabled_Sort; // Enable/disable sorting
    procedure Sort_C(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_C); overload; // Quicksort on range (C)
    procedure Sort_C(OnSort: TSort_C); overload;                   // Quicksort whole list (C)
    procedure Sort_M(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_M); overload; // Quicksort on range (M)
    procedure Sort_M(OnSort: TSort_M); overload;                   // Quicksort whole list (M)
    procedure Sort_P(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_P); overload; // Quicksort on range (P)
    procedure Sort_P(OnSort: TSort_P); overload;                   // Quicksort whole list (P)
    function BuildArrayMemory: PQueueArrayStruct;                  // Builds index cache (caller frees)
    function CheckList: PQueueArrayStruct;                         // Returns index cache, rebuilds if needed
    function GetList(const Index: NativeInt): PQueueStruct;        // Returns node at index (O(1) via cache)
    procedure SetList(const Index: NativeInt; const Value: PQueueStruct); // Replaces node pointer in cache
    property List[const Index: NativeInt]: PQueueStruct read GetList write SetList; // Indexed node access
    function GetItems(const Index: NativeInt): T_;                 // Returns element at index
    procedure SetItems(const Index: NativeInt; const Value: T_);   // Sets element at index
    property Items[const Index: NativeInt]: T_ read GetItems write SetItems; default; // Indexed element access
    property Num: NativeInt read FNum;                             // Number of elements
    property Count: NativeInt read FNum;                           // Alias for Num
    property OnFree: TOnStruct_Event read FOnFree write FOnFree;   // Event fired when element is freed
    property OnAdd: TOnStruct_Event read FOnAdd write FOnAdd;      // Event fired when element is added
    class function Null_Data: T_;                                  // Returns zeroed T_
  end;
  TC_BigList<T_> = class(TCritical_BigList<T_>);                  // Short alias for the thread‑safe version
  // ==========================================================================
  // Object‑specialized version – automatically frees objects when removed.
  // ==========================================================================
  TBig_Object_List<T_: class> = class(TBigList<T_>)
  public
    AutoFreeObject: Boolean;                                      // If True, the object is freed when the node is removed
    constructor Create(AutoFreeObject_: Boolean);                 // Constructor with autofree flag
    procedure DoFree(var Data: T_); override;                     // Override: frees the object if AutoFreeObject is True
  end;
  TObject_BigList<T_: class> = class(TBig_Object_List<T_>);      // Alias
  // Thread‑safe object list
  TCritical_Big_Object_List<T_: class> = class(TCritical_BigList<T_>)
  public
    AutoFreeObject: Boolean;
    constructor Create(AutoFreeObject_: Boolean);
    procedure DoFree(var Data: T_); override;
  end;
  TC_Big_Object_List<T_: class> = class(TCritical_Big_Object_List<T_>); // Alias
{$ENDREGION 'BigList'}
{$REGION 'Pair'}
{
  The TPair* records are simple containers for 2-6 values, used as lightweight
  tuples. They are often used as key‑value pairs or as elements in hash maps
  that require multiple fields.

  The tool classes (TPair*_Tool) provide a list that stores these pairs and
  offers automatic memory management via the list's OnFree/OnAdd events.
}
  TPair2<T1, T2> = record
    Primary: T1;
    Second: T2;
    class function Init(Primary_: T1; Second_: T2): TPair2<T1, T2>; static;
  end;

  TPair3<T1, T2, T3> = record
    Primary: T1;
    Second: T2;
    Third: T3;
    class function Init(Primary_: T1; Second_: T2; Third_: T3): TPair3<T1, T2, T3>; static;
  end;

  TPair4<T1, T2, T3, T4> = record
    Primary: T1;
    Second: T2;
    Third: T3;
    Fourth: T4;
    class function Init(Primary_: T1; Second_: T2; Third_: T3; Fourth_: T4): TPair4<T1, T2, T3, T4>; static;
  end;

  TPair5<T1, T2, T3, T4, T5> = record
    Primary: T1;
    Second: T2;
    Third: T3;
    Fourth: T4;
    Five: T5;
    class function Init(Primary_: T1; Second_: T2; Third_: T3; Fourth_: T4; Five_: T5): TPair5<T1, T2, T3, T4, T5>; static;
  end;

  TPair6<T1, T2, T3, T4, T5, T6> = record
    Primary: T1;
    Second: T2;
    Third: T3;
    Fourth: T4;
    Five: T5;
    Six: T6;
    class function Init(Primary_: T1; Second_: T2; Third_: T3; Fourth_: T4; Five_: T5; Six_: T6): TPair6<T1, T2, T3, T4, T5, T6>; static;
  end;

  TPair2_Tool<T1_, T2_> = class(TCore_Object_Intermediate)
  public type
    TPair = TPair2<T1_, T2_>;
    PPair = ^TPair;
    TPair_BigList__ = TBigList<TPair>;
    PPair__ = TPair_BigList__.PQueueStruct;
  public
    List: TPair_BigList__;
    property L: TPair_BigList__ read List;
    constructor Create;
    destructor Destroy; override;
    procedure DoFree(var Data: TPair); virtual;
    procedure DoAdd(var Data: TPair); virtual;
    function Add_Pair(Primary: T1_; Second: T2_): PPair__;
  end;

  TPair3_Tool<T1_, T2_, T3_> = class(TCore_Object_Intermediate)
  public type
    TPair = TPair3<T1_, T2_, T3_>;
    PPair = ^TPair;
    TPair_BigList__ = TBigList<TPair>;
    PPair__ = TPair_BigList__.PQueueStruct;
  public
    List: TPair_BigList__;
    property L: TPair_BigList__ read List;
    constructor Create;
    destructor Destroy; override;
    procedure DoFree(var Data: TPair); virtual;
    procedure DoAdd(var Data: TPair); virtual;
    function Add_Pair(Primary: T1_; Second: T2_; Third: T3_): PPair__;
  end;

  TPair4_Tool<T1_, T2_, T3_, T4_> = class(TCore_Object_Intermediate)
  public type
    TPair = TPair4<T1_, T2_, T3_, T4_>;
    PPair = ^TPair;
    TPair_BigList__ = TBigList<TPair>;
    PPair__ = TPair_BigList__.PQueueStruct;
  public
    List: TPair_BigList__;
    property L: TPair_BigList__ read List;
    constructor Create;
    destructor Destroy; override;
    procedure DoFree(var Data: TPair); virtual;
    procedure DoAdd(var Data: TPair); virtual;
    function Add_Pair(Primary: T1_; Second: T2_; Third: T3_; Fourth: T4_): PPair__;
  end;

  TPair5_Tool<T1_, T2_, T3_, T4_, T5_> = class(TCore_Object_Intermediate)
  public type
    TPair = TPair5<T1_, T2_, T3_, T4_, T5_>;
    PPair = ^TPair;
    TPair_BigList__ = TBigList<TPair>;
    PPair__ = TPair_BigList__.PQueueStruct;
  public
    List: TPair_BigList__;
    property L: TPair_BigList__ read List;
    constructor Create;
    destructor Destroy; override;
    procedure DoFree(var Data: TPair); virtual;
    procedure DoAdd(var Data: TPair); virtual;
    function Add_Pair(Primary: T1_; Second: T2_; Third: T3_; Fourth: T4_; Five: T5_): PPair__;
  end;

  TPair6_Tool<T1_, T2_, T3_, T4_, T5_, T6_> = class(TCore_Object_Intermediate)
  public type
    TPair = TPair6<T1_, T2_, T3_, T4_, T5_, T6_>;
    PPair = ^TPair;
    TPair_BigList__ = TBigList<TPair>;
    PPair__ = TPair_BigList__.PQueueStruct;
  public
    List: TPair_BigList__;
    property L: TPair_BigList__ read List;
    constructor Create;
    destructor Destroy; override;
    procedure DoFree(var Data: TPair); virtual;
    procedure DoAdd(var Data: TPair); virtual;
    function Add_Pair(Primary: T1_; Second: T2_; Third: T3_; Fourth: T4_; Five: T5_; Six: T6_): PPair__;
  end;
{$ENDREGION 'Pair'}
{$Region 'Hash-Tool'}
{
  TBig_Hash_Pair_Pool<TKey, TValue> – a generic hash map with open addressing
  and collision resolution using linked lists (chaining).
  It uses a CRC32 hash of the key by default, but custom key hashing and
  comparison can be provided via events (On_Get_Key, On_Compare_Key).
  Features:
    - Automatic rehashing: the number of buckets is fixed at creation.
    - LRU optimization: recently accessed keys are moved to the front of
      their bucket list for faster subsequent lookups.
    - Object recycling: removed entries are pooled for reuse.
    - Sorting: the entire map can be sorted by key or value using quicksort.
    - Multiple iteration styles: forward, reverse, and with abortable callbacks.
    - Thread‑safe version (TCritical_Big_Hash_Pair_Pool) adds a lock around
      every public operation.
  This is the primary associative container used in the Z framework.
}
  TBig_Hash_Pair_Pool<TKey_, TValue_> = class(TCore_Object_Intermediate)
  public type
    PKey_ = ^TKey_;                                              // Pointer to key type
    PValue_ = ^TValue_;                                          // Pointer to value type
    PKey = PKey_;                                                // Alias for pointer to key
    PValue = PValue_;                                            // Alias for pointer to value
    T___ = TBig_Hash_Pair_Pool<TKey_, TValue_>;                  // Self-reference for nested types
    TValue_Pair_Pool__ = TPair4_Tool<TKey_, TValue_, Pointer, THash>; // Internal storage: key, value, queue node pointer, hash
    PPair_Pool_Value__ = TValue_Pair_Pool__.PPair__;             // Pointer to a stored entry (pair)
    TPair = TValue_Pair_Pool__.TPair;                            // The actual pair record (key, value, ptr, hash)
    TKey_Hash_Buffer = TGenericsList<TValue_Pair_Pool__>;        // Bucket array: each slot is a list of pairs
    TPool___ = TBigList<PPair_Pool_Value__>;                     // Global queue pool for iteration (all entries)
    TPool_Queue_Ptr___ = TPool___.PQueueStruct;                  // Node pointer within the global queue
    TRepeat___ = TPool___.TRepeat___;                            // Forward iterator over the global queue
    TInvert_Repeat___ = TPool___.TInvert_Repeat___;              // Reverse iterator over the global queue
    TArray_Key = array of TKey_;                                 // Dynamic array of keys
    TOrder_Key = TOrderStruct<TKey_>;                            // FIFO queue of keys
    TArray_Value = array of TValue_;                             // Dynamic array of values
    TOrder_Value = TOrderStruct<TValue_>;                        // FIFO queue of values
    // event
    TOn_Event = procedure(var Key: TKey_; var Value: TValue_) of object; // Called on add/free
    TOn_Get_Key = procedure(const Key_: PKey_; var Hash:THash) of object; // Custom hash computation
    TOn_Compare_Key = procedure(const Key_1, Key_2: PKey_; var IsSame:Boolean) of object; // Custom key equality
    TOn_Compare_Value = procedure(const Value_1, Value_2: PValue_; var IsSame:Boolean) of object; // Custom value equality
    TOn_Sort_Key_C = function(var L, R: TKey_): Integer;         // Sort comparator for keys (C-style)
    TOn_Sort_Key_M = function(var L, R: TKey_): Integer of object; // Sort comparator for keys (M-style)
    TOn_Sort_Value_C = function(var L, R: TValue_): Integer;     // Sort comparator for values (C-style)
    TOn_Sort_Value_M = function(var L, R: TValue_): Integer of object; // Sort comparator for values (M-style)
    TBig_Hash_Pool_For_C = procedure(p: PPair_Pool_Value__; var Aborted: Boolean); // Iterator callback (C)
    TBig_Hash_Pool_For_M = procedure(p: PPair_Pool_Value__; var Aborted: Boolean) of object; // Iterator callback (M)
{$IFDEF FPC}
    TBig_Hash_Pool_For_P = procedure(p: PPair_Pool_Value__; var Aborted: Boolean) is nested; // Iterator callback (P – nested)
    TOn_Sort_Key_P = function(var L, R: TKey_): Integer is nested; // Sort comparator for keys (P – nested)
    TOn_Sort_Value_P = function(var L, R: TValue_): Integer is nested; // Sort comparator for values (P – nested)
{$ELSE FPC}
    TBig_Hash_Pool_For_P = reference to procedure(p: PPair_Pool_Value__; var Aborted: Boolean); // Iterator callback (P – anonymous)
    TOn_Sort_Key_P = reference to function(var L, R: TKey_): Integer; // Sort comparator for keys (P – anonymous)
    TOn_Sort_Value_P = reference to function(var L, R: TValue_): Integer; // Sort comparator for values (P – anonymous)
{$ENDIF FPC}
  private
    FCritical__: TCritical;                                      // Lock for thread safety (lazy-created)
    FQueue_Pool: TPool___;                                       // Global list of all entries (for iteration)
    FHash_Buffer: TKey_Hash_Buffer;                              // Bucket array of collision lists
    FNULL_VALUE: TValue_;                                        // Default value returned for missing keys
    FOnAdd: TOn_Event;                                           // User hook on add
    FOnFree: TOn_Event;                                          // User hook on free
    FOn_Get_Key: TOn_Get_Key;                                    // Custom key hash function
    FOn_Compare_Key: TOn_Compare_Key;                            // Custom key comparison
    FOn_Compare_Value: TOn_Compare_Value;                        // Custom value comparison
    function Get_Critical__: TCritical;                          // Returns the lock, creating it if nil
    function Get_Value_List(const Key_: TKey_; var Key_Hash_: THash): TValue_Pair_Pool__; // Locates the bucket list for a key (creates if missing)
    procedure Free_Value_List(Key_Hash_: THash);                 // Frees an empty bucket list
    procedure Get_Key_Data_Ptr(const Key_P: PKey_; var p: PByte; var Size: NativeInt); // Default key raw data pointer for hashing
    procedure Internal_Do_Queue_Pool_Free(var Data: PPair_Pool_Value__); // Called when an entry is removed from the global queue
    procedure Internal_Do_Free(var Data: TPair);                 // Called when a pair is freed from a bucket list
  public
    class function Null_Key: TKey_;                              // Returns a zero-initialized key
    class function NULL_VALUE: TValue_;                          // Returns a zero-initialized value
    property Critical__: TCritical read Get_Critical__;          // Access to the internal lock
    property Queue_Pool: TPool___ read FQueue_Pool;              // Direct access to the global entry list
    property OnAdd: TOn_Event read FOnAdd write FOnAdd;          // Hook for add events
    property OnFree: TOn_Event read FOnFree write FOnFree;       // Hook for free events
    property On_Get_Key: TOn_Get_Key read FOn_Get_Key write FOn_Get_Key; // Custom key hashing
    property On_Compare_Key: TOn_Compare_Key read FOn_Compare_Key write FOn_Compare_Key; // Custom key equality
    property On_Compare_Value: TOn_Compare_Value read FOn_Compare_Value write FOn_Compare_Value; // Custom value equality
    constructor Create(const HashSize_: integer; const NULL_VALUE_: TValue_); overload; // Constructor with specified null value
    constructor Create(const HashSize_: integer); overload;      // Constructor with default null value (zeroed)
    destructor Destroy; override;                                // Cleans up all resources
    procedure CreateBefore; virtual;                             // Pre-initialization hook (called in constructor)
    procedure CreateAfter; virtual;                              // Post-initialization hook
    procedure DoFree(var Key: TKey_; var Value: TValue_); virtual; // Internal free handler (calls OnFree)
    procedure DoAdd(var Key: TKey_; var Value: TValue_); virtual; // Internal add handler (calls OnAdd)
    function Get_Key_Hash(const Key_: TKey_): THash; virtual;    // Computes hash for a key (uses custom hook or default CRC32)
    function Compare_Key(const Key_1, Key_2: TKey_): Boolean; virtual; // Compares two keys (custom or memory compare)
    function Compare_Value(const Value_1, Value_2: TValue_): Boolean; virtual; // Compares two values (custom or memory compare)
    procedure Lock;                                              // Acquires the internal lock
    procedure UnLock;                                            // Releases the internal lock
    procedure Extract_Queue_Pool_Third;                          // Rebuilds the `Third` pointer of each queue node (after sorting)
    function GetHashSize: Integer;                               // Returns the number of buckets
    procedure Clear;                                             // Removes all entries
    function Exists_Key(const Key: TKey_): Boolean;              // Checks if a key exists (moves it to front on hit)
    function Exists_Value(const Data: TValue_): Boolean;         // Checks if any entry has the given value (linear scan)
    function Exists(const Key: TKey_): Boolean;                  // Alias for Exists_Key
    function Add(const Key: TKey_; const Value: TValue_; Overwrite_: Boolean): PPair_Pool_Value__; // Inserts or updates an entry; returns pointer to the pair
    function Get_Key_Value(const Key: TKey_): TValue_;           // Retrieves value for a key; returns FNULL_VALUE if not found
    procedure Set_Key_Value(const Key: TKey_; const Value: TValue_); // Sets value for a key (overwrites if exists)
    property Key_Value[const Key: TKey_]: TValue_ read Get_Key_Value write Set_Key_Value; default; // Indexed access by key
    procedure Delete(const Key: TKey_);                          // Removes an entry by key
    procedure Remove(p: PPair_Pool_Value__); overload;           // Removes an entry by its pair pointer (with recycling)
    procedure Remove(p: PPair_Pool_Value__; Do_Free_Recycle_Pool_:Boolean); overload; // Removes with option to immediately free recycle pool
    function Num: NativeInt;                                     // Returns number of entries (O(1) via queue pool count)
    property Count: NativeInt read Num;                          // Alias for Num
    function GetSum: NativeInt;                                  // Returns total count across all buckets (linear scan – O(buckets))
    property Sum: NativeInt read GetSum;                         // Alias for GetSum
    function Get_Value_Ptr(const Key: TKey_): PValue_; overload; // Returns pointer to value for a key; inserts default if missing
    function Get_Value_Ptr(const Key: TKey_; const Default_: TValue_): PValue_; overload; // Returns pointer; inserts given default if missing
    function Get_Default_Value(const Key: TKey_; const Default_: TValue_): TValue_; // Returns value or default if missing (does not insert)
    procedure Set_Default_Value(const Key: TKey_; const Default_: TValue_); // Same as Add with overwrite=true
    function Repeat_(): TRepeat___; overload;                    // Forward iterator over all entries
    function Repeat_(BI_, EI_: NativeInt): TRepeat___; overload; // Forward iterator over a range (by global queue indices)
    function Invert_Repeat_(): TInvert_Repeat___; overload;      // Reverse iterator
    function Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___; overload; // Reverse iterator over a range
    procedure For_C(OnFor: TBig_Hash_Pool_For_C); overload;      // Iterate with C-style callback (abortable)
    procedure For_M(OnFor: TBig_Hash_Pool_For_M); overload;      // Iterate with M-style callback
    procedure For_P(OnFor: TBig_Hash_Pool_For_P); overload;      // Iterate with P-style callback
    {******************************************************************************
      Recycle Pool Management for Hash Map Entries
      --------------------------------------------
      These methods manage the deferred destruction of hash map entries.
      When an entry is removed from the hash table, its node is not freed
      immediately; instead, it is pushed into a per-bucket recycle pool
      (FRecycle_Pool__). This reduces memory allocation overhead during
      high‑frequency add/delete operations.
      IMPORTANT - Why two separate methods instead of overloaded versions?
      -------------------------------------------------------------------
      Both parameters are pointer types: PPair_Pool_Value__ (pointer to the
      pair record stored in the bucket's linked list) and TPool_Queue_Ptr___
      (pointer to the node in the global queue pool). In FPC, overload
      resolution for pointer types is ambiguous when both arguments are
      pointers, because the compiler may not distinguish them based on
      type alone (they are both just Pointer at the low level). Delphi's
      overload rules are stricter and can handle this, but FPC's are more
      permissive, often resulting in "ambiguous overload" errors or
      silently selecting the wrong method.
      By giving them distinct names, we guarantee correct compilation
      under both compilers without relying on fragile overload heuristics.
      This is a deliberate design decision – not a limitation, but a
      defensive measure.
    ******************************************************************************}
    {**
      Moves an entry to the recycle pool by its bucket-list node pointer.
      @param p  Pointer to the pair record (PPair_Pool_Value__) that was
                obtained from the bucket's linked list (e.g., via iteration
                over the hash bucket). This pointer references the actual
                key-value pair stored in the hash map.
      @note The entry will not be destroyed immediately; it will be kept
            in the recycle pool until Free_Recycle_Pool is called, at which
            point its memory is released (or reused for future insertions).
            This method is typically called when you have a direct reference
            to an entry from the bucket list (e.g., during a custom scan).
      @warning The pointer must belong to the current hash table instance.
               Passing a pointer from a different instance or an invalid
               pointer will cause undefined behavior (memory corruption /
               access violation).
    }
    procedure Push_To_Recycle_Pool(p: PPair_Pool_Value__);
    {**
      Moves an entry to the recycle pool by its global queue node pointer.
      @param p  Pointer to the node (TPool_Queue_Ptr___) that holds the
                same entry in the global iteration queue (FQueue_Pool).
                This pointer is typically obtained when iterating over the
                entire hash map using Repeat_(), For_C(), etc., where the
                iterator yields queue nodes.
      @note This method is functionally equivalent to the first one, but
            it accepts the queue node pointer rather than the bucket node
            pointer. Internally, it extracts the actual entry pointer from
            the queue node and enqueues it for recycling. It is used when
            you want to remove the current entry during iteration without
            breaking the iterator's integrity.
      @see Push_To_Recycle_Pool
      @warning Same warning applies: the pointer must be valid and belong
               to this hash table instance.
    }
    procedure Push_To_Recycle_Pool2(p: TPool_Queue_Ptr___);
    {**
      Frees all entries currently in the recycle pool and removes empty
      bucket lists.
      @note After this call, all recycled entries are destroyed (their
            DoFree handler is invoked), and any bucket list that becomes
            empty is freed to reduce memory footprint. This operation
            is typically called periodically or during hash table cleanup.
      @warning This method does NOT lock the hash table; the caller is
               responsible for ensuring that no concurrent operations are
               modifying the table while this method runs. For thread‑safe
               usage, call it while holding the hash table's lock.
    }
    procedure Free_Recycle_Pool;

    procedure Sort_Key_C(OnSort: TOn_Sort_Key_C);                // Sorts the global queue by key (C comparator)
    procedure Sort_Key_M(OnSort: TOn_Sort_Key_M);                // Sorts by key (M comparator)
    procedure Sort_Key_P(OnSort: TOn_Sort_Key_P);                // Sorts by key (P comparator)
    procedure Sort_Value_C(OnSort: TOn_Sort_Value_C);            // Sorts by value (C comparator)
    procedure Sort_Value_M(OnSort: TOn_Sort_Value_M);            // Sorts by value (M comparator)
    procedure Sort_Value_P(OnSort: TOn_Sort_Value_P);            // Sorts by value (P comparator)
    function ToPool(): TPool___;                                 // Creates a new BigList containing all entry pointers
    function ToArray_Key(): TArray_Key;                          // Returns all keys as a dynamic array (order of global queue)
    function ToOrder_Key(): TOrder_Key;                          // Returns all keys as a FIFO queue
    function ToArray_Value(): TArray_Value;                      // Returns all values as a dynamic array
    function ToOrder_Value(): TOrder_Value;                      // Returns all values as a FIFO queue
  end;
  // ========================================================================
  // Thread-safe version – every public method is protected by FCritical__
  // ========================================================================
  TCritical_Big_Hash_Pair_Pool<TKey_, TValue_> = class(TCore_Object_Intermediate)
  public type
    PKey_ = ^TKey_;                                              // Pointer to key type
    PValue_ = ^TValue_;                                          // Pointer to value type
    PKey = PKey_;                                                // Alias for pointer to key
    PValue = PValue_;                                            // Alias for pointer to value
    T___ = TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>;         // Self-reference
    TValue_Pair_Pool__ = TPair4_Tool<TKey_, TValue_, Pointer, THash>; // Internal pair storage
    PPair_Pool_Value__ = TValue_Pair_Pool__.PPair__;             // Pointer to pair entry
    TPair = TValue_Pair_Pool__.TPair;                            // The pair record
    TKey_Hash_Buffer = TGenericsList<TValue_Pair_Pool__>;        // Bucket array
    TPool___ = TBigList<PPair_Pool_Value__>;                     // Global queue for iteration
    TPool_Queue_Ptr___ = TPool___.PQueueStruct;                  // Node in global queue
    TRepeat___ = TPool___.TRepeat___;                            // Forward iterator
    TInvert_Repeat___ = TPool___.TInvert_Repeat___;              // Reverse iterator
    TArray_Key = array of TKey_;                                 // Dynamic key array
    TOrder_Key = TOrderStruct<TKey_>;                            // FIFO key queue
    TArray_Value = array of TValue_;                             // Dynamic value array
    TOrder_Value = TOrderStruct<TValue_>;                        // FIFO value queue
    // events
    TOn_Event = procedure(var Key: TKey_; var Value: TValue_) of object;
    TOn_Get_Key = procedure(const Key_: PKey_; var Hash:THash) of object;
    TOn_Compare_Key = procedure(const Key_1, Key_2: PKey_; var IsSame:Boolean) of object;
    TOn_Compare_Value = procedure(const Value_1, Value_2: PValue_; var IsSame:Boolean) of object;
    TOn_Sort_Key_C = function(var L, R: TKey_): Integer;
    TOn_Sort_Key_M = function(var L, R: TKey_): Integer of object;
    TOn_Sort_Value_C = function(var L, R: TValue_): Integer;
    TOn_Sort_Value_M = function(var L, R: TValue_): Integer of object;
    TBig_Hash_Pool_For_C = procedure(p: PPair_Pool_Value__; var Aborted: Boolean);
    TBig_Hash_Pool_For_M = procedure(p: PPair_Pool_Value__; var Aborted: Boolean) of object;
{$IFDEF FPC}
    TBig_Hash_Pool_For_P = procedure(p: PPair_Pool_Value__; var Aborted: Boolean) is nested;
    TOn_Sort_Key_P = function(var L, R: TKey_): Integer is nested;
    TOn_Sort_Value_P = function(var L, R: TValue_): Integer is nested;
{$ELSE FPC}
    TBig_Hash_Pool_For_P = reference to procedure(p: PPair_Pool_Value__; var Aborted: Boolean);
    TOn_Sort_Key_P = reference to function(var L, R: TKey_): Integer;
    TOn_Sort_Value_P = reference to function(var L, R: TValue_): Integer;
{$ENDIF FPC}
  private
    FCritical__: TCritical;                                      // Lock – always created in constructor
    FQueue_Pool: TPool___;                                       // Global entry list
    FHash_Buffer: TKey_Hash_Buffer;                              // Buckets
    FNULL_VALUE: TValue_;                                        // Default null value
    FOnAdd: TOn_Event;                                           // Add hook
    FOnFree: TOn_Event;                                          // Free hook
    FOn_Get_Key: TOn_Get_Key;                                    // Custom hash
    FOn_Compare_Key: TOn_Compare_Key;                            // Custom key compare
    FOn_Compare_Value: TOn_Compare_Value;                        // Custom value compare
    function Get_Value_List(const Key_: TKey_; var Key_Hash_: THash): TValue_Pair_Pool__; // Get bucket list, create if missing
    procedure Free_Value_List(Key_Hash_: THash);                 // Destroy empty bucket
    procedure Get_Key_Data_Ptr(const Key_P: PKey_; var p: PByte; var Size: NativeInt); // Raw key bytes
    procedure Internal_Do_Queue_Pool_Free(var Data: PPair_Pool_Value__); // Called when queue node removed
    procedure Internal_Do_Free(var Data: TPair);                 // Called when pair freed from bucket
  public
    class function Null_Key: TKey_;                              // Zeroed key
    class function NULL_VALUE: TValue_;                          // Zeroed value
    property Critical__: TCritical read FCritical__;             // Expose the lock
    property Queue_Pool: TPool___ read FQueue_Pool;              // Direct global queue access
    property OnAdd: TOn_Event read FOnAdd write FOnAdd;
    property OnFree: TOn_Event read FOnFree write FOnFree;
    property On_Get_Key: TOn_Get_Key read FOn_Get_Key write FOn_Get_Key;
    property On_Compare_Key: TOn_Compare_Key read FOn_Compare_Key write FOn_Compare_Key;
    property On_Compare_Value: TOn_Compare_Value read FOn_Compare_Value write FOn_Compare_Value;
    constructor Create(const HashSize_: integer; const NULL_VALUE_: TValue_); overload; // Create with custom null value
    constructor Create(const HashSize_: integer); overload;      // Create with zeroed null value
    destructor Destroy; override;                                // Cleanup
    procedure CreateBefore; virtual;                             // Pre-creation hook
    procedure CreateAfter; virtual;                              // Post-creation hook
    procedure DoFree(var Key: TKey_; var Value: TValue_); virtual; // Fire OnFree
    procedure DoAdd(var Key: TKey_; var Value: TValue_); virtual; // Fire OnAdd
    function Get_Key_Hash(const Key_: TKey_): THash; virtual;    // Compute hash (custom or CRC32)
    function Compare_Key(const Key_1, Key_2: TKey_): Boolean; virtual; // Compare keys
    function Compare_Value(const Value_1, Value_2: TValue_): Boolean; virtual; // Compare values
    procedure Lock;                                              // Acquire lock
    procedure UnLock;                                            // Release lock
    procedure Extract_Queue_Pool_Third;                          // Re-sync Third pointers after sort
    function GetHashSize: Integer;                               // Number of buckets
    procedure Clear;                                             // Remove all entries
    function Exists_Key(const Key: TKey_): Boolean;              // Check key existence (moves to front if found)
    function Exists_Value(const Data: TValue_): Boolean;         // Check value existence (linear scan)
    function Exists(const Key: TKey_): Boolean;                  // Alias for Exists_Key
    function Add(const Key: TKey_; const Value: TValue_; Overwrite_: Boolean): PPair_Pool_Value__; // Insert/update, returns pair pointer
    function Get_Key_Value(const Key: TKey_): TValue_;           // Get value, returns NULL_VALUE if absent
    procedure Set_Key_Value(const Key: TKey_; const Value: TValue_); // Set value (overwrites if exists)
    property Key_Value[const Key: TKey_]: TValue_ read Get_Key_Value write Set_Key_Value; default;
    procedure Delete(const Key: TKey_);                          // Remove by key
    procedure Remove(p: PPair_Pool_Value__); overload;           // Remove by pair pointer (with recycle)
    procedure Remove(p: PPair_Pool_Value__; Do_Free_Recycle_Pool_:Boolean); overload; // Remove, optionally free recycle pool immediately
    function Num: NativeInt;                                     // Entry count (O(1) via queue pool)
    property Count: NativeInt read Num;
    function GetSum: NativeInt;                                  // Total across all buckets (O(buckets))
    property Sum: NativeInt read GetSum;
    function Get_Value_Ptr(const Key: TKey_): PValue_; overload; // Get pointer to value; creates with NULL_VALUE if missing
    function Get_Value_Ptr(const Key: TKey_; const Default_: TValue_): PValue_; overload; // Get pointer; creates with given default if missing
    function Get_Default_Value(const Key: TKey_; const Default_: TValue_): TValue_; // Get value or default (no insertion)
    procedure Set_Default_Value(const Key: TKey_; const Default_: TValue_); // Same as Add with overwrite
    function Repeat_(): TRepeat___; overload;                    // Forward iterator over all entries
    function Repeat_(BI_, EI_: NativeInt): TRepeat___; overload; // Forward iterator with index range
    function Invert_Repeat_(): TInvert_Repeat___; overload;      // Reverse iterator
    function Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___; overload; // Reverse iterator with index range
    procedure For_C(OnFor: TBig_Hash_Pool_For_C); overload;      // Iterate with C callback
    procedure For_M(OnFor: TBig_Hash_Pool_For_M); overload;      // Iterate with M callback
    procedure For_P(OnFor: TBig_Hash_Pool_For_P); overload;      // Iterate with P callback

    {******************************************************************************
      Recycle Pool Management for Hash Map Entries
      --------------------------------------------
      These methods manage the deferred destruction of hash map entries.
      When an entry is removed from the hash table, its node is not freed
      immediately; instead, it is pushed into a per-bucket recycle pool
      (FRecycle_Pool__). This reduces memory allocation overhead during
      high‑frequency add/delete operations.
      IMPORTANT - Why two separate methods instead of overloaded versions?
      -------------------------------------------------------------------
      Both parameters are pointer types: PPair_Pool_Value__ (pointer to the
      pair record stored in the bucket's linked list) and TPool_Queue_Ptr___
      (pointer to the node in the global queue pool). In FPC, overload
      resolution for pointer types is ambiguous when both arguments are
      pointers, because the compiler may not distinguish them based on
      type alone (they are both just Pointer at the low level). Delphi's
      overload rules are stricter and can handle this, but FPC's are more
      permissive, often resulting in "ambiguous overload" errors or
      silently selecting the wrong method.
      By giving them distinct names, we guarantee correct compilation
      under both compilers without relying on fragile overload heuristics.
      This is a deliberate design decision – not a limitation, but a
      defensive measure.
    ******************************************************************************}
    {**
      Moves an entry to the recycle pool by its bucket-list node pointer.
      @param p  Pointer to the pair record (PPair_Pool_Value__) that was
                obtained from the bucket's linked list (e.g., via iteration
                over the hash bucket). This pointer references the actual
                key-value pair stored in the hash map.
      @note The entry will not be destroyed immediately; it will be kept
            in the recycle pool until Free_Recycle_Pool is called, at which
            point its memory is released (or reused for future insertions).
            This method is typically called when you have a direct reference
            to an entry from the bucket list (e.g., during a custom scan).
      @warning The pointer must belong to the current hash table instance.
               Passing a pointer from a different instance or an invalid
               pointer will cause undefined behavior (memory corruption /
               access violation).
    }
    procedure Push_To_Recycle_Pool(p: PPair_Pool_Value__);
    {**
      Moves an entry to the recycle pool by its global queue node pointer.
      @param p  Pointer to the node (TPool_Queue_Ptr___) that holds the
                same entry in the global iteration queue (FQueue_Pool).
                This pointer is typically obtained when iterating over the
                entire hash map using Repeat_(), For_C(), etc., where the
                iterator yields queue nodes.
      @note This method is functionally equivalent to the first one, but
            it accepts the queue node pointer rather than the bucket node
            pointer. Internally, it extracts the actual entry pointer from
            the queue node and enqueues it for recycling. It is used when
            you want to remove the current entry during iteration without
            breaking the iterator's integrity.
      @see Push_To_Recycle_Pool
      @warning Same warning applies: the pointer must be valid and belong
               to this hash table instance.
    }
    procedure Push_To_Recycle_Pool2(p: TPool_Queue_Ptr___);
    {**
      Frees all entries currently in the recycle pool and removes empty
      bucket lists.
      @note After this call, all recycled entries are destroyed (their
            DoFree handler is invoked), and any bucket list that becomes
            empty is freed to reduce memory footprint. This operation
            is typically called periodically or during hash table cleanup.
      @warning This method does NOT lock the hash table; the caller is
               responsible for ensuring that no concurrent operations are
               modifying the table while this method runs. For thread‑safe
               usage, call it while holding the hash table's lock.
    }
    procedure Free_Recycle_Pool;

    procedure Sort_Key_C(OnSort: TOn_Sort_Key_C);                // Sort global queue by key (C)
    procedure Sort_Key_M(OnSort: TOn_Sort_Key_M);                // Sort by key (M)
    procedure Sort_Key_P(OnSort: TOn_Sort_Key_P);                // Sort by key (P)
    procedure Sort_Value_C(OnSort: TOn_Sort_Value_C);            // Sort by value (C)
    procedure Sort_Value_M(OnSort: TOn_Sort_Value_M);            // Sort by value (M)
    procedure Sort_Value_P(OnSort: TOn_Sort_Value_P);            // Sort by value (P)
    function ToPool(): TPool___;                                 // New BigList of all entry pointers
    function ToArray_Key(): TArray_Key;                          // Dynamic array of keys
    function ToOrder_Key(): TOrder_Key;                          // FIFO queue of keys
    function ToArray_Value(): TArray_Value;                      // Dynamic array of values
    function ToOrder_Value(): TOrder_Value;                      // FIFO queue of values
  end;
  // ========================================================================
  // Object‑specific version for TValue_ that is a class – adds AutoFree
  // ========================================================================
  TBig_Hash_Object_Pool<TKey_, TValue_: class> = class(TBig_Hash_Pair_Pool<TKey_, TValue_>)
  public
    AutoFree: Boolean;                                           // If True, frees the value object on removal
    constructor Create(const HashSize_: integer; const AutoFree_: Boolean); // Pass autofree flag
    procedure DoFree(var Key: TKey_; var Value: TValue_); override; // Override to dispose object if AutoFree
  end;
  // Thread‑safe object pool
  TCritical_Big_Hash_Object_Pool<TKey_, TValue_: class> = class(TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>)
  public
    AutoFree: Boolean;                                           // If True, frees value object on removal
    constructor Create(const HashSize_: integer; const AutoFree_: Boolean); // Constructor with autofree flag
    procedure DoFree(var Key: TKey_; var Value: TValue_); override; // Override to dispose object if AutoFree
  end;
{$EndRegion 'Hash-Tool'}
{$REGION 'soft_synchronize_technology'}
{
  TSoft_Synchronize_Tool – a user space implementation of thread synchronisation
  that avoids the operating system's kernel‑level primitives.

  Instead of using TMonitor or TEvent, it uses a queue (TSynchronize_Queue___)
  and a busy-wait loop on a Boolean flag (Wait_Signal__) to block the calling
  thread until the main thread processes the queued procedure.

  This reduces context-switching overhead and is especially beneficial in
  high-frequency, low-latency scenarios where the cost of entering the kernel
  is significant. However, it consumes CPU cycles during the wait.

  It is used as a replacement for TThread.Synchronize when the define
  'Core_Thread_Soft_Synchronize' is active.
}
  // soft thread-synchronize simulator
  TOnSynchronize_C_NP = procedure();
  TOnSynchronize_M_NP = procedure() of object;
{$IFDEF FPC}
  TOnSynchronize_P_NP = procedure() is nested;
{$ELSE FPC}
  TOnSynchronize_P_NP = reference to procedure();
{$ENDIF FPC}

  TSoft_Synchronize_Tool = class(TCore_Object_Intermediate)
  private type
    TSynchronize_Data___ = TPair4<TOnSynchronize_C_NP, TOnSynchronize_M_NP, TOnSynchronize_P_NP, Boolean>;
    PSynchronize_Data___ = ^TSynchronize_Data___;
    TSynchronize_Queue___ = TOrderStruct<PSynchronize_Data___>;
  private
    SyncQueue__: TSynchronize_Queue___;
    Critical__: TCritical;
  public
    Soft_Synchronize_Main_Thread: TCore_Thread;
    constructor Create(Soft_Synchronize_Main_Thread_: TCore_Thread);
    destructor Destroy; override;
    function Check_Synchronize(Check_Time_: TTimeTick): NativeInt;

    procedure Synchronize(OnSync: TOnSynchronize_P_NP); overload;
    procedure Synchronize_C(OnSync: TOnSynchronize_C_NP); overload;
    procedure Synchronize_M(OnSync: TOnSynchronize_M_NP); overload;
    procedure Synchronize_P(OnSync: TOnSynchronize_P_NP); overload;
    procedure Synchronize(Thread_: TCore_Thread; OnSync: TOnSynchronize_P_NP); overload;
    procedure Synchronize_C(Thread_: TCore_Thread; OnSync: TOnSynchronize_C_NP); overload;
    procedure Synchronize_M(Thread_: TCore_Thread; OnSync: TOnSynchronize_M_NP); overload;
    procedure Synchronize_P(Thread_: TCore_Thread; OnSync: TOnSynchronize_P_NP); overload;
  end;
{$ENDREGION 'soft_synchronize_technology'}
{$Region 'ThreadPost'}
{
  TThreadPost – a queue for posting procedures to be executed on a specific
  thread (typically the main thread). It supports three callback styles:
    - C: simple procedure (no parameters, no object)
    - M: method of an object (of object)
    - P: anonymous/nested reference (reference to procedure)

  The target thread calls Progress() to drain the queue, executing each
  procedure in FIFO order. This is used for cross‑thread communication and
  is the foundation of the “post” system in TCompute and other thread‑pool
  components.

  Features:
    - OneStep: if True, only one procedure is executed per Progress call.
    - ResetRandomSeed: if True, the MT19937 seed is reset before each execution.
    - Sync_Wait_* methods block the caller until the posted procedure is executed.
}
  TThreadPost_C1 = procedure();
  TThreadPost_C2 = procedure(Data1: Pointer);
  TThreadPost_C3 = procedure(Data1: Pointer; Data2: TCore_Object; Data3: Variant);
  TThreadPost_C4 = procedure(Data1: Pointer; Data2: TCore_Object);
  TThreadPost_M1 = procedure() of object;
  TThreadPost_M2 = procedure(Data1: Pointer) of object;
  TThreadPost_M3 = procedure(Data1: Pointer; Data2: TCore_Object; Data3: Variant) of object;
  TThreadPost_M4 = procedure(Data1: Pointer; Data2: TCore_Object) of object;
{$IFDEF FPC}
  TThreadPost_P1 = procedure() is nested;
  TThreadPost_P2 = procedure(Data1: Pointer) is nested;
  TThreadPost_P3 = procedure(Data1: Pointer; Data2: TCore_Object; Data3: Variant) is nested;
  TThreadPost_P4 = procedure(Data1: Pointer; Data2: TCore_Object) is nested;
{$ELSE FPC}
  TThreadPost_P1 = reference to procedure();
  TThreadPost_P2 = reference to procedure(Data1: Pointer);
  TThreadPost_P3 = reference to procedure(Data1: Pointer; Data2: TCore_Object; Data3: Variant);
  TThreadPost_P4 = reference to procedure(Data1: Pointer; Data2: TCore_Object);
{$ENDIF FPC}

  TThreadPost = class(TCore_Object_Intermediate)
  private type
    TThread_Post_Data = record
      On_C1: TThreadPost_C1;
      On_C2: TThreadPost_C2;
      On_C3: TThreadPost_C3;
      On_C4: TThreadPost_C4;
      On_M1: TThreadPost_M1;
      On_M2: TThreadPost_M2;
      On_M3: TThreadPost_M3;
      On_M4: TThreadPost_M4;
      On_P1: TThreadPost_P1;
      On_P2: TThreadPost_P2;
      On_P3: TThreadPost_P3;
      On_P4: TThreadPost_P4;
      Data1: Pointer;
      Data2: TCore_Object;
      Data3: Variant;
      IsRuning, IsExit: PBoolean;
      procedure Init;
    end;

    TThread_Post_Data_Order_Struct__ = TOrderPtrStruct<TThread_Post_Data>;
  protected
    FCritical: TCritical;
    FThreadID: TThreadID;
    FSyncPool: TThread_Post_Data_Order_Struct__;
    FProgressing: TAtomBool;
    FOneStep: Boolean;
    FResetRandomSeed: Boolean;
    procedure FreeThreadProgressPostData(p: TThread_Post_Data_Order_Struct__.PT_);
  public
    constructor Create(ThreadID_: TThreadID);
    destructor Destroy; override;
    property ThreadID: TThreadID read FThreadID write FThreadID;
    property OneStep: Boolean read FOneStep write FOneStep;
    property ResetRandomSeed: Boolean read FResetRandomSeed write FResetRandomSeed;
    property SyncPool: TThread_Post_Data_Order_Struct__ read FSyncPool;
    function Count: NativeInt;
    property Num: NativeInt read Count;
    function Busy: Boolean;

    function Progress(ThreadID_: TThreadID): NativeInt; overload;
    function Progress(Thread_: TThread): NativeInt; overload;
    function Progress(): Integer; overload;

    // post thread
    procedure PostC_NP(OnSync: TThreadPost_C1); // Posts a C‑style procedure to the thread queue (non‑blocking, no status tracking).
    procedure PostM_NP(OnSync: TThreadPost_M1); // Posts an M‑style method to the thread queue (non‑blocking, no status tracking).
    procedure PostP_NP(OnSync: TThreadPost_P1); // Posts a P‑style procedure to the thread queue (non‑blocking, no status tracking).
    procedure PostC1(OnSync: TThreadPost_C1); overload; // Posts a C‑style procedure without extra data.
    procedure PostC1(OnSync: TThreadPost_C1; IsRuning_, IsExit_: PBoolean); overload; // Posts a C‑style procedure; sets IsRuning_=True while running, IsExit_=True when done.
    procedure PostC2(Data1: Pointer; OnSync: TThreadPost_C2); overload; // Posts a C‑style procedure with one pointer argument.
    procedure PostC2(Data1: Pointer; OnSync: TThreadPost_C2; IsRuning_, IsExit_: PBoolean); overload; // Posts a C‑style procedure with pointer; tracks execution status via IsRuning_ and IsExit_.
    procedure PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3); overload; // Posts a C‑style procedure with pointer, object, and Variant arguments.
    procedure PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3; IsRuning_, IsExit_: PBoolean); overload; // Posts C‑style with three arguments; tracks status via IsRuning_/IsExit_.
    procedure PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4); overload; // Posts a C‑style procedure with pointer and object arguments.
    procedure PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4; IsRuning_, IsExit_: PBoolean); overload; // Posts C‑style with pointer and object; tracks execution status.
    procedure PostM1(OnSync: TThreadPost_M1); overload; // Posts an M‑style method (object method) without extra data.
    procedure PostM1(OnSync: TThreadPost_M1; IsRuning_, IsExit_: PBoolean); overload; // Posts an M‑style method; tracks status via IsRuning_/IsExit_.
    procedure PostM2(Data1: Pointer; OnSync: TThreadPost_M2); overload; // Posts an M‑style method with one pointer argument.
    procedure PostM2(Data1: Pointer; OnSync: TThreadPost_M2; IsRuning_, IsExit_: PBoolean); overload; // Posts an M‑style method with pointer; tracks status.
    procedure PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3); overload; // Posts an M‑style method with pointer, object, and Variant.
    procedure PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3; IsRuning_, IsExit_: PBoolean); overload; // Posts M‑style with three args; tracks status.
    procedure PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4); overload; // Posts an M‑style method with pointer and object.
    procedure PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4; IsRuning_, IsExit_: PBoolean); overload; // Posts M‑style with pointer/object; tracks status.
    procedure PostP1(OnSync: TThreadPost_P1); overload; // Posts a P‑style procedure (nested/anonymous) without extra data.
    procedure PostP1(OnSync: TThreadPost_P1; IsRuning_, IsExit_: PBoolean); overload; // Posts a P‑style procedure; tracks status.
    procedure PostP2(Data1: Pointer; OnSync: TThreadPost_P2); overload; // Posts a P‑style procedure with one pointer argument.
    procedure PostP2(Data1: Pointer; OnSync: TThreadPost_P2; IsRuning_, IsExit_: PBoolean); overload; // Posts P‑style with pointer; tracks status.
    procedure PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3); overload; // Posts a P‑style procedure with pointer, object, and Variant.
    procedure PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3; IsRuning_, IsExit_: PBoolean); overload; // Posts P‑style with three args; tracks status.
    procedure PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4); overload; // Posts a P‑style procedure with pointer and object.
    procedure PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4; IsRuning_, IsExit_: PBoolean); overload; // Posts P‑style with pointer/object; tracks status.

    // post thread and wait sync
    procedure Sync_Wait_PostC1(OnSync: TThreadPost_C1); // Posts a C‑style procedure and blocks the caller until it executes on the target thread.
    procedure Sync_Wait_PostC2(Data1: Pointer; OnSync: TThreadPost_C2); // Posts a C‑style procedure with one pointer argument and waits for completion.
    procedure Sync_Wait_PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3); // Posts a C‑style procedure with pointer, object, and Variant; blocks until done.
    procedure Sync_Wait_PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4); // Posts a C‑style procedure with pointer and object; blocks until done.
    procedure Sync_Wait_PostM1(OnSync: TThreadPost_M1); // Posts an M‑style method and blocks the caller until it executes.
    procedure Sync_Wait_PostM2(Data1: Pointer; OnSync: TThreadPost_M2); // Posts an M‑style method with one pointer argument and waits for completion.
    procedure Sync_Wait_PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3); // Posts an M‑style method with pointer, object, and Variant; blocks until done.
    procedure Sync_Wait_PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4); // Posts an M‑style method with pointer and object; blocks until done.
    procedure Sync_Wait_PostP1(OnSync: TThreadPost_P1); // Posts a P‑style procedure (nested/anonymous) and blocks the caller until it executes.
    procedure Sync_Wait_PostP2(Data1: Pointer; OnSync: TThreadPost_P2); // Posts a P‑style procedure with one pointer argument and waits for completion.
    procedure Sync_Wait_PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3); // Posts a P‑style procedure with pointer, object, and Variant; blocks until done.
    procedure Sync_Wait_PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4); // Posts a P‑style procedure with pointer and object; blocks until done.
  end;

  TThread_Post = TThreadPost;
{$EndRegion 'ThreadPost'}
{$Region 'Compute_Thread'}
{
  TCompute – a worker thread that executes tasks (procedures) from a shared
  queue. It is the workhorse of the framework's thread pool.

  Key concepts:
    - Tasks can be posted via the static Run* methods (RunC, RunM, RunP).
    - The task is wrapped in a TComputeDispatch record and placed in a
      global dispatch order (Core_Dispatch_Order__).
    - A single dispatcher thread (TCore_Dispatch_Order_Thread) picks tasks
      and either assigns them to an idle TCompute thread or creates a new one.
    - Each TCompute thread runs in a loop: execute the task, then wait for
      a new one; if idle for too long, it terminates (self‑scaling pool).
    - Soft synchronization is integrated via TSoft_Synchronize_Tool,
      allowing tasks to safely synchronize with the main thread.
    - Each thread has its own MT19937 random generator (FRndInstance) to
      avoid contention.

  The thread pool is initialized by InitCoreThreadPool() and is used
  for both CPU‑bound and I/O‑bound parallelism (e.g., ParallelFor).

  Dispatch and scheduling:
    - The dispatcher thread (TCore_Dispatch_Order_Thread) is created
      once and runs continuously.
    - When a task is posted, it is added to Core_Dispatch_Order__ (a queue).
    - The dispatcher picks the task and either assigns it to an idle
      TCompute thread or creates a new one (up to a limit).
    - Idle threads wait for new tasks; if they remain idle for longer
      than Core_Thread_Life_Time_Tick__, they exit, reducing the pool size.
    - The pool is self‑scaling: it grows under load and shrinks during idle.

  Thread safety:
    - All internal state is protected by Core_Thread_Dispatch_Critical__.
    - The global Core_Thread_Task_Runing__ counter tracks active tasks.
    - Core_Thread_Wait_Sum__ counts threads waiting for tasks.
}
  TCompute = class;

  TRun_Thread_C = procedure(ThSender: TCompute);
  TRun_Thread_M = procedure(ThSender: TCompute) of object;
  TRun_Thread_C_NP = TOnSynchronize_C_NP;
  TRun_Thread_M_NP = TOnSynchronize_M_NP;
  TRun_Thread_P_NP = TOnSynchronize_P_NP;
  {$IFDEF FPC}
  TRun_Thread_P = procedure(ThSender: TCompute) is nested;
  {$ELSE FPC}
  TRun_Thread_P = reference to procedure(ThSender: TCompute);
  {$ENDIF FPC}
  TCoreCompute_Thread_Pool = TBigList<TCompute>;

  TCompute = class(TCore_Thread)
  private
    FSync_Tool: TSoft_Synchronize_Tool;
    Thread_Pool_Queue_Data_Ptr: TCoreCompute_Thread_Pool.PQueueStruct;
    OnRun_C: TRun_Thread_C;
    OnRun_M: TRun_Thread_M;
    OnRun_P: TRun_Thread_P;
    OnRun_C_NP: TRun_Thread_C_NP;
    OnRun_M_NP: TRun_Thread_M_NP;
    OnRun_P_NP: TRun_Thread_P_NP;
    OnDone_C: TRun_Thread_C;
    OnDone_M: TRun_Thread_M;
    OnDone_P: TRun_Thread_P;
    FRndInstance: Pointer;
    FStart_Time_Tick: TTimeTick;
    FThread_Info: string;
    IsRuning, IsExit: PBoolean;
  protected
    procedure Execute; override;
    procedure Done_Sync;
  public
    UserData: Pointer;
    UserObject: TCore_Object;
    property Runing_Ptr: PBoolean read IsRuning;
    property Exit_Ptr: PBoolean read IsExit;
    property Start_Time_Tick: TTimeTick read FStart_Time_Tick;
    property Thread_Info: string read FThread_Info write FThread_Info;

    constructor Create;
    destructor Destroy; override;
    function Sync_Tool: TSoft_Synchronize_Tool;
    class procedure Set_Thread_Info(Thread_Info_: string); overload;
    class procedure Set_Thread_Info(const Fmt: string; const Args: array of const); overload;
    class function Get_Core_Thread_Pool: TCoreCompute_Thread_Pool;
    class function Get_Core_Thread_Dispatch_Critical: TCritical;
    class function Wait_Thread(): NativeInt;
    class function ActivtedTask(): NativeInt;
    class function WaitTask(): NativeInt;
    class function TotalTask(): NativeInt;
    class function State(): string;
    class function GetParallelGranularity(): Integer;
    class function GetMaxActivtedParallel(): Integer;

    // build-in synchronization
    class procedure Sync(OnRun_: TRun_Thread_P_NP); overload;
    class procedure Sync(Thread_: TThread; OnRun_: TRun_Thread_P_NP); overload;
    class procedure SyncC(OnRun_: TRun_Thread_C_NP); overload;
    class procedure SyncC(Thread_: TThread; OnRun_: TRun_Thread_C_NP); overload;
    class procedure SyncM(OnRun_: TRun_Thread_M_NP); overload;
    class procedure SyncM(Thread_: TThread; OnRun_: TRun_Thread_M_NP); overload;
    class procedure SyncP(OnRun_: TRun_Thread_P_NP); overload;
    class procedure SyncP(Thread_: TThread; OnRun_: TRun_Thread_P_NP); overload;

    // build-in synchronization to
    class procedure Sync_To(Dest_Thread_:TCompute; OnRun_: TRun_Thread_P_NP);
    class procedure SyncC_To(Dest_Thread_:TCompute; OnRun_: TRun_Thread_C_NP);
    class procedure SyncM_To(Dest_Thread_:TCompute; OnRun_: TRun_Thread_M_NP);
    class procedure SyncP_To(Dest_Thread_:TCompute; OnRun_: TRun_Thread_P_NP);

    // build-in asynchronous thread
    class procedure RunC(const Data: Pointer; const Obj: TCore_Object; const OnRun, OnDone: TRun_Thread_C); overload;
    class procedure RunC(const Data: Pointer; const Obj: TCore_Object; const OnRun, OnDone: TRun_Thread_C; IsRuning_, IsExit_: PBoolean); overload;
    class procedure RunC(const Data: Pointer; const Obj: TCore_Object; const OnRun: TRun_Thread_C); overload;
    class procedure RunC(const Data: Pointer; const Obj: TCore_Object; const OnRun: TRun_Thread_C; IsRuning_, IsExit_: PBoolean); overload;
    class procedure RunC_NP(const OnRun: TRun_Thread_C_NP); overload;
    class procedure RunC_NP(const OnRun: TRun_Thread_C_NP; IsRuning_, IsExit_: PBoolean); overload;

    class procedure RunM(const Data: Pointer; const Obj: TCore_Object; const OnRun, OnDone: TRun_Thread_M); overload;
    class procedure RunM(const Data: Pointer; const Obj: TCore_Object; const OnRun, OnDone: TRun_Thread_M; IsRuning_, IsExit_: PBoolean); overload;
    class procedure RunM(const Data: Pointer; const Obj: TCore_Object; const OnRun: TRun_Thread_M); overload;
    class procedure RunM(const Data: Pointer; const Obj: TCore_Object; const OnRun: TRun_Thread_M; IsRuning_, IsExit_: PBoolean); overload;
    class procedure RunM_NP(const OnRun: TRun_Thread_M_NP); overload;
    class procedure RunM_NP(const OnRun: TRun_Thread_M_NP; IsRuning_, IsExit_: PBoolean); overload;

    class procedure RunP(const Data: Pointer; const Obj: TCore_Object; const OnRun, OnDone: TRun_Thread_P); overload;
    class procedure RunP(const Data: Pointer; const Obj: TCore_Object; const OnRun, OnDone: TRun_Thread_P; IsRuning_, IsExit_: PBoolean); overload;
    class procedure RunP(const Data: Pointer; const Obj: TCore_Object; const OnRun: TRun_Thread_P); overload;
    class procedure RunP(const Data: Pointer; const Obj: TCore_Object; const OnRun: TRun_Thread_P; IsRuning_, IsExit_: PBoolean); overload;
    class procedure RunP_NP(const OnRun: TRun_Thread_P_NP); overload;
    class procedure RunP_NP(const OnRun: TRun_Thread_P_NP; IsRuning_, IsExit_: PBoolean); overload;

    // free object in thread
    class procedure PostFreeObjectInThread(const Obj: TObject);
    class procedure PostFreeObjectInThreadAndNil(var Obj);

    // main thread progress
    class procedure ProgressPost();

    // post main thread synchronization
    class procedure PostC1(OnSync: TThreadPost_C1); overload;
    class procedure PostC1(OnSync: TThreadPost_C1; IsRuning_, IsExit_: PBoolean); overload;
    class procedure PostC2(Data1: Pointer; OnSync: TThreadPost_C2); overload;
    class procedure PostC2(Data1: Pointer; OnSync: TThreadPost_C2; IsRuning_, IsExit_: PBoolean); overload;
    class procedure PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3); overload;
    class procedure PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3; IsRuning_, IsExit_: PBoolean); overload;
    class procedure PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4); overload;
    class procedure PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4; IsRuning_, IsExit_: PBoolean); overload;

    class procedure PostM1(OnSync: TThreadPost_M1); overload;
    class procedure PostM1(OnSync: TThreadPost_M1; IsRuning_, IsExit_: PBoolean); overload;
    class procedure PostM2(Data1: Pointer; OnSync: TThreadPost_M2); overload;
    class procedure PostM2(Data1: Pointer; OnSync: TThreadPost_M2; IsRuning_, IsExit_: PBoolean); overload;
    class procedure PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3); overload;
    class procedure PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3; IsRuning_, IsExit_: PBoolean); overload;
    class procedure PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4); overload;
    class procedure PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4; IsRuning_, IsExit_: PBoolean); overload;

    class procedure PostP1(OnSync: TThreadPost_P1); overload;
    class procedure PostP1(OnSync: TThreadPost_P1; IsRuning_, IsExit_: PBoolean); overload;
    class procedure PostP2(Data1: Pointer; OnSync: TThreadPost_P2); overload;
    class procedure PostP2(Data1: Pointer; OnSync: TThreadPost_P2; IsRuning_, IsExit_: PBoolean); overload;
    class procedure PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3); overload;
    class procedure PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3; IsRuning_, IsExit_: PBoolean); overload;
    class procedure PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4); overload;
    class procedure PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4; IsRuning_, IsExit_: PBoolean); overload;

    // post main thread and wait synchronization
    class procedure Sync_Wait_PostC1(OnSync: TThreadPost_C1);
    class procedure Sync_Wait_PostC2(Data1: Pointer; OnSync: TThreadPost_C2);
    class procedure Sync_Wait_PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3);
    class procedure Sync_Wait_PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4);
    class procedure Sync_Wait_PostM1(OnSync: TThreadPost_M1);
    class procedure Sync_Wait_PostM2(Data1: Pointer; OnSync: TThreadPost_M2);
    class procedure Sync_Wait_PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3);
    class procedure Sync_Wait_PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4);
    class procedure Sync_Wait_PostP1(OnSync: TThreadPost_P1);
    class procedure Sync_Wait_PostP2(Data1: Pointer; OnSync: TThreadPost_P2);
    class procedure Sync_Wait_PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3);
    class procedure Sync_Wait_PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4);
  end;

  // TCompute alias
  TComputeThread = TCompute;
  TComp = TCompute;
{$EndRegion 'Compute_Thread'}
{$Region 'MT19937Random'}
{
  Mersenne Twister (MT19937) random number generator.

  The generator is implemented as a record (TMT19937Core) that holds the
  624‑word state vector and the current index. Each TCompute thread has its
  own instance (stored in FRndInstance) to avoid lock contention.

  The global pool (MT19937_POOL__) manages these per‑thread instances.
  When a thread terminates, its MT19937Core is recycled or freed.

  The algorithm is standard MT19937 with tempering. The implementation
  follows the paper by Matsumoto and Nishimura (1998).

  Additional features:
    - Save/load of the state to/from a stream for deterministic replication.
    - Thread local seeding: each new thread gets a unique seed from a
      global counter (Randomize_Seed__) to ensure independent sequences.
    - Optionally replaces Delphi's built‑in Random() with this generator
      (when InstallMT19937CoreToDelphi is defined).

  The class TMT19937Random provides a per‑object RNG with its own state,
  while the static class TMT19937 provides thread‑local access (using the
  per‑thread instance of the current thread).
}
  TMT19937Random = class(TCore_Object_Intermediate)
  private
    FInternalCritical: TCritical;
    FRndInstance: Pointer;
    function GetSeed: Integer;
    procedure SetSeed(const Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Rndmize();
    function Rand32(L: Integer): Integer; overload;
    procedure Rand32(L: Integer; dest: PInteger; num: NativeInt); overload;
    function Rand64(L: Int64): Int64; overload;
    procedure Rand64(L: Int64; dest: PInt64; num: NativeInt); overload;
    function RandE: Extended; overload;
    procedure RandE(dest: PExtended; num: NativeInt); overload;
    function RandF: Single; overload;
    procedure RandF(dest: PSingle; num: NativeInt); overload;
    function RandD: Double; overload;
    procedure RandD(dest: PDouble; num: NativeInt); overload;
    function RandBool: Boolean;
    property seed: Integer read GetSeed write SetSeed;
  end;

  TRandom = TMT19937Random;

  TMT19937 = class(TCore_Object_Intermediate)
  public
    // base map
    class function CoreToDelphi: Boolean; static;
    class function InstanceNum(): Integer; static;
    class procedure SetSeed(seed: Integer); static;
    class function GetSeed(): Integer; static;
    class procedure Randomize(); static;
    class function Rand32: Integer; overload; static;
    class function Rand32(L: Integer): Integer; overload; static;
    class procedure Rand32(L: Integer; dest: PInteger; num: NativeInt); overload; static;
    class function Rand64: Int64; overload; static;
    class function Rand64(L: Int64): Int64; overload; static;
    class procedure Rand64(L: Int64; dest: PInt64; num: NativeInt); overload; static;
    class function RandE: Extended; overload; static;
    class procedure RandE(dest: PExtended; num: NativeInt); overload; static;
    class function RandF: Single; overload; static;
    class procedure RandF(dest: PSingle; num: NativeInt); overload; static;
    class function RandD: Double; overload; static;
    class procedure RandD(dest: PDouble; num: NativeInt); overload; static;
    class function Random: Extended;
    // random range
    class function RandomRange(const rnd: TMT19937Random; const min_, max_: Integer): Integer; overload; static;
    class function RandomRange64(const rnd: TMT19937Random; const min_, max_: Int64): Int64; overload; static;
    class function RandomRangeS(const rnd: TMT19937Random; const min_, max_: Single): Single; overload; static;
    class function RandomRangeD(const rnd: TMT19937Random; const min_, max_: Double): Double; overload; static;
    class function RandomRangeF(const rnd: TMT19937Random; const min_, max_: Double): Double; overload; static;
    class function RandomRange(const min_, max_: Integer): Integer; overload; static;
    class function RandomRange64(const min_, max_: Int64): Int64; overload; static;
    class function RandomRangeS(const min_, max_: Single): Single; overload; static;
    class function RandomRangeD(const min_, max_: Double): Double; overload; static;
    class function RandomRangeF(const min_, max_: Double): Double; overload; static;
    class function RR(const rnd: TMT19937Random; const min_, max_: Integer): Integer; overload; static;
    class function RR64(const rnd: TMT19937Random; const min_, max_: Int64): Int64; overload; static;
    class function RRS(const rnd: TMT19937Random; const min_, max_: Single): Single; overload; static;
    class function RRD(const rnd: TMT19937Random; const min_, max_: Double): Double; overload; static;
    class function RRF(const rnd: TMT19937Random; const min_, max_: Double): Double; overload; static;
    class function RR(const min_, max_: Integer): Integer; overload; static;
    class function RR64(const min_, max_: Int64): Int64; overload; static;
    class function RRS(const min_, max_: Single): Single; overload; static;
    class function RRD(const min_, max_: Double): Double; overload; static;
    class function RRF(const min_, max_: Double): Double; overload; static;
    // MT19937 core save
    class procedure SaveToStream(stream: TCore_Stream); static;
    class procedure LoadFromStream(stream: TCore_Stream); static;
  end;
{$EndRegion 'MT19937Random'}
{$Region 'Timer'}
{
  ****************************************************************************
  * Core Timer Subsystem
  *
  ************************************** Description **************************
  * This section provides a simple, lightweight timer framework that allows
  * periodic execution of callback routines. Timers are bound to an arbitrary
  * object (Bind_) which acts as a unique key for registration and removal.
  * The timer is processed during the main thread's synchronization loop
  * (Check_Soft_Thread_Synchronize / Check_System_Thread_Synchronize) and
  * runs on the main thread.
  *
  ************************************** Callback Styles **********************
  * Three callback styles are supported for maximum flexibility:
  *   - C: plain procedure (no self, no object)
  *   - M: method of an object (of object)
  *   - P: nested procedure or anonymous method (reference to procedure)
  *
  ************************************** Usage Example ************************
  *   var
  *     MyObj: TMyClass;
  *   begin
  *     MyObj := TMyClass.Create;
  *     // Subscribe a method to fire every 1000 ms
  *     Subscribe_Timer_M(MyObj, 1000, MyObj.DoTimer);
  *     // ...
  *     // Later, remove the timer
  *     Remove_Timer(MyObj);
  *   end;
  *
  ************************************** Notes ********************************
  * - The timer is not a high-precision real-time timer; it relies on the
  *   main thread's message pump / sync loop, so accuracy depends on loop
  *   frequency and system load.
  * - If the same Bind_ object is subscribed again without removal, the old
  *   timer is overwritten (the hash map uses Add with Overwrite=True).
  * - The timer persists until explicitly removed or the Bind_ object is freed
  *   (if the hash map handles cleanup; ensure to call Remove_Timer in the
  *   destructor of the owning object to avoid dangling references).
  * - All timer callbacks are executed on the main thread (the thread that
  *   processes the synchronisation queue). Therefore, they are safe for
  *   updating UI components but must not block for long periods.
  ****************************************************************************
}

type
  // Callback without parameters – plain procedure (C-style)
  TOn_Timer_C = procedure();

  // Callback without parameters – method of an object (M-style)
  TOn_Timer_M = procedure() of object;

  // Callback without parameters – nested procedure or anonymous reference (P-style)
  // Compiler‑specific: FPC uses "is nested" for true nested procedures; Delphi uses "reference to" for anonymous methods.
{$IFDEF FPC}
  TOn_Timer_P = procedure() is nested;
{$ELSE FPC}
  TOn_Timer_P = reference to procedure();
{$ENDIF FPC}

// ----------------------------------------------------------------------------
// Timer subscription procedures – register a timer for the given object.
// The timer will fire at approximately Interval_ milliseconds.
// ----------------------------------------------------------------------------

// Subscribe a C‑style callback (plain procedure) to fire every Interval_ ms.
// The Bind_ object serves as the unique identifier for this timer.
procedure Subscribe_Timer_C(Bind_: TCore_Object; Interval_: TTimeTick; OnTimer: TOn_Timer_C);

// Subscribe an M‑style callback (object method) to fire every Interval_ ms.
procedure Subscribe_Timer_M(Bind_: TCore_Object; Interval_: TTimeTick; OnTimer: TOn_Timer_M);

// Subscribe a P‑style callback (nested procedure or anonymous method) to fire every Interval_ ms.
procedure Subscribe_Timer_P(Bind_: TCore_Object; Interval_: TTimeTick; OnTimer: TOn_Timer_P);

// ----------------------------------------------------------------------------
// Timer management procedures
// ----------------------------------------------------------------------------

// Remove the timer associated with the given Bind_ object.
// After removal, no further callbacks will be invoked for that timer.
procedure Remove_Timer(Bind_: TCore_Object);

// Reset the timer associated with the given Bind_ object.
// This resets the internal "last fired" timestamp to the current time,
// effectively delaying the next firing by another Interval_ ms from now.
// Useful to prevent a timer from firing immediately after a long operation.
procedure Reset_Timer(Bind_: TCore_Object);

{$EndRegion 'Timer'}
{$Region 'Parallel-API'}
{
  Functions and procedures for parallel programming support.

  These are thin wrappers around the thread pool and the parallel for
  implementations (block/fold) that are provided in the included .inc files.

  The parallel for implementations (in Z.DelphiParallelFor.inc and
  Z.FPCParallelFor.inc) provide two strategies:
    - Block: divides the iteration range into contiguous chunks, each
      assigned to a different thread. Good for uniform work per iteration.
    - Fold: distributes iterations in a round‑robin fashion (each thread
      handles iterations with a step of thread count). Good for load‑balancing
      when iteration costs vary.

  The user can choose between them via the FoldParallel compiler define.

  The Parallel_Overflow__ mechanism limits the number of concurrently
  executing parallel loops to avoid over‑subscription.
}

function Max_Thread_Supported: Integer;
function Get_System_Critical_Num: NativeInt;
function Get_System_Critical_Recycle_Pool_Num: NativeInt;
function Get_MT19937_POOL_Num: NativeInt;
function Get_Atom_Lock_Pool_Num: NativeInt;
function Get_Parallel_Granularity: Integer;
procedure Set_Parallel_Granularity(Thread_Num: Integer);
procedure Set_IDLE_Compute_Wait_Time_Tick(Tick_: TTimeTick);

{$IFDEF FPC}
type
  // freepascal
  TFPCParallel_P32 = procedure(pass: Integer) is nested;
  TFPCParallel_P64 = procedure(pass: Int64) is nested;
// parallel core
procedure FPCParallelFor_Block(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure FPCParallelFor_Block(parallel: Boolean; b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure FPCParallelFor_Block(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TFPCParallel_P64); overload;
procedure FPCParallelFor_Block(parallel: Boolean; b, e: Int64; OnFor: TFPCParallel_P64); overload;
procedure FPCParallelFor_Fold(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure FPCParallelFor_Fold(parallel: Boolean; b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure FPCParallelFor_Fold(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TFPCParallel_P64); overload;
procedure FPCParallelFor_Fold(parallel: Boolean; b, e: Int64; OnFor: TFPCParallel_P64); overload;
// parallel package
procedure FPCParallelFor(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure FPCParallelFor(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TFPCParallel_P64); overload;
procedure FPCParallelFor(parallel: Boolean; b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure FPCParallelFor(parallel: Boolean; b, e: Int64; OnFor: TFPCParallel_P64); overload;
procedure FPCParallelFor(b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure FPCParallelFor(b, e: Int64; OnFor: TFPCParallel_P64); overload;
procedure FPCParallelFor(OnFor: TFPCParallel_P32; b, e: Integer); overload;
procedure FPCParallelFor(OnFor: TFPCParallel_P64; b, e: Int64); overload;
procedure FPCParallelFor(parallel: Boolean; OnFor: TFPCParallel_P32; b, e: Integer); overload;
procedure FPCParallelFor(parallel: Boolean; OnFor: TFPCParallel_P64; b, e: Int64); overload;
procedure ParallelFor(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure ParallelFor(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TFPCParallel_P64); overload;
procedure ParallelFor(parallel: Boolean; b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure ParallelFor(parallel: Boolean; b, e: Int64; OnFor: TFPCParallel_P64); overload;
procedure ParallelFor(b, e: Integer; OnFor: TFPCParallel_P32); overload;
procedure ParallelFor(b, e: Int64; OnFor: TFPCParallel_P64); overload;
procedure ParallelFor(OnFor: TFPCParallel_P32; b, e: Integer); overload;
procedure ParallelFor(OnFor: TFPCParallel_P64; b, e: Int64); overload;
procedure ParallelFor(ThNum: Integer; parallel: Boolean; OnFor: TFPCParallel_P32; b, e: Integer); overload;
procedure ParallelFor(ThNum: Integer; parallel: Boolean; OnFor: TFPCParallel_P64; b, e: Int64); overload;
procedure ParallelFor(parallel: Boolean; OnFor: TFPCParallel_P32; b, e: Integer); overload;
procedure ParallelFor(parallel: Boolean; OnFor: TFPCParallel_P64; b, e: Int64); overload;
{$ELSE FPC}
type
  // delphi
  TDelphiParallel_P32 = reference to procedure(pass: Integer);
  TDelphiParallel_P64 = reference to procedure(pass: Int64);
// parallel core
procedure DelphiParallelFor_Block(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor_Block(parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor_Block(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure DelphiParallelFor_Block(parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure DelphiParallelFor_Fold(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor_Fold(parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor_Fold(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure DelphiParallelFor_Fold(parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
// parallel package
procedure DelphiParallelFor(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure DelphiParallelFor(parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor(parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure DelphiParallelFor(b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor(b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure DelphiParallelFor(OnFor: TDelphiParallel_P32; b, e: Integer); overload;
procedure DelphiParallelFor(OnFor: TDelphiParallel_P64; b, e: Int64); overload;
procedure DelphiParallelFor(parallel: Boolean; OnFor: TDelphiParallel_P32; b, e: Integer); overload;
procedure DelphiParallelFor(parallel: Boolean; OnFor: TDelphiParallel_P64; b, e: Int64); overload;
procedure ParallelFor(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure ParallelFor(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure ParallelFor(parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure ParallelFor(parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure ParallelFor(b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure ParallelFor(b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure ParallelFor(OnFor: TDelphiParallel_P32; b, e: Integer); overload;
procedure ParallelFor(OnFor: TDelphiParallel_P64; b, e: Int64); overload;
procedure ParallelFor(ThNum: Integer; parallel: Boolean; OnFor: TDelphiParallel_P32; b, e: Integer); overload;
procedure ParallelFor(ThNum: Integer; parallel: Boolean; OnFor: TDelphiParallel_P64; b, e: Int64); overload;
procedure ParallelFor(parallel: Boolean; OnFor: TDelphiParallel_P32; b, e: Integer); overload;
procedure ParallelFor(parallel: Boolean; OnFor: TDelphiParallel_P64; b, e: Int64); overload;
{$ENDIF FPC}

{$EndRegion 'Parallel-API'}
{$Region 'api'}

(*
  ******************** Dual-Main-Thread Technology ********************
  This unit provides a user-space thread synchronisation mechanism
  (TSoft_Synchronize_Tool) that allows any thread to act as a simulated
  main thread with its own synchronisation queue, independent of the RTL's
  main thread (MainThreadID).

  To start a simulated main thread, call Begin_Simulator_Main_Thread(Proc)
  where Proc is the entry point of the new thread. That thread will run
  with its own sync queue, and all calls to TCompute.Sync* or
  TSoft_Synchronize_Tool.Synchronize will be dispatched to that thread's
  queue when it calls Check_Synchronize periodically.

  The original boot thread (or any other thread) can pump the simulator's
  queue by calling Boot_Thread_Sync_Tool.Check_Synchronize(Timeout) in a
  loop until Simulator_Main_Thread_Activted returns False.

  Usage example:
  --------------------------------------------------------------------
    procedure MySimulatedMain;
    begin
      // This runs in the simulated main thread.
      while Running do
        Check_Soft_Thread_Synchronize(10); // Z-Core
    end;

    begin
      Begin_Simulator_Main_Thread(MySimulatedMain);
      while Simulator_Main_Thread_Activted do
        begin
          Boot_Thread_Sync_Tool.Check_Synchronize(0); // Z-Core: Check_Synchronize
          CheckSynchronize(10); // System: CheckSynchronize
        end;
    end.
  --------------------------------------------------------------------

  This technology is stable and production-ready. It is extensively used
  by the C4 networking framework and supports Windows, Linux, macOS, iOS,
  Android, and BSD without platform-specific code.

  Key advantages:
    - No reliance on RTL CheckSynchronize or UI message pump.
    - Low-latency, spin-lock based synchronisation.
    - Allows multiple isolated main loops in the same process (e.g., for DLLs).
    - Fully cross-platform and thread-safe.

  Note: The compiler define Core_Thread_Soft_Synchronize must be enabled.
        This model does not support UI frameworks that require
        Application.ProcessMessages; use explicit sync pumping instead.
*)
procedure Begin_Simulator_Main_Thread(Simulator_Main_Proc_: TOnSynchronize_C_NP);
function Simulator_Main_Thread_Activted: Boolean;

{ **************************************************************
  Close_Core_Dispatch_Thread
  --------------------------------------------------------------
  Gracefully shuts down the core dispatch thread and ensures
  all worker tasks are finished, with timeout protection to
  avoid deadlocks – essential for library unloading.
  --------------------------------------------------------------
  Behaviour:
    1. If the dispatcher is already inactive or exiting, does
       nothing.
    2. Signals the dispatcher to exit by clearing the active
       flag.
    3. Waits up to 1 second for the dispatcher thread to finish
       (checks `Core_Dispatch_Order_IsExit__`).
    4. Waits up to another second for all active worker tasks
       to complete (`TCompute.ActivtedTask() = 0`).
    5. During the worker wait, it calls
       `Check_Soft_Thread_Synchronize` to process pending
       `Synchronize` calls, preventing deadlocks between worker
       threads and the main thread.
    6. If timeouts expire, it stops waiting and allows the
       caller to proceed, avoiding a process hang.
  --------------------------------------------------------------
  Important:
    This function is designed for use in finalization sections of
    executables and shared libraries. It trades a potential small
    resource leak for guaranteed process termination.
  **************************************************************}
procedure Close_Core_Dispatch_Thread();
{ **************************************************************
  Open_Core_Dispatch_Thread
  --------------------------------------------------------------
  Starts the core dispatch thread that manages the thread pool.
  It guarantees that only one dispatcher runs at any time.
  --------------------------------------------------------------
  Design:
    - Ensures a clean state by first closing any existing
      dispatcher.
    - Sets the active flag and creates the dispatcher thread.
    - The dispatcher continuously picks tasks from the global
      order queue and assigns them to idle workers or creates
      new workers.
  --------------------------------------------------------------
  Note: This function is safe to call multiple times; it will
  restart the dispatcher if it was previously stopped.
  **************************************************************}
procedure Open_Core_Dispatch_Thread();
function Core_Dispatch_Order_Activted: Boolean; // check Open_Core_Dispatch_Thread

// NoP = No Operation. It's the empty function, whose purpose is only for the
// debugging, or for the piece of code where intentionaly nothing is planned to be.
procedure Nop;
// debug state
function IsDebuging: Boolean;

// check soft thread phototype
var On_Check_Soft_Thread_Synchronize: function(Timeout: TTimeTick; Run_Hook_Event_:Boolean): Boolean;
function Do_Check_Soft_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_:Boolean): Boolean;

// check system thread phototype
var On_Check_System_Thread_Synchronize: function(Timeout: TTimeTick; Run_Hook_Event_:Boolean): Boolean;
function Do_Check_System_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_:Boolean): Boolean;

(*
  When dual-main-thread mode is off (default), these sync helpers work as expected:
    - Check_Soft_Thread_Synchronize  -> uses Z.Core's space soft-sync queue.
    - Check_System_Thread_Synchronize -> uses the RTL's built-in TThread.Synchronize.
    - CheckThreadSynchronize / CheckThread are just aliases that pick one of the
      above based on the Main_Thread_Soft_Synchronize flag.
  BUT once you call Begin_Simulator_Main_Thread (activating dual‑main mode),
  the whole sync system flips: all these functions now behave exactly like
  Check_Soft_Thread_Synchronize. They all go through Z.Core's soft queue,
  and the RTL system sync (CheckSynchronize) is completely bypassed.
  Why? Because in dual‑main mode, the simulated main thread owns the sync
  queue, and we must route every sync request to that thread – not to the
  RTL's main thread. So even if you call Check_System_Thread_Synchronize,
  it won't touch TThread.Synchronize; it will just use Z.Core's soft sync.
  Bottom line: dual‑main mode takes over synchronisation entirely. If you
  still need RTL sync (e.g., with UI components), don't start a simulated
  main thread, or handle TThread.Synchronize manually alongside it.
*)
// --- Soft-sync only (Z.Core's own user‑space queue) ---
function Check_Soft_Thread_Synchronize: Boolean; overload; // no timeout, processes one batch if any
function Check_Soft_Thread_Synchronize(Timeout: TTimeTick): Boolean; overload; // with millisecond timeout
function Check_Soft_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_: Boolean): Boolean; overload; // timeout + optional global hook call
// --- System sync (RTL + soft) – but in dual‑main mode this is redirected to soft‑only ---
procedure Check_System_Thread_Synchronize; overload; // no timeout, immediate return
function Check_System_Thread_Synchronize(Timeout: TTimeTick): Boolean; overload; // with timeout, returns true if any sync processed
function Check_System_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_: Boolean): Boolean; overload; // timeout + hook
// --- Unified aliases – automatically select soft or system based on Main_Thread_Soft_Synchronize flag ---
procedure CheckThreadSynchronize; overload; // no timeout
function CheckThreadSynchronize(Timeout: TTimeTick): Boolean; overload; // with timeout
procedure CheckThreadSync; overload; // alias for CheckThreadSynchronize (no timeout)
function CheckThreadSync(Timeout: TTimeTick): Boolean; overload; // alias with timeout
procedure CheckThread; overload; // shortest alias (no timeout)
function CheckThread(Timeout: TTimeTick): Boolean; overload; // shortest alias with timeout

// compiler define
function Get_Compiler_Version: string; // returns compiler name, version and bitness (e.g., "FPC 3.2.0 64 bit")

// core thread pool
procedure FreeCoreThreadPool; // shuts down the core thread pool and releases all associated resources

// dipose object
function DisposeObject(const Obj: TObject): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // safely frees an object (catches exceptions), returns True if freed
procedure DisposeObject(const objs: array of TObject); overload; // frees all objects in the array
function FreeObj(const Obj: TObject): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}                     // alias to DisposeObject
function FreeObject(const Obj: TObject): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // alias to DisposeObject
procedure FreeObject(const objs: array of TObject); overload; // frees all objects in the array (alias)
function DisposeObjectAndNil(var Obj): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}                     // frees object and sets the variable to nil
function FreeObjAndNil(var Obj): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}                           // alias to DisposeObjectAndNil

// object lock
procedure LockObject(Obj: TObject); // acquires a lock associated with the object (simulates TMonitor.Enter)
procedure UnLockObject(Obj: TObject); // releases the lock previously acquired by LockObject

{$Region 'CRC32_Table'}
const
  C_CRC32Table: array [0 .. 255] of Cardinal = (
    $00000000, $77073096, $EE0E612C, $990951BA, $076DC419, $706AF48F, $E963A535,
    $9E6495A3, $0EDB8832, $79DCB8A4, $E0D5E91E, $97D2D988, $09B64C2B, $7EB17CBD,
    $E7B82D07, $90BF1D91, $1DB71064, $6AB020F2, $F3B97148, $84BE41DE, $1ADAD47D,
    $6DDDE4EB, $F4D4B551, $83D385C7, $136C9856, $646BA8C0, $FD62F97A, $8A65C9EC,
    $14015C4F, $63066CD9, $FA0F3D63, $8D080DF5, $3B6E20C8, $4C69105E, $D56041E4,
    $A2677172, $3C03E4D1, $4B04D447, $D20D85FD, $A50AB56B, $35B5A8FA, $42B2986C,
    $DBBBC9D6, $ACBCF940, $32D86CE3, $45DF5C75, $DCD60DCF, $ABD13D59, $26D930AC,
    $51DE003A, $C8D75180, $BFD06116, $21B4F4B5, $56B3C423, $CFBA9599, $B8BDA50F,
    $2802B89E, $5F058808, $C60CD9B2, $B10BE924, $2F6F7C87, $58684C11, $C1611DAB,
    $B6662D3D, $76DC4190, $01DB7106, $98D220BC, $EFD5102A, $71B18589, $06B6B51F,
    $9FBFE4A5, $E8B8D433, $7807C9A2, $0F00F934, $9609A88E, $E10E9818, $7F6A0DBB,
    $086D3D2D, $91646C97, $E6635C01, $6B6B51F4, $1C6C6162, $856530D8, $F262004E,
    $6C0695ED, $1B01A57B, $8208F4C1, $F50FC457, $65B0D9C6, $12B7E950, $8BBEB8EA,
    $FCB9887C, $62DD1DDF, $15DA2D49, $8CD37CF3, $FBD44C65, $4DB26158, $3AB551CE,
    $A3BC0074, $D4BB30E2, $4ADFA541, $3DD895D7, $A4D1C46D, $D3D6F4FB, $4369E96A,
    $346ED9FC, $AD678846, $DA60B8D0, $44042D73, $33031DE5, $AA0A4C5F, $DD0D7CC9,
    $5005713C, $270241AA, $BE0B1010, $C90C2086, $5768B525, $206F85B3, $B966D409,
    $CE61E49F, $5EDEF90E, $29D9C998, $B0D09822, $C7D7A8B4, $59B33D17, $2EB40D81,
    $B7BD5C3B, $C0BA6CAD, $EDB88320, $9ABFB3B6, $03B6E20C, $74B1D29A, $EAD54739,
    $9DD277AF, $04DB2615, $73DC1683, $E3630B12, $94643B84, $0D6D6A3E, $7A6A5AA8,
    $E40ECF0B, $9309FF9D, $0A00AE27, $7D079EB1, $F00F9344, $8708A3D2, $1E01F268,
    $6906C2FE, $F762575D, $806567CB, $196C3671, $6E6B06E7, $FED41B76, $89D32BE0,
    $10DA7A5A, $67DD4ACC, $F9B9DF6F, $8EBEEFF9, $17B7BE43, $60B08ED5, $D6D6A3E8,
    $A1D1937E, $38D8C2C4, $4FDFF252, $D1BB67F1, $A6BC5767, $3FB506DD, $48B2364B,
    $D80D2BDA, $AF0A1B4C, $36034AF6, $41047A60, $DF60EFC3, $A867DF55, $316E8EEF,
    $4669BE79, $CB61B38C, $BC66831A, $256FD2A0, $5268E236, $CC0C7795, $BB0B4703,
    $220216B9, $5505262F, $C5BA3BBE, $B2BD0B28, $2BB45A92, $5CB36A04, $C2D7FFA7,
    $B5D0CF31, $2CD99E8B, $5BDEAE1D, $9B64C2B0, $EC63F226, $756AA39C, $026D930A,
    $9C0906A9, $EB0E363F, $72076785, $05005713, $95BF4A82, $E2B87A14, $7BB12BAE,
    $0CB61B38, $92D28E9B, $E5D5BE0D, $7CDCEFB7, $0BDBDF21, $86D3D2D4, $F1D4E242,
    $68DDB3F8, $1FDA836E, $81BE16CD, $F6B9265B, $6FB077E1, $18B74777, $88085AE6,
    $FF0F6A70, $66063BCA, $11010B5C, $8F659EFF, $F862AE69, $616BFFD3, $166CCF45,
    $A00AE278, $D70DD2EE, $4E048354, $3903B3C2, $A7672661, $D06016F7, $4969474D,
    $3E6E77DB, $AED16A4A, $D9D65ADC, $40DF0B66, $37D83BF0, $A9BCAE53, $DEBB9EC5,
    $47B2CF7F, $30B5FFE9, $BDBDF21C, $CABAC28A, $53B39330, $24B4A3A6, $BAD03605,
    $CDD70693, $54DE5729, $23D967BF, $B3667A2E, $C4614AB8, $5D681B02, $2A6F2B94,
    $B40BBE37, $C30C8EA1, $5A05DF1B, $2D02EF8D
    );
{$EndRegion 'CRC32_Table'}

// --- CRC32 & Hash utilities ---
function Get_CRC32(const Data: PByte; const Size: NativeInt): THash; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}  // computes CRC32 checksum over a memory block
function Hash_Key_Mod(const hash: THash; const Num: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}  // maps a hash value to a bucket index (0..Num-1)

type
  TBool_Signal_Array = array of Boolean; // dynamic array of Boolean signals
  PBool_Signal_Array = array of PBoolean; // dynamic array of Boolean pointers
  TInteger_Signal_Array = array of integer; // dynamic array of Integer signals
  PInteger_Signal_Array = array of PInteger; // dynamic array of Integer pointers

  // --- Wait until all signals in an array match the given value (busy-wait) ---
procedure Wait_All_Signal(var arry: TBool_Signal_Array; const signal_: Boolean); overload; // Boolean array by value
procedure Wait_All_Signal(const arry: PBool_Signal_Array; const signal_: Boolean); overload; // array of Boolean pointers
procedure Wait_All_Signal(var arry: TInteger_Signal_Array; const signal_: integer); overload; // Integer array
procedure Wait_All_Signal(const arry: PInteger_Signal_Array; const signal_: integer); overload; // array of Integer pointers

// --- Alignment helpers: round up value_ to multiple of Delta_ ---
function DeltaNum(const value_, Delta_: NativeInt): NativeInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}   // aligns up (same as DeltaStep)
function DeltaStep(const value_, Delta_: NativeInt): NativeInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // alias of DeltaNum

// --- Atomic operations (cross‑platform: Delphi uses hardware, FPC uses critical section) ---
function AtomInc(var x: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // atomically increment x by 1, return new value
function AtomInc(var x: Int64; const v: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // atomically increment x by v, return new value
function AtomDec(var x: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // atomically decrement x by 1, return new value
function AtomDec(var x: Int64; const v: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // atomically decrement x by v, return new value

function AtomInc(var x: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // unsigned 64-bit increment
function AtomInc(var x: UInt64; const v: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function AtomDec(var x: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function AtomDec(var x: UInt64; const v: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

function AtomInc(var x: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // signed 32-bit
function AtomInc(var x: integer; const v: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function AtomDec(var x: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function AtomDec(var x: integer; const v: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

function AtomInc(var x: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // unsigned 32-bit
function AtomInc(var x: Cardinal; const v: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function AtomDec(var x: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function AtomDec(var x: Cardinal; const v: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

// --- Fast memory operations ---
procedure FillPtrByte(const dest: Pointer; Size: NativeUInt; const Value: Byte); {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // fill memory with 8-bit value (byte)
procedure FillPtr(const dest: Pointer; Size: NativeUInt; const Value: Byte); {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}     // alias to FillPtrByte
procedure FillByte(const dest: Pointer; Size: NativeUInt; const Value: Byte); {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}    // alias to FillPtrByte
function CompareMemory(const p1, p2: Pointer; Size: NativeUInt): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}        // returns True if two memory blocks are identical
function CompareMemoryIs0(const p: Pointer; Size: NativeUInt): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}          // returns True if memory is empty
procedure CopyPtr(const sour, dest: Pointer; Size: NativeUInt); {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}                  // copies memory (handles overlapping)

// --- Exception helpers ---
procedure RaiseInfo(const n: string); overload; // raises an exception with the given message
procedure RaiseInfo(const n: string; const Args: array of const); overload; // raises a formatted exception

// --- Platform query ---
function IsMobile: Boolean; // True if running on iOS or Android

// --- Time functions ---
function GetTimeTick(): TTimeTick; // returns a monotonically increasing 64‑bit millisecond tick (never wraps)
function GetTimeTickCount(): TTimeTick; // alias for GetTimeTick
function GetCrashTimeTick(): TTimeTick; // returns MaxUInt64 - GetTimeTick (useful for crash dumps)
function GetTimeTickDiff(t1, t2: TTimeTick): TTimeTick;

// --- Floating‑point comparison with tolerance ---
function SameF(const A, B: Double; Epsilon: Double = 0): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // compares two Doubles within Epsilon (auto if 0)
function SameF(const A, B: Single; Epsilon: Single = 0): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // compares two Singles

// --- MT19937 random number generator API ---
function MT19937CoreToDelphi: Boolean; // True if MT19937 has replaced Delphi's Random()
function MT19937InstanceNum(): integer; // number of active MT19937 instances in the pool
procedure SetMT19937Seed(seed: integer); // sets the seed for the current thread's RNG
function GetMT19937Seed(): integer; // returns the current seed of the current thread's RNG
procedure MT19937Randomize(); // randomizes the seed using a global counter
function MT19937Rand32: integer; overload; // returns a random 32‑bit value (0..$7FFFFFFF)
function MT19937Rand32(L: integer): integer; overload; // returns random value in [0, L-1]
procedure MT19937Rand32(L: integer; dest: PInteger; Num: NativeInt); overload; // fills an array with random values in [0, L-1]
function MT19937Rand64: Int64; overload; // returns a random 64‑bit value (0..$7FFFFFFFFFFFFFFF)
function MT19937Rand64(L: Int64): Int64; overload; // returns random value in [0, L-1]
procedure MT19937Rand64(L: Int64; dest: PInt64; Num: NativeInt); overload; // fills array with random values in [0, L-1]
function MT19937RandE: Extended; overload; // returns random Extended in [0, 1)
procedure MT19937RandE(dest: PExtended; Num: NativeInt); overload; // fills array with random Extended in [0, 1)
function MT19937RandF: Single; overload; // returns random Single in [0, 1)
procedure MT19937RandF(dest: PSingle; Num: NativeInt); overload; // fills array with random Single in [0, 1)
function MT19937RandD: Double; overload; // returns random Double in [0, 1)
procedure MT19937RandD(dest: PDouble; Num: NativeInt); overload; // fills array with random Double in [0, 1)
procedure MT19937SaveToStream(stream: TCore_Stream); // saves the current thread's RNG state to a stream
procedure MT19937LoadFromStream(stream: TCore_Stream); // loads the current thread's RNG state from a stream

// --- Bitwise rotation (circular shift) ---
function ROL8(const Value: Byte; Shift: Byte): Byte; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}     // rotate left 8-bit
function ROL16(const Value: Word; Shift: Byte): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}   // rotate left 16-bit
function ROL32(const Value: Cardinal; Shift: Byte): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // rotate left 32-bit
function ROL64(const Value: UInt64; Shift: Byte): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // rotate left 64-bit
function ROR8(const Value: Byte; Shift: Byte): Byte; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}     // rotate right 8-bit
function ROR16(const Value: Word; Shift: Byte): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}   // rotate right 16-bit
function ROR32(const Value: Cardinal; Shift: Byte): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // rotate right 32-bit
function ROR64(const Value: UInt64; Shift: Byte): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // rotate right 64-bit

// --- Endian conversion (native ↔ big/little) ---
function Endian(const Value: SmallInt): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // byte swap
function Endian(const Value: Word): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function Endian(const Value: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function Endian(const Value: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function Endian(const Value: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function Endian(const Value: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

function BE2N(const Value: SmallInt): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // big‑endian to native
function BE2N(const Value: Word): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function BE2N(const Value: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function BE2N(const Value: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function BE2N(const Value: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function BE2N(const Value: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

function LE2N(const Value: SmallInt): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // little‑endian to native
function LE2N(const Value: Word): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function LE2N(const Value: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function LE2N(const Value: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function LE2N(const Value: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function LE2N(const Value: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

function N2BE(const Value: SmallInt): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // native to big‑endian
function N2BE(const Value: Word): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function N2BE(const Value: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function N2BE(const Value: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function N2BE(const Value: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function N2BE(const Value: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

function N2LE(const Value: SmallInt): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; // native to little‑endian
function N2LE(const Value: Word): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function N2LE(const Value: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function N2LE(const Value: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function N2LE(const Value: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function N2LE(const Value: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

// --- Arithmetic right shift (preserve sign) ---
function SAR16(const Value: SmallInt; const Shift: Byte): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // signed 16-bit
function SAR32(const Value: integer; Shift: Byte): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}       // signed 32-bit
function SAR64(const Value: Int64; Shift: Byte): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}           // signed 64-bit

// --- Memory alignment ---
function MemoryAlign(addr: Pointer; alignment_: NativeUInt): Pointer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // rounds up address to given alignment

// --- Conditional (ternary) operators ---
function if_(const bool_: Boolean; const True_, False_: Boolean): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: ShortInt): ShortInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: SmallInt): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: integer): integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: Byte): Byte; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: Word): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: Single): Single; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function if_(const bool_: Boolean; const True_, False_: string): string; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function ifv_(const bool_: Boolean; const True_, False_: Variant): Variant; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // variant version

// --- Pointer arithmetic helpers ---
function GetOffset(const p_: Pointer; const offset_: NativeInt): Pointer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} // adds offset to pointer (byte offset)
function GetPtr(const p_: Pointer; const offset_: NativeInt): Pointer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}   // alias for GetOffset

// check utf8
function IsValidUTF8Bytes(const Data: TBytes): Boolean;

{$EndRegion 'api'}
{$Region 'core var'}

type
  TOn_Check_Thread_Synchronize = procedure();
  TOn_Raise_Info = procedure(const n: string);
  TOn_Instance_Info = procedure(const Instance_: string);

var
  On_Raise_Info: TOn_Raise_Info;
  Inc_Instance_Num: TOn_Instance_Info;
  Dec_Instance_Num: TOn_Instance_Info;
  // Invoked by RaiseInfo just before the exception is raised.
  // Arguments:
  //   Msg            - the raw message passed to RaiseInfo
  //   Caller_Address - return address of RaiseInfo, i.e. the address
  //                    right after the call site in user code
  //
  // Assign this from a unit that wants to report every RaiseInfo
  // invocation (including its source location) without interfering
  // with the raise itself. Set to nil to disable.
  On_Raise_Info_Detail: procedure(const Msg: string; Caller_Address: Pointer) = nil;

  // boot thread
  Boot_Thread: TCore_Thread; // boot-thread
  Boot_Thread_ID: TThreadID; // boot-thread-id
  Boot_Thread_Sync_Tool: TSoft_Synchronize_Tool; // synchronize tool for boot-thread
  // core thread
  Main_Thread: TCore_Thread; // core main-thread
  Main_Thread_ID: TThreadID; // core main-thread-id
  Main_Thread_Soft_Synchronize: Boolean; // core soft thread synchronize simulator
  Main_Thread_Sync_Tool: TSoft_Synchronize_Tool; // core synchronize tool for main-thread

  // Check Synchronize for main-thread
  Enabled_Check_Thread_Synchronize_System: Boolean;
  Main_Thread_Synchronize_Running: Boolean;
  OnCheckThreadSynchronize: TOn_Check_Thread_Synchronize;
  // caller of per second tool
  CPS_Check_Soft_Thread, CPS_Check_System_Thread: TCPS_Tool;
  // DelphiParallelFor and FPCParallelFor work in parallel
  WorkInParallelCore: TAtomBool;
  // same WorkInParallelCore
  ParallelCore: TAtomBool;
  // default is True
  GlobalMemoryHook: TAtomBool;
  // core init time
  CoreInitedTimeTick: TTimeTick;
  // The life time of working in asynchronous thread consistency,
  MT19937LifeTime: TTimeTick;
  // MainThread TThreadPost
  MainThreadProgress: TThreadPost;
  MainThreadPost: TThreadPost;
  CoreThreadPost: TThreadPost;

{$EndRegion 'core var'}
{$Region 'core-const'}
const
  {$IF Defined(WIN32)}
  CurrentPlatform: TExecutePlatform = epWin32;
  {$ELSEIF Defined(WIN64)}
  CurrentPlatform: TExecutePlatform = epWin64;
  {$ELSEIF Defined(OSX)}
    {$IFDEF CPU64}
      CurrentPlatform: TExecutePlatform = epOSX64;
    {$ELSE CPU64}
      CurrentPlatform: TExecutePlatform = epOSX32;
    {$IFEND CPU64}
  {$ELSEIF Defined(IOS)}
    {$IFDEF CPUARM}
    CurrentPlatform: TExecutePlatform = epIOS;
    {$ELSE CPUARM}
    CurrentPlatform: TExecutePlatform = epIOSSIM;
    {$ENDIF CPUARM}
  {$ELSEIF Defined(ANDROID)}
    {$IFDEF CPU64}
    CurrentPlatform: TExecutePlatform = epANDROID64;
    {$ELSE CPU64}
    CurrentPlatform: TExecutePlatform = epANDROID32;
    {$IFEND CPU64}
  {$ELSEIF Defined(Linux)}
    {$IFDEF CPU64}
      CurrentPlatform: TExecutePlatform = epLinux64;
    {$ELSE CPU64}
      CurrentPlatform: TExecutePlatform = epLinux32;
    {$IFEND CPU64}
  {$ELSEIF Defined(BSD)}
      CurrentPlatform: TExecutePlatform = epBSD;
  {$ELSE}
  CurrentPlatform: TExecutePlatform = epUnknow;
  {$IFEND}

  CPU64 = {$IFDEF CPU64}True{$ELSE CPU64}False{$ENDIF CPU64};
  X64 = CPU64;

  IsDebug = {$IFDEF DEBUG}True{$ELSE DEBUG}False{$ENDIF DEBUG};

  MaxInt64: Int64 = $7FFFFFFFFFFFFFFF;

  // timetick define
  C_Tick_Second = TTimeTick(1000);
  C_Tick_Minute = TTimeTick(C_Tick_Second) * 60;
  C_Tick_Hour   = TTimeTick(C_Tick_Minute) * 60;
  C_Tick_Day    = TTimeTick(C_Tick_Hour) * 24;
  C_Tick_Week   = TTimeTick(C_Tick_Day) * 7;
  C_Tick_Year   = TTimeTick(C_Tick_Day) * 365;

  // memory align
  C_MH_MemoryDelta = 0;

  // file mode
  fmCreate         = Classes.fmCreate;
  soFromBeginning  = Classes.soFromBeginning;
  soFromCurrent    = Classes.soFromCurrent;
  soFromEnd        = Classes.soFromEnd;
  fmOpenRead       = SysUtils.fmOpenRead;
  fmOpenWrite      = SysUtils.fmOpenWrite;
  fmOpenReadWrite  = SysUtils.fmOpenReadWrite;
  fmShareExclusive = SysUtils.fmShareExclusive;
  fmShareDenyWrite = SysUtils.fmShareDenyWrite;
  fmShareDenyNone  = SysUtils.fmShareDenyNone;
{$EndRegion 'core-const'}
{$Region 'compatible'}
{$I Z.Core.Compatible.inc}
{$EndRegion 'compatible'}

implementation

{$I Z.Core.CPS.inc}                         // Calls-per-second profiling tool for performance measurement
{$I Z.Core.Intermediate.inc}                // Base classes with optional instance tracking for debugging
{$I Z.Core.Critical.inc}                    // Critical section wrapper with object pooling and atomic helpers
{$I Z.Core.Atomic.inc}                      // Atomic increment/decrement operations and lock pool
{$I Z.Core.MT19937.inc}                     // Mersenne Twister (MT19937) random number generator core
{$I Z.Core.Timer.inc}                       // Timer subscription and management infrastructure
{$I Z.Core.API.inc}                         // Core API utilities: memory ops, disposal, time, hashing, etc.
{$I Z.Core.Endian.inc}                      // Endianness conversion and bitwise rotation functions
{$I Z.Core.SoftSynchronize.inc}             // User-space thread synchronisation (soft sync) tools
{$I Z.Core.ThreadPost.inc}                  // Thread message posting and progress handling
{$I Z.Core.ComputeThread.inc}               // Compute thread pool, task dispatch, and worker threads
{$IFDEF FPC}
  {$I Z.Core.FPCParallelFor.inc}            // Parallel for implementation for Free Pascal (block/fold)
{$ELSE FPC}
  {$I Z.Core.DelphiParallelFor.inc}         // Parallel for implementation for Delphi (block/fold)
{$ENDIF FPC}
{$I Z.Core.AtomVar.inc}                     // Atomic variable wrapper (TAtomVar) for thread-safe access
{$I Z.Core.OrderData.inc}                   // FIFO queue structures (TOrderStruct and variants)
{$I Z.Core.BigList.inc}                     // High-performance doubly linked list with recycle pool and indexing
{$I Z.Core.Hash_Pair.inc}                   // Pair record definitions and tool classes (TPair*)
{$I Z.Core.Hash_Tool.inc}                   // Generic hash map implementation (big hash pair pools)


{$Region 'Base_Define_Imp'}
{$IFDEF FPC}

function TCore_InterfacedObject._AddRef: longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  Result := 1;
end;

function TCore_InterfacedObject._Release: longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  Result := 1;
end;

procedure TCore_InterfacedObject.AfterConstruction;
begin
end;

procedure TCore_InterfacedObject.BeforeDestruction;
begin
end;

{$ELSE}

function TCore_InterfacedObject._AddRef: Integer;
begin
  Result := 1;
end;

function TCore_InterfacedObject._Release: Integer;
begin
  Result := 1;
end;

procedure TCore_InterfacedObject.AfterConstruction;
begin
end;

procedure TCore_InterfacedObject.BeforeDestruction;
begin
end;

constructor TGenericsList<t>.Create;
begin
  inherited Create;
  {$IFDEF Intermediate_Instance_Tool}
  Inc_Instance_Num(UnitName + '.pas (' + ClassName + ')');
  {$ENDIF Intermediate_Instance_Tool}
end;

destructor TGenericsList<t>.Destroy;
begin
  {$IFDEF Intermediate_Instance_Tool}
  Dec_Instance_Num(UnitName + '.pas (' + ClassName + ')');
  {$ENDIF Intermediate_Instance_Tool}
  inherited Destroy;
end;

function TGenericsList<t>.ListData: PGArry;
begin
  // set array pointer
  Arry := TGArry(Pointer(inherited List));
  // @ array
  Result := @Arry;
end;

constructor TGenericsObjectList<t>.Create;
begin
  inherited Create;
  {$IFDEF Intermediate_Instance_Tool}
  Inc_Instance_Num(UnitName + '.pas (' + ClassName + ')');
  {$ENDIF Intermediate_Instance_Tool}
end;

destructor TGenericsObjectList<t>.Destroy;
begin
  {$IFDEF Intermediate_Instance_Tool}
  Dec_Instance_Num(UnitName + '.pas (' + ClassName + ')');
  {$ENDIF Intermediate_Instance_Tool}
  inherited Destroy;
end;

function TGenericsObjectList<t>.ListData: PGArry;
begin
  // set array pointer
  Arry := TGArry(Pointer(inherited List));
  // @ array
  Result := @Arry;
end;

constructor TCore_List.Create;
begin
  inherited Create;
  {$IFDEF Intermediate_Instance_Tool}
  Inc_Instance_Num(UnitName + '.pas (' + ClassName + ')');
  {$ENDIF Intermediate_Instance_Tool}
end;

destructor TCore_List.Destroy;
begin
  {$IFDEF Intermediate_Instance_Tool}
  Dec_Instance_Num(UnitName + '.pas (' + ClassName + ')');
  {$ENDIF Intermediate_Instance_Tool}
  inherited Destroy;
end;

function TCore_List.ListData: PCore_PointerList;
begin
  Result := PCore_PointerList(inherited ListData);
end;

constructor TCore_ListForObj.Create;
begin
  inherited Create;
  {$IFDEF Intermediate_Instance_Tool}
  Inc_Instance_Num(UnitName + '.pas (' + ClassName + ')');
  {$ENDIF Intermediate_Instance_Tool}
end;

destructor TCore_ListForObj.Destroy;
begin
  {$IFDEF Intermediate_Instance_Tool}
  Dec_Instance_Num(UnitName + '.pas (' + ClassName + ')');
  {$ENDIF Intermediate_Instance_Tool}
  inherited Destroy;
end;

function TCore_ListForObj.ListData: PCore_ForObjectList;
begin
  Result := PCore_ForObjectList(inherited ListData);
end;

{$ENDIF}

constructor TCore_ObjectList.Create;
begin
  inherited Create;
  AutoFreeObj := True;
end;

constructor TCore_ObjectList.Create(AutoFreeObj_: Boolean);
begin
  inherited Create;
  AutoFreeObj := AutoFreeObj_;
end;

destructor TCore_ObjectList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TCore_ObjectList.Remove(obj: TCore_Object);
begin
  if AutoFreeObj then
      DisposeObject(obj);
  inherited Remove(obj);
end;

procedure TCore_ObjectList.Delete(index: Integer);
begin
  if (index >= 0) and (index < Count) then
    begin
      if AutoFreeObj then
          disposeObject(Items[index]);
      inherited Delete(index);
    end;
end;

procedure TCore_ObjectList.Clear;
var
  i: Integer;
begin
  if AutoFreeObj then
    for i := 0 to Count - 1 do
        disposeObject(Items[i]);
  inherited Clear;
end;
{$EndRegion 'Base_Define_Imp'}

function Get_Compiler_Version: string;
begin
  {$IFDEF FPC}
    // 使用 FPC 内置的版本常量，避免依赖不稳定的版本宏
    Result := 'FPC ' + IntToStr(FPC_VERSION) + '.' + IntToStr(FPC_RELEASE) + '.' + IntToStr(FPC_PATCH);
  {$ELSE}
    // Delphi / Kylix 分支
    {$IFDEF CONDITIONALEXPRESSIONS}  // Delphi 6 及以上支持条件编译
      {$IF defined(KYLIX3)} Result := 'Kylix 3';
      {$ELSEIF defined(VER140)} Result := 'Delphi 6';
      {$ELSEIF defined(VER150)} Result := 'Delphi 7';
      {$ELSEIF defined(VER160)} Result := 'Delphi 8';
      {$ELSEIF defined(VER170)} Result := 'Delphi 2005';
      {$ELSEIF defined(VER180)} Result := 'Delphi 2006';
      {$ELSEIF defined(VER185)} Result := 'Delphi 2007';
      {$ELSEIF defined(VER200)} Result := 'Delphi 2009';
      {$ELSEIF defined(VER210)} Result := 'Delphi 2010';
      {$ELSEIF defined(VER220)} Result := 'Delphi XE';
      {$ELSEIF defined(VER230)} Result := 'Delphi XE2';
      {$ELSEIF defined(VER240)} Result := 'Delphi XE3';
      {$ELSEIF defined(VER250)} Result := 'Delphi XE4';
      {$ELSEIF defined(VER260)} Result := 'Delphi XE5';
      {$ELSEIF defined(VER265)} Result := 'AppMethod 1';
      {$ELSEIF defined(VER270)} Result := 'Delphi XE6';
      {$ELSEIF defined(VER280)} Result := 'Delphi XE7';
      {$ELSEIF defined(VER290)} Result := 'Delphi XE8';
      {$ELSEIF defined(VER300)} Result := 'Delphi 10 Seattle';
      {$ELSEIF defined(VER310)} Result := 'Delphi 10.1 Berlin';
      {$ELSEIF defined(VER320)} Result := 'Delphi 10.2 Tokyo';
      {$ELSEIF defined(VER330)} Result := 'Delphi 10.3 Rio';
      {$ELSEIF defined(VER340)} Result := 'Delphi 10.4';
      {$ELSEIF defined(VER350)} Result := 'Delphi 11';
      {$ELSEIF defined(VER360)} Result := 'Delphi 11.x or 12 last...';
      {$ELSEIF defined(VER370)} Result := 'Delphi 12 or 13 last...';
      {$ELSEIF defined(VER380)} Result := 'Delphi 12 last...';
      {$ELSEIF defined(VER390)} Result := 'Delphi 13 last...';
      {$ELSEIF defined(VER400)} Result := 'Delphi 14 last...';
      {$ELSE} Result := 'Unknown Delphi Compiler';
      {$IFEND}
    {$ELSE}
      Result := 'Delphi (pre-6)';
    {$ENDIF}
  {$ENDIF}
  {$IFDEF CPU64}
    Result := Result + ' 64 bit';
  {$ELSE}
    Result := Result + ' 32 bit';
  {$ENDIF}
end;

initialization
  {$IFDEF DEBUG} if IsConsole then Writeln('Compiler: ' + Get_Compiler_Version()); {$ENDIF DEBUG}
  // float exception
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  // raise event
  On_Raise_Info := nil;
  // instance trace
  Inc_Instance_Num := ___Inc_Instance_Num___;
  Dec_Instance_Num := ___Dec_Instance_Num___;
  // cirtial recycle pool
  Init_System_Critical_Recycle_Pool();
  // boot-thread Technology
  Boot_Thread := TCore_Thread.CurrentThread;
  Boot_Thread_ID := Boot_Thread.ThreadID;
  Boot_Thread_Sync_Tool := TSoft_Synchronize_Tool.Create(Boot_Thread);
  // main-thread Technology
  Main_Thread := Boot_Thread;
  Main_Thread_ID := Main_Thread.ThreadID;
  Main_Thread_Soft_Synchronize := {$IFDEF Core_Thread_Soft_Synchronize}True{$ELSE Core_Thread_Soft_Synchronize}False{$ENDIF Core_Thread_Soft_Synchronize};
  Main_Thread_Sync_Tool := TSoft_Synchronize_Tool.Create(Main_Thread);
  On_Check_Soft_Thread_Synchronize := Do_Check_Soft_Thread_Synchronize;
  On_Check_System_Thread_Synchronize := Do_Check_System_Thread_Synchronize;
  OnCheckThreadSynchronize := nil;
  // cps
  CPS_Check_Soft_Thread.Reset;
  CPS_Check_System_Thread.Reset;
  // parallel
  WorkInParallelCore := TAtomBool.Create(True);
  ParallelCore := WorkInParallelCore;
  // MM hook
  GlobalMemoryHook := TAtomBool.Create(True);
  // timetick
  Init_Time_Tick();
  // global cirtical
  Init_Critical_System();
  // random
  InitMT19937Rand();
  CoreInitedTimeTick := GetTimeTick();
  // thread pool
  InitCoreThreadPool(if_(IsDebuging, 2, CpuCount * 2), if_(IsDebuging, 2, {$IFDEF LimitMaxParallelThread}8{$ELSE LimitMaxParallelThread}CpuCount * 2{$ENDIF LimitMaxParallelThread}));
  // thread progress
  MainThreadProgress := TThreadPost.Create(Main_Thread_ID);
  MainThreadProgress.OneStep := False;
  MainThreadPost := MainThreadProgress;
  CoreThreadPost := MainThreadProgress;
  // thread Synchronize state
  Enabled_Check_Thread_Synchronize_System := True;
  Main_Thread_Synchronize_Running := False;
  // Core Timer
  Init_Core_Timer();
finalization
  On_Raise_Info := nil;
  OnCheckThreadSynchronize := nil;
  Check_Soft_Thread_Synchronize(0);
  FreeCoreThreadPool;
  Free_Core_Timer();
  MainThreadProgress.Free;
  FreeMT19937Rand();
  Free_Critical_System;
  WorkInParallelCore.Free;
  WorkInParallelCore := nil;
  GlobalMemoryHook.Free;
  GlobalMemoryHook := nil;
  DisposeObjectAndNil(Main_Thread_Sync_Tool);
  DisposeObjectAndNil(Boot_Thread_Sync_Tool);
  Free_System_Critical_Recycle_Pool();
end.
