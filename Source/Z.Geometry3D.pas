{
  *  Z.Geometry3D – 3D geometry and linear algebra library.
  *
  *  This unit provides a comprehensive set of 3D geometric types and operations,
  *  built upon the low‑level geometry routines from Z.Geometry.Low and Z.Geometry2D.
  *  It defines strongly‑typed records for vectors (2D, 3D, 4D) and 4×4 matrices,
  *  with operator overloading for arithmetic, transformations, and interpolation.
  *
  *  Main features:
  *    - TMatrix4: 4×4 homogeneous transformation matrix with methods for inversion,
  *      transposition, affine decomposition, pitch/roll/turn rotations, and interpolation.
  *    - TVector4, TVector3, TVector2: strongly‑typed vector records that wrap
  *      the underlying array types (TVec4, TVec3, TVec2). They support component‑wise
  *      arithmetic, dot/cross products, normalisation, distance calculations,
  *      linear interpolation (Lerp), and conversion to/from lower dimensions.
  *    - TAABB: Axis‑Aligned Bounding Box for collision and inclusion tests.
  *    - Global helper functions for parsing vectors from strings, computing
  *      angles, movement (smooth interpolation with distance/step), and bouncing
  *      (oscillation between two bounds).
  *
  *  The library is designed to be used in game development, simulation,
  *  CAD, and any other application that requires 3D vector and matrix maths.
  *  It is cross‑compiler (Delphi/FPC) and uses the Z.Core and Z.Geometry.Low
  *  infrastructure for performance and portability.
}

unit Z.Geometry3D;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses Types, Z.Core,
  Z.Geometry.Low, Z.Geometry2D, Z.PascalStrings, Z.UPascalStrings, Z.UnicodeMixedLib;

