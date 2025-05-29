import 'package:flutter/material.dart';
import 'dart:math' as math;

class ParallelogramBorder extends ShapeBorder {
  final double skewAmount;
  final BorderSide side;
  final double cornerRadius;

  const ParallelogramBorder({
    this.skewAmount = 15.0,
    this.side = BorderSide.none,
    this.cornerRadius = 0.0,
  });

  @override
  EdgeInsetsGeometry get dimensions {
    return EdgeInsets.all(side.width);
  }

  Path _getPath(Rect rect, double effectiveSkew, double radiusVal) {
    final List<Offset> vertices = [
      Offset(rect.left + effectiveSkew, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.right - effectiveSkew, rect.bottom),
      Offset(rect.left, rect.bottom),
    ];

    double clampedRadius = radiusVal;
    if (clampedRadius > 0) {
      double minHalfSide = double.infinity;
      for (int i = 0; i < vertices.length; i++) {
        final Offset vCurr = vertices[i];
        final Offset vNext = vertices[(i + 1) % vertices.length];
        final double sideLength = (vNext - vCurr).distance;
        if (sideLength < 0.0001) {
          clampedRadius = 0;
          break;
        }
        minHalfSide = math.min(minHalfSide, sideLength / 2.0);
      }
      if (clampedRadius > 0) {
        clampedRadius = math.min(clampedRadius, minHalfSide);
      }
    }
    
    if (clampedRadius <= 0.01) {
      return Path()
        ..moveTo(vertices[0].dx, vertices[0].dy)
        ..lineTo(vertices[1].dx, vertices[1].dy)
        ..lineTo(vertices[2].dx, vertices[2].dy)
        ..lineTo(vertices[3].dx, vertices[3].dy)
        ..close();
    }

    final Path path = Path();
    final Radius arcRadius = Radius.circular(clampedRadius);

    Offset getUnitVector(Offset from, Offset to) {
      final Offset vec = to - from;
      final double len = vec.distance;
      if (len < 0.00001) return Offset.zero;
      return vec / len;
    }

    final List<Offset> arcPoints = List.filled(vertices.length * 2, Offset.zero);

    for (int i = 0; i < vertices.length; i++) {
      final Offset vCurr = vertices[i];
      final Offset vPrev = vertices[(i - 1 + vertices.length) % vertices.length];
      final Offset vNext = vertices[(i + 1) % vertices.length];
      final Offset unitToPrev = getUnitVector(vCurr, vPrev);
      final Offset unitToNext = getUnitVector(vCurr, vNext);
      arcPoints[i * 2]     = vCurr + unitToPrev * clampedRadius;
      arcPoints[i * 2 + 1] = vCurr + unitToNext * clampedRadius;
    }

    path.moveTo(arcPoints[1].dx, arcPoints[1].dy);

    for (int i = 0; i < vertices.length; i++) {
      final int nextVertexIndex = (i + 1) % vertices.length;
      path.lineTo(arcPoints[nextVertexIndex * 2].dx, arcPoints[nextVertexIndex * 2].dy);
      path.arcToPoint(arcPoints[nextVertexIndex * 2 + 1], radius: arcRadius);
    }
    path.close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _getPath(rect.deflate(side.width), skewAmount, cornerRadius);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _getPath(rect, skewAmount, cornerRadius);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0.0) return;
    final Paint paint = side.toPaint()..style = PaintingStyle.stroke..strokeWidth = side.width;
    canvas.drawPath(_getPath(rect.deflate(side.width / 2.0), skewAmount, cornerRadius), paint);
  }

  @override
  ShapeBorder scale(double t) {
    return ParallelogramBorder(
      skewAmount: skewAmount * t,
      side: side.scale(t),
      cornerRadius: cornerRadius * t,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParallelogramBorder &&
        other.skewAmount == skewAmount &&
        other.side == side &&
        other.cornerRadius == cornerRadius;
  }

  @override
  int get hashCode => Object.hash(skewAmount, side, cornerRadius);
}


class CornerTrianglePainter extends CustomPainter {
  final Color color;
  final double triangleSize;
  final double buttonSkewAmount;
  final double buttonHeight;

