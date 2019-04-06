// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';

import 'basic.dart';
import 'framework.dart';
import 'inherited_notifier.dart';
import 'layout_builder.dart';
import 'notification_listener.dart';
import 'scroll_context.dart';
import 'scroll_controller.dart';
import 'scroll_notification.dart';
import 'scroll_physics.dart';
import 'scroll_position.dart';
import 'scroll_position_with_single_context.dart';
import 'scroll_simulation.dart';

/// The signature of a method that provides a [BuildContext] and
/// [ScrollController] for building a widget that may overflow the draggable
/// [Axis] of the containing [DraggableScrollSheet].
///
/// Users should apply the [scrollController] to a [ScrollView] subclass, such
/// as a [SingleChildScrollView], [ListView] or [GridView], to have the whole
/// sheet be draggable.
typedef ScrollableWidgetBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
);

/// A container for a [Scrollable] that responds to drag gestures by resizing
/// the scrollable until a limit is reached, and then scrolling.
///
/// This widget can be dragged along the vertical axis between its
/// [minChildSize], which defaults to `0.25` and [maxChildSize], which defaults
/// to `1.0`. These sizes are percentages of the height of the parent container.
///
/// The widget coordinates resizing and scrolling of the widget returned by
/// builder as the user drags along the horizontal axis.
///
/// The widget will initially be displayed at its initialChildSize which
/// defaults to `0.5`, meaning half the height of its parent. Dragging will work
/// between the range of minChildSize and maxChildSize (as percentages of the
/// parent container's height) as long as the builder creates a widget which
/// uses the provided [ScrollController]. If the widget created by the
/// [ScrollableWidgetBuilder] does not use provided [ScrollController], the
/// sheet will remain at the initialChildSize.
///
/// By default, the widget will expand its non-occupied area to fill availble
/// space in the parent. If this is not desired, e.g. because the parent wants
/// to position sheet based on the space it is taking, the [expand] property
/// may be set ot false.
///
/// {@tool sample}
///
/// This is a sample widget which shows a [ListView] that has 25 [ListTile]s.
/// It starts out as taking up half the body of the [Scaffold], and can be
/// dragged up to the full height of the scaffold or down to 25% of the height
/// of the scaffold. Upon reaching full height, the list contents will be
/// scrolled up or down, until they reach the top of the list again and the user
/// drags the sheet back down.
///
/// ```dart
/// class HomePage extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(
///         title: const Text('DraggableScrollableSheet'),
///       ),
///       body: SizedBox.expand(
///         child: DraggableScrollableSheet(
///           builder: (BuildContext context, ScrollController scrollController) {
///             return Container(
///               color: Colors.blue[100],
///               child: ListView.builder(
///                 controller: scrollController,
///                 itemCount: 25,
///                 itemBuilder: (BuildContext context, int index) {
///                   return ListTile(title: Text('Item $index'));
///                 },
///               ),
///             );
///           },
///         ),
///       ),
///     );
///   }
/// }
/// ```
/// {@end-tool}
class DraggableScrollableSheet extends StatefulWidget {
  /// Creates a widget that can be dragged and scrolled in a single gesture.
  ///
  /// The [builder], [initialChildSize], [minChildSize], [maxChildSize] and
  /// [expand] parameters must not be null.
  const DraggableScrollableSheet({
    Key key,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 1.0,
    this.expand = true,
    @required this.builder,
  })  : assert(initialChildSize != null),
        assert(minChildSize != null),
        assert(maxChildSize != null),
        assert(minChildSize >= 0.0),
        assert(maxChildSize <= 1.0),
        assert(minChildSize <= initialChildSize),
        assert(initialChildSize <= maxChildSize),
        assert(expand != null),
        assert(builder != null),
        super(key: key);

  /// The initial fractional value of the parent container's height to use when
  /// displaying the widget.
  ///
  /// The default value is `0.5`.
  final double initialChildSize;

  /// The minimum fractional value of the parent container's height to use when
  /// displaying the widget.
  ///
  /// The default value is `0.25`.
  final double minChildSize;

  /// The maximum fractional value of the parent container's height to use when
  /// displaying the widget.
  ///
  /// The default value is `1.0`.
  final double maxChildSize;

  /// Whether the widget should expand to fill the available space in its parent
  /// or not.
  ///
  /// In most cases, this should be true. However, in the case of a parent
  /// widget that will position this one based on its desired size (such as a
  /// [MultiChildLayoutDelegate]), this should be set to false.
  ///
  /// The default value is true.
  final bool expand;