type
  { Alias for a 4×4 homogeneous matrix (TMatrix from Z.Geometry.Low). }
  TMat4 = TMatrix;

  { Alias for a 4‑component vector (TVector from Z.Geometry.Low). }
  TVec4 = TVector;

  { Alias for a 3‑component affine vector (TAffineVector from Z.Geometry.Low). }
  TVec3 = TAffineVector;

  {
    TMatrix4 – a 4×4 homogeneous transformation matrix with strong typing
    and operator overloading.

    Internally stores a TMat4 (array[0..3] of TVec4) and provides methods for
    common matrix operations. All operations are performed using the underlying
    low‑level geometry library.
  }
  TMatrix4 = record
    Buff: TMat4;
    /// < Underlying 4×4 matrix storage.
  public
    { Equality comparison (component‑wise). }
    class operator Equal(const Lhs, Rhs: TMatrix4): Boolean;
    { Inequality comparison. }
    class operator NotEqual(const Lhs, Rhs: TMatrix4): Boolean;
    { Matrix multiplication (concatenation). }
    class operator Multiply(const Lhs, Rhs: TMatrix4): TMatrix4;
    { Implicit conversion from a scalar: sets all components to the scalar value. }
    class operator Implicit(Value: TGeoFloat): TMatrix4;
    { Implicit conversion from a raw TMat4 array. }
    class operator Implicit(Value: TMat4): TMatrix4;

    { Returns the transpose of the matrix. }
    function Swap: TMatrix4;
    { Linearly interpolates between this matrix and another by Delta (0..1). }
    function Lerp(M: TMatrix4; Delta: TGeoFloat): TMatrix4;
    { Extracts the affine (3×3) part of the matrix. }
    function AffineMatrix: TAffineMatrix;
    { Computes the inverse of the matrix (if singular, returns identity). }
    function Invert: TMatrix4;
    { Translates the matrix by a 3D vector. }
    function Translate(v: TVec3): TMatrix4;
    { Normalises the matrix (scales each row to unit length). }
    function Normalize: TMatrix4;
    { Returns the transpose of the matrix. }
    function Transpose: TMatrix4;
    { Computes the angle‑preserving inverse (orthogonal inversion). }
    function AnglePreservingInvert: TMatrix4;
    { Computes the determinant of the matrix. }
    function Determinant: TGeoFloat;
    { Returns the adjugate (classical adjoint) matrix. }
    function Adjoint: TMatrix4;
    { Applies a pitch rotation (around X‑axis) by the given angle (in degrees). }
    function Pitch(angle: TGeoFloat): TMatrix4;
    { Applies a roll rotation (around Z‑axis) by the given angle (in degrees). }
    function Roll(angle: TGeoFloat): TMatrix4;
    { Applies a turn rotation (around Y‑axis) by the given angle (in degrees). }
    function Turn(angle: TGeoFloat): TMatrix4;
  end;

  {
    TVector4 – a 4‑component vector (homogeneous, RGBA, or general purpose)
    with strong typing and operator overloading.

    Wraps a TVec4 (array[0..3] of TGeoFloat) and provides many common vector
    operations: component‑wise arithmetic, dot product, cross product (3D),
    normalisation, distance, linear interpolation, and conversions to/from
    TVector3 and TVector2. The vector can be interpreted as a point, direction,
    colour, or any 4D quantity.
  }
  TVector4 = record
    Buff: TVec4;
    /// < Underlying 4‑component storage.
  private
    { Returns the 3‑component affine vector (ignores the 4th component). }
    function GetVec3: TVec3;
    { Sets the 3‑component affine vector (4th component set to 0). }
    procedure SetVec3(const Value: TVec3);
    { Returns the 2‑component vector (first two components). }
    function GetVec2: TVec2;
    { Sets the 2‑component vector (first two components). }
    procedure SetVec2(const Value: TVec2);
    { Gets the i‑th component (0‑based). }
    function GetLinkValue(index: Integer): TGeoFloat;
    { Sets the i‑th component (0‑based). }
    procedure SetLinkValue(index: Integer; const Value: TGeoFloat);
  public
    { Access the vector as a 2D vector (x,y). }
    property Vec2: TVec2 read GetVec2 write SetVec2;
    { Access the vector as a 3D vector (x,y,z). }
    property Vec3: TVec3 read GetVec3 write SetVec3;
    { Alias for Vec3. }
    property XYZ: TVec3 read GetVec3 write SetVec3;
    { Alias for Vec3 (treating as RGB colour). }
    property RGB: TVec3 read GetVec3 write SetVec3;
    { Direct access to the underlying 4D vector. }
    property Vec4: TVec4 read Buff write Buff;
    { Alias for Vec4 (treating as RGBA colour). }
    property RGBA: TVec4 read Buff write Buff;
    { Alias for Vec4. }
    property COLOR: TVec4 read Buff write Buff;
    { Indexed component access (0‑based). }
    property LinkValue[index: Integer]: TGeoFloat read GetLinkValue write SetLinkValue; default;

    { Component‑wise equality. }
    class operator Equal(const Lhs, Rhs: TVector4): Boolean;
    { Component‑wise inequality. }
    class operator NotEqual(const Lhs, Rhs: TVector4): Boolean;
    { All components greater than. }
    class operator GreaterThan(const Lhs, Rhs: TVector4): Boolean;
    { All components greater or equal. }
    class operator GreaterThanOrEqual(const Lhs, Rhs: TVector4): Boolean;
    { All components less than. }
    class operator LessThan(const Lhs, Rhs: TVector4): Boolean;
    { All components less or equal. }
    class operator LessThanOrEqual(const Lhs, Rhs: TVector4): Boolean;

    { Vector addition (component‑wise). }
    class operator Add(const Lhs, Rhs: TVector4): TVector4;
    { Vector plus scalar (add scalar to each component). }
    class operator Add(const Lhs: TVector4; const Rhs: TGeoFloat): TVector4;
    { Scalar plus vector. }
    class operator Add(const Lhs: TGeoFloat; const Rhs: TVector4): TVector4;

    { Vector subtraction (component‑wise). }
    class operator Subtract(const Lhs, Rhs: TVector4): TVector4;
    { Vector minus scalar. }
    class operator Subtract(const Lhs: TVector4; const Rhs: TGeoFloat): TVector4;
    { Scalar minus vector. }
    class operator Subtract(const Lhs: TGeoFloat; const Rhs: TVector4): TVector4;

    { Component‑wise multiplication (Hadamard product). }
    class operator Multiply(const Lhs, Rhs: TVector4): TVector4;
    { Vector multiplied by scalar. }
    class operator Multiply(const Lhs: TVector4; const Rhs: TGeoFloat): TVector4;
    { Scalar multiplied by vector. }
    class operator Multiply(const Lhs: TGeoFloat; const Rhs: TVector4): TVector4;
    { Vector transformed by a 4×4 matrix (matrix on the right). }
    class operator Multiply(const Lhs: TVector4; const Rhs: TMatrix4): TVector4;
    { Vector transformed by a 4×4 matrix (matrix on the left). }
    class operator Multiply(const Lhs: TMatrix4; const Rhs: TVector4): TVector4;
    { Vector transformed by a raw TMat4. }
    class operator Multiply(const Lhs: TVector4; const Rhs: TMat4): TVector4;
    class operator Multiply(const Lhs: TMat4; const Rhs: TVector4): TVector4;
    { Vector transformed by an affine 3×3 matrix. }
    class operator Multiply(const Lhs: TVector4; const Rhs: TAffineMatrix): TVector4;
    class operator Multiply(const Lhs: TAffineMatrix; const Rhs: TVector4): TVector4;

    { Component‑wise division. }
    class operator Divide(const Lhs, Rhs: TVector4): TVector4;
    { Vector divided by scalar. }
    class operator Divide(const Lhs: TVector4; const Rhs: TGeoFloat): TVector4;
    { Scalar divided by vector (component‑wise). }
    class operator Divide(const Lhs: TGeoFloat; const Rhs: TVector4): TVector4;

    { Implicit conversion from scalar: sets all components to that value. }
    class operator Implicit(Value: TGeoFloat): TVector4;
    { Implicit conversion from raw TVec4. }
    class operator Implicit(Value: TVec4): TVector4;
    { Implicit conversion from TVec3 (sets 4th component to 0). }
    class operator Implicit(Value: TVec3): TVector4;
    { Implicit conversion from TVec2 (sets 3rd and 4th to 0). }
    class operator Implicit(Value: TVec2): TVector4;

    { Explicit conversion to TVec4. }
    class operator Explicit(Value: TVector4): TVec4;
    { Explicit conversion to TVec3 (dropping the 4th component). }
    class operator Explicit(Value: TVector4): TVec3;
    { Explicit conversion to TVec2 (dropping 3rd and 4th). }
    class operator Explicit(Value: TVector4): TVec2;

    { Set all four components (RGBA style). }
    procedure SetRGBA(const r, g, b, a: TGeoFloat); overload;
    { Set all four components (location style). }
    procedure SetLocation(const fx, fy, fz, fw: TGeoFloat); overload;
    { Set the first three components (4th unchanged). }
    procedure SetLocation(const fx, fy, fz: TGeoFloat); overload;

    { Euclidean distance in 4D. }
    function Distance4D(const v2: TVector4): TGeoFloat;
    { Euclidean distance in 3D (ignoring the 4th component). }
    function Distance3D(const v2: TVector4): TGeoFloat;
    { Euclidean distance in 2D (ignoring 3rd and 4th components). }
    function Distance2D(const v2: TVector4): TGeoFloat;

    { Linear interpolation towards v2 by factor t (0..1). }
    function Lerp(const v2: TVector4; const t: TGeoFloat): TVector4;
    { Move towards v2 by a fixed distance d (clamps at v2 if d >= distance). }
    function LerpDistance(const v2: TVector4; const d: TGeoFloat): TVector4;

    { Squared norm (sum of squares). }
    function Norm: TGeoFloat;
    { Euclidean length. }
    function length: TGeoFloat;
    { Returns a unit vector in the same direction (if norm ≠ 0). }
    function Normalize: TVector4;

    { Cross product in 3D (ignores 4th component, returns vector with 4th=0). }
    function Cross(const v2: TVector4): TVector4; overload;
    { Cross product with a TVec3. }
    function Cross(const v2: TVec3): TVector4; overload;
    { Cross product with a TVec4. }
    function Cross(const v2: TVec4): TVector4; overload;
  end;

  {
    TVector3 – a 3‑component vector (point, direction, colour) with strong typing
    and operator overloading.

    Wraps a TVec3 (array[0..2] of TGeoFloat) and provides 3D vector operations:
    arithmetic, dot and cross products, normalisation, distance, interpolation,
    and conversions to/from TVector4 and TVector2.
  }
  TVector3 = record
    Buff: TVec3;
    /// < Underlying 3‑component storage.
  private
    { Returns the 2‑component vector (first two components). }
    function GetVec2: TVec2;
    { Sets the 2‑component vector (first two components). }
    procedure SetVec2(const Value: TVec2);
    { Gets the i‑th component (0‑based). }
    function GetLinkValue(index: Integer): TGeoFloat;
    { Sets the i‑th component (0‑based). }
    procedure SetLinkValue(index: Integer; const Value: TGeoFloat);
  public
    { Access the vector as a 2D vector (x,y). }
    property Vec2: TVec2 read GetVec2 write SetVec2;
    { Direct access to the underlying 3D vector. }
    property Vec3: TVec3 read Buff write Buff;
    { Alias for Vec3. }
    property XYZ: TVec3 read Buff write Buff;
    { Alias for Vec3 (treating as RGB colour). }
    property COLOR: TVec3 read Buff write Buff;
    { Alias for Vec3. }
    property RGB: TVec3 read Buff write Buff;
    { Indexed component access (0‑based). }
    property LinkValue[index: Integer]: TGeoFloat read GetLinkValue write SetLinkValue; default;

    { Component‑wise equality. }
    class operator Equal(const Lhs, Rhs: TVector3): Boolean;
    { Component‑wise inequality. }
    class operator NotEqual(const Lhs, Rhs: TVector3): Boolean;
    { All components greater than. }
    class operator GreaterThan(const Lhs, Rhs: TVector3): Boolean;
    { All components greater or equal. }
    class operator GreaterThanOrEqual(const Lhs, Rhs: TVector3): Boolean;
    { All components less than. }
    class operator LessThan(const Lhs, Rhs: TVector3): Boolean;
    { All components less or equal. }
    class operator LessThanOrEqual(const Lhs, Rhs: TVector3): Boolean;

    { Vector addition (component‑wise). }
    class operator Add(const Lhs, Rhs: TVector3): TVector3;
    { Vector plus scalar. }
    class operator Add(const Lhs: TVector3; const Rhs: TGeoFloat): TVector3;
    { Scalar plus vector. }
    class operator Add(const Lhs: TGeoFloat; const Rhs: TVector3): TVector3;

    { Vector subtraction (component‑wise). }
    class operator Subtract(const Lhs, Rhs: TVector3): TVector3;
    { Vector minus scalar. }
    class operator Subtract(const Lhs: TVector3; const Rhs: TGeoFloat): TVector3;
    { Scalar minus vector. }
    class operator Subtract(const Lhs: TGeoFloat; const Rhs: TVector3): TVector3;

    { Component‑wise multiplication. }
    class operator Multiply(const Lhs, Rhs: TVector3): TVector3;
    { Vector multiplied by scalar. }
    class operator Multiply(const Lhs: TVector3; const Rhs: TGeoFloat): TVector3;
    { Scalar multiplied by vector. }
    class operator Multiply(const Lhs: TGeoFloat; const Rhs: TVector3): TVector3;
    { Vector transformed by a 4×4 matrix (matrix on the right). }
    class operator Multiply(const Lhs: TVector3; const Rhs: TMatrix4): TVector3;
    { Vector transformed by a 4×4 matrix (matrix on the left). }
    class operator Multiply(const Lhs: TMatrix4; const Rhs: TVector3): TVector3;
    { Vector transformed by a raw TMat4. }
    class operator Multiply(const Lhs: TVector3; const Rhs: TMat4): TVector3;
    class operator Multiply(const Lhs: TMat4; const Rhs: TVector3): TVector3;
    { Vector transformed by an affine 3×3 matrix. }
    class operator Multiply(const Lhs: TVector3; const Rhs: TAffineMatrix): TVector3;
    class operator Multiply(const Lhs: TAffineMatrix; const Rhs: TVector3): TVector3;

    { Component‑wise division. }
    class operator Divide(const Lhs, Rhs: TVector3): TVector3;
    { Vector divided by scalar. }
    class operator Divide(const Lhs: TVector3; const Rhs: TGeoFloat): TVector3;
    { Scalar divided by vector. }
    class operator Divide(const Lhs: TGeoFloat; const Rhs: TVector3): TVector3;

    { Implicit conversion from scalar: sets all components to that value. }
    class operator Implicit(Value: TGeoFloat): TVector3;
    { Implicit conversion from TVec4 (drops 4th component). }
    class operator Implicit(Value: TVec4): TVector3;
    { Implicit conversion from TVec3. }
    class operator Implicit(Value: TVec3): TVector3;
    { Implicit conversion from TVec2 (sets z=0). }
    class operator Implicit(Value: TVec2): TVector3;

    { Explicit conversion to TVec4 (sets 4th component to 0). }
    class operator Explicit(Value: TVector3): TVec4;
    { Explicit conversion to TVec3. }
    class operator Explicit(Value: TVector3): TVec3;
    { Explicit conversion to TVec2 (drops z). }
    class operator Explicit(Value: TVector3): TVec2;

    { Set all three components. }
    procedure SetLocation(const fx, fy, fz: TGeoFloat); overload;

    { Euclidean distance in 3D. }
    function Distance3D(const v2: TVector3): TGeoFloat;
    { Euclidean distance in 2D (ignoring z). }
    function Distance2D(const v2: TVector3): TGeoFloat;

    { Linear interpolation towards v2 by factor t (0..1). }
    function Lerp(const v2: TVector3; const t: TGeoFloat): TVector3;
    { Move towards v2 by a fixed distance d. }
    function LerpDistance(const v2: TVector3; const d: TGeoFloat): TVector3;

    { Squared norm. }
    function Norm: TGeoFloat;
    { Euclidean length. }
    function length: TGeoFloat;
    { Returns a unit vector. }
    function Normalize: TVector3;

    { 3D cross product. }
    function Cross(const v2: TVector3): TVector3;

    { Convert to a TVector4 with a given 4th component. }
    function Vec4(fw: TGeoFloat): TVector4; overload;
    { Convert to a TVector4 with 4th component set to 0. }
    function Vec4: TVector4; overload;
  end;

  {
    TAABB – Axis‑Aligned Bounding Box defined by two 3D points: Min and Max.

    Provides methods to expand the box to include a point, create a sweep
    volume, compute intersection with another AABB, offset, and test point
    inclusion.
  }
  TAABB = record
    Min, Max: TAffineVector;
    /// < Minimum and maximum corners of the box.
  public
    { Expand the AABB to include the given point p. }
    procedure Include(const p: TVector3);

    { Create an AABB that encloses the swept volume of a sphere (or AABB)
      moving from Start to Dest with the given radius. }
    procedure FromSweep(const Start, dest: TVector3; const radius: TGeoFloat);

    { Return the intersection of this AABB with another. If they do not
      intersect, the resulting AABB will be degenerate (plane, line or point). }
    function Intersection(const aabb2: TAABB): TAABB;

    { Offset both Min and Max by Delta. }
    procedure Offset(const Delta: TVector3);

    { Test if point p is inside the AABB (inclusive). }
    function PointIn(const p: TVector3): Boolean;
  end;

  {
    TVector2 – a 2‑component vector with strong typing and operator overloading.

    Wraps a TVec2 (array[0..1] of TGeoFloat) and provides 2D vector operations:
    arithmetic, normalisation, distance, interpolation, and conversions from/to
    TPoint, TPointf, and TVec2. This complements the 3D types for 2D contexts.
  }
  TVector2 = record
    Buff: TVec2;
    /// < Underlying 2‑component storage.
  private
    { Gets the i‑th component (0‑based). }
    function GetLinkValue(index: Integer): TGeoFloat;
    { Sets the i‑th component (0‑based). }
    procedure SetLinkValue(index: Integer; const Value: TGeoFloat);
  public
    { Indexed component access (0‑based). }
    property LinkValue[index: Integer]: TGeoFloat read GetLinkValue write SetLinkValue; default;

    { Component‑wise equality (using Epsilon tolerance). }
    class operator Equal(const Lhs, Rhs: TVector2): Boolean;
    { Component‑wise inequality. }
    class operator NotEqual(const Lhs, Rhs: TVector2): Boolean;
    { All components greater than. }
    class operator GreaterThan(const Lhs, Rhs: TVector2): Boolean;
    { All components greater or equal. }
    class operator GreaterThanOrEqual(const Lhs, Rhs: TVector2): Boolean;
    { All components less than. }
    class operator LessThan(const Lhs, Rhs: TVector2): Boolean;
    { All components less or equal. }
    class operator LessThanOrEqual(const Lhs, Rhs: TVector2): Boolean;

    { Vector addition (component‑wise). }
    class operator Add(const Lhs, Rhs: TVector2): TVector2;
    { Vector plus scalar. }
    class operator Add(const Lhs: TVector2; const Rhs: TGeoFloat): TVector2;
    { Scalar plus vector. }
    class operator Add(const Lhs: TGeoFloat; const Rhs: TVector2): TVector2;

    { Vector subtraction (component‑wise). }
    class operator Subtract(const Lhs, Rhs: TVector2): TVector2;
    { Vector minus scalar. }
    class operator Subtract(const Lhs: TVector2; const Rhs: TGeoFloat): TVector2;
    { Scalar minus vector. }
    class operator Subtract(const Lhs: TGeoFloat; const Rhs: TVector2): TVector2;

    { Component‑wise multiplication. }
    class operator Multiply(const Lhs, Rhs: TVector2): TVector2;
    { Vector multiplied by scalar. }
    class operator Multiply(const Lhs: TVector2; const Rhs: TGeoFloat): TVector2;
    { Scalar multiplied by vector. }
    class operator Multiply(const Lhs: TGeoFloat; const Rhs: TVector2): TVector2;

    { Component‑wise division. }
    class operator Divide(const Lhs, Rhs: TVector2): TVector2;
    { Vector divided by scalar. }
    class operator Divide(const Lhs: TVector2; const Rhs: TGeoFloat): TVector2;
    { Scalar divided by vector. }
    class operator Divide(const Lhs: TGeoFloat; const Rhs: TVector2): TVector2;

    { Implicit conversion from scalar: sets both components to that value. }
    class operator Implicit(Value: TGeoFloat): TVector2;
    { Implicit conversion from TPoint (integer). }
    class operator Implicit(Value: TPoint): TVector2;
    { Implicit conversion from TPointf (single‑precision). }
    class operator Implicit(Value: TPointf): TVector2;
    { Implicit conversion from TVec2. }
    class operator Implicit(Value: TVec2): TVector2;

    { Explicit conversion to TPointf. }
    class operator Explicit(Value: TVector2): TPointf;
    { Explicit conversion to TPoint (rounds components). }
    class operator Explicit(Value: TVector2): TPoint;
    { Explicit conversion to TVec2. }
    class operator Explicit(Value: TVector2): TVec2;

    { Set both components. }
    procedure SetLocation(const fx, fy: TGeoFloat); overload;

    { Euclidean distance to another 2D vector. }
    function Distance(const v2: TVector2): TGeoFloat;

    { Linear interpolation towards v2 by factor t (0..1). }
    function Lerp(const v2: TVector2; const t: TGeoFloat): TVector2;
    { Move towards v2 by a fixed distance d. }
    function LerpDistance(const v2: TVector2; const d: TGeoFloat): TVector2;

    { Squared norm. }
    function Norm: TGeoFloat;
    { Euclidean length. }
    function length: TGeoFloat;
    { Returns a unit vector. }
    function Normalize: TVector2;
  end;

  { Construct a TVector4 from four scalar components. }
