unit TAChartStrConsts;

{$mode objfpc}{$H+}

interface

resourcestring
  // Series types
  rsAreaSeries = 'Area series';
  rsBarSeries = 'Bar series';
  rsBoxAndWhiskerSeries = 'Box-and-whiskers series';
  rsBubbleSeries = 'Bubble series';
  rsBSplineSeries = 'B-Spline series';
  rsColorMapSeries = 'Color map series';
  rsConstantLine = 'Constant line';
  rsCubicSplineSeries = 'Cubic spline series';
  rsFieldSeries = 'Vector field series';
  rsFunctionSeries = 'Function series';
  rsLeastSquaresFitSeries = 'Least-squares fit series';
  rsLineSeries = 'Line series';
  rsManhattanPlotSeries = 'Manhattan plot series';
  rsOpenHighLowCloseSeries = 'Open-high-low-close series';
  rsParametricCurveSeries = 'Parametric curve series';
  rsPieSeries = 'Pie series';
  rsPolarSeries = 'Polar series';
  rsUserDrawnSeries = 'User-drawn series';
  rsExpressionSeries = 'Math expression series';
  rsExpressionColorMapSeries = 'Math expression color map series';

  // Series editor
  sesSeriesEditorTitle = 'Edit series';

  // Data points editor
  desDatapointEditor = 'DataPoints editor';
  desColor = 'Color';
  desText = 'Text';
  desInsertRow = 'Insert row';
  desDeleteRow = 'Delete row';

  // Axis
  rsLeft = 'Left';
  rsRight = 'Right';
  rsTop = 'Top';
  rsBottom = 'Bottom';
  rsHidden = 'hidden';
  rsInverted = 'inverted';

  // Subcomponents editor
  rsAdd = 'Add';
  rsDelete = 'Delete';
  rsMoveUp = 'Up';
  rsMoveDown = 'Down';

  // Tool editor
  tasToolsEditorTitle = 'Edit tools';

  rsZoomByDrag = 'Zoom by drag';
  rsZoomByClick = 'Zoom by click';
  rsZoomByMousewheel = 'Zoom by mouse-wheel';
  rsPanningByDrag = 'Panning by drag';
  rsPanningByClick = 'Panning by click';
  rsPanningByMousewheel = 'Panning by mouse wheel';
  //rsReticule = 'Reticule';
  rsDataPointClick = 'Data point click';
  rsDataPointDrag = 'Data point drag';
  rsDataPointHint = 'Data point hint';
  rsDataPointCrossHair = 'Data point crosshair';
  rsUserDefinedTool = 'User-defined';
  rsDistanceMeasurement = 'Distance measurement';

  // Transformations
  tasAxisTransformsEditorTitle = 'Edit axis transformations';
  rsAutoScale = 'Auto scale';
  rsCumulativeNormalDistribution = 'Cumulative normal distribution';
  rsLinear = 'Linear';
  rsLogarithmic = 'Logarithmic';
  rsUserDefined = 'User-defined';
  rsInvalidLogBase = 'Logarithm base must be > 0 and <> 1.';

  // ChartUtils
  tasFailedSubcomponentRename = 'Failed to rename components: %s';

  // ChartCombos
  rsRectangleSymbol = 'Rectangle';
  rsCircleSymbol = 'Circle';
  rsTriangleSymbol = 'Triangle';
  rsCrossSymbol = 'Plus';
  rsDiagCrossSymbol = 'Cross';
  rsStarSymbol = 'Star (lines)';
  rsLowBracketSymbol = 'Low bracket';
  rsHighBracketSymbol = 'High bracket';
  rsLeftBracketSymbol = 'Left bracket';
  rsRightBracketSymbol = 'Right bracket';
  rsDiamondSymbol = 'Diamond';
  rsHexagonSymbol = 'Hexagon';
  rsFullStarSymbol = 'Star (full)';
  rsLeftTriangleSymbol = 'Left triangle';
  rsRightTriangleSymbol = 'Right triangle';
  rsDownTriangleSymbol = 'Down triangle';
  rsVertBarSymbol = 'Vertical bar';
  rsHorBarSymbol = 'Horizontal bar';
  rsPointSymbol = 'Point';
  rsNoSymbol = '(none)';

  rsPSSolid = 'solid line';
  rsPSDash = 'dashed line';
  rsPSDot = 'dotted line';
  rsPSDashDot = 'dash-dot';
  rsPSDashDotDot = 'dash-dot-dot';
  rsPSInsideFrame = 'solid (inside frame)';
  rsPSPattern = 'patterned line';
  rsPSClear = 'no line';

  rsBSSolid = 'solid fill';
  rsBSHorizontal = 'horizontally hatched';
  rsBSVertical = 'vertically hatched';
  rsBSFDiagonal = 'forward-diagonal hatch';
  rsBSBDiagonal = 'backward-diagonal hatch';
  rsBSCross = 'crossed';
  rsBSDiagCross = 'diagonally crossed';
  rsBSClear = 'no fill';
  rsBSImage = 'image fill';
  rsBSPattern = 'pattern fill';

  rsErrInvalidResultType = 'Expression result type must be integer or float. Got "%s".';
//  rsTDistParamError = 'Function tdist() requires parameter "tails" to be 1 or 2. Get %d.';

implementation

end.