  /// The builder that creates a child to display in this widget, which will
  /// use the provided [ScrollController] to enable dragging and scrolling
  /// of the contents.
  final ScrollableWidgetBuilder builder;

  @override
  _DraggableScrollableSheetState createState() => _DraggableScrollableSheetState();
}

/// A [Notification] related to the position of the [DraggableScrollableSheet].
///
/// [DraggableScrollableSheet] widgets notify their ancestors about layout
/// related changes. When the extent of the sheet changes via a drag,
/// this notification bubbles up through the tree, which means a given
/// [NotificationListener] will recieve notifications for all descendant
/// [DraggableScrollableSheet] widgets. To focus on notifications form the
/// nearest [DraggableScorllableSheet] descendant, check that the [depth]
/// property of the notification is zero.
///
/// When a extent notification is received by a [NotificationListener], the
/// listener will already have completed build and layout, and it is therefore
/// too late for that widget to call [State.setState]. Any attempt to adjust the
/// build or layout based on an extent notification would result in a layout
/// that lagged one frame behind, which is a poor user experience. Extent
/// notifications are used primarily to drive animations. The [Scaffold] widget
/// is an example of driving animations for the [FloatingActionButton] as the
/// sheet scrolls up.
class ExtentNotification extends Notification with ViewportNotificationMixin {
  /// Creates a notification that the extent of a [DraggableScrollableSheet] has
  /// changed.
  ///
  /// All parameters are required. The [minExtent] must be >= 0.  The [maxExtent]
  /// must be <= 1.0.  The [extent] must be between [minExtent] and [maxExtent].
  ExtentNotification({
    @required this.extent,
    @required this.minExtent,
    @required this.maxExtent,
    @required this.initialExtent,
    @required this.context,
  }) : assert(extent != null),
       assert(initialExtent != null),
       assert(minExtent != null),
       assert(maxExtent != null),
       assert(0.0 <= minExtent),
       assert(maxExtent <= 1.0),
       assert(minExtent <= extent),
       assert(extent <= maxExtent),
       assert(context != null);

  /// The current value of the extent, between [minExtent] and [maxExtent].
  final double extent;

  /// The minimum value of [extent], which is >= 0.
  final double minExtent;

  /// The maximum value of [extent].
  final double maxExtent;

  /// The initially requested value for [extent].
  final double initialExtent;

  /// The build context of the widget that fired this notification.
  ///
  /// This can be used to find the sheet's render objects to determine the size
  /// of the viewport, for instance.
  final BuildContext context;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('minExtent: $minExtent, extent: $extent, maxExtent: $maxExtent, initialExtent: $initialExtent');
  }
}

/// Manages state between [_DraggableScrollableSheetState],
/// [_DraggableScrollableSheetScrollController], and
/// [_DraggableScrollableSheetScrollPosition].
///
/// The State knows the pixels available along the axis the widget wants to
/// scroll, but expects to get a fraction of those pixels to render the sheet.
///
/// The ScrollPosition knows the number of pixels a user wants to move the sheet.
///
/// The [currentExtent] will never be null.
/// The [availablePixels] will never be null, but may be `double.infinity`.
class _DraggableSheetExtent {
  _DraggableSheetExtent({
    @required this.minExtent,
    @required this.maxExtent,
    @required this.initialExtent,
    @required VoidCallback listener,
  }) : assert(minExtent != null),
       assert(maxExtent != null),
       assert(initialExtent != null),
       assert(minExtent >= 0),
       assert(maxExtent <= 1),
       assert(minExtent <= initialExtent),
       assert(initialExtent <= maxExtent),
       _currentExtent = ValueNotifier<double>(initialExtent)..addListener(listener),
       availablePixels = double.infinity;

  final double minExtent;
  final double maxExtent;
  final double initialExtent;
  final ValueNotifier<double> _currentExtent;
  double availablePixels;

  bool get isAtMin => minExtent >= _currentExtent.value;
  bool get isAtMax => maxExtent <= _currentExtent.value;

  set currentExtent(double value) {
    assert(value != null);
    _currentExtent.value = value.clamp(minExtent, maxExtent);
  }
  double get currentExtent => _currentExtent.value;