function Vector4(x, y, Z, w: TGeoFloat): TVector4; overload;

{ Construct a TVector4 from three scalar components (4th = 0). }
function Vector4(x, y, Z: TGeoFloat): TVector4; overload;

{ Construct a TVector4 from a TVec3 (4th = 0). }
function Vector4(v: TVec3): TVector4; overload;

{ Construct a TVector4 from a TVec4. }
function Vector4(v: TVec4): TVector4; overload;

{ Construct a TVector3 from three scalars. }
function Vector3(x, y, Z: TGeoFloat): TVector3; overload;

{ Construct a TVector3 from a TVec3. }
function Vector3(v: TVec3): TVector3; overload;

{ Construct a TVector3 from a TVec4 (drops 4th component). }
function Vector3(v: TVec4): TVector3; overload;

{ Create a raw TVec3 from three scalars. }
function Vec3(const x, y, Z: TGeoFloat): TVec3; overload;

{ Create a raw TVec3 from a TVec4 (drops 4th). }
function Vec3(const v: TVec4): TVec3; overload;

{ Create a raw TVec3 from a TVector3. }
function Vec3(const v: TVector3): TVec3; overload;

{ Create a raw TVec3 from a TVector2 (z=0). }
function Vec3(const v: TVector2): TVec3; overload;

{ Create a raw TVec3 from a TVector2 and a z value. }
function Vec3(const v: TVector2; Z: TGeoFloat): TVec3; overload;

{ Create a raw TVec4 from x,y,z (w=0). }
function Vec4(const x, y, Z: TGeoFloat): TVec4; overload;

{ Create a raw TVec4 from four scalars. }
function Vec4(const x, y, Z, w: TGeoFloat): TVec4; overload;

{ Create a raw TVec4 from a TVec3 (w=0). }
function Vec4(const v: TVec3): TVec4; overload;

{ Create a raw TVec4 from a TVec3 and a w component. }
function Vec4(const v: TVec3; const Z: TGeoFloat): TVec4; overload;

{ Create a raw TVec4 from a TVector3. }
function Vec4(const v: TVector3): TVec4; overload;

{ Extract a TVector2 from a raw TVec3 (x,y). }
function Vec2(const v: TVec3): TVector2; overload;

{ Extract a TVector2 from a raw TVec4 (x,y). }
function Vec2(const v: TVec4): TVector2; overload;

{ Extract a TVector2 from a TVector3. }
function Vec2(const v: TVector3): TVector2; overload;

{ Extract a TVector2 from a TVector4. }
function Vec2(const v: TVector4): TVector2; overload;

{ Convert a raw TVec2 to a comma‑separated string. }
function VecToStr(const v: TVec2): SystemString; overload;

{ Convert a TVector2 to a comma‑separated string. }
function VecToStr(const v: TVector2): SystemString; overload;

{ Convert an array of TVec2 to a comma‑separated string. }
function VecToStr(const v: TArrayVec2): SystemString; overload;

{ Convert a raw TVec3 to a comma‑separated string. }
function VecToStr(const v: TVec3): SystemString; overload;

{ Convert a raw TVec4 to a comma‑separated string. }
function VecToStr(const v: TVec4): SystemString; overload;

{ Convert a TVector3 to a comma‑separated string. }
function VecToStr(const v: TVector3): SystemString; overload;

{ Convert a TVector4 to a comma‑separated string. }
function VecToStr(const v: TVector4): SystemString; overload;

{ Convert a TV2R4 (four 2D points) to a comma‑separated string. }
function VecToStr(const v: TV2R4): SystemString; overload;

{ Convert a TRectV2 to a comma‑separated string. }
function RectToStr(const v: TRectV2): SystemString; overload;

{ Convert a TRect (integer) to a comma‑separated string. }
function RectToStr(const v: TRect): SystemString; overload;

{ Parse a string to a raw TVec2 (supports separators: comma, colon, space). }
function StrToVec2(const s: SystemString): TVec2;

{ Parse a string to a TVector2. }
function StrToVector2(const s: SystemString): TVector2;

{ Parse a string to an array of TVec2 (pairs of numbers). }
function StrToArrayVec2(const s: SystemString): TArrayVec2;

{ Parse a string to a raw TVec3. }
function StrToVec3(const s: SystemString): TVec3;

{ Parse a string to a raw TVec4. }
function StrToVec4(const s: SystemString): TVec4;

{ Parse a string to a TVector3. }
function StrToVector3(const s: SystemString): TVector3;

{ Parse a string to a TVector4. }
function StrToVector4(const s: SystemString): TVector4;

{ Parse a string to a TV2R4 (requires exactly 8 numbers). }
function StrToV2R4(const s: SystemString): TV2R4;

{ Parse a string to a TRect (integer rectangle). }
function StrToRect(const s: SystemString): TRect;

{ Parse a string to a TRectV2 (float rectangle). }
function StrToRectV2(const s: SystemString): TRectV2;

{ Find the minimum value in an array of TGeoFloat. }
function GetMin(const arry: array of TGeoFloat): TGeoFloat; overload;

{ Find the minimum value in an array of Integer. }
function GetMin(const arry: array of Integer): Integer; overload;

{ Find the maximum value in an array of TGeoFloat. }
function GetMax(const arry: array of TGeoFloat): TGeoFloat; overload;

{ Find the maximum value in an array of Integer. }
function GetMax(const arry: array of Integer): Integer; overload;

