{$IFDEF FPC}
  {$UNDEF FPC_DEBUG}

  {$IFDEF FPC_DELPHI_MODE}
    {$MODE delphi}
  {$ELSE FPC_DELPHI_MODE}
    {$MODE objfpc}
  {$ENDIF FPC_DELPHI_MODE}

  {$MODESWITCH AdvancedRecords}
  {$MODESWITCH NestedProcVars}
  {$MODESWITCH NESTEDCOMMENTS}
  {$NOTES OFF}
  {$COPERATORS OFF}
  {$GOTO ON}
  {$INLINE ON}
  {$MACRO ON}
  {$IEEEERRORS OFF}
  {$packrecords c}

  {$DEFINE LITTLE_ENDIAN}
  {$UNDEF BIG_ENDIAN}
  {$IFDEF FPC_BIG_ENDIAN}
    {$UNDEF LITTLE_ENDIAN}
    {$DEFINE BIG_ENDIAN}
  {$ENDIF}

  {$UNDEF FirstCharInZero}
  {$UNDEF Delphi}

  {$IFDEF Unix}
    {$DEFINE Posix}
  {$ENDIF Unix}

  {$IFDEF Linux}
    {$DEFINE Posix}
  {$ENDIF Linux}

  // nativeint as int or int64 type variable when Modifier is overload
  {$UNDEF OVERLOAD_NATIVEINT}

  // fast MD5 only delphi supported, https://github.com/PassByYou888/FastMD5
  {$UNDEF FastMD5}

  // stream is MemoryStream64 or MemoryStream, usage fastMD5 or PurePascal MD5
  // be associate api: UnicodeMixedLib.umlStreamMD5, Fast_MD5.FastMD5
  {$DEFINE OptimizationMemoryStreamMD5}

  // multi thread Parallel switch.
  {$IFDEF CPUARM}
    {$UNDEF Parallel}
  {$ELSE CPUARM}
    {$IFDEF DEBUG}
      {$UNDEF Parallel}
    {$ELSE DEBUG}
      {$DEFINE Parallel}
    {$ENDIF DEBUG}
  {$ENDIF CPUARM}

  // Parallel for fold make better use CPU of multi core
  // if rem this "FoldParallel" parallel for block program, thread can use linear address
  {$DEFINE FoldParallel}

  // MT19937 of seed in the startup TCompute is 0
  {$DEFINE MT19937SeedOnTComputeThreadIs0}

  // automated loading common AI datasets on boot-time
  {$DEFINE Z_AI_Dataset_Build_In}

  // With SMALL_RASTER_FONT_Build_In and LARGE_RASTER_FONT_Build_In, boot-time memory usage increase by 100M-200M and start-up time to be delay 100ms
  {$DEFINE SMALL_RASTER_FONT_Build_In}
  {$UNDEF LARGE_RASTER_FONT_Build_In}

  // ZDB_BACKUP is automatically made and replica caching is enabled.
  // usage ZDB_BACKUP so slows the open of large size ZDB file, after time, but does is high performance.
  {$UNDEF ZDB_BACKUP}

  // ZDB Flush() uses physical IO as the temp storage device
  {$UNDEF ZDB_PHYSICAL_FLUSH}

  // used Critical Simulate Atomic with TMonitor.Enter(obj) and TMonitor.Exit(obj)
  // CriticalSimulateAtomic defined so performance to be reduced
  {$DEFINE CriticalSimulateAtomic}

  {$UNDEF ANTI_DEAD_ATOMIC_LOCK}

  // ZNet Physics-IO used CrossSocket for FPC
  {$DEFINE PhysicsIO_On_FPC_CrossSocket}

  {$IFDEF CPU64BITS}
    // fpc INTERLOCK
    {$DEFINE USED_INTERLOCK}
  {$ELSE CPU64BITS}
    {$UNDEF USED_INTERLOCK}
  {$ENDIF CPU64BITS}

  {$IFDEF FPC_DEBUG}
    {$STACKFRAMES ON}
    {$DEFINE debug}
    {$UNDEF release}
    {$UNDEF INLINE_ASM}
    {$OPTIMIZATION OFF}
    {$S+}   { open stack checks }
  {$ELSE FPC_DEBUG}
    {$STACKFRAMES OFF}
    {$UNDEF debug}
    {$DEFINE release}
    {$DEFINE INLINE_ASM}
    {$OPTIMIZATION LEVEL2}
    {$S-}   { No stack checks ¨C faster, but risk of silent stack overflow }
  {$ENDIF FPC_DEBUG}

  {$CODEPAGE UTF8}
  {$PACKENUM 4}    (* use 4-byte enums *)
  {$R-}   { No range checks ¨C faster, assumes all indices are valid }
  {$I-}   { No I/O checks ¨C faster, use IOResult to handle errors manually }

