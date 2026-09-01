enum HomeStripCardShape { circle, square, rectangle }

enum HomeStripCardSize { small, medium, large }

class HomeStripCardStyle {
  const HomeStripCardStyle({
    this.shape = HomeStripCardShape.circle,
    this.size = HomeStripCardSize.medium,
  });

  factory HomeStripCardStyle.fromData(
    Map<String, dynamic> data, {
    HomeStripCardShape defaultShape = HomeStripCardShape.circle,
  }) {
    return HomeStripCardStyle(
      shape: HomeStripCardShape.values.firstWhere(
        (value) => value.name == data['cardShape']?.toString(),
        orElse: () => defaultShape,
      ),
      size: HomeStripCardSize.values.firstWhere(
        (value) => value.name == data['cardSize']?.toString(),
        orElse: () => HomeStripCardSize.medium,
      ),
    );
  }

  final HomeStripCardShape shape;
  final HomeStripCardSize size;

  bool get isCircle => shape == HomeStripCardShape.circle;
  bool get isRectangle => shape == HomeStripCardShape.rectangle;

  double get imageWidth {
    if (isRectangle) {
      return switch (size) {
        HomeStripCardSize.small => 116,
        HomeStripCardSize.medium => 148,
        HomeStripCardSize.large => 184,
      };
    }
    return imageHeight;
  }

  double get imageHeight => switch (size) {
        HomeStripCardSize.small => isRectangle ? 72 : 74,
        HomeStripCardSize.medium => isRectangle ? 92 : 96,
        HomeStripCardSize.large => isRectangle ? 112 : 120,
      };

  double get tileWidth => imageWidth + 14;
  double get stripHeight => imageHeight + 50;

  double get cornerRadius {
    if (isCircle) return imageHeight / 2;
    if (shape == HomeStripCardShape.square) {
      return switch (size) {
        HomeStripCardSize.small => 15,
        HomeStripCardSize.medium => 20,
        HomeStripCardSize.large => 24,
      };
    }
    return switch (size) {
      HomeStripCardSize.small => 14,
      HomeStripCardSize.medium => 18,
      HomeStripCardSize.large => 22,
    };
  }
}