{ Convert an angle to FireMonkey's coordinate system (normalise). }
function FinalAngle4FMX(const a: TGeoFloat): TGeoFloat;

{ Compute the angle (in degrees) between two 2D vectors (v1‑v2 direction). }
function CalcAngle(const v1, v2: TVec2): TGeoFloat;

{ Compute the shortest angular distance (in degrees) between two angles. }
function AngleDistance(const sour, dest: TGeoFloat): TGeoFloat;

{ Smoothly interpolate an angle towards a destination with a maximum step delta. }
function SmoothAngle(const sour, dest, Delta: TGeoFloat): TGeoFloat;

{ Test if two angles are equal within a small tolerance (0.01°). }
function AngleEqual(const a1, a2: TGeoFloat): Boolean;

{ Euclidean distance between two 2D points. }
function Distance(const v1, v2: TVec2): TGeoFloat; overload;

{ Distance between two TRectV2 (max of corner distances). }
function Distance(const v1, v2: TRectV2): TGeoFloat; overload;

{ Linear interpolation of a scalar. }
function MovementLerp(const s, d, Lerp: TGeoFloat): TGeoFloat; overload;

{ Linear interpolation of a TVec2. }
function MovementLerp(const s, d: TVec2; Lerp: TGeoFloat): TVec2; overload;

{ Linear interpolation of a TRectV2 (each corner independently). }
function MovementLerp(const s, d: TRectV2; Lerp: TGeoFloat): TRectV2; overload;

{ Move from s towards d by a given distance dt (clamps at d). }
function MovementDistance(const s, d: TVec2; dt: TGeoFloat): TVec2; overload;

{ Move a rectangle's corners independently by a given distance. }
function MovementDistance(const s, d: TRectV2; dt: TGeoFloat): TRectV2; overload;

{ Move a 4D vector towards a destination by a fixed distance. }
function MovementDistance(const sour, dest: TVector4; Distance: TGeoFloat): TVector4; overload;

{ Move a 3D vector towards a destination by a fixed distance. }
function MovementDistance(const sour, dest: TVector3; Distance: TGeoFloat): TVector3; overload;

{ Compute the time (in seconds) needed to move from s to d at a given speed. }
function MovementDistanceDeltaTime(const s, d: TVec2; Speed_: TGeoFloat): Double; overload;

{ Compute the time needed for a rectangle to move (max of corners). }
function MovementDistanceDeltaTime(const s, d: TRectV2; Speed_: TGeoFloat): Double; overload;

{ Compute the time needed to roll from angle s to d at a given angular speed. }
function AngleRollDistanceDeltaTime(const s, d: TGeoFloat; RollSpeed_: TGeoFloat): Double; overload;

{ Bounce a 4D vector between two bounds (bVec and eVec), moving by Step_Dist each call.
  eFlag toggles when the bound is reached. }
function BounceVector(const Current: TVector4; Step_Dist: TGeoFloat; const bVec, eVec: TVector4; var eFlag: Boolean): TVector4; overload;

{ Bounce a 3D vector between two bounds. }
function BounceVector(const Current: TVector3; Step_Dist: TGeoFloat; const bVec, eVec: TVector3; var eFlag: Boolean): TVector3; overload;

{ Bounce a 2D vector between two bounds. }
function BounceVector(const Current: TVector2; Step_Dist: TGeoFloat; const bVec, eVec: TVector2; var eFlag: Boolean): TVector2; overload;

{ Bounce a scalar between two bounds (bFloat and eFloat). }
function BounceFloat(const CurrentVal, Step_Dist, bFloat, eFloat: TGeoFloat; var eFlag: Boolean): TGeoFloat; overload;

implementation

uses Z.Expression;

function Vector4(x, y, Z, w: TGeoFloat): TVector4;
begin
  Result.Buff[0] := x;
  Result.Buff[1] := y;
  Result.Buff[2] := Z;
  Result.Buff[3] := w;
end;

function Vector4(x, y, Z: TGeoFloat): TVector4;
begin
  Result.Buff[0] := x;
  Result.Buff[1] := y;
  Result.Buff[2] := Z;
  Result.Buff[3] := 0;
end;

function Vector4(v: TVec3): TVector4;
begin
  Result.Buff[0] := v[0];
  Result.Buff[1] := v[1];
  Result.Buff[2] := v[2];
  Result.Buff[3] := 0;
end;

function Vector4(v: TVec4): TVector4;
begin
  Result.Buff := v;
end;

function Vector3(x, y, Z: TGeoFloat): TVector3;
begin
  Result.Buff[0] := x;
  Result.Buff[1] := y;
  Result.Buff[2] := Z;
end;

function Vector3(v: TVec3): TVector3;
begin
  Result.Buff := v;
end;

function Vector3(v: TVec4): TVector3;
begin
  Result.Buff[0] := v[0];
  Result.Buff[1] := v[1];
  Result.Buff[2] := v[2];
end;

function Vec3(const x, y, Z: TGeoFloat): TVec3;
begin
  Result := AffineVectorMake(x, y, Z);
end;

function Vec3(const v: TVec4): TVec3;
begin
  Result[0] := v[0];
  Result[1] := v[1];
  Result[2] := v[2];
end;

function Vec3(const v: TVector3): TVec3;
begin
  Result := v.Buff;
end;

function Vec3(const v: TVector2): TVec3;
begin
  Result[0] := v[0];
  Result[1] := v[1];
  Result[2] := 0;
end;

function Vec3(const v: TVector2; Z: TGeoFloat): TVec3;
begin
  Result[0] := v[0];
  Result[1] := v[1];
  Result[2] := Z;
end;

function Vec4(const x, y, Z: TGeoFloat): TVec4;
begin
  Result := VectorMake(x, y, Z, 0);
end;

function Vec4(const x, y, Z, w: TGeoFloat): TVec4;
begin
  Result := VectorMake(x, y, Z, w);
end;

function Vec4(const v: TVec3): TVec4;
begin
  Result := VectorMake(v);
end;

function Vec4(const v: TVec3; const Z: TGeoFloat): TVec4;
begin
  Result := VectorMake(v, Z);
end;

function Vec4(const v: TVector3): TVec4;
begin
  Result := VectorMake(v.Buff);
end;

function Vec2(const v: TVec3): TVector2;
begin
  Result := Vec2(v[0], v[1]);
end;

function Vec2(const v: TVec4): TVector2;
begin
  Result := Vec2(v[0], v[1]);
end;

function Vec2(const v: TVector3): TVector2;
begin
  Result[0] := v.Buff[0];
  Result[1] := v.Buff[1];
end;

function Vec2(const v: TVector4): TVector2;
begin
  Result[0] := v.Buff[0];
  Result[1] := v.Buff[1];
end;

function VecToStr(const v: TVec2): SystemString;
begin
  Result := PFormat('%g,%g', [v[0], v[1]]);
end;

function VecToStr(const v: TVector2): SystemString;
begin
  Result := PFormat('%g,%g', [v[0], v[1]]);
end;

function VecToStr(const v: TArrayVec2): SystemString;
var
  i: Integer;
begin
  Result := '';
  for i := low(v) to high(v) do
      Result := Result + if_(i <> low(v), ',', '') + PFormat('%g,%g', [v[i, 0], v[i, 1]]);
end;

function VecToStr(const v: TVec3): SystemString;
begin
  Result := PFormat('%g,%g,%g', [v[0], v[1], v[2]]);
end;

function VecToStr(const v: TVec4): SystemString;
begin
  Result := PFormat('%g,%g,%g,%g', [v[0], v[1], v[2], v[3]]);
end;

function VecToStr(const v: TVector3): SystemString;
begin
  Result := VecToStr(v.Buff);
end;

function VecToStr(const v: TVector4): SystemString;
begin
  Result := VecToStr(v.Buff);
end;

function VecToStr(const v: TV2R4): SystemString;
begin
  Result := PFormat('%s,%s,%s,%s', [VecToStr(v.LeftTop), VecToStr(v.RightTop), VecToStr(v.RightBottom), VecToStr(v.LeftBottom)]);
end;

function RectToStr(const v: TRectV2): SystemString;
begin
  Result := PFormat('%g,%g,%g,%g', [v[0][0], v[0][1], v[1][0], v[1][1]]);
end;

function RectToStr(const v: TRect): SystemString;
begin
  Result := PFormat('%d,%d,%d,%d', [v.Left, v.Top, v.Right, v.Bottom]);
end;

function StrToVec2(const s: SystemString): TVec2;
var
  v, v1, v2: U_String;
begin
  v := umlTrimSpace(s);
  v1 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v2 := umlGetFirstStr(v, ',: ');

  Result[0] := EStrToFloat(v1, 0);
  Result[1] := EStrToFloat(v2, 0);
end;

function StrToVector2(const s: SystemString): TVector2;
var
  v, v1, v2: U_String;
begin
  v := umlTrimSpace(s);
  v1 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v2 := umlGetFirstStr(v, ',: ');

  Result[0] := EStrToFloat(v1, 0);
  Result[1] := EStrToFloat(v2, 0);
end;

function StrToArrayVec2(const s: SystemString): TArrayVec2;
var
  n, v1, v2: U_String;
  L: TV2L;
begin
  L := TV2L.Create;
  n := umlTrimSpace(s);
  while n.L > 0 do
    begin
      v1 := umlGetFirstStr(n, ',: ');
      n := umlDeleteFirstStr(n, ',: ');
      v2 := umlGetFirstStr(n, ',: ');
      n := umlDeleteFirstStr(n, ',: ');
      L.Add(EStrToFloat(v1, 0), EStrToFloat(v2, 0));
    end;
  Result := L.BuildArray();
  DisposeObject(L);
end;

function StrToVec3(const s: SystemString): TVec3;
var
  v, v1, v2, v3: U_String;
begin
  v := umlTrimSpace(s);
  v1 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v2 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v3 := umlGetFirstStr(v, ',: ');

  Result[0] := EStrToFloat(v1, 0);
  Result[1] := EStrToFloat(v2, 0);
  Result[2] := EStrToFloat(v3, 0);
end;

function StrToVec4(const s: SystemString): TVec4;
var
  v, v1, v2, v3, v4: U_String;
begin
  v := umlTrimSpace(s);
  v1 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v2 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v3 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v4 := umlGetFirstStr(v, ',: ');

  Result[0] := EStrToFloat(v1, 0);
  Result[1] := EStrToFloat(v2, 0);
  Result[2] := EStrToFloat(v3, 0);
  Result[3] := EStrToFloat(v4, 0);
end;

function StrToVector3(const s: SystemString): TVector3;
var
  v, v1, v2, v3: U_String;
begin
  v := umlTrimSpace(s);
  v1 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v2 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v3 := umlGetFirstStr(v, ',: ');

  Result.Buff[0] := EStrToFloat(v1, 0);
  Result.Buff[1] := EStrToFloat(v2, 0);
  Result.Buff[2] := EStrToFloat(v3, 0);
end;

function StrToVector4(const s: SystemString): TVector4;
var
  v, v1, v2, v3, v4: U_String;
begin
  v := umlTrimSpace(s);
  v1 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v2 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v3 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v4 := umlGetFirstStr(v, ',: ');

  Result.Buff[0] := EStrToFloat(v1, 0);
  Result.Buff[1] := EStrToFloat(v2, 0);
  Result.Buff[2] := EStrToFloat(v3, 0);
  Result.Buff[3] := EStrToFloat(v4, 0);
end;

function StrToV2R4(const s: SystemString): TV2R4;
var
  v: TExpressionValueVector;
begin
  v := EvaluateExpressionVector(umlTrimSpace(s));

  if length(v) <> 8 then
      raiseInfo('V2R4 expression error: %s', [s]);

  Result.LeftTop[0] := v[0];
  Result.LeftTop[1] := v[1];
  Result.RightTop[0] := v[2];
  Result.RightTop[1] := v[3];
  Result.RightBottom[0] := v[4];
  Result.RightBottom[1] := v[5];
  Result.LeftBottom[0] := v[6];
  Result.LeftBottom[1] := v[7];
end;

function StrToRect(const s: SystemString): TRect;
begin
  Result := Rect2Rect(StrToRectV2(s));
end;

function StrToRectV2(const s: SystemString): TRectV2;
var
  v, v1, v2, v3, v4: U_String;
begin
  v := umlTrimSpace(s);
  v1 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v2 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v3 := umlGetFirstStr(v, ',: ');
  v := umlDeleteFirstStr(v, ',: ');
  v4 := umlGetFirstStr(v, ',: ');

  Result[0][0] := EStrToFloat(v1, 0);
  Result[0][1] := EStrToFloat(v2, 0);
  Result[1][0] := EStrToFloat(v3, 0);
  Result[1][1] := EStrToFloat(v4, 0);
end;

function GetMin(const arry: array of TGeoFloat): TGeoFloat;
var
  i: Integer;
begin
  Result := arry[low(arry)];
  for i := low(arry) + 1 to high(arry) do
    if Result > arry[i] then
        Result := arry[i];
end;

function GetMin(const arry: array of Integer): Integer;
var
  i: Integer;
begin
  Result := arry[low(arry)];
  for i := low(arry) + 1 to high(arry) do
    if Result > arry[i] then
        Result := arry[i];
end;

function GetMax(const arry: array of TGeoFloat): TGeoFloat;
var
  i: Integer;
begin
  Result := arry[low(arry)];
  for i := low(arry) + 1 to high(arry) do
    if Result < arry[i] then
        Result := arry[i];
end;

function GetMax(const arry: array of Integer): Integer;
var
  i: Integer;
begin
  Result := arry[low(arry)];
  for i := low(arry) + 1 to high(arry) do
    if Result < arry[i] then
        Result := arry[i];
end;

function FinalAngle4FMX(const a: TGeoFloat): TGeoFloat;
begin
  Result := NormalizeDegAngle((-a - 90) + 180);
end;

function CalcAngle(const v1, v2: TVec2): TGeoFloat;
begin
  if IsEqual(v1, v2) then
      Result := 0
  else
      Result := RadToDeg_(ArcTan2_(v1[0] - v2[0], v1[1] - v2[1]));
end;

function AngleDistance(const sour, dest: TGeoFloat): TGeoFloat;
begin
  Result := Abs(sour - dest);
  if Result > 180.0 then
      Result := 360.0 - Result;
end;

function SmoothAngle(const sour, dest, Delta: TGeoFloat): TGeoFloat;
var
  a1, a2: TGeoFloat;
begin
  if sour <> dest then
    begin
      if sour >= 0 then
        begin
          a1 := sour + Delta;
          a2 := sour - Delta;
        end
      else
        begin
          a1 := sour + -Delta;
          a2 := sour + Delta;
        end;

      if AngleDistance(dest, a1) >= AngleDistance(dest, a2) then
        begin
          if AngleDistance(dest, a2) > Delta then
              Result := a2
          else
              Result := dest;
        end
      else if AngleDistance(dest, a1) > Delta then
          Result := a1
      else
          Result := dest;
    end
  else
      Result := dest;
end;

function AngleEqual(const a1, a2: TGeoFloat): Boolean;
begin
  Result := AngleDistance(a1, a2) < 0.01;
end;

function Distance(const v1, v2: TVec2): TGeoFloat;
begin
  Result := PointDistance(v1, v2);
end;

function Distance(const v1, v2: TRectV2): TGeoFloat;
var
  d1, d2: TGeoFloat;
begin
  d1 := PointDistance(v1[0], v2[0]);
  d2 := PointDistance(v1[1], v2[1]);
  if d1 >= d2 then
      Result := d1
  else
      Result := d2;
end;

function MovementLerp(const s, d, Lerp: TGeoFloat): TGeoFloat;
begin
  if Lerp < 1.0 then
      Result := s + Lerp * (d - s)
  else
      Result := d;
end;

function MovementLerp(const s, d: TVec2; Lerp: TGeoFloat): TVec2;
begin
  if Lerp < 1.0 then
    begin
      Result[0] := s[0] + Lerp * (d[0] - s[0]);
      Result[1] := s[1] + Lerp * (d[1] - s[1]);
    end
  else
      Result := d;
end;

function MovementLerp(const s, d: TRectV2; Lerp: TGeoFloat): TRectV2;
begin
  if Lerp < 1.0 then
    begin
      Result[0] := MovementLerp(s[0], d[0], Lerp);
      Result[1] := MovementLerp(s[1], d[1], Lerp);
    end
  else
      Result := d;
end;

function MovementDistance(const s, d: TVec2; dt: TGeoFloat): TVec2;
var
  k: Double;
begin
  k := dt / Sqrt((d[0] - s[0]) * (d[0] - s[0]) + (d[1] - s[1]) * (d[1] - s[1]));
  Result[0] := s[0] + k * (d[0] - s[0]);
  Result[1] := s[1] + k * (d[1] - s[1]);
end;

function MovementDistance(const s, d: TRectV2; dt: TGeoFloat): TRectV2;
begin
  if Distance(s[0], d[0]) > dt then
      Result[0] := MovementDistance(s[0], d[0], dt)
  else
      Result[0] := d[0];

  if Distance(s[1], d[1]) > dt then
      Result[1] := MovementDistance(s[1], d[1], dt)
  else
      Result[1] := d[1];
end;

function MovementDistance(const sour, dest: TVector4; Distance: TGeoFloat): TVector4;
var
  k: TGeoFloat;
begin
  // calc distance
  k := Distance / Sqrt((dest[0] - sour[0]) * (dest[0] - sour[0]) + (dest[1] - sour[1]) * (dest[1] - sour[1]) + (dest[2] - sour[2]) * (dest[2] - sour[2]) + (dest[3] - sour[3]) *
      (dest[3] - sour[3]));
  // done
  Result[0] := sour[0] + k * (dest[0] - sour[0]);
  Result[1] := sour[1] + k * (dest[1] - sour[1]);
  Result[2] := sour[2] + k * (dest[2] - sour[2]);
  Result[3] := sour[3] + k * (dest[3] - sour[3]);
end;

function MovementDistance(const sour, dest: TVector3; Distance: TGeoFloat): TVector3;
var
  k: TGeoFloat;
begin
  // calc distance
  k := Distance / Sqrt((dest[0] - sour[0]) * (dest[0] - sour[0]) + (dest[1] - sour[1]) * (dest[1] - sour[1]) + (dest[2] - sour[2]) * (dest[2] - sour[2]));
  // done
  Result[0] := sour[0] + k * (dest[0] - sour[0]);
  Result[1] := sour[1] + k * (dest[1] - sour[1]);
  Result[2] := sour[2] + k * (dest[2] - sour[2]);
end;

function MovementDistanceDeltaTime(const s, d: TVec2; Speed_: TGeoFloat): Double;
begin
  Result := Distance(s, d) / Speed_;
end;

function MovementDistanceDeltaTime(const s, d: TRectV2; Speed_: TGeoFloat): Double;
var
  d1, d2: Double;
begin
  d1 := MovementDistanceDeltaTime(s[0], d[0], Speed_);
  d2 := MovementDistanceDeltaTime(s[1], d[1], Speed_);
  if d1 > d2 then
      Result := d1
  else
      Result := d2;
end;

function AngleRollDistanceDeltaTime(const s, d: TGeoFloat; RollSpeed_: TGeoFloat): Double;
begin
  Result := AngleDistance(s, d) / RollSpeed_;
end;

function BounceVector(const Current: TVector4; Step_Dist: TGeoFloat; const bVec, eVec: TVector4; var eFlag: Boolean): TVector4;
  function ToVector: TVector4;
  begin
    if eFlag then
        Result := eVec
    else
        Result := bVec;
  end;

var
  k: TGeoFloat;
begin
  k := Current.Distance4D(ToVector);
  if k >= Step_Dist then
      Result := MovementDistance(Current, ToVector, Step_Dist)
  else
    begin
      Result := ToVector;
      eFlag := not eFlag;
      Result := MovementDistance(Result, ToVector, Step_Dist - k);
    end;
end;

function BounceVector(const Current: TVector3; Step_Dist: TGeoFloat; const bVec, eVec: TVector3; var eFlag: Boolean): TVector3;
  function ToVector: TVector3;
  begin
    if eFlag then
        Result := eVec
    else
        Result := bVec;
  end;

var
  k: TGeoFloat;
begin
  k := Current.Distance3D(ToVector);
  if k >= Step_Dist then
      Result := MovementDistance(Current, ToVector, Step_Dist)
  else
    begin
      Result := ToVector;
      eFlag := not eFlag;
      Result := MovementDistance(Result, ToVector, Step_Dist - k);
    end;
end;

function BounceVector(const Current: TVector2; Step_Dist: TGeoFloat; const bVec, eVec: TVector2; var eFlag: Boolean): TVector2;
  function ToVector: TVector2;
  begin
    if eFlag then
        Result := eVec
    else
        Result := bVec;
  end;

var
  k: TGeoFloat;
begin
  k := Vec2Distance(Current.Buff, ToVector.Buff);
  if k >= Step_Dist then
      Result := Vec2LerpTo(Current.Buff, ToVector.Buff, Step_Dist)
  else
    begin
      Result := ToVector;
      eFlag := not eFlag;
      Result := Vec2LerpTo(Result.Buff, ToVector.Buff, Step_Dist - k);
    end;
end;

function BounceFloat(const CurrentVal, Step_Dist, bFloat, eFloat: TGeoFloat; var eFlag: Boolean): TGeoFloat;
  function IfOut(Cur, Delta, dest: TGeoFloat): Boolean;
  begin
    if Cur > dest then
        Result := Cur - Delta < dest
    else
        Result := Cur + Delta > dest;
  end;

  function GetOutValue(Cur, Delta, dest: TGeoFloat): TGeoFloat;
  begin
    if IfOut(Cur, Delta, dest) then
      begin
        if Cur > dest then
            Result := dest - (Cur - Delta)
        else
            Result := Cur + Delta - dest;
      end
    else
        Result := 0;
  end;

  function GetDeltaValue(Cur, Delta, dest: TGeoFloat): TGeoFloat;
  begin
    if Cur > dest then
        Result := Cur - Delta
    else
        Result := Cur + Delta;
  end;

begin
  if (Step_Dist > 0) and (bFloat <> eFloat) then
    begin
      if eFlag then
        begin
          if IfOut(CurrentVal, Step_Dist, eFloat) then
            begin
              eFlag := False;
              Result := umlProcessCycleValue(eFloat, GetOutValue(CurrentVal, Step_Dist, eFloat), bFloat, eFloat, eFlag);
            end
          else
              Result := GetDeltaValue(CurrentVal, Step_Dist, eFloat);
        end
      else
        begin
          if IfOut(CurrentVal, Step_Dist, bFloat) then
            begin
              eFlag := True;
              Result := umlProcessCycleValue(bFloat, GetOutValue(CurrentVal, Step_Dist, bFloat), bFloat, eFloat, eFlag);
            end
          else
              Result := GetDeltaValue(CurrentVal, Step_Dist, bFloat);
        end
    end
  else
      Result := CurrentVal;
end;

class operator TMatrix4.Equal(const Lhs, Rhs: TMatrix4): Boolean;
begin
  Result := VectorEquals(Lhs.Buff[0], Rhs.Buff[0]) and VectorEquals(Lhs.Buff[1], Rhs.Buff[1]) and VectorEquals(Lhs.Buff[2], Rhs.Buff[2]) and VectorEquals(Lhs.Buff[3], Rhs.Buff[3]);
end;

class operator TMatrix4.NotEqual(const Lhs, Rhs: TMatrix4): Boolean;
begin
  Result := not(Lhs = Rhs);
end;

class operator TMatrix4.Multiply(const Lhs, Rhs: TMatrix4): TMatrix4;
begin
  Result.Buff := Z.Geometry.Low.MatrixMultiply(Lhs.Buff, Rhs.Buff);
end;

class operator TMatrix4.Implicit(Value: TGeoFloat): TMatrix4;
var
  i, j: Integer;
begin
  for i := 0 to 3 do
    for j := 0 to 3 do
        Result.Buff[i, j] := Value;
end;

class operator TMatrix4.Implicit(Value: TMat4): TMatrix4;
begin
  Result.Buff := Value;
end;

function TMatrix4.Swap: TMatrix4;
var
  i, j: Integer;
begin
  for i := 0 to 3 do
    for j := 0 to 3 do
        Result.Buff[j, i] := Buff[i, j];
end;

function TMatrix4.Lerp(M: TMatrix4; Delta: TGeoFloat): TMatrix4;
var
  i, j: Integer;
begin
  for j := 0 to 3 do
    for i := 0 to 3 do
        Result.Buff[i][j] := Buff[i][j] + (M.Buff[i][j] - Buff[i][j]) * Delta;
end;

function TMatrix4.AffineMatrix: TAffineMatrix;
begin
  Result[0, 0] := Buff[0, 0];
  Result[0, 1] := Buff[0, 1];
  Result[0, 2] := Buff[0, 2];
  Result[1, 0] := Buff[1, 0];
  Result[1, 1] := Buff[1, 1];
  Result[1, 2] := Buff[1, 2];
  Result[2, 0] := Buff[2, 0];
  Result[2, 1] := Buff[2, 1];
  Result[2, 2] := Buff[2, 2];
end;

function TMatrix4.Invert: TMatrix4;
var
  det: TGeoFloat;
begin
  Result.Buff := Buff;
  det := Z.Geometry.Low.MatrixDeterminant(Result.Buff);
  if Abs(det) < Epsilon then
      Result.Buff := Z.Geometry.Low.IdentityHmgMatrix
  else
    begin
      Z.Geometry.Low.AdjointMatrix(Result.Buff);
      Z.Geometry.Low.ScaleMatrix(Result.Buff, 1 / det);
    end;
end;

function TMatrix4.Translate(v: TVec3): TMatrix4;
begin
  Result.Buff := Buff;
  Z.Geometry.Low.TranslateMatrix(Result.Buff, v);
end;

function TMatrix4.Normalize: TMatrix4;
begin
  Result.Buff := Buff;
  Z.Geometry.Low.NormalizeMatrix(Result.Buff);
end;

function TMatrix4.Transpose: TMatrix4;
begin
  Result.Buff := Buff;
  Z.Geometry.Low.TransposeMatrix(Result.Buff);
end;

function TMatrix4.AnglePreservingInvert: TMatrix4;
begin
  Result.Buff := Z.Geometry.Low.AnglePreservingMatrixInvert(Buff);
end;

function TMatrix4.Determinant: TGeoFloat;
begin
  Result := Z.Geometry.Low.MatrixDeterminant(Buff);
end;

function TMatrix4.Adjoint: TMatrix4;
begin
  Result.Buff := Buff;
  Z.Geometry.Low.AdjointMatrix(Result.Buff);
end;

function TMatrix4.Pitch(angle: TGeoFloat): TMatrix4;
begin
  Result.Buff := Z.Geometry.Low.Pitch(Buff, angle);
end;

function TMatrix4.Roll(angle: TGeoFloat): TMatrix4;
begin
  Result.Buff := Z.Geometry.Low.Roll(Buff, angle);
end;

function TMatrix4.Turn(angle: TGeoFloat): TMatrix4;
begin
  Result.Buff := Z.Geometry.Low.Turn(Buff, angle);
end;

function TVector4.GetVec3: TVec3;
begin
  Result := AffineVectorMake(Buff);
end;

procedure TVector4.SetVec3(const Value: TVec3);
begin
  Buff := VectorMake(Value);
end;

function TVector4.GetVec2: TVec2;
begin
  Result[0] := Buff[0];
  Result[1] := Buff[1];
end;

procedure TVector4.SetVec2(const Value: TVec2);
begin
  Buff[0] := Value[0];
  Buff[1] := Value[1];
end;

function TVector4.GetLinkValue(index: Integer): TGeoFloat;
begin
  Result := Buff[index];
end;

procedure TVector4.SetLinkValue(index: Integer; const Value: TGeoFloat);
begin
  Buff[index] := Value;
end;

class operator TVector4.Equal(const Lhs, Rhs: TVector4): Boolean;
begin
  Result := (Lhs.Buff[0] = Rhs.Buff[0]) and (Lhs.Buff[1] = Rhs.Buff[1]) and (Lhs.Buff[2] = Rhs.Buff[2]) and (Lhs.Buff[3] = Rhs.Buff[3]);
end;

class operator TVector4.NotEqual(const Lhs, Rhs: TVector4): Boolean;
begin
  Result := (Lhs.Buff[0] <> Rhs.Buff[0]) or (Lhs.Buff[1] <> Rhs.Buff[1]) or (Lhs.Buff[2] <> Rhs.Buff[2]) or (Lhs.Buff[3] <> Rhs.Buff[3]);
end;

class operator TVector4.GreaterThan(const Lhs, Rhs: TVector4): Boolean;
begin
  Result := (Lhs.Buff[0] > Rhs.Buff[0]) and (Lhs.Buff[1] > Rhs.Buff[1]) and (Lhs.Buff[2] > Rhs.Buff[2]) and (Lhs.Buff[3] > Rhs.Buff[3]);
end;

class operator TVector4.GreaterThanOrEqual(const Lhs, Rhs: TVector4): Boolean;
begin
  Result := (Lhs.Buff[0] >= Rhs.Buff[0]) and (Lhs.Buff[1] >= Rhs.Buff[1]) and (Lhs.Buff[2] >= Rhs.Buff[2]) and (Lhs.Buff[3] >= Rhs.Buff[3]);
end;

class operator TVector4.LessThan(const Lhs, Rhs: TVector4): Boolean;
begin
  Result := (Lhs.Buff[0] < Rhs.Buff[0]) and (Lhs.Buff[1] < Rhs.Buff[1]) and (Lhs.Buff[2] < Rhs.Buff[2]) and (Lhs.Buff[3] < Rhs.Buff[3]);
end;

class operator TVector4.LessThanOrEqual(const Lhs, Rhs: TVector4): Boolean;
begin
  Result := (Lhs.Buff[0] <= Rhs.Buff[0]) and (Lhs.Buff[1] <= Rhs.Buff[1]) and (Lhs.Buff[2] <= Rhs.Buff[2]) and (Lhs.Buff[3] <= Rhs.Buff[3]);
end;

class operator TVector4.Add(const Lhs, Rhs: TVector4): TVector4;
begin
  Result.Buff[0] := Lhs.Buff[0] + Rhs.Buff[0];
  Result.Buff[1] := Lhs.Buff[1] + Rhs.Buff[1];
  Result.Buff[2] := Lhs.Buff[2] + Rhs.Buff[2];
  Result.Buff[3] := Lhs.Buff[3] + Rhs.Buff[3];
end;

class operator TVector4.Add(const Lhs: TVector4; const Rhs: TGeoFloat): TVector4;
begin
  Result.Buff[0] := Lhs.Buff[0] + Rhs;
  Result.Buff[1] := Lhs.Buff[1] + Rhs;
  Result.Buff[2] := Lhs.Buff[2] + Rhs;
  Result.Buff[3] := Lhs.Buff[3] + Rhs;
end;

class operator TVector4.Add(const Lhs: TGeoFloat; const Rhs: TVector4): TVector4;
begin
  Result.Buff[0] := Lhs + Rhs.Buff[0];
  Result.Buff[1] := Lhs + Rhs.Buff[1];
  Result.Buff[2] := Lhs + Rhs.Buff[2];
  Result.Buff[3] := Lhs + Rhs.Buff[3];
end;

class operator TVector4.Subtract(const Lhs, Rhs: TVector4): TVector4;
begin
  Result.Buff[0] := Lhs.Buff[0] - Rhs.Buff[0];
  Result.Buff[1] := Lhs.Buff[1] - Rhs.Buff[1];
  Result.Buff[2] := Lhs.Buff[2] - Rhs.Buff[2];
  Result.Buff[3] := Lhs.Buff[3] - Rhs.Buff[3];
end;

class operator TVector4.Subtract(const Lhs: TVector4; const Rhs: TGeoFloat): TVector4;
begin
  Result.Buff[0] := Lhs.Buff[0] - Rhs;
  Result.Buff[1] := Lhs.Buff[1] - Rhs;
  Result.Buff[2] := Lhs.Buff[2] - Rhs;
  Result.Buff[3] := Lhs.Buff[3] - Rhs;
end;

class operator TVector4.Subtract(const Lhs: TGeoFloat; const Rhs: TVector4): TVector4;
begin
  Result.Buff[0] := Lhs - Rhs.Buff[0];
  Result.Buff[1] := Lhs - Rhs.Buff[1];
  Result.Buff[2] := Lhs - Rhs.Buff[2];
  Result.Buff[3] := Lhs - Rhs.Buff[3];
end;

class operator TVector4.Multiply(const Lhs, Rhs: TVector4): TVector4;
begin
  Result.Buff[0] := Lhs.Buff[0] * Rhs.Buff[0];
  Result.Buff[1] := Lhs.Buff[1] * Rhs.Buff[1];
  Result.Buff[2] := Lhs.Buff[2] * Rhs.Buff[2];
  Result.Buff[3] := Lhs.Buff[2] * Rhs.Buff[3];
end;

class operator TVector4.Multiply(const Lhs: TVector4; const Rhs: TGeoFloat): TVector4;
begin
  Result.Buff[0] := Lhs.Buff[0] * Rhs;
  Result.Buff[1] := Lhs.Buff[1] * Rhs;
  Result.Buff[2] := Lhs.Buff[2] * Rhs;
  Result.Buff[3] := Lhs.Buff[3] * Rhs;
end;

class operator TVector4.Multiply(const Lhs: TGeoFloat; const Rhs: TVector4): TVector4;
begin
  Result.Buff[0] := Lhs * Rhs.Buff[0];
  Result.Buff[1] := Lhs * Rhs.Buff[1];
  Result.Buff[2] := Lhs * Rhs.Buff[2];
  Result.Buff[3] := Lhs * Rhs.Buff[3];
end;

class operator TVector4.Multiply(const Lhs: TVector4; const Rhs: TMatrix4): TVector4;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Lhs.Buff, Rhs.Buff);
end;

class operator TVector4.Multiply(const Lhs: TMatrix4; const Rhs: TVector4): TVector4;
begin
  Result.Buff := VectorTransform(Rhs.Buff, Lhs.Buff);
end;

class operator TVector4.Multiply(const Lhs: TVector4; const Rhs: TMat4): TVector4;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Lhs.Buff, Rhs);
end;

