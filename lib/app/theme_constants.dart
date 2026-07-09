const double adminTextScaleFactor = 1.4;

const double _adminCompactTextScaleFactor = 1.08;
const double _adminCompactTextScaleWidth = 360;
const double _adminDesktopTextScaleWidth = 1080;

double resolveAdminTextScaleFactor(double width) {
  final progress =
      ((width - _adminCompactTextScaleWidth) /
              (_adminDesktopTextScaleWidth - _adminCompactTextScaleWidth))
          .clamp(0.0, 1.0)
          .toDouble();

  return _adminCompactTextScaleFactor +
      ((adminTextScaleFactor - _adminCompactTextScaleFactor) * progress);
}