{$ELSE FPC} { IF DELPHI }
  {$DEFINE Delphi}

  {$DEFINE LITTLE_ENDIAN}
  {$UNDEF BIG_ENDIAN}

  {$IFDEF ANDROID}
    {$DEFINE FirstCharInZero}
  {$ENDIF ANDROID}

  {$IFDEF IOS}
    {$DEFINE FirstCharInZero}
  {$ENDIF IOS}

  // nativeint as int or int64 type variable when Modifier is overload
  {$DEFINE OVERLOAD_NATIVEINT}

  // fast MD5 only delphi supported, https://github.com/PassByYou888/FastMD5
  {$DEFINE FastMD5}

  // stream is MemoryStream64 or MemoryStream, usage fastMD5 or PurePascal MD5
  // be associate api: UnicodeMixedLib.umlStreamMD5, Fast_MD5.FastMD5
  {$DEFINE OptimizationMemoryStreamMD5}

  // multi thread Parallel switch.
  {$IFDEF CPUARM}
    {$UNDEF Parallel}
  {$ELSE CPUARM}
    {$IFDEF DEBUG}
      {$UNDEF Parallel}
    {$ELSE DEBUG}
      {$DEFINE Parallel}
    {$ENDIF DEBUG}
  {$ENDIF CPUARM}

  // Parallel for fold make better use CPU of multi core
  // if rem this "FoldParallel" is parallel for block program, thread can use linear address
  {$DEFINE FoldParallel}

  // paper: Mersenne Twister: A 623-dimensionallyequidistributed uniformpseudorandom number generator
  // Using this paper replace of Delphi Random() and Randomize() function, work on xe 10.3 or laster
  {$UNDEF InstallMT19937CoreToDelphi}

  // delphi 10.3
  {$IFDEF VER330}
    {$DEFINE InstallMT19937CoreToDelphi}
  {$ENDIF VER330}

  // delphi 10.4
  {$IFDEF VER340}
    {$DEFINE InstallMT19937CoreToDelphi}
    {$UNDEF FirstCharInZero}
  {$ENDIF VER340}

  // delphi 11.0
  {$IFDEF VER350}
    {$DEFINE InstallMT19937CoreToDelphi}
    {$UNDEF FirstCharInZero}
  {$ENDIF VER350}

  // delphi 12.x
  {$IFDEF VER360}
    {$DEFINE InstallMT19937CoreToDelphi}
    {$UNDEF FirstCharInZero}
  {$ENDIF VER360}

  // delphi 13.x
  {$IFDEF VER370}
    {$DEFINE InstallMT19937CoreToDelphi}
    {$UNDEF FirstCharInZero}
  {$ENDIF VER370}

  // delphi 14.x
  {$IFDEF VER380}
    {$DEFINE InstallMT19937CoreToDelphi}
    {$UNDEF FirstCharInZero}
  {$ENDIF VER380}

  // MT19937 of seed in the startup TCompute is 0
  {$DEFINE MT19937SeedOnTComputeThreadIs0}

  // automated loading common AI datasets on boot-time
  {$UNDEF Z_AI_Dataset_Build_In}

  // With SMALL_RASTER_FONT_Build_In and LARGE_RASTER_FONT_Build_In, boot-time memory usage increase by 100M-200M and start-up time to be delay 100ms
  {$UNDEF SMALL_RASTER_FONT_Build_In}
  {$UNDEF LARGE_RASTER_FONT_Build_In}

  {$IF Defined(Android) or Defined(IOS)}
    {$DEFINE SMALL_RASTER_FONT_Build_In}
  {$ENDIF}

  // ZDB_BACKUP is automatically made and replica caching is enabled.
  // usage ZDB_BACKUP so slows the open of large size ZDB file, after time, but does is high performance.
  {$UNDEF ZDB_BACKUP}

  // ZDB Flush() uses physical IO as the temp storage device
  {$UNDEF ZDB_PHYSICAL_FLUSH}

  // used Critical Simulate Atomic with TMonitor.Enter(obj) and TMonitor.Exit(obj)
  // CriticalSimulateAtomic defined so performance to be reduced
  {$UNDEF CriticalSimulateAtomic}

  {$UNDEF ANTI_DEAD_ATOMIC_LOCK}

  // It only slows down Delphi strings, doesn't help C++Builder migration and is finally gone in XE+
  {$STRINGCHECKS OFF}

  // All sets only use ASCII chars (<=#127) and the compiler generates the >=#128 check itself
  {$WARN WIDECHAR_REDUCED OFF}

  // for StrLen/StrLComp
  {$WARN SYMBOL_DEPRECATED OFF}

  {$IFDEF release}
    {$DEFINE INLINE_ASM}
    {$R-} { range check }
    {$I-} { Input output checking }
    {$IF Defined(Android) or Defined(IOS) or Defined(Linux)}
      {$O-} { close optimization }
      {$UNDEF INLINE_ASM}
      {$INLINE OFF} { inline }
    {$ELSE}
      {$O+} { open optimization }
      {$INLINE ON} { inline }
    {$IFEND}
    {$STRINGCHECKS OFF}
    {$D-} { debug information }
  {$ELSE release}
    {$UNDEF INLINE_ASM}
    {$O-} { close optimization }
    {$R-} { range check }
    {$I-} { Input output checking }
    {$D+} { debug information }
  {$ENDIF release}

  {$IF Defined(Android)}
    {$DEFINE LINUX}
    {$DEFINE POSIX}
    {$DEFINE SMALL_RASTER_FONT_Build_In}
    {$DEFINE PhysicsIO_On_FPC_CrossSocket}
  {$ELSEIF Defined(IOS)}
    {$DEFINE SMALL_RASTER_FONT_Build_In}
    {$DEFINE PhysicsIO_On_Indy}
  {$ELSEIF Defined(OSX)}
    {$DEFINE SMALL_RASTER_FONT_Build_In}
    {$DEFINE PhysicsIO_On_FPC_CrossSocket}
  {$ELSE}
    // PhysicsIO interface
    {$DEFINE PhysicsIO_On_FPC_CrossSocket}
  {$IFEND}

  {$MINENUMSIZE 4} (* use 4-byte enums *)

  // SSE Optimzied for distance
  {$IF Defined(MSWINDOWS)}
  {$DEFINE SSE_Optimize_Distance_Compute}
  {$ENDIF Defined(MSWINDOWS)}