class operator TVector4.Multiply(const Lhs: TMat4; const Rhs: TVector4): TVector4;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Rhs.Buff, Lhs);
end;

class operator TVector4.Multiply(const Lhs: TVector4; const Rhs: TAffineMatrix): TVector4;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Lhs.Buff, Rhs);
end;

class operator TVector4.Multiply(const Lhs: TAffineMatrix; const Rhs: TVector4): TVector4;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Rhs.Buff, Lhs);
end;

class operator TVector4.Divide(const Lhs, Rhs: TVector4): TVector4;
begin
  Result.Buff[0] := Lhs.Buff[0] / Rhs.Buff[0];
  Result.Buff[1] := Lhs.Buff[1] / Rhs.Buff[1];
  Result.Buff[2] := Lhs.Buff[2] / Rhs.Buff[2];
  Result.Buff[3] := Lhs.Buff[3] / Rhs.Buff[3];
end;

class operator TVector4.Divide(const Lhs: TVector4; const Rhs: TGeoFloat): TVector4;
begin
  Result.Buff[0] := Lhs.Buff[0] / Rhs;
  Result.Buff[1] := Lhs.Buff[1] / Rhs;
  Result.Buff[2] := Lhs.Buff[2] / Rhs;
  Result.Buff[3] := Lhs.Buff[3] / Rhs;