  CornerTrianglePainter({
    required this.color,
    this.triangleSize = 10.0,
    required this.buttonSkewAmount,
    required this.buttonHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const Offset baseOffset = Offset(12, 0);
    final paint = Paint()..color = color;
    final path = Path();

    final Offset pA = Offset(size.width, 0)+ baseOffset;
    final Offset pB = Offset.zero+baseOffset;

    double horizontalShiftForC = 0;
    if (buttonHeight > 0.01) {
      horizontalShiftForC = (triangleSize / buttonHeight) * buttonSkewAmount;
    }

    final Offset pC = Offset(size.width - horizontalShiftForC, size.height)+baseOffset;
    path.moveTo(pA.dx, pA.dy);
    path.lineTo(pB.dx, pB.dy);
    path.lineTo(pC.dx, pC.dy);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CornerTrianglePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.triangleSize != triangleSize ||
        oldDelegate.buttonSkewAmount != buttonSkewAmount ||
        oldDelegate.buttonHeight != buttonHeight;
  }
}

class Bawidgets {
  static const double _defaultSkew = 12.0;
  static const double _buttonHeight = 42.0;
  static const double _horizontalPaddingBase = 18.0;
  static const double _spaceTextTriangle = 4.0;
  static const Color _iconAndTriangleColor = Color(0xFF455A64); 
  static const Color _textColor = Color(0xFF37474F); 

  Widget _buildSkewedMaterialButton({
    required Widget child,
    VoidCallback? onPressed,
    double? height,
    EdgeInsets? padding,
    required double cornerRadius,
    required double skew,
  }) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: ParallelogramBorder(skewAmount: skew, cornerRadius: cornerRadius),
      child: InkWell(
        onTap: onPressed ?? () {},
        customBorder: ParallelogramBorder(skewAmount: skew, cornerRadius: cornerRadius),
        child: Container(
          height: height ?? _buttonHeight,
          padding: padding ??
              EdgeInsets.only(
                left: _horizontalPaddingBase + math.max(0, skew) * 0.7 - math.min(0, skew) * 0.3, // Adjust for negative skew too
                right: _horizontalPaddingBase - math.max(0, skew) * 0.3 + math.min(0, skew) * 0.7,
                top: 8.0,
                bottom: 8.0,
              ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget buildButton1({required double cornerRadius, double? skew}) {
    final currentSkew = skew ?? _defaultSkew;
    const double triangleSize = 10.0;

    final EdgeInsets buttonPadding = EdgeInsets.only(
      left: _horizontalPaddingBase + math.max(0, currentSkew) * 0.7 - math.min(0, currentSkew) * 0.3,
      right: _horizontalPaddingBase - math.max(0, currentSkew) * 0.3 + math.min(0, currentSkew) * 0.7 + triangleSize + _spaceTextTriangle,
      top: 8.0,
      bottom: 8.0,
    );

    return _buildSkewedMaterialButton(
      skew: currentSkew,
      cornerRadius: cornerRadius,
      padding: buttonPadding,
      onPressed: (){},
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            "最新",
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(triangleSize, triangleSize),
              painter: CornerTrianglePainter(
                color: _iconAndTriangleColor,
                triangleSize: triangleSize,
                buttonSkewAmount: currentSkew,
                buttonHeight: _buttonHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildButton2({required double cornerRadius, double? skew}) {
     final currentSkew = skew ?? _defaultSkew;
     final EdgeInsets iconButtonPadding = const EdgeInsets.symmetric(horizontal: _horizontalPaddingBase, vertical: 8.0).copyWith(
        left: _horizontalPaddingBase + math.max(0, currentSkew) * 0.5 - math.min(0, currentSkew) * 0.5,
        right: _horizontalPaddingBase - math.max(0, currentSkew) * 0.5 + math.min(0, currentSkew) * 0.5,
      );

    return _buildSkewedMaterialButton(
      skew: currentSkew,
      cornerRadius: cornerRadius,
      padding: iconButtonPadding,
      onPressed: (){},
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu, color: _iconAndTriangleColor, size: 22),
          SizedBox(width: 6),
          Icon(Icons.arrow_downward, color: _iconAndTriangleColor, size: 20),
        ],
      ),
    );
  }
}