{$ENDIF FPC}


// Intermediate_Instance_Tool is used to trace activity instances, which can affect performance after startup.
// Intermediate_Instance_Tool help debug and analyze the state of large programs
{$IFDEF DEBUG}
  {$DEFINE Intermediate_Instance_Tool}
{$ELSE DEBUG}
  {$UNDEF Intermediate_Instance_Tool}
{$ENDIF DEBUG}

// Core_Thread_Soft_Synchronize is use software to solve atomic hardware synchronization waiting.
// When using a DLL or library program, "Core_Thread_Soft_Synchronize" should be used.
{$DEFINE Core_Thread_Soft_Synchronize}

// tracking delay free object for debug
{$IFDEF DEBUG}
  {$DEFINE Tracking_Dealy_Free_Object}
{$ELSE DEBUG}
  {$UNDEF Tracking_Dealy_Free_Object}
{$ENDIF DEBUG}

{$IFDEF NO_FS}
  // Disable file system for ZNet-DoubleIO
  {$UNDEF DoubleIOFileSystem}
{$ELSE NO_FS}
  // Enabled file system for ZNet-DoubleIO
  {$DEFINE DoubleIOFileSystem}
{$ENDIF NO_FS}

// Using fillchar replace of FillPtr
// Maybe fillchar works on MMX / SSE2,
{$UNDEF FillPtr_Used_FillChar}

// Using Move replace of CopyPtr
{$UNDEF CopyPtr_Used_Move}

// Sequence packets default are opened in Physics-IO
// Sequence package can support multi platform keep-alive mode
// building a network CS system, the symmetry of compiler(FPC/Delphi) "UsedSequencePacket"
{$DEFINE UsedSequencePacket}

// Sequence package can support multi platform keep-alive mode
// building a network CS system, the symmetry of compiler(FPC/Delphi) "UsedSequencePacketOnP2PVM"
// Sequence packets default are closed in P2PVM-IO
{$UNDEF UsedSequencePacketOnP2PVM}

// P2PVM packet encryption, if need to be compatible old versions of ZNet, do not used Encrypt_P2PVM_Packet
{$UNDEF Encrypt_P2PVM_Packet}

// CommunicationFramework used QuietMode
{$UNDEF Communication_QuietMode}

// Core_Synchronize_Technology is Use TThreadPost technology override for TThread.Synchronize
{$DEFINE Core_Synchronize_Technology}

// core Limit Maximum TCompute Threads, Some CPU cores are few, which may cause TCompute to stop
// maybe resident threads consume a large number of threads,include,Z.AI(DNN-Thread Tech),ZDB2(Thread-Queue Tech))
// MaxComputeThread default limit parameter = CpuCount*20
{$UNDEF LimitMaxComputeThread}

// Limit maximum parallel threads
// When parallel threads are too large,
// server performance will be lost, and in some hardware environments, large-scale threads can reduce parallel computing efficiency by 50%
{$DEFINE LimitMaxParallelThread}