end;

class operator TVector4.Divide(const Lhs: TGeoFloat; const Rhs: TVector4): TVector4;
begin
  Result.Buff[0] := Lhs / Rhs.Buff[0];
  Result.Buff[1] := Lhs / Rhs.Buff[1];
  Result.Buff[2] := Lhs / Rhs.Buff[2];
  Result.Buff[3] := Lhs / Rhs.Buff[3];
end;

class operator TVector4.Implicit(Value: TGeoFloat): TVector4;
begin
  Result.Buff[0] := Value;
  Result.Buff[1] := Value;
  Result.Buff[2] := Value;
  Result.Buff[3] := Value;
end;

class operator TVector4.Implicit(Value: TVec4): TVector4;
begin
  Result.Buff := Value;
end;

class operator TVector4.Implicit(Value: TVec3): TVector4;
begin
  Result.Buff := VectorMake(Value);
end;

class operator TVector4.Implicit(Value: TVec2): TVector4;
begin
  Result.Buff := VectorMake(Value[0], Value[1], 0, 0);
end;

class operator TVector4.Explicit(Value: TVector4): TVec4;
begin
  Result := Value.Buff;
end;

class operator TVector4.Explicit(Value: TVector4): TVec3;
begin
  Result := AffineVectorMake(Value.Buff);
end;

class operator TVector4.Explicit(Value: TVector4): TVec2;
begin
  Result[0] := Value.Buff[0];
  Result[1] := Value.Buff[1];
end;

procedure TVector4.SetRGBA(const r, g, b, a: TGeoFloat);
begin
  Buff[0] := r;
  Buff[1] := g;
  Buff[2] := b;
  Buff[3] := a;
end;

procedure TVector4.SetLocation(const fx, fy, fz, fw: TGeoFloat);
begin
  Buff[0] := fx;
  Buff[1] := fy;
  Buff[2] := fz;
  Buff[3] := fw;
end;

procedure TVector4.SetLocation(const fx, fy, fz: TGeoFloat);
begin
  Buff[0] := fx;
  Buff[1] := fy;
  Buff[2] := fz;
end;

function TVector4.Distance4D(const v2: TVector4): TGeoFloat;
begin
  Result := Sqrt(Sqr(v2.Buff[0] - Buff[0]) + Sqr(v2.Buff[1] - Buff[1]) + Sqr(v2.Buff[2] - Buff[2]) + Sqr(v2.Buff[3] - Buff[3]));
end;

function TVector4.Distance3D(const v2: TVector4): TGeoFloat;
begin
  Result := Sqrt(Sqr(v2.Buff[0] - Buff[0]) + Sqr(v2.Buff[1] - Buff[1]) + Sqr(v2.Buff[2] - Buff[2]));
end;

function TVector4.Distance2D(const v2: TVector4): TGeoFloat;
begin
  Result := Sqrt(Sqr(v2.Buff[0] - Buff[0]) + Sqr(v2.Buff[1] - Buff[1]));
end;

function TVector4.Lerp(const v2: TVector4; const t: TGeoFloat): TVector4;
begin
  Result.Buff[0] := Buff[0] + (v2.Buff[0] - Buff[0]) * t;
  Result.Buff[1] := Buff[1] + (v2.Buff[1] - Buff[1]) * t;
  Result.Buff[2] := Buff[2] + (v2.Buff[2] - Buff[2]) * t;
  Result.Buff[3] := Buff[3] + (v2.Buff[3] - Buff[3]) * t;
