{
  ******************************************************************************
  * Unit: Z.Geometry.Low
  * Purpose: Low-level 3D geometry and linear algebra library for Delphi/FPC.
  *          Provides comprehensive vector, matrix, quaternion, plane, and
  *          interpolation routines for 3D graphics, physics, and simulation.
  *
  * Key Features:
  *  - Vector types: TVector2f, TVector3f, TVector4f, TAffineVector, TVector
  *    (homogeneous), and corresponding array types.
  *  - Matrix types: TMatrix3f (affine), TMatrix4f (homogeneous) with
  *    identity, creation (scale, translation, rotation, look-at, frustum,
  *    perspective, ortho), multiplication, inversion, transpose, decomposition,
  *    and packing/unpacking of rotation matrices.
  *  - Quaternion support: creation from axis/angle, Euler angles, matrices;
  *    conjugation, normalization, multiplication, SLERP interpolation, and
  *    conversion to/from matrices.
  *  - Plane representation (THmgPlane = TVector) and operations: plane from
  *    points/normal, evaluation, normalization, half-space tests, point
  *    projection, segment/plane intersection.
  *  - Geometric intersection tests: ray/triangle, ray/sphere, ray/box,
  *    triangle/box, sphere/box, segment/segment, line/line, point-in-polygon,
  *    frustum culling.
  *  - Interpolation and easing: linear (Lerp), spherical (QuaternionSlerp),
  *    matrix interpolation, and various non-linear interpolators (power, sin,
  *    tan, ln, exp).
  *  - Utility functions: dot/cross products, length/norm, normalization,
  *    scaling, addition/subtraction, component-wise min/max, angle
  *    manipulation (degrees/radians, normalization), fast approximations
  *    (FastArcTan2, RSqrt), random point on sphere, barycentric coordinates.
  *  - Coordinate system manipulation: Turn, Pitch, Roll relative to local or
  *    master axes.
  *  - Shadow/projection/reflection matrix generation.
  *  - Support for both Single (Single) and Double precision via compiler
  *    defines; uses OpenGL-style naming conventions.
  *
  * Dependencies: Z.Core, Z.Geometry2D, Math.
  *
  * Remarks:
  *  - All vector/matrix indices follow [x=0, y=1, z=2, w=3] convention.
  *  - Homogeneous vectors use w=0 for directions, w=1 for points.
  *  - Many functions are inlined for performance.
  *  - Constants include common vectors, identity matrices, and mathematical
  *    constants (PI, etc.).
  *  - The unit is designed to be both Delphi and Free Pascal compatible.
  ******************************************************************************
}
unit Z.Geometry.Low;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

type
  { A 2‑component vector (x, y) stored as an array of Single. }
  TVector2f = array [0 .. 1] of Single;

  { A 3‑component vector (x, y, z) stored as an array of Single. }
  TVector3f = array [0 .. 2] of Single;

  { A 4‑component vector (x, y, z, w) stored as an array of Single. }
  TVector4f = array [0 .. 3] of Single;

  { A 4‑component integer vector (used for viewports, etc.). }
  TVector4i = array [0 .. 3] of Integer;

  { A 2×2 matrix stored as an array of two TVector2f. }
  TMatrix2f = array [0 .. 1] of TVector2f;

  { A 3×3 affine matrix stored as an array of three TVector3f. }
  TMatrix3f = array [0 .. 2] of TVector3f;

  { A 4×4 homogeneous matrix stored as an array of four TVector4f. }
  TMatrix4f = array [0 .. 3] of TVector4f;

type
  PFloat = PSingle; { Pointer to a Single (alias for OpenGL compatibility). }

  PTexPoint = ^TTexPoint;

  { A 2D texture coordinate pair (s, t). }
  TTexPoint = record
    s, t: Single;
  end;

  { Types for continuous streams of a specific type. Range checking is usually
    turned off to allow access beyond declared limits. }
  TFloatVector = array [0 .. MaxInt div SizeOf(Single) - 1] of Single;
  PFloatVector = ^TFloatVector;
  PFloatArray = PFloatVector;
  PSingleArray = PFloatArray;
  TSingleArray = array of Single;
  TDoubleVector = array [0 .. MaxInt div SizeOf(Double) - 1] of Double;
  PDoubleVector = ^TDoubleVector;
  PDoubleArray = PDoubleVector;
  TDdoubleArray = array of Double;

  { Common vector and matrix types with predefined limits. Indices: 0=x, 1=y, 2=z, 3=w. }

  PHomogeneousFltVector = ^THomogeneousFltVector;
  THomogeneousFltVector = TVector4f;
  PAffineFltVector = ^TAffineFltVector;
  TAffineFltVector = TVector3f;
  PVector2f = ^TVector2f;

  { Simplified names for common use. }
  PVector = ^TVector;
  TVector = THomogeneousFltVector;
  PHomogeneousVector = ^THomogeneousVector;
  THomogeneousVector = THomogeneousFltVector;
  PAffineVector = ^TAffineVector;
  TAffineVector = TVector3f;
  PVertex = ^TVertex;
  TVertex = TAffineVector;

  { Arrays of vectors. }
  PAffineVectorArray = ^TAffineVectorArray;
  TAffineVectorArray = array [0 .. (MaxInt div SizeOf(TAffineVector)) - 1] of TAffineVector;
  PVectorArray = ^TVectorArray;
  TVectorArray = array [0 .. (MaxInt div SizeOf(TVector)) - 1] of TVector;
  PTexPointArray = ^TTexPointArray;
  TTexPointArray = array [0 .. (MaxInt div SizeOf(TTexPoint)) - 1] of TTexPoint;

  { Matrices. }
  THomogeneousFltMatrix = TMatrix4f;
  TAffineFltMatrix = TMatrix3f;

  { Simplified names for matrices. }
  PMatrix = ^TMatrix;
  TMatrix = THomogeneousFltMatrix;
  TMatrixArray = array [0 .. (MaxInt div SizeOf(TMatrix)) - 1] of TMatrix;
  PMatrixArray = ^TMatrixArray;
  PHomogeneousMatrix = ^THomogeneousMatrix;
  THomogeneousMatrix = THomogeneousFltMatrix;
  PAffineMatrix = ^TAffineMatrix;
  TAffineMatrix = TAffineFltMatrix;

  {
    * A plane equation defined by A·x + B·y + C·z + D = 0.
    * The first three components form the normal vector; the fourth is D.
    * This record is simply an alias for TVector to simplify plane operations.
  }
  THmgPlane = TVector;

  {
    * A quaternion representing a rotation in 3D space.
    * The imaginary part (x, y, z) and the real part (w) are stored separately.
    * Quaternions are used for smooth interpolation (SLERP) and to avoid gimbal lock.
  }
  TQuaternion = record
    RealPart: Single; { w component }
    ImagPart: TAffineVector; { (x, y, z) components }
  end;

  PQuaternion = ^TQuaternion;
  PQuaternionArray = ^TQuaternionArray;
  TQuaternionArray = array [0 .. (MaxInt div SizeOf(TQuaternion)) - 1] of TQuaternion;

  { Integer rectangle (used for viewports). }
  TRectangle = record
    Left, Top, width, height: Integer;
  end;

  {
    * A frustum defined by six clipping planes: left, top, right, bottom, near, far.
    * Each plane is a THmgPlane (normal + D). The planes are oriented such that the
    * interior is the half-space with positive dot product (for a point).
  }
  TFrustum = record
    pLeft, pTop, pRight, pBottom, pNear, pFar: THmgPlane;
  end;

  {
    * Transformation types used in TTransformations.
    * The order of transformations: scale, shear, rotation, translation, perspective.
    * Constants are declared below for easier indexing.
  }
  TTransType = (ttScaleX, ttScaleY, ttScaleZ,
    ttShearXY, ttShearXZ, ttShearYZ,
    ttRotateX, ttRotateY, ttRotateZ,
    ttTranslateX, ttTranslateY, ttTranslateZ,
    ttPerspectiveX, ttPerspectiveY, ttPerspectiveZ, ttPerspectiveW);

  {
    * An array holding the decomposition of a 4×4 matrix into a sequence of
    * transformations: scale (X,Y,Z), shear (XY,XZ,YZ), rotate (X,Y,Z),
    * translation (X,Y,Z), perspective (X,Y,Z,W). Used with MatrixDecompose.
  }
  TTransformations = array [TTransType] of Single;

  {
    * A compressed rotation matrix stored as three 16‑bit integers.
    * This packs a 4×4 rotation matrix into 6 bytes, achieving a high compression
    * ratio with minimal loss of precision (typically < 0.01% deviation).
    * See PackRotationMatrix and UnPackRotationMatrix.
  }
  TPackedRotationMatrix = array [0 .. 2] of SmallInt;

const
  // ---- TexPoint constants ----
  XTexPoint: TTexPoint = (s: 1; t: 0);
  YTexPoint: TTexPoint = (s: 0; t: 1);
  XYTexPoint: TTexPoint = (s: 1; t: 1);
  NullTexPoint: TTexPoint = (s: 0; t: 0);
  MidTexPoint: TTexPoint = (s: 0.5; t: 0.5);

  // ---- Standard 3D axis vectors ----
  XVector: TAffineVector = (1, 0, 0);
  YVector: TAffineVector = (0, 1, 0);
  ZVector: TAffineVector = (0, 0, 1);
  XYVector: TAffineVector = (1, 1, 0);
  XZVector: TAffineVector = (1, 0, 1);
  YZVector: TAffineVector = (0, 1, 1);
  XYZVector: TAffineVector = (1, 1, 1);
  NullVector: TAffineVector = (0, 0, 0);
  MinusXVector: TAffineVector = (-1, 0, 0);
  MinusYVector: TAffineVector = (0, -1, 0);
  MinusZVector: TAffineVector = (0, 0, -1);

  // ---- Standard homogeneous vectors (direction, w=0) ----
  XHmgVector: THomogeneousVector = (1, 0, 0, 0);
  YHmgVector: THomogeneousVector = (0, 1, 0, 0);
  ZHmgVector: THomogeneousVector = (0, 0, 1, 0);
  WHmgVector: THomogeneousVector = (0, 0, 0, 1);
  XYHmgVector: THomogeneousVector = (1, 1, 0, 0);
  YZHmgVector: THomogeneousVector = (0, 1, 1, 0);
  XZHmgVector: THomogeneousVector = (1, 0, 1, 0);
  XYZHmgVector: THomogeneousVector = (1, 1, 1, 0);
  XYZWHmgVector: THomogeneousVector = (1, 1, 1, 1);
  NullHmgVector: THomogeneousVector = (0, 0, 0, 0);

  // ---- Standard homogeneous points (w=1) ----
  XHmgPoint: THomogeneousVector = (1, 0, 0, 1);
  YHmgPoint: THomogeneousVector = (0, 1, 0, 1);
  ZHmgPoint: THomogeneousVector = (0, 0, 1, 1);
  WHmgPoint: THomogeneousVector = (0, 0, 0, 1);
  NullHmgPoint: THomogeneousVector = (0, 0, 0, 1);

  // ---- Identity matrices ----
  IdentityMatrix: TAffineMatrix =
    ((1, 0, 0),
    (0, 1, 0),
    (0, 0, 1));
  IdentityHmgMatrix: TMatrix =
    ((1, 0, 0, 0),
    (0, 1, 0, 0),
    (0, 0, 1, 0),
    (0, 0, 0, 1));
  EmptyMatrix: TAffineMatrix =
    ((0, 0, 0),
    (0, 0, 0),
    (0, 0, 0));
  EmptyHmgMatrix: TMatrix =
    ((0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0));

  // ---- Quaternion identity ----
  IdentityQuaternion: TQuaternion = (RealPart: 1; ImagPart: (0, 0, 0));

  // ---- Small tolerance values ----
  Epsilon: Single = 1E-40; { Used for very small comparisons. }
  EPSILON2: Single = 1E-30; { A slightly larger tolerance for general use. }

  // ---- Mathematical constants ----
  cPI: Single = 3.141592654;
  cPIdiv180: Single = 0.017453292;
  c180divPI: Single = 57.29577951;
  c2PI: Single = 6.283185307;
  cPIdiv2: Single = 1.570796326;
  cPIdiv4: Single = 0.785398163;
  c3PIdiv2: Single = 4.71238898;
  c3PIdiv4: Single = 2.35619449;
  cInv2PI: Single = 1 / 6.283185307;
  cInv360: Single = 1 / 360;
  c180: Single = 180;
  c360: Single = 360;
  cOneHalf: Single = 0.5;
  cLn10: Single = 2.302585093;

  // ---- IEEE floating-point ranges (compatible with Math.pas) ----
  MinSingle = 1.5E-45;
  MaxSingle = 3.4E+38;
  MinDouble = 5.0E-324;
  MaxDouble = 1.7E+308;
  MinComp = -9.223372036854775807E+18;
  MaxComp = 9.223372036854775807E+18;

  CColinearBias = 1E-8; { Tolerance for colinearity tests. }
  cZero: Single = 0.0;
  cOne: Single = 1.0;
  cOneDotFive: Single = 0.5;
  cEpsilon: Single = 1E-10;

  { ---------------------------------------------------------------------------- }
  { Vector functions }
  { ---------------------------------------------------------------------------- }

  {
    * Creates a TTexPoint from (s, t) coordinates.
    * @param s The S (horizontal) texture coordinate.
    * @param t The T (vertical) texture coordinate.
    * @return A TTexPoint record.
  }
function TexPointMake(const s, t: Single): TTexPoint;

{
  * Creates a TAffineVector from three components.
  * @param x,y,z The three coordinates.
  * @return A 3‑component vector.
}
function AffineVectorMake(const x, y, Z: Single): TAffineVector; overload;

{
  * Extracts the affine (x,y,z) part from a homogeneous vector (w ignored).
  * @param v The homogeneous vector.
  * @return The 3‑component affine vector.
}
function AffineVectorMake(const v: TVector): TAffineVector; overload;

{
  * Sets the components of an existing TAffineVector.
  * @param out v The vector to modify.
  * @param x,y,z The new values.
}
procedure SetAffineVector(out v: TAffineVector; const x, y, Z: Single); overload;

{ Overloads of SetVector for convenience. }
procedure SetVector(out v: TAffineVector; const x, y, Z: Single); overload;
procedure SetVector(out v: TAffineVector; const vSrc: TVector); overload;
procedure SetVector(out v: TAffineVector; const vSrc: TAffineVector); overload;

{
  * Creates a homogeneous vector from an affine vector and an optional w component.
  * @param v The affine vector (x,y,z).
  * @param w The w component (default 0, i.e., a direction vector).
  * @return The homogeneous vector.
}
function VectorMake(const v: TAffineVector; w: Single = 0): TVector; overload;

{
  * Creates a homogeneous vector from four scalars.
}
function VectorMake(const x, y, Z: Single; w: Single = 0): TVector; overload;

{
  * Creates a homogeneous point (w=1) from three scalars.
}
function PointMake(const x, y, Z: Single): TVector; overload;
function PointMake(const v: TAffineVector): TVector; overload;
function PointMake(const v: TVector): TVector; overload;

{
  * Sets the components of an existing homogeneous vector.
}
procedure SetVector(out v: TVector; const x, y, Z: Single; w: Single = 0); overload;
procedure SetVector(out v: TVector; const av: TAffineVector; w: Single = 0); overload;
procedure SetVector(out v: TVector; const vSrc: TVector); overload;

{
  * Makes a homogeneous point (w=1) from three scalars.
}
procedure MakePoint(out v: TVector; const x, y, Z: Single); overload;
procedure MakePoint(out v: TVector; const av: TAffineVector); overload;
procedure MakePoint(out v: TVector; const av: TVector); overload;

{
  * Makes a direction vector (w=0) from components.
}
procedure MakeVector(out v: TAffineVector; const x, y, Z: Single); overload;
procedure MakeVector(out v: TVector; const x, y, Z: Single); overload;
procedure MakeVector(out v: TVector; const av: TAffineVector); overload;
procedure MakeVector(out v: TVector; const av: TVector); overload;

{
  * Resets a vector to zero.
}
procedure RstVector(var v: TAffineVector); overload;
procedure RstVector(var v: TVector); overload;

{
  * Compares two TVector2f for exact equality.
}
function VectorEquals(const v1, v2: TVector2f): Boolean; overload;

{
  * Compares two TMatrix3f for exact equality.
}
function MatrixEquals(const Matrix1, Matrix2: TMatrix3f): Boolean; overload;

{
  * Compares two TMatrix4f for exact equality.
}
function MatrixEquals(const Matrix1, Matrix2: TMatrix4f): Boolean; overload;

{
  * Creates a TVector2f from two scalars.
}
function Vector2fMake(const x, y: Single): TVector2f; overload;
function Vector2fMake(const Vector: TVector3f): TVector2f; overload;
function Vector2fMake(const Vector: TVector4f): TVector2f; overload;

{
  * Creates a TVector3f from scalars (defaults for y,z).
}
function Vector3fMake(const x: Single; const y: Single = 0; const Z: Single = 0): TVector3f; overload;
function Vector3fMake(const Vector: TVector2f; const Z: Single = 0): TVector3f; overload;
function Vector3fMake(const Vector: TVector4f): TVector3f; overload;

{
  * Creates a TVector4f from scalars (defaults for y,z,w).
}
function Vector4fMake(const x: Single; const y: Single = 0; const Z: Single = 0; const w: Single = 0): TVector4f; overload;
function Vector4fMake(const Vector: TVector3f; const w: Single = 0): TVector4f; overload;
function Vector4fMake(const Vector: TVector2f; const Z: Single = 0; const w: Single = 0): TVector4f; overload;

{ -------- Comparison functions: vector vs vector -------- }
function VectorMoreThen(const SourceVector, ComparedVector: TVector3f): Boolean; overload;
function VectorMoreEqualThen(const SourceVector, ComparedVector: TVector3f): Boolean; overload;
function VectorLessThen(const SourceVector, ComparedVector: TVector3f): Boolean; overload;
function VectorLessEqualThen(const SourceVector, ComparedVector: TVector3f): Boolean; overload;

function VectorMoreThen(const SourceVector, ComparedVector: TVector4f): Boolean; overload;
function VectorMoreEqualThen(const SourceVector, ComparedVector: TVector4f): Boolean; overload;
function VectorLessThen(const SourceVector, ComparedVector: TVector4f): Boolean; overload;
function VectorLessEqualThen(const SourceVector, ComparedVector: TVector4f): Boolean; overload;

{ -------- Comparison functions: vector vs scalar -------- }
function VectorMoreThen(const SourceVector: TVector3f; const ComparedNumber: Single): Boolean; overload;
function VectorMoreEqualThen(const SourceVector: TVector3f; const ComparedNumber: Single): Boolean; overload;
function VectorLessThen(const SourceVector: TVector3f; const ComparedNumber: Single): Boolean; overload;
function VectorLessEqualThen(const SourceVector: TVector3f; const ComparedNumber: Single): Boolean; overload;

function VectorMoreThen(const SourceVector: TVector4f; const ComparedNumber: Single): Boolean; overload;
function VectorMoreEqualThen(const SourceVector: TVector4f; const ComparedNumber: Single): Boolean; overload;
function VectorLessThen(const SourceVector: TVector4f; const ComparedNumber: Single): Boolean; overload;
function VectorLessEqualThen(const SourceVector: TVector4f; const ComparedNumber: Single): Boolean; overload;

{ -------- Vector arithmetic -------- }
function VectorAdd(const v1, v2: TVector2f): TVector2f; overload;
function VectorAdd(const v1, v2: TAffineVector): TAffineVector; overload;
procedure VectorAdd(const v1, v2: TAffineVector; var vr: TAffineVector); overload;
procedure VectorAdd(const v1, v2: TAffineVector; vr: PAffineVector); overload;
function VectorAdd(const v1, v2: TVector): TVector; overload;
procedure VectorAdd(const v1, v2: TVector; var vr: TVector); overload;
function VectorAdd(const v: TAffineVector; const f: Single): TAffineVector; overload;
function VectorAdd(const v: TVector; const f: Single): TVector; overload;
procedure AddVector(var v1: TAffineVector; const v2: TAffineVector); overload;
procedure AddVector(var v1: TAffineVector; const v2: TVector); overload;
procedure AddVector(var v1: TVector; const v2: TVector); overload;
procedure AddVector(var v: TAffineVector; const f: Single); overload;
procedure AddVector(var v: TVector; const f: Single); overload;
procedure AddPoint(var v1: TVector; const v2: TVector); overload;
function PointAdd(var v1: TVector; const v2: TVector): TVector; overload;

{ -------- Vector array operations -------- }
procedure TexPointArrayAdd(const Src: PTexPointArray; const Delta: TTexPoint; const nb: Integer; dest: PTexPointArray); overload;
procedure TexPointArrayScaleAndAdd(const Src: PTexPointArray; const Delta: TTexPoint; const nb: Integer; const Scale: TTexPoint; dest: PTexPointArray); overload;
procedure VectorArrayAdd(const Src: PAffineVectorArray; const Delta: TAffineVector; const nb: Integer; dest: PAffineVectorArray); overload;

{ -------- Vector subtraction -------- }
function VectorSubtract(const v1, v2: TVector2f): TVector2f; overload;
procedure SubtractVector(var v1: TVector2f; const v2: TVector2f); overload;
function VectorSubtract(const v1, v2: TAffineVector): TAffineVector; overload;
procedure VectorSubtract(const v1, v2: TAffineVector; var Result: TAffineVector); overload;
procedure VectorSubtract(const v1, v2: TAffineVector; var Result: TVector); overload;
procedure VectorSubtract(const v1: TVector; v2: TAffineVector; var Result: TVector); overload;
function VectorSubtract(const v1, v2: TVector): TVector; overload;
procedure VectorSubtract(const v1, v2: TVector; var Result: TVector); overload;
procedure VectorSubtract(const v1, v2: TVector; var Result: TAffineVector); overload;
function VectorSubtract(const v1: TAffineVector; Delta: Single): TAffineVector; overload;
function VectorSubtract(const v1: TVector; Delta: Single): TVector; overload;
procedure SubtractVector(var v1: TAffineVector; const v2: TAffineVector); overload;
procedure SubtractVector(var v1: TVector; const v2: TVector); overload;

{ -------- Linear combinations -------- }
procedure CombineVector(var vr: TAffineVector; const v: TAffineVector; var f: Single); overload;
procedure CombineVector(var vr: TAffineVector; const v: TAffineVector; pf: PFloat); overload;
function TexPointCombine(const t1, t2: TTexPoint; f1, f2: Single): TTexPoint;
function VectorCombine(const v1, v2: TAffineVector; const f1, f2: Single): TAffineVector; overload;
function VectorCombine3(const v1, v2, v3: TAffineVector; const f1, f2, F3: Single): TAffineVector; overload;
procedure VectorCombine3(const v1, v2, v3: TAffineVector; const f1, f2, F3: Single; var vr: TAffineVector); overload;
procedure CombineVector(var vr: TVector; const v: TVector; var f: Single); overload;
procedure CombineVector(var vr: TVector; const v: TAffineVector; var f: Single); overload;
function VectorCombine(const v1, v2: TVector; const f1, f2: Single): TVector; overload;
function VectorCombine(const v1: TVector; const v2: TAffineVector; const f1, f2: Single): TVector; overload;
procedure VectorCombine(const v1: TVector; const v2: TAffineVector; const f1, f2: Single; var vr: TVector); overload;
procedure VectorCombine(const v1, v2: TVector; const f1, f2: Single; var vr: TVector); overload;
procedure VectorCombine(const v1, v2: TVector; const f2: Single; var vr: TVector); overload;
function VectorCombine3(const v1, v2, v3: TVector; const f1, f2, F3: Single): TVector; overload;
procedure VectorCombine3(const v1, v2, v3: TVector; const f1, f2, F3: Single; var vr: TVector); overload;

{ -------- Dot and cross products -------- }
function VectorDotProduct(const v1, v2: TVector2f): Single; overload;
function VectorDotProduct(const v1, v2: TAffineVector): Single; overload;
function VectorDotProduct(const v1, v2: TVector): Single; overload;
function VectorDotProduct(const v1: TVector; const v2: TAffineVector): Single; overload;

function PointProject(const p, origin, direction: TAffineVector): Single; overload;
function PointProject(const p, origin, direction: TVector): Single; overload;

function VectorCrossProduct(const v1, v2: TAffineVector): TAffineVector; overload;
function VectorCrossProduct(const v1, v2: TVector): TVector; overload;
procedure VectorCrossProduct(const v1, v2: TVector; var vr: TVector); overload;
procedure VectorCrossProduct(const v1, v2: TAffineVector; var vr: TVector); overload;
procedure VectorCrossProduct(const v1, v2: TVector; var vr: TAffineVector); overload;
procedure VectorCrossProduct(const v1, v2: TAffineVector; var vr: TAffineVector); overload;

{ -------- Interpolation -------- }
function Lerp(const Start, stop, t: Single): Single;
function AngleLerp(Start, stop, t: Single): Single;
function MatrixLerp(const m1, m2: TMatrix; const Delta: Single): TMatrix;
function DistanceBetweenAngles(angle1, angle2: Single): Single;
function TexPointLerp(const t1, t2: TTexPoint; t: Single): TTexPoint; overload;
function VectorLerp(const v1, v2: TAffineVector; t: Single): TAffineVector; overload;
procedure VectorLerp(const v1, v2: TAffineVector; t: Single; var vr: TAffineVector); overload;
function VectorLerp(const v1, v2: TVector; t: Single): TVector; overload;
procedure VectorLerp(const v1, v2: TVector; t: Single; var vr: TVector); overload;
function VectorAngleLerp(const v1, v2: TAffineVector; t: Single): TAffineVector; overload;
function VectorAngleCombine(const v1, v2: TAffineVector; f: Single): TAffineVector; overload;

procedure VectorArrayLerp(const src1, src2: PVectorArray; t: Single; n: Integer; dest: PVectorArray); overload;
procedure VectorArrayLerp(const src1, src2: PAffineVectorArray; t: Single; n: Integer; dest: PAffineVectorArray); overload;
procedure VectorArrayLerp(const src1, src2: PTexPointArray; t: Single; n: Integer; dest: PTexPointArray); overload;


type
  TGLInterpolationType = (itLinear, itPower, itSin, itSinAlt, itTan, itLn, itExp);

  { -------- Easing functions -------- }
function InterpolatePower(const Start, stop, Delta: Single; const DistortionDegree: Single): Single;
function InterpolateLn(const Start, stop, Delta: Single; const DistortionDegree: Single): Single;
function InterpolateExp(const Start, stop, Delta: Single; const DistortionDegree: Single): Single;
function InterpolateSin(const Start, stop, Delta: Single): Single;
function InterpolateTan(const Start, stop, Delta: Single): Single;
function InterpolateSinAlt(const Start, stop, Delta: Single): Single;
function InterpolateCombinedFastPower(const OriginalStart, OriginalStop, OriginalCurrent: Single;
  const TargetStart, TargetStop: Single; const DistortionDegree: Single): Single;
function InterpolateCombinedSafe(const OriginalStart, OriginalStop, OriginalCurrent: Single;
  const TargetStart, TargetStop: Single; const DistortionDegree: Single; const InterpolationType: TGLInterpolationType): Single;
function InterpolateCombinedFast(const OriginalStart, OriginalStop, OriginalCurrent: Single;
  const TargetStart, TargetStop: Single; const DistortionDegree: Single; const InterpolationType: TGLInterpolationType): Single;
function InterpolateCombined(const Start, stop, Delta: Single;
  const DistortionDegree: Single; const InterpolationType: TGLInterpolationType): Single;

{ -------- Length, norm, normalization -------- }
function VectorLength(const x, y: Single): Single; overload;
function VectorLength(const x, y, Z: Single): Single; overload;
function VectorLength(const v: TVector2f): Single; overload;
function VectorLength(const v: TAffineVector): Single; overload;
function VectorLength(const v: TVector): Single; overload;
function VectorLength(const v: array of Single): Single; overload;

function VectorNorm(const x, y: Single): Single; overload;
function VectorNorm(const v: TAffineVector): Single; overload;
function VectorNorm(const v: TVector): Single; overload;
function VectorNorm(var v: array of Single): Single; overload;

procedure NormalizeVector(var v: TVector2f); overload;
procedure NormalizeVector(var v: TAffineVector); overload;
procedure NormalizeVector(var v: TVector); overload;
function VectorNormalize(const v: TVector2f): TVector2f; overload;
function VectorNormalize(const v: TAffineVector): TAffineVector; overload;
function VectorNormalize(const v: TVector): TVector; overload;
procedure NormalizeVectorArray(List: PAffineVectorArray; n: Integer); overload;

function VectorAngleCosine(const v1, v2: TAffineVector): Single; overload;
function VectorAngleCosine(const v1, v2: TVector): Single; overload;

function VectorNegate(const v: TAffineVector): TAffineVector; overload;
function VectorNegate(const v: TVector): TVector; overload;
procedure NegateVector(var v: TAffineVector); overload;
procedure NegateVector(var v: TVector); overload;
procedure NegateVector(var v: array of Single); overload;

procedure ScaleVector(var v: TVector2f; factor: Single); overload;
procedure ScaleVector(var v: TAffineVector; factor: Single); overload;
procedure ScaleVector(var v: TAffineVector; const factor: TAffineVector); overload;
procedure ScaleVector(var v: TVector; factor: Single); overload;
procedure ScaleVector(var v: TVector; const factor: TVector); overload;

function VectorScale(const v: TVector2f; factor: Single): TVector2f; overload;
function VectorScale(const v: TAffineVector; factor: Single): TAffineVector; overload;
procedure VectorScale(const v: TAffineVector; factor: Single; var vr: TAffineVector); overload;
function VectorScale(const v: TVector; factor: Single): TVector; overload;
procedure VectorScale(const v: TVector; factor: Single; var vr: TVector); overload;
procedure VectorScale(const v: TVector; factor: Single; var vr: TAffineVector); overload;
function VectorScale(const v: TAffineVector; const factor: TAffineVector): TAffineVector; overload;
function VectorScale(const v: TVector; const factor: TVector): TVector; overload;

procedure DivideVector(var v: TVector; const divider: TVector); overload;
procedure DivideVector(var v: TAffineVector; const divider: TAffineVector); overload;
function VectorDivide(const v: TVector; const divider: TVector): TVector; overload;
function VectorDivide(const v: TAffineVector; const divider: TAffineVector): TAffineVector; overload;

function TexpointEquals(const p1, p2: TTexPoint): Boolean;
function VectorEquals(const v1, v2: TVector): Boolean; overload;
function VectorEquals(const v1, v2: TAffineVector): Boolean; overload;
function AffineVectorEquals(const v1, v2: TVector): Boolean; overload;
function VectorIsNull(const v: TVector): Boolean; overload;
function VectorIsNull(const v: TAffineVector): Boolean; overload;

function VectorSpacing(const v1, v2: TTexPoint): Single; overload;
function VectorSpacing(const v1, v2: TAffineVector): Single; overload;
function VectorSpacing(const v1, v2: TVector): Single; overload;

function VectorDistance(const v1, v2: TAffineVector): Single; overload;
function VectorDistance(const v1, v2: TVector): Single; overload;
function VectorDistance2(const v1, v2: TAffineVector): Single; overload;
function VectorDistance2(const v1, v2: TVector): Single; overload;