  /// The scroll position gets inputs in terms of pixels, but the extent is
  /// expected to be expressed as a number between 0..1.
  void addPixelDelta(double delta, BuildContext context) {
    currentExtent += delta / availablePixels;
    ExtentNotification(
      minExtent: minExtent,
      maxExtent: maxExtent,
      extent: currentExtent,
      initialExtent: initialExtent,
      context: context,
    ).dispatch(context);
  }
}

class _DraggableScrollableSheetState extends State<DraggableScrollableSheet> {
  _DraggableScrollableSheetScrollController _scrollController;
  _DraggableSheetExtent _extent;

  @override
  void initState() {
    super.initState();
    _extent = _DraggableSheetExtent(
      minExtent: widget.minChildSize,
      maxExtent: widget.maxChildSize,
      initialExtent: widget.initialChildSize,
      listener: _setExtent,
    );
    _scrollController = _DraggableScrollableSheetScrollController(extent: _extent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (InheritedResetNotifier.shouldReset(context)) {
      // jumpTo can result in trying to replace semantics during build.
      // Just animate really fast.
      // Avoid doing it at all if the offset is already 0.0.
      if (_scrollController.offset != 0.0) {
        _scrollController.animateTo(
          0.0,
          duration: Duration(milliseconds: 1),
          curve: Curves.linear,
        );
      }
      _extent._currentExtent.value = _extent.initialExtent;
    }
  }

  void _setExtent() {
    setState(() {
      // _extent has been updated when this is called.
    });

  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _extent.availablePixels = widget.maxChildSize * constraints.biggest.height;
        final Widget sheet = FractionallySizedBox(
          heightFactor: _extent.currentExtent,
          child: widget.builder(context, _scrollController),
          alignment: Alignment.bottomCenter,
        );
        return widget.expand ? SizedBox.expand(child: sheet) : sheet;
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

/// A [ScrollController] suitable for use in a [ScrollableWidgetBuilder] created
/// by a [DraggableScrollableSheet].
///
/// If a [DraggableScrollableSheet] contains content that is exceeds the height
/// of its container, this controller will allow the sheet to both be dragged to
/// fill the container and then scroll the child content.
///
/// See also:
///
///  * [_DraggableScrollableSheetScrollPosition], which manages the positioning logic for
///    this controller.
///  * [PrimaryScrollController], which can be used to establish a
///    [_DraggableScrollableSheetScrollController] as the primary controller for
///    descendants.
class _DraggableScrollableSheetScrollController extends ScrollController {
  _DraggableScrollableSheetScrollController({
    double initialScrollOffset = 0.0,
    String debugLabel,
    @required this.extent,
  }) : assert(extent != null),
       super(
         debugLabel: debugLabel,
         initialScrollOffset: initialScrollOffset,
       );

  final _DraggableSheetExtent extent;

  @override
  _DraggableScrollableSheetScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition oldPosition,
  ) {
    return _DraggableScrollableSheetScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      extent: extent,
    );
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('extent: $extent');
  }
}

/// A scroll position that manages scroll activities for
/// [_DraggableScrollableSheetScrollController].
///
/// This class is a concrete subclass of [ScrollPosition] logic that handles a
/// single [ScrollContext], such as a [Scrollable]. An instance of this class
/// manages [ScrollActivity] instances, which changes the
/// [_DraggableSheetExtent.currentExtent] or visible content offset in the
/// [Scrollable]'s [Viewport]
///
/// See also:
///
///  * [_DraggableScrollableSheetScrollController], which uses this as its [ScrollPosition].
class _DraggableScrollableSheetScrollPosition
    extends ScrollPositionWithSingleContext {
  _DraggableScrollableSheetScrollPosition({
    @required ScrollPhysics physics,
    @required ScrollContext context,
    double initialPixels = 0.0,
    bool keepScrollOffset = true,
    ScrollPosition oldPosition,
    String debugLabel,
    @required this.extent,
  })  : assert(extent != null),
        super(
          physics: physics,
          context: context,
          initialPixels: initialPixels,
          keepScrollOffset: keepScrollOffset,
          oldPosition: oldPosition,
          debugLabel: debugLabel,
        );

  VoidCallback _dragCancelCallback;
  final _DraggableSheetExtent extent;
  bool get listShouldScroll => pixels > 0.0;

  @override
  void applyUserOffset(double delta) {
    if (!listShouldScroll &&
        (!(extent.isAtMin || extent.isAtMax) ||
          (extent.isAtMin && delta < 0) ||
          (extent.isAtMax && delta > 0))) {
      extent.addPixelDelta(-delta, context.notificationContext);
    } else {
      super.applyUserOffset(delta);
    }
  }

  @override
  void goBallistic(double velocity) {
    if (velocity == 0.0 ||
       (velocity < 0.0 && listShouldScroll) ||
       (velocity > 0.0 && extent.isAtMax)) {
      super.goBallistic(velocity);
      return;
    }
    // Scrollable expects that we will dispose of its current _dragCancelCallback
    _dragCancelCallback?.call();
    _dragCancelCallback = null;

    // The iOS bouncing simulation just isn't right here - once we delegate
    // the ballistic back to the ScrollView, it will use the right simulation.
    final Simulation simulation = ClampingScrollSimulation(
      position: extent.currentExtent,
      velocity: velocity,
      tolerance: physics.tolerance,
    );

    final AnimationController ballisticController = AnimationController.unbounded(
      debugLabel: '$runtimeType',
      vsync: context.vsync,
    );
    double lastDelta = 0;
    void _tick() {
      final double delta = ballisticController.value - lastDelta;
      lastDelta = ballisticController.value;
      extent.addPixelDelta(delta, context.notificationContext);
      if ((velocity > 0 && extent.isAtMax) || (velocity < 0 && extent.isAtMin)) {
        // Make sure we pass along enough velocity to keep scrolling - otherwise
        // we just "bounce" off the top making it look like the list doesn't
        // have more to scroll.
        velocity = ballisticController.velocity + (physics.tolerance.velocity * ballisticController.velocity.sign);
        super.goBallistic(velocity);
        ballisticController.stop();
      }
    }

    ballisticController
      ..addListener(_tick)
      ..animateWith(simulation).whenCompleteOrCancel(
        ballisticController.dispose,
      );
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    // Save this so we can call it later if we have to [goBallistic] on our own.
    _dragCancelCallback = dragCancelCallback;
    return super.drag(details, dragCancelCallback);
  }
}

/// A [ChangeNotifier] to use with [InheritedResetNotifer] to notify
/// descendants that they should reset to initial state.
class ResetNotifier extends ChangeNotifier {
  bool _wasCalled = false;