end;

function TVector4.LerpDistance(const v2: TVector4; const d: TGeoFloat): TVector4;
var
  k: Double;
begin
  k := d / Sqrt((v2.Buff[0] - Buff[0]) * (v2.Buff[0] - Buff[0]) + (v2.Buff[1] - Buff[1]) * (v2.Buff[1] - Buff[1]) + (v2.Buff[2] - Buff[2]) * (v2.Buff[2] - Buff[2]) +
      (v2.Buff[3] - Buff[3]) * (v2.Buff[3] - Buff[3]));
  Result.Buff[0] := Buff[0] + k * (v2.Buff[0] - Buff[0]);
  Result.Buff[1] := Buff[1] + k * (v2.Buff[1] - Buff[1]);
  Result.Buff[2] := Buff[2] + k * (v2.Buff[2] - Buff[2]);
  Result.Buff[3] := Buff[3] + k * (v2.Buff[3] - Buff[3]);
end;

function TVector4.Norm: TGeoFloat;
begin
  Result := Buff[0] * Buff[0] + Buff[1] * Buff[1] + Buff[2] * Buff[2] + Buff[3] * Buff[3];
end;

function TVector4.length: TGeoFloat;
begin
  Result := Sqrt(Norm);
end;

function TVector4.Normalize: TVector4;
var
  InvLen: TGeoFloat;
  vn: TGeoFloat;
begin
  vn := Norm;
  if vn = 0 then
      Result := Self
  else
    begin
      InvLen := RSqrt(vn);
      Result.Buff[0] := Buff[0] * InvLen;
      Result.Buff[1] := Buff[1] * InvLen;
      Result.Buff[2] := Buff[2] * InvLen;
      Result.Buff[3] := Buff[3] * InvLen;
    end;
end;

function TVector4.Cross(const v2: TVector4): TVector4;
begin
  Result.Buff[0] := Buff[1] * v2.Buff[2] - Buff[2] * v2.Buff[1];
  Result.Buff[1] := Buff[2] * v2.Buff[0] - Buff[0] * v2.Buff[2];
  Result.Buff[2] := Buff[0] * v2.Buff[1] - Buff[1] * v2.Buff[0];
  Result.Buff[3] := 0;
end;

function TVector4.Cross(const v2: TVec3): TVector4;
begin
  Result.Buff[0] := Buff[1] * v2[2] - Buff[2] * v2[1];
  Result.Buff[1] := Buff[2] * v2[0] - Buff[0] * v2[2];
  Result.Buff[2] := Buff[0] * v2[1] - Buff[1] * v2[0];
  Result.Buff[3] := 0;
end;

function TVector4.Cross(const v2: TVec4): TVector4;
begin
  Result.Buff[0] := Buff[1] * v2[2] - Buff[2] * v2[1];
  Result.Buff[1] := Buff[2] * v2[0] - Buff[0] * v2[2];
  Result.Buff[2] := Buff[0] * v2[1] - Buff[1] * v2[0];
  Result.Buff[3] := 0;
end;

function TVector3.GetVec2: TVec2;
begin
  Result[0] := Buff[0];
  Result[1] := Buff[1];
end;

procedure TVector3.SetVec2(const Value: TVec2);
begin
  Buff[0] := Value[0];
  Buff[1] := Value[1];
end;

function TVector3.GetLinkValue(index: Integer): TGeoFloat;
begin
  Result := Buff[index];
end;

procedure TVector3.SetLinkValue(index: Integer; const Value: TGeoFloat);
begin
  Buff[index] := Value;
end;

class operator TVector3.Equal(const Lhs, Rhs: TVector3): Boolean;
begin
  Result := (Lhs.Buff[0] = Rhs.Buff[0]) and (Lhs.Buff[1] = Rhs.Buff[1]) and (Lhs.Buff[2] = Rhs.Buff[2]);
end;

class operator TVector3.NotEqual(const Lhs, Rhs: TVector3): Boolean;
begin
  Result := (Lhs.Buff[0] <> Rhs.Buff[0]) or (Lhs.Buff[1] <> Rhs.Buff[1]) or (Lhs.Buff[2] <> Rhs.Buff[2]);
end;

class operator TVector3.GreaterThan(const Lhs, Rhs: TVector3): Boolean;
begin
  Result := (Lhs.Buff[0] > Rhs.Buff[0]) and (Lhs.Buff[1] > Rhs.Buff[1]) and (Lhs.Buff[2] > Rhs.Buff[2]);
end;

class operator TVector3.GreaterThanOrEqual(const Lhs, Rhs: TVector3): Boolean;
begin
  Result := (Lhs.Buff[0] >= Rhs.Buff[0]) and (Lhs.Buff[1] >= Rhs.Buff[1]) and (Lhs.Buff[2] >= Rhs.Buff[2]);
end;

class operator TVector3.LessThan(const Lhs, Rhs: TVector3): Boolean;
begin
  Result := (Lhs.Buff[0] < Rhs.Buff[0]) and (Lhs.Buff[1] < Rhs.Buff[1]) and (Lhs.Buff[2] < Rhs.Buff[2]);
end;

class operator TVector3.LessThanOrEqual(const Lhs, Rhs: TVector3): Boolean;
begin
  Result := (Lhs.Buff[0] <= Rhs.Buff[0]) and (Lhs.Buff[1] <= Rhs.Buff[1]) and (Lhs.Buff[2] <= Rhs.Buff[2]);
end;

class operator TVector3.Add(const Lhs, Rhs: TVector3): TVector3;
begin
  Result.Buff[0] := Lhs.Buff[0] + Rhs.Buff[0];
  Result.Buff[1] := Lhs.Buff[1] + Rhs.Buff[1];
  Result.Buff[2] := Lhs.Buff[2] + Rhs.Buff[2];
end;

class operator TVector3.Add(const Lhs: TVector3; const Rhs: TGeoFloat): TVector3;
begin
  Result.Buff[0] := Lhs.Buff[0] + Rhs;
  Result.Buff[1] := Lhs.Buff[1] + Rhs;
  Result.Buff[2] := Lhs.Buff[2] + Rhs;
end;

class operator TVector3.Add(const Lhs: TGeoFloat; const Rhs: TVector3): TVector3;
begin
  Result.Buff[0] := Lhs + Rhs.Buff[0];
  Result.Buff[1] := Lhs + Rhs.Buff[1];
  Result.Buff[2] := Lhs + Rhs.Buff[2];
end;

class operator TVector3.Subtract(const Lhs, Rhs: TVector3): TVector3;
begin
  Result.Buff[0] := Lhs.Buff[0] - Rhs.Buff[0];
  Result.Buff[1] := Lhs.Buff[1] - Rhs.Buff[1];
  Result.Buff[2] := Lhs.Buff[2] - Rhs.Buff[2];
end;

class operator TVector3.Subtract(const Lhs: TVector3; const Rhs: TGeoFloat): TVector3;
begin
  Result.Buff[0] := Lhs.Buff[0] - Rhs;
  Result.Buff[1] := Lhs.Buff[1] - Rhs;
  Result.Buff[2] := Lhs.Buff[2] - Rhs;
end;

class operator TVector3.Subtract(const Lhs: TGeoFloat; const Rhs: TVector3): TVector3;
begin
  Result.Buff[0] := Lhs - Rhs.Buff[0];
  Result.Buff[1] := Lhs - Rhs.Buff[1];
  Result.Buff[2] := Lhs - Rhs.Buff[2];
end;

class operator TVector3.Multiply(const Lhs, Rhs: TVector3): TVector3;
begin
  Result.Buff[0] := Lhs.Buff[0] * Rhs.Buff[0];
  Result.Buff[1] := Lhs.Buff[1] * Rhs.Buff[1];
  Result.Buff[2] := Lhs.Buff[2] * Rhs.Buff[2];
end;

class operator TVector3.Multiply(const Lhs: TVector3; const Rhs: TGeoFloat): TVector3;
begin
  Result.Buff[0] := Lhs.Buff[0] * Rhs;
  Result.Buff[1] := Lhs.Buff[1] * Rhs;
  Result.Buff[2] := Lhs.Buff[2] * Rhs;
end;

class operator TVector3.Multiply(const Lhs: TGeoFloat; const Rhs: TVector3): TVector3;
begin
  Result.Buff[0] := Lhs * Rhs.Buff[0];
  Result.Buff[1] := Lhs * Rhs.Buff[1];
  Result.Buff[2] := Lhs * Rhs.Buff[2];
end;

class operator TVector3.Multiply(const Lhs: TVector3; const Rhs: TMatrix4): TVector3;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Lhs.Buff, Rhs.Buff);
end;

class operator TVector3.Multiply(const Lhs: TMatrix4; const Rhs: TVector3): TVector3;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Rhs.Buff, Lhs.Buff);
end;

class operator TVector3.Multiply(const Lhs: TVector3; const Rhs: TMat4): TVector3;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Lhs.Buff, Rhs);
end;

class operator TVector3.Multiply(const Lhs: TMat4; const Rhs: TVector3): TVector3;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Rhs.Buff, Lhs);
end;

class operator TVector3.Multiply(const Lhs: TVector3; const Rhs: TAffineMatrix): TVector3;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Lhs.Buff, Rhs);
end;

class operator TVector3.Multiply(const Lhs: TAffineMatrix; const Rhs: TVector3): TVector3;
begin
  Result.Buff := Z.Geometry.Low.VectorTransform(Rhs.Buff, Lhs);
end;

class operator TVector3.Divide(const Lhs, Rhs: TVector3): TVector3;
begin
  Result.Buff[0] := Lhs.Buff[0] / Rhs.Buff[0];
  Result.Buff[1] := Lhs.Buff[1] / Rhs.Buff[1];
  Result.Buff[2] := Lhs.Buff[2] / Rhs.Buff[2];
end;

class operator TVector3.Divide(const Lhs: TVector3; const Rhs: TGeoFloat): TVector3;
begin
  Result.Buff[0] := Lhs.Buff[0] / Rhs;
  Result.Buff[1] := Lhs.Buff[1] / Rhs;
  Result.Buff[2] := Lhs.Buff[2] / Rhs;
end;

class operator TVector3.Divide(const Lhs: TGeoFloat; const Rhs: TVector3): TVector3;
begin
  Result.Buff[0] := Lhs / Rhs.Buff[0];
  Result.Buff[1] := Lhs / Rhs.Buff[1];
  Result.Buff[2] := Lhs / Rhs.Buff[2];
end;

class operator TVector3.Implicit(Value: TGeoFloat): TVector3;
begin
  Result.Buff[0] := Value;
  Result.Buff[1] := Value;
  Result.Buff[2] := Value;
end;

class operator TVector3.Implicit(Value: TVec4): TVector3;
begin
  Result.Buff := AffineVectorMake(Value);
end;

class operator TVector3.Implicit(Value: TVec3): TVector3;
begin
  Result.Buff := Value;
end;

class operator TVector3.Implicit(Value: TVec2): TVector3;
begin
  Result.Buff := AffineVectorMake(Value[0], Value[1], 0);
end;

class operator TVector3.Explicit(Value: TVector3): TVec4;
begin
  Result := VectorMake(Value.Buff);
end;

class operator TVector3.Explicit(Value: TVector3): TVec3;
begin
  Result := Value.Buff;
end;

class operator TVector3.Explicit(Value: TVector3): TVec2;
begin
  Result[0] := Value.Buff[0];
  Result[1] := Value.Buff[1];