function VectorPerpendicular(const v, n: TAffineVector): TAffineVector;
function VectorReflect(const v, n: TAffineVector): TAffineVector;
procedure RotateVector(var Vector: TVector; const axis: TAffineVector; angle: Single); overload;
procedure RotateVector(var Vector: TVector; const axis: TVector; angle: Single); overload;
procedure RotateVectorAroundY(var v: TAffineVector; alpha: Single);
function VectorRotateAroundX(const v: TAffineVector; alpha: Single): TAffineVector; overload;
function VectorRotateAroundY(const v: TAffineVector; alpha: Single): TAffineVector; overload;
procedure VectorRotateAroundY(const v: TAffineVector; alpha: Single; var vr: TAffineVector); overload;
function VectorRotateAroundZ(const v: TAffineVector; alpha: Single): TAffineVector; overload;

procedure AbsVector(var v: TVector); overload;
procedure AbsVector(var v: TAffineVector); overload;
function VectorAbs(const v: TVector): TVector; overload;
function VectorAbs(const v: TAffineVector): TAffineVector; overload;

function IsColinear(const v1, v2: TVector2f): Boolean; overload;
function IsColinear(const v1, v2: TAffineVector): Boolean; overload;
function IsColinear(const v1, v2: TVector): Boolean; overload;

{ ---------------------------------------------------------------------------- }
{ Matrix functions }
{ ---------------------------------------------------------------------------- }

procedure SetMatrix(var dest: TAffineMatrix; const Src: TMatrix); overload;
procedure SetMatrix(var dest: TMatrix; const Src: TAffineMatrix); overload;
procedure SetMatrixRow(var dest: TMatrix; rowNb: Integer; const aRow: TVector); overload;

function CreateScaleMatrix(const v: TAffineVector): TMatrix; overload;
function CreateScaleMatrix(const v: TVector): TMatrix; overload;
function CreateTranslationMatrix(const v: TAffineVector): TMatrix; overload;
function CreateTranslationMatrix(const v: TVector): TMatrix; overload;
function CreateScaleAndTranslationMatrix(const Scale, Offset: TVector): TMatrix; overload;
function CreateRotationMatrixX(const sine, cosine: Single): TMatrix; overload;
function CreateRotationMatrixX(const angle: Single): TMatrix; overload;
function CreateRotationMatrixY(const sine, cosine: Single): TMatrix; overload;
function CreateRotationMatrixY(const angle: Single): TMatrix; overload;
function CreateRotationMatrixZ(const sine, cosine: Single): TMatrix; overload;
function CreateRotationMatrixZ(const angle: Single): TMatrix; overload;
function CreateRotationMatrix(const anAxis: TAffineVector; angle: Single): TMatrix; overload;
function CreateRotationMatrix(const anAxis: TVector; angle: Single): TMatrix; overload;
function CreateAffineRotationMatrix(const anAxis: TAffineVector; angle: Single): TAffineMatrix;

function MatrixMultiply(const m1, m2: TAffineMatrix): TAffineMatrix; overload;
function MatrixMultiply(const m1, m2: TMatrix): TMatrix; overload;
procedure MatrixMultiply(const m1, m2: TMatrix; var MResult: TMatrix); overload;

function VectorTransform(const v: TVector; const M: TMatrix): TVector; overload;
function VectorTransform(const v: TVector; const M: TAffineMatrix): TVector; overload;
function VectorTransform(const v: TAffineVector; const M: TMatrix): TAffineVector; overload;
function VectorTransform(const v: TAffineVector; const M: TAffineMatrix): TAffineVector; overload;

function MatrixDeterminant(const M: TAffineMatrix): Single; overload;
function MatrixDeterminant(const M: TMatrix): Single; overload;

procedure AdjointMatrix(var M: TMatrix); overload;
procedure AdjointMatrix(var M: TAffineMatrix); overload;

procedure ScaleMatrix(var M: TAffineMatrix; const factor: Single); overload;
procedure ScaleMatrix(var M: TMatrix; const factor: Single); overload;

procedure TranslateMatrix(var M: TMatrix; const v: TAffineVector); overload;
procedure TranslateMatrix(var M: TMatrix; const v: TVector); overload;

procedure NormalizeMatrix(var M: TMatrix);

procedure TransposeMatrix(var M: TAffineMatrix); overload;
procedure TransposeMatrix(var M: TMatrix); overload;

procedure InvertMatrix(var M: TMatrix); overload;
function MatrixInvert(const M: TMatrix): TMatrix; overload;
procedure InvertMatrix(var M: TAffineMatrix); overload;
function MatrixInvert(const M: TAffineMatrix): TAffineMatrix; overload;

procedure transpose_scale_m33(const Src: TMatrix; var dest: TMatrix; var Scale: Single);
function AnglePreservingMatrixInvert(const mat: TMatrix): TMatrix;

function MatrixDecompose(const M: TMatrix; var Tran: TTransformations): Boolean;

function CreateLookAtMatrix(const eye, center, normUp: TVector): TMatrix;
function CreateMatrixFromFrustum(Left, Right, Bottom, Top, ZNear, ZFar: Single): TMatrix;
function CreatePerspectiveMatrix(FOV, Aspect, ZNear, ZFar: Single): TMatrix;
function CreateOrthoMatrix(Left, Right, Bottom, Top, ZNear, ZFar: Single): TMatrix;
function CreatePickMatrix(x, y, deltax, deltay: Single; const viewport: TVector4i): TMatrix;
function Project(objectVector: TVector; const ViewProjMatrix: TMatrix; const viewport: TVector4i; out WindowVector: TVector): Boolean;
function UnProject(WindowVector: TVector; ViewProjMatrix: TMatrix; const viewport: TVector4i; out objectVector: TVector): Boolean;

{ ---------------------------------------------------------------------------- }
{ Plane functions }
{ ---------------------------------------------------------------------------- }

function PlaneMake(const p1, p2, p3: TAffineVector): THmgPlane; overload;
function PlaneMake(const p1, p2, p3: TVector): THmgPlane; overload;
function PlaneMake(const Point, normal: TAffineVector): THmgPlane; overload;
function PlaneMake(const Point, normal: TVector): THmgPlane; overload;
procedure NormalizePlane(var plane: THmgPlane);

function PlaneEvaluatePoint(const plane: THmgPlane; const Point: TAffineVector): Single; overload;
function PlaneEvaluatePoint(const plane: THmgPlane; const Point: TVector): Single; overload;

function CalcPlaneNormal(const p1, p2, p3: TAffineVector): TAffineVector; overload;
procedure CalcPlaneNormal(const p1, p2, p3: TAffineVector; var vr: TAffineVector); overload;
procedure CalcPlaneNormal(const p1, p2, p3: TVector; var vr: TAffineVector); overload;

function PointIsInHalfSpace(const Point, planePoint, planeNormal: TVector): Boolean; overload;
function PointIsInHalfSpace(const Point, planePoint, planeNormal: TAffineVector): Boolean; overload;
function PointIsInHalfSpace(const Point: TAffineVector; plane: THmgPlane): Boolean; overload;

function PointPlaneDistance(const Point, planePoint, planeNormal: TVector): Single; overload;
function PointPlaneDistance(const Point, planePoint, planeNormal: TAffineVector): Single; overload;
function PointPlaneDistance(const Point: TAffineVector; plane: THmgPlane): Single; overload;

function PointPlaneOrthoProjection(const Point: TAffineVector; const plane: THmgPlane; var inter: TAffineVector; bothface: Boolean): Boolean;
function PointPlaneProjection(const Point, direction: TAffineVector; const plane: THmgPlane; var inter: TAffineVector; bothface: Boolean): Boolean;

function SegmentPlaneIntersection(const ptA, ptB: TAffineVector; const plane: THmgPlane; var inter: TAffineVector): Boolean;

function PointTriangleOrthoProjection(const Point, ptA, ptB, ptC: TAffineVector; var inter: TAffineVector; bothface: Boolean): Boolean;
function PointTriangleProjection(const Point, direction, ptA, ptB, ptC: TAffineVector; var inter: TAffineVector; bothface: Boolean): Boolean;
function IsLineIntersectTriangle(const Point, direction, ptA, ptB, ptC: TAffineVector): Boolean;

function PointQuadOrthoProjection(const Point, ptA, ptB, ptC, ptD: TAffineVector; var inter: TAffineVector; bothface: Boolean): Boolean;
function PointQuadProjection(const Point, direction, ptA, ptB, ptC, ptD: TAffineVector; var inter: TAffineVector; bothface: Boolean): Boolean;
function IsLineIntersectQuad(const Point, direction, ptA, ptB, ptC, ptD: TAffineVector): Boolean;

function PointDiskOrthoProjection(const Point, center, up: TAffineVector; const radius: Single; var inter: TAffineVector; bothface: Boolean): Boolean;
function PointDiskProjection(const Point, direction, center, up: TAffineVector; const radius: Single; var inter: TAffineVector; bothface: Boolean): Boolean;

function PointSegmentClosestPoint(const Point, segmentStart, segmentStop: TAffineVector): TAffineVector; overload;
function PointSegmentClosestPoint(const Point, segmentStart, segmentStop: TVector): TVector; overload;
function PointSegmentDistance(const Point, segmentStart, segmentStop: TAffineVector): Single;

function PointLineClosestPoint(const Point, linePoint, lineDirection: TAffineVector): TAffineVector;
function PointLineDistance(const Point, linePoint, lineDirection: TAffineVector): Single;

procedure SegmentSegmentClosestPoint(const S0Start, S0Stop, S1Start, S1Stop: TAffineVector;
  var Segment0Closest, Segment1Closest: TAffineVector);
function SegmentSegmentDistance(const S0Start, S0Stop, S1Start, S1Stop: TAffineVector): Single;
function LineLineDistance(const linePt0, lineDir0, linePt1, lineDir1: TAffineVector): Single;

{ ---------------------------------------------------------------------------- }
{ Quaternion functions }
{ ---------------------------------------------------------------------------- }

type
  TEulerOrder = (eulXYZ, eulXZY, eulYXZ, eulYZX, eulZXY, eulZYX);

function QuaternionMake(const Imag: array of Single; Real: Single): TQuaternion;
function QuaternionConjugate(const q: TQuaternion): TQuaternion;
function QuaternionMagnitude(const q: TQuaternion): Single;
procedure NormalizeQuaternion(var q: TQuaternion);

function QuaternionFromPoints(const v1, v2: TAffineVector): TQuaternion;
procedure QuaternionToPoints(const q: TQuaternion; var ArcFrom, ArcTo: TAffineVector);
function QuaternionFromMatrix(const mat: TMatrix): TQuaternion;
function QuaternionToMatrix(quat: TQuaternion): TMatrix;
function QuaternionToAffineMatrix(quat: TQuaternion): TAffineMatrix;
function QuaternionFromAngleAxis(const angle: Single; const axis: TAffineVector): TQuaternion;
function QuaternionFromRollPitchYaw(const r, p, y: Single): TQuaternion;
function QuaternionFromEuler(const x, y, Z: Single; eulerOrder: TEulerOrder): TQuaternion;

function QuaternionMultiply(const qL, qR: TQuaternion): TQuaternion;
function QuaternionSlerp(const QStart, QEnd: TQuaternion; Spin: Integer; t: Single): TQuaternion; overload;
function QuaternionSlerp(const Source, dest: TQuaternion; const t: Single): TQuaternion; overload;

function IsNan(const Value_: Single): Boolean; overload;
function IsNan(const Value_: Double): Boolean; overload;

{ ---------------------------------------------------------------------------- }
{ Logarithmic and exponential functions }
{ ---------------------------------------------------------------------------- }

function LnXP1_(x: Double): Double;
function Log10_(x: Double): Double;
function Log2_(x: Double): Double; overload;
function Log2_(x: Single): Single; overload;
function LogN_(Base, x: Double): Double;
function IntPower_(Base: Double; Exponent: Integer): Double;
function Power_(const Base, Exponent: Single): Single; overload;
function Power_(Base: Single; Exponent: Integer): Single; overload;
function Power_(Base: Single; Exponent: Int64): Single; overload;

{ ---------------------------------------------------------------------------- }
{ Trigonometric functions }
{ ---------------------------------------------------------------------------- }

function DegToRad_(const Degrees: Double): Double; overload;
function DegToRad_(const Degrees: Single): Single; overload;
function RadToDeg_(const Radians: Double): Double; overload;
function RadToDeg_(const Radians: Single): Single; overload;

function NormalizeAngle(angle: Single): Single;
function NormalizeDegAngle(angle: Single): Single;

procedure SinCos_(const Theta: Double; out Sin, Cos: Double); overload;
procedure SinCos_(const Theta: Single; out Sin, Cos: Single); overload;
procedure SinCos_(const Theta, radius: Double; out Sin, Cos: Double); overload;
procedure SinCos_(const Theta, radius: Single; out Sin, Cos: Single); overload;
procedure PrepareSinCosCache(var s, c: array of Single; startAngle, stopAngle: Single);

function ArcCos_(const x: Double): Double; overload;
function ArcCos_(const x: Single): Single; overload;
function ArcSin_(const x: Double): Double; overload;
function ArcSin_(const x: Single): Single; overload;
function ArcTan2_(const y, x: Double): Double; overload;
function ArcTan2_(const y, x: Single): Single; overload;
function FastArcTan2(y, x: Single): Single;

function Tan_(const x: Double): Double; overload;
function Tan_(const x: Single): Single; overload;
function CoTan_(const x: Double): Double; overload;
function CoTan_(const x: Single): Single; overload;

{ ---------------------------------------------------------------------------- }
{ Hyperbolic functions }
{ ---------------------------------------------------------------------------- }
function Sinh(const x: Single): Single; overload;
function Sinh(const x: Double): Double; overload;
function Cosh(const x: Single): Single; overload;
function Cosh(const x: Double): Double; overload;

{ ---------------------------------------------------------------------------- }
{ Miscellaneous math functions }
{ ---------------------------------------------------------------------------- }

function RSqrt(v: Single): Single;
function RLength(x, y: Single): Single;
function ISqrt(i: Integer): Integer;
function ILength(x, y: Integer): Integer; overload;
function ILength(x, y, Z: Integer): Integer; overload;

procedure RandomPointOnSphere(var p: TAffineVector);

function RoundInt(v: Single): Single; overload;
function RoundInt(v: Double): Double; overload;

function Trunc(x: Double): Int64;
function Round(x: Double): Int64;
function Frac(x: Double): Double;

function Ceil(v: Single): Integer; overload;
function Ceil64(v: Double): Int64; overload;
function Floor(v: Single): Integer; overload;
function Floor64(v: Double): Int64; overload;

function ScaleAndRound(i: Integer; var s: Single): Integer;

function Sign(x: Single): Integer;
function SignStrict(x: Single): Integer;

function IsInRange(const x, a, b: Single): Boolean; overload;
function IsInRange(const x, a, b: Double): Boolean; overload;

function IsInCube(const p, d: TAffineVector): Boolean; overload;
function IsInCube(const p, d: TVector): Boolean; overload;

function MinFloat(values: PSingleArray; nbItems: Integer): Single; overload;
function MinFloat(values: PDoubleArray; nbItems: Integer): Double; overload;
function MinFloat(const v1, v2: Single): Single; overload;
function MinFloat(const v: array of Single): Single; overload;
function MinFloat(const v1, v2: Double): Double; overload;
function MinFloat(const v1, v2, v3: Single): Single; overload;
function MinFloat(const v1, v2, v3: Double): Double; overload;

function MaxFloat(values: PSingleArray; nbItems: Integer): Single; overload;
function MaxFloat(values: PDoubleArray; nbItems: Integer): Double; overload;
function MaxFloat(const v: array of Single): Single; overload;
function MaxFloat(const v1, v2: Single): Single; overload;
function MaxFloat(const v1, v2: Double): Double; overload;
function MaxFloat(const v1, v2, v3: Single): Single; overload;
function MaxFloat(const v1, v2, v3: Double): Double; overload;

function MinInteger(const v1, v2: Integer): Integer; overload;
function MinInteger(const v1, v2: Cardinal): Cardinal; overload;
function MinInteger(const v1, v2, v3: Integer): Integer; overload;
function MinInteger(const v1, v2, v3: Cardinal): Cardinal; overload;

function MaxInteger(const v1, v2: Integer): Integer; overload;
function MaxInteger(const v1, v2: Cardinal): Cardinal; overload;
function MaxInteger(const v1, v2, v3: Integer): Integer; overload;
function MaxInteger(const v1, v2, v3: Cardinal): Cardinal; overload;

function ClampInteger(const Value, Min_, Max_: Integer): Integer; overload;
function ClampInteger(const Value, Min_, Max_: Cardinal): Cardinal; overload;

function TriangleArea(const p1, p2, p3: TAffineVector): Single; overload;
function PolygonArea(const p: PAffineVectorArray; nSides: Integer): Single; overload;
function TriangleSignedArea(const p1, p2, p3: TAffineVector): Single; overload;
function PolygonSignedArea(const p: PAffineVectorArray; nSides: Integer): Single; overload;

procedure ScaleFloatArray(values: PSingleArray; nb: Integer; var factor: Single); overload;
procedure ScaleFloatArray(var values: TSingleArray; factor: Single); overload;
procedure OffsetFloatArray(values: PSingleArray; nb: Integer; var Delta: Single); overload;
procedure OffsetFloatArray(var values: array of Single; Delta: Single); overload;
procedure OffsetFloatArray(valuesDest, valuesDelta: PSingleArray; nb: Integer); overload;

function MaxXYZComponent(const v: TVector): Single; overload;
function MaxXYZComponent(const v: TAffineVector): Single; overload;
function MinXYZComponent(const v: TVector): Single; overload;
function MinXYZComponent(const v: TAffineVector): Single; overload;
function MaxAbsXYZComponent(v: TVector): Single;
function MinAbsXYZComponent(v: TVector): Single;

procedure MaxVector(var v: TVector; const v1: TVector); overload;
procedure MaxVector(var v: TAffineVector; const v1: TAffineVector); overload;
procedure MinVector(var v: TVector; const v1: TVector); overload;
procedure MinVector(var v: TAffineVector; const v1: TAffineVector); overload;

procedure SortArrayAscending(var a: array of Double);

function ClampValue(const Value_, Min_, Max_: Single): Single; overload;
function ClampValue(const Value_, Min_: Single): Single; overload;

function ConvertRotation(const Angles: TAffineVector): TVector;

function PointInPolygon(var xp, yp: array of Single; x, y: Single): Boolean;

procedure DivMod(Dividend: Integer; Divisor: Word; var Result, Remainder: Word);

{ ---------------------------------------------------------------------------- }
{ Coordinate system manipulation }
{ ---------------------------------------------------------------------------- }

function Turn(const Matrix: TMatrix; angle: Single): TMatrix; overload;
function Turn(const Matrix: TMatrix; const MasterUp: TAffineVector; angle: Single): TMatrix; overload;
function Pitch(const Matrix: TMatrix; angle: Single): TMatrix; overload;
function Pitch(const Matrix: TMatrix; const MasterRight: TAffineVector; angle: Single): TMatrix; overload;
function Roll(const Matrix: TMatrix; angle: Single): TMatrix; overload;
function Roll(const Matrix: TMatrix; const MasterDirection: TAffineVector; angle: Single): TMatrix; overload;

{ ---------------------------------------------------------------------------- }
{ Intersection functions }
{ ---------------------------------------------------------------------------- }

function IntersectLinePlane(const Point, direction: TVector; const plane: THmgPlane; intersectPoint: PVector = nil): Integer; overload;

function IntersectTriangleBox(const p1, p2, p3, aMinExtent, aMaxExtent: TAffineVector): Boolean;

function IntersectSphereBox(
  const SpherePos: TVector; const SphereRadius: Single; const BoxMatrix: TMatrix;
  const BoxScale: TAffineVector; intersectPoint: PAffineVector = nil; normal: PAffineVector = nil; Depth: PSingle = nil): Boolean;

function RayCastPlaneIntersect(const rayStart, rayVector: TVector; const planePoint, planeNormal: TVector; intersectPoint: PVector = nil): Boolean; overload;
function RayCastPlaneXZIntersect(const rayStart, rayVector: TVector; const planeY: Single; intersectPoint: PVector = nil): Boolean; overload;

function RayCastTriangleIntersect(const rayStart, rayVector: TVector; const p1, p2, p3: TAffineVector; intersectPoint: PVector = nil; intersectNormal: PVector = nil): Boolean; overload;
function RayCastMinDistToPoint(const rayStart, rayVector: TVector; const Point: TVector): Single;
function RayCastIntersectsSphere(const rayStart, rayVector: TVector; const sphereCenter: TVector; const SphereRadius: Single): Boolean; overload;
function RayCastSphereIntersect(const rayStart, rayVector: TVector; const sphereCenter: TVector; const SphereRadius: Single; var i1, i2: TVector): Integer; overload;
function RayCastBoxIntersect(const rayStart, rayVector, aMinExtent, aMaxExtent: TAffineVector; intersectPoint: PAffineVector = nil): Boolean;

function RectanglesIntersect(const CenterOfRect_1, CenterOfRect_2, SizeOfRect_1, SizeOfRect_2: TVector2f): Boolean;
function RectangleContains(const CenterOfBigRect_1, ACenterOfSmallRect2, SizeOfBigRect_1, SizeOfSmallRect_2: TVector2f; const Eps_: Single = 0.0): Boolean;

function SphereVisibleRadius(Distance, radius: Single): Single;
function ExtractFrustumFromModelViewProjection(const modelViewProj: TMatrix): TFrustum;

function IsVolumeClipped(const objPos: TAffineVector; const objRadius: Single; const Frustum: TFrustum): Boolean; overload;
function IsVolumeClipped(const objPos: TVector; const objRadius: Single; const Frustum: TFrustum): Boolean; overload;
function IsVolumeClipped(const Min_, Max_: TAffineVector; const Frustum: TFrustum): Boolean; overload;

function MakeParallelProjectionMatrix(const plane: THmgPlane; const dir: TVector): TMatrix;
function MakeShadowMatrix(const planePoint, planeNormal, lightPos: TVector): TMatrix;
function MakeReflectionMatrix(const planePoint, planeNormal: TAffineVector): TMatrix;

function PackRotationMatrix(const mat: TMatrix): TPackedRotationMatrix;
function UnPackRotationMatrix(const packedMatrix: TPackedRotationMatrix): TMatrix;

function BarycentricCoordinates(const v1, v2, v3, p: TAffineVector; var u, v: Single): Boolean;

function MoveObjectAround(const MovingObjectPosition_, MovingObjectUp_, TargetPosition_: TVector; pitchDelta, turnDelta: Single): TVector;

function AngleBetweenVectors(const a, b, ACenterPoint: TVector): Single; overload;
function AngleBetweenVectors(const a, b, ACenterPoint: TAffineVector): Single; overload;

function ShiftObjectFromCenter(const OriginalPosition_: TVector; const Center_: TVector; const Distance_: Single; const FromCenterSpot_: Boolean): TVector; overload;
function ShiftObjectFromCenter(const OriginalPosition_: TAffineVector; const Center_: TAffineVector; const Distance_: Single; const FromCenterSpot_: Boolean): TAffineVector; overload;


implementation

uses Z.Core, Math;

const
  // to be used as descriptive indices
  x = 0;
  y = 1;
  Z = 2;
  w = 3;

  // ------------------------------------------------------------------------------
  // ----------------- vector functions -------------------------------------------
  // ------------------------------------------------------------------------------

  // TexPointMake
  //
function TexPointMake(const s, t: Single): TTexPoint;
begin
  Result.s := s;
  Result.t := t;
end;

// AffineVectorMake
//
function AffineVectorMake(const x, y, Z: Single): TAffineVector; overload;
begin
  Result[0] := x;
  Result[1] := y;
  Result[2] := Z;
end;

// AffineVectorMake
//
function AffineVectorMake(const v: TVector): TAffineVector;
begin
  Result[0] := v[0];
  Result[1] := v[1];
  Result[2] := v[2];
end;

// SetAffineVector
//
procedure SetAffineVector(out v: TAffineVector; const x, y, Z: Single); overload;
begin
  v[0] := x;
  v[1] := y;
  v[2] := Z;
end;

// SetVector (affine)
//
procedure SetVector(out v: TAffineVector; const x, y, Z: Single);
begin
  v[0] := x;
  v[1] := y;
  v[2] := Z;
end;

// SetVector (affine-hmg)
//
procedure SetVector(out v: TAffineVector; const vSrc: TVector);
begin
  v[0] := vSrc[0];
  v[1] := vSrc[1];
  v[2] := vSrc[2];
end;

// SetVector (affine-affine)
//
procedure SetVector(out v: TAffineVector; const vSrc: TAffineVector);
begin
  v[0] := vSrc[0];
  v[1] := vSrc[1];
  v[2] := vSrc[2];
end;

// VectorMake
//
function VectorMake(const v: TAffineVector; w: Single = 0): TVector;
begin
  Result[0] := v[0];
  Result[1] := v[1];
  Result[2] := v[2];
  Result[3] := w;
end;

// VectorMake
//
function VectorMake(const x, y, Z: Single; w: Single = 0): TVector;
begin
  Result[0] := x;
  Result[1] := y;
  Result[2] := Z;
  Result[3] := w;
end;

// PointMake (xyz)
//
function PointMake(const x, y, Z: Single): TVector; overload;
begin
  Result[0] := x;
  Result[1] := y;
  Result[2] := Z;
  Result[3] := 1;
end;

// PointMake (affine)
//
function PointMake(const v: TAffineVector): TVector; overload;
begin
  Result[0] := v[0];
  Result[1] := v[1];
  Result[2] := v[2];
  Result[3] := 1;
end;

// PointMake (hmg)
//
function PointMake(const v: TVector): TVector; overload;
begin
  Result[0] := v[0];
  Result[1] := v[1];
  Result[2] := v[2];
  Result[3] := 1;
end;

// SetVector
//
procedure SetVector(out v: TVector; const x, y, Z: Single; w: Single = 0);
begin
  v[0] := x;
  v[1] := y;
  v[2] := Z;
  v[3] := w;
end;

// SetVector
//
procedure SetVector(out v: TVector; const av: TAffineVector; w: Single = 0);
begin
  v[0] := av[0];
  v[1] := av[1];
  v[2] := av[2];
  v[3] := w;
end;

// SetVector
//
procedure SetVector(out v: TVector; const vSrc: TVector);
begin
  // faster than memcpy, move or ':=' on the TVector...
  v[0] := vSrc[0];
  v[1] := vSrc[1];
  v[2] := vSrc[2];
  v[3] := vSrc[3];
end;

// MakePoint
//
procedure MakePoint(out v: TVector; const x, y, Z: Single);
begin
  v[0] := x;
  v[1] := y;
  v[2] := Z;
  v[3] := 1;
end;

// MakePoint
//
procedure MakePoint(out v: TVector; const av: TAffineVector);
begin
  v[0] := av[0];
  v[1] := av[1];
  v[2] := av[2];
  v[3] := 1;
end;

// MakePoint
//
procedure MakePoint(out v: TVector; const av: TVector);
begin
  v[0] := av[0];
  v[1] := av[1];
  v[2] := av[2];
  v[3] := 1;
end;

// MakeVector
//
procedure MakeVector(out v: TAffineVector; const x, y, Z: Single); overload;
begin
  v[0] := x;
  v[1] := y;
  v[2] := Z;
end;

// MakeVector
//
procedure MakeVector(out v: TVector; const x, y, Z: Single);
begin
  v[0] := x;
  v[1] := y;
  v[2] := Z;
  v[3] := 0;
end;

// MakeVector
//
procedure MakeVector(out v: TVector; const av: TAffineVector);
begin
  v[0] := av[0];
  v[1] := av[1];
  v[2] := av[2];
  v[3] := 0;
end;

// MakeVector
//
procedure MakeVector(out v: TVector; const av: TVector);
begin
  v[0] := av[0];
  v[1] := av[1];
  v[2] := av[2];
  v[3] := 0;
end;

// RstVector (affine)
//
procedure RstVector(var v: TAffineVector);
begin
  v[0] := 0;
  v[1] := 0;
  v[2] := 0;
end;

// RstVector (hmg)
//
procedure RstVector(var v: TVector);
begin
  v[0] := 0;
  v[1] := 0;
  v[2] := 0;
  v[3] := 0;
end;

// VectorAdd (func)
//
function VectorAdd(const v1, v2: TVector2f): TVector2f;
begin
  Result[0] := v1[0] + v2[0];
  Result[1] := v1[1] + v2[1];
end;

// VectorAdd (func, affine)
//
function VectorAdd(const v1, v2: TAffineVector): TAffineVector;
begin
  Result[0] := v1[0] + v2[0];
  Result[1] := v1[1] + v2[1];
  Result[2] := v1[2] + v2[2];
end;

// VectorAdd (proc, affine)
//
procedure VectorAdd(const v1, v2: TAffineVector; var vr: TAffineVector); overload;
begin
  vr[0] := v1[0] + v2[0];
  vr[1] := v1[1] + v2[1];
  vr[2] := v1[2] + v2[2];
end;

// VectorAdd (proc, affine)
//
procedure VectorAdd(const v1, v2: TAffineVector; vr: PAffineVector); overload;
begin
  vr^[0] := v1[0] + v2[0];
  vr^[1] := v1[1] + v2[1];
  vr^[2] := v1[2] + v2[2];
end;

// VectorAdd (hmg)
//
function VectorAdd(const v1, v2: TVector): TVector;
begin
  Result[0] := v1[0] + v2[0];
  Result[1] := v1[1] + v2[1];
  Result[2] := v1[2] + v2[2];
  Result[3] := v1[3] + v2[3];
end;

// VectorAdd (hmg, proc)
//
procedure VectorAdd(const v1, v2: TVector; var vr: TVector);
begin
  vr[0] := v1[0] + v2[0];
  vr[1] := v1[1] + v2[1];
  vr[2] := v1[2] + v2[2];
  vr[3] := v1[3] + v2[3];
end;

// VectorAdd (affine, Single)
//
function VectorAdd(const v: TAffineVector; const f: Single): TAffineVector;
begin
  Result[0] := v[0] + f;
  Result[1] := v[1] + f;
  Result[2] := v[2] + f;
end;

// VectorAdd (hmg, Single)
//
function VectorAdd(const v: TVector; const f: Single): TVector;
begin
  Result[0] := v[0] + f;
  Result[1] := v[1] + f;
  Result[2] := v[2] + f;
  Result[3] := v[3] + f;
end;

// PointAdd (hmg, W = 1)
//
function PointAdd(var v1: TVector; const v2: TVector): TVector;
begin
  Result[0] := v1[0] + v2[0];
  Result[1] := v1[1] + v2[1];
  Result[2] := v1[2] + v2[2];
  Result[3] := 1;
end;

// AddVector (affine)
//
procedure AddVector(var v1: TAffineVector; const v2: TAffineVector);
begin
  v1[0] := v1[0] + v2[0];
  v1[1] := v1[1] + v2[1];
  v1[2] := v1[2] + v2[2];
end;

// AddVector (affine)
//
procedure AddVector(var v1: TAffineVector; const v2: TVector);
begin
  v1[0] := v1[0] + v2[0];
  v1[1] := v1[1] + v2[1];
  v1[2] := v1[2] + v2[2];