  /// Fires a reset notification to descendants.
  ///
  /// Returns false if there are no listeners.
  bool sendReset() {
    if (!hasListeners) {
      return false;
    }
    _wasCalled = true;
    notifyListeners();
    return true;
  }
}

/// An [InheritedNotifier] that can be used to notify descdendant
/// [DraggableScrollableSheet]s set its extent to a particular value.
///
/// A widget that manipulates the [Navigator] on [ExtentNofitication]s may use
/// a [DraggableScrollableSheetContext] to notify its children that they should
/// scroll to a particular position. For example, when a persistent bottom sheet
/// in a scaffold is scrolled upwards by a screen reader, a [LocalHistoryEntry]
/// is added to the enclosing [ModalRoute] so that screen reading software will
/// be able to notify the user that they can go back, and to enable a user to
/// do so without requiring the use of a drag gesture that the screen reader
/// cannot assist with.
///
/// See also:
///   * [Scaffold.bottomSheet], which uses this mechanism.
class InheritedResetNotifier extends InheritedNotifier<ResetNotifier> {
  /// Creates an [InheritedNotifier] that the [DraggableScrollableSheet] will
  /// listen to for an indication that it should change its extent.
  ///
  /// The [child] and [notifier] properties must not be null.
  const InheritedResetNotifier({
    Key key,
    @required Widget child,
    @required ResetNotifier notifier,
  }) : super(key: key, child: child, notifier: notifier);

  /// Specifies whether the [DraggableScrollableSheet] should reset to its
  /// initial position.
  ///
  /// Returns true if the notifier requested a reset, false otherwise.
  static bool shouldReset(BuildContext context) {
    final InheritedWidget widget = context.inheritFromWidgetOfExactType(InheritedResetNotifier);
    if (widget == null) {
      return false;
    }
    assert(widget is InheritedResetNotifier);
    final InheritedResetNotifier inheritedNotifier = widget;
    final bool wasCalled = inheritedNotifier.notifier._wasCalled;
    inheritedNotifier.notifier._wasCalled = false;
    return wasCalled;
  }
}