end;

procedure TVector3.SetLocation(const fx, fy, fz: TGeoFloat);
begin
  Buff[0] := fx;
  Buff[1] := fy;
  Buff[2] := fz;
end;

function TVector3.Distance3D(const v2: TVector3): TGeoFloat;
begin
  Result := Sqrt(Sqr(v2.Buff[0] - Buff[0]) + Sqr(v2.Buff[1] - Buff[1]) + Sqr(v2.Buff[2] - Buff[2]));
end;

function TVector3.Distance2D(const v2: TVector3): TGeoFloat;
begin
  Result := Sqrt(Sqr(v2.Buff[0] - Buff[0]) + Sqr(v2.Buff[1] - Buff[1]));
end;

function TVector3.Lerp(const v2: TVector3; const t: TGeoFloat): TVector3;
begin
  Result.Buff[0] := Buff[0] + (v2.Buff[0] - Buff[0]) * t;
  Result.Buff[1] := Buff[1] + (v2.Buff[1] - Buff[1]) * t;
  Result.Buff[2] := Buff[2] + (v2.Buff[2] - Buff[2]) * t;
end;

function TVector3.LerpDistance(const v2: TVector3; const d: TGeoFloat): TVector3;
var
  k: Double;
begin
  k := d / Sqrt((v2.Buff[0] - Buff[0]) * (v2.Buff[0] - Buff[0]) + (v2.Buff[1] - Buff[1]) * (v2.Buff[1] - Buff[1]) + (v2.Buff[2] - Buff[2]) * (v2.Buff[2] - Buff[2]));
  Result.Buff[0] := Buff[0] + k * (v2.Buff[0] - Buff[0]);
  Result.Buff[1] := Buff[1] + k * (v2.Buff[1] - Buff[1]);
  Result.Buff[2] := Buff[2] + k * (v2.Buff[2] - Buff[2]);
end;

function TVector3.Norm: TGeoFloat;
begin
  Result := Buff[0] * Buff[0] + Buff[1] * Buff[1] + Buff[2] * Buff[2];
end;

function TVector3.length: TGeoFloat;
begin
  Result := Sqrt(Norm);
end;

function TVector3.Normalize: TVector3;
var
  InvLen: TGeoFloat;
  vn: TGeoFloat;
begin
  vn := Norm;
  if vn = 0 then
      Result := Self
  else
    begin
      InvLen := RSqrt(vn);
      Result.Buff[0] := Buff[0] * InvLen;
      Result.Buff[1] := Buff[1] * InvLen;
      Result.Buff[2] := Buff[2] * InvLen;
    end;
end;

function TVector3.Cross(const v2: TVector3): TVector3;
begin
  Result.Buff[0] := Buff[1] * v2.Buff[2] - Buff[2] * v2.Buff[1];
  Result.Buff[1] := Buff[2] * v2.Buff[0] - Buff[0] * v2.Buff[2];
  Result.Buff[2] := Buff[0] * v2.Buff[1] - Buff[1] * v2.Buff[0];
end;

function TVector3.Vec4(fw: TGeoFloat): TVector4;
begin
  Result.SetLocation(Buff[0], Buff[1], Buff[2], fw);
end;

function TVector3.Vec4: TVector4;
begin
  Result.SetLocation(Buff[0], Buff[1], Buff[2], 0);
end;

{ TAABB }

procedure TAABB.Include(const p: TVector3);
begin
  if p.Buff[0] < Min[0] then
      Min[0] := p.Buff[0];
  if p.Buff[0] > Max[0] then
      Max[0] := p.Buff[0];

  if p.Buff[1] < Min[1] then
      Min[1] := p.Buff[1];
  if p.Buff[1] > Max[1] then
      Max[1] := p.Buff[1];

  if p.Buff[2] < Min[2] then
      Min[2] := p.Buff[2];
  if p.Buff[2] > Max[2] then
      Max[2] := p.Buff[2];
end;

procedure TAABB.FromSweep(const Start, dest: TVector3; const radius: TGeoFloat);
begin
  if Start.Buff[0] < dest.Buff[0] then
    begin
      Min[0] := Start.Buff[0] - radius;
      Max[0] := dest.Buff[0] + radius;
    end
  else
    begin
      Min[0] := dest.Buff[0] - radius;
      Max[0] := Start.Buff[0] + radius;
    end;

  if Start.Buff[1] < dest.Buff[1] then
    begin
      Min[1] := Start.Buff[1] - radius;
      Max[1] := dest.Buff[1] + radius;
    end
  else
    begin
      Min[1] := dest.Buff[1] - radius;
      Max[1] := Start.Buff[1] + radius;
    end;

  if Start.Buff[2] < dest.Buff[2] then
    begin
      Min[2] := Start.Buff[2] - radius;
      Max[2] := dest.Buff[2] + radius;
    end
  else
    begin
      Min[2] := dest.Buff[2] - radius;
      Max[2] := Start.Buff[2] + radius;
    end;
end;

function TAABB.Intersection(const aabb2: TAABB): TAABB;
var
  i: Integer;
begin
  for i := 0 to 2 do
    begin
      Result.Min[i] := MaxFloat(Min[i], aabb2.Min[i]);
      Result.Max[i] := MinFloat(Max[i], aabb2.Max[i]);
    end;
end;

procedure TAABB.Offset(const Delta: TVector3);
begin
  AddVector(Min, Delta.Buff);
  AddVector(Max, Delta.Buff);
end;

function TAABB.PointIn(const p: TVector3): Boolean;
begin
  Result := (p.Buff[0] <= Max[0]) and (p.Buff[0] >= Min[0])
    and (p.Buff[1] <= Max[1]) and (p.Buff[1] >= Min[1])
    and (p.Buff[2] <= Max[2]) and (p.Buff[2] >= Min[2]);
end;

function TVector2.GetLinkValue(index: Integer): TGeoFloat;
begin
  Result := Buff[index];
end;

procedure TVector2.SetLinkValue(index: Integer; const Value: TGeoFloat);
begin
  Buff[index] := Value;
end;

class operator TVector2.Equal(const Lhs, Rhs: TVector2): Boolean;
begin
  Result := IsEqual(Lhs.Buff, Rhs.Buff);
end;

class operator TVector2.NotEqual(const Lhs, Rhs: TVector2): Boolean;
begin
  Result := NotEqual(Lhs.Buff, Rhs.Buff);
end;

class operator TVector2.GreaterThan(const Lhs, Rhs: TVector2): Boolean;
begin
  Result := (Lhs.Buff[0] > Rhs.Buff[0]) and (Lhs.Buff[1] > Rhs.Buff[1]);
end;

class operator TVector2.GreaterThanOrEqual(const Lhs, Rhs: TVector2): Boolean;
begin
  Result := (Lhs.Buff[0] >= Rhs.Buff[0]) and (Lhs.Buff[1] >= Rhs.Buff[1]);
end;

class operator TVector2.LessThan(const Lhs, Rhs: TVector2): Boolean;
begin
  Result := (Lhs.Buff[0] < Rhs.Buff[0]) and (Lhs.Buff[1] < Rhs.Buff[1]);
end;

class operator TVector2.LessThanOrEqual(const Lhs, Rhs: TVector2): Boolean;
begin
  Result := (Lhs.Buff[0] <= Rhs.Buff[0]) and (Lhs.Buff[1] <= Rhs.Buff[1]);
end;

class operator TVector2.Add(const Lhs, Rhs: TVector2): TVector2;
begin
  Result.Buff := Vec2Add(Lhs.Buff, Rhs.Buff);
end;

class operator TVector2.Add(const Lhs: TVector2; const Rhs: TGeoFloat): TVector2;
begin
  Result.Buff := Vec2Add(Lhs.Buff, Rhs);
end;

class operator TVector2.Add(const Lhs: TGeoFloat; const Rhs: TVector2): TVector2;
begin
  Result.Buff := Vec2Add(Lhs, Rhs.Buff);
end;

class operator TVector2.Subtract(const Lhs, Rhs: TVector2): TVector2;
begin
  Result.Buff := Vec2Sub(Lhs.Buff, Rhs.Buff);
end;

class operator TVector2.Subtract(const Lhs: TVector2; const Rhs: TGeoFloat): TVector2;
begin
  Result.Buff := Vec2Sub(Lhs.Buff, Rhs);
end;

class operator TVector2.Subtract(const Lhs: TGeoFloat; const Rhs: TVector2): TVector2;
begin
  Result.Buff := Vec2Sub(Lhs, Rhs.Buff);
end;

class operator TVector2.Multiply(const Lhs, Rhs: TVector2): TVector2;
begin
  Result.Buff := Vec2Mul(Lhs.Buff, Rhs.Buff);
end;

class operator TVector2.Multiply(const Lhs: TVector2; const Rhs: TGeoFloat): TVector2;
begin
  Result.Buff := Vec2Mul(Lhs.Buff, Rhs);
end;

class operator TVector2.Multiply(const Lhs: TGeoFloat; const Rhs: TVector2): TVector2;
begin
  Result.Buff := Vec2Mul(Lhs, Rhs.Buff);
end;

class operator TVector2.Divide(const Lhs, Rhs: TVector2): TVector2;
begin
  Result.Buff := Vec2Div(Lhs.Buff, Rhs.Buff);
end;

class operator TVector2.Divide(const Lhs: TVector2; const Rhs: TGeoFloat): TVector2;
begin
  Result.Buff := Vec2Div(Lhs.Buff, Rhs);
end;

class operator TVector2.Divide(const Lhs: TGeoFloat; const Rhs: TVector2): TVector2;
begin
  Result.Buff := Vec2Div(Lhs, Rhs.Buff);
end;

class operator TVector2.Implicit(Value: TGeoFloat): TVector2;
begin
  Result.Buff := Vec2(Value);
end;

class operator TVector2.Implicit(Value: TPoint): TVector2;
begin
  Result.Buff := Vec2(Value);
end;

class operator TVector2.Implicit(Value: TPointf): TVector2;
begin
  Result.Buff := Vec2(Value);
end;

class operator TVector2.Implicit(Value: TVec2): TVector2;
begin
  Result.Buff := Value;
end;

class operator TVector2.Explicit(Value: TVector2): TPointf;
begin
  Result := MakePointf(Value.Buff);
end;

class operator TVector2.Explicit(Value: TVector2): TPoint;
begin
  Result := MakePoint(Value.Buff);
end;

class operator TVector2.Explicit(Value: TVector2): TVec2;
begin
  Result := Value.Buff;
end;

procedure TVector2.SetLocation(const fx, fy: TGeoFloat);
begin
  Buff := Vec2(fx, fy);
end;

function TVector2.Distance(const v2: TVector2): TGeoFloat;
begin
  Result := Vec2Distance(Buff, v2.Buff);
end;

function TVector2.Lerp(const v2: TVector2; const t: TGeoFloat): TVector2;
begin
  Result.Buff := Vec2Lerp(Buff, v2.Buff, t);
end;

function TVector2.LerpDistance(const v2: TVector2; const d: TGeoFloat): TVector2;
begin
  Result.Buff := Vec2LerpTo(Buff, v2.Buff, d);
end;

function TVector2.Norm: TGeoFloat;
begin
  Result := Vec2Norm(Buff);
end;

function TVector2.length: TGeoFloat;
begin
  Result := Vec2Length(Buff);
end;

function TVector2.Normalize: TVector2;
begin
  Result.Buff := Vec2Normalize(Buff);
end;

end.