end;

// AddVector (hmg)
//
procedure AddVector(var v1: TVector; const v2: TVector);
begin
  v1[0] := v1[0] + v2[0];
  v1[1] := v1[1] + v2[1];
  v1[2] := v1[2] + v2[2];
  v1[3] := v1[3] + v2[3];
end;

// AddVector (affine)
//
procedure AddVector(var v: TAffineVector; const f: Single);
begin
  v[0] := v[0] + f;
  v[1] := v[1] + f;
  v[2] := v[2] + f;
end;

// AddVector (hmg)
//
procedure AddVector(var v: TVector; const f: Single);
begin
  v[0] := v[0] + f;
  v[1] := v[1] + f;
  v[2] := v[2] + f;
  v[3] := v[3] + f;
end;

// AddPoint (hmg, W = 1)
//
procedure AddPoint(var v1: TVector; const v2: TVector);
begin
  v1[0] := v1[0] + v2[0];
  v1[1] := v1[1] + v2[1];
  v1[2] := v1[2] + v2[2];
  v1[3] := 1;
end;

// TexPointArrayAdd
//
procedure TexPointArrayAdd(const Src: PTexPointArray; const Delta: TTexPoint;
  const nb: Integer;
  dest: PTexPointArray); overload;
var
  i: Integer;
begin
  for i := 0 to nb - 1 do
    begin
      dest^[i].s := Src^[i].s + Delta.s;
      dest^[i].t := Src^[i].t + Delta.t;
    end;
end;

// TexPointArrayScaleAndAdd
//
procedure TexPointArrayScaleAndAdd(const Src: PTexPointArray; const Delta: TTexPoint;
  const nb: Integer; const Scale: TTexPoint;
  dest: PTexPointArray); overload;
var
  i: Integer;
begin
  for i := 0 to nb - 1 do
    begin
      dest^[i].s := Src^[i].s * Scale.s + Delta.s;
      dest^[i].t := Src^[i].t * Scale.t + Delta.t;
    end;
end;

// VectorArrayAdd
//
procedure VectorArrayAdd(const Src: PAffineVectorArray; const Delta: TAffineVector;
  const nb: Integer; dest: PAffineVectorArray);
var
  i: Integer;
begin
  for i := 0 to nb - 1 do
    begin
      dest^[i][0] := Src^[i][0] + Delta[0];
      dest^[i][1] := Src^[i][1] + Delta[1];
      dest^[i][2] := Src^[i][2] + Delta[2];
    end;
end;

// VectorSubtract (func, affine)
//
function VectorSubtract(const v1, v2: TAffineVector): TAffineVector;
begin
  Result[0] := v1[0] - v2[0];
  Result[1] := v1[1] - v2[1];
  Result[2] := v1[2] - v2[2];
end;

// VectorSubtract (func, 2f)
//
function VectorSubtract(const v1, v2: TVector2f): TVector2f;
begin
  Result[0] := v1[0] - v2[0];
  Result[1] := v1[1] - v2[1];
end;

// VectorSubtract (proc, affine)
//
procedure VectorSubtract(const v1, v2: TAffineVector; var Result: TAffineVector);
begin
  Result[0] := v1[0] - v2[0];
  Result[1] := v1[1] - v2[1];
  Result[2] := v1[2] - v2[2];
end;

// VectorSubtract (proc, affine-hmg)
//
procedure VectorSubtract(const v1, v2: TAffineVector; var Result: TVector);
begin
  Result[0] := v1[0] - v2[0];
  Result[1] := v1[1] - v2[1];
  Result[2] := v1[2] - v2[2];
  Result[3] := 0;
end;

// VectorSubtract
//
procedure VectorSubtract(const v1: TVector; v2: TAffineVector; var Result: TVector);
begin
  Result[0] := v1[0] - v2[0];
  Result[1] := v1[1] - v2[1];
  Result[2] := v1[2] - v2[2];
  Result[3] := v1[0];
end;

// VectorSubtract (hmg)
//
function VectorSubtract(const v1, v2: TVector): TVector;
begin
  Result[0] := v1[0] - v2[0];
  Result[1] := v1[1] - v2[1];
  Result[2] := v1[2] - v2[2];
  Result[3] := v1[3] - v2[3];
end;

// VectorSubtract (proc, hmg)
//
procedure VectorSubtract(const v1, v2: TVector; var Result: TVector);
begin
  Result[0] := v1[0] - v2[0];
  Result[1] := v1[1] - v2[1];
  Result[2] := v1[2] - v2[2];
  Result[3] := v1[3] - v2[3];
end;

// VectorSubtract (proc, affine)
//
procedure VectorSubtract(const v1, v2: TVector; var Result: TAffineVector); overload;
begin
  Result[0] := v1[0] - v2[0];
  Result[1] := v1[1] - v2[1];
  Result[2] := v1[2] - v2[2];
end;

// VectorSubtract (affine, Single)
//
function VectorSubtract(const v1: TAffineVector; Delta: Single): TAffineVector;
begin
  Result[0] := v1[0] - Delta;
  Result[1] := v1[1] - Delta;
  Result[2] := v1[2] - Delta;
end;

// VectorSubtract (hmg, Single)
//
function VectorSubtract(const v1: TVector; Delta: Single): TVector;
begin
  Result[0] := v1[0] - Delta;
  Result[1] := v1[1] - Delta;
  Result[2] := v1[2] - Delta;
  Result[3] := v1[3] - Delta;
end;

// SubtractVector (affine)
//
procedure SubtractVector(var v1: TAffineVector; const v2: TAffineVector);
begin
  v1[0] := v1[0] - v2[0];
  v1[1] := v1[1] - v2[1];
  v1[2] := v1[2] - v2[2];
end;

// SubtractVector (2f)
//
procedure SubtractVector(var v1: TVector2f; const v2: TVector2f);
begin
  v1[0] := v1[0] - v2[0];
  v1[1] := v1[1] - v2[1];
end;

// SubtractVector (hmg)
//
procedure SubtractVector(var v1: TVector; const v2: TVector);
begin
  v1[0] := v1[0] - v2[0];
  v1[1] := v1[1] - v2[1];
  v1[2] := v1[2] - v2[2];
  v1[3] := v1[3] - v2[3];
end;

// CombineVector (var)
//
procedure CombineVector(var vr: TAffineVector; const v: TAffineVector; var f: Single);
begin
  vr[0] := vr[0] + v[0] * f;
  vr[1] := vr[1] + v[1] * f;
  vr[2] := vr[2] + v[2] * f;
end;

// CombineVector (pointer)
//
procedure CombineVector(var vr: TAffineVector; const v: TAffineVector; pf: PFloat);
begin
  vr[0] := vr[0] + v[0] * pf^;
  vr[1] := vr[1] + v[1] * pf^;
  vr[2] := vr[2] + v[2] * pf^;
end;

// TexPointCombine
//
function TexPointCombine(const t1, t2: TTexPoint; f1, f2: Single): TTexPoint;
begin
  Result.s := (f1 * t1.s) + (f2 * t2.s);
  Result.t := (f1 * t1.t) + (f2 * t2.t);
end;

// VectorCombine
//
function VectorCombine(const v1, v2: TAffineVector; const f1, f2: Single): TAffineVector;
begin
  Result[x] := (f1 * v1[x]) + (f2 * v2[x]);
  Result[y] := (f1 * v1[y]) + (f2 * v2[y]);
  Result[Z] := (f1 * v1[Z]) + (f2 * v2[Z]);
end;

// VectorCombine3 (func)
//
function VectorCombine3(const v1, v2, v3: TAffineVector; const f1, f2, F3: Single): TAffineVector;
begin
  Result[x] := (f1 * v1[x]) + (f2 * v2[x]) + (F3 * v3[x]);
  Result[y] := (f1 * v1[y]) + (f2 * v2[y]) + (F3 * v3[y]);
  Result[Z] := (f1 * v1[Z]) + (f2 * v2[Z]) + (F3 * v3[Z]);
end;

// VectorCombine3 (vector)
//
procedure VectorCombine3(const v1, v2, v3: TAffineVector; const f1, f2, F3: Single; var vr: TAffineVector);
begin
  vr[x] := (f1 * v1[x]) + (f2 * v2[x]) + (F3 * v3[x]);
  vr[y] := (f1 * v1[y]) + (f2 * v2[y]) + (F3 * v3[y]);
  vr[Z] := (f1 * v1[Z]) + (f2 * v2[Z]) + (F3 * v3[Z]);
end;

// CombineVector
//
procedure CombineVector(var vr: TVector; const v: TVector; var f: Single); overload;
begin
  vr[0] := vr[0] + v[0] * f;
  vr[1] := vr[1] + v[1] * f;
  vr[2] := vr[2] + v[2] * f;
  vr[3] := vr[3] + v[3] * f;
end;

// CombineVector
//
procedure CombineVector(var vr: TVector; const v: TAffineVector; var f: Single); overload;
begin
  vr[0] := vr[0] + v[0] * f;
  vr[1] := vr[1] + v[1] * f;
  vr[2] := vr[2] + v[2] * f;
end;

// VectorCombine
//
function VectorCombine(const v1, v2: TVector; const f1, f2: Single): TVector;
begin
  Result[x] := (f1 * v1[x]) + (f2 * v2[x]);
  Result[y] := (f1 * v1[y]) + (f2 * v2[y]);
  Result[Z] := (f1 * v1[Z]) + (f2 * v2[Z]);
  Result[w] := (f1 * v1[w]) + (f2 * v2[w]);
end;

// VectorCombine
//
function VectorCombine(const v1: TVector; const v2: TAffineVector; const f1, f2: Single): TVector; overload;
begin
  Result[x] := (f1 * v1[x]) + (f2 * v2[x]);
  Result[y] := (f1 * v1[y]) + (f2 * v2[y]);
  Result[Z] := (f1 * v1[Z]) + (f2 * v2[Z]);
  Result[w] := f1 * v1[w];
end;

// VectorCombine
//
procedure VectorCombine(const v1, v2: TVector; const f1, f2: Single; var vr: TVector); overload;
begin
  vr[0] := (f1 * v1[0]) + (f2 * v2[0]);
  vr[1] := (f1 * v1[1]) + (f2 * v2[1]);
  vr[2] := (f1 * v1[2]) + (f2 * v2[2]);
  vr[3] := (f1 * v1[3]) + (f2 * v2[3]);
end;

// VectorCombine (F1=1.0)
//
procedure VectorCombine(const v1, v2: TVector; const f2: Single; var vr: TVector); overload;
begin
  vr[0] := v1[0] + (f2 * v2[0]);
  vr[1] := v1[1] + (f2 * v2[1]);
  vr[2] := v1[2] + (f2 * v2[2]);
  vr[3] := v1[3] + (f2 * v2[3]);
end;

// VectorCombine
//
procedure VectorCombine(const v1: TVector; const v2: TAffineVector; const f1, f2: Single; var vr: TVector);
begin
  vr[x] := (f1 * v1[x]) + (f2 * v2[x]);
  vr[y] := (f1 * v1[y]) + (f2 * v2[y]);
  vr[Z] := (f1 * v1[Z]) + (f2 * v2[Z]);
  vr[w] := f1 * v1[w];
end;

// VectorCombine3
//
function VectorCombine3(const v1, v2, v3: TVector; const f1, f2, F3: Single): TVector;
begin
  Result[x] := (f1 * v1[x]) + (f2 * v2[x]) + (F3 * v3[x]);
  Result[y] := (f1 * v1[y]) + (f2 * v2[y]) + (F3 * v3[y]);
  Result[Z] := (f1 * v1[Z]) + (f2 * v2[Z]) + (F3 * v3[Z]);
  Result[w] := (f1 * v1[w]) + (f2 * v2[w]) + (F3 * v3[w]);
end;

// VectorCombine3
//
procedure VectorCombine3(const v1, v2, v3: TVector; const f1, f2, F3: Single; var vr: TVector);
begin
  vr[x] := (f1 * v1[x]) + (f2 * v2[x]) + (F3 * v3[x]);
  vr[y] := (f1 * v1[y]) + (f2 * v2[y]) + (F3 * v3[y]);
  vr[Z] := (f1 * v1[Z]) + (f2 * v2[Z]) + (F3 * v3[Z]);
  vr[w] := (f1 * v1[w]) + (f2 * v2[w]) + (F3 * v3[w]);
end;

// VectorDotProduct (2f)
//
function VectorDotProduct(const v1, v2: TVector2f): Single;
begin
  Result := v1[0] * v2[0] + v1[1] * v2[1];
end;

// VectorDotProduct (affine)
//
function VectorDotProduct(const v1, v2: TAffineVector): Single;
begin
  Result := v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
end;

// VectorDotProduct (hmg)
//
function VectorDotProduct(const v1, v2: TVector): Single;
begin
  Result := v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3];
end;

// VectorDotProduct
//
function VectorDotProduct(const v1: TVector; const v2: TAffineVector): Single;
begin
  Result := v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
end;

// PointProject (affine)
//
function PointProject(const p, origin, direction: TAffineVector): Single;
begin
  Result := direction[0] * (p[0] - origin[0])
    + direction[1] * (p[1] - origin[1])
    + direction[2] * (p[2] - origin[2]);
end;

// PointProject (vector)
//
function PointProject(const p, origin, direction: TVector): Single;
begin
  Result := direction[0] * (p[0] - origin[0])
    + direction[1] * (p[1] - origin[1])
    + direction[2] * (p[2] - origin[2]);
end;

// VectorCrossProduct
//
function VectorCrossProduct(const v1, v2: TAffineVector): TAffineVector;
begin
  Result[x] := v1[y] * v2[Z] - v1[Z] * v2[y];
  Result[y] := v1[Z] * v2[x] - v1[x] * v2[Z];
  Result[Z] := v1[x] * v2[y] - v1[y] * v2[x];
end;

// VectorCrossProduct
//
function VectorCrossProduct(const v1, v2: TVector): TVector;
begin
  Result[x] := v1[y] * v2[Z] - v1[Z] * v2[y];
  Result[y] := v1[Z] * v2[x] - v1[x] * v2[Z];
  Result[Z] := v1[x] * v2[y] - v1[y] * v2[x];
  Result[w] := 0;
end;

// VectorCrossProduct
//
procedure VectorCrossProduct(const v1, v2: TVector; var vr: TVector);
begin
  vr[x] := v1[y] * v2[Z] - v1[Z] * v2[y];
  vr[y] := v1[Z] * v2[x] - v1[x] * v2[Z];
  vr[Z] := v1[x] * v2[y] - v1[y] * v2[x];
  vr[w] := 0;
end;

// VectorCrossProduct
//
procedure VectorCrossProduct(const v1, v2: TAffineVector; var vr: TVector); overload;
begin
  vr[x] := v1[y] * v2[Z] - v1[Z] * v2[y];
  vr[y] := v1[Z] * v2[x] - v1[x] * v2[Z];
  vr[Z] := v1[x] * v2[y] - v1[y] * v2[x];
  vr[w] := 0;
end;

// VectorCrossProduct
//
procedure VectorCrossProduct(const v1, v2: TVector; var vr: TAffineVector); overload;
begin
  vr[x] := v1[y] * v2[Z] - v1[Z] * v2[y];
  vr[y] := v1[Z] * v2[x] - v1[x] * v2[Z];
  vr[Z] := v1[x] * v2[y] - v1[y] * v2[x];
end;

// VectorCrossProduct
//
procedure VectorCrossProduct(const v1, v2: TAffineVector; var vr: TAffineVector); overload;
begin
  vr[x] := v1[y] * v2[Z] - v1[Z] * v2[y];
  vr[y] := v1[Z] * v2[x] - v1[x] * v2[Z];
  vr[Z] := v1[x] * v2[y] - v1[y] * v2[x];
end;

// Lerp
//
function Lerp(const Start, stop, t: Single): Single;
begin
  Result := Start + (stop - Start) * t;
end;

// Angle Lerp
//
function AngleLerp(Start, stop, t: Single): Single;
var
  d: Single;
begin
  Start := NormalizeAngle(Start);
  stop := NormalizeAngle(stop);
  d := stop - Start;
  if d > pi then
    begin
      // positive d, angle on opposite side, becomes negative i.e. changes direction
      d := -d - c2PI;
    end
  else if d < -pi then
    begin
      // negative d, angle on opposite side, becomes positive i.e. changes direction
      d := d + c2PI;
    end;
  Result := Start + d * t;
end;

// DistanceBetweenAngles
//
function DistanceBetweenAngles(angle1, angle2: Single): Single;
begin
  angle1 := NormalizeAngle(angle1);
  angle2 := NormalizeAngle(angle2);
  Result := Abs(angle2 - angle1);
  if Result > pi then
      Result := c2PI - Result;
end;

// TexPointLerp
//
function TexPointLerp(const t1, t2: TTexPoint; t: Single): TTexPoint; overload;
begin
  Result.s := t1.s + (t2.s - t1.s) * t;
  Result.t := t1.t + (t2.t - t1.t) * t;
end;

// VectorAffineLerp
//
function VectorLerp(const v1, v2: TAffineVector; t: Single): TAffineVector;
begin
  Result[x] := v1[x] + (v2[x] - v1[x]) * t;
  Result[y] := v1[y] + (v2[y] - v1[y]) * t;
  Result[Z] := v1[Z] + (v2[Z] - v1[Z]) * t;
end;

// VectorLerp
//
procedure VectorLerp(const v1, v2: TAffineVector; t: Single; var vr: TAffineVector);
begin
  vr[x] := v1[x] + (v2[x] - v1[x]) * t;
  vr[y] := v1[y] + (v2[y] - v1[y]) * t;
  vr[Z] := v1[Z] + (v2[Z] - v1[Z]) * t;
end;

// VectorLerp
//
function VectorLerp(const v1, v2: TVector; t: Single): TVector;
begin
  Result[x] := v1[x] + (v2[x] - v1[x]) * t;
  Result[y] := v1[y] + (v2[y] - v1[y]) * t;
  Result[Z] := v1[Z] + (v2[Z] - v1[Z]) * t;
  Result[w] := v1[w] + (v2[w] - v1[w]) * t;
end;

// VectorLerp
//
procedure VectorLerp(const v1, v2: TVector; t: Single; var vr: TVector);
begin
  vr[x] := v1[x] + (v2[x] - v1[x]) * t;
  vr[y] := v1[y] + (v2[y] - v1[y]) * t;
  vr[Z] := v1[Z] + (v2[Z] - v1[Z]) * t;
  vr[w] := v1[w] + (v2[w] - v1[w]) * t;
end;

// VectorAngleLerp
//
function VectorAngleLerp(const v1, v2: TAffineVector; t: Single): TAffineVector;
var
  q1, q2, qR: TQuaternion;
  M: TMatrix;
  Tran: TTransformations;
begin
  if VectorEquals(v1, v2) then
    begin
      Result := v1;
    end
  else
    begin
      q1 := QuaternionFromEuler(RadToDeg_(v1[0]), RadToDeg_(v1[1]), RadToDeg_(v1[2]), eulZYX);
      q2 := QuaternionFromEuler(RadToDeg_(v2[0]), RadToDeg_(v2[1]), RadToDeg_(v2[2]), eulZYX);
      qR := QuaternionSlerp(q1, q2, t);
      M := QuaternionToMatrix(qR);
      MatrixDecompose(M, Tran);
      Result[0] := Tran[ttRotateX];
      Result[1] := Tran[ttRotateY];
      Result[2] := Tran[ttRotateZ];
    end;
end;

// VectorAngleCombine
//
function VectorAngleCombine(const v1, v2: TAffineVector; f: Single): TAffineVector;
begin
  Result := VectorCombine(v1, v2, 1, f);
end;

// VectorArrayLerp (hmg)
//
procedure VectorArrayLerp(const src1, src2: PVectorArray; t: Single; n: Integer; dest: PVectorArray);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    begin
      dest^[i][0] := src1^[i][0] + (src2^[i][0] - src1^[i][0]) * t;
      dest^[i][1] := src1^[i][1] + (src2^[i][1] - src1^[i][1]) * t;
      dest^[i][2] := src1^[i][2] + (src2^[i][2] - src1^[i][2]) * t;
      dest^[i][3] := src1^[i][3] + (src2^[i][3] - src1^[i][3]) * t;
    end;
end;

// VectorArrayLerp (affine)
//
procedure VectorArrayLerp(const src1, src2: PAffineVectorArray; t: Single; n: Integer; dest: PAffineVectorArray);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    begin
      dest^[i][0] := src1^[i][0] + (src2^[i][0] - src1^[i][0]) * t;
      dest^[i][1] := src1^[i][1] + (src2^[i][1] - src1^[i][1]) * t;
      dest^[i][2] := src1^[i][2] + (src2^[i][2] - src1^[i][2]) * t;
    end;
end;

procedure VectorArrayLerp(const src1, src2: PTexPointArray; t: Single; n: Integer; dest: PTexPointArray);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    begin
      dest^[i].s := src1^[i].s + (src2^[i].s - src1^[i].s) * t;
      dest^[i].t := src1^[i].t + (src2^[i].t - src1^[i].t) * t;
    end;
end;

// InterpolateCombined
//
function InterpolateCombined(const Start, stop, Delta: Single; const DistortionDegree: Single; const InterpolationType: TGLInterpolationType): Single;
begin
  case InterpolationType of
    itLinear: Result := Lerp(Start, stop, Delta);
    itPower: Result := InterpolatePower(Start, stop, Delta, DistortionDegree);
    itSin: Result := InterpolateSin(Start, stop, Delta);
    itSinAlt: Result := InterpolateSinAlt(Start, stop, Delta);
    itTan: Result := InterpolateTan(Start, stop, Delta);
    itLn: Result := InterpolateLn(Start, stop, Delta, DistortionDegree);
    itExp: Result := InterpolateExp(Start, stop, Delta, DistortionDegree);
    else
      begin
        Result := -1;
        Assert(False);
      end;
  end;
end;

// InterpolateCombinedFastPower
//
function InterpolateCombinedFastPower(const OriginalStart, OriginalStop, OriginalCurrent: Single; const TargetStart, TargetStop: Single; const DistortionDegree: Single): Single;
begin
  Result := InterpolatePower(TargetStart, TargetStop, (OriginalCurrent - OriginalStart) / (OriginalStop - OriginalStart), DistortionDegree);
end;

// InterpolateCombinedSafe
//
function InterpolateCombinedSafe(const OriginalStart, OriginalStop, OriginalCurrent: Single; const TargetStart, TargetStop: Single; const DistortionDegree: Single; const InterpolationType: TGLInterpolationType): Single;
var
  ChangeDelta: Single;
begin
  if OriginalStop = OriginalStart then
      Result := TargetStart
  else
    begin
      ChangeDelta := (OriginalCurrent - OriginalStart) / (OriginalStop - OriginalStart);
      Result := InterpolateCombined(TargetStart, TargetStop, ChangeDelta, DistortionDegree, InterpolationType);
    end;
end;

// InterpolateCombinedFast
//
function InterpolateCombinedFast(const OriginalStart, OriginalStop, OriginalCurrent: Single; const TargetStart, TargetStop: Single; const DistortionDegree: Single; const InterpolationType: TGLInterpolationType): Single;
var
  ChangeDelta: Single;
begin
  ChangeDelta := (OriginalCurrent - OriginalStart) / (OriginalStop - OriginalStart);
  Result := InterpolateCombined(TargetStart, TargetStop, ChangeDelta, DistortionDegree, InterpolationType);
end;

// InterpolateLn
//
function InterpolateLn(const Start, stop, Delta: Single; const DistortionDegree: Single): Single;
begin
  Result := (stop - Start) * ln(1 + Delta * DistortionDegree) / ln(1 + DistortionDegree) + Start;
end;

// InterpolateExp
//
function InterpolateExp(const Start, stop, Delta: Single; const DistortionDegree: Single): Single;
begin
  Result := (stop - Start) * Exp(-DistortionDegree * (1 - Delta)) + Start;
end;

// InterpolateSinAlt
//
function InterpolateSinAlt(const Start, stop, Delta: Single): Single;
begin
  Result := (stop - Start) * Delta * Sin(Delta * pi / 2) + Start;
end;

// InterpolateSin
//
function InterpolateSin(const Start, stop, Delta: Single): Single;
begin
  Result := (stop - Start) * Sin(Delta * pi / 2) + Start;
end;

// InterpolateTan
//
function InterpolateTan(const Start, stop, Delta: Single): Single;
begin
  Result := (stop - Start) * Tan_(Delta * pi / 4) + Start;
end;

// InterpolatePower
//
function InterpolatePower(const Start, stop, Delta: Single; const DistortionDegree: Single): Single;
begin
  if (Round(DistortionDegree) <> DistortionDegree) and (Delta < 0) then
      Result := (stop - Start) * Power_(Delta, Round(DistortionDegree)) + Start
  else
      Result := (stop - Start) * Power_(Delta, DistortionDegree) + Start;
end;

// MatrixLerp
//
function MatrixLerp(const m1, m2: TMatrix; const Delta: Single): TMatrix;
var
  i, j: Integer;
begin
  for j := 0 to 3 do
    for i := 0 to 3 do
        Result[i][j] := m1[i][j] + (m2[i][j] - m1[i][j]) * Delta;
end;

// VectorLength (array)
//
function VectorLength(const v: array of Single): Single;
var
  i: Integer;
begin
  Result := 0;
  for i := low(v) to high(v) do
      Result := Result + Sqr(v[i]);
  Result := Sqrt(Result);
end;

// VectorLength  (x, y)
//
function VectorLength(const x, y: Single): Single;
begin
  Result := Sqrt(x * x + y * y);
end;

// VectorLength (x, y, z)
//
function VectorLength(const x, y, Z: Single): Single;
begin
  Result := Sqrt(x * x + y * y + Z * Z);
end;

// VectorLength
//
function VectorLength(const v: TVector2f): Single;
begin
  Result := Sqrt(VectorNorm(v[0], v[1]));
end;

// VectorLength
//
function VectorLength(const v: TAffineVector): Single;
begin
  Result := Sqrt(VectorNorm(v));
end;

// VectorLength
//
function VectorLength(const v: TVector): Single;
begin
  Result := Sqrt(VectorNorm(v));
end;

// VectorNorm
//
function VectorNorm(const x, y: Single): Single;
begin
  Result := Sqr(x) + Sqr(y);
end;

// VectorNorm (affine)
//
function VectorNorm(const v: TAffineVector): Single;
begin
  Result := v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
end;

// VectorNorm (hmg)
//
function VectorNorm(const v: TVector): Single;
begin
  Result := v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
end;

// VectorNorm
//
function VectorNorm(var v: array of Single): Single;
var
  i: Integer;
begin
  Result := 0;
  for i := low(v) to high(v) do
      Result := Result + v[i] * v[i];
end;

// NormalizeVector (2f)
//
procedure NormalizeVector(var v: TVector2f);
var
  InvLen: Single;
  vn: Single;
begin
  vn := VectorNorm(v);
  if vn > 0 then
    begin
      InvLen := RSqrt(vn);
      v[0] := v[0] * InvLen;
      v[1] := v[1] * InvLen;
    end;
end;

// NormalizeVector (affine)
//
procedure NormalizeVector(var v: TAffineVector);
var
  InvLen: Single;
  vn: Single;
begin
  vn := VectorNorm(v);
  if vn > 0 then
    begin
      InvLen := RSqrt(vn);
      v[0] := v[0] * InvLen;
      v[1] := v[1] * InvLen;
      v[2] := v[2] * InvLen;
    end;
end;

// VectorNormalize
//
function VectorNormalize(const v: TVector2f): TVector2f;
var
  InvLen: Single;
  vn: Single;
begin
  vn := VectorNorm(v[0], v[1]);
  if vn = 0 then
      Result := v
  else
    begin
      InvLen := RSqrt(vn);
      Result[0] := v[0] * InvLen;
      Result[1] := v[1] * InvLen;
    end;
end;

// VectorNormalize
//
function VectorNormalize(const v: TAffineVector): TAffineVector;
var
  InvLen: Single;
  vn: Single;
begin
  vn := VectorNorm(v);
  if vn = 0 then
      SetVector(Result, v)
  else
    begin
      InvLen := RSqrt(vn);
      Result[0] := v[0] * InvLen;
      Result[1] := v[1] * InvLen;
      Result[2] := v[2] * InvLen;
    end;
end;

