import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:signspeak/services/model_service.dart';

void main() {
  group('ModelService & Bounding Box Logic Tests', () {
    test('NormalizedRect toSquareWithPadding creates square with correct dimensions', () {
      // Tall rectangular bounding box (e.g. hand)
      const rect = NormalizedRect(
        left: 0.2,
        top: 0.3,
        right: 0.5,
        bottom: 0.8,
      );

      expect(rect.width, closeTo(0.3, 0.001));
      expect(rect.height, closeTo(0.5, 0.001));

      final square = rect.toSquareWithPadding(1.2);

      // Width and height of square should be equal
      expect(square.width, closeTo(square.height, 0.001));
      // Side should be max(w, h) * 1.2 = 0.5 * 1.2 = 0.6
      expect(square.width, closeTo(0.6, 0.001));

      // Center should match
      final cxOriginal = (rect.left + rect.right) / 2.0;
      final cyOriginal = (rect.top + rect.bottom) / 2.0;
      final cxSquare = (square.left + square.right) / 2.0;
      final cySquare = (square.top + square.bottom) / 2.0;

      expect(cxSquare, closeTo(cxOriginal, 0.001));
      expect(cySquare, closeTo(cyOriginal, 0.001));
    });

    test('NormalizedRect clamps within [0.0, 1.0]', () {
      const edgeRect = NormalizedRect(
        left: 0.0,
        top: 0.0,
        right: 0.9,
        bottom: 0.9,
      );

      final square = edgeRect.toSquareWithPadding(2.0);
      expect(square.left, greaterThanOrEqualTo(0.0));
      expect(square.top, greaterThanOrEqualTo(0.0));
      expect(square.right, lessThanOrEqualTo(1.0));
      expect(square.bottom, lessThanOrEqualTo(1.0));
    });

    test('RecognitionResult empty and unknown definitions', () {
      expect(RecognitionResult.empty.label, equals("No Hand Detected"));
      expect(RecognitionResult.empty.confidence, equals(0.0));
      expect(RecognitionResult.empty.isRecognized, isFalse);

      expect(RecognitionResult.unknown.label, equals("Unknown"));
      expect(RecognitionResult.unknown.confidence, equals(0.0));
      expect(RecognitionResult.unknown.isRecognized, isFalse);

      const validResult = RecognitionResult(
        label: "A",
        confidence: 0.85,
        index: 0,
        scores: [0.85],
      );
      expect(validResult.isRecognized, isTrue);
    });

    test('preprocessImage creates 64x64x3 float32 tensor in range [0, 255]', () {
      final modelService = ModelService();

      // Create a dummy image
      final testImg = img.Image(width: 100, height: 150);
      // Fill with sample color
      for (int y = 0; y < 150; y++) {
        for (int x = 0; x < 100; x++) {
          testImg.setPixelRgb(x, y, 120, 200, 50);
        }
      }

      final tensor = modelService.preprocessImage(
        testImg,
        cropRoi: const NormalizedRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9),
      );

      // Expected size: 1 * 64 * 64 * 3 = 12,288
      expect(tensor.length, equals(1 * 64 * 64 * 3));

      // Values should be in [0.0, 255.0]
      for (int i = 0; i < tensor.length; i += 3) {
        expect(tensor[i], closeTo(120.0, 5.0));     // R
        expect(tensor[i + 1], closeTo(200.0, 5.0)); // G
        expect(tensor[i + 2], closeTo(50.0, 5.0));  // B
      }
    });
  });
}