// when the c4 network is deployed and connected for the first time,
// if a connection failure occurs, it is mostly due to the server being started or maintained.
// at this time, c4 will try to connect repeatedly
// after opening this switch, it can facilitate large-scale system integration and deployment.
// the fault repair time can only last for 4 hours. If it exceeds this time, it will be considered a failure
// this "ZNet_C4_Auto_Repair_First_BuildDependNetwork_Fault" is effective for IoT device deployment and large-scale server groups.
{$DEFINE ZNet_C4_Auto_Repair_First_BuildDependNetwork_Fault}

// Safe flush is a power-off protection technology
// ZDB2-HPC support system defaults to using Safe Flush.
// Safe flush can effectively solve the problem of data loss during power outages, and on the other hand, it can reduce IO performance
{$DEFINE ZDB2_Thread_Engine_Safe_Flush}

// When using the ZDB2 engine in the ZNet-C4 framework Safe Flush technology, prioritize the use of Safe Flush technology
{$DEFINE C4_Safe_Flush}

// Print the structure and debugging information of OPCode
{$UNDEF Print_OPCode_Debug}

{$IFDEF DEBUG}
  // initialization status prompt
  {$DEFINE initializationStatus}
  // warning prompt
  {$WARNINGS ON}
  // JPEG support can output debug info
  {$UNDEF JPEG_Debug}
  // show ZDB2 free log in progress
  {$UNDEF SHOW_ZDB2_Data_Free_LOG}
  // Enabled ZDB2 Load Thread
  {$UNDEF Enabled_ZDB2_Load_Thread}
  // show TZDB2_Th_Engine.Build() options
  {$UNDEF SHOW_ZDB2_THREAD_BUILD_LOG}
  // show DisposeObject_PrintInfo class log
  {$DEFINE SHOW_DISPOSEOBJECT_PRINTINFO_LOG}
{$ELSE DEBUG}
  // initialization status prompt
  {$UNDEF initializationStatus}
  // warning prompt
  {$IFDEF FPC}
    {$WARNINGS OFF}
  {$ELSE FPC}
    {$WARNINGS OFF}
  {$ENDIF FPC}
  // JPEG support can output debug info
  {$UNDEF JPEG_Debug}
  // show ZDB2 free log in progress
  {$UNDEF SHOW_ZDB2_Data_Free_LOG}
  // Enabled ZDB2 Load Thread
  {$DEFINE Enabled_ZDB2_Load_Thread}
  // show TZDB2_Th_Engine.Build() options
  {$UNDEF SHOW_ZDB2_THREAD_BUILD_LOG}
  // show DisposeObject_PrintInfo class log
  {$UNDEF SHOW_DISPOSEOBJECT_PRINTINFO_LOG}
{$ENDIF DEBUG}

{$IFDEF Parallel}
  // TMemoryRaster Parallel switch.
  {$DEFINE MemoryRaster_Parallel}
  // TRasterVertex Parallel switch.
  {$DEFINE Vertex_Parallel}
  // TMorphomatics Parallel switch.
  {$DEFINE Morphomatics_Parallel}
  // TMorphologyBinaryzation Parallel switch.
  {$DEFINE MorphologyBinaryzation_Parallel}
{$ELSE Parallel}
  // TMemoryRaster Parallel switch.
  {$UNDEF MemoryRaster_Parallel}
  // TRasterVertex Parallel switch.
  {$UNDEF Vertex_Parallel}
  // TMorphomatics Parallel switch.
  {$UNDEF Morphomatics_Parallel}
  // TMorphologyBinaryzation Parallel switch.
  {$UNDEF MorphologyBinaryzation_Parallel}
{$ENDIF Parallel}

{$HINTS OFF}
{$M-} { Run-Time Type Information }
{$H+} { long string }
{$Q-} { Overflow checking }
{$B-} { Complete boolean evaluation }
{$J-} { Writeable typed constants }
{$T-} { Type-checked Pointers }
{$X+} { Extended Syntax with Pointers }

(*
  Pointer math is simply treating any given typed pointer in some narrow,
  instances as a scaled ordinal where you can perform simple arithmetic operations directly on the pointer variable.
*)
{$POINTERMATH OFF}

{$UNDEF CPU64}

{$IFDEF CPU64BITS}
  {$DEFINE CPU64}
{$ELSE CPU64BITS}
  {$IFDEF CPUX64}
    {$DEFINE CPU64}
  {$ENDIF CPUX64}
{$ENDIF CPU64BITS}

{$IFNDEF CPU64}
  {$DEFINE CPU32}
{$ENDIF CPU64}

{$IFDEF BIG_ENDIAN}
  {$MESSAGE FATAL 'Big-endian system not supported'}
{$ENDIF BIG_ENDIAN}

{$IFOPT R+}
  {$DEFINE RangeCheck}
{$ENDIF}

{$IFOPT Q+}
  {$DEFINE OverflowCheck}
{$ENDIF}