// NormalizeVectorArray
//
procedure NormalizeVectorArray(List: PAffineVectorArray; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
      NormalizeVector(List^[i]);
end;

// NormalizeVector (hmg)
//
procedure NormalizeVector(var v: TVector);
var
  InvLen: Single;
  vn: Single;
begin
  vn := VectorNorm(v);
  if vn > 0 then
    begin
      InvLen := RSqrt(vn);
      v[0] := v[0] * InvLen;
      v[1] := v[1] * InvLen;
      v[2] := v[2] * InvLen;
    end;
  v[3] := 0;
end;

// VectorNormalize (hmg, func)
//
function VectorNormalize(const v: TVector): TVector;
var
  InvLen: Single;
  vn: Single;
begin
  vn := VectorNorm(v);
  if vn = 0 then
      SetVector(Result, v)
  else
    begin
      InvLen := RSqrt(vn);
      Result[0] := v[0] * InvLen;
      Result[1] := v[1] * InvLen;
      Result[2] := v[2] * InvLen;
    end;
  Result[3] := 0;
end;

// VectorAngleCosine
//
function VectorAngleCosine(const v1, v2: TAffineVector): Single;
begin
  Result := VectorDotProduct(v1, v2) / (VectorLength(v1) * VectorLength(v2));
end;

// VectorAngleCosine
//
function VectorAngleCosine(const v1, v2: TVector): Single;
begin
  Result := VectorDotProduct(v1, v2) / (VectorLength(v1) * VectorLength(v2));
end;

// VectorNegate (affine)
//
function VectorNegate(const v: TAffineVector): TAffineVector;
begin
  Result[0] := -v[0];
  Result[1] := -v[1];
  Result[2] := -v[2];
end;

// VectorNegate (hmg)
//
function VectorNegate(const v: TVector): TVector;
begin
  Result[0] := -v[0];
  Result[1] := -v[1];
  Result[2] := -v[2];
  Result[3] := -v[3];
end;

// NegateVector
//
procedure NegateVector(var v: TAffineVector);
begin
  v[0] := -v[0];
  v[1] := -v[1];
  v[2] := -v[2];
end;

// NegateVector
//
procedure NegateVector(var v: TVector);
begin
  v[0] := -v[0];
  v[1] := -v[1];
  v[2] := -v[2];
  v[3] := -v[3];
end;

// NegateVector
//
procedure NegateVector(var v: array of Single);
var
  i: Integer;
begin
  for i := low(v) to high(v) do
      v[i] := -v[i];
end;

// ScaleVector (2f)
//
procedure ScaleVector(var v: TVector2f; factor: Single);
begin
  v[0] := v[0] * factor;
  v[1] := v[1] * factor;
end;

// ScaleVector (affine)
//
procedure ScaleVector(var v: TAffineVector; factor: Single);
begin
  v[0] := v[0] * factor;
  v[1] := v[1] * factor;
  v[2] := v[2] * factor;
end;

// ScaleVector (hmg)
//
procedure ScaleVector(var v: TVector; factor: Single);
begin
  v[0] := v[0] * factor;
  v[1] := v[1] * factor;
  v[2] := v[2] * factor;
  v[3] := v[3] * factor;
end;

// ScaleVector (affine vector)
//
procedure ScaleVector(var v: TAffineVector; const factor: TAffineVector);
begin
  v[0] := v[0] * factor[0];
  v[1] := v[1] * factor[1];
  v[2] := v[2] * factor[2];
end;

// ScaleVector (hmg vector)
//
procedure ScaleVector(var v: TVector; const factor: TVector);
begin
  v[0] := v[0] * factor[0];
  v[1] := v[1] * factor[1];
  v[2] := v[2] * factor[2];
  v[3] := v[3] * factor[3];
end;

// VectorScale (2f)
//
function VectorScale(const v: TVector2f; factor: Single): TVector2f;
begin
  Result[0] := v[0] * factor;
  Result[1] := v[1] * factor;
end;

// VectorScale (affine)
//
function VectorScale(const v: TAffineVector; factor: Single): TAffineVector;
begin
  Result[0] := v[0] * factor;
  Result[1] := v[1] * factor;
  Result[2] := v[2] * factor;
end;

// VectorScale (proc, affine)
//
procedure VectorScale(const v: TAffineVector; factor: Single; var vr: TAffineVector);
begin
  vr[0] := v[0] * factor;
  vr[1] := v[1] * factor;
  vr[2] := v[2] * factor;
end;

// VectorScale (hmg)
//
function VectorScale(const v: TVector; factor: Single): TVector;
begin
  Result[0] := v[0] * factor;
  Result[1] := v[1] * factor;
  Result[2] := v[2] * factor;
  Result[3] := v[3] * factor;
end;

// VectorScale (proc, hmg)
//
procedure VectorScale(const v: TVector; factor: Single; var vr: TVector);
begin
  vr[0] := v[0] * factor;
  vr[1] := v[1] * factor;
  vr[2] := v[2] * factor;
  vr[3] := v[3] * factor;
end;

// VectorScale (proc, hmg-affine)
//
procedure VectorScale(const v: TVector; factor: Single; var vr: TAffineVector);
begin
  vr[0] := v[0] * factor;
  vr[1] := v[1] * factor;
  vr[2] := v[2] * factor;
end;

// VectorScale (func, affine)
//
function VectorScale(const v: TAffineVector; const factor: TAffineVector): TAffineVector;
begin
  Result[0] := v[0] * factor[0];
  Result[1] := v[1] * factor[1];
  Result[2] := v[2] * factor[2];
end;

// VectorScale (func, hmg)
//
function VectorScale(const v: TVector; const factor: TVector): TVector;
begin
  Result[0] := v[0] * factor[0];
  Result[1] := v[1] * factor[1];
  Result[2] := v[2] * factor[2];
  Result[3] := v[3] * factor[3];
end;

// DivideVector
//
procedure DivideVector(var v: TVector; const divider: TVector);
begin
  v[0] := v[0] / divider[0];
  v[1] := v[1] / divider[1];
  v[2] := v[2] / divider[2];
  v[3] := v[3] / divider[3];
end;

// DivideVector
//
procedure DivideVector(var v: TAffineVector; const divider: TAffineVector); overload;
begin
  v[0] := v[0] / divider[0];
  v[1] := v[1] / divider[1];
  v[2] := v[2] / divider[2];
end;

// VectorDivide
//
function VectorDivide(const v: TVector; const divider: TVector): TVector; overload;
begin
  Result[0] := v[0] / divider[0];
  Result[1] := v[1] / divider[1];
  Result[2] := v[2] / divider[2];
  Result[3] := v[3] / divider[3];
end;

// VectorDivide
//
function VectorDivide(const v: TAffineVector; const divider: TAffineVector): TAffineVector; overload;
begin
  Result[0] := v[0] / divider[0];
  Result[1] := v[1] / divider[1];
  Result[2] := v[2] / divider[2];
end;

// TexpointEquals
//
function TexpointEquals(const p1, p2: TTexPoint): Boolean;
begin
  Result := (p1.s = p2.s) and (p1.t = p2.t);
end;

// VectorEquals (hmg vector)
//
function VectorEquals(const v1, v2: TVector): Boolean;
begin
  Result := (v1[0] = v2[0]) and (v1[1] = v2[1]) and (v1[2] = v2[2]) and (v1[3] = v2[3]);
end;

// VectorEquals (affine vector)
//
function VectorEquals(const v1, v2: TAffineVector): Boolean;
begin
  Result := (v1[0] = v2[0]) and (v1[1] = v2[1]) and (v1[2] = v2[2]);
end;

// AffineVectorEquals (hmg vector)
//
function AffineVectorEquals(const v1, v2: TVector): Boolean;
begin
  Result := (v1[0] = v2[0]) and (v1[1] = v2[1]) and (v1[2] = v2[2]);
end;

// VectorIsNull (hmg)
//
function VectorIsNull(const v: TVector): Boolean;
begin
  Result := ((v[0] = 0) and (v[1] = 0) and (v[2] = 0));
end;

// VectorIsNull (affine)
//
function VectorIsNull(const v: TAffineVector): Boolean; overload;
begin
  Result := ((v[0] = 0) and (v[1] = 0) and (v[2] = 0));
end;

// VectorSpacing (texpoint)
//
function VectorSpacing(const v1, v2: TTexPoint): Single; overload;
begin
  Result := Abs(v2.s - v1.s) + Abs(v2.t - v1.t);
end;

// VectorSpacing (affine)
//
function VectorSpacing(const v1, v2: TAffineVector): Single;
begin
  Result := Abs(v2[0] - v1[0]) + Abs(v2[1] - v1[1]) + Abs(v2[2] - v1[2]);
end;

// VectorSpacing (Hmg)
//
function VectorSpacing(const v1, v2: TVector): Single;
begin
  Result := Abs(v2[0] - v1[0]) + Abs(v2[1] - v1[1]) + Abs(v2[2] - v1[2]) + Abs(v2[3] - v1[3]);
end;

// VectorDistance (affine)
//
function VectorDistance(const v1, v2: TAffineVector): Single;
begin
  Result := Sqrt(Sqr(v2[0] - v1[0]) + Sqr(v2[1] - v1[1]) + Sqr(v2[2] - v1[2]));
end;

// VectorDistance (hmg)
//
function VectorDistance(const v1, v2: TVector): Single;
begin
  Result := Sqrt(Sqr(v2[0] - v1[0]) + Sqr(v2[1] - v1[1]) + Sqr(v2[2] - v1[2]));
end;

// VectorDistance2 (affine)
//
function VectorDistance2(const v1, v2: TAffineVector): Single;
begin
  Result := Sqr(v2[0] - v1[0]) + Sqr(v2[1] - v1[1]) + Sqr(v2[2] - v1[2]);
end;

// VectorDistance2 (hmg)
//
function VectorDistance2(const v1, v2: TVector): Single;
begin
  Result := Sqr(v2[0] - v1[0]) + Sqr(v2[1] - v1[1]) + Sqr(v2[2] - v1[2]);
end;

// VectorPerpendicular
//
function VectorPerpendicular(const v, n: TAffineVector): TAffineVector;
var
  dot: Single;
begin
  dot := VectorDotProduct(v, n);
  Result[x] := v[x] - dot * n[x];
  Result[y] := v[y] - dot * n[y];
  Result[Z] := v[Z] - dot * n[Z];
end;

// VectorReflect
//
function VectorReflect(const v, n: TAffineVector): TAffineVector;
begin
  Result := VectorCombine(v, n, 1, -2 * VectorDotProduct(v, n));
end;

// RotateVector
//
procedure RotateVector(var Vector: TVector; const axis: TAffineVector; angle: Single);
var
  rotMatrix: TMatrix4f;
begin
  rotMatrix := CreateRotationMatrix(axis, angle);
  Vector := VectorTransform(Vector, rotMatrix);
end;

// RotateVector
//
procedure RotateVector(var Vector: TVector; const axis: TVector; angle: Single); overload;
var
  rotMatrix: TMatrix4f;
begin
  rotMatrix := CreateRotationMatrix(PAffineVector(@axis)^, angle);
  Vector := VectorTransform(Vector, rotMatrix);
end;

// RotateVectorAroundY
//
procedure RotateVectorAroundY(var v: TAffineVector; alpha: Single);
var
  c, s, v0: Single;
begin
  SinCos_(alpha, s, c);
  v0 := v[0];
  v[0] := c * v0 + s * v[2];
  v[2] := c * v[2] - s * v0;
end;

// VectorRotateAroundX (func)
//
function VectorRotateAroundX(const v: TAffineVector; alpha: Single): TAffineVector;
var
  c, s: Single;
begin
  SinCos_(alpha, s, c);
  Result[0] := v[0];
  Result[1] := c * v[1] + s * v[2];
  Result[2] := c * v[2] - s * v[1];
end;

// VectorRotateAroundY (func)
//
function VectorRotateAroundY(const v: TAffineVector; alpha: Single): TAffineVector;
var
  c, s: Single;
begin
  SinCos_(alpha, s, c);
  Result[1] := v[1];
  Result[0] := c * v[0] + s * v[2];
  Result[2] := c * v[2] - s * v[0];
end;

// VectorRotateAroundY (proc)
//
procedure VectorRotateAroundY(const v: TAffineVector; alpha: Single; var vr: TAffineVector);
var
  c, s: Single;
begin
  SinCos_(alpha, s, c);
  vr[1] := v[1];
  vr[0] := c * v[0] + s * v[2];
  vr[2] := c * v[2] - s * v[0];
end;

// VectorRotateAroundZ (func)
//
function VectorRotateAroundZ(const v: TAffineVector; alpha: Single): TAffineVector;
var
  c, s: Single;
begin
  SinCos_(alpha, s, c);
  Result[0] := c * v[0] + s * v[1];
  Result[1] := c * v[1] - s * v[0];
  Result[2] := v[2];
end;

// AbsVector (hmg)
//
procedure AbsVector(var v: TVector);
begin
  v[0] := Abs(v[0]);
  v[1] := Abs(v[1]);
  v[2] := Abs(v[2]);
  v[3] := Abs(v[3]);
end;

// AbsVector (affine)
//
procedure AbsVector(var v: TAffineVector);
begin
  v[0] := Abs(v[0]);
  v[1] := Abs(v[1]);
  v[2] := Abs(v[2]);
end;

// VectorAbs (hmg)
//
function VectorAbs(const v: TVector): TVector;
begin
  Result[0] := Abs(v[0]);
  Result[1] := Abs(v[1]);
  Result[2] := Abs(v[2]);
  Result[3] := Abs(v[3]);
end;

// VectorAbs (affine)
//
function VectorAbs(const v: TAffineVector): TAffineVector;
begin
  Result[0] := Abs(v[0]);
  Result[1] := Abs(v[1]);
  Result[2] := Abs(v[2]);
end;

// IsColinear (2f)
//
function IsColinear(const v1, v2: TVector2f): Boolean;
var
  a, b, c: Single;
begin
  a := VectorDotProduct(v1, v1);
  b := VectorDotProduct(v1, v2);
  c := VectorDotProduct(v2, v2);
  Result := (a * c - b * b) < CColinearBias;
end;

// IsColinear (affine)
//
function IsColinear(const v1, v2: TAffineVector): Boolean;
var
  a, b, c: Single;
begin
  a := VectorDotProduct(v1, v1);
  b := VectorDotProduct(v1, v2);
  c := VectorDotProduct(v2, v2);
  Result := (a * c - b * b) < CColinearBias;
end;

// IsColinear (hmg)
//
function IsColinear(const v1, v2: TVector): Boolean;
var
  a, b, c: Single;
begin
  a := VectorDotProduct(v1, v1);
  b := VectorDotProduct(v1, v2);
  c := VectorDotProduct(v2, v2);
  Result := (a * c - b * b) < CColinearBias;
end;

// SetMatrix (hmg->affine)
//
procedure SetMatrix(var dest: TAffineMatrix; const Src: TMatrix);
begin
  dest[0, 0] := Src[0, 0];
  dest[0, 1] := Src[0, 1];
  dest[0, 2] := Src[0, 2];
  dest[1, 0] := Src[1, 0];
  dest[1, 1] := Src[1, 1];
  dest[1, 2] := Src[1, 2];
  dest[2, 0] := Src[2, 0];
  dest[2, 1] := Src[2, 1];
  dest[2, 2] := Src[2, 2];
end;

// SetMatrix (affine->hmg)
//
procedure SetMatrix(var dest: TMatrix; const Src: TAffineMatrix);
begin
  dest[0, 0] := Src[0, 0];
  dest[0, 1] := Src[0, 1];
  dest[0, 2] := Src[0, 2];
  dest[0, 3] := 0;
  dest[1, 0] := Src[1, 0];
  dest[1, 1] := Src[1, 1];
  dest[1, 2] := Src[1, 2];
  dest[1, 3] := 0;
  dest[2, 0] := Src[2, 0];
  dest[2, 1] := Src[2, 1];
  dest[2, 2] := Src[2, 2];
  dest[2, 3] := 0;
  dest[3, 0] := 0;
  dest[3, 1] := 0;
  dest[3, 2] := 0;
  dest[3, 3] := 1;
end;

// SetMatrixRow
//
procedure SetMatrixRow(var dest: TMatrix; rowNb: Integer; const aRow: TVector);
begin
  dest[0, rowNb] := aRow[0];
  dest[1, rowNb] := aRow[1];
  dest[2, rowNb] := aRow[2];
  dest[3, rowNb] := aRow[3];
end;

// CreateScaleMatrix (affine)
//
function CreateScaleMatrix(const v: TAffineVector): TMatrix;
begin
  Result := IdentityHmgMatrix;
  Result[x, x] := v[x];
  Result[y, y] := v[y];
  Result[Z, Z] := v[Z];
end;

// CreateScaleMatrix (Hmg)
//
function CreateScaleMatrix(const v: TVector): TMatrix;
begin
  Result := IdentityHmgMatrix;
  Result[x, x] := v[x];
  Result[y, y] := v[y];
  Result[Z, Z] := v[Z];
end;

// CreateTranslationMatrix (affine)
//
function CreateTranslationMatrix(const v: TAffineVector): TMatrix;
begin
  Result := IdentityHmgMatrix;
  Result[w, x] := v[x];
  Result[w, y] := v[y];
  Result[w, Z] := v[Z];
end;

// CreateTranslationMatrix (hmg)
//
function CreateTranslationMatrix(const v: TVector): TMatrix;
begin
  Result := IdentityHmgMatrix;
  Result[w, x] := v[x];
  Result[w, y] := v[y];
  Result[w, Z] := v[Z];
end;

// CreateScaleAndTranslationMatrix
//
function CreateScaleAndTranslationMatrix(const Scale, Offset: TVector): TMatrix;
begin
  Result := IdentityHmgMatrix;
  Result[x, x] := Scale[x];
  Result[w, x] := Offset[x];
  Result[y, y] := Scale[y];
  Result[w, y] := Offset[y];
  Result[Z, Z] := Scale[Z];
  Result[w, Z] := Offset[Z];
end;

// CreateRotationMatrixX
//
function CreateRotationMatrixX(const sine, cosine: Single): TMatrix;
begin
  Result := EmptyHmgMatrix;
  Result[x, x] := 1;
  Result[y, y] := cosine;
  Result[y, Z] := sine;
  Result[Z, y] := -sine;
  Result[Z, Z] := cosine;
  Result[w, w] := 1;
end;

// CreateRotationMatrixX
//
function CreateRotationMatrixX(const angle: Single): TMatrix;
var
  s, c: Single;
begin
  SinCos_(angle, s, c);
  Result := CreateRotationMatrixX(s, c);
end;

// CreateRotationMatrixY
//
function CreateRotationMatrixY(const sine, cosine: Single): TMatrix;
begin
  Result := EmptyHmgMatrix;
  Result[x, x] := cosine;
  Result[x, Z] := -sine;
  Result[y, y] := 1;
  Result[Z, x] := sine;
  Result[Z, Z] := cosine;
  Result[w, w] := 1;
end;

// CreateRotationMatrixY
//
function CreateRotationMatrixY(const angle: Single): TMatrix;
var
  s, c: Single;
begin
  SinCos_(angle, s, c);
  Result := CreateRotationMatrixY(s, c);
end;

// CreateRotationMatrixZ
//
function CreateRotationMatrixZ(const sine, cosine: Single): TMatrix;
begin
  Result := EmptyHmgMatrix;
  Result[x, x] := cosine;
  Result[x, y] := sine;
  Result[y, x] := -sine;
  Result[y, y] := cosine;
  Result[Z, Z] := 1;
  Result[w, w] := 1;
end;

// CreateRotationMatrixZ
//
function CreateRotationMatrixZ(const angle: Single): TMatrix;
var
  s, c: Single;
begin
  SinCos_(angle, s, c);
  Result := CreateRotationMatrixZ(s, c);
end;

// CreateRotationMatrix (affine)
//
function CreateRotationMatrix(const anAxis: TAffineVector; angle: Single): TMatrix;
var
  axis: TAffineVector;
  cosine, sine, one_minus_cosine: Single;
begin
  SinCos_(angle, sine, cosine);
  one_minus_cosine := 1 - cosine;
  axis := VectorNormalize(anAxis);

  Result[x, x] := (one_minus_cosine * axis[0] * axis[0]) + cosine;
  Result[x, y] := (one_minus_cosine * axis[0] * axis[1]) - (axis[2] * sine);
  Result[x, Z] := (one_minus_cosine * axis[2] * axis[0]) + (axis[1] * sine);
  Result[x, w] := 0;

  Result[y, x] := (one_minus_cosine * axis[0] * axis[1]) + (axis[2] * sine);
  Result[y, y] := (one_minus_cosine * axis[1] * axis[1]) + cosine;
  Result[y, Z] := (one_minus_cosine * axis[1] * axis[2]) - (axis[0] * sine);
  Result[y, w] := 0;

  Result[Z, x] := (one_minus_cosine * axis[2] * axis[0]) - (axis[1] * sine);
  Result[Z, y] := (one_minus_cosine * axis[1] * axis[2]) + (axis[0] * sine);
  Result[Z, Z] := (one_minus_cosine * axis[2] * axis[2]) + cosine;
  Result[Z, w] := 0;

  Result[w, x] := 0;
  Result[w, y] := 0;
  Result[w, Z] := 0;
  Result[w, w] := 1;
end;

// CreateRotationMatrix (hmg)
//
function CreateRotationMatrix(const anAxis: TVector; angle: Single): TMatrix;
begin
  Result := CreateRotationMatrix(PAffineVector(@anAxis)^, angle);
end;

// CreateAffineRotationMatrix
//
function CreateAffineRotationMatrix(const anAxis: TAffineVector; angle: Single): TAffineMatrix;
var
  axis: TAffineVector;
  cosine, sine, one_minus_cosine: Single;
begin
  SinCos_(angle, sine, cosine);
  one_minus_cosine := 1 - cosine;
  axis := VectorNormalize(anAxis);

  Result[x, x] := (one_minus_cosine * Sqr(axis[0])) + cosine;
  Result[x, y] := (one_minus_cosine * axis[0] * axis[1]) - (axis[2] * sine);
  Result[x, Z] := (one_minus_cosine * axis[2] * axis[0]) + (axis[1] * sine);

  Result[y, x] := (one_minus_cosine * axis[0] * axis[1]) + (axis[2] * sine);
  Result[y, y] := (one_minus_cosine * Sqr(axis[1])) + cosine;
  Result[y, Z] := (one_minus_cosine * axis[1] * axis[2]) - (axis[0] * sine);

  Result[Z, x] := (one_minus_cosine * axis[2] * axis[0]) - (axis[1] * sine);
  Result[Z, y] := (one_minus_cosine * axis[1] * axis[2]) + (axis[0] * sine);
  Result[Z, Z] := (one_minus_cosine * Sqr(axis[2])) + cosine;
end;

// MatrixMultiply (3x3 func)
//
function MatrixMultiply(const m1, m2: TAffineMatrix): TAffineMatrix;
begin
  Result[x, x] := m1[x, x] * m2[x, x] + m1[x, y] * m2[y, x] + m1[x, Z] * m2[Z, x];
  Result[x, y] := m1[x, x] * m2[x, y] + m1[x, y] * m2[y, y] + m1[x, Z] * m2[Z, y];
  Result[x, Z] := m1[x, x] * m2[x, Z] + m1[x, y] * m2[y, Z] + m1[x, Z] * m2[Z, Z];
  Result[y, x] := m1[y, x] * m2[x, x] + m1[y, y] * m2[y, x] + m1[y, Z] * m2[Z, x];
  Result[y, y] := m1[y, x] * m2[x, y] + m1[y, y] * m2[y, y] + m1[y, Z] * m2[Z, y];
  Result[y, Z] := m1[y, x] * m2[x, Z] + m1[y, y] * m2[y, Z] + m1[y, Z] * m2[Z, Z];
  Result[Z, x] := m1[Z, x] * m2[x, x] + m1[Z, y] * m2[y, x] + m1[Z, Z] * m2[Z, x];
  Result[Z, y] := m1[Z, x] * m2[x, y] + m1[Z, y] * m2[y, y] + m1[Z, Z] * m2[Z, y];
  Result[Z, Z] := m1[Z, x] * m2[x, Z] + m1[Z, y] * m2[y, Z] + m1[Z, Z] * m2[Z, Z];
end;

// MatrixMultiply (4x4, func)
//
function MatrixMultiply(const m1, m2: TMatrix): TMatrix;
begin
  Result[x, x] := m1[x, x] * m2[x, x] + m1[x, y] * m2[y, x] + m1[x, Z] * m2[Z, x] + m1[x, w] * m2[w, x];
  Result[x, y] := m1[x, x] * m2[x, y] + m1[x, y] * m2[y, y] + m1[x, Z] * m2[Z, y] + m1[x, w] * m2[w, y];
  Result[x, Z] := m1[x, x] * m2[x, Z] + m1[x, y] * m2[y, Z] + m1[x, Z] * m2[Z, Z] + m1[x, w] * m2[w, Z];
  Result[x, w] := m1[x, x] * m2[x, w] + m1[x, y] * m2[y, w] + m1[x, Z] * m2[Z, w] + m1[x, w] * m2[w, w];
  Result[y, x] := m1[y, x] * m2[x, x] + m1[y, y] * m2[y, x] + m1[y, Z] * m2[Z, x] + m1[y, w] * m2[w, x];
  Result[y, y] := m1[y, x] * m2[x, y] + m1[y, y] * m2[y, y] + m1[y, Z] * m2[Z, y] + m1[y, w] * m2[w, y];
  Result[y, Z] := m1[y, x] * m2[x, Z] + m1[y, y] * m2[y, Z] + m1[y, Z] * m2[Z, Z] + m1[y, w] * m2[w, Z];
  Result[y, w] := m1[y, x] * m2[x, w] + m1[y, y] * m2[y, w] + m1[y, Z] * m2[Z, w] + m1[y, w] * m2[w, w];
  Result[Z, x] := m1[Z, x] * m2[x, x] + m1[Z, y] * m2[y, x] + m1[Z, Z] * m2[Z, x] + m1[Z, w] * m2[w, x];
  Result[Z, y] := m1[Z, x] * m2[x, y] + m1[Z, y] * m2[y, y] + m1[Z, Z] * m2[Z, y] + m1[Z, w] * m2[w, y];
  Result[Z, Z] := m1[Z, x] * m2[x, Z] + m1[Z, y] * m2[y, Z] + m1[Z, Z] * m2[Z, Z] + m1[Z, w] * m2[w, Z];
  Result[Z, w] := m1[Z, x] * m2[x, w] + m1[Z, y] * m2[y, w] + m1[Z, Z] * m2[Z, w] + m1[Z, w] * m2[w, w];
  Result[w, x] := m1[w, x] * m2[x, x] + m1[w, y] * m2[y, x] + m1[w, Z] * m2[Z, x] + m1[w, w] * m2[w, x];
  Result[w, y] := m1[w, x] * m2[x, y] + m1[w, y] * m2[y, y] + m1[w, Z] * m2[Z, y] + m1[w, w] * m2[w, y];
  Result[w, Z] := m1[w, x] * m2[x, Z] + m1[w, y] * m2[y, Z] + m1[w, Z] * m2[Z, Z] + m1[w, w] * m2[w, Z];
  Result[w, w] := m1[w, x] * m2[x, w] + m1[w, y] * m2[y, w] + m1[w, Z] * m2[Z, w] + m1[w, w] * m2[w, w];
end;

// MatrixMultiply (4x4, proc)
//
procedure MatrixMultiply(const m1, m2: TMatrix; var MResult: TMatrix);
begin
  MResult := MatrixMultiply(m1, m2);
end;

// VectorTransform
//
function VectorTransform(const v: TVector; const M: TMatrix): TVector;
begin
  Result[x] := v[x] * M[x, x] + v[y] * M[y, x] + v[Z] * M[Z, x] + v[w] * M[w, x];
  Result[y] := v[x] * M[x, y] + v[y] * M[y, y] + v[Z] * M[Z, y] + v[w] * M[w, y];
  Result[Z] := v[x] * M[x, Z] + v[y] * M[y, Z] + v[Z] * M[Z, Z] + v[w] * M[w, Z];
  Result[w] := v[x] * M[x, w] + v[y] * M[y, w] + v[Z] * M[Z, w] + v[w] * M[w, w];
end;

// VectorTransform
//
function VectorTransform(const v: TVector; const M: TAffineMatrix): TVector;
begin
  Result[x] := v[x] * M[x, x] + v[y] * M[y, x] + v[Z] * M[Z, x];
  Result[y] := v[x] * M[x, y] + v[y] * M[y, y] + v[Z] * M[Z, y];
  Result[Z] := v[x] * M[x, Z] + v[y] * M[y, Z] + v[Z] * M[Z, Z];
  Result[w] := v[w];
end;

// VectorTransform
//
function VectorTransform(const v: TAffineVector; const M: TMatrix): TAffineVector;
begin
  Result[x] := v[x] * M[x, x] + v[y] * M[y, x] + v[Z] * M[Z, x] + M[w, x];
  Result[y] := v[x] * M[x, y] + v[y] * M[y, y] + v[Z] * M[Z, y] + M[w, y];
  Result[Z] := v[x] * M[x, Z] + v[y] * M[y, Z] + v[Z] * M[Z, Z] + M[w, Z];
end;

// VectorTransform
//
function VectorTransform(const v: TAffineVector; const M: TAffineMatrix): TAffineVector;
begin
  Result[x] := v[x] * M[x, x] + v[y] * M[y, x] + v[Z] * M[Z, x];
  Result[y] := v[x] * M[x, y] + v[y] * M[y, y] + v[Z] * M[Z, y];
  Result[Z] := v[x] * M[x, Z] + v[y] * M[y, Z] + v[Z] * M[Z, Z];
end;

// MatrixDeterminant (affine)
//
function MatrixDeterminant(const M: TAffineMatrix): Single;
begin
  Result :=
    M[x, x] * (M[y, y] * M[Z, Z] - M[Z, y] * M[y, Z])
    - M[x, y] * (M[y, x] * M[Z, Z] - M[Z, x] * M[y, Z])
    + M[x, Z] * (M[y, x] * M[Z, y] - M[Z, x] * M[y, y]);
end;

// MatrixDetInternal
//
function MatrixDetInternal(const a1, a2, a3, b1, b2, b3, c1, c2, c3: Single): Single;
// internal version for the determinant of a 3x3 matrix
begin
  Result :=
    a1 * (b2 * c3 - b3 * c2)
    - b1 * (a2 * c3 - a3 * c2)
    + c1 * (a2 * b3 - a3 * b2);
end;

// MatrixDeterminant (hmg)
//
function MatrixDeterminant(const M: TMatrix): Single;
begin
  Result :=
    M[x, x] * MatrixDetInternal(M[y, y], M[Z, y], M[w, y], M[y, Z], M[Z, Z], M[w, Z], M[y, w], M[Z, w], M[w, w])
    - M[x, y] * MatrixDetInternal(M[y, x], M[Z, x], M[w, x], M[y, Z], M[Z, Z], M[w, Z], M[y, w], M[Z, w], M[w, w])
    + M[x, Z] * MatrixDetInternal(M[y, x], M[Z, x], M[w, x], M[y, y], M[Z, y], M[w, y], M[y, w], M[Z, w], M[w, w])
    - M[x, w] * MatrixDetInternal(M[y, x], M[Z, x], M[w, x], M[y, y], M[Z, y], M[w, y], M[y, Z], M[Z, Z], M[w, Z]);
end;

// AdjointMatrix
//
procedure AdjointMatrix(var M: TMatrix);
var
  a1, a2, a3, a4: Single;
  b1, b2, b3, b4: Single;
  c1, c2, c3, c4: Single;
  d1, d2, d3, d4: Single;
begin
  a1 := M[x, x];
  b1 := M[x, y];
  c1 := M[x, Z];
  d1 := M[x, w];
  a2 := M[y, x];
  b2 := M[y, y];
  c2 := M[y, Z];
  d2 := M[y, w];
  a3 := M[Z, x];
  b3 := M[Z, y];
  c3 := M[Z, Z];
  d3 := M[Z, w];
  a4 := M[w, x];
  b4 := M[w, y];
  c4 := M[w, Z];
  d4 := M[w, w];

  // row column labeling reversed since we transpose rows & columns
  M[x, x] := MatrixDetInternal(b2, b3, b4, c2, c3, c4, d2, d3, d4);
  M[y, x] := -MatrixDetInternal(a2, a3, a4, c2, c3, c4, d2, d3, d4);
  M[Z, x] := MatrixDetInternal(a2, a3, a4, b2, b3, b4, d2, d3, d4);
  M[w, x] := -MatrixDetInternal(a2, a3, a4, b2, b3, b4, c2, c3, c4);

  M[x, y] := -MatrixDetInternal(b1, b3, b4, c1, c3, c4, d1, d3, d4);
  M[y, y] := MatrixDetInternal(a1, a3, a4, c1, c3, c4, d1, d3, d4);
  M[Z, y] := -MatrixDetInternal(a1, a3, a4, b1, b3, b4, d1, d3, d4);
  M[w, y] := MatrixDetInternal(a1, a3, a4, b1, b3, b4, c1, c3, c4);

  M[x, Z] := MatrixDetInternal(b1, b2, b4, c1, c2, c4, d1, d2, d4);
  M[y, Z] := -MatrixDetInternal(a1, a2, a4, c1, c2, c4, d1, d2, d4);
  M[Z, Z] := MatrixDetInternal(a1, a2, a4, b1, b2, b4, d1, d2, d4);
  M[w, Z] := -MatrixDetInternal(a1, a2, a4, b1, b2, b4, c1, c2, c4);

  M[x, w] := -MatrixDetInternal(b1, b2, b3, c1, c2, c3, d1, d2, d3);
  M[y, w] := MatrixDetInternal(a1, a2, a3, c1, c2, c3, d1, d2, d3);
  M[Z, w] := -MatrixDetInternal(a1, a2, a3, b1, b2, b3, d1, d2, d3);
  M[w, w] := MatrixDetInternal(a1, a2, a3, b1, b2, b3, c1, c2, c3);
end;

// AdjointMatrix (affine)
//
procedure AdjointMatrix(var M: TAffineMatrix);
var
  a1, a2, a3: Single;
  b1, b2, b3: Single;
  c1, c2, c3: Single;
begin
  a1 := M[x, x];
  a2 := M[x, y];
  a3 := M[x, Z];
  b1 := M[y, x];
  b2 := M[y, y];
  b3 := M[y, Z];
  c1 := M[Z, x];
  c2 := M[Z, y];
  c3 := M[Z, Z];
  M[x, x] := (b2 * c3 - c2 * b3);
  M[y, x] := -(b1 * c3 - c1 * b3);
  M[Z, x] := (b1 * c2 - c1 * b2);

  M[x, y] := -(a2 * c3 - c2 * a3);
  M[y, y] := (a1 * c3 - c1 * a3);
  M[Z, y] := -(a1 * c2 - c1 * a2);

  M[x, Z] := (a2 * b3 - b2 * a3);
  M[y, Z] := -(a1 * b3 - b1 * a3);
  M[Z, Z] := (a1 * b2 - b1 * a2);
end;

// ScaleMatrix (affine)
//
procedure ScaleMatrix(var M: TAffineMatrix; const factor: Single);
var
  i: Integer;
begin
  for i := 0 to 2 do
    begin
      M[i, 0] := M[i, 0] * factor;
      M[i, 1] := M[i, 1] * factor;
      M[i, 2] := M[i, 2] * factor;
    end;
end;

// ScaleMatrix (hmg)
//
procedure ScaleMatrix(var M: TMatrix; const factor: Single);
var
  i: Integer;
begin
  for i := 0 to 3 do
    begin
      M[i, 0] := M[i, 0] * factor;
      M[i, 1] := M[i, 1] * factor;
      M[i, 2] := M[i, 2] * factor;
      M[i, 3] := M[i, 3] * factor;
    end;
end;

// TranslateMatrix (affine vec)
//
procedure TranslateMatrix(var M: TMatrix; const v: TAffineVector);
begin
  M[3][0] := M[3][0] + v[0];
  M[3][1] := M[3][1] + v[1];
  M[3][2] := M[3][2] + v[2];
end;

// TranslateMatrix
//
procedure TranslateMatrix(var M: TMatrix; const v: TVector);
begin
  M[3][0] := M[3][0] + v[0];
  M[3][1] := M[3][1] + v[1];
  M[3][2] := M[3][2] + v[2];
end;

// NormalizeMatrix
//
procedure NormalizeMatrix(var M: TMatrix);
begin
  M[0][3] := 0;
  NormalizeVector(M[0]);
  M[1][3] := 0;
  NormalizeVector(M[1]);
  M[2] := VectorCrossProduct(M[0], M[1]);
  M[0] := VectorCrossProduct(M[1], M[2]);
  M[3] := WHmgVector;
end;

// TransposeMatrix
//
procedure TransposeMatrix(var M: TAffineMatrix);
var
  f: Single;
begin
  f := M[0, 1];
  M[0, 1] := M[1, 0];
  M[1, 0] := f;
  f := M[0, 2];
  M[0, 2] := M[2, 0];
  M[2, 0] := f;
  f := M[1, 2];
  M[1, 2] := M[2, 1];
  M[2, 1] := f;
end;

// TransposeMatrix
//
procedure TransposeMatrix(var M: TMatrix);
var
  f: Single;
begin
  f := M[0, 1];
  M[0, 1] := M[1, 0];
  M[1, 0] := f;
  f := M[0, 2];
  M[0, 2] := M[2, 0];
  M[2, 0] := f;
  f := M[0, 3];
  M[0, 3] := M[3, 0];
  M[3, 0] := f;
  f := M[1, 2];
  M[1, 2] := M[2, 1];
  M[2, 1] := f;
  f := M[1, 3];
  M[1, 3] := M[3, 1];
  M[3, 1] := f;
  f := M[2, 3];
  M[2, 3] := M[3, 2];
  M[3, 2] := f;
end;

// InvertMatrix
//
procedure InvertMatrix(var M: TMatrix);
var
  det: Single;
begin
  det := MatrixDeterminant(M);
  if Abs(det) < Epsilon then
      M := IdentityHmgMatrix
  else
    begin
      AdjointMatrix(M);
      ScaleMatrix(M, 1 / det);
    end;
end;

// MatrixInvert
//
function MatrixInvert(const M: TMatrix): TMatrix;
begin
  Result := M;
  InvertMatrix(Result);
end;

// InvertMatrix (affine)
//
procedure InvertMatrix(var M: TAffineMatrix);
var
  det: Single;
begin
  det := MatrixDeterminant(M);
  if Abs(det) < Epsilon then
      M := IdentityMatrix
  else
    begin
      AdjointMatrix(M);
      ScaleMatrix(M, 1 / det);
    end;
end;

// MatrixInvert (affine)
//
function MatrixInvert(const M: TAffineMatrix): TAffineMatrix;
begin
  Result := M;
  InvertMatrix(Result);
end;

// transpose_scale_m33
//
procedure transpose_scale_m33(const Src: TMatrix; var dest: TMatrix; var Scale: Single);
begin
  dest[0][0] := Scale * Src[0][0];
  dest[1][0] := Scale * Src[0][1];
  dest[2][0] := Scale * Src[0][2];
  dest[0][1] := Scale * Src[1][0];
  dest[1][1] := Scale * Src[1][1];
  dest[2][1] := Scale * Src[1][2];
  dest[0][2] := Scale * Src[2][0];
  dest[1][2] := Scale * Src[2][1];
  dest[2][2] := Scale * Src[2][2];
end;

// AnglePreservingMatrixInvert
//
function AnglePreservingMatrixInvert(const mat: TMatrix): TMatrix;
var
  Scale: Single;
begin
  Scale := VectorNorm(mat[0]);

  // Is the submatrix A singular?
  if Abs(Scale) < Epsilon then
    begin
      // Matrix M has no inverse
      Result := IdentityHmgMatrix;
      Exit;
    end
  else
    begin
      // Calculate the inverse of the square of the isotropic scale factor
      Scale := 1.0 / Scale;
    end;

  // Fill in last row while CPU is busy with the division
  Result[0][3] := 0.0;
  Result[1][3] := 0.0;
  Result[2][3] := 0.0;
  Result[3][3] := 1.0;

  // Transpose and scale the 3 by 3 upper-left submatrix
  transpose_scale_m33(mat, Result, Scale);

  // Calculate -(transpose(A) / s*s) C
  Result[3][0] := -(Result[0][0] * mat[3][0]
      + Result[1][0] * mat[3][1]
      + Result[2][0] * mat[3][2]);
  Result[3][1] := -(Result[0][1] * mat[3][0]
      + Result[1][1] * mat[3][1]
      + Result[2][1] * mat[3][2]);
  Result[3][2] := -(Result[0][2] * mat[3][0]
      + Result[1][2] * mat[3][1]
      + Result[2][2] * mat[3][2]);
end;

// MatrixDecompose
//
function MatrixDecompose(const M: TMatrix; var Tran: TTransformations): Boolean;
var
  i, j: Integer;
  LocMat, pmat, invpmat: TMatrix;
  prhs, psol: TVector;
  row0, row1, row2: TAffineVector;
  f: Single;
begin
  Result := False;
  LocMat := M;
  // normalize the matrix
  if LocMat[w, w] = 0 then
      Exit;
  for i := 0 to 3 do
    for j := 0 to 3 do
        LocMat[i, j] := LocMat[i, j] / LocMat[w, w];

  // pmat is used to solve for perspective, but it also provides
  // an easy way to test for singularity of the upper 3x3 component.

  pmat := LocMat;
  for i := 0 to 2 do
      pmat[i, w] := 0;
  pmat[w, w] := 1;

  if MatrixDeterminant(pmat) = 0 then
      Exit;

  // First, isolate perspective.  This is the messiest.
  if (LocMat[x, w] <> 0) or (LocMat[y, w] <> 0) or (LocMat[Z, w] <> 0) then
    begin
      // prhs is the right hand side of the equation.
      prhs[x] := LocMat[x, w];
      prhs[y] := LocMat[y, w];
      prhs[Z] := LocMat[Z, w];
      prhs[w] := LocMat[w, w];

      // Solve the equation by inverting pmat and multiplying
      // prhs by the inverse.  (This is the easiest way, not
      // necessarily the best.)

      invpmat := pmat;
      InvertMatrix(invpmat);
      TransposeMatrix(invpmat);
      psol := VectorTransform(prhs, invpmat);

      // stuff the answer away
      Tran[ttPerspectiveX] := psol[x];
      Tran[ttPerspectiveY] := psol[y];
      Tran[ttPerspectiveZ] := psol[Z];
      Tran[ttPerspectiveW] := psol[w];

      // clear the perspective partition
      LocMat[x, w] := 0;
      LocMat[y, w] := 0;
      LocMat[Z, w] := 0;
      LocMat[w, w] := 1;
    end
  else
    begin
      // no perspective
      Tran[ttPerspectiveX] := 0;
      Tran[ttPerspectiveY] := 0;
      Tran[ttPerspectiveZ] := 0;
      Tran[ttPerspectiveW] := 0;
    end;

  // next take care of translation (easy)
  for i := 0 to 2 do
    begin
      Tran[TTransType(Ord(ttTranslateX) + i)] := LocMat[w, i];
      LocMat[w, i] := 0;
    end;

  // now get scale and shear
  SetVector(row0, LocMat[0]);
  SetVector(row1, LocMat[1]);
  SetVector(row2, LocMat[2]);

  // compute X scale factor and normalize first row
  Tran[ttScaleX] := VectorNorm(row0);
  ScaleVector(row0, RSqrt(Tran[ttScaleX]));

  // compute XY shear factor and make 2nd row orthogonal to 1st
  Tran[ttShearXY] := VectorDotProduct(row0, row1);
  f := -Tran[ttShearXY];
  CombineVector(row1, row0, f);

  // now, compute Y scale and normalize 2nd row
  Tran[ttScaleY] := VectorNorm(row1);
  ScaleVector(row1, RSqrt(Tran[ttScaleY]));
  Tran[ttShearXY] := Tran[ttShearXY] / Tran[ttScaleY];

  // compute XZ and YZ shears, orthogonalize 3rd row
  Tran[ttShearXZ] := VectorDotProduct(row0, row2);
  f := -Tran[ttShearXZ];
  CombineVector(row2, row0, f);
  Tran[ttShearYZ] := VectorDotProduct(row1, row2);
  f := -Tran[ttShearYZ];
  CombineVector(row2, row1, f);

  // next, get Z scale and normalize 3rd row
  Tran[ttScaleZ] := VectorNorm(row2);
  ScaleVector(row2, RSqrt(Tran[ttScaleZ]));
  Tran[ttShearXZ] := Tran[ttShearXZ] / Tran[ttScaleZ];
  Tran[ttShearYZ] := Tran[ttShearYZ] / Tran[ttScaleZ];

  // At this point, the matrix (in rows[]) is orthonormal.
  // Check for a coordinate system flip.  If the determinant
  // is -1, then negate the matrix and the scaling factors.
  if VectorDotProduct(row0, VectorCrossProduct(row1, row2)) < 0 then
    begin
      for i := 0 to 2 do
          Tran[TTransType(Ord(ttScaleX) + i)] := -Tran[TTransType(Ord(ttScaleX) + i)];
      NegateVector(row0);
      NegateVector(row1);
      NegateVector(row2);
    end;

  // now, get the rotations out, as described in the gem
  Tran[ttRotateY] := ArcSin_(-row0[Z]);
  if Cos(Tran[ttRotateY]) <> 0 then
    begin
      Tran[ttRotateX] := ArcTan2_(row1[Z], row2[Z]);
      Tran[ttRotateZ] := ArcTan2_(row0[y], row0[x]);
    end
  else
    begin
      Tran[ttRotateX] := ArcTan2_(row1[x], row1[y]);
      Tran[ttRotateZ] := 0;
    end;
  // All done!
  Result := True;
end;

function CreateLookAtMatrix(const eye, center, normUp: TVector): TMatrix;
var
  XAxis, YAxis, ZAxis, negEye: TVector;
begin
  ZAxis := VectorSubtract(center, eye);
  NormalizeVector(ZAxis);
  XAxis := VectorCrossProduct(ZAxis, normUp);
  NormalizeVector(XAxis);
  YAxis := VectorCrossProduct(XAxis, ZAxis);
  Result[0] := XAxis;
  Result[1] := YAxis;
  Result[2] := ZAxis;
  NegateVector(Result[2]);
  Result[3] := NullHmgPoint;
  TransposeMatrix(Result);
  negEye := eye;
  NegateVector(negEye);
  negEye[3] := 1;
  negEye := VectorTransform(negEye, Result);
  Result[3] := negEye;
end;

function CreateMatrixFromFrustum(Left, Right, Bottom, Top, ZNear, ZFar: Single): TMatrix;
begin
  Result[0][0] := 2 * ZNear / (Right - Left);
  Result[0][1] := 0;
  Result[0][2] := 0;
  Result[0][3] := 0;

  Result[1][0] := 0;
  Result[1][1] := 2 * ZNear / (Top - Bottom);
  Result[1][2] := 0;
  Result[1][3] := 0;

  Result[2][0] := (Right + Left) / (Right - Left);
  Result[2][1] := (Top + Bottom) / (Top - Bottom);
  Result[2][2] := -(ZFar + ZNear) / (ZFar - ZNear);
  Result[2][3] := -1;

  Result[3][0] := 0;
  Result[3][1] := 0;
  Result[3][2] := -2 * ZFar * ZNear / (ZFar - ZNear);
  Result[3][3] := 0;
end;

function CreatePerspectiveMatrix(FOV, Aspect, ZNear, ZFar: Single): TMatrix;
var
  x, y: Single;
begin
  FOV := MinFloat(179.9, MaxFloat(0, FOV));
  y := ZNear * Tan_(DegToRad_(FOV) * 0.5);
  x := y * Aspect;
  Result := CreateMatrixFromFrustum(-x, x, -y, y, ZNear, ZFar);
end;

function CreateOrthoMatrix(Left, Right, Bottom, Top, ZNear, ZFar: Single): TMatrix;
begin
  Result[0][0] := 2 / (Right - Left);
  Result[0][1] := 0;
  Result[0][2] := 0;
  Result[0][3] := 0;

  Result[1][0] := 0;
  Result[1][1] := 2 / (Top - Bottom);
  Result[1][2] := 0;
  Result[1][3] := 0;

  Result[2][0] := 0;
  Result[2][1] := 0;
  Result[2][2] := -2 / (ZFar - ZNear);
  Result[2][3] := 0;

  Result[3][0] := (Left + Right) / (Left - Right);
  Result[3][1] := (Bottom + Top) / (Bottom - Top);
  Result[3][2] := (ZNear + ZFar) / (ZNear - ZFar);
  Result[3][3] := 1;
end;

function CreatePickMatrix(x, y, deltax, deltay: Single; const viewport: TVector4i): TMatrix;
begin
  if (deltax <= 0) or (deltay <= 0) then
    begin
      Result := IdentityHmgMatrix;
      Exit;
    end;
  // Translate and scale the picked region to the entire window
  Result := CreateTranslationMatrix(AffineVectorMake(
      (viewport[2] - 2 * (x - viewport[0])) / deltax,
      (viewport[3] - 2 * (y - viewport[1])) / deltay,
      0.0));
  Result[0][0] := viewport[2] / deltax;
  Result[1][1] := viewport[3] / deltay;
end;

function Project(
  objectVector: TVector;
  const ViewProjMatrix: TMatrix;
  const viewport: TVector4i;
  out WindowVector: TVector): Boolean;
begin
  Result := False;
  objectVector[3] := 1.0;
  WindowVector := VectorTransform(objectVector, ViewProjMatrix);
  if WindowVector[3] = 0.0 then
      Exit;
  WindowVector[0] := WindowVector[0] / WindowVector[3];
  WindowVector[1] := WindowVector[1] / WindowVector[3];
  WindowVector[2] := WindowVector[2] / WindowVector[3];
  // Map x, y and z to range 0-1
  WindowVector[0] := WindowVector[0] * 0.5 + 0.5;
  WindowVector[1] := WindowVector[1] * 0.5 + 0.5;
  WindowVector[2] := WindowVector[2] * 0.5 + 0.5;

  // Map x,y to viewport
  WindowVector[0] := WindowVector[0] * viewport[2] + viewport[0];
  WindowVector[1] := WindowVector[1] * viewport[3] + viewport[1];
  Result := True;
end;

function UnProject(
  WindowVector: TVector;
  ViewProjMatrix: TMatrix;
  const viewport: TVector4i;
  out objectVector: TVector): Boolean;
begin
  Result := False;
  InvertMatrix(ViewProjMatrix);
  WindowVector[3] := 1.0;
  // Map x and y from window coordinates
  WindowVector[0] := (WindowVector[0] - viewport[0]) / viewport[2];
  WindowVector[1] := (WindowVector[1] - viewport[1]) / viewport[3];
  // Map to range -1 to 1
  WindowVector[0] := WindowVector[0] * 2 - 1;
  WindowVector[1] := WindowVector[1] * 2 - 1;
  WindowVector[2] := WindowVector[2] * 2 - 1;
  objectVector := VectorTransform(WindowVector, ViewProjMatrix);
  if objectVector[3] = 0.0 then
      Exit;
  objectVector[0] := objectVector[0] / objectVector[3];
  objectVector[1] := objectVector[1] / objectVector[3];
  objectVector[2] := objectVector[2] / objectVector[3];
  Result := True;
end;

// CalcPlaneNormal (func, affine)
//
function CalcPlaneNormal(const p1, p2, p3: TAffineVector): TAffineVector;
var
  v1, v2: TAffineVector;
begin
  VectorSubtract(p2, p1, v1);
  VectorSubtract(p3, p1, v2);
  VectorCrossProduct(v1, v2, Result);
  NormalizeVector(Result);
end;

// CalcPlaneNormal (proc, affine)
//
procedure CalcPlaneNormal(const p1, p2, p3: TAffineVector; var vr: TAffineVector);
var
  v1, v2: TAffineVector;
begin
  VectorSubtract(p2, p1, v1);
  VectorSubtract(p3, p1, v2);
  VectorCrossProduct(v1, v2, vr);
  NormalizeVector(vr);
end;

// CalcPlaneNormal (proc, hmg)
//
procedure CalcPlaneNormal(const p1, p2, p3: TVector; var vr: TAffineVector);
var
  v1, v2: TVector;
begin
  VectorSubtract(p2, p1, v1);
  VectorSubtract(p3, p1, v2);
  VectorCrossProduct(v1, v2, vr);
  NormalizeVector(vr);
end;

// PlaneMake (point + normal, affine)
//
function PlaneMake(const Point, normal: TAffineVector): THmgPlane;
begin
  PAffineVector(@Result)^ := normal;
  Result[3] := -VectorDotProduct(Point, normal);
end;

// PlaneMake (point + normal, hmg)
//
function PlaneMake(const Point, normal: TVector): THmgPlane;
begin
  PAffineVector(@Result)^ := PAffineVector(@normal)^;
  Result[3] := -VectorDotProduct(PAffineVector(@Point)^, PAffineVector(@normal)^);
end;

// PlaneMake (3 points, affine)
//
function PlaneMake(const p1, p2, p3: TAffineVector): THmgPlane;
begin
  CalcPlaneNormal(p1, p2, p3, PAffineVector(@Result)^);
  Result[3] := -VectorDotProduct(p1, PAffineVector(@Result)^);
end;

// PlaneMake (3 points, hmg)
//
function PlaneMake(const p1, p2, p3: TVector): THmgPlane;
begin
  CalcPlaneNormal(p1, p2, p3, PAffineVector(@Result)^);
  Result[3] := -VectorDotProduct(p1, PAffineVector(@Result)^);
end;

// NormalizePlane
//
procedure NormalizePlane(var plane: THmgPlane);
var
  n: Single;
begin
  n := RSqrt(plane[0] * plane[0] + plane[1] * plane[1] + plane[2] * plane[2]);
  ScaleVector(plane, n);
end;

// PlaneEvaluatePoint (affine)
//
function PlaneEvaluatePoint(const plane: THmgPlane; const Point: TAffineVector): Single;
begin
  Result := plane[0] * Point[0] + plane[1] * Point[1] + plane[2] * Point[2] + plane[3];
end;

// PlaneEvaluatePoint (hmg)
//
function PlaneEvaluatePoint(const plane: THmgPlane; const Point: TVector): Single;
begin
  Result := plane[0] * Point[0] + plane[1] * Point[1] + plane[2] * Point[2] + plane[3];
end;

// PointIsInHalfSpace
//
function PointIsInHalfSpace(const Point, planePoint, planeNormal: TVector): Boolean;
begin
  Result := (PointPlaneDistance(Point, planePoint, planeNormal) > 0); // 44
end;

// PointIsInHalfSpace
//
function PointIsInHalfSpace(const Point, planePoint, planeNormal: TAffineVector): Boolean;
begin
  Result := (PointPlaneDistance(Point, planePoint, planeNormal) > 0);
end;

// PointIsInHalfSpace
//
function PointIsInHalfSpace(const Point: TAffineVector; plane: THmgPlane): Boolean;
begin
  Result := (PointPlaneDistance(Point, plane) > 0);
end;

// PointPlaneDistance
//
function PointPlaneDistance(const Point, planePoint, planeNormal: TVector): Single;
begin
  Result := (Point[0] - planePoint[0]) * planeNormal[0]
    + (Point[1] - planePoint[1]) * planeNormal[1]
    + (Point[2] - planePoint[2]) * planeNormal[2];
end;

// PointPlaneDistance
//
function PointPlaneDistance(const Point, planePoint, planeNormal: TAffineVector): Single;
begin
  Result := (Point[0] - planePoint[0]) * planeNormal[0]
    + (Point[1] - planePoint[1]) * planeNormal[1]
    + (Point[2] - planePoint[2]) * planeNormal[2];
end;

// PointPlaneDistance
//
function PointPlaneDistance(const Point: TAffineVector; plane: THmgPlane): Single;
begin
  Result := PlaneEvaluatePoint(plane, Point);
end;

// PointPlaneOrthoProjection
//
function PointPlaneOrthoProjection(const Point: TAffineVector; const plane: THmgPlane;
  var inter: TAffineVector; bothface: Boolean): Boolean;
var
  h: Single;
  normal: TAffineVector;
begin
  Result := False;

  h := PointPlaneDistance(Point, plane);

  if (not bothface) and (h < 0) then
      Exit;

  normal := Vector3fMake(plane);
  inter := VectorAdd(Point, VectorScale(normal, -h));
  Result := True;
end;

// PointPlaneProjection
//
function PointPlaneProjection(const Point, direction: TAffineVector; const plane: THmgPlane;
  var inter: TAffineVector; bothface: Boolean): Boolean;
var
  h, dot: Single;
  normal: TAffineVector;
begin
  Result := False;

  normal := Vector3fMake(plane);
  dot := VectorDotProduct(VectorNormalize(direction), normal);

  if (not bothface) and (dot > 0) then
      Exit;

  if Abs(dot) >= 0.000000001 then
    begin
      h := PointPlaneDistance(Point, plane);
      inter := VectorAdd(Point, VectorScale(direction, -h / dot));
      Result := True;
    end;
end;

// SegmentPlaneIntersection
//
function SegmentPlaneIntersection(const ptA, ptB: TAffineVector; const plane: THmgPlane; var inter: TAffineVector): Boolean;
var
  hA, hB, dot: Single;
  normal, direction: TVector3f;
begin
  Result := False;
  hA := PointPlaneDistance(ptA, plane);
  hB := PointPlaneDistance(ptB, plane);
  if hA * hB <= 0 then
    begin
      normal := Vector3fMake(plane);
      direction := VectorNormalize(VectorSubtract(ptB, ptA));
      dot := VectorDotProduct(direction, normal);
      if Abs(dot) >= 0.000000001 then
        begin
          inter := VectorAdd(ptA, VectorScale(direction, -hA / dot));
          Result := True;
        end;
    end;
end;

// PointTriangleOrthoProjection
//
function PointTriangleOrthoProjection(const Point, ptA, ptB, ptC: TAffineVector;
  var inter: TAffineVector; bothface: Boolean): Boolean;
var
  plane: THmgPlane;
begin
  Result := False;

  plane := PlaneMake(ptA, ptB, ptC);
  if not IsLineIntersectTriangle(Point, Vector3fMake(plane), ptA, ptB, ptC) then
      Exit;

  Result := PointPlaneOrthoProjection(Point, plane, inter, bothface);
end;

// PointTriangleProjection
//
function PointTriangleProjection(const Point, direction, ptA, ptB, ptC: TAffineVector;
  var inter: TAffineVector; bothface: Boolean): Boolean;
var
  plane: THmgPlane;
begin
  Result := False;

  if not IsLineIntersectTriangle(Point, direction, ptA, ptB, ptC) then
      Exit;

  plane := PlaneMake(ptA, ptB, ptC);
  Result := PointPlaneProjection(Point, direction, plane, inter, bothface);
end;

// IsLineIntersectTriangle
//
function IsLineIntersectTriangle(const Point, direction, ptA, ptB, ptC: TAffineVector): Boolean;
var
  PA, PB, PC: TAffineVector;
  crossAB, crossBC, crossCA: TAffineVector;
begin
  Result := False;

  PA := VectorSubtract(ptA, Point);
  PB := VectorSubtract(ptB, Point);
  PC := VectorSubtract(ptC, Point);

  crossAB := VectorCrossProduct(PA, PB);
  crossBC := VectorCrossProduct(PB, PC);

  if VectorDotProduct(crossAB, direction) > 0 then
    begin
      if VectorDotProduct(crossBC, direction) > 0 then
        begin
          crossCA := VectorCrossProduct(PC, PA);
          if VectorDotProduct(crossCA, direction) > 0 then
              Result := True;
        end;
    end
  else
    if VectorDotProduct(crossBC, direction) < 0 then
    begin
      crossCA := VectorCrossProduct(PC, PA);
      if VectorDotProduct(crossCA, direction) < 0 then
          Result := True;
    end
end;

// PointQuadOrthoProjection
//
function PointQuadOrthoProjection(const Point, ptA, ptB, ptC, ptD: TAffineVector; var inter: TAffineVector; bothface: Boolean): Boolean;
var
  plane: THmgPlane;
begin
  Result := False;

  plane := PlaneMake(ptA, ptB, ptC);
  if not IsLineIntersectQuad(Point, Vector3fMake(plane), ptA, ptB, ptC, ptD) then
      Exit;

  Result := PointPlaneOrthoProjection(Point, plane, inter, bothface);
end;

// PointQuadProjection
//
function PointQuadProjection(const Point, direction, ptA, ptB, ptC, ptD: TAffineVector; var inter: TAffineVector; bothface: Boolean): Boolean;
var
  plane: THmgPlane;
begin
  Result := False;

  if not IsLineIntersectQuad(Point, direction, ptA, ptB, ptC, ptD) then
      Exit;

  plane := PlaneMake(ptA, ptB, ptC);
  Result := PointPlaneProjection(Point, direction, plane, inter, bothface);
end;

// IsLineIntersectQuad
//
function IsLineIntersectQuad(const Point, direction, ptA, ptB, ptC, ptD: TAffineVector): Boolean;
var
  PA, PB, PC, PD: TAffineVector;
  crossAB, crossBC, crossCD, crossDA: TAffineVector;
begin
  Result := False;

  PA := VectorSubtract(ptA, Point);
  PB := VectorSubtract(ptB, Point);
  PC := VectorSubtract(ptC, Point);
  PD := VectorSubtract(ptD, Point);

  crossAB := VectorCrossProduct(PA, PB);
  crossBC := VectorCrossProduct(PB, PC);

  if VectorDotProduct(crossAB, direction) > 0 then
    begin
      if VectorDotProduct(crossBC, direction) > 0 then
        begin
          crossCD := VectorCrossProduct(PC, PD);
          if VectorDotProduct(crossCD, direction) > 0 then
            begin
              crossDA := VectorCrossProduct(PD, PA);
              if VectorDotProduct(crossDA, direction) > 0 then
                  Result := True;
            end;
        end;
    end
  else
    if VectorDotProduct(crossBC, direction) < 0 then
    begin
      crossCD := VectorCrossProduct(PC, PD);
      if VectorDotProduct(crossCD, direction) < 0 then
        begin
          crossDA := VectorCrossProduct(PD, PA);
          if VectorDotProduct(crossDA, direction) < 0 then
              Result := True;
        end;
    end
end;

// PointDiskOrthoProjection
//
function PointDiskOrthoProjection(const Point, center, up: TAffineVector; const radius: Single; var inter: TAffineVector; bothface: Boolean): Boolean;
begin
  if PointPlaneOrthoProjection(Point, PlaneMake(center, up), inter, bothface) then
      Result := (VectorDistance2(inter, center) <= radius * radius)
  else
      Result := False;
end;

// PointDiskProjection
//
function PointDiskProjection(const Point, direction, center, up: TAffineVector; const radius: Single; var inter: TAffineVector; bothface: Boolean): Boolean;
begin
  if PointPlaneProjection(Point, direction, PlaneMake(center, up), inter, bothface) then
      Result := VectorDistance2(inter, center) <= radius * radius
  else
      Result := False;
end;

// PointLineClosestPoint
//
function PointLineClosestPoint(const Point, linePoint, lineDirection: TAffineVector): TAffineVector;
var
  w: TAffineVector;
  c1, c2, b: Single;
begin
  w := VectorSubtract(Point, linePoint);

  c1 := VectorDotProduct(w, lineDirection);
  c2 := VectorDotProduct(lineDirection, lineDirection);
  b := c1 / c2;

  VectorAdd(linePoint, VectorScale(lineDirection, b), Result);
end;

// PointLineDistance
//
function PointLineDistance(const Point, linePoint, lineDirection: TAffineVector): Single;
var
  PB: TAffineVector;
begin
  PB := PointLineClosestPoint(Point, linePoint, lineDirection);
  Result := VectorDistance(Point, PB);
end;

// PointSegmentClosestPoint
//
function PointSegmentClosestPoint(const Point, segmentStart, segmentStop: TVector): TVector;
var
  w, lineDirection: TVector;
  c1, c2, b: Single;
begin
  lineDirection := VectorSubtract(segmentStop, segmentStart);
  w := VectorSubtract(Point, segmentStart);

  c1 := VectorDotProduct(w, lineDirection);
  c2 := VectorDotProduct(lineDirection, lineDirection);
  b := ClampValue(c1 / c2, 0, 1);

  VectorAdd(segmentStart, VectorScale(lineDirection, b), Result);
end;

// PointSegmentClosestPoint
//
function PointSegmentClosestPoint(const Point, segmentStart, segmentStop: TAffineVector): TAffineVector;
var
  w, lineDirection: TAffineVector;
  c1, c2, b: Single;
begin
  lineDirection := VectorSubtract(segmentStop, segmentStart);
  w := VectorSubtract(Point, segmentStart);

  c1 := VectorDotProduct(w, lineDirection);
  c2 := VectorDotProduct(lineDirection, lineDirection);
  b := ClampValue(c1 / c2, 0, 1);

  VectorAdd(segmentStart, VectorScale(lineDirection, b), Result);
end;

// PointSegmentDistance
//
function PointSegmentDistance(const Point, segmentStart, segmentStop: TAffineVector): Single;
var
  PB: TAffineVector;
begin
  PB := PointSegmentClosestPoint(Point, segmentStart, segmentStop);
  Result := VectorDistance(Point, PB);
end;

// http://geometryalgorithms.com/Archive/algorithm_0104/algorithm_0104B.htm
// SegmentSegmentClosestPoint
//
procedure SegmentSegmentClosestPoint(const S0Start, S0Stop, S1Start, S1Stop: TAffineVector; var Segment0Closest, Segment1Closest: TAffineVector);
const
  cSMALL_NUM = 0.000000001;
var
  u, v, w: TAffineVector;
  a, b, c, smalld, E, largeD, sc, sn, sD, tc, tN, tD: Single;
begin
  VectorSubtract(S0Stop, S0Start, u);
  VectorSubtract(S1Stop, S1Start, v);
  VectorSubtract(S0Start, S1Start, w);

  a := VectorDotProduct(u, u);
  b := VectorDotProduct(u, v);
  c := VectorDotProduct(v, v);
  smalld := VectorDotProduct(u, w);
  E := VectorDotProduct(v, w);
  largeD := a * c - b * b;

  sD := largeD;
  tD := largeD;

  if largeD < cSMALL_NUM then
    begin
      sn := 0.0;
      sD := 1.0;
      tN := E;
      tD := c;
    end
  else
    begin
      sn := (b * E - c * smalld);
      tN := (a * E - b * smalld);
      if (sn < 0.0) then
        begin
          sn := 0.0;
          tN := E;
          tD := c;
        end
      else if (sn > sD) then
        begin
          sn := sD;
          tN := E + b;
          tD := c;
        end;
    end;

  if (tN < 0.0) then
    begin
      tN := 0.0;
      // recompute sc for this edge
      if (-smalld < 0.0) then
          sn := 0.0
      else if (-smalld > a) then
          sn := sD
      else
        begin
          sn := -smalld;
          sD := a;
        end;
    end
  else if (tN > tD) then
    begin
      tN := tD;
      // recompute sc for this edge
      if ((-smalld + b) < 0.0) then
          sn := 0
      else if ((-smalld + b) > a) then
          sn := sD
      else
        begin
          sn := (-smalld + b);
          sD := a;
        end;
    end;

  // finally do the division to get sc and tc
  // sc := (abs(sN) < SMALL_NUM ? 0.0 : sN / sD);
  if Abs(sn) < cSMALL_NUM then
      sc := 0
  else
      sc := sn / sD;

  // tc := (abs(tN) < SMALL_NUM ? 0.0 : tN / tD);
  if Abs(tN) < cSMALL_NUM then
      tc := 0
  else
      tc := tN / tD;

  // get the difference of the two closest points
  // Vector   dP = w + (sc * u) - (tc * v);  // = S0(sc) - S1(tc)

  Segment0Closest := VectorAdd(S0Start, VectorScale(u, sc));
  Segment1Closest := VectorAdd(S1Start, VectorScale(v, tc));
end;

// SegmentSegmentDistance
//
function SegmentSegmentDistance(const S0Start, S0Stop, S1Start, S1Stop: TAffineVector): Single;
var
  Pb0, PB1: TAffineVector;
begin
  SegmentSegmentClosestPoint(S0Start, S0Stop, S1Start, S1Stop, Pb0, PB1);
  Result := VectorDistance(Pb0, PB1);
end;

// LineLineDistance
//
function LineLineDistance(const linePt0, lineDir0, linePt1, lineDir1: TAffineVector): Single;
const
  cBIAS = 0.000000001;
var
  det: Single;
begin
  det := Abs((linePt1[0] - linePt0[0]) * (lineDir0[1] * lineDir1[2] - lineDir1[1] * lineDir0[2]) -
      (linePt1[1] - linePt0[1]) * (lineDir0[0] * lineDir1[2] - lineDir1[0] * lineDir0[2]) +
      (linePt1[2] - linePt0[2]) * (lineDir0[0] * lineDir1[1] - lineDir1[0] * lineDir0[1]));
  if det < cBIAS then
      Result := PointLineDistance(linePt0, linePt1, lineDir1)
  else
      Result := det / VectorLength(VectorCrossProduct(lineDir0, lineDir1));
end;

// QuaternionMake
//
function QuaternionMake(const Imag: array of Single; Real: Single): TQuaternion;
var
  n: Integer;
begin
  n := length(Imag);
  if n >= 1 then
      Result.ImagPart[0] := Imag[0];
  if n >= 2 then
      Result.ImagPart[1] := Imag[1];
  if n >= 3 then
      Result.ImagPart[2] := Imag[2];
  Result.RealPart := Real;
end;

// QuaternionConjugate
//
function QuaternionConjugate(const q: TQuaternion): TQuaternion;
begin
  Result.ImagPart[0] := -q.ImagPart[0];
  Result.ImagPart[1] := -q.ImagPart[1];
  Result.ImagPart[2] := -q.ImagPart[2];
  Result.RealPart := q.RealPart;
end;

// QuaternionMagnitude
//
function QuaternionMagnitude(const q: TQuaternion): Single;
begin
  Result := Sqrt(VectorNorm(q.ImagPart) + Sqr(q.RealPart));
end;

// NormalizeQuaternion
//
procedure NormalizeQuaternion(var q: TQuaternion);
var
  M, f: Single;
begin
  M := QuaternionMagnitude(q);
  if M > EPSILON2 then
    begin
      f := 1 / M;
      ScaleVector(q.ImagPart, f);
      q.RealPart := q.RealPart * f;
    end
  else
      q := IdentityQuaternion;
end;

// QuaternionFromPoints
//
function QuaternionFromPoints(const v1, v2: TAffineVector): TQuaternion;
begin
  Result.ImagPart := VectorCrossProduct(v1, v2);
  Result.RealPart := Sqrt((VectorDotProduct(v1, v2) + 1) / 2);
end;

// QuaternionFromMatrix
//
function QuaternionFromMatrix(const mat: TMatrix): TQuaternion;
// the matrix must be a rotation matrix!
var
  traceMat, s, invS: Double;
begin
  traceMat := 1 + mat[0, 0] + mat[1, 1] + mat[2, 2];
  if traceMat > EPSILON2 then
    begin
      s := Sqrt(traceMat) * 2;
      invS := 1 / s;
      Result.ImagPart[0] := (mat[1, 2] - mat[2, 1]) * invS;
      Result.ImagPart[1] := (mat[2, 0] - mat[0, 2]) * invS;
      Result.ImagPart[2] := (mat[0, 1] - mat[1, 0]) * invS;
      Result.RealPart := 0.25 * s;
    end
  else if (mat[0, 0] > mat[1, 1]) and (mat[0, 0] > mat[2, 2]) then
    begin // Row 0:
      s := Sqrt(MaxFloat(EPSILON2, cOne + mat[0, 0] - mat[1, 1] - mat[2, 2])) * 2;
      invS := 1 / s;
      Result.ImagPart[0] := 0.25 * s;
      Result.ImagPart[1] := (mat[0, 1] + mat[1, 0]) * invS;
      Result.ImagPart[2] := (mat[2, 0] + mat[0, 2]) * invS;
      Result.RealPart := (mat[1, 2] - mat[2, 1]) * invS;
    end
  else if (mat[1, 1] > mat[2, 2]) then
    begin // Row 1:
      s := Sqrt(MaxFloat(EPSILON2, cOne + mat[1, 1] - mat[0, 0] - mat[2, 2])) * 2;
      invS := 1 / s;
      Result.ImagPart[0] := (mat[0, 1] + mat[1, 0]) * invS;
      Result.ImagPart[1] := 0.25 * s;
      Result.ImagPart[2] := (mat[1, 2] + mat[2, 1]) * invS;
      Result.RealPart := (mat[2, 0] - mat[0, 2]) * invS;
    end
  else
    begin // Row 2:
      s := Sqrt(MaxFloat(EPSILON2, cOne + mat[2, 2] - mat[0, 0] - mat[1, 1])) * 2;
      invS := 1 / s;
      Result.ImagPart[0] := (mat[2, 0] + mat[0, 2]) * invS;
      Result.ImagPart[1] := (mat[1, 2] + mat[2, 1]) * invS;
      Result.ImagPart[2] := 0.25 * s;
      Result.RealPart := (mat[0, 1] - mat[1, 0]) * invS;
    end;
  NormalizeQuaternion(Result);
end;

// QuaternionMultiply
//
function QuaternionMultiply(const qL, qR: TQuaternion): TQuaternion;
var
  Temp: TQuaternion;
begin
  Temp.RealPart := qL.RealPart * qR.RealPart - qL.ImagPart[x] * qR.ImagPart[x]
    - qL.ImagPart[y] * qR.ImagPart[y] - qL.ImagPart[Z] * qR.ImagPart[Z];
  Temp.ImagPart[x] := qL.RealPart * qR.ImagPart[x] + qL.ImagPart[x] * qR.RealPart
    + qL.ImagPart[y] * qR.ImagPart[Z] - qL.ImagPart[Z] * qR.ImagPart[y];
  Temp.ImagPart[y] := qL.RealPart * qR.ImagPart[y] + qL.ImagPart[y] * qR.RealPart
    + qL.ImagPart[Z] * qR.ImagPart[x] - qL.ImagPart[x] * qR.ImagPart[Z];
  Temp.ImagPart[Z] := qL.RealPart * qR.ImagPart[Z] + qL.ImagPart[Z] * qR.RealPart
    + qL.ImagPart[x] * qR.ImagPart[y] - qL.ImagPart[y] * qR.ImagPart[x];
  Result := Temp;
end;

// QuaternionToMatrix
//
function QuaternionToMatrix(quat: TQuaternion): TMatrix;
var
  w, x, y, Z, xx, xy, xz, xw, yy, yz, yw, zz, zw: Single;
begin
  NormalizeQuaternion(quat);
  w := quat.RealPart;
  x := quat.ImagPart[0];
  y := quat.ImagPart[1];
  Z := quat.ImagPart[2];
  xx := x * x;
  xy := x * y;
  xz := x * Z;
  xw := x * w;
  yy := y * y;
  yz := y * Z;
  yw := y * w;
  zz := Z * Z;
  zw := Z * w;
  Result[0, 0] := 1 - 2 * (yy + zz);
  Result[1, 0] := 2 * (xy - zw);
  Result[2, 0] := 2 * (xz + yw);
  Result[3, 0] := 0;
  Result[0, 1] := 2 * (xy + zw);
  Result[1, 1] := 1 - 2 * (xx + zz);
  Result[2, 1] := 2 * (yz - xw);
  Result[3, 1] := 0;
  Result[0, 2] := 2 * (xz - yw);
  Result[1, 2] := 2 * (yz + xw);
  Result[2, 2] := 1 - 2 * (xx + yy);
  Result[3, 2] := 0;
  Result[0, 3] := 0;
  Result[1, 3] := 0;
  Result[2, 3] := 0;
  Result[3, 3] := 1;
end;

// QuaternionToAffineMatrix
//
function QuaternionToAffineMatrix(quat: TQuaternion): TAffineMatrix;
var
  w, x, y, Z, xx, xy, xz, xw, yy, yz, yw, zz, zw: Single;
begin
  NormalizeQuaternion(quat);
  w := quat.RealPart;
  x := quat.ImagPart[0];
  y := quat.ImagPart[1];
  Z := quat.ImagPart[2];
  xx := x * x;
  xy := x * y;
  xz := x * Z;
  xw := x * w;
  yy := y * y;
  yz := y * Z;
  yw := y * w;
  zz := Z * Z;
  zw := Z * w;
  Result[0, 0] := 1 - 2 * (yy + zz);
  Result[1, 0] := 2 * (xy - zw);
  Result[2, 0] := 2 * (xz + yw);
  Result[0, 1] := 2 * (xy + zw);
  Result[1, 1] := 1 - 2 * (xx + zz);
  Result[2, 1] := 2 * (yz - xw);
  Result[0, 2] := 2 * (xz - yw);
  Result[1, 2] := 2 * (yz + xw);
  Result[2, 2] := 1 - 2 * (xx + yy);
end;

// QuaternionFromAngleAxis
//
function QuaternionFromAngleAxis(const angle: Single; const axis: TAffineVector): TQuaternion;
var
  f, s, c: Single;
begin
  SinCos_(DegToRad_(angle * cOneDotFive), s, c);
  Result.RealPart := c;
  f := s / VectorLength(axis);
  Result.ImagPart[0] := axis[0] * f;
  Result.ImagPart[1] := axis[1] * f;
  Result.ImagPart[2] := axis[2] * f;
end;

// QuaternionFromRollPitchYaw
//
function QuaternionFromRollPitchYaw(const r, p, y: Single): TQuaternion;
var
  qp, qy: TQuaternion;
begin
  Result := QuaternionFromAngleAxis(r, ZVector);
  qp := QuaternionFromAngleAxis(p, XVector);
  qy := QuaternionFromAngleAxis(y, YVector);

  Result := QuaternionMultiply(qp, Result);
  Result := QuaternionMultiply(qy, Result);
end;

// QuaternionFromEuler
//
function QuaternionFromEuler(const x, y, Z: Single; eulerOrder: TEulerOrder): TQuaternion;
// input angles in degrees
var
  gimbalLock: Boolean;
  quat1, quat2: TQuaternion;

  function EulerToQuat(const x, y, Z: Single; eulerOrder: TEulerOrder): TQuaternion;
  const
    cOrder: array [low(TEulerOrder) .. high(TEulerOrder)] of array [1 .. 3] of Byte =
      ((1, 2, 3), (1, 3, 2), (2, 1, 3), // eulXYZ, eulXZY, eulYXZ,
      (3, 1, 2), (2, 3, 1), (3, 2, 1)); // eulYZX, eulZXY, eulZYX
  var
    q: array [1 .. 3] of TQuaternion;
  begin
    q[cOrder[eulerOrder][1]] := QuaternionFromAngleAxis(x, XVector);
    q[cOrder[eulerOrder][2]] := QuaternionFromAngleAxis(y, YVector);
    q[cOrder[eulerOrder][3]] := QuaternionFromAngleAxis(Z, ZVector);
    Result := QuaternionMultiply(q[2], q[3]);
    Result := QuaternionMultiply(q[1], Result);
  end;

const
  SMALL_ANGLE = 0.001;
begin
  NormalizeDegAngle(x);
  NormalizeDegAngle(y);
  NormalizeDegAngle(Z);
  case eulerOrder of
    eulXYZ, eulZYX: gimbalLock := Abs(Abs(y) - 90.0) <= EPSILON2; // cos(Y) = 0;
    eulYXZ, eulZXY: gimbalLock := Abs(Abs(x) - 90.0) <= EPSILON2; // cos(X) = 0;
    eulXZY, eulYZX: gimbalLock := Abs(Abs(Z) - 90.0) <= EPSILON2; // cos(Z) = 0;
    else
        Assert(False);
      gimbalLock := False;
  end;
  if gimbalLock then
    begin
      case eulerOrder of
        eulXYZ, eulZYX: quat1 := EulerToQuat(x, y - SMALL_ANGLE, Z, eulerOrder);
        eulYXZ, eulZXY: quat1 := EulerToQuat(x - SMALL_ANGLE, y, Z, eulerOrder);
        eulXZY, eulYZX: quat1 := EulerToQuat(x, y, Z - SMALL_ANGLE, eulerOrder);
      end;
      case eulerOrder of
        eulXYZ, eulZYX: quat2 := EulerToQuat(x, y + SMALL_ANGLE, Z, eulerOrder);
        eulYXZ, eulZXY: quat2 := EulerToQuat(x + SMALL_ANGLE, y, Z, eulerOrder);
        eulXZY, eulYZX: quat2 := EulerToQuat(x, y, Z + SMALL_ANGLE, eulerOrder);
      end;
      Result := QuaternionSlerp(quat1, quat2, 0.5);
    end
  else
    begin
      Result := EulerToQuat(x, y, Z, eulerOrder);
    end;
end;

// QuaternionToPoints
//
procedure QuaternionToPoints(const q: TQuaternion; var ArcFrom, ArcTo: TAffineVector);
var
  s, invS: Single;
begin
  s := q.ImagPart[x] * q.ImagPart[x] + q.ImagPart[y] * q.ImagPart[y];
  if s = 0 then
      SetAffineVector(ArcFrom, 0, 1, 0)
  else
    begin
      invS := RSqrt(s);
      SetAffineVector(ArcFrom, -q.ImagPart[y] * invS, q.ImagPart[x] * invS, 0);
    end;
  ArcTo[x] := q.RealPart * ArcFrom[x] - q.ImagPart[Z] * ArcFrom[y];
  ArcTo[y] := q.RealPart * ArcFrom[y] + q.ImagPart[Z] * ArcFrom[x];
  ArcTo[Z] := q.ImagPart[x] * ArcFrom[y] - q.ImagPart[y] * ArcFrom[x];
  if q.RealPart < 0 then
      SetAffineVector(ArcFrom, -ArcFrom[x], -ArcFrom[y], 0);
end;

function IsNan(const Value_: Single): Boolean;
begin
  Result := Math.IsNan(Value_);
end;

function IsNan(const Value_: Double): Boolean;
begin
  Result := Math.IsNan(Value_);
end;

// LnXP1_
//
function LnXP1_(x: Double): Double;
begin
  Result := Math.LnXP1(x);
end;

// Log10_
//
function Log10_(x: Double): Double;
begin
  Result := Math.Log10(x);
end;

// Log2_
//
function Log2_(x: Double): Double;
begin
  Result := Math.Log2(x);
end;

// Log2_
//
function Log2_(x: Single): Single;
begin
  Result := Math.Log2(x);
end;

// LogN_
//
function LogN_(Base, x: Double): Double;
begin
  Result := Math.LogN(Base, x);
end;

// IntPower_
//
function IntPower_(Base: Double; Exponent: Integer): Double;
begin
  Result := Math.IntPower(Base, Exponent);
end;

// Power_
//
function Power_(const Base, Exponent: Single): Single;
begin
  if Exponent = cZero then
      Result := cOne
  else if (Base = cZero) and (Exponent > cZero) then
      Result := cZero
  else if RoundInt(Exponent) = Exponent then
      Result := Power_(Base, Integer(Round(Exponent)))
  else
      Result := Exp(Exponent * ln(Base));
end;

// Power_ (int exponent)
//
function Power_(Base: Single; Exponent: Integer): Single;
begin
  Result := Math.Power(Base, Exponent);
end;

function Power_(Base: Single; Exponent: Int64): Single;
begin
  Result := Math.Power(Base, Exponent);
end;

// DegToRad_ (Double)
//
function DegToRad_(const Degrees: Double): Double;
begin
  Result := Degrees * (pi / 180);
end;

// DegToRad_ (Single)
//
function DegToRad_(const Degrees: Single): Single;
// Result:=Degrees * cPIdiv180;
// don't laugh, Delphi's compiler manages to make a nightmare of this one
// with pushs, pops, etc. in its default compile... (this one is twice faster !)
begin
  Result := Degrees * cPIdiv180;
end;

// RadToDeg_ (Double)
//
function RadToDeg_(const Radians: Double): Double;
begin
  Result := Radians * (180 / pi);
end;

// RadToDeg_ (Single)
//
function RadToDeg_(const Radians: Single): Single;
// Result:=Radians * c180divPI;
// don't laugh, Delphi's compiler manages to make a nightmare of this one
// with pushs, pops, etc. in its default compile... (this one is twice faster !)
begin
  Result := Radians * c180divPI;
end;

// NormalizeAngle
//
function NormalizeAngle(angle: Single): Single;
begin
  Result := angle - Int(angle * cInv2PI) * c2PI;
  if Result > pi then
      Result := Result - 2 * pi
  else if Result < -pi then
      Result := Result + 2 * pi;
end;

// NormalizeDegAngle
//
function NormalizeDegAngle(angle: Single): Single;
begin
  Result := angle - Int(angle * cInv360) * c360;
  if Result > c180 then
      Result := Result - c360
  else if Result < -c180 then
      Result := Result + c360;
end;

// SinCos_ (Double)
//
procedure SinCos_(const Theta: Double; out Sin, Cos: Double);
begin
  Math.SinCos(Theta, Sin, Cos);
end;

// SinCos_ (Single)
//
procedure SinCos_(const Theta: Single; out Sin, Cos: Single);
var
  s, c: Double;
begin
  Math.SinCos(Theta, s, c);
  Sin := s;
  Cos := c;
end;

// SinCos_ (Double w radius)
//
procedure SinCos_(const Theta, radius: Double; out Sin, Cos: Double);
var
  s, c: Double;
begin
  Math.SinCos(Theta, s, c);
  Sin := s * radius;
  Cos := c * radius;
end;

// SinCos_ (Single w radius)
//
procedure SinCos_(const Theta, radius: Single; out Sin, Cos: Single);
var
  s, c: Double;
begin
  Math.SinCos(Theta, s, c);
  Sin := s * radius;
  Cos := c * radius;
end;

// PrepareSinCosCache
//
procedure PrepareSinCosCache(var s, c: array of Single; startAngle, stopAngle: Single);
var
  i: Integer;
  d, alpha, beta: Single;
begin
  Assert((high(s) = high(c)) and (low(s) = low(c)));
  stopAngle := stopAngle + 1E-5;
  if high(s) > low(s) then
      d := cPIdiv180 * (stopAngle - startAngle) / (high(s) - low(s))
  else
      d := 0;

  if high(s) - low(s) < 1000 then
    begin
      // Fast computation (approx 5.5x)
      alpha := 2 * Sqr(Sin(d * 0.5));
      beta := Sin(d);
      SinCos_(startAngle * cPIdiv180, s[low(s)], c[low(s)]);
      for i := low(s) to high(s) - 1 do
        begin
          // Make use of the incremental formulae:
          // cos (theta+delta) = cos(theta) - [alpha*cos(theta) + beta*sin(theta)]
          // sin (theta+delta) = sin(theta) - [alpha*sin(theta) - beta*cos(theta)]
          c[i + 1] := c[i] - alpha * c[i] - beta * s[i];
          s[i + 1] := s[i] - alpha * s[i] + beta * c[i];
        end;
    end
  else
    begin
      // Slower, but maintains precision when steps are small
      startAngle := startAngle * cPIdiv180;
      for i := low(s) to high(s) do
          SinCos_((i - low(s)) * d + startAngle, s[i], c[i]);
    end;
end;

// ArcCos_ (Double)
//
function ArcCos_(const x: Double): Double;
begin
  Result := ArcTan2_(Sqrt(1 - Sqr(x)), x);
end;

// ArcCos_ (Single)
//
function ArcCos_(const x: Single): Single;
// Result:=ArcTan2_(Sqrt(c1 - X * X), X);
begin
{$IFDEF FPC}
  if Abs(x) > 1.0 then
      Result := Math.ArcCos(Sign(x))
  else
{$ENDIF}
      Result := Math.ArcCos(x);
end;

// ArcSin_ (Double)
//
function ArcSin_(const x: Double): Double;
begin
  Result := ArcTan2_(x, Sqrt(1 - Sqr(x)))
end;

// ArcSin_ (Single)
//
function ArcSin_(const x: Single): Single;
// Result:=ArcTan2_(X, Sqrt(1 - X * X))
begin
  Result := Math.ArcSin(x);
end;

// ArcTan2_ (Double)
//
function ArcTan2_(const y, x: Double): Double;
begin
  Result := Math.ArcTan2(y, x);
end;

// ArcTan2_ (Single)
//
function ArcTan2_(const y, x: Single): Single;
begin
  Result := Math.ArcTan2(y, x);
end;

// FastArcTan2
//
function FastArcTan2(y, x: Single): Single;
// accuracy of about 0.07 rads
var
  abs_y: Single;
begin
  abs_y := Abs(y) + cEpsilon; // prevent 0/0 condition
  if y < 0 then
    begin
      if x >= 0 then
          Result := cPIdiv4 * (x - abs_y) / (x + abs_y) - cPIdiv4
      else
          Result := cPIdiv4 * (x + abs_y) / (abs_y - x) - c3PIdiv4;
    end
  else
    begin
      if x >= 0 then
          Result := cPIdiv4 - cPIdiv4 * (x - abs_y) / (x + abs_y)
      else
          Result := c3PIdiv4 - cPIdiv4 * (x + abs_y) / (abs_y - x);
    end;
end;

// Tan_ (Double)
//
function Tan_(const x: Double): Double;
begin
  Result := Math.Tan(x);
end;

// Tan_ (Single)
//
function Tan_(const x: Single): Single;
begin
  Result := Math.Tan(x);
end;

// CoTan_ (Double)
//
function CoTan_(const x: Double): Double;
begin
  Result := Math.CoTan(x);
end;

// CoTan_ (Single)
//
function CoTan_(const x: Single): Single;
begin
  Result := Math.CoTan(x);
end;

// Sinh
//
function Sinh(const x: Single): Single;
begin
  Result := 0.5 * (Exp(x) - Exp(-x));
end;

// Sinh
//
function Sinh(const x: Double): Double;
begin
  Result := 0.5 * (Exp(x) - Exp(-x));
end;

// Cosh
//
function Cosh(const x: Single): Single;
begin
  Result := 0.5 * (Exp(x) + Exp(-x));
end;

// Cosh
//
function Cosh(const x: Double): Double;
begin
  Result := 0.5 * (Exp(x) + Exp(-x));
end;

// RSqrt
//
function RSqrt(v: Single): Single;
begin
  Result := 1 / Sqrt(v);
end;

// ISqrt
//
function ISqrt(i: Integer): Integer;
begin
  Result := Round(Sqrt(i));
end;

// ILength
//
function ILength(x, y: Integer): Integer;
begin
  Result := Round(Sqrt(x * x + y * y));
end;

// ILength
//
function ILength(x, y, Z: Integer): Integer;
begin
  Result := Round(Sqrt(x * x + y * y + Z * Z));
end;

// RLength
//
function RLength(x, y: Single): Single;
begin
  Result := 1 / Sqrt(x * x + y * y);
end;

// RandomPointOnSphere
//
procedure RandomPointOnSphere(var p: TAffineVector);
var
  t, w: Single;
begin
  p[2] := 2 * MT19937RandF - 1;
  t := 2 * pi * MT19937RandF;
  w := Sqrt(1 - p[2] * p[2]);
  SinCos_(t, w, p[1], p[0]);
end;

// RoundInt (Single)
//
function RoundInt(v: Single): Single;
begin
  Result := Int(v + cOneDotFive);
end;

// RoundInt (Double)
//
function RoundInt(v: Double): Double;
begin
  Result := Int(v + 0.5);
end;

function Trunc(x: Double): Int64;
begin
  Result := System.Trunc(x);
end;

function Round(x: Double): Int64;
begin
  Result := System.Round(x);
end;

function Frac(x: Double): Double;
begin
  Result := System.Frac(x);
end;

// Ceil64 (Double)
//
function Ceil64(v: Double): Int64;
begin
  if Frac(v) > 0 then
      Result := Trunc(v) + 1
  else
      Result := Trunc(v);
end;

// Ceil (Single)
//
function Ceil(v: Single): Integer;
begin
  if Frac(v) > 0 then
      Result := Trunc(v) + 1
  else
      Result := Trunc(v);
end;

// Floor64 (Double)
//
function Floor64(v: Double): Int64;
begin
  if v < 0 then
      Result := Trunc(v) - 1
  else
      Result := Trunc(v);
end;

// Floor (Single)
//
function Floor(v: Single): Integer;
begin
  if v < 0 then
      Result := Trunc(v) - 1
  else
      Result := Trunc(v);
end;

// Sign
//
function Sign(x: Single): Integer;
begin
  if x < 0 then
      Result := -1
  else if x > 0 then
      Result := 1
  else
      Result := 0;
end;

// SignStrict
//
function SignStrict(x: Single): Integer;
begin
  if x < 0 then
      Result := -1
  else
      Result := 1
end;

// ScaleAndRound
//
function ScaleAndRound(i: Integer; var s: Single): Integer;
begin
  Result := Round(i * s);
end;

// IsInRange (Single)
//
function IsInRange(const x, a, b: Single): Boolean;
begin
  if a < b then
      Result := (a <= x) and (x <= b)
  else
      Result := (b <= x) and (x <= a);
end;

// IsInRange (double)
//
function IsInRange(const x, a, b: Double): Boolean;
begin
  if a < b then
      Result := (a <= x) and (x <= b)
  else
      Result := (b <= x) and (x <= a);
end;

// IsInCube (affine)
//
function IsInCube(const p, d: TAffineVector): Boolean;
begin
  Result := ((p[0] >= -d[0]) and (p[0] <= d[0]))
    and ((p[1] >= -d[1]) and (p[1] <= d[1]))
    and ((p[2] >= -d[2]) and (p[2] <= d[2]));
end;

// IsInCube (hmg)
//
function IsInCube(const p, d: TVector): Boolean;
begin
  Result := ((p[0] >= -d[0]) and (p[0] <= d[0]))
    and ((p[1] >= -d[1]) and (p[1] <= d[1]))
    and ((p[2] >= -d[2]) and (p[2] <= d[2]));
end;

// MinFloat (Single)
//
function MinFloat(values: PSingleArray; nbItems: Integer): Single;
var
  i, k: Integer;
begin
  if nbItems > 0 then
    begin
      k := 0;
      for i := 1 to nbItems - 1 do
        if values^[i] < values^[k] then
            k := i;
      Result := values^[k];
    end
  else
      Result := 0;
end;

// MinFloat (double)
//
function MinFloat(values: PDoubleArray; nbItems: Integer): Double;
var
  i, k: Integer;
begin
  if nbItems > 0 then
    begin
      k := 0;
      for i := 1 to nbItems - 1 do
        if values^[i] < values^[k] then
            k := i;
      Result := values^[k];
    end
  else
      Result := 0;
end;

// MinFloat (array)
//
function MinFloat(const v: array of Single): Single;
var
  i: Integer;
begin
  if length(v) > 0 then
    begin
      Result := v[0];
      for i := 1 to high(v) do
        if v[i] < Result then
            Result := v[i];
    end
  else
      Result := 0;
end;

// MinFloat (Single 2)
//
function MinFloat(const v1, v2: Single): Single;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

// MinFloat (double 2)
//
function MinFloat(const v1, v2: Double): Double;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

// MinFloat
//
function MinFloat(const v1, v2, v3: Single): Single;
begin
  if v1 <= v2 then
    if v1 <= v3 then
        Result := v1
    else if v3 <= v2 then
        Result := v3
    else
        Result := v2
  else if v2 <= v3 then
      Result := v2
  else if v3 <= v1 then
      Result := v3
  else
      Result := v1;
end;

// MinFloat (double)
//
function MinFloat(const v1, v2, v3: Double): Double;
begin
  if v1 <= v2 then
    if v1 <= v3 then
        Result := v1
    else if v3 <= v2 then
        Result := v3
    else
        Result := v2
  else if v2 <= v3 then
      Result := v2
  else if v3 <= v1 then
      Result := v3
  else
      Result := v1;
end;

// MaxFloat (Single)
//
function MaxFloat(values: PSingleArray; nbItems: Integer): Single;
var
  i, k: Integer;
begin
  if nbItems > 0 then
    begin
      k := 0;
      for i := 1 to nbItems - 1 do
        if values^[i] > values^[k] then
            k := i;
      Result := values^[k];
    end
  else
      Result := 0;
end;

// MaxFloat (double)
//
function MaxFloat(values: PDoubleArray; nbItems: Integer): Double;
var
  i, k: Integer;
begin
  if nbItems > 0 then
    begin
      k := 0;
      for i := 1 to nbItems - 1 do
        if values^[i] > values^[k] then
            k := i;
      Result := values^[k];
    end
  else
      Result := 0;
end;

// MaxFloat
//
function MaxFloat(const v: array of Single): Single;
var
  i: Integer;
begin
  if length(v) > 0 then
    begin
      Result := v[0];
      for i := 1 to high(v) do
        if v[i] > Result then
            Result := v[i];
    end
  else
      Result := 0;
end;

// MaxFloat
//
function MaxFloat(const v1, v2: Single): Single;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

// MaxFloat
//
function MaxFloat(const v1, v2: Double): Double;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

// MaxFloat
//
function MaxFloat(const v1, v2, v3: Single): Single;
begin
  if v1 >= v2 then
    if v1 >= v3 then
        Result := v1
    else if v3 >= v2 then
        Result := v3
    else
        Result := v2
  else if v2 >= v3 then
      Result := v2
  else if v3 >= v1 then
      Result := v3
  else
      Result := v1;
end;

// MaxFloat
//
function MaxFloat(const v1, v2, v3: Double): Double;
begin
  if v1 >= v2 then
    if v1 >= v3 then
        Result := v1
    else if v3 >= v2 then
        Result := v3
    else
        Result := v2
  else if v2 >= v3 then
      Result := v2
  else if v3 >= v1 then
      Result := v3
  else
      Result := v1;
end;

// MinInteger (2 int)
//
function MinInteger(const v1, v2: Integer): Integer;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

// MinInteger (2 card)
//
function MinInteger(const v1, v2: Cardinal): Cardinal;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

// MinInteger
//
function MinInteger(const v1, v2, v3: Integer): Integer;
begin
  if v1 <= v2 then
    if v1 <= v3 then
        Result := v1
    else if v3 <= v2 then
        Result := v3
    else
        Result := v2
  else if v2 <= v3 then
      Result := v2
  else if v3 <= v1 then
      Result := v3
  else
      Result := v1;
end;

// MinInteger
//
function MinInteger(const v1, v2, v3: Cardinal): Cardinal;
begin
  if v1 <= v2 then
    if v1 <= v3 then
        Result := v1
    else if v3 <= v2 then
        Result := v3
    else
        Result := v2
  else if v2 <= v3 then
      Result := v2
  else if v3 <= v1 then
      Result := v3
  else
      Result := v1;
end;

// MaxInteger (2 int)
//
function MaxInteger(const v1, v2: Integer): Integer;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

// MaxInteger (2 card)
//
function MaxInteger(const v1, v2: Cardinal): Cardinal;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

// MaxInteger
//
function MaxInteger(const v1, v2, v3: Integer): Integer;
begin
  if v1 >= v2 then
    if v1 >= v3 then
        Result := v1
    else if v3 >= v2 then
        Result := v3
    else
        Result := v2
  else if v2 >= v3 then
      Result := v2
  else if v3 >= v1 then
      Result := v3
  else
      Result := v1;
end;

// MaxInteger
//
function MaxInteger(const v1, v2, v3: Cardinal): Cardinal;
begin
  if v1 >= v2 then
    if v1 >= v3 then
        Result := v1
    else if v3 >= v2 then
        Result := v3
    else
        Result := v2
  else if v2 >= v3 then
      Result := v2
  else if v3 >= v1 then
      Result := v3
  else
      Result := v1;
end;

function ClampInteger(const Value, Min_, Max_: Integer): Integer;
begin
  Result := MinInteger(MaxInteger(Value, Min_), Max_);
end;

function ClampInteger(const Value, Min_, Max_: Cardinal): Cardinal;
begin
  Result := MinInteger(MaxInteger(Value, Min_), Max_);
end;

// TriangleArea
//
function TriangleArea(const p1, p2, p3: TAffineVector): Single;
begin
  Result := 0.5 * VectorLength(VectorCrossProduct(VectorSubtract(p2, p1), VectorSubtract(p3, p1)));
end;

// PolygonArea
//
function PolygonArea(const p: PAffineVectorArray; nSides: Integer): Single;
var
  r: TAffineVector;
  i: Integer;
  p1, p2, p3: PAffineVector;
begin
  Result := 0;
  if nSides > 2 then
    begin
      RstVector(r);
      p1 := @p^[0];
      p2 := @p^[1];
      for i := 2 to nSides - 1 do
        begin
          p3 := @p^[i];
          AddVector(r, VectorCrossProduct(VectorSubtract(p2^, p1^), VectorSubtract(p3^, p1^)));
          p2 := p3;
        end;
      Result := VectorLength(r) * 0.5;
    end;
end;

// TriangleSignedArea
//
function TriangleSignedArea(const p1, p2, p3: TAffineVector): Single;
begin
  Result := 0.5 * ((p2[0] - p1[0]) * (p3[1] - p1[1]) - (p3[0] - p1[0]) * (p2[1] - p1[1]));
end;

// PolygonSignedArea
//
function PolygonSignedArea(const p: PAffineVectorArray; nSides: Integer): Single;
var
  i: Integer;
  p1, p2, p3: PAffineVector;
begin
  Result := 0;
  if nSides > 2 then
    begin
      p1 := @(p^[0]);
      p2 := @(p^[1]);
      for i := 2 to nSides - 1 do
        begin
          p3 := @(p^[i]);
          Result := Result + (p2^[0] - p1^[0]) * (p3^[1] - p1^[1])
            - (p3^[0] - p1^[0]) * (p2^[1] - p1^[1]);
          p2 := p3;
        end;
      Result := Result * 0.5;
    end;
end;

// ScaleFloatArray (raw)
//
procedure ScaleFloatArray(values: PSingleArray; nb: Integer; var factor: Single);
var
  i: Integer;
begin
  for i := 0 to nb - 1 do
      values^[i] := values^[i] * factor;
end;

// ScaleFloatArray (array)
//
procedure ScaleFloatArray(var values: TSingleArray; factor: Single);
begin
  if length(values) > 0 then
      ScaleFloatArray(@values[0], length(values), factor);
end;

// OffsetFloatArray (raw)
//
procedure OffsetFloatArray(values: PSingleArray; nb: Integer; var Delta: Single);
var
  i: Integer;
begin
  for i := 0 to nb - 1 do
      values^[i] := values^[i] + Delta;
end;

// ScaleFloatArray (array)
//
procedure OffsetFloatArray(var values: array of Single; Delta: Single);
begin
  if length(values) > 0 then
      ScaleFloatArray(@values[0], length(values), Delta);
end;

// OffsetFloatArray (raw, raw)
//
procedure OffsetFloatArray(valuesDest, valuesDelta: PSingleArray; nb: Integer);
var
  i: Integer;
begin
  for i := 0 to nb - 1 do
      valuesDest^[i] := valuesDest^[i] + valuesDelta^[i];
end;

// MaxXYZComponent
//
function MaxXYZComponent(const v: TVector): Single;
begin
  Result := MaxFloat(v[0], v[1], v[2]);
end;

// MaxXYZComponent
//
function MaxXYZComponent(const v: TAffineVector): Single;
begin
  Result := MaxFloat(v[0], v[1], v[2]);
end;

// MinXYZComponent
//
function MinXYZComponent(const v: TVector): Single;
begin
  if v[0] <= v[1] then
    if v[0] <= v[2] then
        Result := v[0]
    else if v[2] <= v[1] then
        Result := v[2]
    else
        Result := v[1]
  else if v[1] <= v[2] then
      Result := v[1]
  else if v[2] <= v[0] then
      Result := v[2]
  else
      Result := v[0];
end;

// MinXYZComponent
//
function MinXYZComponent(const v: TAffineVector): Single;
begin
  Result := MinFloat(v[0], v[1], v[2]);
end;

// MaxAbsXYZComponent
//
function MaxAbsXYZComponent(v: TVector): Single;
begin
  AbsVector(v);
  Result := MaxXYZComponent(v);
end;

// MinAbsXYZComponent
//
function MinAbsXYZComponent(v: TVector): Single;
begin
  AbsVector(v);
  Result := MinXYZComponent(v);
end;

// MaxVector (hmg)
//
procedure MaxVector(var v: TVector; const v1: TVector);
begin
  if v1[0] > v[0] then
      v[0] := v1[0];
  if v1[1] > v[1] then
      v[1] := v1[1];
  if v1[2] > v[2] then
      v[2] := v1[2];
  if v1[3] > v[3] then
      v[3] := v1[3];
end;

// MaxVector (affine)
//
procedure MaxVector(var v: TAffineVector; const v1: TAffineVector);
begin
  if v1[0] > v[0] then
      v[0] := v1[0];
  if v1[1] > v[1] then
      v[1] := v1[1];
  if v1[2] > v[2] then
      v[2] := v1[2];
end;

// MinVector (hmg)
//
procedure MinVector(var v: TVector; const v1: TVector);
begin
  if v1[0] < v[0] then
      v[0] := v1[0];
  if v1[1] < v[1] then
      v[1] := v1[1];
  if v1[2] < v[2] then
      v[2] := v1[2];
  if v1[3] < v[3] then
      v[3] := v1[3];
end;

// MinVector (affine)
//
procedure MinVector(var v: TAffineVector; const v1: TAffineVector);
begin
  if v1[0] < v[0] then
      v[0] := v1[0];
  if v1[1] < v[1] then
      v[1] := v1[1];
  if v1[2] < v[2] then
      v[2] := v1[2];
end;

// SortArrayAscending (Double)
//
procedure SortArrayAscending(var a: array of Double);
var
  i, j, M: Integer;
  Buf: Double;
begin
  for i := low(a) to high(a) - 1 do
    begin
      M := i;
      for j := i + 1 to high(a) do
        if a[j] < a[M] then
            M := j;
      if M <> i then
        begin
          Buf := a[M];
          a[M] := a[i];
          a[i] := Buf;
        end;
    end;
end;

// ClampValue (Min_-Max_)
//
function ClampValue(const Value_, Min_, Max_: Single): Single;
begin
  if Min_ > Max_ then
      Result := ClampValue(Value_, Max_, Min_)
  else if Value_ > Max_ then
      Result := Max_
  else if Value_ < Min_ then
      Result := Min_
  else
      Result := Value_;
end;

// ClampValue (Min_-)
//
function ClampValue(const Value_, Min_: Single): Single;
begin
  if Value_ < Min_ then
      Result := Min_
  else
      Result := Value_;
end;

// PointInPolygon
//
function PointInPolygon(var xp, yp: array of Single; x, y: Single): Boolean;
// The code below is from Wm. Randolph Franklin <wrf@ecse.rpi.edu>
// with some minor modifications for speed.  It returns 1 for strictly
// interior points, 0 for strictly exterior, and 0 or 1 for points on
// the boundary.
var
  i, j: Integer;
begin
  Result := False;
  if high(xp) = high(yp) then
    begin
      j := high(xp);
      for i := 0 to high(xp) do
        begin
          if ((((yp[i] <= y) and (y < yp[j])) or ((yp[j] <= y) and (y < yp[i])))
              and (x < (xp[j] - xp[i]) * (y - yp[i]) / (yp[j] - yp[i]) + xp[i])) then
              Result := not Result;
          j := i;
        end;
    end;
end;

// DivMod
//
procedure DivMod(Dividend: Integer; Divisor: Word; var Result, Remainder: Word);
begin
  Result := Dividend div Divisor;
  Remainder := Dividend mod Divisor;
end;

// ConvertRotation
//
function ConvertRotation(const Angles: TAffineVector): TVector;

{ Rotation of the Angle t about the axis (X, Y, Z) is given by:

  | X^2 + (1-X^2) Cos(t),    XY(1-Cos(t))  +  Z Sin(t), XZ(1-Cos(t))-Y Sin(t) |
  M = | XY(1-Cos(t))-Z Sin(t), Y^2 + (1-Y^2) Cos(t),      YZ(1-Cos(t)) + X Sin(t) |
  | XZ(1-Cos(t)) + Y Sin(t), YZ(1-Cos(t))-X Sin(t),   Z^2 + (1-Z^2) Cos(t)    |

  Rotation about the three axes (Angles a1, a2, a3) can be represented as
  the product of the individual rotation matrices:

  | 1  0       0       | | Cos(a2) 0 -Sin(a2) | |  Cos(a3) Sin(a3) 0 |
  | 0  Cos(a1) Sin(a1) | * | 0       1  0       | * | -Sin(a3) Cos(a3) 0 |
  | 0 -Sin(a1) Cos(a1) | | Sin(a2) 0  Cos(a2) | |  0       0       1 |
  Mx                       My                     Mz

  We now want to solve for X, Y, Z, and t given 9 equations in 4 unknowns.
  Using the diagonal elements of the two matrices, we get:

  X^2 + (1-X^2) Cos(t) = M[0][0]
  Y^2 + (1-Y^2) Cos(t) = M[1][1]
  Z^2 + (1-Z^2) Cos(t) = M[2][2]

  Adding the three equations, we get:

  X^2  +  Y^2  +  Z^2 - (M[0][0]  +  M[1][1]  +  M[2][2]) =
  - (3 - X^2 - Y^2 - Z^2) Cos(t)

  Since (X^2  +  Y^2  +  Z^2) = 1, we can rewrite as:

  Cos(t) = (1 - (M[0][0]  +  M[1][1]  +  M[2][2])) / 2

  Solving for t, we get:

  t = Acos(((M[0][0]  +  M[1][1]  +  M[2][2]) - 1) / 2)

  We can substitute t into the equations for X^2, Y^2, and Z^2 above
  to get the values for X, Y, and Z.  To find the proper signs we note
  that:

  2 X Sin(t) = M[1][2] - M[2][1]
  2 Y Sin(t) = M[2][0] - M[0][2]
  2 Z Sin(t) = M[0][1] - M[1][0]
}
var
  Axis1, Axis2: TVector3f;
  M, m1, m2: TMatrix;
  cost, cost1, sint, s1, s2, s3: Single;
  i: Integer;
begin
  // see if we are only rotating about a Single Axis
  if Abs(Angles[x]) < Epsilon then
    begin
      if Abs(Angles[y]) < Epsilon then
        begin
          SetVector(Result, 0, 0, 1, Angles[Z]);
          Exit;
        end
      else if Abs(Angles[Z]) < Epsilon then
        begin
          SetVector(Result, 0, 1, 0, Angles[y]);
          Exit;
        end
    end
  else if (Abs(Angles[y]) < Epsilon) and (Abs(Angles[Z]) < Epsilon) then
    begin
      SetVector(Result, 1, 0, 0, Angles[x]);
      Exit;
    end;

  // make the rotation matrix
  Axis1 := XVector;
  M := CreateRotationMatrix(Axis1, Angles[x]);

  Axis2 := YVector;
  m2 := CreateRotationMatrix(Axis2, Angles[y]);
  m1 := MatrixMultiply(M, m2);

  Axis2 := ZVector;
  m2 := CreateRotationMatrix(Axis2, Angles[Z]);
  M := MatrixMultiply(m1, m2);

  cost := ((M[x, x] + M[y, y] + M[Z, Z]) - 1) / 2;
  if cost < -1 then
      cost := -1
  else if cost > 1 - Epsilon then
    begin
      // Bad Angle - this would cause a crash
      SetVector(Result, XHmgVector);
      Exit;
    end;

  cost1 := 1 - cost;
  SetVector(Result, Sqrt((M[x, x] - cost) / cost1),
    Sqrt((M[y, y] - cost) / cost1),
    Sqrt((M[Z, Z] - cost) / cost1),
    ArcCos_(cost));

  sint := 2 * Sqrt(1 - cost * cost); // This is actually 2 Sin(t)

  // Determine the proper signs
  for i := 0 to 7 do
    begin
      if (i and 1) > 1 then
          s1 := -1
      else
          s1 := 1;
      if (i and 2) > 1 then
          s2 := -1
      else
          s2 := 1;
      if (i and 4) > 1 then
          s3 := -1
      else
          s3 := 1;
      if (Abs(s1 * Result[x] * sint - M[y, Z] + M[Z, y]) < EPSILON2)
        and (Abs(s2 * Result[y] * sint - M[Z, x] + M[x, Z]) < EPSILON2)
        and (Abs(s3 * Result[Z] * sint - M[x, y] + M[y, x]) < EPSILON2) then
        begin
          // We found the right combination of signs
          Result[x] := Result[x] * s1;
          Result[y] := Result[y] * s2;
          Result[Z] := Result[Z] * s3;
          Exit;
        end;
    end;
end;

// QuaternionSlerp
//
function QuaternionSlerp(const QStart, QEnd: TQuaternion; Spin: Integer; t: Single): TQuaternion;
var
  beta, // complementary interp parameter
  Theta, // Angle between A and B
  sint, cost, // sine, cosine of theta
  Phi: Single; // theta plus spins
  bflip: Boolean; // use negativ t?
begin
  // cosine theta
  cost := VectorAngleCosine(QStart.ImagPart, QEnd.ImagPart);

  // if QEnd is on opposite hemisphere from QStart, use -QEnd instead
  if cost < 0 then
    begin
      cost := -cost;
      bflip := True;
    end
  else
      bflip := False;

  // if QEnd is (within precision limits) the same as QStart,
  // just linear interpolate between QStart and QEnd.
  // Can't do spins, since we don't know what direction to spin.

  if (1 - cost) < Epsilon then
      beta := 1 - t
  else
    begin
      // normal case
      Theta := ArcCos_(cost);
      Phi := Theta + Spin * pi;
      sint := Sin(Theta);
      beta := Sin(Theta - t * Phi) / sint;
      t := Sin(t * Phi) / sint;
    end;

  if bflip then
      t := -t;

  // interpolate
  Result.ImagPart[x] := beta * QStart.ImagPart[x] + t * QEnd.ImagPart[x];
  Result.ImagPart[y] := beta * QStart.ImagPart[y] + t * QEnd.ImagPart[y];
  Result.ImagPart[Z] := beta * QStart.ImagPart[Z] + t * QEnd.ImagPart[Z];
  Result.RealPart := beta * QStart.RealPart + t * QEnd.RealPart;
end;

// QuaternionSlerp
//
function QuaternionSlerp(const Source, dest: TQuaternion; const t: Single): TQuaternion;
var
  to1: array [0 .. 4] of Single;
  omega, cosom, sinom, scale0, scale1: Double;
  // t goes from 0 to 1
  // absolute rotations
begin
  // calc cosine
  cosom := Source.ImagPart[0] * dest.ImagPart[0]
    + Source.ImagPart[1] * dest.ImagPart[1]
    + Source.ImagPart[2] * dest.ImagPart[2]
    + Source.RealPart * dest.RealPart;
  // adjust signs (if necessary)
  if cosom < 0 then
    begin
      cosom := -cosom;
      to1[0] := -dest.ImagPart[0];
      to1[1] := -dest.ImagPart[1];
      to1[2] := -dest.ImagPart[2];
      to1[3] := -dest.RealPart;
    end
  else
    begin
      to1[0] := dest.ImagPart[0];
      to1[1] := dest.ImagPart[1];
      to1[2] := dest.ImagPart[2];
      to1[3] := dest.RealPart;
    end;
  // calculate coefficients
  if ((1.0 - cosom) > EPSILON2) then
    begin // standard case (slerp)
      omega := ArcCos_(cosom);
      sinom := 1 / Sin(omega);
      scale0 := Sin((1.0 - t) * omega) * sinom;
      scale1 := Sin(t * omega) * sinom;
    end
  else
    begin // "from" and "to" quaternions are very close
      // ... so we can do a linear interpolation
      scale0 := 1.0 - t;
      scale1 := t;
    end;
  // calculate final values
  Result.ImagPart[0] := scale0 * Source.ImagPart[0] + scale1 * to1[0];
  Result.ImagPart[1] := scale0 * Source.ImagPart[1] + scale1 * to1[1];
  Result.ImagPart[2] := scale0 * Source.ImagPart[2] + scale1 * to1[2];
  Result.RealPart := scale0 * Source.RealPart + scale1 * to1[3];
  NormalizeQuaternion(Result);
end;

// ----------------- coordinate system manipulation functions -----------------------------------------------------------

// Turn (Y axis)
//
function Turn(const Matrix: TMatrix; angle: Single): TMatrix;
begin
  Result := MatrixMultiply(Matrix, CreateRotationMatrix(AffineVectorMake(Matrix[1][0], Matrix[1][1], Matrix[1][2]), angle));
end;

// Turn (direction)
//
function Turn(const Matrix: TMatrix; const MasterUp: TAffineVector; angle: Single): TMatrix;
begin
  Result := MatrixMultiply(Matrix, CreateRotationMatrix(MasterUp, angle));
end;

// Pitch (X axis)
//
function Pitch(const Matrix: TMatrix; angle: Single): TMatrix;
begin
  Result := MatrixMultiply(Matrix, CreateRotationMatrix(AffineVectorMake(Matrix[0][0], Matrix[0][1], Matrix[0][2]), angle));
end;

// Pitch (direction)
//
function Pitch(const Matrix: TMatrix; const MasterRight: TAffineVector; angle: Single): TMatrix;
begin
  Result := MatrixMultiply(Matrix, CreateRotationMatrix(MasterRight, angle));
end;

// Roll (Z axis)
//
function Roll(const Matrix: TMatrix; angle: Single): TMatrix;
begin
  Result := MatrixMultiply(Matrix, CreateRotationMatrix(AffineVectorMake(Matrix[2][0], Matrix[2][1], Matrix[2][2]), angle));
end;

// Roll (direction)
//
function Roll(const Matrix: TMatrix; const MasterDirection: TAffineVector; angle: Single): TMatrix;
begin
  Result := MatrixMultiply(Matrix, CreateRotationMatrix(MasterDirection, angle));
end;

// RayCastPlaneIntersect (plane defined by point+normal)
//
function RayCastPlaneIntersect(const rayStart, rayVector: TVector;
  const planePoint, planeNormal: TVector;
  intersectPoint: PVector = nil): Boolean;
var
  sp: TVector;
  t, d: Single;
begin
  d := VectorDotProduct(rayVector, planeNormal);
  Result := ((d > EPSILON2) or (d < -EPSILON2));
  if Result and Assigned(intersectPoint) then
    begin
      VectorSubtract(planePoint, rayStart, sp);
      d := 1 / d; // will keep one FPU unit busy during dot product calculation
      t := VectorDotProduct(sp, planeNormal) * d;
      if t > 0 then
          VectorCombine(rayStart, rayVector, t, intersectPoint^)
      else
          Result := False;
    end;
end;

// RayCastPlaneXZIntersect
//
function RayCastPlaneXZIntersect(const rayStart, rayVector: TVector;
  const planeY: Single;
  intersectPoint: PVector = nil): Boolean;
var
  t: Single;
begin
  if rayVector[1] = 0 then
      Result := False
  else
    begin
      t := (rayStart[1] - planeY) / rayVector[1];
      if t < 0 then
        begin
          if Assigned(intersectPoint) then
              VectorCombine(rayStart, rayVector, t, intersectPoint^);
          Result := True;
        end
      else
          Result := False;
    end;
end;

// RayCastTriangleIntersect
//
function RayCastTriangleIntersect(const rayStart, rayVector: TVector;
  const p1, p2, p3: TAffineVector;
  intersectPoint: PVector = nil;
  intersectNormal: PVector = nil): Boolean;
var
  pvec: TAffineVector;
  v1, v2, qvec, tvec: TVector;
  t, u, v, det, invDet: Single;
begin
  VectorSubtract(p2, p1, v1);
  VectorSubtract(p3, p1, v2);
  VectorCrossProduct(rayVector, v2, pvec);
  det := VectorDotProduct(v1, pvec);
  if ((det < EPSILON2) and (det > -EPSILON2)) then
    begin // vector is Parallel to triangle's plane
      Result := False;
      Exit;
    end;
  invDet := cOne / det;
  VectorSubtract(rayStart, p1, tvec);
  u := VectorDotProduct(tvec, pvec) * invDet;
  if (u < 0) or (u > 1) then
      Result := False
  else
    begin
      qvec := VectorCrossProduct(tvec, v1);
      v := VectorDotProduct(rayVector, qvec) * invDet;
      Result := (v >= 0) and (u + v <= 1);
      if Result then
        begin
          t := VectorDotProduct(v2, qvec) * invDet;
          if t > 0 then
            begin
              if intersectPoint <> nil then
                  VectorCombine(rayStart, rayVector, t, intersectPoint^);
              if intersectNormal <> nil then
                  VectorCrossProduct(v1, v2, intersectNormal^);
            end
          else
              Result := False;
        end;
    end;
end;

// RayCastMinDistToPoint
//
function RayCastMinDistToPoint(const rayStart, rayVector: TVector;
  const Point: TVector): Single;
var
  proj: Single;
begin
  proj := PointProject(Point, rayStart, rayVector);
  if proj <= 0 then
      proj := 0; // rays don't go backward!
  Result := VectorDistance(Point, VectorCombine(rayStart, rayVector, 1, proj));
end;

// RayCastIntersectsSphere
//
function RayCastIntersectsSphere(const rayStart, rayVector: TVector;
  const sphereCenter: TVector;
  const SphereRadius: Single): Boolean;
var
  proj: Single;
begin
  proj := PointProject(sphereCenter, rayStart, rayVector);
  if proj <= 0 then
      proj := 0; // rays don't go backward!
  Result := (VectorDistance2(sphereCenter, VectorCombine(rayStart, rayVector, 1, proj)) <= Sqr(SphereRadius));
end;

// RayCastSphereIntersect
//
function RayCastSphereIntersect(const rayStart, rayVector: TVector;
  const sphereCenter: TVector;
  const SphereRadius: Single;
  var i1, i2: TVector): Integer;
var
  proj, d2: Single;
  id2: Integer;
  projPoint: TVector;
begin
  proj := PointProject(sphereCenter, rayStart, rayVector);
  VectorCombine(rayStart, rayVector, proj, projPoint);
  d2 := SphereRadius * SphereRadius - VectorDistance2(sphereCenter, projPoint);
  id2 := PInteger(@d2)^;
  if id2 >= 0 then
    begin
      if id2 = 0 then
        begin
          if PInteger(@proj)^ > 0 then
            begin
              VectorCombine(rayStart, rayVector, proj, i1);
              Result := 1;
              Exit;
            end;
        end
      else if id2 > 0 then
        begin
          d2 := Sqrt(d2);
          if proj >= d2 then
            begin
              VectorCombine(rayStart, rayVector, proj - d2, i1);
              VectorCombine(rayStart, rayVector, proj + d2, i2);
              Result := 2;
              Exit;
            end
          else if proj + d2 >= 0 then
            begin
              VectorCombine(rayStart, rayVector, proj + d2, i1);
              Result := 1;
              Exit;
            end;
        end;
    end;
  Result := 0;
end;

// RayCastBoxIntersect
//
function RayCastBoxIntersect(
  const rayStart, rayVector, aMinExtent, aMaxExtent: TAffineVector;
  intersectPoint: PAffineVector = nil): Boolean;
var
  i, planeInd: Integer;
  ResAFV, MaxDist, plane: TAffineVector;
  isMiddle: array [0 .. 2] of Boolean;
begin
  // Find plane.
  Result := True;
  for i := 0 to 2 do
    if rayStart[i] < aMinExtent[i] then
      begin
        plane[i] := aMinExtent[i];
        isMiddle[i] := False;
        Result := False;
      end
    else if rayStart[i] > aMaxExtent[i] then
      begin
        plane[i] := aMaxExtent[i];
        isMiddle[i] := False;
        Result := False;
      end
    else
      begin
        isMiddle[i] := True;
      end;
  if Result then
    begin
      // rayStart inside box.
      if intersectPoint <> nil
      then
          intersectPoint^ := rayStart;
    end
  else
    begin
      // Distance to plane.
      planeInd := 0;
      for i := 0 to 2 do
        if isMiddle[i]
          or (rayVector[i] = 0)
        then
            MaxDist[i] := -1
        else
          begin
            MaxDist[i] := (plane[i] - rayStart[i]) / rayVector[i];
            if MaxDist[i] > 0 then
              begin
                if MaxDist[planeInd] < MaxDist[i]
                then
                    planeInd := i;
                Result := True;
              end;
          end;
      // Inside box ?
      if Result then
        begin
          for i := 0 to 2 do
            if planeInd = i
            then
                ResAFV[i] := plane[i]
            else
              begin
                ResAFV[i] := rayStart[i] + MaxDist[planeInd] * rayVector[i];
                Result := (ResAFV[i] >= aMinExtent[i])
                  and (ResAFV[i] <= aMaxExtent[i]);
                if not Result then
                    Exit;
              end;
          if intersectPoint <> nil
          then
              intersectPoint^ := ResAFV;
        end;
    end;
end;

// SphereVisibleRadius
//
function SphereVisibleRadius(Distance, radius: Single): Single;
var
  d2, r2, IR, tr: Single;
begin
  d2 := Distance * Distance;
  r2 := radius * radius;
  IR := Sqrt(d2 - r2);
  tr := (d2 + r2 - Sqr(IR)) / (2 * IR);

  Result := Sqrt(r2 + Sqr(tr));
end;

// IntersectLinePlane
//
function IntersectLinePlane(const Point, direction: TVector;
  const plane: THmgPlane;
  intersectPoint: PVector = nil): Integer;
var
  a, b: Double;
  t: Single;
begin
  a := VectorDotProduct(plane, direction); // direction projected to plane normal
  b := PlaneEvaluatePoint(plane, Point); // distance to plane
  if a = 0 then
    begin // direction is Parallel to plane
      if b = 0 then
          Result := -1 // line is inside plane
      else
          Result := 0; // line is outside plane
    end
  else
    begin
      if Assigned(intersectPoint) then
        begin
          t := -b / a; // parameter of intersection
          intersectPoint^ := Point;
          // calculate intersection = p + t*d
          CombineVector(intersectPoint^, direction, t);
        end;
      Result := 1;
    end;
end;

// TriangleBoxIntersect
//
function IntersectTriangleBox(
  const p1, p2, p3, aMinExtent, aMaxExtent: TAffineVector): Boolean;
var
  RayDir, iPoint: TAffineVector;
  BoxDiagPt, BoxDiagPt2,
    BoxDiagDir, iPnt: TVector;
begin
  // Triangle edge (p2, p1) - Box intersection
  VectorSubtract(p2, p1, RayDir);
  Result := RayCastBoxIntersect(p1, RayDir, aMinExtent, aMaxExtent, @iPoint);
  if Result then
      Result := VectorNorm(VectorSubtract(p1, iPoint))
      < VectorNorm(VectorSubtract(p1, p2));
  if Result then
      Exit;

  // Triangle edge (p3, p1) - Box intersection
  VectorSubtract(p3, p1, RayDir);
  Result := RayCastBoxIntersect(p1, RayDir, aMinExtent, aMaxExtent, @iPoint);
  if Result then
      Result := VectorNorm(VectorSubtract(p1, iPoint))
      < VectorNorm(VectorSubtract(p1, p3));
  if Result then
      Exit;

  // Triangle edge (p2, p3) - Box intersection
  VectorSubtract(p2, p3, RayDir);
  Result := RayCastBoxIntersect(p3, RayDir, aMinExtent, aMaxExtent, @iPoint);
  if Result then
      Result := VectorNorm(VectorSubtract(p3, iPoint))
      < VectorNorm(VectorSubtract(p3, p2));
  if Result then
      Exit;

  // Triangle - Box diagonal 1 intersection
  BoxDiagPt := VectorMake(aMinExtent);
  VectorSubtract(aMaxExtent, aMinExtent, BoxDiagDir);
  Result := RayCastTriangleIntersect(BoxDiagPt, BoxDiagDir, p1, p2, p3, @iPnt);
  if Result then
      Result := VectorNorm(VectorSubtract(BoxDiagPt, iPnt))
      < VectorNorm(VectorSubtract(aMaxExtent, aMinExtent));
  if Result then
      Exit;

  // Triangle - Box diagonal 2 intersection
  BoxDiagPt := VectorMake(aMinExtent[0], aMinExtent[1], aMaxExtent[2]);
  BoxDiagPt2 := VectorMake(aMaxExtent[0], aMaxExtent[1], aMinExtent[2]);
  VectorSubtract(BoxDiagPt2, BoxDiagPt, BoxDiagDir);
  Result := RayCastTriangleIntersect(BoxDiagPt, BoxDiagDir, p1, p2, p3, @iPnt);
  if Result then
      Result := VectorNorm(VectorSubtract(BoxDiagPt, iPnt))
      < VectorNorm(VectorSubtract(BoxDiagPt, BoxDiagPt2));
  if Result then
      Exit;

  // Triangle - Box diagonal 3 intersection
  BoxDiagPt := VectorMake(aMinExtent[0], aMaxExtent[1], aMinExtent[2]);
  BoxDiagPt2 := VectorMake(aMaxExtent[0], aMinExtent[1], aMaxExtent[2]);
  VectorSubtract(BoxDiagPt, BoxDiagPt, BoxDiagDir);
  Result := RayCastTriangleIntersect(BoxDiagPt, BoxDiagDir, p1, p2, p3, @iPnt);
  if Result then
      Result := VectorLength(VectorSubtract(BoxDiagPt, iPnt))
      < VectorLength(VectorSubtract(BoxDiagPt, BoxDiagPt));
  if Result then
      Exit;

  // Triangle - Box diagonal 4 intersection
  BoxDiagPt := VectorMake(aMaxExtent[0], aMinExtent[1], aMinExtent[2]);
  BoxDiagPt2 := VectorMake(aMinExtent[0], aMaxExtent[1], aMaxExtent[2]);
  VectorSubtract(BoxDiagPt, BoxDiagPt, BoxDiagDir);
  Result := RayCastTriangleIntersect(BoxDiagPt, BoxDiagDir, p1, p2, p3, @iPnt);
  if Result then
      Result := VectorLength(VectorSubtract(BoxDiagPt, iPnt))
      < VectorLength(VectorSubtract(BoxDiagPt, BoxDiagPt));
end;

// IntersectSphereBox
//
function IntersectSphereBox(
  const SpherePos: TVector;
  const SphereRadius: Single;
  const BoxMatrix: TMatrix; // Up Direction and Right must be normalized!
  // Use CubDepht, CubeHeight and CubeWidth
  // for scale TGLCube.
  const BoxScale: TAffineVector; intersectPoint: PAffineVector = nil; normal: PAffineVector = nil; Depth: PSingle = nil): Boolean;

  function dDOTByColumn(const v: TAffineVector; const M: TMatrix; const aColumn: Integer): Single;
  begin
    Result := v[0] * M[0, aColumn]
      + v[1] * M[1, aColumn]
      + v[2] * M[2, aColumn];
  end;

  function dDotByRow(const v: TAffineVector; const M: TMatrix; const aRow: Integer): Single;
  begin
    // Equal with: Result := VectorDotProduct(v, AffineVectorMake(m[aRow]));
    Result := v[0] * M[aRow, 0]
      + v[1] * M[aRow, 1]
      + v[2] * M[aRow, 2];
  end;

  function dDotMatrByColumn(const v: TAffineVector; const M: TMatrix): TAffineVector;
  begin
    Result[0] := dDOTByColumn(v, M, 0);
    Result[1] := dDOTByColumn(v, M, 1);
    Result[2] := dDOTByColumn(v, M, 2);
  end;

  function dDotMatrByRow(const v: TAffineVector; const M: TMatrix): TAffineVector;
  begin
    Result[0] := dDotByRow(v, M, 0);
    Result[1] := dDotByRow(v, M, 1);
    Result[2] := dDotByRow(v, M, 2);
  end;

var
  tmp, L, t, p, q, r: TAffineVector;
  FaceDistance,
    MinDistance, Depth1: Single;
  mini, i: Integer;
  isSphereCenterInsideBox: Boolean;
begin
  // this is easy. get the sphere center `p' relative to the box, and then clip
  // that to the boundary of the box (call that point `q'). if q is on the
  // boundary of the box and |p-q| is <= sphere radius, they touch.
  // if q is inside the box, the sphere is inside the box, so set a contact
  // normal to push the sphere to the closest box face.

  p[0] := SpherePos[0] - BoxMatrix[3, 0];
  p[1] := SpherePos[1] - BoxMatrix[3, 1];
  p[2] := SpherePos[2] - BoxMatrix[3, 2];

  isSphereCenterInsideBox := True;
  for i := 0 to 2 do
    begin
      L[i] := 0.5 * BoxScale[i];
      t[i] := dDotByRow(p, BoxMatrix, i);
      if t[i] < -L[i] then
        begin
          t[i] := -L[i];
          isSphereCenterInsideBox := False;
        end
      else if t[i] > L[i] then
        begin
          t[i] := L[i];
          isSphereCenterInsideBox := False;
        end;
    end;

  if isSphereCenterInsideBox then
    begin

      MinDistance := L[0] - Abs(t[0]);
      mini := 0;
      for i := 1 to 2 do
        begin
          FaceDistance := L[i] - Abs(t[i]);
          if FaceDistance < MinDistance then
            begin
              MinDistance := FaceDistance;
              mini := i;
            end;
        end;

      if intersectPoint <> nil then
          intersectPoint^ := AffineVectorMake(SpherePos);

      if normal <> nil then
        begin
          tmp := NullVector;
          if t[mini] > 0 then
              tmp[mini] := 1
          else
              tmp[mini] := -1;
          normal^ := dDotMatrByRow(tmp, BoxMatrix);
        end;

      if Depth <> nil then
          Depth^ := MinDistance + SphereRadius;

      Result := True;
    end
  else
    begin
      q := dDotMatrByColumn(t, BoxMatrix);
      r := VectorSubtract(p, q);
      Depth1 := SphereRadius - VectorLength(r);
      if Depth1 < 0 then
        begin
          Result := False;
        end
      else
        begin
          if intersectPoint <> nil then
              intersectPoint^ := VectorAdd(q, AffineVectorMake(BoxMatrix[3]));
          if normal <> nil then
            begin
              normal^ := VectorNormalize(r);
            end;
          if Depth <> nil then
              Depth^ := Depth1;
          Result := True;
        end;
    end;
end;

// ExtractFrustumFromModelViewProjection
//
function ExtractFrustumFromModelViewProjection(const modelViewProj: TMatrix): TFrustum;
begin
  with Result do
    begin
      // extract left plane
      pLeft[0] := modelViewProj[0][3] + modelViewProj[0][0];
      pLeft[1] := modelViewProj[1][3] + modelViewProj[1][0];
      pLeft[2] := modelViewProj[2][3] + modelViewProj[2][0];
      pLeft[3] := modelViewProj[3][3] + modelViewProj[3][0];
      NormalizePlane(pLeft);
      // extract top plane
      pTop[0] := modelViewProj[0][3] - modelViewProj[0][1];
      pTop[1] := modelViewProj[1][3] - modelViewProj[1][1];
      pTop[2] := modelViewProj[2][3] - modelViewProj[2][1];
      pTop[3] := modelViewProj[3][3] - modelViewProj[3][1];
      NormalizePlane(pTop);
      // extract right plane
      pRight[0] := modelViewProj[0][3] - modelViewProj[0][0];
      pRight[1] := modelViewProj[1][3] - modelViewProj[1][0];
      pRight[2] := modelViewProj[2][3] - modelViewProj[2][0];
      pRight[3] := modelViewProj[3][3] - modelViewProj[3][0];
      NormalizePlane(pRight);
      // extract bottom plane
      pBottom[0] := modelViewProj[0][3] + modelViewProj[0][1];
      pBottom[1] := modelViewProj[1][3] + modelViewProj[1][1];
      pBottom[2] := modelViewProj[2][3] + modelViewProj[2][1];
      pBottom[3] := modelViewProj[3][3] + modelViewProj[3][1];
      NormalizePlane(pBottom);
      // extract far plane
      pFar[0] := modelViewProj[0][3] - modelViewProj[0][2];
      pFar[1] := modelViewProj[1][3] - modelViewProj[1][2];
      pFar[2] := modelViewProj[2][3] - modelViewProj[2][2];
      pFar[3] := modelViewProj[3][3] - modelViewProj[3][2];
      NormalizePlane(pFar);
      // extract near plane
      pNear[0] := modelViewProj[0][3] + modelViewProj[0][2];
      pNear[1] := modelViewProj[1][3] + modelViewProj[1][2];
      pNear[2] := modelViewProj[2][3] + modelViewProj[2][2];
      pNear[3] := modelViewProj[3][3] + modelViewProj[3][2];
      NormalizePlane(pNear);
    end;
end;

// IsVolumeClipped
//
function IsVolumeClipped(const objPos: TAffineVector; const objRadius: Single;
  const Frustum: TFrustum): Boolean;
var
  negRadius: Single;
begin
  negRadius := -objRadius;
  Result := (PlaneEvaluatePoint(Frustum.pLeft, objPos) < negRadius)
    or (PlaneEvaluatePoint(Frustum.pTop, objPos) < negRadius)
    or (PlaneEvaluatePoint(Frustum.pRight, objPos) < negRadius)
    or (PlaneEvaluatePoint(Frustum.pBottom, objPos) < negRadius)
    or (PlaneEvaluatePoint(Frustum.pNear, objPos) < negRadius)
    or (PlaneEvaluatePoint(Frustum.pFar, objPos) < negRadius);
end;

// IsVolumeClipped
//
function IsVolumeClipped(const objPos: TVector; const objRadius: Single;
  const Frustum: TFrustum): Boolean;
begin
  Result := IsVolumeClipped(PAffineVector(@objPos)^, objRadius, Frustum);
end;

// IsVolumeClipped
//
function IsVolumeClipped(const Min_, Max_: TAffineVector; const Frustum: TFrustum): Boolean;
begin
  // change box to sphere
  Result := IsVolumeClipped(VectorScale(VectorAdd(Min_, Max_), 0.5),
    VectorDistance(Min_, Max_) * 0.5, Frustum);
end;

// MakeParallelProjectionMatrix
//
function MakeParallelProjectionMatrix(const plane: THmgPlane;
  const dir: TVector): TMatrix;
// Based on material from a course by William D. Shoaff (www.cs.fit.edu)
var
  dot, invDot: Single;
begin
  dot := plane[0] * dir[0] + plane[1] * dir[1] + plane[2] * dir[2];
  if Abs(dot) < 1E-5 then
    begin
      Result := IdentityHmgMatrix;
      Exit;
    end;
  invDot := 1 / dot;

  Result[0][0] := (plane[1] * dir[1] + plane[2] * dir[2]) * invDot;
  Result[1][0] := (-plane[1] * dir[0]) * invDot;
  Result[2][0] := (-plane[2] * dir[0]) * invDot;
  Result[3][0] := (-plane[3] * dir[0]) * invDot;

  Result[0][1] := (-plane[0] * dir[1]) * invDot;
  Result[1][1] := (plane[0] * dir[0] + plane[2] * dir[2]) * invDot;
  Result[2][1] := (-plane[2] * dir[1]) * invDot;
  Result[3][1] := (-plane[3] * dir[1]) * invDot;

  Result[0][2] := (-plane[0] * dir[2]) * invDot;
  Result[1][2] := (-plane[1] * dir[2]) * invDot;
  Result[2][2] := (plane[0] * dir[0] + plane[1] * dir[1]) * invDot;
  Result[3][2] := (-plane[3] * dir[2]) * invDot;

  Result[0][3] := 0;
  Result[1][3] := 0;
  Result[2][3] := 0;
  Result[3][3] := 1;
end;

// MakeShadowMatrix
//
function MakeShadowMatrix(const planePoint, planeNormal, lightPos: TVector): TMatrix;
var
  planeNormal3, dot: Single;
begin
  // Find the last coefficient by back substitutions
  planeNormal3 := -(planeNormal[0] * planePoint[0]
      + planeNormal[1] * planePoint[1]
      + planeNormal[2] * planePoint[2]);
  // Dot product of plane and light position
  dot := planeNormal[0] * lightPos[0]
    + planeNormal[1] * lightPos[1]
    + planeNormal[2] * lightPos[2]
    + planeNormal3 * lightPos[3];
  // Now do the projection
  // First column
  Result[0][0] := dot - lightPos[0] * planeNormal[0];
  Result[1][0] := -lightPos[0] * planeNormal[1];
  Result[2][0] := -lightPos[0] * planeNormal[2];
  Result[3][0] := -lightPos[0] * planeNormal3;
  // Second column
  Result[0][1] := -lightPos[1] * planeNormal[0];
  Result[1][1] := dot - lightPos[1] * planeNormal[1];
  Result[2][1] := -lightPos[1] * planeNormal[2];
  Result[3][1] := -lightPos[1] * planeNormal3;
  // Third Column
  Result[0][2] := -lightPos[2] * planeNormal[0];
  Result[1][2] := -lightPos[2] * planeNormal[1];
  Result[2][2] := dot - lightPos[2] * planeNormal[2];
  Result[3][2] := -lightPos[2] * planeNormal3;
  // Fourth Column
  Result[0][3] := -lightPos[3] * planeNormal[0];
  Result[1][3] := -lightPos[3] * planeNormal[1];
  Result[2][3] := -lightPos[3] * planeNormal[2];
  Result[3][3] := dot - lightPos[3] * planeNormal3;
end;

// MakeReflectionMatrix
//
function MakeReflectionMatrix(const planePoint, planeNormal: TAffineVector): TMatrix;
var
  pv2: Single;
begin
  // Precalcs
  pv2 := 2 * VectorDotProduct(planePoint, planeNormal);
  // 1st column
  Result[0][0] := 1 - 2 * Sqr(planeNormal[0]);
  Result[0][1] := -2 * planeNormal[0] * planeNormal[1];
  Result[0][2] := -2 * planeNormal[0] * planeNormal[2];
  Result[0][3] := 0;
  // 2nd column
  Result[1][0] := -2 * planeNormal[1] * planeNormal[0];
  Result[1][1] := 1 - 2 * Sqr(planeNormal[1]);
  Result[1][2] := -2 * planeNormal[1] * planeNormal[2];
  Result[1][3] := 0;
  // 3rd column
  Result[2][0] := -2 * planeNormal[2] * planeNormal[0];
  Result[2][1] := -2 * planeNormal[2] * planeNormal[1];
  Result[2][2] := 1 - 2 * Sqr(planeNormal[2]);
  Result[2][3] := 0;
  // 4th column
  Result[3][0] := pv2 * planeNormal[0];
  Result[3][1] := pv2 * planeNormal[1];
  Result[3][2] := pv2 * planeNormal[2];
  Result[3][3] := 1;
end;

// PackRotationMatrix
//
function PackRotationMatrix(const mat: TMatrix): TPackedRotationMatrix;
var
  q: TQuaternion;
const
  cFact: Single = 32767;
begin
  q := QuaternionFromMatrix(mat);
  NormalizeQuaternion(q);
  if q.RealPart < 0 then
    begin
      Result[0] := Round(-q.ImagPart[0] * cFact);
      Result[1] := Round(-q.ImagPart[1] * cFact);
      Result[2] := Round(-q.ImagPart[2] * cFact);
    end
  else
    begin
      Result[0] := Round(q.ImagPart[0] * cFact);
      Result[1] := Round(q.ImagPart[1] * cFact);
      Result[2] := Round(q.ImagPart[2] * cFact);
    end;
end;

// UnPackRotationMatrix
//
function UnPackRotationMatrix(const packedMatrix: TPackedRotationMatrix): TMatrix;
var
  q: TQuaternion;
const
  cFact: Single = 1 / 32767;
begin
  q.ImagPart[0] := packedMatrix[0] * cFact;
  q.ImagPart[1] := packedMatrix[1] * cFact;
  q.ImagPart[2] := packedMatrix[2] * cFact;
  q.RealPart := 1 - VectorNorm(q.ImagPart);
  if q.RealPart < 0 then
      q.RealPart := 0
  else
      q.RealPart := Sqrt(q.RealPart);
  Result := QuaternionToMatrix(q);
end;

// BarycentricCoordinates
//
function BarycentricCoordinates(const v1, v2, v3, p: TAffineVector; var u, v: Single): Boolean;
var
  a1, a2: Integer;
  n, e1, e2, pt: TAffineVector;
begin
  // calculate edges
  VectorSubtract(v1, v3, e1);
  VectorSubtract(v2, v3, e2);

  // calculate p relative to v3
  VectorSubtract(p, v3, pt);

  // find the dominant axis
  n := VectorCrossProduct(e1, e2);
  AbsVector(n);
  a1 := 0;
  if n[1] > n[a1] then
      a1 := 1;
  if n[2] > n[a1] then
      a1 := 2;

  // use dominant axis for projection
  case a1 of
    0:
      begin
        a1 := 1;
        a2 := 2;
      end;
    1:
      begin
        a1 := 0;
        a2 := 2;
      end;
    else // 2:
        a1 := 0;
      a2 := 1;
  end;

  // solve for u and v
  u := (pt[a2] * e2[a1] - pt[a1] * e2[a2]) / (e1[a2] * e2[a1] - e1[a1] * e2[a2]);
  v := (pt[a2] * e1[a1] - pt[a1] * e1[a2]) / (e2[a2] * e1[a1] - e2[a1] * e1[a2]);

  Result := (u >= 0) and (v >= 0) and (u + v <= 1);
end;

{ ***************************************************************************** }

// VectorMake functions
// 2x
function Vector2fMake(const x, y: Single): TVector2f;
begin
  Result[0] := x;
  Result[1] := y;
end;


// **************

function Vector2fMake(const Vector: TVector3f): TVector2f;
begin
  Result[0] := Vector[0];
  Result[1] := Vector[1];
end;

// **********

function Vector2fMake(const Vector: TVector4f): TVector2f;
begin
  Result[0] := Vector[0];
  Result[1] := Vector[1];
end;

{ ***************************************************************************** }

// 3x
function Vector3fMake(const x, y, Z: Single): TVector3f;
begin
  Result[0] := x;
  Result[1] := y;
  Result[2] := Z;
end;

// *******

function Vector3fMake(const Vector: TVector2f; const Z: Single): TVector3f;
begin
  Result[0] := Vector[0];
  Result[1] := Vector[1];
  Result[2] := Z;
end;

// *******

function Vector3fMake(const Vector: TVector4f): TVector3f;
begin
  Result[0] := Vector[0];
  Result[1] := Vector[1];
  Result[2] := Vector[2];
end;

{ ***************************************************************************** }

// 4x
function Vector4fMake(const x, y, Z, w: Single): TVector4f;
begin
  Result[0] := x;
  Result[1] := y;
  Result[2] := Z;
  Result[3] := w;
end;

// ********

function Vector4fMake(const Vector: TVector3f; const w: Single): TVector4f;
begin
  Result[0] := Vector[0];
  Result[1] := Vector[1];
  Result[2] := Vector[2];
  Result[3] := w;
end;

// *******

function Vector4fMake(const Vector: TVector2f; const Z: Single; const w: Single): TVector4f;
begin
  Result[0] := Vector[0];
  Result[1] := Vector[1];
  Result[2] := Z;
  Result[3] := w;
end;

{ ***************************************************************************** }

// 2
function VectorEquals(const v1, v2: TVector2f): Boolean;
begin
  Result := (v1[0] = v2[0]) and (v1[1] = v2[1]);
end;

{ ***************************************************************************** }

// 3x3f
function MatrixEquals(const Matrix1, Matrix2: TMatrix3f): Boolean;
begin
  Result := VectorEquals(Matrix1[0], Matrix2[0]) and
    VectorEquals(Matrix1[1], Matrix2[1]) and
    VectorEquals(Matrix1[2], Matrix2[2]);
end;

// 3x3i
{ ***************************************************************************** }

// 4x4f
function MatrixEquals(const Matrix1, Matrix2: TMatrix4f): Boolean;
begin
  Result := VectorEquals(Matrix1[0], Matrix2[0]) and
    VectorEquals(Matrix1[1], Matrix2[1]) and
    VectorEquals(Matrix1[2], Matrix2[2]) and
    VectorEquals(Matrix1[3], Matrix2[3]);
end;

{ ***************************************************************************** }

// Vector comparison functions:
// 3f
function VectorMoreThen(const SourceVector, ComparedVector: TVector3f): Boolean;
begin
  Result := (SourceVector[0] > ComparedVector[0]) and
    (SourceVector[1] > ComparedVector[1]) and
    (SourceVector[2] > ComparedVector[2]);
end;

function VectorMoreEqualThen(const SourceVector, ComparedVector: TVector3f): Boolean;
begin
  Result := (SourceVector[0] >= ComparedVector[0]) and
    (SourceVector[1] >= ComparedVector[1]) and
    (SourceVector[2] >= ComparedVector[2]);
end;

function VectorLessThen(const SourceVector, ComparedVector: TVector3f): Boolean;
begin
  Result := (SourceVector[0] < ComparedVector[0]) and
    (SourceVector[1] < ComparedVector[1]) and
    (SourceVector[2] < ComparedVector[2]);
end;

function VectorLessEqualThen(const SourceVector, ComparedVector: TVector3f): Boolean;
begin
  Result := (SourceVector[0] <= ComparedVector[0]) and
    (SourceVector[1] <= ComparedVector[1]) and
    (SourceVector[2] <= ComparedVector[2]);
end;

// 4f
function VectorMoreThen(const SourceVector, ComparedVector: TVector4f): Boolean;
begin
  Result := (SourceVector[0] > ComparedVector[0]) and
    (SourceVector[1] > ComparedVector[1]) and
    (SourceVector[2] > ComparedVector[2]) and
    (SourceVector[3] > ComparedVector[3]);
end;

function VectorMoreEqualThen(const SourceVector, ComparedVector: TVector4f): Boolean;
begin
  Result := (SourceVector[0] >= ComparedVector[0]) and
    (SourceVector[1] >= ComparedVector[1]) and
    (SourceVector[2] >= ComparedVector[2]) and
    (SourceVector[3] >= ComparedVector[3]);
end;

function VectorLessThen(const SourceVector, ComparedVector: TVector4f): Boolean;
begin
  Result := (SourceVector[0] < ComparedVector[0]) and
    (SourceVector[1] < ComparedVector[1]) and
    (SourceVector[2] < ComparedVector[2]) and
    (SourceVector[3] < ComparedVector[3]);
end;

function VectorLessEqualThen(const SourceVector, ComparedVector: TVector4f): Boolean;
begin
  Result := (SourceVector[0] <= ComparedVector[0]) and
    (SourceVector[1] <= ComparedVector[1]) and
    (SourceVector[2] <= ComparedVector[2]) and
    (SourceVector[3] <= ComparedVector[3]);
end;

// ComparedNumber
// 3f
function VectorMoreThen(const SourceVector: TVector3f; const ComparedNumber: Single): Boolean;
begin
  Result := (SourceVector[0] > ComparedNumber) and
    (SourceVector[1] > ComparedNumber) and
    (SourceVector[2] > ComparedNumber);
end;

function VectorMoreEqualThen(const SourceVector: TVector3f; const ComparedNumber: Single): Boolean;
begin
  Result := (SourceVector[0] >= ComparedNumber) and
    (SourceVector[1] >= ComparedNumber) and
    (SourceVector[2] >= ComparedNumber);
end;

function VectorLessThen(const SourceVector: TVector3f; const ComparedNumber: Single): Boolean;
begin
  Result := (SourceVector[0] < ComparedNumber) and
    (SourceVector[1] < ComparedNumber) and
    (SourceVector[2] < ComparedNumber);
end;

function VectorLessEqualThen(const SourceVector: TVector3f; const ComparedNumber: Single): Boolean;
begin
  Result := (SourceVector[0] <= ComparedNumber) and
    (SourceVector[1] <= ComparedNumber) and
    (SourceVector[2] <= ComparedNumber);
end;

// 4f
function VectorMoreThen(const SourceVector: TVector4f; const ComparedNumber: Single): Boolean;
begin
  Result := (SourceVector[0] > ComparedNumber) and
    (SourceVector[1] > ComparedNumber) and
    (SourceVector[2] > ComparedNumber) and
    (SourceVector[3] > ComparedNumber);
end;

function VectorMoreEqualThen(const SourceVector: TVector4f; const ComparedNumber: Single): Boolean;
begin
  Result := (SourceVector[0] >= ComparedNumber) and
    (SourceVector[1] >= ComparedNumber) and
    (SourceVector[2] >= ComparedNumber) and
    (SourceVector[3] >= ComparedNumber);
end;

function VectorLessThen(const SourceVector: TVector4f; const ComparedNumber: Single): Boolean;
begin
  Result := (SourceVector[0] < ComparedNumber) and
    (SourceVector[1] < ComparedNumber) and
    (SourceVector[2] < ComparedNumber) and
    (SourceVector[3] < ComparedNumber);
end;

function VectorLessEqualThen(const SourceVector: TVector4f; const ComparedNumber: Single): Boolean;
begin
  Result := (SourceVector[0] <= ComparedNumber) and
    (SourceVector[1] <= ComparedNumber) and
    (SourceVector[2] <= ComparedNumber) and
    (SourceVector[3] <= ComparedNumber);
end;

{ Determine if 2 rectanges intersect. }
function RectanglesIntersect(const CenterOfRect_1, CenterOfRect_2, SizeOfRect_1, SizeOfRect_2: TVector2f): Boolean;
begin
  Result := (Abs(CenterOfRect_1[0] - CenterOfRect_2[0]) < (SizeOfRect_1[0] + SizeOfRect_2[0]) / 2) and
    (Abs(CenterOfRect_1[1] - CenterOfRect_2[1]) < (SizeOfRect_1[1] + SizeOfRect_2[1]) / 2);
end;

{ Determine if BigRect completely contains SmallRect. }
function RectangleContains(const CenterOfBigRect_1, ACenterOfSmallRect2,
  SizeOfBigRect_1, SizeOfSmallRect_2: TVector2f; const Eps_: Single = 0.0): Boolean;
begin
  Result := (Abs(CenterOfBigRect_1[0] - ACenterOfSmallRect2[0]) + SizeOfSmallRect_2[0] / 2 - SizeOfBigRect_1[0] / 2 < Eps_) and
    (Abs(CenterOfBigRect_1[1] - ACenterOfSmallRect2[1]) + SizeOfSmallRect_2[1] / 2 - SizeOfBigRect_1[1] / 2 < Eps_);
end;

function MoveObjectAround(const MovingObjectPosition_, MovingObjectUp_, TargetPosition_: TVector; pitchDelta, turnDelta: Single): TVector;
var
  originalT2C, normalT2C, normalCameraRight: TVector;
  pitchNow, Dist: Single;
begin
  // normalT2C points away from the direction the camera is looking
  originalT2C := VectorSubtract(MovingObjectPosition_, TargetPosition_);
  SetVector(normalT2C, originalT2C);
  Dist := VectorLength(normalT2C);
  NormalizeVector(normalT2C);
  // normalRight points to the camera's right
  // the camera is pitching around this axis.
  normalCameraRight := VectorCrossProduct(MovingObjectUp_, normalT2C);
  if VectorLength(normalCameraRight) < 0.001 then
      SetVector(normalCameraRight, XVector) // arbitrary vector
  else
      NormalizeVector(normalCameraRight);
  // calculate the current pitch.
  // 0 is looking down and PI is looking up
  pitchNow := ArcCos_(VectorDotProduct(MovingObjectUp_, normalT2C));
  pitchNow := ClampValue(pitchNow + DegToRad_(pitchDelta), 0 + 0.025, pi -
      0.025);
  // create a new vector pointing up and then rotate it down
  // into the new position
  SetVector(normalT2C, MovingObjectUp_);
  RotateVector(normalT2C, normalCameraRight, -pitchNow);
  RotateVector(normalT2C, MovingObjectUp_, -DegToRad_(turnDelta));
  ScaleVector(normalT2C, Dist);
  Result := VectorAdd(MovingObjectPosition_, VectorSubtract(normalT2C,
      originalT2C));
end;

{ Calcualtes Angle between 2 Vectors: (A-CenterPoint) and (B-CenterPoint). In radians. }
function AngleBetweenVectors(const a, b, ACenterPoint: TVector): Single;
begin
  Result := ArcCos_(VectorAngleCosine(
      VectorNormalize(VectorSubtract(a, ACenterPoint)),
      VectorNormalize(VectorSubtract(b, ACenterPoint))));
end;

{ Calcualtes Angle between 2 Vectors: (A-CenterPoint) and (B-CenterPoint). In radians. }
function AngleBetweenVectors(const a, b, ACenterPoint: TAffineVector): Single;
begin
  Result := ArcCos_(VectorAngleCosine(
      VectorNormalize(VectorSubtract(a, ACenterPoint)),
      VectorNormalize(VectorSubtract(b, ACenterPoint))));
end;

{ OriginalPosition_ - Object initial position.
  Center_ - some point, from which is should be distanced.

  Distance_ + FromCenterSpot_ - distance, which object should keep from Center_
  or
  Distance_ + not FromCenterSpot_ - distance, which object should shift from his current position away from center.
}
function ShiftObjectFromCenter(const OriginalPosition_: TVector;
  const Center_: TVector; const Distance_: Single; const FromCenterSpot_: Boolean): TVector;
var
  lDirection: TVector;
begin
  lDirection := VectorNormalize(VectorSubtract(OriginalPosition_, Center_));
  if FromCenterSpot_ then
      Result := VectorAdd(Center_, VectorScale(lDirection, Distance_))
  else
      Result := VectorAdd(OriginalPosition_, VectorScale(lDirection, Distance_))
end;

{ OriginalPosition_ - Object initial position.
  Center_ - some point, from which is should be distanced.

  Distance_ + FromCenterSpot_ - distance, which object should keep from Center_
  or
  Distance_ + not FromCenterSpot_ - distance, which object should shift from his current position away from center.
}
function ShiftObjectFromCenter(const OriginalPosition_: TAffineVector;
  const Center_: TAffineVector; const Distance_: Single; const FromCenterSpot_: Boolean): TAffineVector;
var
  lDirection: TAffineVector;
begin
  lDirection := VectorNormalize(VectorSubtract(OriginalPosition_, Center_));
  if FromCenterSpot_ then
      Result := VectorAdd(Center_, VectorScale(lDirection, Distance_))
  else
      Result := VectorAdd(OriginalPosition_, VectorScale(lDirection, Distance_))
end;

initialization

end.
